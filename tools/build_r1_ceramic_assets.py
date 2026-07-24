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

from PIL import Image, ImageChops, ImageDraw, ImageFilter


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

KNURL_BED_OFFSETS = {
    "natural-white": 0.009,
    "terracotta": -0.030,
    "sage": -0.013,
    "slate": -0.050,
    "ochre": -0.025,
}

# Blind emboss response is material-dependent. The darker bodies need the
# accepted full relief to survive product-scale projection. Natural white
# receives a shallower groove so its high albedo cannot read as grey ink.
SIGNET_RELIEF_PROFILES = {
    "natural-white": (0.155, 0.200, 0.080),
    "terracotta": (0.300, 0.220, 0.380),
    "sage": (0.300, 0.220, 0.380),
    "slate": (0.300, 0.220, 0.380),
    "ochre": (0.300, 0.220, 0.380),
}

SIZE = 340
FACE_CENTER = (170.0, 164.0)
FACE_RADIUS = (146.5, 144.0)
FACE_BOTTOM = int(FACE_CENTER[1] + FACE_RADIUS[1])
SOURCE_WALL_BOTTOM = 328
WALL_BOTTOM = 338.0
KNURL_COUNT = 128
SIGNET_CENTER = (170.0, 157.5)
SIGNET_BBOX = 150.0
SIGNET_STROKE = 5


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


def taller_alpha(source: Image.Image) -> Image.Image:
    """Extend only the projected ceramic wall; the circular face is untouched."""
    cleaned = cleaned_alpha(source)
    wall = cleaned.crop((0, FACE_BOTTOM, SIZE, SOURCE_WALL_BOTTOM)).resize(
        (SIZE, int(WALL_BOTTOM) - FACE_BOTTOM),
        Image.Resampling.LANCZOS,
    )
    result = Image.new("L", (SIZE, SIZE), 0)
    result.paste(cleaned.crop((0, 0, SIZE, FACE_BOTTOM)), (0, 0))
    result.paste(wall, (0, FACE_BOTTOM))
    return result


def shifted(mask: Image.Image, x: int, y: int) -> Image.Image:
    result = Image.new("L", mask.size, 0)
    result.paste(mask, (x, y))
    return result


def signet_relief_fields() -> tuple[Image.Image, Image.Image, Image.Image]:
    """Build a narrow deboss with a world-lit upper edge, never printed ink."""
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)
    half = SIGNET_BBOX / 2
    left = SIGNET_CENTER[0] - half
    top = SIGNET_CENTER[1] - half

    def point(x: float, y: float) -> tuple[int, int]:
        return (round(left + SIGNET_BBOX * x), round(top + SIGNET_BBOX * y))

    def line(points: list[tuple[float, float]], closed: bool = False) -> None:
        resolved = [point(x, y) for x, y in points]
        if closed:
            resolved.append(resolved[0])
        draw.line(resolved, fill=255, width=SIGNET_STROKE, joint="curve")

    # Faceted W2 mark from the accepted precision-rändelung reference.
    line([(0.50, 0.02), (0.98, 0.50), (0.50, 0.98), (0.02, 0.50)], True)
    line([(0.02, 0.50), (0.28, 0.27), (0.28, 0.73), (0.02, 0.50)])
    line([(0.98, 0.50), (0.72, 0.27), (0.72, 0.73), (0.98, 0.50)])
    line([(0.50, 0.02), (0.28, 0.27)])
    line([(0.50, 0.02), (0.72, 0.27)])
    line([(0.50, 0.98), (0.28, 0.73)])
    line([(0.50, 0.98), (0.72, 0.73)])
    line([(0.50, 0.02), (0.35, 0.43), (0.65, 0.43), (0.50, 0.02)])
    line([(0.35, 0.43), (0.50, 0.58), (0.65, 0.43)])
    line([(0.35, 0.63), (0.65, 0.63)])
    line([(0.35, 0.63), (0.50, 0.98), (0.65, 0.63)])

    groove = mask.filter(ImageFilter.GaussianBlur(radius=0.45))
    highlight = shifted(groove, -2, -2)
    dark_wall = shifted(groove, 2, 2)
    return groove, highlight, dark_wall


def build_material(name: str, base: tuple[int, int, int], alpha: Image.Image) -> Image.Image:
    coarse = noise_field(SIZE, SIZE, 22, 1_441 + len(name) * 17)
    medium = noise_field(SIZE, SIZE, 72, 14_410 + len(name) * 31)
    fine = noise_field(SIZE, SIZE, 220, 144_100 + len(name) * 47)
    coarse_px = coarse.load()
    medium_px = medium.load()
    fine_px = fine.load()
    alpha_px = alpha.load()
    groove, relief_highlight, relief_dark_wall = signet_relief_fields()
    groove_px = groove.load()
    relief_highlight_px = relief_highlight.load()
    relief_dark_wall_px = relief_dark_wall.load()
    relief_highlight_strength, relief_wall_strength, relief_groove_strength = (
        SIGNET_RELIEF_PROFILES[name]
    )

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
                directional = (-nx * 0.035) + (-ny * 0.055)
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
                phase_warp = (
                    0.018 * math.sin(angle * 9.0 + 0.4)
                    + 0.010 * math.sin(angle * 17.0 - 0.7)
                )
                tooth_phase = ((angle / math.tau) * KNURL_COUNT + phase_warp) % 1.0
                tooth_strength = (
                    1.0
                    + 0.080 * math.sin(angle * 5.0 + 0.9)
                    + 0.045 * math.sin(angle * 11.0 - 0.3)
                )
                knurl_bed = KNURL_BED_OFFSETS[name] * knurl_envelope
                # A paired full-period cut survives the 106-px gameplay
                # projection. The rejected subpixel Gaussian notch averaged
                # into a pale plastic band despite being visible at 340 px.
                dark_edge = -0.440 * math.cos(math.tau * (tooth_phase - 0.42))
                counter_edge = 0.140 * math.cos(2.0 * math.tau * (tooth_phase - 0.67))
                knurl = (
                    knurl_bed + (dark_edge + counter_edge) * tooth_strength
                ) * knurl_envelope
                inner_edge = -0.055 * math.exp(-((radius - 0.795) / 0.012) ** 2)
                # A blind emboss is read from paired edge lighting. Natural
                # white keeps a restrained groove body; darker materials use
                # the accepted deeper response that survives gameplay scale.
                relief = (
                    relief_highlight_px[x, y] / 255 * relief_highlight_strength
                    - relief_dark_wall_px[x, y] / 255 * relief_wall_strength
                    - groove_px[x, y] / 255 * relief_groove_strength
                )
                value = (
                    0.965 + directional + face_falloff + bevel
                    + texture + knurl + inner_edge + relief
                )
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
                bottom_lip = max(0.0, min(1.0, (depth - 0.56) / 0.44))
                value = (
                    0.87 - depth * 0.35
                    + bottom_lip ** 1.35 * 0.35
                    + texture
                )

            out[x, y] = (
                clamp_channel(base[0] * value),
                clamp_channel(base[1] * value),
                clamp_channel(base[2] * value),
                opacity,
            )

    return result


def main() -> None:
    alpha = taller_alpha(Image.open(MASK_PATH).convert("L"))
    if alpha.size != (SIZE, SIZE):
        raise ValueError(f"R1 alpha mask must be {SIZE} x {SIZE}, got {alpha.size}")

    for name, (base, output) in OUTPUTS.items():
        output.parent.mkdir(parents=True, exist_ok=True)
        build_material(name, base, alpha).save(output, optimize=True)
        print(output.relative_to(ROOT))


if __name__ == "__main__":
    main()
