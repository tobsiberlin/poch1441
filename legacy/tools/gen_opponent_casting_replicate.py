#!/usr/bin/env python3
"""Generate preview-only opponent casting boards for the HTML design review."""

import json
import os
import time
from pathlib import Path

import replicate
import requests


ROOT = Path("/Users/tobsi/poch1441")
OUT = ROOT / "artifacts" / "opponent-casting"
LOG = OUT / "log.json"
MODEL = "black-forest-labs/flux-1.1-pro"

OUT.mkdir(parents=True, exist_ok=True)

key_file = Path("~/.config/replicate.key").expanduser()
if key_file.exists():
    os.environ["REPLICATE_API_TOKEN"] = key_file.read_text().strip()

BASE = (
    "premium mobile card-game opponent casting board, three equal vertical portrait panels, "
    "one different authentic white European adult in each panel, chest-up, direct or slightly off-camera gaze, "
    "natural facial asymmetry and skin texture, believable lived-in faces rather than fashion models, "
    "contemporary understated European clothing, quiet confidence, restrained editorial painted realism, "
    "clean graphic shapes, dark warm graphite studio background, soft frontal key light, delicate warm brass rim light, "
    "consistent camera height and crop across all three panels, generous safe padding around every head, "
    "high facial readability at small mobile size, no interaction between panels"
)

AVOID = (
    "no text, no labels, no logo, no watermark, no fantasy, no period costume, no medieval clothing, no crown, "
    "no casino, no poker room, no neon, no cyberpunk, no glamour retouching, no influencer look, no caricature, "
    "no emoji, no plastic skin, no exaggerated gesture, no face crop, no profile-only portrait, no duplicate person"
)

DIRECTIONS = [
    {
        "id": "A-contemporary-table",
        "seed": 144411,
        "subjects": (
            "left: a thoughtful white German woman age 36, ash-brown shoulder-length hair, observant grey-green eyes, "
            "charcoal wool overshirt; middle: a composed white French man age 43, short dark blond hair with early grey, "
            "light stubble, navy knit polo; right: a sharp white Dutch woman age 51, short silver-blond crop, fine smile lines, "
            "graphite tailored jacket. All expressions calm, attentive and subtly competitive"
        ),
    },
    {
        "id": "B-intergenerational",
        "seed": 144412,
        "subjects": (
            "left: a candid white Austrian man age 29, tousled brown hair, open intelligent face, dark crew-neck knit; "
            "middle: a self-possessed white Italian woman age 46, dark wavy bob with a few silver strands, expressive brows, "
            "deep green structured blouse; right: a dignified white Belgian man age 62, silver hair, weathered face, "
            "round subtle glasses, matte charcoal jacket. Expressions warm, experienced and strategically alert"
        ),
    },
    {
        "id": "C-quiet-rivals",
        "seed": 144413,
        "subjects": (
            "left: a reserved white Scandinavian woman age 33, pale freckled skin, copper-blond hair tied loosely back, "
            "petrol high-neck top; middle: a pragmatic white British man age 39, close brown curls, clean shaven, "
            "slate overshirt; right: a charismatic white Spanish woman age 44, warm fair skin, dark chestnut bob, "
            "muted burgundy jacket. Expressions readable but restrained, like serious friends around a real game table"
        ),
    },
    {
        "id": "D-character-table",
        "seed": 144414,
        "subjects": (
            "left: a white Swiss woman age 58, natural silver curls, angular face, calm analytical gaze, black knit jacket; "
            "middle: a white Irish man age 35, auburn hair, faint freckles, trimmed beard, muted olive shirt jacket; "
            "right: a white Czech man age 48, receding dark hair, pronounced cheekbones, clean shaven, deep navy workwear jacket. "
            "Distinct memorable silhouettes, intelligent restrained expressions, authentic rather than polished"
        ),
    },
    {
        "id": "E-real-game-night",
        "seed": 144415,
        "subjects": (
            "left: an ordinary white German woman age 42 with a slightly tired but warm face, natural mousy-brown bob, "
            "minimal makeup, small smile lines, charcoal cardigan; middle: an ordinary white Polish man age 54, thinning hair, "
            "uneven grey stubble, thoughtful eyes, dark blue work shirt; right: an ordinary white French woman age 31, "
            "freckled fair skin, loosely tied dark blond hair with flyaways, plain burgundy knit. Documentary honesty, "
            "subtle imperfections, familiar people one could actually meet at a weekly game night"
        ),
    },
    {
        "id": "F-seasoned-players",
        "seed": 144416,
        "subjects": (
            "left: a white Danish man age 67 with a narrow weathered face, sparse silver hair, clean shaven, black knit polo; "
            "middle: a white Czech woman age 55 with a strong nose, natural under-eye lines, short dark hair streaked grey, "
            "muted green blouse; right: a white Austrian man age 37 with an approachable round face, sandy hair, light beard, "
            "graphite overshirt. Unretouched mature skin, distinct everyday faces, calm competitive focus, no glamour"
        ),
    },
]


def fetch(output) -> bytes:
    item = output[0] if isinstance(output, list) else output
    if hasattr(item, "read"):
        return item.read()
    if hasattr(item, "url"):
        item = item.url
    response = requests.get(str(item), timeout=240)
    response.raise_for_status()
    return response.content


def main() -> None:
    log = {}
    for direction in DIRECTIONS:
        path = OUT / f"{direction['id']}.png"
        prompt = f"{BASE}. Subjects: {direction['subjects']}. {AVOID}."
        if not path.exists():
            print(f"[{direction['id']}] generating")
            for attempt in range(3):
                try:
                    started = time.time()
                    result = replicate.run(
                        MODEL,
                        input={
                            "prompt": prompt,
                            "aspect_ratio": "16:9",
                            "output_format": "png",
                            "output_quality": 100,
                            "prompt_upsampling": False,
                            "safety_tolerance": 2,
                            "seed": direction["seed"],
                        },
                    )
                    path.write_bytes(fetch(result))
                    print(f"[{direction['id']}] ok ({time.time() - started:.0f}s)")
                    break
                except Exception as exc:
                    print(f"[{direction['id']}] attempt {attempt + 1}: {exc}")
                    if attempt == 2:
                        raise
                    time.sleep(4)
        log[direction["id"]] = {
            "model": MODEL,
            "seed": direction["seed"],
            "prompt": prompt,
            "file": path.name,
        }
    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False) + "\n")
    print(OUT)


if __name__ == "__main__":
    main()
