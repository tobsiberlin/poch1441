#!/usr/bin/env python3
"""Generate neutral portrait references for the additional opponent pool."""

import argparse
import os
from pathlib import Path

import replicate
import requests


ROOT = Path("/Users/tobsi/poch1441")
OUTPUT = ROOT / "artifacts" / "opponent-roster"
MODEL = "openai/gpt-image-2"

PROFILES = {
    "Hana": (
        "an adult East Asian woman in her early thirties, shoulder-length dark hair with a clean natural shape, "
        "wearing a restrained deep forest-green contemporary knit top"
    ),
    "Darius": (
        "an adult Black man in his late thirties, close-cropped natural hair and neatly trimmed short beard, "
        "wearing a restrained charcoal contemporary knit shirt"
    ),
    "Samir": (
        "an adult Middle Eastern man in his mid thirties, dark wavy hair and a neatly trimmed short beard, "
        "wearing a restrained black contemporary overshirt"
    ),
}


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
    parser.add_argument("--name", choices=PROFILES, required=True)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    key_file = Path("~/.config/replicate.key").expanduser()
    if key_file.exists():
        os.environ["REPLICATE_API_TOKEN"] = key_file.read_text().strip()

    OUTPUT.mkdir(parents=True, exist_ok=True)
    destination = OUTPUT / f"Opponent{args.name}Neutral.png"
    if destination.exists() and not args.force:
        print(destination)
        return

    prompt = (
        f"A photorealistic square studio portrait of {PROFILES[args.name]}. Calm attentive neutral expression, authentic "
        "natural skin texture, direct but relaxed presence, subtle gaze just beside the camera. Head and upper shoulders, "
        "generous dark negative space around the head, consistent eye line, soft low-key directional studio light, dark "
        "graphite seamless background. Contemporary premium card-game character portrait, grounded and believable, not a "
        "fashion campaign. No cultural costume, no jewelry emphasis, no props, no cards, no casino, no neon, no text, no "
        "logo, no glamour retouching, no caricature."
    )
    client = replicate.Client(timeout=900)
    result = client.run(
        MODEL,
        input={
            "prompt": prompt,
            "aspect_ratio": "1:1",
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
