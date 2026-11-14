#!/usr/bin/env python3
"""Generate the locked, neutral Poch 1441 glass token source asset."""

import os
from pathlib import Path

import replicate
import requests


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Assets_Raw" / "game-tokens" / "glass-token-v3.png"
REFERENCE = ROOT / "Assets_Raw" / "game-tokens" / "glass-token-v2.png"
MODEL = "black-forest-labs/flux-kontext-pro"


def fetch(item: object) -> bytes:
    if isinstance(item, list):
        item = item[0]
    if hasattr(item, "read"):
        return item.read()
    if hasattr(item, "url"):
        item = item.url()
    response = requests.get(str(item), timeout=300)
    response.raise_for_status()
    return response.content


def main() -> None:
    key_file = Path("~/.config/replicate.key").expanduser()
    if key_file.exists():
        os.environ["REPLICATE_API_TOKEN"] = key_file.read_text().strip()

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    prompt = (
        "Edit this exact token into a flatter, more tactile board-game piece while preserving its sharp brass edge and dark "
        "premium material contrast. Remove the convex lens and dome completely. Replace it with a flat inset smoked mineral-"
        "glass disc, visibly only 4 mm thick, with a subtle fine horizontal microtexture and one narrow controlled highlight. "
        "Exact orthographic top-down view, perfectly circular, centered and fully visible with generous padding. Keep the thin "
        "satin dark-brass and gunmetal rim without alternating casino stripes. Include a "
        "tight crisp contact shadow only. Place it on a perfectly flat solid #FF00FF background. No bowl, no other tokens, "
        "no text, no number, no logo, no symbol, no poker chip pattern, no sphere, no marble, no blur, no neon, no glow, "
        "no chrome mirror, no tilt, no perspective, no watermark. The token must remain crisp and recognizable at 16 pixels."
    )
    with REFERENCE.open("rb") as input_image:
        output = replicate.run(
            MODEL,
            input={
                "prompt": prompt,
                "input_image": input_image,
                "aspect_ratio": "1:1",
                "output_format": "png",
                "safety_tolerance": 2,
                "prompt_upsampling": False,
                "seed": 144169,
            },
        )
    OUTPUT.write_bytes(fetch(output))
    print(OUTPUT)


if __name__ == "__main__":
    main()
