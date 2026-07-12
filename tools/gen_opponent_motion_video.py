#!/usr/bin/env python3
"""Generate one identity-locked opponent reaction clip for visual evaluation."""

import argparse
import os
from pathlib import Path

import replicate
import requests


ROOT = Path("/Users/tobsi/poch1441")
PORTRAITS = ROOT / "artifacts" / "opponent-roster"
OUTPUT = ROOT / "artifacts" / "opponent-motion"
MODELS = {
    "live": "minimax/video-01-live",
    "hailuo": "minimax/hailuo-2.3",
}

REACTIONS = {
    "pressure": (
        "A locked-off portrait shot of the exact same woman. The camera, crop, lighting, background, hairstyle, clothing, "
        "head angle and shoulders remain still. Her pupils keep looking toward the viewer's right exactly as in the first "
        "frame, never toward the camera. She starts neutral. Her expression gradually tightens into restrained competitive "
        "focus during a card game: a small brow furrow, slightly narrowed eyes, subtly tightened lower eyelids, and a composed "
        "closed-mouth expression. Her lips remain closed and relaxed enough to feel human. Emotion intensity is 35 percent: "
        "clearly readable but understated. Only facial muscles move. No teeth visible at any time, no open mouth, no grimace, "
        "no anger, no aggression, no speech, no lip sync, no head movement, no body movement, no camera movement, no zoom, "
        "no cuts, no scene change, no added objects, no morphing identity, no beauty retouching, no exaggerated acting."
    ),
}


def fetch(output) -> bytes:
    if hasattr(output, "read"):
        return output.read()
    if hasattr(output, "url"):
        output = output.url
    response = requests.get(str(output), timeout=600)
    response.raise_for_status()
    return response.content


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", default="Liv")
    parser.add_argument("--reaction", choices=REACTIONS, default="pressure")
    parser.add_argument("--model", choices=MODELS, default="hailuo")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    key_file = Path("~/.config/replicate.key").expanduser()
    if key_file.exists():
        os.environ["REPLICATE_API_TOKEN"] = key_file.read_text().strip()

    source = PORTRAITS / f"Opponent{args.name}Neutral.png"
    destination = OUTPUT / f"Opponent{args.name}{args.reaction.title()}Motion-{args.model}-v1.mp4"
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if destination.exists() and not args.force:
        print(destination)
        return

    with source.open("rb") as first_frame:
        model_input = {
            "first_frame_image": first_frame,
            "prompt": REACTIONS[args.reaction],
            "prompt_optimizer": False,
        }
        if args.model == "hailuo":
            model_input.update({"duration": 6, "resolution": "768p"})
        result = replicate.run(MODELS[args.model], input=model_input)
    destination.write_bytes(fetch(result))
    print(destination)


if __name__ == "__main__":
    main()
