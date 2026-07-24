#!/usr/bin/env python3
"""Deterministic W2 card-back ageing from two decades of cared-for outdoor play."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "tasks/reviews/goty-2026-live-assets/current-cardback-single.png"
DEFAULT_OUTPUT = ROOT / "tasks/reviews/card-back-camping-v11"
VARIANT_NAMES = (
    "top_bottom_wear",
    "left_grip_wear",
    "right_grip_wear",
    "corner_softening",
    "shuffle_burnish",
    "local_print_fade",
    "shallow_flex_a",
    "shallow_flex_b",
    "edge_delamination",
    "repaired_flex",
)


def stable_seed(label: str) -> int:
    return int.from_bytes(hashlib.sha256(label.encode("utf-8")).digest()[:8], "big")


def rounded_hull(size: tuple[int, int], inset: int = 0) -> Image.Image:
    width, height = size
    mask = Image.new("L", size, 0)
    radius = max(1, round(width * 0.096) - inset)
    ImageDraw.Draw(mask).rounded_rectangle(
        (inset, inset, width - inset - 1, height - inset - 1),
        radius=radius,
        fill=255,
    )
    return mask


def low_frequency_noise(size: tuple[int, int], rng: np.random.Generator,
                        grid: tuple[int, int] = (23, 31), blur: float = 0.0) -> np.ndarray:
    samples = rng.random(grid, dtype=np.float32)
    image = Image.fromarray(np.uint8(samples * 255), "L").resize(size, Image.Resampling.BICUBIC)
    if blur:
        image = image.filter(ImageFilter.GaussianBlur(blur))
    values = np.asarray(image, dtype=np.float32) / 255
    return np.clip((values - values.min()) / max(1e-6, values.max() - values.min()), 0, 1)


def edge_wear(size: tuple[int, int], rng: np.random.Generator,
              intensity: float) -> np.ndarray:
    width, height = size
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    radius = round(width * .092)
    inset = max(2, round(width * .006))
    segment_count = int(rng.integers(8, 12))
    for _ in range(segment_count):
        side = int(rng.integers(0, 4))
        line_width = int(rng.integers(max(2, round(width * .003)), max(4, round(width * .007))))
        value = int(rng.integers(78, 128) * intensity)
        if side < 2:
            length = int(rng.uniform(width * .055, width * .145))
            x = int(rng.uniform(radius, width - radius - length))
            y = int(rng.uniform(width * .008, width * .019)) if side == 0 else height - int(rng.uniform(width * .008, width * .019))
            parts = int(rng.integers(2, 5))
            for part in range(parts):
                start = x + round(length * part / parts) + int(rng.uniform(0, length * .035))
                end = x + round(length * (part + 1) / parts) - int(rng.uniform(0, length * .055))
                if end > start:
                    draw.line((start, y + int(rng.integers(-2, 3)),
                               end, y + int(rng.integers(-2, 3))),
                              fill=value, width=max(1, line_width + int(rng.integers(-2, 3))))
        else:
            length = int(rng.uniform(height * .040, height * .110))
            y = int(rng.uniform(radius, height - radius - length))
            x = int(rng.uniform(width * .008, width * .019)) if side == 2 else width - int(rng.uniform(width * .008, width * .019))
            parts = int(rng.integers(2, 5))
            for part in range(parts):
                start = y + round(length * part / parts) + int(rng.uniform(0, length * .035))
                end = y + round(length * (part + 1) / parts) - int(rng.uniform(0, length * .055))
                if end > start:
                    draw.line((x + int(rng.integers(-2, 3)), start,
                               x + int(rng.integers(-2, 3)), end),
                              fill=value, width=max(1, line_width + int(rng.integers(-2, 3))))

    for corner_index in rng.choice(4, size=2, replace=False):
        corner_index = int(corner_index)
        if corner_index == 0:
            box, base_angle = (inset, inset, radius * 2, radius * 2), 180
        elif corner_index == 1:
            box, base_angle = (width - radius * 2, inset, width - inset, radius * 2), 270
        elif corner_index == 2:
            box, base_angle = (inset, height - radius * 2, radius * 2, height - inset), 90
        else:
            box, base_angle = (width - radius * 2, height - radius * 2,
                               width - inset, height - inset), 0
        start = base_angle + int(rng.uniform(5, 34))
        span = int(rng.uniform(18, 48))
        draw.arc(box, start=start, end=start + span,
                 fill=int(rng.integers(66, 106) * intensity),
                 width=int(rng.integers(max(2, round(width * .004)),
                                        max(4, round(width * .008)))))

    for _ in range(int(rng.integers(5, 10))):
        side = int(rng.integers(0, 4))
        fibre_width = int(rng.integers(1, 3))
        value = int(rng.integers(88, 146) * intensity)
        if side < 2:
            x = int(rng.uniform(radius, width - radius))
            y = inset if side == 0 else height - inset - 1
            length = int(rng.uniform(width * .012, width * .035))
            draw.line((x, y, x + length, y + int(rng.integers(-2, 3))),
                      fill=value, width=fibre_width)
        else:
            x = inset if side == 2 else width - inset - 1
            y = int(rng.uniform(radius, height - radius))
            length = int(rng.uniform(height * .008, height * .024))
            draw.line((x, y, x + int(rng.integers(-2, 3)), y + length),
                      fill=value, width=fibre_width)
    softened = np.asarray(mask.filter(ImageFilter.GaussianBlur(1.25)), dtype=np.float32) / 255
    grain = rng.random((height, width), dtype=np.float32)
    grain_image = Image.fromarray(np.uint8(grain * 255), "L").filter(ImageFilter.GaussianBlur(.75))
    grain = np.asarray(grain_image, dtype=np.float32) / 255
    return softened * (.52 + grain * .48)


def broad_surface_age(size: tuple[int, int], rng: np.random.Generator,
                      intensity: float) -> np.ndarray:
    width, height = size
    field = .72 + low_frequency_noise(size, rng, (13, 19), blur=8) * .28
    for _ in range(2):
        cx = int(rng.uniform(width * .25, width * .75))
        cy = int(rng.uniform(height * .22, height * .78))
        rx = int(rng.uniform(width * .13, width * .22))
        ry = int(rng.uniform(height * .07, height * .14))
        patch = ellipse_mask(size, (cx - rx, cy - ry, cx + rx, cy + ry),
                             blur=round(width * .045))
        field += patch * float(rng.uniform(.08, .18))
    grain = .88 + low_frequency_noise(size, rng, (97, 137)) * .12
    hull = np.asarray(rounded_hull(size, round(width * .018)), dtype=np.float32) / 255
    return np.clip(field, 0, 1) * grain * hull * intensity


def ellipse_mask(size: tuple[int, int], box: tuple[int, int, int, int],
                 blur: float) -> np.ndarray:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).ellipse(box, fill=255)
    return np.asarray(mask.filter(ImageFilter.GaussianBlur(blur)), dtype=np.float32) / 255


def soft_polyline(size: tuple[int, int], points: list[tuple[float, float]],
                  width: int, blur: float) -> np.ndarray:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).line(points, fill=255, width=width, joint="curve")
    return np.asarray(mask.filter(ImageFilter.GaussianBlur(blur)), dtype=np.float32) / 255


def alpha_composite_mask(base: Image.Image, color: tuple[int, int, int],
                         mask: np.ndarray) -> Image.Image:
    layer = Image.new("RGBA", base.size, (*color, 0))
    layer.putalpha(Image.fromarray(np.uint8(np.clip(mask, 0, 1) * 255), "L"))
    return Image.alpha_composite(base, layer)


def build_overlay(size: tuple[int, int], variant: int) -> tuple[Image.Image, dict]:
    rng = np.random.default_rng(stable_seed(f"w2-camping-v11:{variant}"))
    width, height = size
    layers: list[tuple[str, tuple[int, int, int], np.ndarray]] = []

    edge_intensity = 0.90 + float(rng.uniform(-0.06, 0.08))
    edge = edge_wear(size, rng, edge_intensity)
    layers.append(("exposed_edge_fibre", (174, 159, 134), edge))

    age_intensity = 0.158 + float(rng.uniform(-0.008, 0.010))
    age = broad_surface_age(size, rng, age_intensity)
    layers.append(("oxidised_surface_haze", (112, 104, 94), age))

    detail = VARIANT_NAMES[variant]
    if detail in {"left_grip_wear", "right_grip_wear"}:
        mask = ellipse_mask(size, (-round(width * .12), round(height * .30),
                                   round(width * .20), round(height * .67)),
                            round(width * .050))
        mask *= .052 + float(rng.uniform(0, .010))
        if detail == "right_grip_wear":
            mask = np.fliplr(mask)
        irregularity = .70 + low_frequency_noise(size, rng, (37, 53)) * .30
        layers.append((detail, (158, 146, 130), mask * irregularity))
    elif detail == "corner_softening":
        mask = ellipse_mask(size, (-18, -18, 92, 92), 11)
        mask = np.maximum(mask, np.flipud(np.fliplr(mask))) * 0.15
        layers.append((detail, (174, 158, 132), mask))
    elif detail == "shuffle_burnish":
        mask = ellipse_mask(size, (round(width * .20), round(height * .55),
                                    round(width * .80), round(height * .76)), 46) * 0.052
        mask *= .68 + low_frequency_noise(size, rng, (41, 31)) * .32
        layers.append((detail, (166, 153, 136), mask))
    elif detail == "local_print_fade":
        mask = ellipse_mask(size, (round(width * .22), round(height * .22),
                                    round(width * .78), round(height * .58)), 64) * 0.055
        layers.append((detail, (160, 148, 131), mask))
    elif detail in {"shallow_flex_a", "shallow_flex_b", "repaired_flex"}:
        if detail == "shallow_flex_a":
            points = [(round(width * .17), round(height * .67)),
                      (round(width * .42), round(height * .655)),
                      (round(width * .69), round(height * .668)),
                      (round(width * .84), round(height * .658))]
        else:
            points = [(round(width * .18), round(height * .30)),
                      (round(width * .38), round(height * .38)),
                      (round(width * .61), round(height * .47)),
                      (round(width * .80), round(height * .55))]
        core = soft_polyline(size, points, max(1, round(width * .002)), 0.65) * .19
        highlight = soft_polyline(size, [(x, y - 3) for x, y in points],
                                  max(2, round(width * .004)), 1.8) * .095
        shadow = soft_polyline(size, [(x, y + 3) for x, y in points],
                               max(2, round(width * .004)), 2.0) * .075
        layers.append(("flex_core", (118, 105, 86), core))
        layers.append(("flex_highlight", (160, 150, 137), highlight))
        layers.append(("flex_shadow", (10, 10, 10), shadow))
        if detail == "repaired_flex":
            tape = Image.new("L", size, 0)
            tape_draw = ImageDraw.Draw(tape)
            tape_draw.polygon([
                (round(width * .12), round(height * .275)),
                (round(width * .245), round(height * .32)),
                (round(width * .205), round(height * .47)),
                (round(width * .085), round(height * .425)),
            ], fill=255)
            tape_mask = np.asarray(tape.filter(ImageFilter.GaussianBlur(1.1)), dtype=np.float32) / 255
            tape_mask *= .075 * (.76 + low_frequency_noise(size, rng, (21, 29)) * .24)
            layers.append(("aged_cellulose_repair", (157, 141, 116), tape_mask))
            tape_edge = soft_polyline(
                size,
                [(round(width * .12), round(height * .275)),
                 (round(width * .245), round(height * .32))],
                2,
                0.8,
            ) * .075
            layers.append(("repair_light_edge", (186, 171, 146), tape_edge))
    elif detail == "edge_delamination":
        lip = Image.new("L", size, 0)
        lip_draw = ImageDraw.Draw(lip)
        y0, y1 = round(height * .47), round(height * .64)
        points = [(width - 3, y0), (width - 6, round((y0 + y1) * .5)), (width - 3, y1)]
        lip_draw.line(points, fill=47, width=max(2, round(width * .007)), joint="curve")
        lip_mask = np.asarray(lip.filter(ImageFilter.GaussianBlur(.7)), dtype=np.float32) / 255
        layers.append(("fibre_lip", (130, 114, 88), lip_mask))
        inset_shadow = soft_polyline(size, [(x - 5, y) for x, y in points], 2, 1.3) * .075
        layers.append(("delamination_shadow", (9, 9, 9), inset_shadow))

    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    layer_report = []
    for name, color, mask in layers:
        overlay = alpha_composite_mask(overlay, color, mask)
        layer_report.append({
            "name": name,
            "max_alpha": round(float(mask.max()), 4),
            "coverage_over_1_percent": round(float(np.count_nonzero(mask > .01) / mask.size), 5),
        })

    hull = np.asarray(rounded_hull(size), dtype=np.uint16)
    rgba = np.asarray(overlay, dtype=np.uint8).copy()
    rgba[:, :, 3] = ((rgba[:, :, 3].astype(np.uint16) * hull) // 255).astype(np.uint8)
    rgba[rgba[:, :, 3] == 0, :3] = 0
    return Image.fromarray(rgba, "RGBA"), {
        "variant": variant,
        "name": detail,
        "layers": layer_report,
        "alpha_coverage": round(float(np.count_nonzero(rgba[:, :, 3]) / (width * height)), 5),
        "alpha_max": int(rgba[:, :, 3].max()),
    }


def card_shadow(card: Image.Image) -> Image.Image:
    alpha = card.getchannel("A")
    shadow = Image.new("RGBA", card.size, (0, 0, 0, 0))
    blurred = alpha.filter(ImageFilter.GaussianBlur(max(2, round(card.width * .018))))
    shadow.putalpha(blurred.point(lambda value: round(value * .45)))
    return shadow


def make_atlas(cards: list[Image.Image]) -> Image.Image:
    thumb_size = (180, 252)
    canvas = Image.new("RGB", (thumb_size[0] * 5, thumb_size[1] * 2), (22, 19, 18))
    for index, card in enumerate(cards):
        canvas.paste(card.convert("RGB").resize(thumb_size, Image.Resampling.LANCZOS),
                     ((index % 5) * thumb_size[0], (index // 5) * thumb_size[1]))
    return canvas


def make_phone_fan(cards: list[Image.Image]) -> Image.Image:
    canvas = Image.new("RGBA", (1170, 540), (32, 29, 27, 255))
    chosen = [cards[index] for index in (6, 1, 4, 3, 8, 5, 0)]
    for card, x, angle in zip(chosen, (240, 350, 455, 565, 675, 785, 895), (-17, -11, -6, 0, 6, 11, 17)):
        scaled = card.resize((216, 302), Image.Resampling.LANCZOS)
        shadow = card_shadow(scaled).rotate(-angle, Image.Resampling.BICUBIC, expand=True)
        rotated = scaled.rotate(-angle, Image.Resampling.BICUBIC, expand=True)
        y = 92 + round(abs(x - 565) * .055)
        canvas.alpha_composite(shadow, (x - shadow.width // 2 + 8, y + 13))
        canvas.alpha_composite(rotated, (x - rotated.width // 2, y))
    return canvas.resize((390, 180), Image.Resampling.LANCZOS).convert("RGB")


def make_phone_size_gate(master: Image.Image, cards: list[Image.Image]) -> Image.Image:
    canvas = Image.new("RGBA", (780, 520), (32, 29, 27, 255))
    for index, card in enumerate((master, cards[4], cards[6], cards[9])):
        scaled = card.resize((184, 258), Image.Resampling.LANCZOS)
        shadow = card_shadow(scaled)
        x = 18 + index * 190
        canvas.alpha_composite(shadow, (x + 6, 16 + 9))
        canvas.alpha_composite(scaled, (x, 16))
    for index, card_index in enumerate((0, 1, 3, 4, 6, 8, 9)):
        scaled = cards[card_index].resize((104, 148), Image.Resampling.LANCZOS)
        x = 18 + index * 108
        canvas.alpha_composite(scaled, (x, 336))
    return canvas.resize((390, 260), Image.Resampling.LANCZOS).convert("RGB")


def make_detail_sheet(cards: list[Image.Image]) -> Image.Image:
    crops = []
    for index in (2, 3, 4, 5, 6, 8):
        card = cards[index]
        if index == 5:
            crop = card.crop((0, 850, 420, 1270))
        elif index in (3, 8):
            crop = card.crop((180, 600, 820, 1020))
        else:
            crop = card.crop((0, 0, 420, 420))
        crops.append(crop.resize((420, 300), Image.Resampling.LANCZOS).convert("RGB"))
    sheet = Image.new("RGB", (1260, 600), (22, 19, 18))
    for index, crop in enumerate(crops):
        sheet.paste(crop, ((index % 3) * 420, (index // 3) * 300))
    return sheet


def generate(source: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    master = Image.open(source).convert("RGBA")
    cards = []
    reports = []
    for variant in range(len(VARIANT_NAMES)):
        overlay, report = build_overlay(master.size, variant)
        card = Image.alpha_composite(master, overlay)
        card.putalpha(master.getchannel("A"))
        cards.append(card)
        reports.append(report)
        card.save(output / f"card-back-camping-{variant:02d}.png")
        overlay.save(output / f"card-back-camping-overlay-{variant:02d}.png")
    make_atlas(cards).save(output / "camping-damage-atlas.png")
    make_phone_fan(cards).save(output / "camping-damage-phone-fan.png")
    make_phone_size_gate(master, cards).save(output / "camping-damage-phone-size-gate.png")
    make_detail_sheet(cards).save(output / "camping-damage-details.png")
    contract = {
        "version": "V11-review",
        "source": str(source.relative_to(ROOT)) if source.is_relative_to(ROOT) else str(source),
        "story": "20 years of cared-for camping-table use; worn, never filthy",
        "variant_count": len(cards),
        "base_design_unchanged": True,
        "damage_composited_after_print": True,
        "forbidden": ["decorative scratch field", "brown dirt", "grease stain", "identity assignment"],
        "variants": reports,
    }
    (output / "camping-damage-report.json").write_text(
        json.dumps(contract, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    generate(args.source, args.output)


if __name__ == "__main__":
    main()
