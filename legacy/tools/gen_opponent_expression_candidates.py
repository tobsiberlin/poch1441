#!/usr/bin/env python3
"""Generate high-variance expression candidates from a locked opponent identity."""

import argparse
import os
from pathlib import Path

import replicate
import requests


ROOT = Path("/Users/tobsi/poch1441")
PORTRAITS = ROOT / "artifacts" / "opponent-roster"
OUTPUT = ROOT / "artifacts" / "opponent-expression-candidates"
MODEL = "minimax/image-01"

MOODS = {
    "thinking": (
        "She is visibly calculating a difficult card-game decision: one eyebrow raised, the other lowered, a one-sided "
        "squint, lips pursed slightly to one side, focused and skeptical."
    ),
    "pressure": (
        "She projects restrained competitive pressure during a card game: eyebrows lowered and drawn together, a clear "
        "brow furrow, narrowed eyes, tightened lower eyelids, closed lips and a set jaw. Intense but dignified, not angry."
    ),
    "defeated": (
        "She has just lost a close card-game round and shows clearly readable restrained disappointment: inner eyebrows "
        "raised, upper eyelids lowered, mouth corners visibly downturned, cheeks relaxed after a quiet exhale. Dignified, "
        "not crying."
    ),
}


def fetch(item) -> bytes:
    if hasattr(item, "read"):
        return item.read()
    if hasattr(item, "url"):
        item = item.url
    response = requests.get(str(item), timeout=300)
    response.raise_for_status()
    return response.content


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", default="Liv")
    parser.add_argument("--mood", choices=MOODS, required=True)
    parser.add_argument("--count", type=int, choices=range(1, 10), default=4)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    key_file = Path("~/.config/replicate.key").expanduser()
    if key_file.exists():
        os.environ["REPLICATE_API_TOKEN"] = key_file.read_text().strip()

    source = PORTRAITS / f"Opponent{args.name}Neutral.png"
    destination = OUTPUT / args.name / args.mood
    destination.mkdir(parents=True, exist_ok=True)
    existing = sorted(destination.glob("candidate-*.jpg"))
    if len(existing) >= args.count and not args.force:
        print(destination)
        return

    prompt = (
        "Create a photorealistic square portrait of the exact same adult white European woman from the subject reference. "
        "Preserve her identity, age, facial proportions, red hair in the same bun, teal turtleneck, dark neutral background, "
        "soft studio lighting, shoulder crop, head size, head angle and gaze toward the viewer's right. "
        f"{MOODS[args.mood]} The expression must be unmistakably different from neutral and readable at 64 pixels while "
        "remaining authentic. No direct eye contact, no head turn, no open mouth, no visible teeth, no hands, no props, "
        "no text, no logo, no glamour retouching, no caricature, no theatrical pose."
    )
    with source.open("rb") as subject_reference:
        result = replicate.run(
            MODEL,
            input={
                "prompt": prompt,
                "aspect_ratio": "1:1",
                "number_of_images": args.count,
                "prompt_optimizer": False,
                "subject_reference": subject_reference,
            },
        )
    for index, item in enumerate(result, start=1):
        (destination / f"candidate-{index:02d}.jpg").write_bytes(fetch(item))
    print(destination)


if __name__ == "__main__":
    main()
