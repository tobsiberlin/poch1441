#!/usr/bin/env python3
"""Generate six code-native, historically grounded W3 card-back candidates."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import gen_card_damage_v10_reviews as damage

WIDTH, HEIGHT = 1000, 1400
PAPER = "#D4C5A7"
PAPER_DARK = "#C3B18F"
PAPER_LIGHT = "#DED2B8"
INDIGO = "#34495B"
INDIGO_LIGHT = "#526777"
CHARCOAL = "#292C2D"
REVIEW_BG = (27, 25, 23, 255)

CANDIDATES = (
    {
        "number": 1, "slug": "tapestry-rosette", "name": "Tapisserie-Rosette",
        "direction": "Kleines Tapisserie-/Rosettenrepeat",
        "damage_variant": 1, "damage": "feine Stresslinie",
        "scores": {"authenticity": 9.0, "phone": 8.5, "printability": 9.1},
        "verdict": "Eigenständig und stofflich; in der Hand ruhig, ohne Tapetenhaftigkeit.",
    },
    {
        "number": 2, "slug": "guilloche-weave", "name": "Guilloche-Bandgewebe",
        "direction": "Guillochiertes Bandgewebe",
        "damage_variant": 5, "damage": "matter Reparaturfilm",
        "scores": {"authenticity": 9.6, "phone": 9.2, "printability": 9.4},
        "verdict": "Beste Balance: historisch glaubwürdig, unverwechselbar und mobil klar.",
        "favorite": True,
    },
    {
        "number": 3, "slug": "botanical-engraving", "name": "Botanische Gravur",
        "direction": "Feine botanische Gravur ohne Kitsch",
        "damage_variant": 8, "damage": "untere Kantenkompression",
        "scores": {"authenticity": 9.3, "phone": 7.8, "printability": 8.6},
        "verdict": "Sehr authentisch und charaktervoll; verliert im kleinsten Fächer etwas Linie.",
    },
    {
        "number": 4, "slug": "diamond-weave", "name": "Karo-Webung",
        "direction": "Kompakte Karo-Webung",
        "damage_variant": 3, "damage": "verzweigte Stresslinie",
        "scores": {"authenticity": 8.8, "phone": 9.3, "printability": 9.5},
        "verdict": "Am klarsten im Phone-Fächer; das Poch-Karo bleibt reine Webstruktur.",
    },
    {
        "number": 5, "slug": "micro-star-grid", "name": "Mikro-Sterngitter",
        "direction": "Ruhiges Mikro-Stern-/Punktgitter",
        "damage_variant": 6, "damage": "matter Reparaturfilm",
        "scores": {"authenticity": 8.6, "phone": 8.8, "printability": 9.6},
        "verdict": "Leise und robust druckbar; bewusst weniger erzählerisch als 1, 2 und 3.",
    },
    {
        "number": 6, "slug": "two-tone-linocut", "name": "Zweifarbiger Linolschnitt",
        "direction": "Zweifarbiger historischer Linolschnitt",
        "damage_variant": 9, "damage": "rechte Kantenkompression",
        "scores": {"authenticity": 9.1, "phone": 8.9, "printability": 8.7},
        "verdict": "Kräftigster eigener Charakter; etwas rustikaler als der Favorit.",
    },
)


def stable_rng(label: str) -> np.random.Generator:
    value = int.from_bytes(hashlib.sha256(label.encode()).digest()[:8], "big")
    return np.random.default_rng(value)


def mirrored_marks(candidate: int) -> str:
    rng = stable_rng(f"w3-paper:{candidate}")
    fibres, misses = [], []
    for _ in range(42):
        x = float(rng.uniform(95, 905))
        y = float(rng.uniform(92, 690))
        length = float(rng.uniform(7, 25))
        angle = float(rng.uniform(-.55, .55))
        dx, dy = np.cos(angle) * length, np.sin(angle) * length
        fibres.append(
            f'<path d="M{x:.1f},{y:.1f} l{dx:.1f},{dy:.1f}" '
            f'stroke="{PAPER_DARK}" stroke-width="1.2" opacity="{rng.uniform(.12,.25):.2f}"/>'
        )
    for _ in range(34):
        x = float(rng.uniform(105, 895))
        y = float(rng.uniform(105, 690))
        radius = float(rng.uniform(1.2, 4.0))
        misses.append(
            f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{radius:.1f}" ry="{radius*.45:.1f}" '
            f'fill="{PAPER_LIGHT}" opacity="{rng.uniform(.25,.58):.2f}"/>'
        )
    fibre_group = "".join(fibres)
    miss_group = "".join(misses)
    return f"""
    <g id="paper-fibres">{fibre_group}</g>
    <use href="#paper-fibres" transform="rotate(180 500 700)"/>
    <g id="print-misses">{miss_group}</g>
    <use href="#print-misses" transform="rotate(180 500 700)"/>
    """


def common_border() -> str:
    return f"""
    <g fill="none" stroke="{INDIGO}" stroke-linejoin="round">
      <rect x="48" y="48" width="904" height="1304" rx="118" stroke-width="9" opacity=".88"/>
      <rect x="69" y="69" width="862" height="1262" rx="99" stroke-width="3.5" opacity=".78"/>
    </g>
    <g id="border-rub" stroke="{PAPER}" stroke-linecap="round">
      <path d="M248 51 L326 51" stroke-width="13" opacity=".84"/>
      <path d="M70 344 L70 388" stroke-width="7" opacity=".62"/>
    </g>
    <use href="#border-rub" transform="rotate(180 500 700)"/>
    """


def rosette_pattern() -> tuple[str, str]:
    defs = f"""
    <g id="rosette" fill="none" stroke="{INDIGO}" stroke-width="4.2" opacity=".88">
      <ellipse cx="0" cy="-19" rx="10" ry="23"/>
      <ellipse cx="0" cy="19" rx="10" ry="23"/>
      <ellipse cx="-19" cy="0" rx="23" ry="10"/>
      <ellipse cx="19" cy="0" rx="23" ry="10"/>
      <circle r="8" fill="{INDIGO}" stroke="none"/>
      <circle r="31" stroke="{INDIGO_LIGHT}" stroke-width="2"/>
    </g>"""
    marks = []
    for row, y in enumerate(range(150, 701, 92)):
        for x in range(140 + (row % 2) * 46, 910, 92):
            marks.append(f'<use href="#rosette" transform="translate({x} {y}) scale(.72)"/>')
    top = "".join(marks)
    body = f'<g id="pattern-top">{top}</g><use href="#pattern-top" transform="rotate(180 500 700)"/>'
    return defs, body


def wave_path(y: float, phase: float, amplitude: float, cycles: float) -> str:
    points = []
    for x in np.linspace(110, 890, 161):
        value = y + amplitude * np.sin((x - 110) / 780 * np.pi * 2 * cycles + phase)
        points.append((x, value))
    return "M" + " L".join(f"{x:.1f},{py:.1f}" for x, py in points)


def guilloche_pattern() -> tuple[str, str]:
    bands = []
    for row, y in enumerate((160, 270, 380, 490, 600)):
        for phase, color, width in ((0, INDIGO, 3.4), (np.pi, INDIGO_LIGHT, 2.2)):
            bands.append(
                f'<path d="{wave_path(y, phase + row*.45, 27, 4.5)}" '
                f'fill="none" stroke="{color}" stroke-width="{width}" opacity=".86"/>'
            )
        bands.append(
            f'<path d="{wave_path(y, np.pi/2 + row*.3, 12, 9)}" fill="none" '
            f'stroke="{CHARCOAL}" stroke-width="1.4" opacity=".58"/>'
        )
    top = "".join(bands)
    body = f'<g id="pattern-top">{top}</g><use href="#pattern-top" transform="rotate(180 500 700)"/>'
    return "", body


def botanical_pattern() -> tuple[str, str]:
    defs = f"""
    <g id="vine" fill="none" stroke="{INDIGO}" stroke-linecap="round">
      <path d="M130 150 C170 255 250 320 342 398 C420 464 445 548 470 640" stroke-width="5"/>
      <path d="M193 273 C155 281 133 309 119 350 M257 337 C294 318 330 320 363 340
               M342 399 C304 418 280 451 271 492 M411 490 C445 470 478 474 509 499" stroke-width="2.3"/>
      <g fill="{INDIGO_LIGHT}" stroke-width="1.7">
        <path d="M119 350 C128 319 149 306 177 303 C169 333 149 350 119 350Z"/>
        <path d="M363 340 C334 339 313 329 299 307 C329 302 350 313 363 340Z"/>
        <path d="M271 492 C279 455 299 436 330 429 C325 463 307 485 271 492Z"/>
        <path d="M509 499 C475 499 452 488 439 462 C472 457 496 470 509 499Z"/>
      </g>
      <circle cx="224" cy="304" r="6" fill="{CHARCOAL}" stroke="none"/>
      <circle cx="383" cy="447" r="5" fill="{CHARCOAL}" stroke="none"/>
    </g>"""
    body = """
    <use href="#vine"/><use href="#vine" transform="translate(1000 0) scale(-1 1)"/>
    <use href="#vine" transform="rotate(180 500 700)"/>
    <use href="#vine" transform="rotate(180 500 700) translate(1000 0) scale(-1 1)"/>
    """
    return defs, body


def diamond_pattern() -> tuple[str, str]:
    lines = []
    for offset in range(-1800, 1801, 72):
        lines.append(f'<path d="M-500 {offset-300} L1500 {offset+1700}"/>')
        lines.append(f'<path d="M-500 {offset+1700} L1500 {offset-300}"/>')
    diamonds = []
    for row, y in enumerate(range(155, 700, 144)):
        for x in range(150 + (row % 2) * 72, 920, 144):
            diamonds.append(
                f'<path d="M{x} {y-12} L{x+12} {y} L{x} {y+12} L{x-12} {y} Z" '
                f'fill="{PAPER}" stroke="{CHARCOAL}" stroke-width="2" opacity=".78"/>'
            )
    top_diamonds = "".join(diamonds)
    body = (
        f'<g fill="none" stroke="{INDIGO}" stroke-width="3" opacity=".76">{"".join(lines)}</g>'
        f'<g id="pattern-top">{top_diamonds}</g>'
        f'<use href="#pattern-top" transform="rotate(180 500 700)"/>'
    )
    return "", body


def star_pattern() -> tuple[str, str]:
    defs = f"""
    <g id="micro-star" stroke="{INDIGO}" stroke-width="2.2" opacity=".82">
      <path d="M0 -10 L0 10 M-10 0 L10 0 M-7 -7 L7 7 M7 -7 L-7 7"/>
      <circle r="2.6" fill="{CHARCOAL}" stroke="none"/>
    </g>"""
    marks = []
    for row, y in enumerate(range(145, 701, 58)):
        for x in range(125 + (row % 2) * 29, 910, 58):
            kind = "micro-star" if (x // 29 + row) % 3 else "micro-dot"
            if kind == "micro-star":
                marks.append(f'<use href="#micro-star" transform="translate({x} {y}) scale(.72)"/>')
            else:
                marks.append(f'<circle cx="{x}" cy="{y}" r="4" fill="{INDIGO_LIGHT}" opacity=".78"/>')
    top = "".join(marks)
    body = f'<g id="pattern-top">{top}</g><use href="#pattern-top" transform="rotate(180 500 700)"/>'
    return defs, body


def linocut_pattern() -> tuple[str, str]:
    blocks = []
    for row, y in enumerate((130, 260, 390, 520, 650)):
        shift = 0 if row % 2 == 0 else 54
        for x in range(110 + shift, 900, 108):
            color = INDIGO if (x // 108 + row) % 2 == 0 else CHARCOAL
            blocks.append(
                f'<path d="M{x} {y} L{x+44} {y-24} L{x+88} {y} L{x+44} {y+24} Z" '
                f'fill="{color}" opacity=".82"/>'
            )
            blocks.append(
                f'<path d="M{x+14} {y} L{x+44} {y-12} L{x+74} {y}" fill="none" '
                f'stroke="{PAPER_LIGHT}" stroke-width="4" opacity=".48"/>'
            )
    top = "".join(blocks)
    body = f'<g id="pattern-top">{top}</g><use href="#pattern-top" transform="rotate(180 500 700)"/>'
    return "", body


PATTERN_BUILDERS = (
    rosette_pattern, guilloche_pattern, botanical_pattern,
    diamond_pattern, star_pattern, linocut_pattern,
)


def candidate_svg(candidate: dict) -> str:
    defs, pattern = PATTERN_BUILDERS[candidate["number"] - 1]()
    return f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
      width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">
      <defs>
        <clipPath id="card-clip"><rect width="1000" height="1400" rx="154"/></clipPath>
        <clipPath id="pattern-clip"><rect x="88" y="88" width="824" height="1224" rx="82"/></clipPath>
        {defs}
      </defs>
      <g clip-path="url(#card-clip)">
        <rect width="1000" height="1400" fill="{PAPER}"/>
        <rect x="20" y="20" width="960" height="1360" rx="136" fill="none"
              stroke="{PAPER_LIGHT}" stroke-width="18" opacity=".22"/>
        <g clip-path="url(#pattern-clip)">{pattern}</g>
        {mirrored_marks(candidate["number"])}
        {common_border()}
      </g>
    </svg>\n"""


def render_svg(svg: Path, output: Path) -> Image.Image:
    subprocess.run(
        ["rsvg-convert", "-w", str(WIDTH), "-h", str(HEIGHT), "-o", str(output), str(svg)],
        check=True, capture_output=True,
    )
    return Image.open(output).convert("RGBA")


def rotation_rms(image: Image.Image) -> float:
    array = np.asarray(image, dtype=np.float32)
    rotated = np.rot90(array, 2)
    return float(np.sqrt(np.mean((array - rotated) ** 2)))


def phone_pattern_contrast(image: Image.Image) -> float:
    phone = image.convert("RGB").resize((72, 101), Image.LANCZOS)
    array = np.asarray(phone, dtype=np.float32)
    luminance = array[:, :, 0] * .2126 + array[:, :, 1] * .7152 + array[:, :, 2] * .0722
    center = luminance[7:-7, 7:-7]
    return float(center.std())


def review_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(
        "/System/Library/Fonts/HelveticaNeue.ttc", size, index=1 if bold else 0
    )


def make_atlas(cards: list[Image.Image], output: Path) -> None:
    thumb = (280, 392)
    label_h, margin = 48, 32
    canvas = Image.new("RGBA", (margin * 3 + thumb[0] * 2,
                                margin * 4 + (thumb[1] + label_h) * 3), REVIEW_BG)
    draw = ImageDraw.Draw(canvas)
    font = review_font(21, True)
    for index, (candidate, card) in enumerate(zip(CANDIDATES, cards)):
        col, row = index % 2, index // 2
        x = margin + col * (thumb[0] + margin)
        y = margin + row * (thumb[1] + label_h + margin)
        canvas.alpha_composite(card.resize(thumb, Image.LANCZOS), (x, y))
        draw.text((x, y + thumb[1] + 10), f'{candidate["number"]} · {candidate["name"]}',
                  fill=(226, 217, 198), font=font)
    canvas.convert("RGB").save(output)


def make_phone_fan(cards: list[Image.Image], output: Path) -> None:
    canvas = Image.new("RGBA", (390, 180), REVIEW_BG)
    positions = (-100, -60, -20, 20, 60, 100)
    angles = (-17, -10, -4, 4, 10, 17)
    for card, offset, angle in zip(cards, positions, angles):
        rendered = card.resize((72, 101), Image.LANCZOS).rotate(-angle, Image.BICUBIC, expand=True)
        x = round(195 + offset - rendered.width / 2)
        y = round(34 + abs(offset) * .08)
        canvas.alpha_composite(rendered, (x, y))
    canvas.convert("RGB").save(output)


def make_detail_sheet(cards: list[Image.Image], output: Path) -> None:
    crop_w, crop_h, label_h = 320, 240, 28
    canvas = Image.new("RGB", (crop_w * 3, (crop_h + label_h) * 2), REVIEW_BG[:3])
    draw = ImageDraw.Draw(canvas)
    font = review_font(17, True)
    centers = ((360, 350), (500, 300), (340, 430), (500, 360), (420, 320), (500, 420))
    for index, (candidate, card, center) in enumerate(zip(CANDIDATES, cards, centers)):
        left, top = center[0] - crop_w // 2, center[1] - crop_h // 2
        crop = card.crop((left, top, left + crop_w, top + crop_h)).convert("RGB")
        x, y = (index % 3) * crop_w, (index // 3) * (crop_h + label_h)
        canvas.paste(crop, (x, y))
        draw.text((x + 7, y + crop_h + 4), f'{candidate["number"]} · 1:1-Detail',
                  fill=(226, 217, 198), font=font)
    canvas.save(output)


def selection_html(report: dict) -> str:
    cards_html = []
    for candidate in report["candidates"]:
        favorite = '<span class="favorite">Favorit</span>' if candidate.get("favorite") else ""
        scores = candidate["scores"]
        cards_html.append(f"""
        <article class="candidate">
          <figure><img src="candidate-{candidate['number']:02d}-{candidate['slug']}.png"
            alt="Kartenrücken Kandidat {candidate['number']}: {candidate['name']}">
            <figcaption><span>{candidate['number']:02d}</span> {candidate['name']} {favorite}</figcaption>
          </figure>
          <p class="direction">{candidate['direction']}</p>
          <p>{candidate['verdict']}</p>
          <dl><div><dt>Authentizität</dt><dd>{scores['authenticity']:.1f}</dd></div>
              <div><dt>Phone</dt><dd>{scores['phone']:.1f}</dd></div>
              <div><dt>Druck</dt><dd>{scores['printability']:.1f}</dd></div></dl>
          <p class="damage">V10.2 · {candidate['damage']}</p>
        </article>""")
    return f"""<!doctype html><html lang="de"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Poch 1441 · Kartenrücken W3 Auswahl</title>
    <style>
    :root{{--paper:#d4c5a7;--ink:#282b2d;--indigo:#34495b;--canvas:#ebe4d7}}
    *{{box-sizing:border-box}}body{{margin:0;background:var(--canvas);color:var(--ink);
      font:16px/1.45 -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif}}
    main{{max-width:1120px;margin:auto;padding:52px 28px 80px}}header{{max-width:760px;margin-bottom:38px}}
    h1{{font:600 clamp(34px,5vw,58px)/1.02 Georgia,serif;margin:0 0 18px;letter-spacing:-.025em}}
    .lead{{font-size:19px;color:#56534d}}.favorite-note{{padding:18px 20px;background:#d8cfbc;
      border-left:4px solid var(--indigo);border-radius:0 14px 14px 0}}
    .grid{{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:28px}}
    .candidate{{background:#f3ede2;border:1px solid #cfc5b3;border-radius:24px;padding:20px;
      box-shadow:0 14px 34px #554b3d14}}figure{{margin:0}}figure img{{display:block;width:100%;max-height:650px;
      object-fit:contain;background:#211f1d;border-radius:16px;padding:18px}}
    figcaption{{font:600 24px/1.2 Georgia,serif;margin-top:16px}}figcaption>span{{font:500 13px/1 sans-serif;
      display:inline-grid;place-items:center;width:30px;height:30px;border:1px solid #9e927e;border-radius:50%}}
    .favorite{{font:600 12px/1 sans-serif;color:white;background:var(--indigo);padding:6px 9px;
      border-radius:99px;vertical-align:middle}}.direction{{color:#34495b;font-weight:650}}
    dl{{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:18px 0 12px}}dl div{{background:#e6ddcd;
      padding:10px;border-radius:12px}}dt{{font-size:11px;color:#6d675d;text-transform:uppercase;letter-spacing:.05em}}
    dd{{font:600 21px Georgia,serif;margin:2px 0 0}}.damage{{font-size:12px;color:#777066}}
    .evidence{{margin-top:48px;display:grid;gap:22px}}.evidence img{{width:100%;background:#211f1d;
      border-radius:18px}}@media(max-width:720px){{main{{padding:32px 16px 60px}}.grid{{grid-template-columns:1fr}}
      .candidate{{padding:14px}}}}
    </style></head><body><main><header><h1>W3 · Historische Kartenrücken</h1>
    <p class="lead">Sechs originale, code-native Druckrichtungen auf warmem, leicht gealtertem Kartenpapier.
    Alle Grundmuster sind 180°-symmetrisch; Beschriftung liegt ausschließlich außerhalb der Karten.</p>
    <p class="favorite-note"><strong>Empfehlung: 02 Guilloche-Bandgewebe.</strong> Es verbindet die höchste
    historische Glaubwürdigkeit mit klarer Phone-Lesbarkeit und zuverlässiger Zweiton-Druckbarkeit.</p></header>
    <section class="grid">{''.join(cards_html)}</section>
    <section class="evidence"><h2>Vergleich im Nutzungskontext</h2>
      <img src="w3-phone-fan.png" alt="Sechs Kartenrücken im 390 Pixel Phone-Fächer">
      <img src="w3-detail-sheet.png" alt="Nahdetails aller sechs Druckmuster">
      <img src="w3-selection-atlas.png" alt="Zwei mal drei Auswahl-Atlas"></section>
    </main></body></html>"""


def generate(output: Path) -> None:
    output.mkdir(parents=True, exist_ok=False)
    rendered_cards: list[Image.Image] = []
    report_candidates: list[dict] = []
    with tempfile.TemporaryDirectory(prefix="poch-w3-render-") as temporary:
        temporary_root = Path(temporary)
        for candidate in CANDIDATES:
            stem = f"candidate-{candidate['number']:02d}-{candidate['slug']}"
            svg_path = output / f"{stem}.svg"
            svg_path.write_text(candidate_svg(candidate), encoding="utf-8")
            clean_path = temporary_root / f"{stem}-clean.png"
            clean = render_svg(svg_path, clean_path)
            overlay = damage.back_damage_overlay(clean.size, candidate["damage_variant"])
            rendered = Image.alpha_composite(clean, overlay)
            rendered.save(output / f"{stem}.png")
            rendered_cards.append(rendered)
            alpha = np.asarray(overlay.getchannel("A"), dtype=np.uint8)
            report_candidates.append({
                **candidate,
                "clean_rotation_rms": round(rotation_rms(clean), 5),
                "phone_pattern_contrast": round(phone_pattern_contrast(clean), 3),
                "damage_alpha_coverage": round(float(np.count_nonzero(alpha) / alpha.size), 7),
                "svg_sha256": hashlib.sha256(svg_path.read_bytes()).hexdigest(),
                "png_sha256": hashlib.sha256((output / f"{stem}.png").read_bytes()).hexdigest(),
            })
    make_phone_fan(rendered_cards, output / "w3-phone-fan.png")
    make_atlas(rendered_cards, output / "w3-selection-atlas.png")
    make_detail_sheet(rendered_cards, output / "w3-detail-sheet.png")
    report = {
        "canvas": [WIDTH, HEIGHT],
        "favorite": 2,
        "favorite_name": "Guilloche-Bandgewebe",
        "palette": {"paper": PAPER, "indigo": INDIGO, "charcoal": CHARCOAL},
        "candidates": report_candidates,
    }
    (output / "index.html").write_text(selection_html(report), encoding="utf-8")
    (output / "w3-selection-report.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    generate(args.output)
    print(f"Six W3 card-back candidates -> {args.output}")


if __name__ == "__main__":
    main()
