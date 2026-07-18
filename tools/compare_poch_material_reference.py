#!/usr/bin/env python3
"""Register and compare a rendered Poch well against a material reference.

Both inputs are cropped from an explicitly supplied circular well and mapped to
the same 256 x 256 coordinate system. Machine-readable JSON is written to
stdout; a compact human-readable report is written to stderr. This separation
keeps the command useful in CI without hiding the physical meaning of a score.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageFilter

try:
    from scipy.ndimage import gaussian_filter
except ImportError:  # pragma: no cover - exercised only in minimal toolchains
    gaussian_filter = None

try:
    from skimage.metrics import structural_similarity
except ImportError:  # pragma: no cover - SSIM is explicitly optional
    structural_similarity = None


DEFAULT_SIZE = 256
VERTICAL_BAND_CENTERS = (-0.70, -0.50, -0.25, 0.0, 0.25, 0.50, 0.70)


@dataclass(frozen=True)
class CircleSpec:
    x: float
    y: float
    radius: float


def circle_spec(values: list[str]) -> CircleSpec:
    try:
        x, y, radius = (float(value) for value in values)
    except ValueError as error:
        raise argparse.ArgumentTypeError("circle values must be numbers: X Y RADIUS") from error
    if not math.isfinite(x) or not math.isfinite(y) or not math.isfinite(radius):
        raise argparse.ArgumentTypeError("circle values must be finite")
    if radius <= 0:
        raise argparse.ArgumentTypeError("circle radius must be greater than zero")
    return CircleSpec(x=x, y=y, radius=radius)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Register two circular Poch wells and compare lighting, rings, "
            "colour and local texture. JSON goes to stdout; text goes to stderr."
        )
    )
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--actual", type=Path, required=True)
    parser.add_argument(
        "--reference-circle",
        nargs=3,
        metavar=("X", "Y", "RADIUS"),
        required=True,
        type=str,
        help="reference well centre and outer metal radius in source pixels",
    )
    parser.add_argument(
        "--actual-circle",
        nargs=3,
        metavar=("X", "Y", "RADIUS"),
        required=True,
        type=str,
        help="actual well centre and outer metal radius in source pixels",
    )
    parser.add_argument("--size", type=int, default=DEFAULT_SIZE)
    parser.add_argument(
        "--floor-radius-ratio",
        type=float,
        default=0.68,
        help="textile floor radius divided by the supplied outer radius",
    )
    parser.add_argument(
        "--metal-inner-ratio",
        type=float,
        default=0.82,
        help="inner edge of the metal comparison annulus",
    )
    parser.add_argument(
        "--metal-outer-ratio",
        type=float,
        default=0.98,
        help="outer edge of the metal comparison annulus",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="optional RGBA PNG heatmap path",
    )
    parser.add_argument(
        "--compact-json",
        action="store_true",
        help="emit JSON without indentation",
    )
    args = parser.parse_args()
    try:
        args.reference_circle = circle_spec(args.reference_circle)
        args.actual_circle = circle_spec(args.actual_circle)
    except argparse.ArgumentTypeError as error:
        parser.error(str(error))
    if args.size < 64:
        parser.error("--size must be at least 64")
    if not 0.30 <= args.floor_radius_ratio <= 0.85:
        parser.error("--floor-radius-ratio must be between 0.30 and 0.85")
    if not (
        args.floor_radius_ratio < args.metal_inner_ratio
        < args.metal_outer_ratio <= 1.0
    ):
        parser.error(
            "ratios must satisfy floor-radius < metal-inner < metal-outer <= 1"
        )
    return args


def validate_crop(path: Path, spec: CircleSpec) -> Image.Image:
    if not path.is_file():
        raise ValueError(f"image does not exist: {path}")
    image = Image.open(path).convert("RGB")
    left = spec.x - spec.radius
    top = spec.y - spec.radius
    right = spec.x + spec.radius
    bottom = spec.y + spec.radius
    if left < 0 or top < 0 or right > image.width or bottom > image.height:
        raise ValueError(
            f"circle {spec} is outside {path} ({image.width}x{image.height})"
        )
    return image


def registered_image(image: Image.Image, spec: CircleSpec, size: int) -> np.ndarray:
    box = (
        spec.x - spec.radius,
        spec.y - spec.radius,
        spec.x + spec.radius,
        spec.y + spec.radius,
    )
    registered = image.transform(
        (size, size),
        Image.Transform.EXTENT,
        box,
        resample=Image.Resampling.BICUBIC,
    )
    return np.asarray(registered, dtype=np.float64) / 255.0


def luma(rgb: np.ndarray) -> np.ndarray:
    return (
        rgb[..., 0] * 0.2126
        + rgb[..., 1] * 0.7152
        + rgb[..., 2] * 0.0722
    )


def normalized_coordinates(size: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    yy, xx = np.mgrid[:size, :size]
    centre = (size - 1) / 2.0
    nx = (xx - centre) / (size / 2.0)
    ny = (yy - centre) / (size / 2.0)
    radius = np.sqrt(nx * nx + ny * ny)
    return nx, ny, radius


def masked_mae(reference: np.ndarray, actual: np.ndarray, mask: np.ndarray) -> float:
    difference = np.abs(reference - actual)
    if difference.ndim == 3:
        return float(np.mean(difference[mask, :]))
    return float(np.mean(difference[mask]))


def vertical_luma_bands(
    values: np.ndarray,
    nx: np.ndarray,
    ny: np.ndarray,
    radius: np.ndarray,
    floor_ratio: float,
) -> list[dict[str, float]]:
    bands: list[dict[str, float]] = []
    half_height = floor_ratio * 0.06
    half_width = floor_ratio * 0.58
    floor_limit = floor_ratio * 0.92
    for centre in VERTICAL_BAND_CENTERS:
        normalized_y = centre * floor_ratio
        mask = (
            (np.abs(ny - normalized_y) <= half_height)
            & (np.abs(nx) <= half_width)
            & (radius <= floor_limit)
        )
        sample = values[mask]
        bands.append(
            {
                "position": centre,
                "median_luma_8bit": float(np.median(sample) * 255.0),
                "mean_luma_8bit": float(np.mean(sample) * 255.0),
                "p10_luma_8bit": float(np.percentile(sample, 10) * 255.0),
                "p90_luma_8bit": float(np.percentile(sample, 90) * 255.0),
            }
        )
    return bands


def radial_luma_profile(
    values: np.ndarray,
    radius: np.ndarray,
    bins: int = 64,
) -> list[float]:
    edges = np.linspace(0.0, 1.0, bins + 1)
    profile: list[float] = []
    for lower, upper in zip(edges[:-1], edges[1:]):
        sample = values[(radius >= lower) & (radius < upper)]
        profile.append(float(np.median(sample) * 255.0))
    return profile


def srgb_to_lab(rgb_8bit: list[float]) -> list[float]:
    rgb = np.asarray(rgb_8bit, dtype=np.float64) / 255.0
    linear = np.where(
        rgb <= 0.04045,
        rgb / 12.92,
        ((rgb + 0.055) / 1.055) ** 2.4,
    )
    xyz = np.array(
        [
            linear[0] * 0.4124564 + linear[1] * 0.3575761 + linear[2] * 0.1804375,
            linear[0] * 0.2126729 + linear[1] * 0.7151522 + linear[2] * 0.0721750,
            linear[0] * 0.0193339 + linear[1] * 0.1191920 + linear[2] * 0.9503041,
        ]
    )
    xyz /= np.array([0.95047, 1.0, 1.08883])
    delta = 6.0 / 29.0
    transformed = np.where(
        xyz > delta**3,
        np.cbrt(xyz),
        xyz / (3.0 * delta * delta) + 4.0 / 29.0,
    )
    return [
        float(116.0 * transformed[1] - 16.0),
        float(500.0 * (transformed[0] - transformed[1])),
        float(200.0 * (transformed[1] - transformed[2])),
    ]


def colour_metrics(
    reference: np.ndarray,
    actual: np.ndarray,
    mask: np.ndarray,
) -> dict[str, Any]:
    reference_median = [float(value * 255.0) for value in np.median(reference[mask], axis=0)]
    actual_median = [float(value * 255.0) for value in np.median(actual[mask], axis=0)]
    reference_lab = srgb_to_lab(reference_median)
    actual_lab = srgb_to_lab(actual_median)
    return {
        "reference_median_rgb_8bit": reference_median,
        "actual_median_rgb_8bit": actual_median,
        "median_rgb_distance_8bit": float(
            np.linalg.norm(np.asarray(reference_median) - np.asarray(actual_median))
        ),
        "reference_median_lab": reference_lab,
        "actual_median_lab": actual_lab,
        "median_delta_e_76": float(
            np.linalg.norm(np.asarray(reference_lab) - np.asarray(actual_lab))
        ),
    }


def highpass(values: np.ndarray, sigma: float = 1.35) -> np.ndarray:
    if gaussian_filter is not None:
        return values - gaussian_filter(values, sigma=sigma, mode="reflect")
    blurred = Image.fromarray(np.uint8(np.clip(values * 255.0, 0, 255))).filter(
        ImageFilter.GaussianBlur(radius=sigma)
    )
    return values - np.asarray(blurred, dtype=np.float64) / 255.0


def frequency_metrics(values: np.ndarray, floor_ratio: float) -> dict[str, float]:
    size = values.shape[0]
    floor_radius_pixels = size * floor_ratio / 2.0
    half = max(12, int(floor_radius_pixels * 0.62))
    centre = size // 2
    patch = values[centre - half : centre + half, centre - half : centre + half].copy()
    patch -= np.mean(patch)
    window_y = np.hanning(patch.shape[0])
    window_x = np.hanning(patch.shape[1])
    spectrum = np.fft.fftshift(np.fft.fft2(patch * np.outer(window_y, window_x)))
    power = np.abs(spectrum) ** 2
    fy = np.fft.fftshift(np.fft.fftfreq(patch.shape[0]))
    fx = np.fft.fftshift(np.fft.fftfreq(patch.shape[1]))
    frequency_radius = np.sqrt(fy[:, None] ** 2 + fx[None, :] ** 2)
    non_dc = frequency_radius > 0.015
    total = float(np.sum(power[non_dc]))
    if total <= np.finfo(np.float64).eps:
        return {
            "mid_frequency_energy_ratio": 0.0,
            "high_frequency_energy_ratio": 0.0,
        }
    middle = (frequency_radius >= 0.06) & (frequency_radius < 0.18)
    high = frequency_radius >= 0.18
    return {
        "mid_frequency_energy_ratio": float(np.sum(power[middle]) / total),
        "high_frequency_energy_ratio": float(np.sum(power[high]) / total),
    }


def texture_metrics(
    values: np.ndarray,
    radius: np.ndarray,
    floor_ratio: float,
) -> dict[str, float]:
    texture_mask = radius <= floor_ratio * 0.88
    filtered = highpass(values)
    gy, gx = np.gradient(values)
    gradient = np.sqrt(gx * gx + gy * gy)
    metrics = {
        "highpass_sd_luma_8bit": float(np.std(filtered[texture_mask]) * 255.0),
        "mean_gradient_luma_8bit": float(np.mean(gradient[texture_mask]) * 255.0),
    }
    metrics.update(frequency_metrics(values, floor_ratio))
    return metrics


def ssim_metrics(
    reference: np.ndarray,
    actual: np.ndarray,
    floor_ratio: float,
) -> dict[str, float | None]:
    if structural_similarity is None:
        return {"registered_ssim": None, "floor_center_ssim": None}
    size = reference.shape[0]
    half = max(12, int(size * floor_ratio * 0.31))
    centre = size // 2
    floor_reference = reference[centre - half : centre + half, centre - half : centre + half]
    floor_actual = actual[centre - half : centre + half, centre - half : centre + half]
    return {
        "registered_ssim": float(
            structural_similarity(reference, actual, channel_axis=2, data_range=1.0)
        ),
        "floor_center_ssim": float(
            structural_similarity(
                floor_reference,
                floor_actual,
                channel_axis=2,
                data_range=1.0,
            )
        ),
    }


def save_heatmap(
    path: Path,
    reference: np.ndarray,
    actual: np.ndarray,
    circle_mask: np.ndarray,
) -> dict[str, float | str]:
    difference = np.mean(np.abs(reference - actual), axis=2)
    scale = max(float(np.percentile(difference[circle_mask], 95)), 1.0 / 255.0)
    intensity = np.clip(difference / scale, 0.0, 1.0)
    red = intensity
    green = np.clip((intensity - 0.45) / 0.55, 0.0, 1.0)
    blue = (1.0 - intensity) * 0.18
    alpha = circle_mask.astype(np.float64)
    rgba = np.dstack((red, green, blue, alpha))
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.uint8(np.clip(rgba * 255.0, 0, 255)), mode="RGBA").save(path)
    return {"path": str(path), "p95_normalization": scale}


def compare(args: argparse.Namespace) -> dict[str, Any]:
    reference_source = validate_crop(args.reference, args.reference_circle)
    actual_source = validate_crop(args.actual, args.actual_circle)
    reference = registered_image(reference_source, args.reference_circle, args.size)
    actual = registered_image(actual_source, args.actual_circle, args.size)
    nx, ny, radius = normalized_coordinates(args.size)
    circle_mask = radius <= 0.98
    floor_mask = radius <= args.floor_radius_ratio
    metal_mask = (
        (radius >= args.metal_inner_ratio)
        & (radius <= args.metal_outer_ratio)
    )
    reference_luma = luma(reference)
    actual_luma = luma(actual)
    reference_bands = vertical_luma_bands(
        reference_luma, nx, ny, radius, args.floor_radius_ratio
    )
    actual_bands = vertical_luma_bands(
        actual_luma, nx, ny, radius, args.floor_radius_ratio
    )
    band_errors = [
        abs(ref["median_luma_8bit"] - act["median_luma_8bit"])
        for ref, act in zip(reference_bands, actual_bands)
    ]
    reference_profile = radial_luma_profile(reference_luma, radius)
    actual_profile = radial_luma_profile(actual_luma, radius)
    reference_top_bottom = (
        reference_bands[-1]["median_luma_8bit"]
        - reference_bands[0]["median_luma_8bit"]
    )
    actual_top_bottom = (
        actual_bands[-1]["median_luma_8bit"]
        - actual_bands[0]["median_luma_8bit"]
    )

    result: dict[str, Any] = {
        "schema_version": 1,
        "registration": {
            "size": args.size,
            "reference": {
                "path": str(args.reference),
                "circle": asdict(args.reference_circle),
            },
            "actual": {
                "path": str(args.actual),
                "circle": asdict(args.actual_circle),
            },
            "floor_radius_ratio": args.floor_radius_ratio,
            "metal_inner_ratio": args.metal_inner_ratio,
            "metal_outer_ratio": args.metal_outer_ratio,
        },
        "pixel": {
            "circle_rgb_mae_0_to_1": masked_mae(reference, actual, circle_mask),
            "circle_luma_mae_0_to_1": masked_mae(
                reference_luma, actual_luma, circle_mask
            ),
            "floor_rgb_mae_0_to_1": masked_mae(reference, actual, floor_mask),
            "floor_luma_mae_0_to_1": masked_mae(
                reference_luma, actual_luma, floor_mask
            ),
            **ssim_metrics(reference, actual, args.floor_radius_ratio),
        },
        "lighting": {
            "reference_vertical_bands": reference_bands,
            "actual_vertical_bands": actual_bands,
            "vertical_band_median_mae_8bit": float(np.mean(band_errors)),
            "reference_top_to_bottom_delta_8bit": reference_top_bottom,
            "actual_top_to_bottom_delta_8bit": actual_top_bottom,
            "top_to_bottom_delta_error_8bit": abs(
                reference_top_bottom - actual_top_bottom
            ),
        },
        "ao_and_ring": {
            "metal_annulus_luma_mae_0_to_1": masked_mae(
                reference_luma, actual_luma, metal_mask
            ),
            "radial_profile_luma_mae_8bit": float(
                np.mean(np.abs(np.asarray(reference_profile) - np.asarray(actual_profile)))
            ),
            "reference_radial_luma_profile_8bit": reference_profile,
            "actual_radial_luma_profile_8bit": actual_profile,
        },
        "colour": colour_metrics(reference, actual, floor_mask),
        "texture": {
            "reference": texture_metrics(
                reference_luma, radius, args.floor_radius_ratio
            ),
            "actual": texture_metrics(actual_luma, radius, args.floor_radius_ratio),
        },
        "capabilities": {
            "scipy_highpass": gaussian_filter is not None,
            "skimage_ssim": structural_similarity is not None,
        },
    }
    if args.output is not None:
        result["heatmap"] = save_heatmap(
            args.output, reference, actual, circle_mask
        )
    return result


def compact_rgb(values: list[float]) -> str:
    return "/".join(str(round(value)) for value in values)


def human_report(result: dict[str, Any]) -> str:
    pixel = result["pixel"]
    lighting = result["lighting"]
    ring = result["ao_and_ring"]
    colour = result["colour"]
    texture = result["texture"]
    reference_bands = lighting["reference_vertical_bands"]
    actual_bands = lighting["actual_vertical_bands"]
    reference_band_text = " / ".join(
        f'{band["median_luma_8bit"]:.1f}' for band in reference_bands
    )
    actual_band_text = " / ".join(
        f'{band["median_luma_8bit"]:.1f}' for band in actual_bands
    )
    ssim = pixel["registered_ssim"]
    floor_ssim = pixel["floor_center_ssim"]
    lines = [
        "Poch material reference comparison",
        (
            f'  registered: {result["registration"]["size"]}x'
            f'{result["registration"]["size"]} px'
        ),
        (
            f'  pixel: circle RGB MAE {pixel["circle_rgb_mae_0_to_1"]:.4f}, '
            f'floor RGB MAE {pixel["floor_rgb_mae_0_to_1"]:.4f}, '
            f'SSIM {ssim:.4f}' if ssim is not None else
            f'  pixel: circle RGB MAE {pixel["circle_rgb_mae_0_to_1"]:.4f}, '
            f'floor RGB MAE {pixel["floor_rgb_mae_0_to_1"]:.4f}, SSIM unavailable'
        ),
        (
            f'  floor-centre SSIM: {floor_ssim:.4f}'
            if floor_ssim is not None else "  floor-centre SSIM: unavailable"
        ),
        f"  vertical luma ref:    {reference_band_text}",
        f"  vertical luma actual: {actual_band_text}",
        (
            f'  AO: top-bottom ref {lighting["reference_top_to_bottom_delta_8bit"]:.1f}, '
            f'actual {lighting["actual_top_to_bottom_delta_8bit"]:.1f}, '
            f'error {lighting["top_to_bottom_delta_error_8bit"]:.1f}'
        ),
        (
            f'  ring: metal-annulus luma MAE '
            f'{ring["metal_annulus_luma_mae_0_to_1"]:.4f}, radial-profile MAE '
            f'{ring["radial_profile_luma_mae_8bit"]:.1f}/255'
        ),
        (
            f'  colour: median RGB ref '
            f'{compact_rgb(colour["reference_median_rgb_8bit"])}, actual '
            f'{compact_rgb(colour["actual_median_rgb_8bit"])}, '
            f'DeltaE76 {colour["median_delta_e_76"]:.2f}'
        ),
        (
            f'  texture highpass SD ref '
            f'{texture["reference"]["highpass_sd_luma_8bit"]:.2f}, actual '
            f'{texture["actual"]["highpass_sd_luma_8bit"]:.2f}; high-frequency '
            f'energy ref {texture["reference"]["high_frequency_energy_ratio"]:.3f}, '
            f'actual {texture["actual"]["high_frequency_energy_ratio"]:.3f}'
        ),
    ]
    if "heatmap" in result:
        lines.append(f'  heatmap: {result["heatmap"]["path"]}')
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    try:
        result = compare(args)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    print(human_report(result), file=sys.stderr)
    if args.compact_json:
        print(json.dumps(result, separators=(",", ":"), sort_keys=True))
    else:
        print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
