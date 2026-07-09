#!/usr/bin/env python3
"""Poch 1441 card fronts from Public Domain vector-playing-cards SVGs.

No AI, no generated sheet slicing. Each court card is rendered from its own SVG.
The standard deck is restyled for the app:
- pure white card stock
- quiet court palette: yellow -> matte gold, blue -> graphite/navy
- original vector layout and indices are preserved to avoid overpaint artifacts
- no second-pass value/suit labels are drawn over the SVG cards
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "Assets_Raw" / "vector-playing-cards" / "cards-svg"
OUT_MASTER = ROOT / "Assets_Raw" / "cards" / "final"
CATALOG = ROOT / "App" / "Assets.xcassets" / "Cards"

W, H = 624, 888
SS = 2
CORNER_R = 96

PAPER = (255, 255, 255, 255)
RED = (204, 35, 52, 255)
BLACK = (0, 0, 0, 255)
GOLD = (184, 141, 52, 255)
NAVY = (42, 58, 82, 255)
GRAPHITE = (32, 30, 38, 255)

RANKS = [
    ("A", "ace"),
    ("K", "king"),
    ("Q", "queen"),
    ("J", "jack"),
    ("10", "ten"),
    ("9", "nine"),
    ("8", "eight"),
    ("7", "seven"),
]
SUITS = [
    ("S", "spades", "Pik"),
    ("H", "hearts", "Herz"),
    ("C", "clubs", "Kreuz"),
    ("D", "diamonds", "Karo"),
]
COURTS = {"K", "Q", "J"}

_STOCK_TEXTURE: np.ndarray | None = None

CARD_CODE = {
    "A": "A",
    "K": "K",
    "Q": "Q",
    "J": "J",
    "10": "10",
    "9": "9",
    "8": "8",
    "7": "7",
}


def restyle_svg(text: str) -> str:
    # Remove the source deck's own white rounded card body. We draw the final
    # Poch card stock ourselves, otherwise padding creates a visible
    # card-inside-card border.
    text = re.sub(
        r'\s*<path\s+style="fill:#FFFFFF;stroke-width:0\.5;"\s+d="M166\.8369141.*?id="path5"\s*/>',
        "",
        text,
        count=1,
        flags=re.S,
    )
    replacements = {
        "#e2d200": "#B88D34",
        "#dcd00f": "#B88D34",
        "#1156a1": "#2A3A52",
        "#5e95bc": "#526D86",
        "#df0000": "#D93650",
        "#000400": "#201E26",
        "#666666": "#C9CDD3",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    # App-readable corner typography without drawing a second label over the card.
    # The source deck uses thin Arial-like text; keep positions and suit pips, but
    # make the existing text larger/bolder before rendering.
    text = re.sub(r"font-size:29\.22270203px", "font-size:34px", text)
    text = re.sub(r"font-size:32px", "font-size:36px", text)
    text = text.replace("font-weight:normal", "font-weight:bold")
    text = text.replace("font-family:Bitstream Vera Sans", "font-family:Helvetica Neue, Arial, sans-serif")
    text = text.replace("font-family:Arial", "font-family:Helvetica Neue, Arial, sans-serif")
    text = text.replace("-inkscape-font-specification:Arial", "-inkscape-font-specification:Helvetica Neue Bold")
    return text


def render_svg(svg_path: Path, tmpdir: Path) -> Image.Image:
    styled = tmpdir / svg_path.name
    styled.write_text(restyle_svg(svg_path.read_text()), encoding="utf-8")
    raw = tmpdir / f"{svg_path.stem}.png"
    subprocess.run(["rsvg-convert", "-w", str(W * SS), "-o", str(raw), str(styled)],
                   check=True, capture_output=True)
    im = Image.open(raw).convert("RGBA")
    # Fit source ratio into our established 52:74 card format without changing app layout.
    scale = max(W * SS / im.width, H * SS / im.height)
    resized = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    left = (resized.width - W * SS) // 2
    top = (resized.height - H * SS) // 2
    return resized.crop((left, top, left + W * SS, top + H * SS))


def draw_suit_symbol(size: int, suit: str, color: tuple[int, int, int, int]) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size
    cx = s / 2
    if suit == "H":
        d.ellipse([0.12*s, 0.08*s, 0.52*s, 0.48*s], fill=color)
        d.ellipse([0.48*s, 0.08*s, 0.88*s, 0.48*s], fill=color)
        d.polygon([(0.10*s, 0.32*s), (0.90*s, 0.32*s), (cx, 0.95*s)], fill=color)
    elif suit == "D":
        d.polygon([(cx, 0.04*s), (0.92*s, cx), (cx, 0.96*s), (0.08*s, cx)], fill=color)
    elif suit == "S":
        d.ellipse([0.12*s, 0.32*s, 0.52*s, 0.72*s], fill=color)
        d.ellipse([0.48*s, 0.32*s, 0.88*s, 0.72*s], fill=color)
        d.polygon([(0.10*s, 0.50*s), (0.90*s, 0.50*s), (cx, 0.02*s)], fill=color)
        d.polygon([(0.39*s, 0.66*s), (0.61*s, 0.66*s), (0.72*s, 0.94*s), (0.28*s, 0.94*s)], fill=color)
    else:
        d.ellipse([0.30*s, 0.02*s, 0.70*s, 0.42*s], fill=color)
        d.ellipse([0.08*s, 0.34*s, 0.48*s, 0.74*s], fill=color)
        d.ellipse([0.52*s, 0.34*s, 0.92*s, 0.74*s], fill=color)
        d.polygon([(0.39*s, 0.58*s), (0.61*s, 0.58*s), (0.74*s, 0.95*s), (0.26*s, 0.95*s)], fill=color)
    return im.filter(ImageFilter.GaussianBlur(0.12))


def rounded_card() -> Image.Image:
    im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, W * SS - 1, H * SS - 1], radius=CORNER_R * SS,
                        fill=PAPER, outline=(210, 214, 220, 255), width=1 * SS)
    return im


def premium_stock_finish(card: Image.Image) -> Image.Image:
    """Subtle premium white stock: linen grain, air-cushion dimples and curvature.

    This encodes the texture direction in a deterministic way. The visual card
    remains pure white at read distance; the finish only appears as micro
    variation under the app's dark UI.
    """
    global _STOCK_TEXTURE
    if _STOCK_TEXTURE is None:
        rng = np.random.default_rng(1441)
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        nx = (xx / (W - 1)) * 2 - 1
        ny = (yy / (H - 1)) * 2 - 1

        linen = (
            np.sin(xx * 2 * np.pi / 9.0) * 0.45 +
            np.sin(yy * 2 * np.pi / 7.0) * 0.45
        )
        dimples = (
            np.sin(xx * 2 * np.pi / 18.0) *
            np.sin(yy * 2 * np.pi / 18.0)
        ) * 0.55
        noise = rng.normal(0.0, 0.45, (H, W)).astype(np.float32)

        # Very mild top-left illumination and edge curvature.
        curvature = 1.0 - 0.018 * (nx * nx + ny * ny) + 0.012 * (-0.55 * nx - 0.75 * ny)
        micro = (linen + dimples + noise) / 255.0
        _STOCK_TEXTURE = np.clip(curvature + micro, 0.94, 1.035)[:, :, None]

    rgba = np.asarray(card, dtype=np.float32)
    alpha = rgba[:, :, 3:4] / 255.0
    whiteish = rgba[:, :, :3].mean(axis=2, keepdims=True) > 238
    rgba[:, :, :3] = np.where(
        whiteish,
        np.clip(rgba[:, :, :3] * _STOCK_TEXTURE, 0, 255),
        rgba[:, :, :3],
    )
    rgba[:, :, :3] = rgba[:, :, :3] * alpha + 255 * (1 - alpha)
    rgba[:, :, 3] = np.asarray(card)[:, :, 3]
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8))


def boost_red_ace_mark(card: Image.Image, suit: str) -> Image.Image:
    """Keep the original ace artwork, but remove the washed-out red-card look.

    The public-domain red aces use soft gradients. On our white premium stock
    that reads too pale, while the other red number cards are fine. This boosts
    only the central red ace mark area and leaves corner indices/layout intact.
    """
    if suit not in {"H", "D"}:
        return card
    arr = np.asarray(card, dtype=np.float32)
    yy, xx = np.mgrid[0:arr.shape[0], 0:arr.shape[1]]
    cx, cy = arr.shape[1] / 2, arr.shape[0] / 2
    central = ((xx - cx) / (arr.shape[1] * 0.34)) ** 2 + ((yy - cy) / (arr.shape[0] * 0.28)) ** 2 < 1.0
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    redish = (r > g * 1.08) & (r > b * 1.08) & (r > 130)
    mask = central & redish
    target = np.array([217, 54, 80], dtype=np.float32)
    arr[:, :, :3][mask] = arr[:, :, :3][mask] * 0.35 + target * 0.65
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def index_tile(rank: str, suit: str, font: ImageFont.FreeTypeFont,
               ten_font: ImageFont.FreeTypeFont, pip_size: int) -> Image.Image:
    color = RED if suit in {"H", "D"} else BLACK
    active = ten_font if rank == "10" else font
    bbox = active.getbbox(rank)
    letter = Image.new("RGBA", (bbox[2] - bbox[0], bbox[3] - bbox[1]), (0, 0, 0, 0))
    ImageDraw.Draw(letter).text((-bbox[0], -bbox[1]), rank, fill=color, font=active)
    if rank == "10":
        letter = letter.resize((round(letter.width * 0.80), letter.height), Image.LANCZOS)
    pip = draw_suit_symbol(pip_size * SS, suit, color)
    w = max(letter.width, pip.width)
    h = letter.height + 12 * SS + pip.height
    tile = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tile.alpha_composite(letter, ((w - letter.width) // 2, 0))
    tile.alpha_composite(pip, ((w - pip.width) // 2, letter.height + 12 * SS))
    return tile


def add_indices(card: Image.Image, rank: str, suit: str, font, ten_font,
                pip_size: int = 48, x_pt: int = 24, y_pt: int = 26) -> Image.Image:
    tile = index_tile(rank, suit, font, ten_font, pip_size)
    x, y = x_pt * SS, y_pt * SS
    d = ImageDraw.Draw(card)
    for px, py in ((x, y), (W * SS - x - tile.width, H * SS - y - tile.height)):
        d.rounded_rectangle([px - 12 * SS, py - 12 * SS,
                             px + tile.width + 12 * SS, py + tile.height + 12 * SS],
                            radius=20 * SS, fill=PAPER)
    card.alpha_composite(tile, (x, y))
    card.alpha_composite(tile.rotate(180), (W * SS - x - tile.width, H * SS - y - tile.height))
    return card


PIP_LAYOUT = {
    "7": [(-1, -1), (1, -1), (0, -0.5), (-1, 0), (1, 0), (-1, 1), (1, 1)],
    "8": [(-1, -1), (1, -1), (0, -0.5), (-1, 0), (1, 0), (0, 0.5), (-1, 1), (1, 1)],
    "9": [(-1, -1), (1, -1), (-1, -1/3), (1, -1/3), (0, 0), (-1, 1/3), (1, 1/3), (-1, 1), (1, 1)],
    "10": [(-1, -1), (1, -1), (0, -2/3), (-1, -1/3), (1, -1/3), (-1, 1/3), (1, 1/3), (0, 2/3), (-1, 1), (1, 1)],
}


def add_number_pips(card: Image.Image, rank: str, suit: str) -> None:
    color = RED if suit in {"H", "D"} else BLACK
    if rank == "A":
        pip = draw_suit_symbol(300 * SS, suit, color)
        card.alpha_composite(pip, ((W * SS - pip.width) // 2, (H * SS - pip.height) // 2))
        return
    for col, row in PIP_LAYOUT[rank]:
        pip = draw_suit_symbol(94 * SS, suit, color)
        if row > 0:
            pip = pip.rotate(180)
        px = W * SS // 2 + col * 88 * SS - pip.width // 2
        py = H * SS // 2 + round(row * 235 * SS) - pip.height // 2
        card.alpha_composite(pip, (px, py))


def compose(rank: str, suit: str, font, ten_font, tmpdir: Path) -> Image.Image:
    svg = SRC_DIR / f"{rank}{suit}.svg"
    source_card = render_svg(svg, tmpdir)
    # Quiet the source: less toy, more printed object. Keep the original SVG
    # geometry intact; overpainting indices creates visible layout collisions.
    rgb = source_card.convert("RGB")
    alpha = source_card.getchannel("A")
    rgb = ImageEnhance.Color(rgb).enhance(0.76)
    rgb = ImageEnhance.Contrast(rgb).enhance(0.99)
    source_card = rgb.convert("RGBA")
    source_card.putalpha(alpha)

    # The source deck is technically correct, but it sits too close to the card
    # edge for our mobile UI. Place it on our own white stock with a small inset
    # instead of redrawing any values/suits.
    card = rounded_card()
    inset_scale = 0.88 if rank in COURTS else 0.90
    inner = source_card.resize((round(W * SS * inset_scale), round(H * SS * inset_scale)), Image.LANCZOS)
    card.alpha_composite(inner, ((W * SS - inner.width) // 2, (H * SS - inner.height) // 2))
    if rank == "A":
        card = boost_red_ace_mark(card, suit)
    out = card.resize((W, H), Image.LANCZOS)
    return premium_stock_finish(out)


def write_imageset(name: str, master: Image.Image) -> None:
    d = CATALOG / f"{name}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    for old in d.glob("*.png"):
        old.unlink()
    master.resize((312, 444), Image.LANCZOS).save(d / f"{name}@2x.png")
    master.resize((468, 666), Image.LANCZOS).save(d / f"{name}@3x.png")
    (d / "Contents.json").write_text(json.dumps({
        "images": [
            {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": f"{name}@3x.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }, indent=2), encoding="utf-8")


def main() -> None:
    OUT_MASTER.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 156 * SS, index=1)
    ten_font = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 126 * SS, index=1)
    with tempfile.TemporaryDirectory() as t:
        tmpdir = Path(t)
        for suit_code, suit_name, _ in SUITS:
            for rank_code, rank_name in RANKS:
                name = f"card_{suit_name}_{rank_name}"
                master = compose(rank_code, suit_code, font, ten_font, tmpdir)
                master.save(OUT_MASTER / f"{name}.png")
                write_imageset(name, master)
    print(f"32 vector cards -> {OUT_MASTER} + {CATALOG}")


if __name__ == "__main__":
    main()
