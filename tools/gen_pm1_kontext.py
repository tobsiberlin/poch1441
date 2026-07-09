#!/usr/bin/env python3
"""PM1-reference retakes with correct physical Poch board geometry.

Uses PM1 as image reference for material/aesthetic only. The generated target
must rebuild the geometry: 8 outer coin basins + 1 centered basin, not an
overlay on PM1's invalid pocket layout.
"""
import os
import time
from pathlib import Path

import replicate
import requests
from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/Users/tobsi/poch1441")
SRC = ROOT / "Assets_Raw" / "pochring" / "precision-monolith" / "PM1.png"
RAW = ROOT / "Assets_Raw" / "pochring" / "precision-monolith"
ART = ROOT / "artifacts" / "precision-monolith"

MODEL = "black-forest-labs/flux-kontext-pro"
KEY_FILE = Path("~/.config/replicate.key").expanduser()
if KEY_FILE.exists():
    os.environ["REPLICATE_API_TOKEN"] = KEY_FILE.read_text().strip()

GUARDS = (
    "Keep the exact PM1 material mood from the reference image: dark graphite ceramic, "
    "fine engraved black-on-black surface ornament, warm edge catchlights, premium real "
    "manufactured board-game object. Do not add neon, LEDs, UI glow, casino, roulette, "
    "poker chips, text, letters, numbers, logo, monogram, emblem, center symbol, cheap "
    "painted overlay, sticker rings, broken/chipped color, glossy gems, candy colors."
)

BASE = (
    "Edit the reference into a correct physical Poch board while preserving PM1's "
    "material and aesthetic. Rebuild the board geometry cleanly: exactly eight outer "
    "coin basins arranged symmetrically around exactly one centered middle basin, nine "
    "basins total. The center basin must be perfectly centered in the circular board. "
    "The eight outer basins should be slightly larger and a little farther outward than "
    "in the reference, prepared to hold real coins: shallow flat coin floors with rounded "
    "steep side walls, not hemispherical bowls. The middle basin is smaller than the old "
    "large central plate, calm and functional, also with a flat coin floor. "
)

JOBS = [
    (
        "PM38",
        "PM1 Real Board A",
        144238,
        BASE
        + "Each outer basin has a complete, very thin matte pigment inlay set into the inner lip, "
        "subtle like PM1's existing colored material edges, not bright and not painted on top. "
        "Five inlays are muted antique gold, one deep garnet, one dark emerald teal, one restrained amethyst. "
        "The center basin has a thin matte platinum inner lip. "
        + GUARDS,
    ),
    (
        "PM39",
        "PM1 Real Board B",
        144239,
        BASE
        + "Make the pigment inlays even quieter and more material-like: thin continuous colored bevels "
        "inside every basin lip, aligned perfectly with the circular wells. Slightly wider outer basins, "
        "stronger real-board manufacturable spacing between basins, centered platinum middle pot. "
        + GUARDS,
    ),
    (
        "PM40",
        "PM1 Real Board C",
        144240,
        BASE
        + "Most conservative PM1 retake: preserve the reference look strongly, but correct the layout to "
        "8 outer basins plus centered middle basin. Colored inlays are barely visible satin mineral material "
        "inside the lips, complete and centered, no cheap overlay effect. "
        + GUARDS,
    ),
]


def fetch_output(output):
    if hasattr(output, "read"):
        return output.read()
    item = output[0] if isinstance(output, list) else output
    if hasattr(item, "url"):
        item = item.url
    response = requests.get(str(item), timeout=180)
    response.raise_for_status()
    return response.content


def label_image(src: Path, dest: Path, label: str, name: str):
    img = Image.open(src).convert("RGB")
    img.thumbnail((1000, 1000), Image.Resampling.LANCZOS)
    pad = 78
    out = Image.new("RGB", (img.width, img.height + pad), (10, 8, 12))
    out.paste(img, (0, pad))
    draw = ImageDraw.Draw(out)
    try:
        font_big = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 30)
        font_small = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 20)
    except OSError:
        font_big = ImageFont.load_default()
        font_small = ImageFont.load_default()
    draw.text((18, 14), label, fill=(226, 232, 240), font=font_big)
    draw.text((120, 20), name, fill=(197, 160, 89), font=font_small)
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)


def main():
    RAW.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    for label, name, seed, prompt in JOBS:
        raw_path = RAW / f"{label}.png"
        art_path = ART / f"{label}.png"
        print(f"[{label}] {name} via {MODEL}")
        for attempt in range(3):
            try:
                t0 = time.time()
                with SRC.open("rb") as input_image:
                    output = replicate.run(
                        MODEL,
                        input={
                            "prompt": prompt,
                            "input_image": input_image,
                            "aspect_ratio": "match_input_image",
                            "output_format": "png",
                            "safety_tolerance": 2,
                            "prompt_upsampling": False,
                            "seed": seed,
                        },
                    )
                raw_path.write_bytes(fetch_output(output))
                label_image(raw_path, art_path, label, name)
                print(f"[{label}] ok ({time.time() - t0:.0f}s)")
                break
            except Exception as exc:
                print(f"[{label}] Fehler {attempt + 1}: {str(exc)[:220]}")
                time.sleep(4)


if __name__ == "__main__":
    main()
