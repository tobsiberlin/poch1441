#!/usr/bin/env python3
"""Erweitert die gelockten Gegnerportraits um Reaktionszustände via Replicate.

Die vorhandenen Triptychs dienen als Bildreferenz. FLUX Kontext editiert nur
Ausdruck und dezente Gestik; Identität, Kleidung, Kamera und Licht bleiben fest.
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
LOG = RAW / "reactions-log.json"
MODEL = "black-forest-labs/flux-kontext-pro"

REACTIONS = ["Winning", "Defeated", "Surprised"]
PEOPLE = [
    ("Mira", 244301),
    ("Kian", 244302),
    ("Juno", 244303),
]

PROMPT = (
    "Keep the exact same three-panel triptych, exact person identity, facial structure, skin tone, "
    "hair, clothing, crop, camera, background and premium painted-realism lighting. Change only "
    "the expressions and restrained upper-body gestures. Left panel: controlled genuine victory, "
    "lifted posture, warm restrained smile, one subtle hand gesture near the chest. Middle panel: "
    "composed defeat, quiet exhale, softened gaze, shoulders slightly lowered, dignified not sad. "
    "Right panel: brief impressed surprise, slightly widened eyes and one subtle open-palm gesture. "
    "Keep every face centered and highly readable at small mobile size. No text, no labels, no logo, "
    "no casino, no poker gesture, no cheering, no raised fists, no hands covering faces, no new person, "
    "no wardrobe change, no camera change, no crop change, no neon, no fantasy."
)


def fetch_output(output):
    if hasattr(output, "read"):
        return output.read()
    item = output[0] if isinstance(output, list) else output
    if hasattr(item, "url"):
        item = item.url
    response = requests.get(str(item), timeout=240)
    response.raise_for_status()
    return response.content


def save_imageset(image: Image.Image, asset_name: str):
    preview_path = PREVIEW / f"{asset_name}.png"
    image.save(preview_path, quality=100)

    image_set = ASSETS / f"{asset_name}.imageset"
    image_set.mkdir(parents=True, exist_ok=True)
    image.save(image_set / f"{asset_name}.png", quality=100)
    manifest = {
        "images": [
            {"filename": f"{asset_name}.png", "idiom": "universal", "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (image_set / "Contents.json").write_text(json.dumps(manifest, indent=2) + "\n")


def crop_triptych(source: Path, person: str):
    image = Image.open(source).convert("RGB")
    panel_width = image.width / 3
    for index, reaction in enumerate(REACTIONS):
        x0 = int(round(index * panel_width))
        x1 = int(round((index + 1) * panel_width))
        panel = image.crop((x0, 0, x1, image.height))
        side = int(min(panel.width * 0.90, panel.height * 0.90))
        left = (panel.width - side) // 2
        top = max(0, int((panel.height - side) * 0.30))
        crop = panel.crop((left, top, left + side, top + side))
        crop = crop.resize((1024, 1024), Image.Resampling.LANCZOS)
        save_imageset(crop, f"Opponent{person}{reaction}")


def main():
    key_file = Path("~/.config/replicate.key").expanduser()
    if key_file.exists():
        os.environ["REPLICATE_API_TOKEN"] = key_file.read_text().strip()

    force = "--force" in sys.argv
    log = json.loads(LOG.read_text()) if LOG.exists() else {}
    for person, seed in PEOPLE:
        reference = RAW / f"{person}-triptych.png"
        output_path = RAW / f"{person}-reactions-triptych.png"
        if not reference.exists():
            raise FileNotFoundError(reference)

        if not output_path.exists() or force:
            print(f"[{person}] reaction edit via {MODEL}")
            for attempt in range(3):
                try:
                    started = time.time()
                    with reference.open("rb") as input_image:
                        output = replicate.run(
                            MODEL,
                            input={
                                "prompt": PROMPT,
                                "input_image": input_image,
                                "aspect_ratio": "match_input_image",
                                "output_format": "png",
                                "safety_tolerance": 2,
                                "prompt_upsampling": False,
                                "seed": seed,
                            },
                        )
                    output_path.write_bytes(fetch_output(output))
                    print(f"[{person}] ok ({time.time() - started:.0f}s)")
                    break
                except Exception as exc:
                    print(f"[{person}] attempt {attempt + 1} failed: {str(exc)[:240]}")
                    if attempt == 2:
                        raise
                    time.sleep(4)

        crop_triptych(output_path, person)
        log[person] = {
            "model": MODEL,
            "seed": seed,
            "prompt": PROMPT,
            "reference": str(reference.relative_to(ROOT)),
            "source": str(output_path.relative_to(ROOT)),
        }

    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False) + "\n")
    print(PREVIEW)


if __name__ == "__main__":
    main()
