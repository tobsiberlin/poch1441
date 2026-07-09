#!/usr/bin/env python3
"""Poch-Ring Material-Sichtung via Replicate.

Ziel: Look-/Materialreferenzen fuer den Poch-Ring erzeugen. Die finalen
Labels, Werte, Touch-Zonen und Morph-Geometrien bleiben Code/Vektor. Das
Modell darf keine Schrift, Zahlen oder finalen UI-Text erzeugen.
"""
import base64
import json
import os
import sys
import time
from io import BytesIO
from pathlib import Path

import replicate
import requests
from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/Users/tobsi/poch1441")
RAW = ROOT / "Assets_Raw" / "pochring" / "replicate"
ART = ROOT / "artifacts" / "pochring"
HTML = ROOT / "artifacts" / "pochring-sichtung.html"
TEMP_HTML = Path("/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/pochring-sichtung.html")
LOG = RAW / "log.json"

RAW.mkdir(parents=True, exist_ok=True)
ART.mkdir(parents=True, exist_ok=True)

KEY_FILE = Path("~/.config/replicate.key").expanduser()
if KEY_FILE.exists():
    os.environ["REPLICATE_API_TOKEN"] = KEY_FILE.read_text().strip()

MODEL = "black-forest-labs/flux-1.1-pro"
DATE = "2026-07-08"

GUARDS = (
    "top-down product design render, no text, no letters, no numbers, "
    "no typography, no logo, no watermark, no playing cards, no poker chips, "
    "no casino, no roulette wheel, no slot machine, no neon arcade, "
    "no cyberpunk, no glowing button UI, no chrome, no glossy plastic, "
    "no luminous crystals, no LEDs, no small light sources, no gemstones"
)

BASE = (
    "Poch 1441 game board ring concept, circular nine-basin game board, "
    "one central basin and eight surrounding recessed basins, clean modern "
    "premium tabletop object, warm ink-black material, matte jewel tone accents "
    "(muted gold, garnet rose, emerald teal, restrained amethyst, soft platinum), "
    "material over glow, precise milled edges, soft studio light, readable "
    "silhouette, luxurious but restrained"
)

JOBS = [
    {
        "label": "A",
        "name": "Gefraester Monolith",
        "seed": 144101,
        "prompt": (
            BASE + ", a single matte black monolithic disc with nine concave "
            "recesses cut into it, very thin warm platinum bevels, jewel color "
            "only as subtle inlay strips inside each basin, quiet high-end object, "
            "Apple Watch Ultra material restraint, not an interface mockup, " + GUARDS
        ),
    },
    {
        "label": "B",
        "name": "Siegel-Medaillon",
        "seed": 144102,
        "prompt": (
            BASE + ", large seal medallion language, circular crest-like board, "
            "radial basins framed like a premium signet ring, dark engraved stone, "
            "thin brushed graphite and platinum ridges, restrained jewel inlays, "
            "brand-signature object not casino, " + GUARDS
        ),
    },
    {
        "label": "C",
        "name": "Mechanisches Uhrwerk",
        "seed": 144103,
        "prompt": (
            BASE + ", precise mechanical watch dial construction, segmented plates "
            "with tiny shadow gaps, eight outer basins seated like machined parts, "
            "central pot basin slightly deeper, matte graphite and ink-black layers, "
            "very subtle gold catchlights, tactile engineered feel, " + GUARDS
        ),
    },
    {
        "label": "D",
        "name": "Juwelen-Fassungen",
        "seed": 144104,
        "prompt": (
            BASE + ", each basin is a matte gemstone setting, jewel pigments are "
            "embedded mineral surfaces rather than lights, garnet, emerald, "
            "amethyst, warm gold and platinum facets set into black ceramic, "
            "clear category-color labeling by material only, elegant and calm, " + GUARDS
        ),
    },
    {
        "label": "E",
        "name": "Monolith v2",
        "seed": 144105,
        "prompt": (
            BASE + ", strict orthographic top-down view, one solid warm black "
            "ceramic disc, eight shallow rounded rectangular outer basins and one "
            "round central basin, no shiny bowls, no jewels, no light sources, "
            "muted pigment inlay bands painted into each basin, hairline graphite "
            "bevels, extremely matte, restrained luxury board game component, " + GUARDS
        ),
    },
    {
        "label": "F",
        "name": "Gefraeste Mulden",
        "seed": 144106,
        "prompt": (
            BASE + ", strict flat product reference, recessed basins carved into "
            "black anodized metal and matte stone, the basins are dark cavities "
            "with thin colored mineral rims only, large calm center pot, no gold "
            "outer hoop, no ornamental medallion, no watch dial, no lights, " + GUARDS
        ),
    },
    {
        "label": "G",
        "name": "Intarsien-Ring",
        "seed": 144107,
        "prompt": (
            BASE + ", flat inlay marquetry board, color appears as satin mineral "
            "intarsia strips flush with the black surface, eight outer wedge-like "
            "recesses around a central pot, very low relief, soft shadow only, "
            "premium board game object, no glossy gem facets, no glow, " + GUARDS
        ),
    },
    {
        "label": "H",
        "name": "Ruhiges Siegel v2",
        "seed": 144108,
        "prompt": (
            BASE + ", quiet circular seal object, wide negative-space center, "
            "eight outer basins as understated carved plaques, subtle platinum "
            "hairlines and muted pigment fills, no starburst, no flower medallion, "
            "no jewelry, no casino chip, calm modern premium design, " + GUARDS
        ),
    },
]


def fetch_output(output):
    if hasattr(output, "read"):
        return output.read()
    item = output[0] if isinstance(output, list) else output
    if hasattr(item, "url"):
        item = item.url
    response = requests.get(str(item), timeout=180)
    response.raise_for_status()
    return response.content


def label_image(src: Path, dest: Path, label: str, name: str):
    img = Image.open(src).convert("RGB")
    img.thumbnail((960, 960), Image.Resampling.LANCZOS)
    pad = 78
    out = Image.new("RGB", (img.width, img.height + pad), (10, 8, 12))
    out.paste(img, (0, pad))
    draw = ImageDraw.Draw(out)
    try:
        font_big = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 30)
        font_small = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 20)
    except OSError:
        font_big = ImageFont.load_default()
        font_small = ImageFont.load_default()
    draw.text((18, 14), label, fill=(226, 232, 240), font=font_big)
    draw.text((70, 20), name, fill=(197, 160, 89), font=font_small)
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)


def generate(only: set[str]):
    log = json.loads(LOG.read_text()) if LOG.exists() else {}
    for job in JOBS:
        label = job["label"]
        if only and label not in only:
            continue
        raw_path = RAW / f"ring-{label}.png"
        labeled_path = ART / f"ring-{label}.png"
        if raw_path.exists() and not only:
            print(f"[{label}] existiert, skip")
            label_image(raw_path, labeled_path, label, job["name"])
            continue
        print(f"[{label}] {job['name']} via {MODEL}")
        for attempt in range(3):
            try:
                t0 = time.time()
                output = replicate.run(
                    MODEL,
                    input={
                        "prompt": job["prompt"],
                        "aspect_ratio": "1:1",
                        "output_format": "png",
                        "output_quality": 100,
                        "prompt_upsampling": False,
                        "safety_tolerance": 2,
                        "seed": job["seed"],
                    },
                )
                raw_path.write_bytes(fetch_output(output))
                label_image(raw_path, labeled_path, label, job["name"])
                log[label] = {
                    "date": DATE,
                    "model": MODEL,
                    "seed": job["seed"],
                    "name": job["name"],
                    "prompt": job["prompt"],
                    "raw": str(raw_path.relative_to(ROOT)),
                    "labeled": str(labeled_path.relative_to(ROOT)),
                }
                print(f"[{label}] ok ({time.time() - t0:.0f}s)")
                break
            except Exception as exc:
                msg = str(exc)
                if "insufficient credit" in msg.lower() or "payment" in msg.lower():
                    print("!!! Replicate-Guthaben/Payment blockiert - Abbruch")
                    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False))
                    sys.exit(2)
                print(f"[{label}] Fehler {attempt + 1}: {msg[:220]}")
                time.sleep(4)
        else:
            print(f"[{label}] FEHLGESCHLAGEN")
    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False))


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def write_html():
    cards = []
    notes = {
        "A": "Ruhigste Richtung. Pruefen: liest der Ring als wertiges Spielobjekt oder zu leer?",
        "B": "Staerkste Markennaehe. Pruefen: Signet-Charakter ohne Heraldik/Kitsch.",
        "C": "Beste Mechanik-Sprache. Pruefen: Uhrwerk ja, Tech-Interface nein.",
        "D": "Farbe=Label am klarsten. Pruefen: Juwel-Fassung ohne Bonbon/Arcade.",
        "E": "Retake aus A: matte Pigment-Inlays statt Lichtpunkte. Kandidat fuer Code-Uebersetzung.",
        "F": "Retake mit dunklen Mulden und farbigen Mineral-Raendern. Kandidat fuer beste Lesbarkeit.",
        "G": "Flacher Intarsien-Ring. Pruefen: elegant oder zu nah an Mockup-Segmentrad?",
        "H": "Ruhiges Siegel ohne Schmuckglanz. Pruefen: markant genug fuer Phase 1?",
    }
    for job in JOBS:
        path = ART / f"ring-{job['label']}.png"
        if not path.exists():
            continue
        cards.append(f"""
        <section class="card">
          <img src="data:image/png;base64,{b64(path)}" alt="{job['label']} {job['name']}">
          <h2>{job['label']} · {job['name']}</h2>
          <p>{notes[job['label']]}</p>
        </section>
        """)
    html = f"""<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Poch-Ring Sichtung</title>
  <style>
    :root {{ color-scheme: dark; --bg:#08070b; --panel:#131018; --text:#e2e8f0; --muted:#8b93a0; --gold:#c5a059; }}
    body {{ margin:0; background:var(--bg); color:var(--text); font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif; }}
    header {{ max-width:1180px; margin:0 auto; padding:28px 22px 10px; }}
    h1 {{ margin:0 0 8px; font-size:28px; letter-spacing:.02em; }}
    .lead {{ margin:0; color:var(--muted); max-width:900px; line-height:1.45; }}
    main {{ max-width:1180px; margin:0 auto; padding:18px 22px 36px; display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:18px; }}
    .card {{ background:linear-gradient(180deg,#17131d,#0f0d13); border:1px solid rgba(197,160,89,.22); border-radius:10px; padding:12px; }}
    img {{ display:block; width:100%; border-radius:6px; background:#09070c; }}
    h2 {{ font-size:16px; margin:12px 2px 4px; color:var(--gold); }}
    p {{ color:var(--muted); margin:0 2px 4px; line-height:1.35; font-size:13px; }}
    .rule {{ max-width:1136px; margin:0 auto 24px; padding:0 22px; color:#aeb6c2; font-size:13px; }}
    code {{ color:var(--gold); }}
  </style>
</head>
<body>
  <header>
    <h1>Poch-Ring Sichtung · Materialrichtungen</h1>
    <p class="lead">Diese Bilder sind Look-Referenzen, keine finalen UI-Assets. Final bleiben Labels, Werte, Touch-Zonen, Animationen und Morph-Geometrie in SwiftUI/SpriteKit. Verboten bleiben Casino, Neon-Arcade, KI-Schrift und generierte Zahlen.</p>
  </header>
  <main>
    {''.join(cards)}
  </main>
  <div class="rule">Rohbilder: <code>Assets_Raw/pochring/replicate/</code> · gelabelte Sichtung: <code>artifacts/pochring/</code> · Log: <code>{LOG.relative_to(ROOT)}</code></div>
</body>
</html>
"""
    HTML.write_text(html, encoding="utf-8")
    TEMP_HTML.write_text(html, encoding="utf-8")
    print("HTML:", HTML)
    print("TEMP:", TEMP_HTML)


def main():
    only = {arg for arg in sys.argv[1:] if not arg.startswith("--")}
    generate(only)
    write_html()


if __name__ == "__main__":
    main()
