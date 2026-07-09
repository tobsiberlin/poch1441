#!/usr/bin/env python3
"""Geometry-correct PM1-inspired physical Poch board studies.

Purpose: stop relying on image models for the functional basin layout. These
renders prioritize exact physical geometry: 8 outer coin basins + 1 centered
middle basin with flat coin floors and subtle PM1-like material restraint.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/Users/tobsi/poch1441")
RAW = ROOT / "Assets_Raw" / "pochring" / "precision-monolith"
ART = ROOT / "artifacts" / "precision-monolith"
SIZE = 1024
CX = CY = SIZE // 2

GOLD = (192, 149, 70)
GOLD_SOFT = (152, 113, 54)
GARNET = (118, 34, 49)
EMERALD = (35, 117, 95)
AMETHYST = (83, 48, 122)
PLATINUM = (174, 180, 190)

POOLS = [
    ("K", GOLD),
    ("Q", GOLD_SOFT),
    ("MAR", GARNET),
    ("POCH", AMETHYST),
    ("SEQ", EMERALD),
    ("10", GOLD),
    ("J", GOLD_SOFT),
    ("A", GOLD),
]


def radial_points(radius: float, start: float = -90) -> list[tuple[float, float]]:
    return [
        (
            CX + math.cos(math.radians(start + i * 45)) * radius,
            CY + math.sin(math.radians(start + i * 45)) * radius,
        )
        for i in range(8)
    ]


def noise(size: int, seed: int, opacity: int) -> Image.Image:
    rnd = random.Random(seed)
    img = Image.new("L", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = rnd.randint(0, 255)
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    return Image.merge("RGBA", (img, img, img, Image.new("L", (size, size), opacity)))


def disc_gradient(seed: int) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (28, 30, 31, 255))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - CX, y - CY
            r = math.hypot(dx, dy) / 430
            light = max(0, 1 - r) * 18
            top = max(0, 1 - ((x - 610) ** 2 + (y - 170) ** 2) ** 0.5 / 620) * 28
            v = int(17 + light + top)
            px[x, y] = (v, v, min(34, v + 4), 255)
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([82, 82, 942, 942], fill=(0, 0, 0, 0), outline=(42, 39, 45, 190), width=3)
    img.alpha_composite(noise(SIZE, seed, 24))
    return img


def apply_disc_mask(img: Image.Image):
    mask = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse([82, 82, 942, 942], fill=255)
    bg = Image.new("RGBA", (SIZE, SIZE), (34, 36, 38, 255))
    bg.alpha_composite(noise(SIZE, 998, 12))
    img.putalpha(mask)
    bg.alpha_composite(img)
    return bg


def draw_pm1_surface(d: ImageDraw.ImageDraw, subtle: float):
    # Warm PM1-like outer catch, but not an emissive casino ring.
    alpha = int(112 * subtle)
    d.arc([88, 86, 936, 938], 196, 358, fill=(184, 128, 44, alpha), width=5)
    d.arc([90, 88, 934, 936], 0, 130, fill=(221, 199, 132, int(42 * subtle)), width=3)
    d.arc([108, 108, 916, 916], 205, 335, fill=(0, 0, 0, 70), width=12)
    d.arc([108, 108, 916, 916], 18, 145, fill=(98, 97, 106, 42), width=8)

    # Engraved black-on-black hints, kept away from basin rings.
    for i in range(8):
        a = math.radians(-90 + i * 45)
        x = CX + math.cos(a) * 378
        y = CY + math.sin(a) * 378
        tangent = a + math.pi / 2
        p1 = (x + math.cos(a) * 18, y + math.sin(a) * 18)
        p2 = (x + math.cos(tangent) * 38 - math.cos(a) * 12, y + math.sin(tangent) * 38 - math.sin(a) * 12)
        p3 = (x - math.cos(tangent) * 38 - math.cos(a) * 12, y - math.sin(tangent) * 38 - math.sin(a) * 12)
        d.line([p1, p2, p3, p1], fill=(5, 5, 7, 76), width=2)
        d.line([p1, p2], fill=(58, 57, 64, 42), width=1)


def draw_basin(
    img: Image.Image,
    center: tuple[float, float],
    radius: int,
    floor_radius: int,
    color: tuple[int, int, int],
    *,
    inlay_alpha: int,
    lip_width: int,
):
    x, y = center
    d = ImageDraw.Draw(img, "RGBA")
    outer = [x - radius, y - radius, x + radius, y + radius]
    floor = [x - floor_radius, y - floor_radius, x + floor_radius, y + floor_radius]

    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow, "RGBA")
    sd.ellipse([outer[0] - 5, outer[1] + 11, outer[2] + 5, outer[3] + 22], fill=(0, 0, 0, 170))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(10)))

    # Physical construction: thick graphite lip, steep wall, flat coin floor.
    d.ellipse(outer, fill=(5, 5, 8, 250), outline=(47, 46, 53, 230), width=8)
    wall = [outer[0] + 10, outer[1] + 10, outer[2] - 10, outer[3] - 10]
    d.ellipse(wall, fill=(12, 12, 16, 246))
    d.arc(wall, 205, 345, fill=(0, 0, 0, 150), width=18)
    d.arc(wall, 22, 150, fill=(132, 132, 140, 58), width=10)

    dark = tuple(max(0, int(c * 0.42)) for c in color)
    light = tuple(min(255, c + 28) for c in color)
    inlay = [outer[0] + 12, outer[1] + 12, outer[2] - 12, outer[3] - 12]
    d.ellipse(inlay, outline=(*dark, int(inlay_alpha * 0.55)), width=lip_width + 2)
    d.ellipse(inlay, outline=(*color, inlay_alpha), width=lip_width)
    d.arc(inlay, 28, 146, fill=(*light, int(inlay_alpha * 0.33)), width=max(1, lip_width - 1))

    d.ellipse(floor, fill=(14, 14, 18, 250))
    d.ellipse([floor[0] + 8, floor[1] + 8, floor[2] - 8, floor[3] - 8], fill=(18, 18, 22, 245))
    d.arc([floor[0] + 8, floor[1] + 8, floor[2] - 8, floor[3] - 8], 210, 340, fill=(0, 0, 0, 120), width=12)
    d.arc([floor[0] + 8, floor[1] + 8, floor[2] - 8, floor[3] - 8], 32, 142, fill=(96, 96, 104, 42), width=7)


def draw_center(img: Image.Image, radius: int, floor_radius: int, alpha: int):
    draw_basin(img, (CX, CY), radius, floor_radius, PLATINUM, inlay_alpha=alpha, lip_width=4)


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


def make(label: str, name: str, *, basin_r: int, floor_r: int, ring_r: int, center_r: int, center_floor: int, alpha: int, seed: int, subtle: float):
    img = disc_gradient(seed)
    img = apply_disc_mask(img)
    d = ImageDraw.Draw(img, "RGBA")
    draw_pm1_surface(d, subtle)

    # Inner guide is only material contour, not a functional ring.
    d.ellipse([CX - 164, CY - 164, CX + 164, CY + 164], outline=(7, 7, 10, 120), width=5)
    d.ellipse([CX - 178, CY - 178, CX + 178, CY + 178], outline=(82, 66, 38, 62), width=2)

    for (_, color), point in zip(POOLS, radial_points(ring_r)):
        draw_basin(img, point, basin_r, floor_r, color, inlay_alpha=alpha, lip_width=4)
    draw_center(img, center_r, center_floor, int(alpha * 0.72))
    save(label, name, img)


def main():
    make("PM41", "Real Mulden A", basin_r=98, floor_r=58, ring_r=304, center_r=132, center_floor=82, alpha=78, seed=144241, subtle=0.86)
    make("PM42", "Real Mulden B", basin_r=104, floor_r=64, ring_r=314, center_r=124, center_floor=78, alpha=68, seed=144242, subtle=0.76)
    make("PM43", "Real Mulden C", basin_r=100, floor_r=66, ring_r=320, center_r=118, center_floor=76, alpha=56, seed=144243, subtle=0.64)


if __name__ == "__main__":
    main()
