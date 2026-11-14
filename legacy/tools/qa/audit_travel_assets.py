#!/usr/bin/env python3
"""Reproducible contract gate for the Track-B tray and cent assets.

The gate intentionally checks only objective integration properties. It does not
claim that raster material, lighting, or composition passed a human art review.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError as error:  # pragma: no cover - environment failure path
    raise SystemExit("FAIL: Pillow is required to inspect PNG alpha data") from error


ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = ROOT / "App" / "Assets.xcassets"
RENDERER = ROOT / "App" / "TravelTableRenderer.swift"

EXPECTED = {
    "TravelTray": ("travel-tray.png", 1024),
    **{
        f"TravelCent{index}": (f"travel-cent-{index}.png", 512)
        for index in range(6)
    },
}

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
CORNER_PATCH_FRACTION = 0.05
MIN_TRANSPARENT_CORNER_RATIO = 0.98
MIN_TRANSPARENT_CANVAS_RATIO = 0.08
MAX_OPAQUE_NEAR_BLACK_RATIO = 0.005
MAX_CHROMA_RESIDUE_RATIO = 0.00001
IPAD_DISPLAY_SCALE = 2
LARGE_IPHONE_DISPLAY_SCALE = 3
LARGE_IPHONE_SHORT_EDGE_POINTS = 440
LOW_RESOLUTION_HEADROOM = 0.05


class Gate:
    def __init__(self) -> None:
        self.failures: list[str] = []
        self.passes: list[str] = []
        self.risks: list[str] = []

    def check(self, condition: bool, label: str, detail: str = "") -> None:
        if condition:
            self.passes.append(label)
            return
        suffix = f": {detail}" if detail else ""
        self.failures.append(f"{label}{suffix}")

    def risk(self, label: str, detail: str) -> None:
        self.risks.append(f"{label}: {detail}")

    def report(self) -> int:
        for label in self.passes:
            print(f"PASS  {label}")
        for risk in self.risks:
            print(f"RISK  {risk}")
        for failure in self.failures:
            print(f"FAIL  {failure}")
        print(f"\nTravel asset contract: {len(self.passes)} PASS, "
              f"{len(self.risks)} RISK, {len(self.failures)} FAIL")
        return 1 if self.failures else 0


def declared_filename(imageset: Path) -> str | None:
    contents = imageset / "Contents.json"
    try:
        payload = json.loads(contents.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    filenames = [
        image.get("filename")
        for image in payload.get("images", [])
        if image.get("filename")
    ]
    return filenames[0] if len(filenames) == 1 else None


def renderer_size_contract() -> tuple[float, float] | None:
    try:
        source = RENDERER.read_text(encoding="utf-8")
    except OSError:
        return None
    match = re.search(
        r"let side = min\(proxy\.size\.width \* (?P<fraction>\d+(?:\.\d+)?), "
        r"proxy\.size\.height \* (?P=fraction), (?P<cap>\d+(?:\.\d+)?)\)",
        source,
    )
    if not match:
        return None
    return float(match.group("fraction")), float(match.group("cap"))


def inspect_tray_resolution(
    gate: Gate,
    width: int,
    height: int,
    require_full_cap_3x: bool,
) -> None:
    contract = renderer_size_contract()
    gate.check(
        contract is not None,
        "Travel renderer exposes an auditable viewport fraction and point cap",
        "expected min(width * fraction, height * fraction, cap)",
    )
    if contract is None:
        return

    viewport_fraction, point_cap = contract
    ipad_2x_pixels = math.ceil(point_cap * IPAD_DISPLAY_SCALE)
    large_iphone_points = min(
        point_cap,
        LARGE_IPHONE_SHORT_EDGE_POINTS * viewport_fraction,
    )
    large_iphone_3x_pixels = math.ceil(
        large_iphone_points * LARGE_IPHONE_DISPLAY_SCALE
    )
    current_required_pixels = max(ipad_2x_pixels, large_iphone_3x_pixels)
    available_pixels = min(width, height)
    gate.check(
        available_pixels >= current_required_pixels,
        "TravelTray covers current iPad 2x and large-iPhone 3x render targets",
        (
            f"asset={available_pixels}px, iPad-cap@2x={ipad_2x_pixels}px, "
            f"{large_iphone_points:.1f}pt-phone@3x={large_iphone_3x_pixels}px"
        ),
    )

    headroom = available_pixels / ipad_2x_pixels - 1
    if headroom < LOW_RESOLUTION_HEADROOM:
        gate.risk(
            "TravelTray iPad 2x headroom is narrow",
            (
                f"{available_pixels - ipad_2x_pixels}px / {headroom:.2%}; "
                "any larger point cap or crop requires a new raster"
            ),
        )

    full_cap_3x_pixels = math.ceil(point_cap * LARGE_IPHONE_DISPLAY_SCALE)
    full_cap_3x_ready = available_pixels >= full_cap_3x_pixels
    if require_full_cap_3x:
        gate.check(
            full_cap_3x_ready,
            "TravelTray covers the full renderer cap at 3x",
            f"asset={available_pixels}px, required={full_cap_3x_pixels}px",
        )
    elif not full_cap_3x_ready:
        gate.risk(
            "TravelTray does not cover a future full-cap 3x surface",
            (
                f"asset={available_pixels}px, required={full_cap_3x_pixels}px; "
                f"current 3x ceiling without upsampling is "
                f"{available_pixels / LARGE_IPHONE_DISPLAY_SCALE:.0f}pt"
            ),
        )


def inspect_asset(
    gate: Gate,
    name: str,
    filename: str,
    minimum_side: int,
    require_full_cap_3x: bool,
) -> None:
    imageset = ASSET_ROOT / f"{name}.imageset"
    png = imageset / filename
    gate.check(imageset.is_dir(), f"{name} imageset exists")
    gate.check(
        declared_filename(imageset) == filename,
        f"{name} declares exactly {filename}",
    )
    if not png.is_file():
        gate.check(False, f"{name} PNG exists", str(png.relative_to(ROOT)))
        return

    gate.check(png.read_bytes()[:8] == PNG_SIGNATURE, f"{name} has PNG signature")
    try:
        with Image.open(png) as source:
            source.load()
            width, height = source.size
            mode = source.mode
            has_alpha = "A" in source.getbands()
            image = source.convert("RGBA")
    except OSError as error:
        gate.check(False, f"{name} decodes", str(error))
        return

    gate.check(mode == "RGBA" and has_alpha, f"{name} is PNG RGBA with alpha", mode)
    gate.check(
        width >= minimum_side and height >= minimum_side,
        f"{name} meets minimum {minimum_side}px resolution",
        f"{width}x{height}",
    )
    if name == "TravelTray":
        gate.check(width == height, "TravelTray is exactly square", f"{width}x{height}")
        inspect_tray_resolution(gate, width, height, require_full_cap_3x)

    pixels = list(image.getdata())
    pixel_count = len(pixels)
    transparent_ratio = sum(alpha <= 5 for *_, alpha in pixels) / pixel_count
    gate.check(
        transparent_ratio >= MIN_TRANSPARENT_CANVAS_RATIO,
        f"{name} has a genuinely transparent canvas",
        f"{transparent_ratio:.4%}",
    )

    patch_side = max(4, int(min(width, height) * CORNER_PATCH_FRACTION))
    corner_origins = (
        (0, 0),
        (width - patch_side, 0),
        (0, height - patch_side),
        (width - patch_side, height - patch_side),
    )
    corner_ratios = []
    for origin_x, origin_y in corner_origins:
        alphas = [
            image.getpixel((x, y))[3]
            for y in range(origin_y, origin_y + patch_side)
            for x in range(origin_x, origin_x + patch_side)
        ]
        corner_ratios.append(sum(alpha <= 5 for alpha in alphas) / len(alphas))
    gate.check(
        min(corner_ratios) >= MIN_TRANSPARENT_CORNER_RATIO,
        f"{name} has transparent corner patches",
        ", ".join(f"{ratio:.2%}" for ratio in corner_ratios),
    )

    opaque_near_black = sum(
        alpha >= 245 and max(red, green, blue) < 18
        for red, green, blue, alpha in pixels
    ) / pixel_count
    gate.check(
        opaque_near_black <= MAX_OPAQUE_NEAR_BLACK_RATIO,
        f"{name} has no near-black rectangular matte",
        f"{opaque_near_black:.5%}",
    )

    # Chroma extraction used a green key. Ignore nearly transparent antialias
    # pixels, then reject even a very small population of green-dominant residue.
    chroma_residue = sum(
        alpha > 32
        and green >= 70
        and green - red >= 28
        and green - blue >= 18
        for red, green, blue, alpha in pixels
    ) / pixel_count
    gate.check(
        chroma_residue <= MAX_CHROMA_RESIDUE_RATIO,
        f"{name} is free of visible chroma-key residue",
        f"{chroma_residue:.6%}",
    )


def inspect_asset_inventory(gate: Gate) -> None:
    actual = {
        path.name.removesuffix(".imageset")
        for path in ASSET_ROOT.glob("Travel*.imageset")
        if path.is_dir()
    }
    expected = set(EXPECTED)
    gate.check(
        actual == expected,
        "Travel inventory is exactly one tray plus six cent variants",
        f"actual={sorted(actual)}",
    )


def inspect_renderer(gate: Gate) -> None:
    try:
        source = RENDERER.read_text(encoding="utf-8")
    except OSError as error:
        gate.check(False, "Travel renderer exists", str(error))
        return

    active_sources = "\n".join(
        path.read_text(encoding="utf-8", errors="replace")
        for path in sorted((ROOT / "App").rglob("*.swift"))
    )
    gate.check(
        'TableWorldBoardBase(world: .unterwegs' in source
        and 'Image("TravelTray")' in active_sources,
        "Renderer reaches the approved tray asset through the shared board base",
    )
    gate.check(
        'Image("TravelCent\\(assetIndex)")' in source,
        "Renderer references the six indexed cent assets",
    )
    function_match = re.search(
        r"static func index\(seed: UInt64,\s*"
        r"index: Int,\s*"
        r"compartment: TravelCompartment\) -> Int \{(?P<body>.*?)\n    \}",
        source,
        flags=re.DOTALL,
    )
    body = function_match.group("body") if function_match else ""
    gate.check(bool(function_match), "Renderer has an explicit shared asset resolver")
    gate.check(
        "static let variantCount = 6" in source
        and all(
            token in body
            for token in (
                "seed % UInt64(variantCount)",
                "safeIndex * 5",
                "compartmentIndex * 3",
                ") % variantCount",
            )
        ),
        "Renderer selects all six variants deterministically",
        "expected shared seed/index/compartment arithmetic modulo variantCount=6",
    )
    gate.check("hashValue" not in source, "Renderer does not use hashValue")
    gate.check(
        not re.search(r"\b(?:random|arc4random|drand48)\b", source, flags=re.IGNORECASE),
        "Renderer does not use nondeterministic random APIs",
    )

    string_literals = re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', active_sources)
    static_v3_reference = next(
        (
            literal
            for literal in string_literals
            if re.search(r"travel|track[-_ ]?b|unterwegs", literal, flags=re.IGNORECASE)
            and re.search(r"v3|static[-_ ]?scene|scene[-_ ]?v3", literal, flags=re.IGNORECASE)
        ),
        None,
    )
    gate.check(
        static_v3_reference is None,
        "No static Track-B v3 scene is referenced by active Swift sources",
        static_v3_reference or "",
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--require-full-cap-3x",
        action="store_true",
        help=(
            "Treat a raster smaller than the renderer's full point cap at 3x "
            "as a hard failure. The default audits the current iPad-2x and "
            "large-iPhone-3x device matrix and reports future 3x-cap debt as RISK."
        ),
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    gate = Gate()
    inspect_asset_inventory(gate)
    for name, (filename, minimum_side) in EXPECTED.items():
        inspect_asset(
            gate,
            name,
            filename,
            minimum_side,
            arguments.require_full_cap_3x,
        )
    inspect_renderer(gate)
    return gate.report()


if __name__ == "__main__":
    sys.exit(main())
