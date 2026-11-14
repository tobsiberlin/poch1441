#!/usr/bin/env python3
"""Build the deterministic dark mineral table surface used during play.

The texture is intentionally quiet: multi-scale aggregate, a few shallow pores,
and broad upper-left illumination. It is generated once at build time so the
runtime only scales one opaque image behind the physical table world.
"""

from __future__ import annotations

import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "App/Assets.xcassets/PochTableConcrete.imageset/poch-table-concrete.png"
SIZE = 1536
SEED = 1_441_2026
BASE_RGB = np.array([29.0, 32.0, 36.0], dtype=np.float32)


def noise_field(grid: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    source = Image.fromarray(rng.integers(0, 256, (grid, grid), dtype=np.uint8), mode="L")
    resized = source.resize((SIZE, SIZE), Image.Resampling.BICUBIC)
    return (np.asarray(resized, dtype=np.float32) - 127.5) / 127.5


def pore_field() -> np.ndarray:
    rng = random.Random(SEED + 90)
    pores = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(pores)
    for _ in range(340):
        x = rng.randrange(10, SIZE - 10)
        y = rng.randrange(10, SIZE - 10)
        radius_x = rng.uniform(0.65, 2.7)
        radius_y = radius_x * rng.uniform(0.55, 1.25)
        strength = rng.randrange(90, 190)
        draw.ellipse(
            (x - radius_x, y - radius_y, x + radius_x, y + radius_y),
            fill=strength,
        )
    return np.asarray(pores.filter(ImageFilter.GaussianBlur(0.55)), dtype=np.float32) / 255.0


def build_surface() -> Image.Image:
    coarse = noise_field(14, SEED + 1)
    aggregate = noise_field(58, SEED + 2)
    grain = noise_field(286, SEED + 3)
    pores = pore_field()

    axis = np.linspace(0.0, 1.0, SIZE, dtype=np.float32)
    x, y = np.meshgrid(axis, axis)
    upper_left_light = 4.8 - x * 4.2 - y * 5.0
    radial_distance = np.sqrt(((x - 0.48) / 0.78) ** 2 + ((y - 0.43) / 0.82) ** 2)
    edge_falloff = -2.4 * np.clip(radial_distance - 0.36, 0.0, 0.82) ** 1.35

    structure = coarse * 3.4 + aggregate * 1.65 + grain * 0.62
    value = structure + upper_left_light + edge_falloff - pores * 10.5

    # A slightly cooler response in the fine aggregate prevents neutral gray
    # from turning warm beneath the jewel-colored phase atmosphere.
    result = np.empty((SIZE, SIZE, 3), dtype=np.float32)
    result[:, :, 0] = BASE_RGB[0] + value * 0.91
    result[:, :, 1] = BASE_RGB[1] + value * 0.98
    result[:, :, 2] = BASE_RGB[2] + value * 1.06 + aggregate * 0.25
    result = np.clip(np.rint(result), 0, 255).astype(np.uint8)
    return Image.fromarray(result, mode="RGB")


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    build_surface().save(OUTPUT, optimize=True)
    print(OUTPUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
