#!/usr/bin/env python3
"""Generate one consistent multi-expression portrait sheet from a reference identity."""

import argparse
import os
from pathlib import Path

import replicate
import requests
from PIL import Image


ROOT = Path("/Users/tobsi/poch1441")
PORTRAITS = ROOT / "artifacts" / "opponent-roster"
OUTPUT = ROOT / "artifacts" / "opponent-expression-sheets"
MODEL = "openai/gpt-image-2"
STATES = ("Neutral", "Thinking", "Pressure", "Surprised", "Winning", "Defeated")
PROFILES = {
    "Liv": "adult white European woman",
    "Mara": "adult white European woman",
    "Nina": "adult white European woman",
    "Thomas": "adult white European man",
    "Jonas": "adult white European man",
    "Leon": "adult white European man",
    "Noah": "adult white European man",
    "Finn": "adult white European man",
    "Hana": "adult East Asian woman",
    "Darius": "adult Black man",
    "Samir": "adult Middle Eastern man",
}


def fetch(item) -> bytes:
    if hasattr(item, "read"):
        return item.read()
    if hasattr(item, "url"):
        item = item.url
    response = requests.get(str(item), timeout=600)
    response.raise_for_status()
    return response.content


def crop_sheet(sheet_path: Path, name: str) -> None:
    sheet = Image.open(sheet_path).convert("RGB")
    panel_width = sheet.width // 3
    panel_height = sheet.height // 2
    destination = OUTPUT / name
    destination.mkdir(parents=True, exist_ok=True)
    for index, state in enumerate(STATES):
        column = index % 3
        row = index // 3
        panel = sheet.crop(
            (
                column * panel_width,
                row * panel_height,
                (column + 1) * panel_width,
                (row + 1) * panel_height,
            )
        )
        panel.save(destination / f"{state}.png", quality=100)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", choices=PROFILES, default="Liv")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    key_file = Path("~/.config/replicate.key").expanduser()
    if key_file.exists():
        os.environ["REPLICATE_API_TOKEN"] = key_file.read_text().strip()

    source = PORTRAITS / f"Opponent{args.name}Neutral.png"
    OUTPUT.mkdir(parents=True, exist_ok=True)
    destination = OUTPUT / f"Opponent{args.name}ExpressionSheet-v1.png"
    if destination.exists() and not args.force:
        crop_sheet(destination, args.name)
        print(destination)
        return

    prompt = (
        "Edit the input portrait into one photorealistic professional actor expression reference sheet. Create exactly six "
        "equal square portrait panels in a precise 3-column by 2-row grid with narrow dark gutters. Every panel must show the "
        f"exact same {PROFILES[args.name]} from the input, with identical facial identity, hairstyle, clothing, background, "
        "studio lighting, shoulder crop, head size, head angle, camera position and original gaze direction. Never change sex, "
        "age, identity, wardrobe, lighting, framing or gaze. Only facial muscles may change. Panel order, left to "
        "right: top row (1) calm neutral, (2) unmistakably calculating with one raised eyebrow, one-sided squint and pursed "
        "lips, (3) restrained competitive pressure with furrowed brow, narrowed eyes, closed lips and set jaw; bottom row "
        "(4) believable surprise with raised brows, wide eyes and slightly parted lips, (5) warm confident victory with genuine "
        "smile and cheek lift, (6) restrained defeat with inner brows raised, lowered eyelids and clearly downturned mouth corners. "
        "All six expressions must be visibly distinct and readable at 64 pixels while remaining authentic and dignified. "
        "No text, no captions, no symbols, no numbers, no watermark, no hands, no props, no visible teeth except a natural "
        "small smile if necessary, no caricature, no theatrical acting, no beauty retouching."
    )
    with source.open("rb") as reference:
        client = replicate.Client(timeout=900)
        result = client.run(
            MODEL,
            input={
                "prompt": prompt,
                "input_images": [reference],
                "aspect_ratio": "3:2",
                "quality": "high",
                "number_of_images": 1,
                "output_format": "png",
                "background": "opaque",
                "moderation": "auto",
            },
        )
    item = result[0] if isinstance(result, list) else result
    destination.write_bytes(fetch(item))
    crop_sheet(destination, args.name)
    print(destination)


if __name__ == "__main__":
    main()
