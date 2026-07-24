#!/usr/bin/env python3
"""Poch 1441 card fronts from Public Domain vector-playing-cards SVGs.

No AI, no generated sheet slicing. Each court card is rendered from its own SVG.
The standard deck is restyled for the app:
- neutral ivory-gray #DEDCD7 card stock with deterministic build-time patina
- quiet court palette: yellow -> matte gold, blue -> graphite/navy
- original vector layout and indices are preserved to avoid overpaint artifacts
- no second-pass value/suit labels are drawn over the SVG cards
"""
from __future__ import annotations

import argparse
import hashlib
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

PAPER = (222, 220, 215, 255)
RED = (204, 35, 52, 255)
BLACK = (0, 0, 0, 255)
GOLD = (184, 141, 52, 255)
NAVY = (42, 58, 82, 255)
GRAPHITE = (32, 30, 38, 255)

PATINA_SATURATION = 0.59
PRINT_FADE = 0.120
PAPER_GRAIN_LIMIT = 0.02
INK_EDGE_SOFTENING = 0.30
INK_POROSITY_MAX = 0.14
INK_DRYNESS_MAX = 0.035
PRINT_WEAR_AREA_MIN = 0.006
PRINT_WEAR_AREA_MAX = 0.010
PRINT_WEAR_OPACITY_MIN = 0.08
PRINT_WEAR_OPACITY_MAX = 0.15
PRINT_WEAR_MAX_COMPONENT_PX = 7
FOLD_RIDGE_LEVEL = (12, 18)
FOLD_SHADOW_LEVEL = (16, 23)
FOLD_RIDGE_BLUR = 2.00
FOLD_SHADOW_BLUR = 1.80
FOLD_SHADOW_STRENGTH = 0.24
EDGE_MATTE_STRENGTH = 0.12
CORNER_HANDLING_STRENGTH = 0.28
CORNER_SOFTNESS_MIN = 0.88
CORNER_SOFTNESS_MAX = 1.12
GRIP_ZONE_STRENGTH = 0.10
HANDLING_POLISH_MAX = 0.025
EDGE_FIBER_STRENGTH = 0.45
EDGE_WEAR_MIN_PX = 12
EDGE_WEAR_MAX_PX = 20
ALPHA_NICK_MIN_COUNT = 1
ALPHA_NICK_MAX_COUNT = 3
ALPHA_NICK_MAX_DEPTH = 3
ALPHA_NICK_MAX_CHANGED_PIXELS = 64
PRINT_RUB_OPACITY_MIN = 0.025
PRINT_RUB_OPACITY_MAX = 0.045
INDEX_ZONE_WIDTH = 172
INDEX_ZONE_HEIGHT = 238
REVIEW_CARDS = ("AS", "KH", "QC", "10D")
PHONE_HAND_CARDS = ("10H", "AS", "10C", "KH", "10D", "8C", "9C")
PHONE_CARD_WIDTH = 72
PHONE_CARD_HEIGHT = 103
PHONE_HAND_TRANSLATIONS = (-116, -78, -40, 0, 40, 78, 116)
PHONE_HAND_ROTATIONS = (-20, -13, -7, 0, 7, 13, 20)

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
_STOCK_GRAIN: np.ndarray | None = None

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
                        fill=PAPER, outline=(198, 197, 193, 255), width=1 * SS)
    return im


def _resized_noise(rng: np.random.Generator, cell_size: int) -> np.ndarray:
    source = rng.normal(
        0,
        1,
        (max(3, round(H / cell_size)), max(3, round(W / cell_size))),
    ).astype(np.float32)
    field = np.asarray(
        Image.fromarray(source, mode="F").resize((W, H), Image.BICUBIC),
        dtype=np.float32,
    ).copy()
    field -= float(field.mean())
    field /= max(float(field.std()), 0.001)
    return field


def _blur_float_field(field: np.ndarray, radius: float) -> np.ndarray:
    normalized = field.astype(np.float32).copy()
    normalized -= float(normalized.mean())
    normalized /= max(float(normalized.std()), 0.001)
    encoded = np.clip(normalized * 32 + 128, 0, 255).astype(np.uint8)
    blurred = np.asarray(
        Image.fromarray(encoded, mode="L").filter(ImageFilter.GaussianBlur(radius)),
        dtype=np.float32,
    )
    return (blurred - float(blurred.mean())) / 32


def _multidirectional_fibres(rng: np.random.Generator) -> np.ndarray:
    """Fine non-periodic fibres balanced across eight direction bins."""
    field = np.zeros((H, W), dtype=np.float32)
    for base_angle in np.linspace(0, np.pi, 8, endpoint=False):
        for _ in range(32):
            angle = float(base_angle + rng.uniform(-np.pi / 20, np.pi / 20))
            length = int(rng.integers(12, 44))
            start_x = float(rng.uniform(0, W))
            start_y = float(rng.uniform(0, H))
            amplitude = float(rng.uniform(-0.7, 0.7))
            for step in range(length):
                progress = step / max(1, length - 1)
                taper = np.sin(np.pi * progress) ** 1.35
                x = round(start_x + np.cos(angle) * step)
                y = round(start_y + np.sin(angle) * step)
                if 0 <= x < W and 0 <= y < H:
                    field[y, x] += amplitude * taper
    field = _blur_float_field(field, radius=0.55)
    field -= float(field.mean())
    field /= max(float(field.std()), 0.001)
    return field


def _isotropic_stock_grain(rng: np.random.Generator) -> np.ndarray:
    """Irregular low-frequency mottling plus direction-balanced microfibres."""
    broad_mottle = _resized_noise(rng, cell_size=58)
    fine_mottle = _resized_noise(rng, cell_size=24)

    raw_micro = rng.normal(0, 1, (H, W)).astype(np.float32)
    near = _blur_float_field(raw_micro, radius=0.7)
    far = _blur_float_field(raw_micro, radius=2.4)
    bandpass = (near - far).copy()
    bandpass -= float(bandpass.mean())
    bandpass /= max(float(bandpass.std()), 0.001)

    fibres = _multidirectional_fibres(rng)
    field = broad_mottle * 1.28 + fine_mottle * 0.66 + fibres * 0.22 + bandpass * 0.40
    field -= float(field.mean())
    field /= max(float(field.std()), 0.001)
    return np.clip(1.0 + field * 0.0085,
                   1.0 - PAPER_GRAIN_LIMIT,
                   1.0 + PAPER_GRAIN_LIMIT)


def premium_stock_finish(card: Image.Image) -> Image.Image:
    """Subtle warm stock: linen grain, air-cushion dimples and curvature.

    This encodes the texture direction in a deterministic way. The visual card
    remains warm and quiet at read distance; the finish only appears as micro
    variation under the app's dark UI.
    """
    global _STOCK_GRAIN, _STOCK_TEXTURE
    if _STOCK_TEXTURE is None:
        rng = np.random.default_rng(1441)
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        nx = (xx / (W - 1)) * 2 - 1
        ny = (yy / (H - 1)) * 2 - 1

        # Very mild top-left illumination and edge curvature.
        curvature = 1.0 - 0.018 * (nx * nx + ny * ny) + 0.012 * (-0.55 * nx - 0.75 * ny)
        _STOCK_GRAIN = _isotropic_stock_grain(rng)
        _STOCK_TEXTURE = np.clip(curvature * _STOCK_GRAIN, 0.94, 1.035)[:, :, None]

    rgba = np.asarray(card, dtype=np.float32)
    alpha = rgba[:, :, 3:4] / 255.0
    stock_rgb = np.asarray(PAPER[:3], dtype=np.float32)[None, None, :]
    channel_spread = rgba[:, :, :3].max(axis=2) - rgba[:, :, :3].min(axis=2)
    paper_distance = np.linalg.norm(rgba[:, :, :3] - stock_rgb, axis=2)
    source_white = (
        (rgba[:, :, :3].mean(axis=2) > 225) &
        (channel_spread < 24)
    )
    whiteish = (
        source_white |
        ((paper_distance < 34) &
         (rgba[:, :, :3].mean(axis=2) > 202) &
         (channel_spread < 24))
    )[:, :, None]
    rgba[:, :, :3] = np.where(
        whiteish,
        np.clip(stock_rgb * _STOCK_TEXTURE, 0, 255),
        rgba[:, :, :3],
    )
    rgba[:, :, :3] = rgba[:, :, :3] * alpha + 255 * (1 - alpha)
    rgba[:, :, 3] = np.asarray(card)[:, :, 3]
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8))


def stable_asset_seed(asset_name: str) -> int:
    """Stable seed from the public SVG asset name, independent of Python hashing."""
    digest = hashlib.sha256(asset_name.encode("utf-8")).digest()
    return int.from_bytes(digest[:8], byteorder="big", signed=False)


def protected_index_mask(width: int = W, height: int = H) -> np.ndarray:
    """Top-left and rotated bottom-right indices remain untouched by wear."""
    mask = np.zeros((height, width), dtype=bool)
    mask[:INDEX_ZONE_HEIGHT, :INDEX_ZONE_WIDTH] = True
    mask[height - INDEX_ZONE_HEIGHT:, width - INDEX_ZONE_WIDTH:] = True
    return mask


def _blend_rgb(arr: np.ndarray, color: tuple[int, int, int], mask: np.ndarray) -> None:
    amount = np.clip(mask.astype(np.float32), 0, 1)[:, :, None]
    target = np.asarray(color, dtype=np.float32)[None, None, :]
    arr[:, :, :3] = arr[:, :, :3] * (1 - amount) + target * amount


def _darken_rgb(arr: np.ndarray, mask: np.ndarray, strength: float) -> None:
    amount = np.clip(mask.astype(np.float32) * strength, 0, 1)[:, :, None]
    arr[:, :, :3] *= 1 - amount


def _alpha_edge_distance(alpha: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Distance through the handling zone, derived without changing alpha."""
    solid = alpha > 0
    remaining = solid.copy()
    distance = np.full((H, W), EDGE_WEAR_MAX_PX + 1, dtype=np.float32)
    for depth in range(EDGE_WEAR_MAX_PX + 1):
        source = Image.fromarray(remaining.astype(np.uint8) * 255, mode="L")
        eroded = np.asarray(source.filter(ImageFilter.MinFilter(3))) > 0
        distance[remaining & ~eroded] = depth
        remaining = eroded
    return distance, solid


def _tapered_edge_fibres(rng: np.random.Generator, band: np.ndarray) -> np.ndarray:
    """Fine perimeter-parallel fibres with sine-tapered ends, never rectangular dabs."""
    fibres = np.zeros((H, W), dtype=np.float32)
    for _ in range(56):
        side = int(rng.integers(0, 4))
        horizontal = side in {0, 2}
        span = W if horizontal else H
        length = int(rng.integers(22, 92))
        start = int(rng.integers(CORNER_R // 2, span - CORNER_R // 2 - length))
        depth = float(rng.uniform(1.5, EDGE_WEAR_MAX_PX - 0.5))
        phase = float(rng.uniform(0, np.pi * 2))
        for step in range(length):
            progress = step / max(1, length - 1)
            taper = np.sin(np.pi * progress) ** 1.45
            offset = np.sin(progress * np.pi * 2 + phase) * 0.7
            position = start + step
            if side == 0:
                x, y = position, round(depth + offset)
            elif side == 1:
                x, y = round(W - 1 - depth - offset), position
            elif side == 2:
                x, y = position, round(H - 1 - depth - offset)
            else:
                x, y = round(depth + offset), position
            if 0 <= x < W and 0 <= y < H:
                fibres[y, x] = max(fibres[y, x], EDGE_FIBER_STRENGTH * taper)
    fibres = np.asarray(
        Image.fromarray(np.clip(fibres * 255, 0, 255).astype(np.uint8), mode="L")
        .filter(ImageFilter.GaussianBlur(0.45)),
        dtype=np.float32,
    ) / 255.0
    return fibres * band


def _perimeter_wear_masks(
    rng: np.random.Generator,
    alpha: np.ndarray,
) -> tuple[
    np.ndarray, np.ndarray, np.ndarray, np.ndarray,
    float, float, float, float, float,
]:
    """Continuous 12-20 px matte perimeter with visibly handled corners."""
    distance, solid = _alpha_edge_distance(alpha)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    phase_x, phase_y = rng.uniform(0, np.pi * 2, size=2)
    waviness = (
        np.sin(xx * 2 * np.pi / 83.0 + phase_x) * 2.35 +
        np.sin(yy * 2 * np.pi / 127.0 + phase_y) * 1.75
    )
    width = np.clip(16.0 + waviness, EDGE_WEAR_MIN_PX, EDGE_WEAR_MAX_PX)
    band = solid & (distance < width)
    inward_fade = np.clip((width - distance) / np.maximum(width, 1), 0, 1)
    slow_variation = 0.5 + 0.5 * np.sin((xx + yy * 0.16) * 2 * np.pi / 149.0 + phase_x)
    matte_field = np.clip(0.5 + _resized_noise(rng, cell_size=43) * 0.22, 0, 1)

    nearest_x = np.minimum(xx, W - 1 - xx)
    nearest_y = np.minimum(yy, H - 1 - yy)
    corner_proximity = (
        np.clip((142 - nearest_x) / 142, 0, 1) *
        np.clip((142 - nearest_y) / 142, 0, 1)
    )
    corner_softness = float(rng.uniform(CORNER_SOFTNESS_MIN, CORNER_SOFTNESS_MAX))
    left_weight, right_weight = rng.uniform(0.88, 1.12, size=2)
    left_grip = np.clip((118 - xx) / 104, 0, 1) * left_weight
    right_grip = np.clip((118 - (W - 1 - xx)) / 104, 0, 1) * right_weight
    lower_bias = 0.32 + np.clip((yy - H * 0.44) / (H * 0.46), 0, 1) * 0.68
    lower_corner_grip = (
        np.clip((110 - nearest_y) / 94, 0, 1) * corner_proximity
    )
    grip_irregularity = np.clip(0.58 + _resized_noise(rng, cell_size=71) * 0.17, 0, 1)
    grip_zone = band * np.clip(
        np.maximum(left_grip, right_grip) * lower_bias + lower_corner_grip * 0.62,
        0,
        1,
    ) * grip_irregularity

    warm_gray = band * (
        0.23 + inward_fade * 0.21 + matte_field * EDGE_MATTE_STRENGTH
    ) + grip_zone * GRIP_ZONE_STRENGTH
    ivory = band * (
        0.10 + slow_variation * 0.15 + (1 - matte_field) * EDGE_MATTE_STRENGTH
    ) + grip_zone * GRIP_ZONE_STRENGTH * 0.18
    corner_handling = band * corner_proximity * (
        CORNER_HANDLING_STRENGTH * corner_softness * (0.55 + inward_fade * 0.45)
    )
    fibres = _tapered_edge_fibres(rng, band.astype(np.float32))
    boundary = solid & (distance == 0)
    coverage = float(band[boundary].mean()) if boundary.any() else 0.0
    inner_width_rms = float(np.std(width[boundary])) if boundary.any() else 0.0
    edge_matte_rms = float(np.std(matte_field[band])) if band.any() else 0.0
    grip_zone_rms = float(np.sqrt(np.mean(np.square(grip_zone[band])))) if band.any() else 0.0
    return (
        warm_gray,
        ivory,
        corner_handling,
        fibres,
        coverage,
        inner_width_rms,
        edge_matte_rms,
        corner_softness,
        grip_zone_rms,
    )


def _handling_polish(
    rng: np.random.Generator,
    arr: np.ndarray,
    opaque: np.ndarray,
) -> float:
    """Very subtle neutral smoothing where fingers commonly hold the stock."""
    paper = np.asarray(PAPER[:3], dtype=np.float32)
    stock = np.linalg.norm(arr[:, :, :3] - paper[None, None, :], axis=2) < 38
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    nearest_x = np.minimum(xx, W - 1 - xx)
    nearest_y = np.minimum(yy, H - 1 - yy)
    side_zone = np.clip((128 - nearest_x) / 92, 0, 1)
    end_zone = np.clip((148 - nearest_y) / 108, 0, 1)
    handling_zone = np.maximum(side_zone * 0.85, end_zone * 0.55)
    irregularity = np.clip(0.55 + _resized_noise(rng, cell_size=79) * 0.18, 0, 1)
    polish = handling_zone * irregularity * HANDLING_POLISH_MAX
    polish *= stock & opaque

    softly_smoothed = np.asarray(
        Image.fromarray(np.clip(arr[:, :, :3], 0, 255).astype(np.uint8), mode="RGB")
        .filter(ImageFilter.GaussianBlur(2.2)),
        dtype=np.float32,
    )
    smooth_amount = (polish * 2.4)[:, :, None]
    arr[:, :, :3] = arr[:, :, :3] * (1 - smooth_amount) + softly_smoothed * smooth_amount
    _blend_rgb(arr, (229, 227, 222), polish)
    active = polish > 0
    return float(np.sqrt(np.mean(np.square(polish[active])))) if active.any() else 0.0


def _soften_printed_ink(
    rng: np.random.Generator,
    arr: np.ndarray,
    protected: np.ndarray,
    opaque: np.ndarray,
) -> float:
    """Slightly soft, porous ink contours without stains or damage to indices."""
    paper = np.asarray(PAPER[:3], dtype=np.float32)
    ink = np.linalg.norm(arr[:, :, :3] - paper[None, None, :], axis=2) > 48
    ink &= ~protected & opaque
    ink_image = Image.fromarray(ink.astype(np.uint8) * 255, mode="L")
    eroded = np.asarray(ink_image.filter(ImageFilter.MinFilter(5))) > 0
    contour = ink & ~eroded

    softened = np.asarray(
        Image.fromarray(np.clip(arr[:, :, :3], 0, 255).astype(np.uint8), mode="RGB")
        .filter(ImageFilter.GaussianBlur(0.72)),
        dtype=np.float32,
    )
    contour_amount = contour.astype(np.float32)[:, :, None] * INK_EDGE_SOFTENING
    arr[:, :, :3] = arr[:, :, :3] * (1 - contour_amount) + softened * contour_amount

    noise = rng.random((H, W), dtype=np.float32)
    porosity = contour * np.clip((noise - 0.34) * 0.22, 0, INK_POROSITY_MAX)
    _blend_rgb(arr, PAPER[:3], porosity)

    dry_grain = rng.random((H, W), dtype=np.float32) * INK_DRYNESS_MAX
    _blend_rgb(arr, PAPER[:3], dry_grain * ink)
    return float(porosity[contour].mean()) if contour.any() else 0.0


def _micro_print_wear_mask(
    rng: np.random.Generator,
    candidates: np.ndarray,
    target_count: int,
) -> tuple[np.ndarray, np.ndarray]:
    """Separated 1-3 px pores and thin tapered scuffs, never dropout bubbles."""
    selected = np.zeros((H, W), dtype=bool)
    amount = np.zeros((H, W), dtype=np.float32)
    blocked = np.zeros((H, W), dtype=bool)
    candidate_positions = rng.permutation(np.flatnonzero(candidates))
    directions = ((1, 0), (1, 1), (0, 1), (-1, 1),
                  (-1, 0), (-1, -1), (0, -1), (1, -1))
    selected_count = 0

    for position in candidate_positions:
        if selected_count >= target_count:
            break
        y, x = divmod(int(position), W)
        remaining = target_count - selected_count
        is_scuff = remaining >= 4 and rng.random() < 0.18
        direction_x, direction_y = directions[int(rng.integers(0, len(directions)))]

        if is_scuff:
            length = min(int(rng.integers(4, PRINT_WEAR_MAX_COMPONENT_PX + 1)), remaining)
            offsets = [(direction_x * step, direction_y * step) for step in range(length)]
            weights = np.sin(np.linspace(0.45, np.pi - 0.45, length)).astype(np.float32)
        else:
            pore_size = min(int(rng.choice((1, 1, 2, 2, 3))), remaining)
            offsets = [(direction_x * step, direction_y * step) for step in range(pore_size)]
            if pore_size == 3 and rng.random() < 0.55:
                # A tiny kink reads as porous ink, not a stamped circular hole.
                offsets[-1] = (direction_x + direction_y, direction_y - direction_x)
            weights = np.ones(pore_size, dtype=np.float32)

        points = list(dict.fromkeys((x + dx, y + dy) for dx, dy in offsets))
        if len(points) > remaining:
            points = points[:remaining]
            weights = weights[:remaining]
        if not points or any(
            px < 0 or px >= W or py < 0 or py >= H or
            not candidates[py, px] or blocked[py, px]
            for px, py in points
        ):
            continue

        for index, (px, py) in enumerate(points):
            selected[py, px] = True
            amount[py, px] = max(amount[py, px], float(weights[index]))
            blocked[max(0, py - 1):min(H, py + 2),
                    max(0, px - 1):min(W, px + 2)] = True
        selected_count += len(points)

    return selected, amount


def _large_round_component_count(mask: np.ndarray) -> tuple[int, int]:
    """Count connected wear blobs wider than 3 px and plausibly circular."""
    remaining = set(int(position) for position in np.flatnonzero(mask))
    large_round = 0
    max_component = 0
    while remaining:
        start = remaining.pop()
        stack = [start]
        component = [start]
        while stack:
            position = stack.pop()
            y, x = divmod(position, W)
            for offset_y in (-1, 0, 1):
                for offset_x in (-1, 0, 1):
                    if offset_x == 0 and offset_y == 0:
                        continue
                    neighbor_x, neighbor_y = x + offset_x, y + offset_y
                    if 0 <= neighbor_x < W and 0 <= neighbor_y < H:
                        neighbor = neighbor_y * W + neighbor_x
                        if neighbor in remaining:
                            remaining.remove(neighbor)
                            stack.append(neighbor)
                            component.append(neighbor)

        component_x = [position % W for position in component]
        component_y = [position // W for position in component]
        width = max(component_x) - min(component_x) + 1
        height = max(component_y) - min(component_y) + 1
        fill_ratio = len(component) / (width * height)
        aspect = max(width, height) / max(1, min(width, height))
        max_component = max(max_component, len(component))
        if width > 3 and height > 3 and aspect <= 1.45 and fill_ratio >= 0.50:
            large_round += 1
    return large_round, max_component


def _printed_surface_wear(
    rng: np.random.Generator,
    arr: np.ndarray,
    protected: np.ndarray,
    opaque: np.ndarray,
) -> tuple[float, float, int, int]:
    """Dry handling wear on 0.6-1.0% of large printed areas, never on indices."""
    paper = np.asarray(PAPER[:3], dtype=np.float32)
    ink = np.linalg.norm(arr[:, :, :3] - paper[None, None, :], axis=2) > 48
    candidates = ink & ~protected & opaque
    target_count = min(
        int(rng.uniform(PRINT_WEAR_AREA_MIN, PRINT_WEAR_AREA_MAX) * W * H),
        int(candidates.sum()),
    )
    if target_count == 0:
        return 0.0, 0.0, 0, 0

    # Preserve the V5 random stream so edge/corner handling remains byte-stable;
    # this field now seeds sparse micro-wear instead of becoming broad blobs.
    legacy_score = _resized_noise(rng, cell_size=19)
    wear_digest = hashlib.sha256(legacy_score.tobytes()).digest()
    wear_rng = np.random.default_rng(int.from_bytes(wear_digest[:8], "big"))
    selected, wear_amount = _micro_print_wear_mask(wear_rng, candidates, target_count)
    opacity = float(rng.uniform(PRINT_WEAR_OPACITY_MIN, PRINT_WEAR_OPACITY_MAX))
    _blend_rgb(arr, PAPER[:3], wear_amount * opacity)
    large_round_components, max_component = _large_round_component_count(selected)
    return float(selected.mean()), opacity, large_round_components, max_component


def _print_rub_traces(
    rng: np.random.Generator,
    arr: np.ndarray,
    protected: np.ndarray,
    opaque: np.ndarray,
) -> tuple[int, float]:
    """One or two faint tapered handling traces confined to printed pigment."""
    paper = np.asarray(PAPER[:3], dtype=np.float32)
    ink = np.linalg.norm(arr[:, :, :3] - paper[None, None, :], axis=2) > 48
    candidates = ink & ~protected & opaque
    candidate_positions = np.flatnonzero(candidates)
    trace_count = int(rng.integers(1, 3))
    if not len(candidate_positions):
        return 0, 0.0

    rub = np.zeros((H, W), dtype=np.float32)
    for _ in range(trace_count):
        anchor = int(rng.choice(candidate_positions))
        anchor_y, anchor_x = divmod(anchor, W)
        angle = float(rng.uniform(0, np.pi * 2))
        length = int(rng.integers(18, 43))
        direction_x, direction_y = np.cos(angle), np.sin(angle)
        normal_x, normal_y = -direction_y, direction_x
        for step in range(length):
            progress = step / max(1, length - 1)
            taper = np.sin(np.pi * progress) ** 1.55
            lateral = np.sin(progress * np.pi * 2 + angle) * 0.55
            x = round(anchor_x + (step - length / 2) * direction_x + lateral * normal_x)
            y = round(anchor_y + (step - length / 2) * direction_y + lateral * normal_y)
            if 0 <= x < W and 0 <= y < H and candidates[y, x]:
                rub[y, x] = max(rub[y, x], taper)

    rub = np.asarray(
        Image.fromarray(np.clip(rub * 255, 0, 255).astype(np.uint8), mode="L")
        .filter(ImageFilter.GaussianBlur(0.65)),
        dtype=np.float32,
    ) / 255.0
    rub *= candidates
    opacity = float(rng.uniform(PRINT_RUB_OPACITY_MIN, PRINT_RUB_OPACITY_MAX))
    _blend_rgb(arr, PAPER[:3], rub * opacity)
    return trace_count, opacity


def _subtle_alpha_nicks(
    rng: np.random.Generator,
    original_alpha: np.ndarray,
) -> tuple[np.ndarray, int, int, int, int]:
    """Add 1-3 tiny tapered edge compressions without fraying the silhouette."""
    result = original_alpha.copy()
    changed = np.zeros((H, W), dtype=bool)
    nick_count = int(rng.integers(ALPHA_NICK_MIN_COUNT, ALPHA_NICK_MAX_COUNT + 1))
    max_depth_used = 0
    changed_count = 0

    for _ in range(nick_count):
        side = int(rng.choice((0, 1, 2), p=(0.36, 0.36, 0.28)))
        if side in {0, 1}:
            center = int(rng.uniform(H * 0.55, H - CORNER_R - 14))
        elif rng.random() < 0.5:
            center = int(rng.uniform(CORNER_R + 10, W * 0.31))
        else:
            center = int(rng.uniform(W * 0.69, W - CORNER_R - 10))
        span = int(rng.integers(3, 7))
        depth = int(rng.integers(1, ALPHA_NICK_MAX_DEPTH + 1))
        max_depth_used = max(max_depth_used, depth)

        for offset in range(span):
            progress = (offset + 0.5) / span
            local_depth = max(1, round(depth * np.sin(np.pi * progress) ** 1.35))
            along = center + offset - span // 2
            for inset in range(local_depth):
                if side == 0:
                    x, y = inset, along
                elif side == 1:
                    x, y = W - 1 - inset, along
                else:
                    x, y = along, H - 1 - inset
                if (
                    0 <= x < W and 0 <= y < H and original_alpha[y, x] > 0 and
                    changed_count < ALPHA_NICK_MAX_CHANGED_PIXELS
                ):
                    result[y, x] = 0
                    if not changed[y, x]:
                        changed[y, x] = True
                        changed_count += 1

            if side == 0:
                feather_x, feather_y = local_depth, along
            elif side == 1:
                feather_x, feather_y = W - 1 - local_depth, along
            else:
                feather_x, feather_y = along, H - 1 - local_depth
            if (
                0 <= feather_x < W and 0 <= feather_y < H and
                original_alpha[feather_y, feather_x] > 0 and
                changed_count < ALPHA_NICK_MAX_CHANGED_PIXELS
            ):
                result[feather_y, feather_x] = min(
                    result[feather_y, feather_x],
                    round(float(original_alpha[feather_y, feather_x]) * 0.68),
                )
                if not changed[feather_y, feather_x]:
                    changed[feather_y, feather_x] = True
                    changed_count += 1

    changed_pixels = changed_count
    removed_opaque = int(((original_alpha >= 250) & (result == 0)).sum())
    if np.any(result > original_alpha) or changed_pixels > ALPHA_NICK_MAX_CHANGED_PIXELS:
        raise RuntimeError("V9 alpha nicks exceeded the bounded silhouette contract")
    return result, nick_count, changed_pixels, removed_opaque, max_depth_used


def _apply_print_registration(
    rng: np.random.Generator,
    arr: np.ndarray,
    protected: np.ndarray,
    opaque: np.ndarray,
) -> tuple[int, int]:
    """A nearly imperceptible one-pixel dry-print drift, never on corner indices."""
    offset_x = int(rng.choice((-1, 1)))
    offset_y = int(rng.choice((-1, 0, 1)))
    shifted = np.roll(arr[:, :, :3], shift=(offset_y, offset_x), axis=(0, 1))
    chroma = arr[:, :, :3].max(axis=2) - arr[:, :, :3].min(axis=2)
    registration_mask = (chroma > 22) & ~protected & opaque
    amount = registration_mask.astype(np.float32)[:, :, None] * 0.035
    arr[:, :, :3] = arr[:, :, :3] * (1 - amount) + shifted * amount
    return offset_x, offset_y


def _shallow_fold_masks(rng: np.random.Generator,
                        protected: np.ndarray) -> tuple[np.ndarray, np.ndarray, int]:
    """One or two shallow, lightly broken pressure creases without paper tears."""
    light = Image.new("L", (W, H), 0)
    shade = Image.new("L", (W, H), 0)
    light_draw = ImageDraw.Draw(light)
    shade_draw = ImageDraw.Draw(shade)
    fold_count = int(rng.integers(1, 3))
    for _ in range(fold_count):
        center_x = float(rng.uniform(W * 0.28, W * 0.72))
        center_y = float(rng.uniform(H * 0.28, H * 0.72))
        angle = float(rng.uniform(-0.85, 0.85))
        length = float(rng.uniform(W * 0.34, W * 0.58))
        dx = np.cos(angle) * length / 2
        dy = np.sin(angle) * length / 2
        normal_x, normal_y = -np.sin(angle), np.cos(angle)
        positions = np.linspace(-1, 1, 9)
        jitter = rng.uniform(-2.0, 2.0, size=len(positions))
        line = [
            (center_x + dx * position + normal_x * offset,
             center_y + dy * position + normal_y * offset)
            for position, offset in zip(positions, jitter)
        ]
        ridge_line = [(x - normal_x * 1.7, y - normal_y * 1.7) for x, y in line]
        shadow_line = [(x + normal_x * 2.1, y + normal_y * 2.1) for x, y in line]
        light_draw.line(ridge_line, fill=int(rng.integers(*FOLD_RIDGE_LEVEL)), width=6)
        shade_draw.line(shadow_line, fill=int(rng.integers(*FOLD_SHADOW_LEVEL)), width=4)

    light_mask = np.asarray(
        light.filter(ImageFilter.GaussianBlur(FOLD_RIDGE_BLUR)), dtype=np.float32
    ) / 255.0
    shade_mask = np.asarray(
        shade.filter(ImageFilter.GaussianBlur(FOLD_SHADOW_BLUR)), dtype=np.float32
    ) / 255.0
    light_mask[protected] = 0
    shade_mask[protected] = 0
    return light_mask, shade_mask, fold_count


def stock_texture_metrics() -> dict[str, float]:
    """Direction and periodicity checks on the stock field at a 390 px card width."""
    if _STOCK_GRAIN is None:
        raise RuntimeError("Stock texture must be initialized before measuring it")
    rendered_height = round(390 * H / W)
    field = np.asarray(
        Image.fromarray(_STOCK_GRAIN.astype(np.float32), mode="F")
        .resize((390, rendered_height), Image.BICUBIC),
        dtype=np.float32,
    ).copy()
    field -= float(field.mean())

    energies = [
        float(np.mean(np.abs(np.diff(field, axis=1)))),
        float(np.mean(np.abs(np.diff(field, axis=0)))),
        float(np.mean(np.abs(field[1:, 1:] - field[:-1, :-1]))) / np.sqrt(2),
        float(np.mean(np.abs(field[1:, :-1] - field[:-1, 1:]))) / np.sqrt(2),
    ]
    axis_balance = max(energies[0], energies[1]) / max(min(energies[0], energies[1]), 1e-8)
    diagonal_balance = max(energies[2], energies[3]) / max(min(energies[2], energies[3]), 1e-8)
    directionality = max(axis_balance, diagonal_balance)

    normalized = field / max(float(field.std()), 1e-8)
    correlations: list[float] = []
    for axis in (0, 1):
        axis_correlations: list[float] = []
        for lag in range(6, 71):
            if axis == 0:
                first, second = normalized[:-lag, :], normalized[lag:, :]
            else:
                first, second = normalized[:, :-lag], normalized[:, lag:]
            axis_correlations.append(float(np.mean(first * second)))
        for index in range(1, len(axis_correlations) - 1):
            shoulder = (axis_correlations[index - 1] + axis_correlations[index + 1]) / 2
            correlations.append(max(0.0, axis_correlations[index] - shoulder))
    periodicity = max(correlations, default=0.0)
    return {
        "texture_directionality": round(directionality, 4),
        "texture_periodicity": round(periodicity, 5),
    }


def apply_build_time_patina(card: Image.Image, asset_name: str) -> tuple[Image.Image, dict[str, int | float | str]]:
    """Apply deterministic, alpha-preserving wear after the vector render."""
    rng = np.random.default_rng(stable_asset_seed(asset_name))
    original_alpha = np.asarray(card.getchannel("A"), dtype=np.uint8).copy()

    rgb = ImageEnhance.Color(card.convert("RGB")).enhance(PATINA_SATURATION)
    saturated = rgb.convert("RGBA")
    saturated.putalpha(Image.fromarray(original_alpha, mode="L"))
    arr = np.asarray(saturated, dtype=np.float32).copy()
    protected = protected_index_mask()
    opaque = original_alpha > 0

    paper = np.asarray(PAPER[:3], dtype=np.float32)
    ink = np.linalg.norm(arr[:, :, :3] - paper[None, None, :], axis=2) > 48
    print_fade = ink & ~protected & opaque
    _blend_rgb(arr, PAPER[:3], print_fade.astype(np.float32) * PRINT_FADE)

    registration_x, registration_y = _apply_print_registration(rng, arr, protected, opaque)
    ink_porosity = _soften_printed_ink(rng, arr, protected, opaque)
    (
        print_wear_area,
        print_wear_opacity,
        print_wear_large_round_components,
        print_wear_max_component_pixels,
    ) = _printed_surface_wear(rng, arr, protected, opaque)
    print_rub_trace_count, print_rub_opacity = _print_rub_traces(
        rng, arr, protected, opaque
    )
    handling_polish_rms = _handling_polish(rng, arr, opaque)

    (
        edge_gray,
        edge_ivory,
        corner_handling,
        edge_fibres,
        perimeter_coverage,
        inner_width_rms,
        edge_matte_rms,
        corner_softness,
        grip_zone_rms,
    ) = _perimeter_wear_masks(rng, original_alpha)
    edge_gray *= opaque
    edge_ivory *= opaque
    corner_handling *= opaque
    edge_fibres *= opaque
    _blend_rgb(arr, (202, 202, 199), edge_gray)
    _blend_rgb(arr, (232, 230, 225), edge_ivory)
    _blend_rgb(arr, (211, 210, 207), corner_handling)
    _blend_rgb(arr, (190, 190, 188), edge_fibres)

    fold_light, fold_shade, fold_count = _shallow_fold_masks(rng, protected)
    fold_light *= opaque
    fold_shade *= opaque
    _blend_rgb(arr, (228, 226, 221), fold_light)
    _darken_rgb(arr, fold_shade, strength=FOLD_SHADOW_STRENGTH)

    (
        final_alpha,
        alpha_nick_count,
        alpha_changed_pixels,
        alpha_removed_opaque_pixels,
        alpha_nick_max_depth,
    ) = _subtle_alpha_nicks(rng, original_alpha)
    arr[:, :, 3] = final_alpha
    result = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode="RGBA")
    if alpha_changed_pixels == 0:
        raise RuntimeError("V9 must produce a subtle per-card silhouette variation")
    return result, {
        **stock_texture_metrics(),
        "asset_name": asset_name,
        "seed": stable_asset_seed(asset_name),
        "paper_luminance": round(
            PAPER[0] * 0.2126 + PAPER[1] * 0.7152 + PAPER[2] * 0.0722,
            3,
        ),
        "paper_neutral_spread": max(PAPER[:3]) - min(PAPER[:3]),
        "saturation": PATINA_SATURATION,
        "paper_grain_limit": PAPER_GRAIN_LIMIT,
        "ink_edge_softening": INK_EDGE_SOFTENING,
        "ink_porosity": round(ink_porosity, 5),
        "ink_dryness_max": INK_DRYNESS_MAX,
        "print_wear_area": round(print_wear_area, 5),
        "print_wear_opacity": round(print_wear_opacity, 5),
        "print_wear_large_round_components": print_wear_large_round_components,
        "print_wear_max_component_pixels": print_wear_max_component_pixels,
        "print_rub_trace_count": print_rub_trace_count,
        "print_rub_opacity": round(print_rub_opacity, 5),
        "handling_polish_rms": round(handling_polish_rms, 5),
        "edge_fiber_strength": EDGE_FIBER_STRENGTH,
        "edge_matte_rms": round(edge_matte_rms, 5),
        "corner_handling_strength": CORNER_HANDLING_STRENGTH,
        "corner_softness": round(corner_softness, 5),
        "grip_zone_rms": round(grip_zone_rms, 5),
        "print_fade": PRINT_FADE,
        "registration_x": registration_x,
        "registration_y": registration_y,
        "perimeter_coverage": round(perimeter_coverage, 4),
        "inner_edge_width_rms": round(inner_width_rms, 4),
        "alpha_nick_count": alpha_nick_count,
        "alpha_changed_pixels": alpha_changed_pixels,
        "alpha_removed_opaque_pixels": alpha_removed_opaque_pixels,
        "alpha_nick_max_depth": alpha_nick_max_depth,
        "alpha_change_fraction": round(alpha_changed_pixels / (W * H), 7),
        "folds": fold_count,
    }


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


def compose(rank: str, suit: str, font, ten_font,
            tmpdir: Path) -> tuple[Image.Image, dict[str, int | float | str]]:
    svg = SRC_DIR / f"{rank}{suit}.svg"
    source_card = render_svg(svg, tmpdir)
    # Quiet the source: less toy, more printed object. Keep the original SVG
    # geometry intact; overpainting indices creates visible layout collisions.
    rgb = source_card.convert("RGB")
    alpha = source_card.getchannel("A")
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
    rendered = premium_stock_finish(out)
    return apply_build_time_patina(rendered, svg.name)


def write_imageset(name: str, master: Image.Image, catalog: Path = CATALOG,
                   contents_template: bytes | None = None) -> None:
    """Write one staged 2x/3x imageset while preserving the established 1x slot."""
    d = catalog / f"{name}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    for old in d.glob("*.png"):
        old.unlink()
    master.resize((312, 444), Image.LANCZOS).save(d / f"{name}@2x.png")
    master.resize((468, 666), Image.LANCZOS).save(d / f"{name}@3x.png")
    contents_path = d / "Contents.json"
    if contents_template is not None:
        contents_path.write_bytes(contents_template)
    else:
        contents_path.write_text(json.dumps({
            "images": [
                {"idiom": "universal", "scale": "1x"},
                {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
                {"filename": f"{name}@3x.png", "idiom": "universal", "scale": "3x"},
            ],
            "info": {"author": "xcode", "version": 1},
        }, indent=2), encoding="utf-8")


def parse_card_code(code: str) -> tuple[str, str]:
    match = re.fullmatch(r"(10|[AKQJ987])([SHCD])", code.upper())
    if match is None:
        raise ValueError(f"Unsupported review card code: {code}")
    return match.group(1), match.group(2)


def review_sheet(cards: list[tuple[str, Image.Image]], card_width: int) -> Image.Image:
    thumb_width = card_width
    thumb_height = round(thumb_width * H / W)
    margin = 42
    label_height = 36
    sheet = Image.new("RGB", (margin * 3 + thumb_width * 2,
                              margin * 3 + (thumb_height + label_height) * 2),
                      (24, 21, 20))
    draw = ImageDraw.Draw(sheet)
    for index, (code, card) in enumerate(cards):
        column = index % 2
        row = index // 2
        x = margin + column * (thumb_width + margin)
        y = margin + row * (thumb_height + label_height + margin)
        sheet.paste(card.convert("RGB").resize((thumb_width, thumb_height), Image.LANCZOS),
                    (x, y))
        draw.text((x, y + thumb_height + 8), f"{code} · public SVG · deterministic patina",
                  fill=(220, 213, 201))
    return sheet


def compact_contact_sheet(cards: list[tuple[str, Image.Image]]) -> Image.Image:
    """Compact full-deck proof with up to eight cards per row."""
    card_width = 96
    card_height = round(card_width * H / W)
    columns = min(8, max(1, len(cards)))
    rows = (len(cards) + columns - 1) // columns
    margin = 18
    label_height = 20
    sheet = Image.new(
        "RGB",
        (margin * (columns + 1) + card_width * columns,
         margin * (rows + 1) + (card_height + label_height) * rows),
        (24, 21, 20),
    )
    draw = ImageDraw.Draw(sheet)
    for index, (code, card) in enumerate(cards):
        column = index % columns
        row = index // columns
        x = margin + column * (card_width + margin)
        y = margin + row * (card_height + label_height + margin)
        sheet.paste(card.convert("RGB").resize((card_width, card_height), Image.LANCZOS),
                    (x, y))
        draw.text((x, y + card_height + 4), code, fill=(220, 213, 201))
    return sheet


def phone_hand_fan(cards: dict[str, Image.Image]) -> Image.Image:
    """Track-B hand proof at the canonical 390 px stage and 72x103 px card size."""
    canvas = Image.new("RGBA", (390, 180), (28, 25, 24, 255))
    background = ImageDraw.Draw(canvas)
    for y in range(canvas.height):
        progress = y / max(1, canvas.height - 1)
        value = round(38 - progress * 15)
        background.line((0, y, canvas.width, y), fill=(value + 3, value, value - 1, 255))
    background.line((0, 153, 390, 153), fill=(112, 103, 94, 40), width=1)

    center_x = canvas.width / 2
    for code, translation, rotation in zip(
        PHONE_HAND_CARDS,
        PHONE_HAND_TRANSLATIONS,
        PHONE_HAND_ROTATIONS,
    ):
        card = cards[code].resize((PHONE_CARD_WIDTH, PHONE_CARD_HEIGHT), Image.LANCZOS)
        rotated = card.rotate(-rotation, resample=Image.BICUBIC, expand=True)
        card_center_x = center_x + translation
        top = 26 + abs(translation) / max(abs(value) for value in PHONE_HAND_TRANSLATIONS) * 12
        x = round(card_center_x - rotated.width / 2)
        y = round(top + PHONE_CARD_HEIGHT / 2 - rotated.height / 2)

        shadow_alpha = rotated.getchannel("A").filter(ImageFilter.GaussianBlur(3.0))
        shadow = Image.new("RGBA", rotated.size, (0, 0, 0, 0))
        shadow.putalpha(shadow_alpha.point(lambda alpha: round(alpha * 0.48)))
        canvas.alpha_composite(shadow, (x - 1, y + 5))
        canvas.alpha_composite(rotated, (x, y))
    return canvas.convert("RGB")


def phone_edge_difference(card: Image.Image) -> float:
    """Mean local rim deviation from inner stock at Track-B hand size."""
    small = card.resize((PHONE_CARD_WIDTH, PHONE_CARD_HEIGHT), Image.LANCZOS).convert("RGBA")
    arr = np.asarray(small, dtype=np.float32)
    solid = arr[:, :, 3] > 245
    rings: list[np.ndarray] = []
    remaining = solid.copy()
    for _ in range(7):
        source = Image.fromarray(remaining.astype(np.uint8) * 255, mode="L")
        eroded = np.asarray(source.filter(ImageFilter.MinFilter(3))) > 0
        rings.append(remaining & ~eroded)
        remaining = eroded

    rgb = arr[:, :, :3]
    neutral = (rgb.max(axis=2) - rgb.min(axis=2) < 34) & (rgb.mean(axis=2) > 178)
    edge = (rings[0] | rings[1]) & neutral
    inner = (rings[4] | rings[5] | rings[6]) & neutral
    luminance = rgb[:, :, 0] * 0.2126 + rgb[:, :, 1] * 0.7152 + rgb[:, :, 2] * 0.0722
    if not edge.any() or not inner.any():
        return 0.0
    return float(np.mean(np.abs(luminance[edge] - luminance[inner].mean())))


def phone_corner_difference(card: Image.Image) -> float:
    """Mean local corner-rim deviation after Track-B hand-size downsampling."""
    small = card.resize((PHONE_CARD_WIDTH, PHONE_CARD_HEIGHT), Image.LANCZOS).convert("RGBA")
    arr = np.asarray(small, dtype=np.float32)
    solid = arr[:, :, 3] > 245
    rings: list[np.ndarray] = []
    remaining = solid.copy()
    for _ in range(7):
        source = Image.fromarray(remaining.astype(np.uint8) * 255, mode="L")
        eroded = np.asarray(source.filter(ImageFilter.MinFilter(3))) > 0
        rings.append(remaining & ~eroded)
        remaining = eroded

    rgb = arr[:, :, :3]
    neutral = (rgb.max(axis=2) - rgb.min(axis=2) < 34) & (rgb.mean(axis=2) > 178)
    yy, xx = np.mgrid[0:PHONE_CARD_HEIGHT, 0:PHONE_CARD_WIDTH]
    corner = (
        ((xx < 19) | (xx >= PHONE_CARD_WIDTH - 19)) &
        ((yy < 21) | (yy >= PHONE_CARD_HEIGHT - 21))
    )
    edge = (rings[0] | rings[1] | rings[2]) & neutral & corner
    inner = (rings[4] | rings[5] | rings[6]) & neutral & corner
    luminance = rgb[:, :, 0] * 0.2126 + rgb[:, :, 1] * 0.7152 + rgb[:, :, 2] * 0.0722
    if not edge.any() or not inner.any():
        return 0.0
    return float(np.mean(np.abs(luminance[edge] - luminance[inner].mean())))


def index_contrast(card: Image.Image) -> float:
    arr = np.asarray(card.convert("RGBA"), dtype=np.float32)
    luminance = (arr[:, :, 0] * 0.2126 + arr[:, :, 1] * 0.7152 + arr[:, :, 2] * 0.0722)
    zones = [
        luminance[:INDEX_ZONE_HEIGHT, :INDEX_ZONE_WIDTH],
        luminance[H - INDEX_ZONE_HEIGHT:, W - INDEX_ZONE_WIDTH:],
    ]
    alphas = [
        arr[:INDEX_ZONE_HEIGHT, :INDEX_ZONE_WIDTH, 3],
        arr[H - INDEX_ZONE_HEIGHT:, W - INDEX_ZONE_WIDTH:, 3],
    ]
    contrasts: list[float] = []
    for zone, alpha in zip(zones, alphas):
        opaque_values = zone[alpha > 250]
        contrasts.append(float(np.percentile(opaque_values, 90) - np.percentile(opaque_values, 10)))
    return min(contrasts)


def material_metrics(card: Image.Image) -> dict[str, float]:
    """Small review metrics for V2/V3 comparisons; not part of runtime rendering."""
    arr = np.asarray(card.convert("RGBA"), dtype=np.float32)
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3]
    paper = np.asarray(PAPER[:3], dtype=np.float32)
    yy, xx = np.mgrid[0:H, 0:W]
    distance_to_edge = np.minimum.reduce((xx, W - 1 - xx, yy, H - 1 - yy))
    protected = protected_index_mask()

    luminance = rgb[:, :, 0] * 0.2126 + rgb[:, :, 1] * 0.7152 + rgb[:, :, 2] * 0.0722
    blurred = np.asarray(
        Image.fromarray(np.clip(luminance, 0, 255).astype(np.uint8), mode="L")
        .filter(ImageFilter.GaussianBlur(4.0)),
        dtype=np.float32,
    )
    edge = (
        (distance_to_edge >= 2) & (distance_to_edge <= 15) &
        (alpha > 250) & ~protected
    )
    edge_texture_rms = float(np.sqrt(np.mean(np.square(luminance[edge] - blurred[edge]))))

    stock_distance = np.linalg.norm(rgb - paper[None, None, :], axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    printed_color = (
        (stock_distance > 52) & (chroma > 20) & (alpha > 250) &
        ~protected & (distance_to_edge > 20)
    )
    printed_chroma = chroma[printed_color]
    print_chroma = float(np.mean(printed_chroma)) if len(printed_chroma) else 0.0

    stock = (stock_distance < 32) & (alpha > 250) & (distance_to_edge > 20)
    stock_image = Image.fromarray(stock.astype(np.uint8) * 255, mode="L")
    stock = np.asarray(stock_image.filter(ImageFilter.MinFilter(17))) > 0
    stock_residual = luminance - np.asarray(
        Image.fromarray(np.clip(luminance, 0, 255).astype(np.uint8), mode="L")
        .filter(ImageFilter.GaussianBlur(8.0)),
        dtype=np.float32,
    )
    paper_grain_rms = float(np.sqrt(np.mean(np.square(stock_residual[stock]))))

    ink = (stock_distance > 52) & (alpha > 250) & ~protected
    ink_image = Image.fromarray(ink.astype(np.uint8) * 255, mode="L")
    ink_eroded = np.asarray(ink_image.filter(ImageFilter.MinFilter(3))) > 0
    ink_contour = ink & ~ink_eroded
    gradient_x = np.abs(np.diff(luminance, axis=1, prepend=luminance[:, :1]))
    gradient_y = np.abs(np.diff(luminance, axis=0, prepend=luminance[:1, :]))
    ink_edge_gradient = float(np.mean(np.hypot(gradient_x, gradient_y)[ink_contour]))
    return {
        "edge_texture_rms": round(edge_texture_rms, 3),
        "ink_edge_gradient": round(ink_edge_gradient, 3),
        "paper_grain_rms": round(paper_grain_rms, 3),
        "print_chroma": round(print_chroma, 3),
    }


def render_review(output: Path, card_codes: list[str]) -> None:
    output.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 156 * SS, index=1)
    ten_font = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 126 * SS, index=1)
    rendered: list[tuple[str, Image.Image]] = []
    rendered_by_code: dict[str, Image.Image] = {}
    report: list[dict[str, int | float | str]] = []
    with tempfile.TemporaryDirectory() as t:
        tmpdir = Path(t)
        for code in card_codes:
            rank, suit = parse_card_code(code)
            card, metadata = compose(rank, suit, font, ten_font, tmpdir)
            path = output / f"{code}.png"
            card.save(path)
            rendered.append((code, card))
            rendered_by_code[code] = card
            report.append({
                **metadata,
                **material_metrics(card),
                "code": code,
                "width": card.width,
                "height": card.height,
                "index_contrast": round(index_contrast(card), 3),
                "phone_corner_difference": round(phone_corner_difference(card), 3),
                "phone_edge_difference": round(phone_edge_difference(card), 3),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            })
        for code in PHONE_HAND_CARDS:
            if code in rendered_by_code:
                continue
            rank, suit = parse_card_code(code)
            card, _ = compose(rank, suit, font, ten_font, tmpdir)
            rendered_by_code[code] = card
    review_sheet(rendered, card_width=390).save(output / "card-patina-review.png")
    review_sheet(rendered, card_width=W).save(output / "card-patina-original-size.png")
    compact_contact_sheet(rendered).save(output / "card-patina-contact-sheet.png")
    phone_hand_fan(rendered_by_code).save(output / "card-patina-phone-hand.png")
    (output / "patina-report.json").write_text(
        json.dumps({"cards": report}, indent=2, sort_keys=True),
        encoding="utf-8",
    )
    print(f"{len(rendered)} review cards -> {output}")


def write_production() -> None:
    raise RuntimeError(
        "Direct V9 production writes are disabled. Use "
        "tools/gen_card_damage_v10_reviews.py --promote-production --backup-root <iCloud TEMP>."
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--review-output", type=Path,
                      help="render selected cards outside the production catalog")
    mode.add_argument("--write-production", action="store_true",
                      help="disabled legacy mode; use the staged V10 promotion command")
    parser.add_argument("--cards", default=",".join(REVIEW_CARDS),
                        help="comma-separated review codes, e.g. AS,KH,QC,10D")
    args = parser.parse_args()

    if args.write_production:
        write_production()
        return
    card_codes = [code.strip().upper() for code in args.cards.split(",") if code.strip()]
    if not card_codes:
        parser.error("--cards must contain at least one public asset code")
    render_review(args.review_output, card_codes)


if __name__ == "__main__":
    main()
