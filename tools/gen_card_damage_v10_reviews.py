#!/usr/bin/env python3
"""Deterministic V10 review damage for V9 fronts and identity-neutral W2 backs."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import gen_cards_vector_public_domain as cards

ROOT = Path(__file__).resolve().parents[1]
FRONT_SOURCE = ROOT / "tasks/reviews/card-patina-v9-full-set"
BACK_SOURCE = ROOT / "tasks/reviews/goty-2026-live-assets/current-cardback-single.png"
PRODUCTION_CARDS = ROOT / "App/Assets.xcassets/Cards"
PRODUCTION_BACK_DAMAGE = ROOT / "App/Assets.xcassets/CardBackDamage"
PRODUCTION_MASTERS = ROOT / "Assets_Raw/cards/final"
ICLOUD_TEMP = Path("/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP")
CANONICAL_SIZE = (624, 888)
CANONICAL_2X = (312, 444)
CANONICAL_3X = (468, 666)
CANONICAL_CORNER_RADIUS = 96
FRONT_CODES = tuple(f"{rank}{suit}" for rank in ("A", "K", "Q", "J", "10", "9", "8", "7") for suit in ("S", "H", "C", "D"))
FRONT_DAMAGE_COUNTS = {"stress_line": 6, "repair_film": 3, "corner_fold": 5, "corner_chip": 2}
BACK_VARIANT_COUNT = 10
BACK_DAMAGE_PLAN = (
    "stress_line", "stress_line", "stress_line", "stress_line",
    "repair_film", "repair_film", "repair_film",
    "edge_compression", "edge_compression", "quiet",
)
BACK_PHONE_ORDER = (8, 1, 5, 2, 6, 3, 9)
BACK_MATERIAL_CONTRACT = {
    "version": "V10.2",
    "stress_line_luminance_reduction_percent": 40,
    "stress_line_segment_breaks": [2, 4],
    "stress_line_branches": [1, 2],
    "repair_film_opacity_range": [0.13, 0.15],
    "repair_film_width_range": [50, 66],
    "repair_film_reflection_edges": 1,
    "alpha_preserved": True,
}
PRODUCTION_VERSION = "V10.2"


def seed(label: str) -> int:
    return int.from_bytes(hashlib.sha256(label.encode()).digest()[:8], "big")


def front_plan() -> dict[str, str]:
    ordered = sorted(FRONT_CODES, key=lambda code: seed(f"v10-front:{code}"))
    plan = {code: "none" for code in FRONT_CODES}
    cursor = 0
    for damage, count in FRONT_DAMAGE_COUNTS.items():
        for code in ordered[cursor:cursor + count]:
            plan[code] = damage
        cursor += count
    return plan


def blend(image: Image.Image, color: tuple[int, int, int], mask: np.ndarray) -> Image.Image:
    arr = np.asarray(image.convert("RGBA"), dtype=np.float32).copy()
    amount = np.clip(mask, 0, 1)[:, :, None]
    arr[:, :, :3] = arr[:, :, :3] * (1 - amount) + np.asarray(color) * amount
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def soft_line_mask(size: tuple[int, int], points: list[tuple[float, float]], width: int = 1, blur: float = 0.7) -> np.ndarray:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).line(points, fill=255, width=width, joint="curve")
    return np.asarray(mask.filter(ImageFilter.GaussianBlur(blur)), dtype=np.float32) / 255


def irregular_back_path(rng: np.random.Generator, cx: int, cy: int, length: int,
                        angle: float, samples: int = 17) -> list[tuple[float, float]]:
    tangent = np.array((np.cos(angle), np.sin(angle)))
    normal = np.array((-np.sin(angle), np.cos(angle)))
    offsets = np.linspace(-length / 2, length / 2, samples)
    drift = np.cumsum(rng.normal(0, 1.55, samples))
    drift -= np.linspace(drift[0], drift[-1], samples)
    drift = np.clip(drift, -7.0, 7.0)
    center = np.array((cx, cy), dtype=np.float64)
    return [tuple(center + tangent * offset + normal * wobble)
            for offset, wobble in zip(offsets, drift)]


def interrupted_back_line(size: tuple[int, int], points: list[tuple[float, float]],
                          rng: np.random.Generator, width: int = 6,
                          blur: float = 1.05) -> tuple[np.ndarray, list[int]]:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    segment_count = len(points) - 1
    break_count = int(rng.integers(2, 5))
    candidates = np.arange(2, max(3, segment_count - 2))
    breaks = sorted(int(value) for value in rng.choice(candidates, size=break_count, replace=False))
    for index in range(segment_count):
        start = np.asarray(points[index])
        end = np.asarray(points[index + 1])
        if index in breaks:
            gap_start = float(rng.uniform(.38, .48))
            gap_end = gap_start + float(rng.uniform(.18, .28))
            draw.line((tuple(start), tuple(start + (end - start) * gap_start)), fill=255, width=width)
            draw.line((tuple(start + (end - start) * gap_end), tuple(end)), fill=255, width=width)
        else:
            draw.line((tuple(start), tuple(end)), fill=255, width=width)
    return (np.asarray(mask.filter(ImageFilter.GaussianBlur(blur)), dtype=np.float32) / 255,
            breaks)


def irregular_film_mask(size: tuple[int, int], points: list[tuple[float, float]],
                        angle: float, width: int, rng: np.random.Generator) -> tuple[np.ndarray, list[tuple[float, float]]]:
    normal = np.array((-np.sin(angle), np.cos(angle)))
    upper: list[tuple[float, float]] = []
    lower: list[tuple[float, float]] = []
    for index, point in enumerate(points):
        edge_taper = .82 if index in {0, len(points) - 1} else 1.0
        local_half_width = width * edge_taper / 2 + float(rng.uniform(-3.2, 3.2))
        center = np.asarray(point)
        upper.append(tuple(center + normal * local_half_width))
        lower.append(tuple(center - normal * local_half_width))
    source = Image.new("L", size, 0)
    ImageDraw.Draw(source).polygon(upper + list(reversed(lower)), fill=255)
    film = np.asarray(source.filter(ImageFilter.GaussianBlur(1.15)), dtype=np.float32) / 255
    return film, upper


def front_damage(image: Image.Image, code: str, damage: str) -> tuple[Image.Image, tuple[int, int, int, int] | None, int]:
    if damage == "none":
        return image, None, 0
    rng = np.random.default_rng(seed(f"v10-front-effect:{code}"))
    protected = cards.protected_index_mask()
    out = image.convert("RGBA")
    chip_pixels = 0

    if damage in {"stress_line", "repair_film"}:
        cx = int(rng.uniform(210, cards.W - 170))
        cy = int(rng.uniform(285, cards.H - 250))
        length = int(rng.integers(6, 19)) if damage == "stress_line" else int(rng.integers(42, 69))
        angle = float(rng.uniform(-0.75, 0.75))
        dx, dy = np.cos(angle) * length / 2, np.sin(angle) * length / 2
        points = [(cx - dx, cy - dy), (cx, cy + rng.uniform(-1.2, 1.2)), (cx + dx, cy + dy)]
        mask = soft_line_mask(out.size, points, width=1, blur=0.75)
        mask[protected] = 0
        out = blend(out, (176, 176, 174), mask * 0.10)
        bbox = (cx - length // 2 - 16, cy - 24, cx + length // 2 + 16, cy + 24)
        if damage == "repair_film":
            film = soft_line_mask(out.size, [points[0], points[-1]], width=int(rng.integers(9, 14)), blur=1.0)
            film[protected] = 0
            out = blend(out, (229, 228, 224), film * 0.11)
    elif damage == "corner_fold":
        top_right = bool(rng.integers(0, 2))
        extent = int(rng.integers(30, 46))
        mask = Image.new("L", out.size, 0)
        draw = ImageDraw.Draw(mask)
        if top_right:
            polygon = [(cards.W - extent, 0), (cards.W, 0), (cards.W, extent)]
            crease = [(cards.W - extent, 0), (cards.W, extent)]
            bbox = (cards.W - extent - 12, 0, cards.W, extent + 12)
        else:
            polygon = [(0, cards.H - extent), (0, cards.H), (extent, cards.H)]
            crease = [(0, cards.H - extent), (extent, cards.H)]
            bbox = (0, cards.H - extent - 12, extent + 12, cards.H)
        draw.polygon(polygon, fill=150)
        fold = np.asarray(mask.filter(ImageFilter.GaussianBlur(2.0)), dtype=np.float32) / 255
        out = blend(out, (205, 204, 201), fold * 0.18)
        line = soft_line_mask(out.size, crease, width=2, blur=1.4)
        out = blend(out, (237, 235, 230), line * 0.12)
    else:
        alpha = np.asarray(out.getchannel("A"), dtype=np.uint8).copy()
        depth = int(rng.integers(2, 6))
        bottom_left = bool(rng.integers(0, 2))
        center = 112 if bottom_left else cards.W - 112
        for offset in range(-depth, depth + 1):
            local = max(1, round(depth * (1 - abs(offset) / (depth + 1))))
            for inset in range(local):
                x = center + offset
                y = cards.H - 1 - inset if bottom_left else inset
                if 0 <= x < cards.W and 0 <= y < cards.H and alpha[y, x] > 0:
                    alpha[y, x] = 0
                    chip_pixels += 1
        out.putalpha(Image.fromarray(alpha, "L"))
        bbox = (center - 24, cards.H - 56, center + 24, cards.H) if bottom_left else (center - 24, 0, center + 24, 56)
    return out, tuple(max(0, int(v)) for v in bbox), chip_pixels


def damage_atlas(rendered: dict[str, Image.Image], entries: list[dict]) -> Image.Image:
    affected = [entry for entry in entries if entry["damage_type"] != "none"]
    tile_w, tile_h, label_h, columns = 180, 140, 22, 4
    rows = (len(affected) + columns - 1) // columns
    atlas = Image.new("RGB", (columns * tile_w, rows * (tile_h + label_h)), (24, 21, 20))
    draw = ImageDraw.Draw(atlas)
    for index, entry in enumerate(affected):
        bbox = entry["damage_bbox"]
        cx, cy = (bbox[0] + bbox[2]) // 2, (bbox[1] + bbox[3]) // 2
        left = min(max(0, cx - tile_w // 2), cards.W - tile_w)
        top = min(max(0, cy - tile_h // 2), cards.H - tile_h)
        crop = rendered[entry["code"]].crop((left, top, left + tile_w, top + tile_h)).convert("RGB")
        x, y = (index % columns) * tile_w, (index // columns) * (tile_h + label_h)
        atlas.paste(crop, (x, y))
        draw.text((x + 5, y + tile_h + 3), f'{entry["code"]} · {entry["damage_type"]}', fill=(222, 216, 205))
    return atlas


def build_front(output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    plan = front_plan()
    rendered, entries = {}, []
    for code in FRONT_CODES:
        source = Image.open(FRONT_SOURCE / f"{code}.png").convert("RGBA")
        result, bbox, chip_pixels = front_damage(source, code, plan[code])
        result.save(output / f"{code}.png")
        rendered[code] = result
        entries.append({
            "code": code, "damage_type": plan[code], "damage_bbox": bbox,
            "corner_chip_pixels": chip_pixels,
            "index_contrast": round(cards.index_contrast(result), 3),
            "sha256": hashlib.sha256((output / f"{code}.png").read_bytes()).hexdigest(),
        })
    ordered = [(code, rendered[code]) for code in FRONT_CODES]
    cards.compact_contact_sheet(ordered).save(output / "card-patina-contact-sheet.png")
    cards.review_sheet(ordered, 390).save(output / "card-patina-review.png")
    cards.review_sheet(ordered, cards.W).save(output / "card-patina-original-size.png")
    cards.phone_hand_fan(rendered).save(output / "card-patina-phone-hand.png")
    damage_atlas(rendered, entries).save(output / "damage-atlas.png")
    distribution = {damage: sum(entry["damage_type"] == damage for entry in entries) for damage in (*FRONT_DAMAGE_COUNTS, "none")}
    (output / "damage-report.json").write_text(json.dumps({"distribution": distribution, "cards": entries}, indent=2, sort_keys=True))


def back_effect_layers(size: tuple[int, int], variant: int) -> tuple[list[tuple[tuple[int, int, int], np.ndarray]], tuple[int, int, int, int] | None]:
    rng = np.random.default_rng(seed(f"v10.2-back:{variant}"))
    width, height = size
    scale = min(width / 1000, height / 1400)
    damage = BACK_DAMAGE_PLAN[variant - 1]
    layers: list[tuple[tuple[int, int, int], np.ndarray]] = []
    bbox = None
    if damage in {"stress_line", "repair_film"}:
        cx, cy = int(rng.uniform(width * .34, width * .66)), int(rng.uniform(height * .18, height * .32))
        base_length = int(rng.integers(155, 236)) if damage == "stress_line" else int(rng.integers(245, 331))
        length = max(1, round(base_length * scale))
        angle = float(rng.uniform(-0.38, 0.38))
        if damage == "stress_line":
            points = irregular_back_path(rng, cx, cy, length, angle)
            light, breaks = interrupted_back_line(
                size, points, rng, width=max(1, round(6 * scale)), blur=max(.55, 1.05 * scale)
            )
            layers.append(((156, 151, 148), light * 0.42))
            shadow = soft_line_mask(
                size, [(x, y + 3 * scale) for x, y in points],
                width=max(1, round(2 * scale)), blur=max(.5, 1.1 * scale),
            )
            shadow *= (light > .02)
            layers.append(((11, 11, 12), shadow * 0.14))
            branch_count = int(rng.integers(1, 3))
            available = [index for index in range(4, len(points) - 4) if index not in breaks]
            for branch_index in rng.choice(available, size=branch_count, replace=False):
                origin = np.asarray(points[int(branch_index)])
                branch_angle = angle + float(rng.choice((-1, 1))) * float(rng.uniform(.43, .72))
                branch_length = int(rng.integers(27, 44)) * scale
                direction = np.array((np.cos(branch_angle), np.sin(branch_angle)))
                end = tuple(origin + direction * branch_length)
                branch = soft_line_mask(
                    size, [tuple(origin), end], width=max(1, round(3 * scale)),
                    blur=max(.45, .85 * scale),
                )
                layers.append(((145, 140, 137), branch * 0.29))
            pad_y = round(42 * scale)
        else:
            points = irregular_back_path(rng, cx, cy, length, angle, samples=11)
            film_width = max(1, round(int(rng.integers(50, 67)) * scale))
            film, upper_edge = irregular_film_mask(size, points, angle, film_width, rng)
            film_opacity = float(rng.uniform(.13, .15))
            layers.append(((68, 66, 66), film * film_opacity))
            repaired_stress, _ = interrupted_back_line(
                size, points, rng, width=max(1, round(4 * scale)), blur=max(.5, scale),
            )
            layers.append(((121, 117, 114), repaired_stress * 0.16))
            reflection_points = upper_edge[1:-2]
            reflection = soft_line_mask(
                size, reflection_points, width=max(1, round(2 * scale)),
                blur=max(.45, .8 * scale),
            )
            reflection *= film
            layers.append(((137, 132, 128), reflection * 0.15))
            pad_y = film_width
        bbox = (max(0, cx - length // 2 - round(28 * scale)), max(0, cy - pad_y),
                min(width, cx + length // 2 + round(28 * scale)), min(height, cy + pad_y))
    elif damage == "edge_compression":
        mask = np.zeros((height, width), dtype=np.float32)
        if variant == 8:
            band_depth = max(1, round(82 * scale))
            band = np.linspace(0, .64, band_depth, dtype=np.float32)
            mask[-band_depth:, int(width * .20):int(width * .72)] = band[:, None]
            bbox = (int(width * .14), height - round(205 * scale), int(width * .78), height)
        else:
            band_depth = max(1, round(78 * scale))
            band = np.linspace(0, .64, band_depth, dtype=np.float32)
            mask[int(height * .36):int(height * .78), -band_depth:] = band[None, :]
            bbox = (width - round(180 * scale), int(height * .32), width, int(height * .82))
        layers.append(((118, 114, 112), mask * 0.78))
    return layers, bbox


def back_variant(master: Image.Image, variant: int) -> tuple[Image.Image, tuple[int, int, int, int] | None]:
    out = master.convert("RGBA")
    layers, bbox = back_effect_layers(out.size, variant)
    for color, mask in layers:
        out = blend(out, color, mask)
    out.putalpha(master.convert("RGBA").getchannel("A"))
    return out, bbox


def back_damage_overlay(size: tuple[int, int], variant: int) -> Image.Image:
    """Return only V10.2 material damage on a transparent canonical card canvas."""
    layers, _ = back_effect_layers(size, variant)
    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    for color, mask in layers:
        alpha = Image.fromarray(np.clip(mask * 255, 0, 255).astype(np.uint8), "L")
        layer = Image.new("RGBA", size, (*color, 0))
        layer.putalpha(alpha)
        overlay = Image.alpha_composite(overlay, layer)

    silhouette = Image.new("L", size, 0)
    radius = round(CANONICAL_CORNER_RADIUS * size[0] / CANONICAL_SIZE[0])
    ImageDraw.Draw(silhouette).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255
    )
    alpha = np.asarray(overlay.getchannel("A"), dtype=np.uint16)
    hull = np.asarray(silhouette, dtype=np.uint16)
    clipped_alpha = ((alpha * hull) // 255).astype(np.uint8)
    rgba = np.asarray(overlay, dtype=np.uint8).copy()
    rgba[:, :, 3] = clipped_alpha
    rgba[clipped_alpha == 0, :3] = 0
    return Image.fromarray(rgba, "RGBA")


def back_phone_fan(variants: list[Image.Image]) -> Image.Image:
    canvas = Image.new("RGBA", (390, 180), (28, 25, 24, 255))
    selected = [variants[index - 1] for index in BACK_PHONE_ORDER]
    for image, x, angle in zip(selected, (-116, -78, -40, 0, 40, 78, 116), (-20, -13, -7, 0, 7, 13, 20)):
        card = image.resize((72, 103), Image.LANCZOS).rotate(-angle, Image.BICUBIC, expand=True)
        canvas.alpha_composite(card, (round(195 + x - card.width / 2), round(32 + abs(x) * .08)))
    return canvas.convert("RGB")


def back_damage_crops(variants: list[Image.Image], entries: list[dict]) -> Image.Image:
    affected = [entry for entry in entries if entry["damage_bbox"] is not None]
    crop_w, crop_h, label_h, columns = 380, 240, 22, 3
    rows = (len(affected) + columns - 1) // columns
    atlas = Image.new("RGB", (columns * crop_w, rows * (crop_h + label_h)), (18, 16, 17))
    draw = ImageDraw.Draw(atlas)
    for index, entry in enumerate(affected):
        bbox = entry["damage_bbox"]
        cx, cy = (bbox[0] + bbox[2]) // 2, (bbox[1] + bbox[3]) // 2
        left = min(max(0, cx - crop_w // 2), 1000 - crop_w)
        top = min(max(0, cy - crop_h // 2), 1400 - crop_h)
        crop = variants[entry["variant"] - 1].crop((left, top, left + crop_w, top + crop_h)).convert("RGB")
        x, y = (index % columns) * crop_w, (index // columns) * (crop_h + label_h)
        atlas.paste(crop, (x, y))
        draw.text((x + 5, y + crop_h + 3), f'V{entry["variant"]:02d} · {entry["primary_damage"]}', fill=(222, 216, 205))
    return atlas


def build_back(output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    master = Image.open(BACK_SOURCE).convert("RGBA")
    variants, entries = [], []
    alpha_hash = hashlib.sha256(master.getchannel("A").tobytes()).hexdigest()
    for index in range(1, BACK_VARIANT_COUNT + 1):
        result, damage_bbox = back_variant(master, index)
        path = output / f"back-variant-{index:02d}.png"
        result.save(path)
        variants.append(result)
        entries.append({"variant": index, "primary_damage": BACK_DAMAGE_PLAN[index - 1], "damage_bbox": damage_bbox, "alpha_sha256": hashlib.sha256(result.getchannel("A").tobytes()).hexdigest(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    thumb_w, thumb_h = 160, 224
    atlas = Image.new("RGB", (thumb_w * 5, thumb_h * 2), (18, 16, 17))
    for index, variant in enumerate(variants):
        atlas.paste(variant.convert("RGB").resize((thumb_w, thumb_h), Image.LANCZOS), ((index % 5) * thumb_w, (index // 5) * thumb_h))
    atlas.save(output / "back-damage-atlas.png")
    back_phone_fan(variants).save(output / "back-phone-hand.png")
    back_damage_crops(variants, entries).save(output / "back-damage-crops-1x.png")
    distribution = {damage: sum(entry["primary_damage"] == damage for entry in entries) for damage in ("stress_line", "repair_film", "edge_compression", "quiet")}
    (output / "back-damage-report.json").write_text(json.dumps({"variant_count": BACK_VARIANT_COUNT, "canvas": list(master.size), "source_alpha_sha256": alpha_hash, "distribution": distribution, "phone_variant_order": BACK_PHONE_ORDER, "material_contract": BACK_MATERIAL_CONTRACT, "variants": entries}, indent=2, sort_keys=True))


def production_card_identities() -> list[tuple[str, str, str]]:
    return [
        (f"card_{suit_name}_{rank_name}", f"{rank_code}{suit_code}", f"{rank_code}{suit_code}.svg")
        for suit_code, suit_name, _ in cards.SUITS
        for rank_code, rank_name in cards.RANKS
    ]


def clean_transparent_rgb(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    rgba[rgba[:, :, 3] == 0, :3] = 0
    return Image.fromarray(rgba, "RGBA")


def write_back_damage_imageset(catalog: Path, index: int, overlay: Image.Image) -> None:
    name = f"card_back_damage_{index:02d}"
    imageset = catalog / f"{name}.imageset"
    imageset.mkdir(parents=True, exist_ok=False)
    for scale, size in (("2x", CANONICAL_2X), ("3x", CANONICAL_3X)):
        rendered = clean_transparent_rgb(overlay.resize(size, Image.LANCZOS))
        rendered.save(imageset / f"{name}@{scale}.png")
    (imageset / "Contents.json").write_text(json.dumps({
        "images": [
            {"idiom": "universal", "scale": "1x"},
            {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": f"{name}@3x.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }, indent=2), encoding="utf-8")


def rounded_hull(size: tuple[int, int]) -> np.ndarray:
    hull = Image.new("L", size, 0)
    radius = round(CANONICAL_CORNER_RADIUS * size[0] / CANONICAL_SIZE[0])
    ImageDraw.Draw(hull).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255
    )
    return np.asarray(hull, dtype=np.uint8)


def png_record(path: Path) -> dict[str, int | str]:
    image = Image.open(path)
    record: dict[str, int | str] = {
        "width": image.width,
        "height": image.height,
        "mode": image.mode,
    }
    if "A" in image.getbands():
        record["alpha_sha256"] = hashlib.sha256(image.getchannel("A").tobytes()).hexdigest()
    return record


def production_manifest(roots: dict[str, Path]) -> dict:
    files: list[dict] = []
    for label, root in sorted(roots.items()):
        if not root.exists():
            continue
        for path in sorted(item for item in root.rglob("*") if item.is_file()):
            entry: dict[str, object] = {
                "path": f"{label}/{path.relative_to(root).as_posix()}",
                "bytes": path.stat().st_size,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
            if path.suffix.lower() == ".png":
                entry["png"] = png_record(path)
            files.append(entry)
    return {
        "schema": 1,
        "production_version": PRODUCTION_VERSION,
        "files": files,
    }


def write_json(path: Path, payload: object) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def validate_contents(contents_path: Path, name: str) -> None:
    contents = json.loads(contents_path.read_text(encoding="utf-8"))
    scales = {entry.get("scale"): entry.get("filename") for entry in contents.get("images", [])}
    if scales != {
        "1x": None,
        "2x": f"{name}@2x.png",
        "3x": f"{name}@3x.png",
    }:
        raise RuntimeError(f"{contents_path}: canonical empty-1x/2x/3x structure changed")


def validate_production_layout(cards_root: Path, masters_root: Path,
                               back_root: Path, report: dict) -> None:
    identities = production_card_identities()
    expected_card_sets = {f"{name}.imageset" for name, _, _ in identities}
    actual_card_sets = {path.name for path in cards_root.glob("*.imageset") if path.is_dir()}
    if actual_card_sets != expected_card_sets:
        raise RuntimeError("Staged Cards catalog must contain exactly 32 canonical imagesets")
    expected_masters = {f"{name}.png" for name, _, _ in identities}
    actual_masters = {path.name for path in masters_root.glob("*.png")}
    if actual_masters != expected_masters:
        raise RuntimeError("Staged raw output must contain exactly 32 V10 masters")

    for name, _, _ in identities:
        imageset = cards_root / f"{name}.imageset"
        files = {path.name for path in imageset.iterdir() if path.is_file()}
        if files != {"Contents.json", f"{name}@2x.png", f"{name}@3x.png"}:
            raise RuntimeError(f"{imageset}: unexpected staged files")
        validate_contents(imageset / "Contents.json", name)
        expected_contents = PRODUCTION_CARDS / f"{name}.imageset/Contents.json"
        if expected_contents.exists() and (imageset / "Contents.json").read_bytes() != expected_contents.read_bytes():
            raise RuntimeError(f"{name}: existing Contents.json was not preserved byte-for-byte")
        if Image.open(imageset / f"{name}@2x.png").size != CANONICAL_2X:
            raise RuntimeError(f"{name}: invalid 2x dimensions")
        if Image.open(imageset / f"{name}@3x.png").size != CANONICAL_3X:
            raise RuntimeError(f"{name}: invalid 3x dimensions")
        master = Image.open(masters_root / f"{name}.png")
        if master.size != CANONICAL_SIZE or master.mode != "RGBA":
            raise RuntimeError(f"{name}: raw master must be 624x888 RGBA")

    expected_back_sets = {f"card_back_damage_{index:02d}.imageset" for index in range(10)}
    actual_back_sets = {path.name for path in back_root.glob("*.imageset") if path.is_dir()}
    if actual_back_sets != expected_back_sets:
        raise RuntimeError("Staged CardBackDamage catalog must contain exactly 10 imagesets")
    for index in range(10):
        name = f"card_back_damage_{index:02d}"
        imageset = back_root / f"{name}.imageset"
        files = {path.name for path in imageset.iterdir() if path.is_file()}
        if files != {"Contents.json", f"{name}@2x.png", f"{name}@3x.png"}:
            raise RuntimeError(f"{imageset}: unexpected staged files")
        validate_contents(imageset / "Contents.json", name)
        for scale, size in (("2x", CANONICAL_2X), ("3x", CANONICAL_3X)):
            image = Image.open(imageset / f"{name}@{scale}.png").convert("RGBA")
            if image.size != size:
                raise RuntimeError(f"{name}: invalid {scale} dimensions")
            rgba = np.asarray(image, dtype=np.uint8)
            alpha = rgba[:, :, 3]
            hull = rounded_hull(size)
            if np.any(alpha[hull == 0] != 0):
                raise RuntimeError(f"{name}: damage escaped the canonical rounded alpha hull")
            if np.any(rgba[alpha == 0, :3] != 0):
                raise RuntimeError(f"{name}: transparent pixels contain a baked RGB base")
            coverage = float(np.count_nonzero(alpha) / alpha.size)
            if index == 9:
                if coverage != 0:
                    raise RuntimeError("Quiet back overlay must remain fully transparent")
            elif not (0 < coverage < .13):
                raise RuntimeError(f"{name}: overlay coverage suggests a missing or baked base")
            center = alpha[round(size[1] * .35):round(size[1] * .65),
                           round(size[0] * .30):round(size[0] * .70)]
            if np.any(center):
                raise RuntimeError(f"{name}: center contains a baked W2 signet/base")

    if report["front_distribution"] != {
        "stress_line": 6, "repair_film": 3, "corner_fold": 5,
        "corner_chip": 2, "none": 16,
    }:
        raise RuntimeError("V10 front damage distribution changed during staging")


def actool_validate(cards_root: Path, back_root: Path) -> dict[str, str | int]:
    actool = subprocess.run(
        ["xcrun", "--find", "actool"], check=True, capture_output=True, text=True
    ).stdout.strip()
    with tempfile.TemporaryDirectory(prefix="poch-v10-actool-") as temporary:
        temporary_root = Path(temporary)
        catalog = temporary_root / "V10Validation.xcassets"
        catalog.mkdir()
        (catalog / "Contents.json").write_text(
            '{"info":{"author":"xcode","version":1}}\n', encoding="utf-8"
        )
        shutil.copytree(cards_root, catalog / "Cards")
        shutil.copytree(back_root, catalog / "CardBackDamage")
        compiled = temporary_root / "compiled"
        compiled.mkdir()
        partial = temporary_root / "partial.plist"
        result = subprocess.run([
            actool, str(catalog), "--compile", str(compiled),
            "--platform", "iphoneos", "--minimum-deployment-target", "17.0",
            "--target-device", "iphone", "--output-partial-info-plist", str(partial),
        ], capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"actool rejected staged V10 assets:\n{result.stdout}\n{result.stderr}")
        return {
            "exit_code": result.returncode,
            "tool": actool,
            "warnings": result.stderr.strip(),
        }


def build_production_stage(output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=False)
    cards_stage = output / "Cards"
    masters_stage = output / "final"
    back_stage = output / "CardBackDamage"
    cards_stage.mkdir()
    masters_stage.mkdir()
    back_stage.mkdir()
    font = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 156 * cards.SS, index=1)
    ten_font = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 126 * cards.SS, index=1)
    plan = front_plan()
    front_entries: list[dict] = []
    with tempfile.TemporaryDirectory(prefix="poch-v10-front-render-") as temporary:
        render_tmp = Path(temporary)
        for name, code, _ in production_card_identities():
            rank, suit = cards.parse_card_code(code)
            base, _ = cards.compose(rank, suit, font, ten_font, render_tmp)
            result, bbox, chip_pixels = front_damage(base, code, plan[code])
            master_path = masters_stage / f"{name}.png"
            result.save(master_path)
            contents_path = PRODUCTION_CARDS / f"{name}.imageset/Contents.json"
            template = contents_path.read_bytes() if contents_path.exists() else None
            cards.write_imageset(name, result, catalog=cards_stage, contents_template=template)
            front_entries.append({
                "asset_name": name,
                "code": code,
                "damage_type": plan[code],
                "damage_bbox": bbox,
                "corner_chip_pixels": chip_pixels,
                "sha256": hashlib.sha256(master_path.read_bytes()).hexdigest(),
            })

    back_entries: list[dict] = []
    for index in range(BACK_VARIANT_COUNT):
        variant = index + 1
        overlay = back_damage_overlay(CANONICAL_SIZE, variant)
        write_back_damage_imageset(back_stage, index, overlay)
        alpha = np.asarray(overlay.getchannel("A"), dtype=np.uint8)
        back_entries.append({
            "asset_name": f"card_back_damage_{index:02d}",
            "source_variant": variant,
            "damage_type": BACK_DAMAGE_PLAN[index],
            "master_canvas": list(CANONICAL_SIZE),
            "alpha_coverage": round(float(np.count_nonzero(alpha) / alpha.size), 7),
            "alpha_sha256": hashlib.sha256(alpha.tobytes()).hexdigest(),
        })
    distribution = {
        damage: sum(entry["damage_type"] == damage for entry in front_entries)
        for damage in (*FRONT_DAMAGE_COUNTS, "none")
    }
    report = {
        "production_version": PRODUCTION_VERSION,
        "front_distribution": distribution,
        "fronts": front_entries,
        "back_material_contract": BACK_MATERIAL_CONTRACT,
        "back_overlays": back_entries,
    }
    validate_production_layout(cards_stage, masters_stage, back_stage, report)
    report["actool"] = actool_validate(cards_stage, back_stage)
    write_json(output / "production-report.json", report)
    return report


def production_roots(cards_root: Path, masters_root: Path,
                     back_root: Path) -> dict[str, Path]:
    return {
        "App/Assets.xcassets/CardBackDamage": back_root,
        "App/Assets.xcassets/Cards": cards_root,
        "Assets_Raw/cards/final": masters_root,
    }


def assert_clean_production_paths() -> None:
    result = subprocess.run([
        "git", "status", "--porcelain=v1", "--untracked-files=all", "--",
        str(PRODUCTION_CARDS.relative_to(ROOT)),
        str(PRODUCTION_BACK_DAMAGE.relative_to(ROOT)),
    ], cwd=ROOT, check=True, capture_output=True, text=True)
    if result.stdout.strip():
        raise RuntimeError(
            "Production card paths are dirty; refusing to stage or replace anything:\n"
            + result.stdout.rstrip()
        )


def create_backup(backup_root: Path, before_manifest: dict) -> Path:
    if backup_root.resolve() != ICLOUD_TEMP.resolve():
        raise RuntimeError(f"Backup root must be the canonical iCloud TEMP folder: {ICLOUD_TEMP}")
    backup_root.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = backup_root / f"poch1441-card-v10-production-backup-{timestamp}-{uuid.uuid4().hex[:8]}"
    backup.mkdir(exist_ok=False)
    shutil.copytree(PRODUCTION_CARDS, backup / "Cards")
    shutil.copytree(PRODUCTION_MASTERS, backup / "Assets_Raw_cards_final")
    if PRODUCTION_BACK_DAMAGE.exists():
        shutil.copytree(PRODUCTION_BACK_DAMAGE, backup / "CardBackDamage")
    write_json(backup / "manifest-before.json", before_manifest)
    metadata = {
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "production_version": PRODUCTION_VERSION,
        "git_head": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
            capture_output=True, text=True,
        ).stdout.strip(),
    }
    write_json(backup / "backup-metadata.json", metadata)
    backup_roots = {
        "App/Assets.xcassets/Cards": backup / "Cards",
        "Assets_Raw/cards/final": backup / "Assets_Raw_cards_final",
    }
    if (backup / "CardBackDamage").exists():
        backup_roots["App/Assets.xcassets/CardBackDamage"] = backup / "CardBackDamage"
    if production_manifest(backup_roots) != before_manifest:
        raise RuntimeError("iCloud backup manifest does not match production before-state")
    return backup


def replace_production_from_stage(stage: Path, backup: Path,
                                  stage_manifest: dict, report: dict) -> None:
    transaction = uuid.uuid4().hex[:8]
    targets = [
        (stage / "Cards", PRODUCTION_CARDS),
        (stage / "final", PRODUCTION_MASTERS),
        (stage / "CardBackDamage", PRODUCTION_BACK_DAMAGE),
    ]
    previous: list[tuple[Path, Path | None]] = []
    try:
        for staged, destination in targets:
            rollback = destination.parent / f".{destination.name}.v10-previous-{transaction}"
            old = None
            if destination.exists():
                os.replace(destination, rollback)
                old = rollback
            previous.append((destination, old))
            os.replace(staged, destination)
        validate_production_layout(
            PRODUCTION_CARDS, PRODUCTION_MASTERS, PRODUCTION_BACK_DAMAGE, report
        )
        after_manifest = production_manifest(production_roots(
            PRODUCTION_CARDS, PRODUCTION_MASTERS, PRODUCTION_BACK_DAMAGE
        ))
        if after_manifest != stage_manifest:
            raise RuntimeError("After-manifest differs from the fully validated stage")
        write_json(backup / "manifest-after.json", after_manifest)
    except Exception:
        for destination, old in reversed(previous):
            if destination.exists():
                shutil.rmtree(destination)
            if old is not None and old.exists():
                os.replace(old, destination)
        raise
    for _, old in previous:
        if old is not None and old.exists():
            shutil.rmtree(old)


def promote_production(backup_root: Path) -> Path:
    assert_clean_production_paths()
    if not PRODUCTION_CARDS.is_dir() or not PRODUCTION_MASTERS.is_dir():
        raise RuntimeError("Existing Cards catalog and ignored raw masters are required for backup")
    before = production_manifest(production_roots(
        PRODUCTION_CARDS, PRODUCTION_MASTERS, PRODUCTION_BACK_DAMAGE
    ))
    backup = create_backup(backup_root, before)
    stage = ROOT / f".card-v10-production-stage-{uuid.uuid4().hex[:8]}"
    try:
        report = build_production_stage(stage)
        stage_manifest = production_manifest(production_roots(
            stage / "Cards", stage / "final", stage / "CardBackDamage"
        ))
        write_json(backup / "manifest-stage.json", stage_manifest)
        shutil.copy2(stage / "production-report.json", backup / "production-report.json")
        assert_clean_production_paths()
        replace_production_from_stage(stage, backup, stage_manifest, report)
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    return backup


def main() -> None:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--front-output", type=Path)
    mode.add_argument("--back-output", type=Path)
    mode.add_argument("--stage-production", type=Path,
                      help="build and validate a complete V10 production stage without installing it")
    mode.add_argument("--promote-production", action="store_true",
                      help="backup, stage, validate, then atomically install V10 production assets")
    parser.add_argument("--backup-root", type=Path,
                        help="required iCloud TEMP root for --promote-production")
    args = parser.parse_args()
    if args.front_output:
        build_front(args.front_output)
    elif args.back_output:
        build_back(args.back_output)
    elif args.stage_production:
        build_production_stage(args.stage_production)
        print(f"Validated V10 production stage -> {args.stage_production}")
    else:
        if args.backup_root is None:
            parser.error("--promote-production requires --backup-root")
        backup = promote_production(args.backup_root)
        print(f"Promoted V10.2 production assets; backup + manifests -> {backup}")


if __name__ == "__main__":
    main()
