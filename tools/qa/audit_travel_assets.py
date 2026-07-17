#!/usr/bin/env python3
"""Reproducible contract gate for the Track-B tray and cent assets.

The gate intentionally checks only objective integration properties. It does not
claim that raster material, lighting, or composition passed a human art review.
"""

from __future__ import annotations

import json
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


class Gate:
    def __init__(self) -> None:
        self.failures: list[str] = []
        self.passes: list[str] = []

    def check(self, condition: bool, label: str, detail: str = "") -> None:
        if condition:
            self.passes.append(label)
            return
        suffix = f": {detail}" if detail else ""
        self.failures.append(f"{label}{suffix}")

    def report(self) -> int:
        for label in self.passes:
            print(f"PASS  {label}")
        for failure in self.failures:
            print(f"FAIL  {failure}")
        print(f"\nTravel asset contract: {len(self.passes)} PASS, "
              f"{len(self.failures)} FAIL")
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


def inspect_asset(gate: Gate, name: str, filename: str, minimum_side: int) -> None:
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

    gate.check(
        'Image("TravelTray")' in source,
        "Renderer references the approved tray asset",
    )
    gate.check(
        'Image("TravelCent\\(assetIndex)")' in source,
        "Renderer references the six indexed cent assets",
    )
    function_match = re.search(
        r"private func assetIndex\(for index: Int\) -> Int \{(?P<body>.*?)\n    \}",
        source,
        flags=re.DOTALL,
    )
    body = function_match.group("body") if function_match else ""
    gate.check(bool(function_match), "Renderer has an explicit asset-index function")
    gate.check(
        all(token in body for token in ("seed % 6", "index * 5", "compartmentIndex * 3", ") % 6")),
        "Renderer selects all six variants deterministically",
        "expected seed/index/compartment arithmetic modulo six",
    )
    gate.check("hashValue" not in source, "Renderer does not use hashValue")
    gate.check(
        not re.search(r"\b(?:random|arc4random|drand48)\b", source, flags=re.IGNORECASE),
        "Renderer does not use nondeterministic random APIs",
    )

    active_sources = "\n".join(
        path.read_text(encoding="utf-8", errors="replace")
        for path in sorted((ROOT / "App").rglob("*.swift"))
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


def main() -> int:
    gate = Gate()
    inspect_asset_inventory(gate)
    for name, (filename, minimum_side) in EXPECTED.items():
        inspect_asset(gate, name, filename, minimum_side)
    inspect_renderer(gate)
    return gate.report()


if __name__ == "__main__":
    sys.exit(main())
