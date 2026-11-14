#!/usr/bin/env python3
"""Procedural Poch-ring variants with locked 8+center geometry.

These are controlled visual studies, not AI retakes. They keep the PM1/PM7
material direction while enforcing the functional Poch board layout:
8 outer basins plus one center pot.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/Users/tobsi/poch1441")
RAW = ROOT / "Assets_Raw" / "pochring" / "precision-monolith"
ART = ROOT / "artifacts" / "precision-monolith"

SIZE = 1024
CX = CY = SIZE // 2

GOLD = (190, 151, 76)
GOLD_DARK = (142, 105, 47)
GARNET = (118, 34, 50)
EMERALD = (32, 118, 93)
AMETHYST = (86, 47, 120)
PLATINUM = (180, 186, 194)

POOLS = [
    ("K", GOLD),
    ("Q", GOLD),
    ("MAR", GARNET),
    ("POCH", AMETHYST),
    ("SEQ", EMERALD),
    ("10", GOLD),
    ("J", GOLD),
    ("A", GOLD),
]


def radial_points(radius: float, count: int = 8, start: float = -90) -> list[tuple[float, float]]:
    return [
        (
            CX + math.cos(math.radians(start + i * 360 / count)) * radius,
            CY + math.sin(math.radians(start + i * 360 / count)) * radius,
        )
        for i in range(count)
    ]


def noise(size: int, opacity: int, seed: int) -> Image.Image:
    rnd = random.Random(seed)
    img = Image.new("L", (size, size), 0)
    px = img.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = rnd.randint(0, 255)
    img = img.filter(ImageFilter.GaussianBlur(0.55))
    alpha = Image.new("L", (size, size), opacity)
    return Image.merge("RGBA", (img, img, img, alpha))


def ellipse_mask(box: list[float], blur: float = 0) -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse(box, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(blur)) if blur else mask


def alpha_composite_masked(base: Image.Image, layer: Image.Image, mask: Image.Image):
    tmp = Image.new("RGBA", base.size, (0, 0, 0, 0))
    tmp.alpha_composite(layer)
    tmp.putalpha(ImageChops.multiply(tmp.getchannel("A"), mask))
    base.alpha_composite(tmp)


def draw_disc(draw: ImageDraw.ImageDraw, variant: str):
    outer = [92, 92, 932, 932]
    draw.ellipse(outer, fill=(16, 16, 20))
    draw.ellipse([116, 96, 908, 910], fill=(24, 24, 29))
    draw.ellipse([140, 122, 884, 884], fill=(19, 19, 24))

    if variant in {"pm1_a", "pm1_b", "pm1_c"}:
        # PM1 keeps a warm external material catch, but not a casino glow.
        edge = (170, 125, 52, 115 if variant != "pm1_c" else 78)
        draw.arc([96, 94, 928, 930], 196, 359, fill=edge, width=5)
        draw.arc([96, 94, 928, 930], 0, 128, fill=(210, 185, 120, 48), width=3)
        for i in range(8):
            a = math.radians(-90 + i * 45)
            x = CX + math.cos(a) * 345
            y = CY + math.sin(a) * 345
            draw.polygon(
                [
                    (x + math.cos(a) * 22, y + math.sin(a) * 22),
                    (x + math.cos(a + 0.22) * 48, y + math.sin(a + 0.22) * 48),
                    (x + math.cos(a - 0.22) * 48, y + math.sin(a - 0.22) * 48),
                ],
                outline=(42, 41, 48, 96),
            )
    else:
        draw.ellipse(outer, outline=(55, 54, 62, 140), width=4)
        draw.arc([100, 98, 924, 930], 206, 335, fill=(96, 96, 104, 70), width=4)


def draw_basin(
    img: Image.Image,
    center: tuple[float, float],
    radius: int,
    ring_color: tuple[int, int, int],
    *,
    ring_width: int,
    metal: bool,
    strength: float,
    seed: int,
):
    x, y = center
    d = ImageDraw.Draw(img, "RGBA")
    box = [x - radius, y - radius, x + radius, y + radius]

    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow, "RGBA")
    sd.ellipse([box[0] - 6, box[1] + 8, box[2] + 6, box[3] + 18], fill=(0, 0, 0, 175))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(12)))

    d.ellipse(box, fill=(4, 4, 7, 235), outline=(46, 45, 52, 220), width=9)
    d.arc([box[0] + 8, box[1] + 7, box[2] - 8, box[3] - 7], 200, 345, fill=(0, 0, 0, 190), width=12)
    d.arc([box[0] + 10, box[1] + 10, box[2] - 10, box[3] - 10], 20, 148, fill=(138, 138, 146, 78), width=9)

    inset = 16
    inner = [box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset]
    if metal:
        base = tuple(max(0, int(c * 0.54)) for c in ring_color)
        d.ellipse(inner, fill=(*base, int(120 * strength)))
        d.arc(inner, 215, 355, fill=(0, 0, 0, 118), width=18)
        d.arc(inner, 24, 145, fill=(*tuple(min(255, int(c * 1.2)) for c in ring_color), int(78 * strength)), width=13)
        d.ellipse(
            [inner[0] + 18, inner[1] + 17, inner[2] - 18, inner[3] - 17],
            outline=(*ring_color, int(92 * strength)),
            width=ring_width,
        )
    else:
        d.ellipse(inner, fill=(9, 9, 12, 238))
        d.arc([inner[0] + 2, inner[1] + 2, inner[2] - 2, inner[3] - 2], 198, 340, fill=(0, 0, 0, 156), width=16)
        d.arc([inner[0] + 4, inner[1] + 4, inner[2] - 4, inner[3] - 4], 28, 148, fill=(118, 118, 128, 58), width=12)

    # The color belongs to the basin lip, so use the same geometry as the inner
    # bevel. No separate radial overlay can drift away from the pocket.
    lip = [box[0] + 10, box[1] + 10, box[2] - 10, box[3] - 10]
    dark = tuple(max(0, int(c * 0.34)) for c in ring_color)
    d.ellipse(lip, outline=(*dark, int(110 * strength)), width=ring_width + 4)
    d.ellipse(lip, outline=(*ring_color, int(120 * strength)), width=ring_width)
    d.arc(lip, 28, 148, fill=(*tuple(min(255, c + 34) for c in ring_color), int(74 * strength)), width=max(1, ring_width - 2))

    if seed % 2 == 0:
        grain = noise(SIZE, 12, seed)
        mask = ellipse_mask(inner, 0)
        alpha_composite_masked(img, grain, mask)


def draw_center(img: Image.Image, variant: str, metal: bool):
    d = ImageDraw.Draw(img, "RGBA")
    radius = 138 if variant != "pm1_c" else 126
    box = [CX - radius, CY - radius, CX + radius, CY + radius]
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow, "RGBA")
    sd.ellipse([box[0] - 4, box[1] + 10, box[2] + 4, box[3] + 18], fill=(0, 0, 0, 188))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))

    d.ellipse(box, fill=(5, 5, 8, 236), outline=(42, 42, 50, 230), width=13)
    inner = [box[0] + 18, box[1] + 18, box[2] - 18, box[3] - 18]
    fill = (15, 15, 19, 238) if not metal else (18, 19, 22, 238)
    d.ellipse(inner, fill=fill)
    d.arc(inner, 210, 344, fill=(0, 0, 0, 170), width=22)
    d.arc(inner, 25, 152, fill=(126, 128, 136, 62), width=15)
    d.ellipse([box[0] + 11, box[1] + 11, box[2] - 11, box[3] - 11], outline=(*PLATINUM, 84), width=5)
    d.arc([box[0] + 11, box[1] + 11, box[2] - 11, box[3] - 11], 25, 146, fill=(230, 234, 240, 70), width=4)


def make_variant(label: str, name: str, variant: str, *, metal: bool, ring_width: int, strength: float, basin_radius: int, body_seed: int):
    img = Image.new("RGBA", (SIZE, SIZE), (28, 30, 32, 255))
    bg = Image.new("RGBA", (SIZE, SIZE), (34, 36, 39, 255))
    bg.alpha_composite(noise(SIZE, 18, body_seed))
    img = bg

    d = ImageDraw.Draw(img, "RGBA")
    draw_disc(d, variant)

    disc_mask = ellipse_mask([92, 92, 932, 932], 0)
    texture = noise(SIZE, 22 if not metal else 15, body_seed + 10)
    alpha_composite_masked(img, texture, disc_mask)

    points = radial_points(306 if basin_radius >= 86 else 300)
    for index, ((_, color), point) in enumerate(zip(POOLS, points)):
        draw_basin(
            img,
            point,
            basin_radius,
            color if not metal else metal_tone(color, index),
            ring_width=ring_width,
            metal=metal,
            strength=strength,
            seed=body_seed + index,
        )

    draw_center(img, variant, metal=metal)
    save(label, name, img)


def metal_tone(color: tuple[int, int, int], index: int) -> tuple[int, int, int]:
    if color == GOLD:
        tones = [(164, 124, 59), (182, 139, 69), (152, 116, 62), (173, 134, 72), (146, 112, 58)]
        return tones[index % len(tones)]
    return {
        GARNET: (128, 45, 59),
        EMERALD: (41, 124, 98),
        AMETHYST: (91, 59, 128),
    }.get(color, color)


def label_image(src: Image.Image, label: str, name: str) -> Image.Image:
    img = src.convert("RGB")
    img.thumbnail((1000, 1000), Image.Resampling.LANCZOS)
    pad = 78
    out = Image.new("RGB", (img.width, img.height + pad), (10, 8, 12))
    out.paste(img, (0, pad))
    draw = ImageDraw.Draw(out)
    try:
        font_big = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 30)
        font_small = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 20)
    except OSError:
        font_big = ImageFont.load_default()
        font_small = ImageFont.load_default()
    draw.text((18, 14), label, fill=(226, 232, 240), font=font_big)
    draw.text((120, 20), name, fill=GOLD, font=font_small)
    return out


def save(label: str, name: str, img: Image.Image):
    RAW.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    raw_path = RAW / f"{label}.png"
    art_path = ART / f"{label}.png"
    img.convert("RGB").save(raw_path, quality=95)
    label_image(img, label, name).save(art_path, quality=95)
    print("RAW:", raw_path)
    print("ART:", art_path)


def main():
    make_variant("PM13", "PM1 Geometry Fix", "pm1_a", metal=False, ring_width=5, strength=0.58, basin_radius=88, body_seed=144213)
    make_variant("PM17", "PM1 Centerpot A", "pm1_a", metal=False, ring_width=4, strength=0.50, basin_radius=87, body_seed=144217)
    make_variant("PM18", "PM1 Centerpot B", "pm1_b", metal=False, ring_width=6, strength=0.64, basin_radius=90, body_seed=144218)
    make_variant("PM19", "PM1 Centerpot C", "pm1_c", metal=False, ring_width=4, strength=0.44, basin_radius=84, body_seed=144219)
    make_variant("PM20", "PM7 Metal Mulden A", "pm7_a", metal=True, ring_width=4, strength=0.54, basin_radius=87, body_seed=144220)
    make_variant("PM21", "PM7 Metal Mulden B", "pm7_b", metal=True, ring_width=5, strength=0.64, basin_radius=90, body_seed=144221)
    make_variant("PM22", "PM7 Metal Mulden C", "pm7_c", metal=True, ring_width=4, strength=0.48, basin_radius=84, body_seed=144222)


if __name__ == "__main__":
    main()
