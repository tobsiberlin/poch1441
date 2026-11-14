#!/usr/bin/env python3
"""Retake only the framing of an existing six-panel opponent expression sheet."""

import argparse
import os
from pathlib import Path

import replicate
import requests


ROOT = Path("/Users/tobsi/poch1441")
SHEETS = ROOT / "artifacts" / "opponent-expression-sheets"
MODEL = "openai/gpt-image-2"


def fetch(item) -> bytes:
    if hasattr(item, "read"):
        return item.read()
    if hasattr(item, "url"):
        item = item.url
    response = requests.get(str(item), timeout=600)
    response.raise_for_status()
    return response.content


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--percent", type=int, default=20)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    key_file = Path("~/.config/replicate.key").expanduser()
    if key_file.exists():
        os.environ["REPLICATE_API_TOKEN"] = key_file.read_text().strip()

    source = SHEETS / f"Opponent{args.name}ExpressionSheet-v1.png"
    destination = SHEETS / f"Opponent{args.name}ExpressionSheet-framing-v2.png"
    if destination.exists() and not args.force:
        print(destination)
        return

    prompt = (
        f"Edit only the camera framing of this exact six-panel 3-by-2 actor expression sheet. Zoom the camera out uniformly "
        f"by {args.percent} percent in every panel, revealing the complete head, hair and upper shoulders with generous dark "
        "negative space. Extend the existing studio background seamlessly. Preserve the exact same person, identity, age, "
        "hairstyle, clothing, facial expression, gaze direction, lighting, colors, panel order, panel dimensions and narrow "
        "gutters. Keep all six expressions unchanged. Exactly six equal panels, no text, no captions, no symbols, no new "
        "person, no wardrobe change, no expression change, no crop mismatch between panels."
    )
    client = replicate.Client(timeout=900)
    with source.open("rb") as reference:
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
    print(destination)


if __name__ == "__main__":
    main()
