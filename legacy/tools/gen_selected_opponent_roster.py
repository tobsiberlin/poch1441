#!/usr/bin/env python3
"""Build identity-locked reaction previews for the selected opponent roster."""

import argparse
import json
import os
import time
from pathlib import Path
from typing import Optional

import replicate
import requests
from PIL import Image


ROOT = Path("/Users/tobsi/poch1441")
CASTING = ROOT / "artifacts" / "opponent-casting"
RAW = ROOT / "Assets_Raw" / "opponents" / "roster"
PREVIEW = ROOT / "artifacts" / "opponent-roster"
LOG = RAW / "log.json"
MODEL = "black-forest-labs/flux-kontext-max"

RAW.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)

ROSTER = {
    "C1": {"name": "Liv", "board": "C-quiet-rivals.png", "panel": 0, "seed": 344411},
    "E1": {"name": "Mara", "board": "E-real-game-night.png", "panel": 0, "seed": 344412},
    "E3": {"name": "Nina", "board": "E-real-game-night.png", "panel": 2, "seed": 344413},
    "F1": {"name": "Thomas", "board": "F-seasoned-players.png", "panel": 0, "seed": 344414},
    "F3": {"name": "Jonas", "board": "F-seasoned-players.png", "panel": 2, "seed": 344415},
    "C2": {"name": "Leon", "board": "C-quiet-rivals.png", "panel": 1, "seed": 344416},
    "B1": {"name": "Noah", "board": "B-intergenerational.png", "panel": 0, "seed": 344417},
    "D2": {"name": "Finn", "board": "D-character-table.png", "panel": 1, "seed": 344418},
}

LOCK = (
    "Use the input portrait as the strict identity and camera reference. Return one single square portrait of the exact same person. "
    "Preserve the exact facial identity, head rotation, chin angle, eye line, "
    "gaze direction and gaze target relative to the camera. Her irises must remain aimed toward the viewer's right, exactly "
    "as in the input portrait; do not make her look into the camera. Preserve shoulder angle, posture, hairstyle, clothing, focal length, "
    "crop, background and lighting. The face and eyes must remain at the same pixel position as in the input portrait. "
    "Change only facial muscle tension and a small amount of upper-body tension. The reaction must be unmistakable "
    "even at 64 pixels while remaining authentic, as if captured during a real high-stakes card game. "
    "natural skin texture, readable at small mobile size. No text, no labels, no logo, no hands near the face, no new person, "
    "no wardrobe change, no camera change, no head turn, no eye-direction change, no beauty retouching, no glamour, "
    "no caricature, no theatrical posing, no neon, no casino."
)

MOODS = {
    "Thinking": (
        10,
        "A clearly visible skeptical calculation reaction: her left eyebrow is distinctly raised while the other is lowered, "
        "one eye strongly squints in concentration, lips visibly purse to one side, and a pronounced vertical crease forms between the brows. "
        "This is a mid-reaction photograph, not a nearly neutral portrait."
    ),
    "Pressure": (
        20,
        "A clearly visible competitive pressure reaction: both eyebrows pulled sharply down and together, deep brow furrow, "
        "eyes narrowed, lower eyelids tightened, nostrils tense, jaw visibly clenched and lips firmly compressed. A subtle "
        "forward tension in her shoulders reinforces the stare. This is a mid-reaction photograph, not a neutral portrait. "
        "She remains the same woman. "
        "No masculine facial structure, no facial hair."
    ),
    "Surprised": (
        30,
        "Clearly surprised for one brief moment: eyebrows lifted high, eyes visibly widened, lips slightly parted, "
        "a small inhale visible in the cheeks. Believable and dignified, not comic."
    ),
    "Winning": (
        40,
        "Clearly pleased by a hard-earned win: genuine asymmetric smile, visible cheek lift, eyes warmly crinkled, "
        "subtle confidence in the jaw. Joyful but not cheering."
    ),
    "Defeated": (
        50,
        "A clearly visible restrained defeat reaction immediately after losing: inner eyebrows rise into a pronounced "
        "worried crease, upper eyelids droop, the mouth forms a visible downturned frown, lips press after a quiet "
        "exhale, cheeks slack and shoulders visibly release. This is a mid-reaction photograph, not a neutral portrait. "
        "Dignified, not crying or melodramatic."
    ),
}


def fetch(output) -> bytes:
    item = output[0] if isinstance(output, list) else output
    if hasattr(item, "read"):
        return item.read()
    if hasattr(item, "url"):
        item = item.url
    response = requests.get(str(item), timeout=240)
    response.raise_for_status()
    return response.content


def square_crop(panel: Image.Image) -> Image.Image:
    side = int(min(panel.width * 0.90, panel.height * 0.82))
    left = (panel.width - side) // 2
    top = max(0, int((panel.height - side) * 0.22))
    return panel.crop((left, top, left + side, top + side)).resize(
        (1024, 1024), Image.Resampling.LANCZOS
    )


def extract_reference(candidate: str, config: dict) -> Path:
    board = Image.open(CASTING / config["board"]).convert("RGB")
    panel_width = board.width / 3
    x0 = int(round(config["panel"] * panel_width))
    x1 = int(round((config["panel"] + 1) * panel_width))
    reference = square_crop(board.crop((x0, 0, x1, board.height)))
    path = RAW / f"{candidate}-{config['name']}-reference.png"
    reference.save(path, quality=100)
    reference.save(PREVIEW / f"Opponent{config['name']}Neutral.png", quality=100)
    return path


def generate(candidate: str, force: bool, only_reference: bool, selected_mood: Optional[str], log: dict) -> None:
    config = ROSTER[candidate]
    reference = extract_reference(candidate, config)
    entry = {"name": config["name"], "reference": str(reference.relative_to(ROOT)), "moods": {}}
    if only_reference:
        log[candidate] = entry
        return

    moods = {selected_mood: MOODS[selected_mood]} if selected_mood else MOODS
    for mood, (seed_offset, mood_prompt) in moods.items():
        source = RAW / f"{candidate}-{config['name']}-{mood}.png"
        prompt = (
            "Edit the single input portrait. Return one single square portrait, not a panel, grid or collage. "
            f"{LOCK} The person is a white European woman and must remain the exact same woman. {mood_prompt}"
        )
        if not source.exists() or force:
            print(f"[{candidate}/{config['name']}/{mood}] generating")
            for attempt in range(3):
                try:
                    started = time.time()
                    with reference.open("rb") as input_image:
                        result = replicate.run(
                            MODEL,
                            input={
                                "prompt": prompt,
                                "input_image": input_image,
                                "aspect_ratio": "match_input_image",
                                "output_format": "png",
                                "safety_tolerance": 2,
                                "prompt_upsampling": False,
                                "seed": config["seed"] + seed_offset,
                            },
                        )
                    source.write_bytes(fetch(result))
                    print(f"[{candidate}/{mood}] ok ({time.time() - started:.0f}s)")
                    break
                except Exception as exc:
                    print(f"[{candidate}/{mood}] attempt {attempt + 1}: {exc}")
                    if attempt == 2:
                        raise
                    time.sleep(4)
        image = Image.open(source).convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
        image.save(PREVIEW / f"Opponent{config['name']}{mood}.png", quality=100)
        entry["moods"][mood] = {
            "source": str(source.relative_to(ROOT)),
            "prompt": prompt,
            "seed": config["seed"] + seed_offset,
        }
    log[candidate] = entry


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", choices=ROSTER.keys())
    parser.add_argument("--mood", choices=MOODS.keys())
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--only-reference", action="store_true")
    args = parser.parse_args()

    key_file = Path("~/.config/replicate.key").expanduser()
    if key_file.exists():
        os.environ["REPLICATE_API_TOKEN"] = key_file.read_text().strip()

    log = json.loads(LOG.read_text()) if LOG.exists() else {}
    candidates = [args.candidate] if args.candidate else list(ROSTER)
    for candidate in candidates:
        generate(candidate, args.force, args.only_reference, args.mood, log)
    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False) + "\n")
    print(PREVIEW)


if __name__ == "__main__":
    main()
