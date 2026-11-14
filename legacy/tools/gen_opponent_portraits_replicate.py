#!/usr/bin/env python3
"""Erzeugt konsistente Gegner-Portraitsets für Poch 1441 via Replicate.

Jede Generation ist ein Triptychon derselben Figur. Die drei Panels werden
anschließend deterministisch in neutrale, nachdenkliche und druckvolle
Portrait-Assets geschnitten. Schrift und UI bleiben außerhalb des Artworks.
"""

import json
import os
import sys
import time
from pathlib import Path

import replicate
import requests
from PIL import Image


ROOT = Path("/Users/tobsi/poch1441")
RAW = ROOT / "Assets_Raw" / "opponents" / "replicate"
PREVIEW = ROOT / "artifacts" / "opponents"
ASSETS = ROOT / "App" / "Assets.xcassets" / "Opponents"
LOG = RAW / "log.json"
MODEL = "black-forest-labs/flux-1.1-pro"

RAW.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)
ASSETS.mkdir(parents=True, exist_ok=True)

key_file = Path("~/.config/replicate.key").expanduser()
if key_file.exists():
    os.environ["REPLICATE_API_TOKEN"] = key_file.read_text().strip()

STYLE = (
    "premium mobile board-game character portrait triptych, three equal vertical panels, "
    "the exact same person in every panel with identical face, hair, clothing, camera, crop and lighting, "
    "chest-up editorial painted realism with clean graphic shapes, expressive but restrained, "
    "timeless contemporary wardrobe, quiet luxury, dark warm graphite studio backdrop, "
    "soft frontal key light and delicate warm brass rim light, high facial readability at small mobile size, "
    "centered head and shoulders, generous safe padding, no hands covering the face"
)

PANELS = (
    "left panel calm neutral attentive expression, "
    "middle panel visibly thinking with focused eyes and one subtle raised brow, "
    "right panel confident pressure expression with direct gaze and restrained half smile"
)

AVOID = (
    "no text, no labels, no logo, no watermark, no fantasy, no medieval costume, no crown, "
    "no casino, no poker room, no neon, no cyberpunk, no cartoon emoji, no caricature, "
    "no duplicate people inside one panel, no face crop, no profile view, no dramatic gesture, "
    "no inconsistent identity, no changing clothes, no changing hairstyle"
)

JOBS = [
    {
        "id": "Mira",
        "seed": 144301,
        "subject": (
            "Mira, a poised woman in her early thirties with warm olive skin, straight dark chin-length bob, "
            "intelligent brown eyes, charcoal tailored jacket with one muted emerald enamel pin"
        ),
    },
    {
        "id": "Kian",
        "seed": 144302,
        "subject": (
            "Kian, a thoughtful man in his mid thirties with medium brown skin, short textured black hair, "
            "neatly trimmed beard, observant dark eyes, deep graphite overshirt with one muted amethyst accent"
        ),
    },
    {
        "id": "Juno",
        "seed": 144303,
        "subject": (
            "Juno, a sharp nonbinary person in their early thirties with deep brown skin, close cropped hair, "
            "defined cheekbones, alert dark eyes, matte black high-collar jacket with one muted petrol accent"
        ),
    },
]

MOODS = ["Neutral", "Thinking", "Pressure"]


def fetch_output(output):
    if hasattr(output, "read"):
        return output.read()
    item = output[0] if isinstance(output, list) else output
    if hasattr(item, "url"):
        item = item.url
    response = requests.get(str(item), timeout=240)
    response.raise_for_status()
    return response.content


def crop_triptych(source: Path, person: str):
    image = Image.open(source).convert("RGB")
    panel_width = image.width / 3
    for index, mood in enumerate(MOODS):
        x0 = int(round(index * panel_width))
        x1 = int(round((index + 1) * panel_width))
        panel = image.crop((x0, 0, x1, image.height))
        # Die Generator-Trennlinien liegen exakt an den Panelkanten. Ein engerer
        # quadratischer Crop entfernt sie, ohne Gesicht oder Schulter anzuschneiden.
        side = int(min(panel.width * 0.90, panel.height * 0.90))
        left = (panel.width - side) // 2
        top = max(0, int((panel.height - side) * 0.30))
        crop = panel.crop((left, top, left + side, top + side)).resize((1024, 1024), Image.Resampling.LANCZOS)

        asset_name = f"Opponent{person}{mood}"
        preview_path = PREVIEW / f"{asset_name}.png"
        crop.save(preview_path, quality=100)

        image_set = ASSETS / f"{asset_name}.imageset"
        image_set.mkdir(parents=True, exist_ok=True)
        crop.save(image_set / f"{asset_name}.png", quality=100)
        manifest = {
            "images": [
                {"filename": f"{asset_name}.png", "idiom": "universal", "scale": "1x"},
                {"idiom": "universal", "scale": "2x"},
                {"idiom": "universal", "scale": "3x"},
            ],
            "info": {"author": "xcode", "version": 1},
        }
        (image_set / "Contents.json").write_text(json.dumps(manifest, indent=2) + "\n")


def main():
    force = "--force" in sys.argv
    log = json.loads(LOG.read_text()) if LOG.exists() else {}
    for job in JOBS:
        source = RAW / f"{job['id']}-triptych.png"
        prompt = f"{STYLE}. Subject: {job['subject']}. Expressions: {PANELS}. {AVOID}."
        if not source.exists() or force:
            print(f"[{job['id']}] via {MODEL}")
            for attempt in range(3):
                try:
                    started = time.time()
                    output = replicate.run(
                        MODEL,
                        input={
                            "prompt": prompt,
                            "aspect_ratio": "16:9",
                            "output_format": "png",
                            "output_quality": 100,
                            "prompt_upsampling": False,
                            "safety_tolerance": 2,
                            "seed": job["seed"],
                        },
                    )
                    source.write_bytes(fetch_output(output))
                    print(f"[{job['id']}] ok ({time.time() - started:.0f}s)")
                    break
                except Exception as exc:
                    print(f"[{job['id']}] attempt {attempt + 1} failed: {str(exc)[:240]}")
                    if attempt == 2:
                        raise
                    time.sleep(4)
        crop_triptych(source, job["id"])
        log[job["id"]] = {
            "model": MODEL,
            "seed": job["seed"],
            "prompt": prompt,
            "source": str(source.relative_to(ROOT)),
        }
    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False) + "\n")
    print(PREVIEW)


if __name__ == "__main__":
    main()
