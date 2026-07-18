#!/usr/bin/env python3
"""Build the deterministic presentation assets for the Track-A disc.

The canonical disc remains the geometry and detail source. A cleaned base keeps
its opaque body, sidewall and controlled edge antialiasing while removing only
the baked external shadow. A transparent overlay then grades measured material
zones after asset normalization. Both assets are deterministic and contain no
semantic labels or runtime noise.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "App/Assets.xcassets/PochDiscMaterialGrade.imageset/poch-disc-material-grade.png"
CLEAN_BASE_OUTPUT = ROOT / "App/Assets.xcassets/PochDiscCleanBase.imageset/poch-disc-clean-base.png"
SOURCE = ROOT / "App/Assets.xcassets/PochDisc2026.imageset/poch-disc-2026.png"
SIZE = 1254

# Stage 2 color contract, measured from the binding reference under the same
# north-west key light. Gamma maps the source P90/P10 luminance ratio to 4.22x
# while the chromaticity fixes the robust body median at muted slate blue.
GRAPHITE_TARGET_SRGB = (47, 56, 69)
GRAPHITE_CONTRAST_GAMMA = 1.315
GRAPHITE_LIGHT_CENTER_SRGB = (49.0, 58.5, 72.5)
GRAPHITE_LIGHT_VERTICAL_DELTA = (-32.0, -32.0, -33.0)
GRAPHITE_LOWER_BOUNCE_SRGB = (12.0, 12.0, 13.0)
GRAPHITE_DETAIL_SIGMA_RATIO = 0.065
WELL_METAL_TARGET_SRGB = (135, 138, 140)
WELL_METAL_CONTRAST_GAMMA = 1.08
CENTER_LIP_TARGET_SRGB = (40, 46, 57)
CENTER_LIP_CONTRAST_GAMMA = 0.45
ASSET_SCALE = 1.26
ASSET_OFFSET = (0.0010, 0.0372)

WELLS = {
    "king": (0.5000, 0.1463),
    "queen": (0.7311, 0.2358),
    "mariage": (0.8426, 0.4639),
    "jack": (0.7462, 0.7080),
    "ten": (0.4990, 0.8135),
    "sequence": (0.2498, 0.7100),
    "poch": (0.1564, 0.4649),
    "ace": (0.2679, 0.2358),
    "center": (0.5000, 0.5000),
}


def noise_field(grid: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    field = Image.new("L", (grid, grid))
    field.putdata([rng.randrange(256) for _ in range(grid * grid)])
    return field.resize((SIZE, SIZE), Image.Resampling.BICUBIC)


def circle(draw: ImageDraw.ImageDraw, center: tuple[float, float], radius: float, fill: int) -> None:
    cx, cy = center
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=fill)


def ring(draw: ImageDraw.ImageDraw,
         center: tuple[float, float],
         outer_radius: float,
         inner_radius: float,
         fill: int) -> None:
    circle(draw, center, outer_radius, fill)
    circle(draw, center, inner_radius, 0)


def normalized_center(value: tuple[float, float]) -> tuple[float, float]:
    return value[0] * SIZE, value[1] * SIZE


def build_graphite_mask() -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)
    circle(draw, (SIZE * 0.5, SIZE * 0.5), SIZE * 0.458, 255)
    for name, normalized in WELLS.items():
        # The raised centre bowl reaches beyond its visible inner lip. Preserve
        # its complete source relief and lower cast shadow.
        radius = SIZE * (0.168 if name == "center" else 0.087)
        circle(draw, normalized_center(normalized), radius, 0)
    return mask.filter(ImageFilter.GaussianBlur(radius=1.8))


def normalized_source() -> Image.Image:
    """Mirror `normalizedPochDiscAsset` in presentation-pixel space."""
    source = Image.open(SOURCE).convert("RGBA")
    center = SIZE * 0.5
    offset_x = SIZE * ASSET_OFFSET[0]
    offset_y = SIZE * ASSET_OFFSET[1]
    inverse = 1.0 / ASSET_SCALE
    translate_x = center * (1.0 - inverse) - offset_x * inverse
    translate_y = center * (1.0 - inverse) - offset_y * inverse
    return source.transform(
        (SIZE, SIZE),
        Image.Transform.AFFINE,
        (inverse, 0, translate_x, 0, inverse, translate_y),
        resample=Image.Resampling.BICUBIC,
    )


def build_clean_base() -> Image.Image:
    """Remove the baked halo without repainting any physical board pixel."""
    source = np.asarray(Image.open(SOURCE).convert("RGBA"), dtype=np.uint8)
    source_alpha = source[..., 3]
    high_alpha = source_alpha >= 224

    labels, _ = ndimage.label(high_alpha, structure=np.ones((3, 3), dtype=bool))
    body_label = int(labels[590, 626])
    if body_label == 0:
        raise RuntimeError("Poch disc body seed is missing at the measured center")
    body = labels == body_label
    body = ndimage.binary_closing(
        body,
        structure=ndimage.generate_binary_structure(2, 1),
        iterations=1,
    )
    body = ndimage.binary_fill_holes(body)

    ys, xs = np.nonzero(body)
    bbox = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
    if bbox != (137, 102, 1114, 1096):
        raise RuntimeError(f"Unexpected Poch disc body bounds: {bbox}")
    expected_area = 764_035
    if abs(int(body.sum()) - expected_area) > expected_area * 0.001:
        raise RuntimeError(f"Unexpected Poch disc body area: {int(body.sum())}")

    inside_distance = ndimage.distance_transform_edt(body)
    outside_distance, nearest = ndimage.distance_transform_edt(
        ~body,
        return_indices=True,
    )
    signed_distance = inside_distance - outside_distance
    unit = np.clip((signed_distance + 1.5) / 3.0, 0.0, 1.0)
    smooth = unit * unit * (3.0 - 2.0 * unit)
    clean_alpha = np.rint(smooth * 255.0).astype(np.uint8)

    clean = np.zeros_like(source)
    clean[body, :3] = source[body, :3]
    outside_aa = (clean_alpha > 0) & ~body
    nearest_y = nearest[0][outside_aa]
    nearest_x = nearest[1][outside_aa]
    clean[outside_aa, :3] = source[nearest_y, nearest_x, :3]
    clean[..., 3] = clean_alpha

    if clean[1095, 626, 3] == 0 or clean[1098, 626, 3] != 0:
        raise RuntimeError("Clean-base sidewall contract failed")
    CLEAN_BASE_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    result = Image.fromarray(clean, mode="RGBA")
    result.save(CLEAN_BASE_OUTPUT, optimize=True)
    return result


def srgb_to_linear(values: np.ndarray) -> np.ndarray:
    return np.where(
        values <= 0.04045,
        values / 12.92,
        ((values + 0.055) / 1.055) ** 2.4,
    )


def linear_to_srgb(values: np.ndarray) -> np.ndarray:
    return np.where(
        values <= 0.0031308,
        values * 12.92,
        1.055 * np.power(values, 1.0 / 2.4) - 0.055,
    )


def build_source_derived_grade(mask_image: Image.Image,
                               target_srgb: tuple[int, int, int],
                               contrast_gamma: float) -> Image.Image:
    source = np.asarray(normalized_source(), dtype=np.float64)
    linear = srgb_to_linear(source[..., :3] / 255.0)
    luminance = (linear[..., 0] * 0.2126
                 + linear[..., 1] * 0.7152
                 + linear[..., 2] * 0.0722)
    mask = np.asarray(mask_image, dtype=np.float64) / 255.0
    interior = mask >= 0.99

    target_linear = srgb_to_linear(
        np.asarray(target_srgb, dtype=np.float64) / 255.0
    )
    target_luminance = float(target_linear[0] * 0.2126
                             + target_linear[1] * 0.7152
                             + target_linear[2] * 0.0722)
    curved = np.power(np.maximum(luminance, 1e-6), contrast_gamma)
    source_median = float(np.median(curved[interior]))
    calibrated_luminance = curved * (target_luminance / source_median)

    # Constant target chromaticity, source-derived luminance: this retains every
    # bevel, pore and north-west highlight without adding a flat color veil.
    chromaticity = target_linear / target_luminance
    corrected_linear = calibrated_luminance[..., None] * chromaticity
    corrected_srgb = linear_to_srgb(np.clip(corrected_linear, 0.0, 1.0))
    corrected = np.empty_like(source, dtype=np.uint8)
    corrected[..., :3] = np.rint(corrected_srgb * 255.0).astype(np.uint8)
    corrected[..., 3] = np.rint(mask * 255.0).astype(np.uint8)
    return Image.fromarray(corrected, mode="RGBA")


def build_graphite_grade() -> Image.Image:
    source_grade = build_source_derived_grade(
        build_graphite_mask(),
        GRAPHITE_TARGET_SRGB,
        GRAPHITE_CONTRAST_GAMMA,
    )
    grade = np.asarray(source_grade, dtype=np.float64).copy()
    luma = (grade[..., 0] * 0.2126
            + grade[..., 1] * 0.7152
            + grade[..., 2] * 0.0722)
    broad_light = ndimage.gaussian_filter(
        luma,
        sigma=SIZE * GRAPHITE_DETAIL_SIGMA_RATIO,
        mode="reflect",
    )
    detail = np.clip(luma - broad_light, -10.0, 10.0)

    # Registered colour-picker samples from the binding board reference show
    # a nearly vertical field: both upper quadrants are equally lit and both
    # lower quadrants fall into the same quiet graphite range. The canonical
    # source carried a diagonal highlight, which made north-east too dark and
    # south-west too bright even though its global median happened to match.
    yy = np.arange(SIZE, dtype=np.float64)[:, None]
    xx = np.arange(SIZE, dtype=np.float64)[None, :]
    normalized_y = (yy - SIZE * 0.5) / (SIZE * 0.458)
    normalized_x = (xx - SIZE * 0.5) / (SIZE * 0.458)
    center = np.asarray(GRAPHITE_LIGHT_CENTER_SRGB, dtype=np.float64)
    vertical_delta = np.asarray(GRAPHITE_LIGHT_VERTICAL_DELTA, dtype=np.float64)
    lower_bounce = np.asarray(GRAPHITE_LOWER_BOUNCE_SRGB, dtype=np.float64)
    bottomness = smoothstep(0.02, 0.45, normalized_y)
    lower_bias = np.clip(1.0 - normalized_x * 0.8, 0.65, 1.35)
    target = (center
              + normalized_y[..., None] * vertical_delta
              + (bottomness * lower_bias)[..., None] * lower_bounce)
    target = np.broadcast_to(target, grade[..., :3].shape)
    grade[..., :3] = np.rint(np.clip(target + detail[..., None], 0.0, 255.0))
    return Image.fromarray(grade.astype(np.uint8), mode="RGBA")


def build_well_metal_mask() -> Image.Image:
    """Select existing bright ring pixels; never invent a geometric annulus."""
    geometry = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(geometry)
    for name, normalized in WELLS.items():
        if name == "center":
            continue
        center = normalized_center(normalized)
        ring(draw, center, SIZE * 0.092, SIZE * 0.060, 255)

    source = np.asarray(normalized_source(), dtype=np.float64)
    luminance = (source[..., 0] * 0.2126
                 + source[..., 1] * 0.7152
                 + source[..., 2] * 0.0722)
    # Smooth threshold excludes the black well wall and velvet while retaining
    # the full source highlight and bevel variation of the actual metal pixels.
    metal_weight = np.clip((luminance - 62.0) / 58.0, 0.0, 1.0)
    mask = (np.asarray(geometry, dtype=np.float64) / 255.0) * metal_weight
    return Image.fromarray(np.rint(mask * 255.0).astype(np.uint8), mode="L")


def build_well_metal_grade() -> Image.Image:
    return build_source_derived_grade(
        build_well_metal_mask(),
        WELL_METAL_TARGET_SRGB,
        WELL_METAL_CONTRAST_GAMMA,
    )


def smoothstep(edge0: float, edge1: float, values: np.ndarray) -> np.ndarray:
    normalized = np.clip((values - edge0) / (edge1 - edge0), 0.0, 1.0)
    return normalized * normalized * (3.0 - 2.0 * normalized)


def build_velvet_texture() -> np.ndarray:
    """Return clustered velvet nap without radial or centre-dependent noise."""
    broad = np.asarray(noise_field(54, 14_410), dtype=np.float64) / 255.0 - 0.5
    pile = np.asarray(noise_field(172, 144_100), dtype=np.float64) / 255.0 - 0.5
    fine = np.asarray(noise_field(560, 1_441_000), dtype=np.float64) / 255.0 - 0.5
    base = np.empty((SIZE, SIZE, 4), dtype=np.uint8)
    # The reference nap reads through the final phone-scale downsample as soft,
    # irregular fibre clusters. Fine grain alone averaged into the rejected
    # smooth rubber surface, so the dominant variation intentionally lives at
    # 7-24 presentation pixels without becoming a marble vein.
    delta = broad * 13.0 + pile * 11.0 + fine * 3.0
    for index, channel in enumerate((41.0, 48.0, 58.0)):
        base[..., index] = np.rint(np.clip(channel + delta, 0.0, 255.0)).astype(np.uint8)
    base[..., 3] = 255
    return base.astype(np.float64)


def build_velvet_grade() -> Image.Image:
    """Build the floor and upper inner-wall shadow as one directed-light layer.

    The reference is not radially occluded: its depth comes from a black upper
    wall and a floor that opens into light toward six o'clock. Extending the
    flor underneath the lower wall also removes the source asset's false dark
    donut without painting over the physical metal lip.
    """
    texture = build_velvet_texture()
    result = np.zeros((SIZE, SIZE, 4), dtype=np.float64)

    for name, normalized in WELLS.items():
        is_center = name == "center"
        outer_radius = SIZE * (0.152 if is_center else 0.074)
        inner_wall_radius = SIZE * (0.102 if is_center else 0.061)
        cx, cy = normalized_center(normalized)
        extent = int(math.ceil(outer_radius + 3.0))
        x0 = max(0, int(cx) - extent)
        x1 = min(SIZE, int(cx) + extent + 1)
        y0 = max(0, int(cy) - extent)
        y1 = min(SIZE, int(cy) + extent + 1)
        yy, xx = np.mgrid[y0:y1, x0:x1]
        nx = (xx - cx) / outer_radius
        ny = (yy - cy) / outer_radius
        radius = np.hypot(nx, ny)

        edge = 1.0 - smoothstep(0.968, 1.0, radius)
        topness = smoothstep(-0.35, 0.55, -ny)
        light_positions = np.asarray((-1.0, -0.62, -0.50, -0.27, -0.05,
                                      0.18, 0.41, 0.59, 1.0))
        light_values = np.asarray(
            (0.07, 0.10, 0.15, 0.47, 0.75, 0.94, 1.05, 1.10, 1.28)
            if not is_center else
            (0.62, 0.68, 0.72, 0.78, 0.82, 0.88, 0.93, 0.97, 0.98)
        )
        light = np.interp(ny, light_positions, light_values)

        rgb = texture[y0:y1, x0:x1, :3].copy()
        if is_center:
            rgb -= 2.0
        else:
            rgb += np.asarray((-2.0, -5.0, -3.0))
        rgb *= light[..., None]

        wall_start = inner_wall_radius / outer_radius
        wall = (smoothstep(wall_start - 0.035, wall_start + 0.015, radius)
                * (1.0 - smoothstep(0.965, 1.0, radius)))
        wall_alpha = wall * (0.012 + (0.74 if is_center else 0.82) * topness)
        wall_color = np.asarray((7.0, 10.0, 16.0) if is_center else (6.0, 9.0, 14.0))
        rgb = rgb * (1.0 - wall_alpha[..., None]) + wall_color * wall_alpha[..., None]

        target = result[y0:y1, x0:x1]
        target[..., :3] = np.rint(np.clip(rgb, 0.0, 255.0))
        target[..., 3] = np.maximum(target[..., 3], np.rint(edge * 255.0))

    return Image.fromarray(result.astype(np.uint8), mode="RGBA")


def build_center_lip_grade() -> Image.Image:
    """Tint the complete source relief without replacing its physical steps."""
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)
    center = normalized_center(WELLS["center"])
    ring(draw, center, SIZE * 0.164, SIZE * 0.151, 255)
    return build_source_derived_grade(
        mask.filter(ImageFilter.GaussianBlur(radius=1.4)),
        CENTER_LIP_TARGET_SRGB,
        CENTER_LIP_CONTRAST_GAMMA,
    )


def build_center_upper_wall_cover() -> Image.Image:
    """Hide only the obsolete woven source seam at twelve o'clock."""
    result = np.zeros((SIZE, SIZE, 4), dtype=np.float64)
    cx, cy = normalized_center(WELLS["center"])
    yy, xx = np.mgrid[:SIZE, :SIZE]
    normalized_x = (xx - cx) / SIZE
    normalized_y = (yy - cy) / SIZE
    radius = np.hypot(normalized_x, normalized_y)
    annulus = (smoothstep(0.149, 0.153, radius)
               * (1.0 - smoothstep(0.158, 0.161, radius)))
    topness = smoothstep(-0.12, 0.70, -normalized_y / 0.164)
    alpha = annulus * topness * 0.94
    result[..., :3] = np.asarray((6.0, 9.0, 14.0))
    result[..., 3] = np.rint(alpha * 255.0)
    return Image.fromarray(result.astype(np.uint8), mode="RGBA")


def main() -> None:
    build_clean_base()
    result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    graphite = build_graphite_grade()
    result = Image.alpha_composite(result, graphite)

    velvet = build_velvet_grade()
    result = Image.alpha_composite(result, velvet)

    # Physical rims are composited after the floor, so the extended lower flor
    # can hide the false dark donut without ever erasing a real metal pixel.
    well_metal = build_well_metal_grade()
    result = Image.alpha_composite(result, well_metal)

    center_lip = build_center_lip_grade()
    result = Image.alpha_composite(result, center_lip)

    center_upper_wall = build_center_upper_wall_cover()
    result = Image.alpha_composite(result, center_upper_wall)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    result.save(OUTPUT, optimize=True)
    print(CLEAN_BASE_OUTPUT.relative_to(ROOT))
    print(OUTPUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
