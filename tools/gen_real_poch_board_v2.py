#!/usr/bin/env python3
"""Improved geometry-locked Poch board renders.

These studies deliberately trade AI beauty for correct structure. They use
smooth supersampled procedural rendering so the result is less "flat vector"
than PM41-PM43 while keeping exact 8+center geometry.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/Users/tobsi/poch1441")
RAW = ROOT / "Assets_Raw" / "pochring" / "precision-monolith"
ART = ROOT / "artifacts" / "precision-monolith"

S = 2
SIZE = 1024
W = SIZE * S
CX = CY = W // 2

GOLD = (188, 143, 62)
GOLD_DIM = (146, 108, 50)
GARNET = (128, 34, 49)
EMERALD = (31, 124, 98)
AMETHYST = (86, 48, 123)
PLATINUM = (170, 176, 186)

POOLS = [GOLD, GOLD_DIM, GARNET, AMETHYST, EMERALD, GOLD, GOLD_DIM, GOLD]


def sc(v: float) -> int:
    return int(round(v * S))


def radial_points(radius: float) -> list[tuple[int, int]]:
    return [
        (int(CX + math.cos(math.radians(-90 + i * 45)) * sc(radius)),
         int(CY + math.sin(math.radians(-90 + i * 45)) * sc(radius)))
        for i in range(8)
    ]


def base_canvas(seed: int, warmth: float) -> Image.Image:
    rnd = random.Random(seed)
    img = Image.new("RGBA", (W, W), (8, 8, 10, 255))
    pix = img.load()
    for y in range(W):
        for x in range(W):
            dx = (x - CX) / sc(430)
            dy = (y - CY) / sc(430)
            r = math.hypot(dx, dy)
            if r > 1:
                pix[x, y] = (28, 30, 31, 255)
                continue
            top_light = max(0, 1 - math.hypot((x - sc(660)) / sc(680), (y - sc(110)) / sc(680))) * 20
            center = max(0, 1 - r) * 10
            grain = rnd.randint(-5, 5)
            v = int(16 + top_light + center + grain)
            warm = int(warmth * max(0, 1 - math.hypot((x - sc(180)) / sc(620), (y - sc(880)) / sc(420))) * 9)
            pix[x, y] = (max(0, v + warm), max(0, v + warm // 2), min(40, v + 4), 255)
    mask = Image.new("L", (W, W), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([sc(78), sc(78), sc(946), sc(946)], fill=255)
    bg = Image.new("RGBA", (W, W), (31, 33, 34, 255))
    img.putalpha(mask)
    bg.alpha_composite(img)
    return bg


def draw_ellipse_shadow(img: Image.Image, box: list[int], opacity: int, blur: int, dy: int):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer, "RGBA")
    d.ellipse([box[0], box[1] + dy, box[2], box[3] + dy], fill=(0, 0, 0, opacity))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def draw_ring_contours(img: Image.Image, warmth: float):
    d = ImageDraw.Draw(img, "RGBA")
    outer = [sc(80), sc(80), sc(944), sc(944)]
    d.ellipse(outer, outline=(46, 43, 48, 170), width=sc(3))
    d.arc(outer, 196, 358, fill=(190, 128, 42, int(105 * warmth)), width=sc(4))
    d.arc([sc(84), sc(84), sc(940), sc(940)], 0, 130, fill=(222, 205, 146, int(34 * warmth)), width=sc(2))
    d.arc([sc(118), sc(118), sc(906), sc(906)], 205, 336, fill=(0, 0, 0, 105), width=sc(8))
    d.arc([sc(118), sc(118), sc(906), sc(906)], 22, 145, fill=(112, 112, 120, 42), width=sc(5))

    for i in range(8):
        a = math.radians(-90 + i * 45)
        x = CX + math.cos(a) * sc(374)
        y = CY + math.sin(a) * sc(374)
        t = a + math.pi / 2
        pts = [
            (x + math.cos(a) * sc(18), y + math.sin(a) * sc(18)),
            (x + math.cos(t) * sc(36) - math.cos(a) * sc(10), y + math.sin(t) * sc(36) - math.sin(a) * sc(10)),
            (x - math.cos(t) * sc(36) - math.cos(a) * sc(10), y - math.sin(t) * sc(36) - math.sin(a) * sc(10)),
        ]
        d.line(pts + [pts[0]], fill=(3, 3, 5, 88), width=sc(2))
        d.line([pts[0], pts[1]], fill=(58, 57, 64, 34), width=sc(1))


def basin_gradient(radius: int, floor_radius: int, color: tuple[int, int, int], inlay_alpha: int, lip_width: int) -> Image.Image:
    r = sc(radius)
    fr = sc(floor_radius)
    pad = sc(18)
    size = (r + pad) * 2
    cx = cy = size // 2
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pix = img.load()
    for y in range(size):
        for x in range(size):
            dx = x - cx
            dy = y - cy
            dist = math.hypot(dx, dy)
            if dist > r:
                continue
            # Lip/wall/floor zones.
            if dist > r - sc(12):
                v = 34 - int((dist - (r - sc(12))) / sc(12) * 15)
            elif dist > fr:
                wall_t = (dist - fr) / max(1, (r - sc(12) - fr))
                v = int(8 + wall_t * 21)
            else:
                floor_t = dist / max(1, fr)
                v = int(13 + (1 - floor_t) * 8)
            highlight = max(0, 1 - math.hypot((x - cx - sc(26)) / sc(86), (y - cy + sc(36)) / sc(82))) * 35
            shade = max(0, 1 - math.hypot((x - cx + sc(36)) / sc(86), (y - cy - sc(38)) / sc(82))) * 18
            vv = max(0, min(58, int(v + highlight - shade)))
            pix[x, y] = (vv, vv, min(66, vv + 5), 255)

    d = ImageDraw.Draw(img, "RGBA")
    outer = [cx - r, cy - r, cx + r, cy + r]
    floor = [cx - fr, cy - fr, cx + fr, cy + fr]
    d.ellipse(outer, outline=(56, 55, 62, 225), width=sc(6))
    d.arc([outer[0] + sc(8), outer[1] + sc(8), outer[2] - sc(8), outer[3] - sc(8)], 25, 148,
          fill=(136, 136, 144, 58), width=sc(7))
    d.arc([outer[0] + sc(8), outer[1] + sc(8), outer[2] - sc(8), outer[3] - sc(8)], 205, 345,
          fill=(0, 0, 0, 115), width=sc(11))
    dark = tuple(max(0, int(c * 0.42)) for c in color)
    light = tuple(min(255, c + 28) for c in color)
    inlay = [outer[0] + sc(11), outer[1] + sc(11), outer[2] - sc(11), outer[3] - sc(11)]
    d.ellipse(inlay, outline=(*dark, int(inlay_alpha * 0.6)), width=sc(lip_width + 1))
    d.ellipse(inlay, outline=(*color, inlay_alpha), width=sc(lip_width))
    d.arc(inlay, 28, 146, fill=(*light, int(inlay_alpha * 0.28)), width=sc(max(1, lip_width - 1)))
    d.ellipse(floor, outline=(4, 4, 6, 130), width=sc(5))
    d.ellipse([floor[0] + sc(6), floor[1] + sc(6), floor[2] - sc(6), floor[3] - sc(6)],
              outline=(88, 88, 96, 40), width=sc(2))
    return img


def paste_basin(img: Image.Image, center: tuple[int, int], radius: int, floor_radius: int, color, alpha: int, lip_width: int):
    x, y = center
    box = [x - sc(radius), y - sc(radius), x + sc(radius), y + sc(radius)]
    draw_ellipse_shadow(img, box, opacity=118, blur=sc(10), dy=sc(12))
    basin = basin_gradient(radius, floor_radius, color, alpha, lip_width)
    img.alpha_composite(basin, (x - basin.width // 2, y - basin.height // 2))


def label_image(src: Image.Image, label: str, name: str) -> Image.Image:
    img = src.resize((1000, 1000), Image.Resampling.LANCZOS).convert("RGB")
    pad = 78
    out = Image.new("RGB", (1000, 1000 + pad), (10, 8, 12))
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
    img = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    RAW.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    raw = RAW / f"{label}.png"
    art = ART / f"{label}.png"
    img.convert("RGB").save(raw, quality=95)
    label_image(img, label, name).save(art, quality=95)
    print("RAW:", raw)
    print("ART:", art)


def make(label: str, name: str, *, ring_radius: int, basin_r: int, floor_r: int, center_r: int, center_floor: int, alpha: int, warmth: float, seed: int):
    img = base_canvas(seed, warmth)
    draw_ring_contours(img, warmth)
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([CX - sc(164), CY - sc(164), CX + sc(164), CY + sc(164)], outline=(5, 5, 8, 110), width=sc(4))
    d.ellipse([CX - sc(178), CY - sc(178), CX + sc(178), CY + sc(178)], outline=(92, 70, 34, 45), width=sc(1))
    for color, point in zip(POOLS, radial_points(ring_radius)):
        paste_basin(img, point, basin_r, floor_r, color, alpha, lip_width=3)
    paste_basin(img, (CX, CY), center_r, center_floor, PLATINUM, int(alpha * 0.72), lip_width=3)
    save(label, name, img)


def main():
    make("PM44", "Real Graphite A", ring_radius=314, basin_r=96, floor_r=57, center_r=128, center_floor=78, alpha=92, warmth=0.86, seed=144244)
    make("PM45", "Real Graphite B", ring_radius=322, basin_r=100, floor_r=62, center_r=122, center_floor=76, alpha=78, warmth=0.78, seed=144245)
    make("PM46", "Real Graphite C", ring_radius=326, basin_r=96, floor_r=64, center_r=116, center_floor=74, alpha=66, warmth=0.70, seed=144246)


if __name__ == "__main__":
    main()
