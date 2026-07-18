#!/usr/bin/env python3
"""Build the five deterministic matte-ceramic R1 material assets.

The alpha hull is a locked geometry input. Material light, low-frequency clay
variation, and fine mineral grain are baked once at build time so runtime R1
views only compose the asset, the rotating blind emboss, and contact shadows.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
MASK_PATH = ROOT / "tools" / "r1-material" / "r1-alpha-mask.png"
OUTPUTS = {
    "natural-white": (
        (230, 226, 222),
        ROOT / "App/Assets.xcassets/R1NaturalWhite.imageset/r1-natural-white.png",
    ),
    "terracotta": (
        (186, 123, 98),
        ROOT / "App/Assets.xcassets/R1Terracotta.imageset/r1-terracotta.png",
    ),
    "sage": (
        (135, 140, 123),
        ROOT / "App/Assets.xcassets/R1Sage.imageset/r1-sage.png",
    ),
    "slate": (
        (115, 116, 120),
        ROOT / "App/Assets.xcassets/R1Slate.imageset/r1-slate.png",
    ),
    "ochre": (
        (188, 140, 68),
        ROOT / "App/Assets.xcassets/R1Ochre.imageset/r1-ochre.png",
    ),
}

# Material-specific pressed-clay spectra. Natural white and terracotta are
# compact and fine, while sage and especially slate retain a dry mineral tooth.
# Keeping these amplitudes separate avoids one procedural skin across all R1.
TEXTURE_PROFILES = {
    "natural-white": (0.004, 0.010, 0.010),
    "terracotta": (0.005, 0.014, 0.016),
    "sage": (0.006, 0.036, 0.055),
    "slate": (0.008, 0.065, 0.098),
    "ochre": (0.005, 0.018, 0.020),
}

SIZE = 340
FACE_CENTER = (170.0, 164.0)
FACE_RADIUS = (146.5, 144.0)
WALL_BOTTOM = 328.0
KNURL_COUNT = 128


def noise_field(width: int, height: int, grid: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    field = Image.new("L", (grid, grid))
    field.putdata([rng.randrange(256) for _ in range(grid * grid)])
    return field.resize((width, height), Image.Resampling.BICUBIC)


def clamp_channel(value: float) -> int:
    return max(0, min(255, round(value)))


def cleaned_alpha(source: Image.Image) -> Image.Image:
    """Replace the old two-step fringe with one continuous antialias pixel."""
    solid = source.point(lambda value: 255 if value >= 128 else 0)
    support = source.point(lambda value: 255 if value > 0 else 0)
    softened = solid.filter(ImageFilter.GaussianBlur(radius=0.58))
    return ImageChops.multiply(softened, support)


def build_material(name: str, base: tuple[int, int, int], alpha: Image.Image) -> Image.Image:
    coarse = noise_field(SIZE, SIZE, 22, 1_441 + len(name) * 17)
    medium = noise_field(SIZE, SIZE, 72, 14_410 + len(name) * 31)
    fine = noise_field(SIZE, SIZE, 220, 144_100 + len(name) * 47)
    coarse_px = coarse.load()
    medium_px = medium.load()
    fine_px = fine.load()
    alpha_px = alpha.load()

    result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out = result.load()
    cx, cy = FACE_CENTER
    rx, ry = FACE_RADIUS
    coarse_weight, medium_weight, fine_weight = TEXTURE_PROFILES[name]

    for y in range(SIZE):
        for x in range(SIZE):
            opacity = alpha_px[x, y]
            if opacity == 0:
                continue

            nx = (x - cx) / rx
            ny = (y - cy) / ry
            radius = math.hypot(nx, ny)
            clay = (coarse_px[x, y] - 127.5) / 127.5
            mineral = (medium_px[x, y] - 127.5) / 127.5
            grain = (fine_px[x, y] - 127.5) / 127.5

            if radius <= 1.0:
                # Dense dry-pressed stoneware: restrained low-frequency body,
                # visible mineral grain and a narrow rolled shoulder. Broad
                # cloudy marbling reads as molded plastic at product size.
                directional = (-nx * 0.020) + (-ny * 0.030)
                face_falloff = -0.018 * max(0.0, radius - 0.28) ** 1.7
                shoulder = max(0.0, min(1.0, (radius - 0.940) / 0.060))
                bevel = -0.070 * shoulder ** 1.45
                texture = (
                    clay * coarse_weight
                    + mineral * medium_weight
                    + grain * fine_weight
                )

                # Fine radial rändelung belongs to the physical edge rather
                # than the UI emboss. The narrow dark cut and smaller trailing
                # counter-edge reproduce a machined 128-tooth perimeter.
                knurl_start = max(0.0, min(1.0, (radius - 0.815) / 0.015))
                knurl_end = 1.0 - max(0.0, min(1.0, (radius - 0.925) / 0.020))
                knurl_envelope = knurl_start * knurl_end
                # The pressed face may be mineral, but its precision-cut ring
                # remains optically crisp even on the rougher slate body.
                texture *= 1.0 - knurl_envelope * 0.65
                angle = math.atan2(ny, nx)
                tooth_phase = ((angle / math.tau) * KNURL_COUNT) % 1.0
                dark_cut = math.exp(-((tooth_phase - 0.42) / 0.13) ** 2)
                counter_edge = math.exp(-((tooth_phase - 0.67) / 0.11) ** 2)
                knurl_bed = -0.070 * knurl_envelope
                knurl = (knurl_bed - 0.180 * dark_cut + 0.018 * counter_edge) * knurl_envelope
                inner_edge = -0.055 * math.exp(-((radius - 0.795) / 0.012) ** 2)
                value = 0.965 + directional + face_falloff + bevel + texture + knurl + inner_edge
            else:
                # The 20-px wall is the projected 0.066-D body. Its upper edge
                # remains materially related to the face, then rolls into a
                # darker bottom seam without a flat plastic band.
                depth = max(0.0, min(1.0, (y - (cy + ry)) / (WALL_BOTTOM - (cy + ry))))
                banding = math.sin(y * 0.58 + x * 0.035) * 0.005
                texture = (
                    clay * coarse_weight * 0.80
                    + mineral * medium_weight * 0.55
                    + grain * fine_weight * 0.25
                    + banding
                )
                value = 0.82 - depth * 0.22 + texture

            out[x, y] = (
                clamp_channel(base[0] * value),
                clamp_channel(base[1] * value),
                clamp_channel(base[2] * value),
                opacity,
            )

    return result


def main() -> None:
    alpha = cleaned_alpha(Image.open(MASK_PATH).convert("L"))
    if alpha.size != (SIZE, SIZE):
        raise ValueError(f"R1 alpha mask must be {SIZE} x {SIZE}, got {alpha.size}")

    for name, (base, output) in OUTPUTS.items():
        output.parent.mkdir(parents=True, exist_ok=True)
        build_material(name, base, alpha).save(output, optimize=True)
        print(output.relative_to(ROOT))


if __name__ == "__main__":
    main()
