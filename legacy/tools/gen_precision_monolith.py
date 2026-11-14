#!/usr/bin/env python3
"""Precision-Monolith-Sichtung fuer den Poch-Ring.

Fokussierte Retake-Runde nach externer Feedback-Aggregation:
F/E/A/H -> gefraester Graphit-Monolith, tiefe dunkle Mulden,
matte Pigment-Inlays, keine Casino-/Roulette-/Glow-Sprache.
"""
import base64
import json
import math
import os
import sys
import time
from io import BytesIO
from pathlib import Path

import replicate
import requests
from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/Users/tobsi/poch1441")
RAW = ROOT / "Assets_Raw" / "pochring" / "precision-monolith"
ART = ROOT / "artifacts" / "precision-monolith"
HTML = ROOT / "artifacts" / "precision-monolith-sichtung.html"
TEMP_HTML = Path("/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/precision-monolith-sichtung.html")
LOG = RAW / "log.json"

RAW.mkdir(parents=True, exist_ok=True)
ART.mkdir(parents=True, exist_ok=True)

KEY_FILE = Path("~/.config/replicate.key").expanduser()
if KEY_FILE.exists():
    os.environ["REPLICATE_API_TOKEN"] = KEY_FILE.read_text().strip()

MODEL = "black-forest-labs/flux-1.1-pro"
DATE = "2026-07-08"

GUARDS = (
    "strict orthographic top-down product reference, no text, no letters, no numbers, "
    "no typography, no logos, no watermark, no playing cards, no poker chips, "
    "no casino, no roulette wheel, no slot machine, no wheel of fortune, "
    "no neon arcade, no cyberpunk, no glowing UI, no underglow, no LEDs, "
    "no luminous crystals, no glossy gemstones, no heraldic star, no rosette, "
    "no watch dial, no gears, no radial tick marks, no continuous gold outer ring"
)

BASE = (
    "Precision Monolith Poch board ring for a premium iOS card strategy game, "
    "one massive matte warm-black graphite ceramic disc, eight outer recessed basins "
    "and one larger central pot basin, physical luxury board game object, "
    "material over glow, quiet dark premium aesthetic, soft directional studio light, "
    "fine graphite bevels, subtle ambient occlusion, readable at small mobile size"
)

JOBS = [
    {
        "label": "PM1",
        "name": "Graphit-Mulden",
        "seed": 144151,
        "prompt": (
            BASE + ", deep circular dark basins with satin mineral pigment inner rims, "
            "pigment rims are muted gold, garnet rose, emerald teal, restrained amethyst "
            "and soft platinum, basin floors almost black, no shiny stones, no bright gold, "
            "only hairline edge lighting on bevels, very calm and precise, " + GUARDS
        ),
    },
    {
        "label": "PM2",
        "name": "Pigment-Cabochons",
        "seed": 144152,
        "prompt": (
            BASE + ", each basin contains a flat matte pigment cabochon disc embedded flush "
            "inside a dark recessed cavity, cabochons are satin not glossy, color is muted "
            "mineral pigment, central pot is empty dark platinum-rimmed bowl, no ornaments, "
            "no decorative symbols, highly restrained, " + GUARDS
        ),
    },
    {
        "label": "PM3",
        "name": "Plaque-Mulden",
        "seed": 144153,
        "prompt": (
            BASE + ", outer basins are rounded rectangular carved plaques arranged in a ring, "
            "not a roulette wheel, each plaque has a dark floor and a thin matte colored "
            "mineral line on the inner bevel only, central basin is a calm shallow platinum "
            "pot, minimal high-end industrial design, " + GUARDS
        ),
    },
    {
        "label": "PM4",
        "name": "Keramik-Siegel",
        "seed": 144154,
        "prompt": (
            BASE + ", quiet seal-like silhouette with thick heavy outer edge in matte black "
            "ceramic, eight evenly spaced deep bowls cut into the surface, color appears only "
            "as dusted pigment inside the bevel grooves, wide negative-space center, no central "
            "emblem, no starburst, no jewelry, " + GUARDS
        ),
    },
    {
        "label": "PM5",
        "name": "Keramik-Pigment",
        "seed": 144155,
        "prompt": (
            BASE + ", final hybrid design: heavy matte black ceramic and graphite body "
            "like a calm precision seal, eight distinct deep recessed pockets plus one "
            "shallow central platinum pot, each pocket has a dark concave floor and a "
            "thin matte color-coded pigment rim in muted gold, garnet rose, emerald teal "
            "or restrained amethyst, color is mineral pigment not light, no orange edge "
            "glow, no rim lighting around the disc, no glowing points inside the pockets, "
            "no sparkle points, no radial tile segments, no central button, clean empty "
            "center pot with a subtle platinum inner bevel, premium board game instrument, "
            + GUARDS
        ),
    },
    {
        "label": "PM6",
        "name": "Graphit-Pigment",
        "seed": 144156,
        "prompt": (
            BASE + ", final hybrid design: PM1-style deep graphite basins but with PM4-style "
            "heavy quiet ceramic mass, no decorative rim texture, no exterior gold halo, "
            "no tiny ornaments, only matte colored pigment rings on the inner lip of the "
            "eight basins, basin floors are dark and usable like physical bowls for chips, "
            "central pot is broad, shallow, empty, platinum-rimmed and calm, no glow at all, "
            "no lights, no jewels, no segmented roulette structure, " + GUARDS
        ),
    },
    {
        "label": "PM7",
        "name": "Sculpted Pigment Monolith",
        "seed": 144157,
        "prompt": (
            BASE + ", production target design based on PM5 material and PM6 sculpted mass: "
            "exactly eight outer recessed pockets evenly spaced plus one center pot, nine total, "
            "clear Poch board layout, heavy matte black ceramic and graphite body, subtly sculpted "
            "surface transitions between pockets, no radial tile segmentation, no decorative dots, "
            "no screws, no LEDs, each outer pocket is a deep usable concave basin with a consistent "
            "matte cabochon-like pigment inlay or thin pigment rim, all inlays have the same satin "
            "finish, no faceted gems, no sparkle, no gloss, color coding: five muted warm-gold "
            "pockets for face cards, one garnet rose pocket, one emerald teal pocket, one restrained "
            "amethyst pocket, center is a shallow calm platinum-rimmed pot, no central button, no "
            "emblem, no orange edge glow, no rim lighting around the disc, no glowing points, "
            "premium precision board game instrument, " + GUARDS
        ),
    },
    {
        "label": "PM8",
        "name": "PM7 Palette Fix",
        "seed": 144158,
        "prompt": (
            BASE + ", final corrected PM7 body: massive matte graphite ceramic monolith, "
            "neutral studio background, strict orthographic top-down view, exactly eight "
            "outer recessed pockets evenly spaced plus one central pot, 9 total, clear "
            "Poch board layout, no extra dots or markers. The outer pockets are deep, "
            "usable, concave basins with smooth rounded inner radii. Color-coded matte "
            "pigment inlays: five pockets use muted warm gold pigment for face cards, "
            "one pocket uses deep garnet red pigment, one pocket uses emerald teal pigment, "
            "one pocket uses restrained amethyst purple pigment, all hues clearly distinct, "
            "no copper, no bronze, no orange. All inlays are matte satin pigment or matte "
            "cabochon finish, no metallic sheen, no specular highlights, no faceted gems, "
            "no sparkle. Center is a clean shallow recessed graphite-platinum pot with a "
            "thin matte platinum inner bevel, no central button, no emblem. No floating "
            "diamonds, no kite shapes, no ornament near the center, no decorative symbols. "
            "No glow, no edge lighting, no rim lighting, no luminous points, premium "
            "precision board game instrument, " + GUARDS + ", no copper, no bronze, "
            "no metallic bowls, no diamond shapes"
        ),
    },
    {
        "label": "PM9",
        "name": "Pigment-Rim Final",
        "seed": 144160,
        "prompt": (
            "matte clay product render of a physical Poch board, diffuse soft daylight, "
            "neutral dark grey background, absolutely no emissive materials. Massive "
            "matte graphite ceramic monolith, strict orthographic top-down view, exactly "
            "eight outer recessed pockets evenly spaced plus one central recessed pot, "
            "9 total, clear simple Poch board layout. Each outer pocket is a deep empty "
            "concave dark basin for holding coins, with smooth rounded inner radii. The "
            "only color is a very thin dark matte painted pigment line on the upper inner "
            "lip of each basin, not a glowing ring, not bright, not metallic. Color coding: "
            "five pockets have muted dark ochre-gold pigment lines, one pocket has deep "
            "garnet red pigment line, one pocket has dark emerald teal pigment line, one "
            "pocket has dark amethyst purple pigment line. The central pot is dark graphite "
            "with a thin matte warm-platinum painted line. Empty basins, no coins, no text, "
            "no labels, no numbers, no central button, no emblem, no floating diamonds, no "
            "dot markers, no decorative symbols, no outer colored ring, no segmented roulette "
            "structure, no radial tick marks. No glow, no neon, no LEDs, no luminous points, "
            "no rim lighting, no edge lighting, no glossy gems, no faceted inlays, no sparkle, "
            "no orange, no copper, no bronze, no metallic bowls, premium precision board game "
            "instrument, " + GUARDS + ", matte paint only, unlit pigment"
        ),
    },
    {
        "label": "PM10",
        "name": "PM1 Full Bezel A",
        "seed": 144161,
        "prompt": (
            "PM1-style graphite Poch board, matte black graphite ceramic circular monolith, "
            "strict orthographic top-down product render, exactly eight deep circular outer "
            "basins plus one large central basin, 9 total, all eight outer basins have a "
            "consistent thin matte colored ceramic bezel around the upper inner lip, every "
            "basin has a bezel, no basin is uncolored. Bezel colors: five muted dark ochre-gold, "
            "one deep garnet red, one dark emerald teal, one restrained amethyst purple, all "
            "matte pigment, all same thickness. Basin floors are empty, black, concave and "
            "usable for coins. Body has subtle PM1-like engraved graphite texture, no exterior "
            "gold halo, no tiny sparkle points, no decorative dots, no screws, no diamonds, "
            "no center emblem, no text, no labels, no numbers, no glow, no neon, no LED, no "
            "rim lighting, no luminous materials, no roulette, no casino, no 3x3 grid, "
            "premium precision board game object, no colored discs at basin bottom"
        ),
    },
    {
        "label": "PM11",
        "name": "PM1 Full Bezel B",
        "seed": 144162,
        "prompt": (
            "PM1-inspired precision monolith Poch board, circular heavy matte graphite body, "
            "orthographic top-down, eight evenly spaced deep black concave pockets and one "
            "large clean center pot, exact 8 plus center layout. Each pocket has a very subtle "
            "matte mineral-pigment inlay ring on the bevel, continuous but understated, not "
            "glowing, not metallic. Five rings are muted warm gold, one ring garnet rose, one "
            "ring emerald teal, one ring amethyst violet, center pot has a thin matte platinum "
            "bezel. Fine graphite surface grain and soft ambient occlusion like PM1, no outer "
            "gold ring, no ornaments, no dot markers, no faceted gems, no colored discs on "
            "the bottom, no text, no symbol, no neon, no glow, no LEDs, no roulette wheel, "
            "no casino chip, no square board"
        ),
    },
    {
        "label": "PM12",
        "name": "PM1 Full Bezel C",
        "seed": 144163,
        "prompt": (
            "refined PM1 graphite basins variant, dark premium circular Poch board object, "
            "top-down orthographic view, exactly eight outer coin basins arranged in a ring "
            "around one central coin basin. All eight basins are identical deep matte black "
            "bowls with consistent colored pigment bezels on their upper lip; the color is "
            "painted ceramic pigment, low contrast, satin matte. Five basins have dark gold "
            "bezels, one has garnet, one has emerald teal, one has amethyst, center has a "
            "platinum bezel. No glow anywhere, no illuminated rings, no full outer gold ring, "
            "no extra pockets, no markers, no screws, no diamonds, no heraldic ornament, no "
            "center logo, no text, no labels, no numbers, no coins, no casino, no roulette, "
            "soft neutral product lighting, Apple Watch Ultra graphite material restraint"
        ),
    },
    {
        "label": "PM13",
        "name": "PM1 Geometry Fix",
        "seed": None,
        "prompt": "Procedural PM1 material study: exact 8+center geometry, subtle matte pigment rings on all basins.",
    },
    {
        "label": "PM14",
        "name": "PM7 Symmetric Metal A",
        "seed": 144164,
        "prompt": (
            "PM7-style premium Poch board object, strict orthographic top-down product render, "
            "perfectly symmetrical circular layout with exactly eight outer deep recessed basins "
            "plus one larger central recessed basin, 9 total. Keep the PM7 sculpted monolith body: "
            "massive matte graphite ceramic, broad soft bevels, premium physical board-game object. "
            "Each basin is a smooth concave metal-lined bowl with subdued satin metallic sheen, "
            "not glossy, not glowing. Muted premium metal tones: five dark antique-gold basins, "
            "one deep garnet metal basin, one dark emerald teal metal basin, one muted amethyst "
            "metal basin, center basin graphite with restrained platinum metal lip. All basins "
            "same size and symmetric, no extra pockets, no dots, no screws, no ornament, no text, "
            "no emblem, no neon, no LEDs, no glow, no roulette, no casino, no 3x3 grid, no square board"
        ),
    },
    {
        "label": "PM15",
        "name": "PM7 Symmetric Metal B",
        "seed": 144165,
        "prompt": (
            "PM7 body language refined into a real luxury Poch board, circular matte black graphite "
            "monolith, top-down orthographic, exactly eight evenly spaced outer concave metal basins "
            "around one central concave pot, 8 plus center, no more and no fewer. The metal inside "
            "the basins has a soft brushed satin reflection, subdued and premium, different muted "
            "jewel-metal tones, not bright color: aged gold, dark rose-garnet, smoky emerald, deep "
            "amethyst, graphite-platinum. Body remains PM7-like sculpted ceramic, heavy and calm. "
            "No outer glowing ring, no illuminated rims, no LEDs, no dot markers, no diamond shapes, "
            "no central knob, no symbol, no text, no coins, no casino, no roulette wheel"
        ),
    },
    {
        "label": "PM16",
        "name": "PM7 Symmetric Metal C",
        "seed": 144166,
        "prompt": (
            "real-world manufacturable premium Poch board, inspired by PM7 sculpted pigment monolith, "
            "round heavy graphite ceramic body, exact functional Poch layout: eight outer bowls and "
            "one center bowl, all symmetrically arranged. Outer bowls are inset metal cups with muted "
            "anodized jewel tones, satin brushed finish, gentle metallic highlights only from studio "
            "light, no emission. Five bowls warm aged-gold, one garnet, one emerald teal, one amethyst, "
            "center bowl dark graphite with platinum rim. Looks like an expensive physical game board "
            "that could be manufactured, not UI, not fantasy. No glow, no neon, no extra bowls, no "
            "markers, no decorative symbols, no text, no roulette, no poker chip, no slot machine"
        ),
    },
    {
        "label": "PM17",
        "name": "PM1 Centerpot A",
        "seed": None,
        "prompt": "Procedural PM1 material study: exact 8+center geometry, very subtle rings.",
    },
    {
        "label": "PM18",
        "name": "PM1 Centerpot B",
        "seed": None,
        "prompt": "Procedural PM1 material study: exact 8+center geometry, slightly clearer rings and deeper basins.",
    },
    {
        "label": "PM19",
        "name": "PM1 Centerpot C",
        "seed": None,
        "prompt": "Procedural PM1 material study: exact 8+center geometry, quietest premium rings.",
    },
    {
        "label": "PM20",
        "name": "PM7 Metal Mulden A",
        "seed": None,
        "prompt": "Procedural PM7 metal-basin study: symmetric 8+center, subdued mixed premium metal tones.",
    },
    {
        "label": "PM21",
        "name": "PM7 Metal Mulden B",
        "seed": None,
        "prompt": "Procedural PM7 metal-basin study: stronger satin metal cups, symmetric 8+center.",
    },
    {
        "label": "PM22",
        "name": "PM7 Metal Mulden C",
        "seed": None,
        "prompt": "Procedural PM7 metal-basin study: darkest muted metal, symmetric 8+center.",
    },
    {
        "label": "PM23",
        "name": "PM1 True Edit A",
        "seed": None,
        "prompt": "Minimal edit of original PM1: keep PM1 material, add center basin and subtle colored rings on existing basin lips.",
    },
    {
        "label": "PM24",
        "name": "PM1 True Edit B",
        "seed": None,
        "prompt": "Minimal edit of original PM1: deeper center basin, slightly clearer PM1-style colored rings on existing basin lips.",
    },
    {
        "label": "PM25",
        "name": "PM1 True Edit C",
        "seed": None,
        "prompt": "Minimal edit of original PM1: quietest center basin and very subtle PM1-style rings on all existing basin lips.",
    },
    {
        "label": "PM26",
        "name": "PM1 Lip Edit A",
        "seed": None,
        "prompt": "Minimal edit of original PM1: clipped pigment only on dark basin lips, center basin added.",
    },
    {
        "label": "PM27",
        "name": "PM1 Lip Edit B",
        "seed": None,
        "prompt": "Minimal edit of original PM1: deeper center basin and clipped understated pigment lips.",
    },
    {
        "label": "PM28",
        "name": "PM1 Lip Edit C",
        "seed": None,
        "prompt": "Minimal edit of original PM1: quietest clipped pigment lips and smaller center basin.",
    },
    {
        "label": "PM29",
        "name": "PM1 Center Only",
        "seed": None,
        "prompt": "Original PM1 kept almost untouched: only add the missing center basin.",
    },
    {
        "label": "PM30",
        "name": "PM1 Lip Arcs A",
        "seed": None,
        "prompt": "Original PM1 with center basin and partial PM1-style pigment catches on every basin lip.",
    },
    {
        "label": "PM31",
        "name": "PM1 Lip Arcs B",
        "seed": None,
        "prompt": "Original PM1 with center basin and very quiet partial pigment catches on every basin lip.",
    },
    {
        "label": "PM32",
        "name": "PM1 Clean Inlay A",
        "seed": None,
        "prompt": "Original PM1 with center basin and complete, thin, unchipped pigment inlays inside every basin lip.",
    },
    {
        "label": "PM33",
        "name": "PM1 Clean Inlay B",
        "seed": None,
        "prompt": "Original PM1 with center basin and quieter complete pigment inlays inside every basin lip.",
    },
    {
        "label": "PM34",
        "name": "PM1 Clean Inlay C",
        "seed": None,
        "prompt": "Original PM1 with smaller center basin and most subtle complete pigment inlays.",
    },
    {
        "label": "PM35",
        "name": "PM1 Center Fixed A",
        "seed": None,
        "prompt": "Original PM1 with precisely centered, symmetric center basin and complete thin pigment inlays.",
    },
    {
        "label": "PM36",
        "name": "PM1 Center Fixed B",
        "seed": None,
        "prompt": "Original PM1 with precisely centered normal-size center basin and quieter complete pigment inlays.",
    },
    {
        "label": "PM37",
        "name": "PM1 Center Fixed C",
        "seed": None,
        "prompt": "Original PM1 with precisely centered smaller center basin and subtle complete pigment inlays.",
    },
    {
        "label": "PM38",
        "name": "PM1 Real Board A",
        "seed": None,
        "prompt": "PM1-reference retake: rebuild correct 8+center physical Poch board, subtle complete inlays.",
    },
    {
        "label": "PM39",
        "name": "PM1 Real Board B",
        "seed": None,
        "prompt": "PM1-reference retake: wider functional coin basins, quieter complete inlays, centered pot.",
    },
    {
        "label": "PM40",
        "name": "PM1 Real Board C",
        "seed": None,
        "prompt": "PM1-reference retake: strongest PM1 preservation, corrected 8+center geometry.",
    },
    {
        "label": "PM41",
        "name": "Real Mulden A",
        "seed": None,
        "prompt": "Procedural physical board: exact 8+center coin basins, flat floors, PM1-inspired graphite material.",
    },
    {
        "label": "PM42",
        "name": "Real Mulden B",
        "seed": None,
        "prompt": "Procedural physical board: larger outward coin basins, smaller center, subtle PM1-inspired inlays.",
    },
    {
        "label": "PM43",
        "name": "Real Mulden C",
        "seed": None,
        "prompt": "Procedural physical board: quietest real coin basins, flatter floors, minimal inlays.",
    },
    {
        "label": "PM44",
        "name": "Real Graphite A",
        "seed": None,
        "prompt": "Procedural physical board V2: dark PM1-like graphite, exact 8+center real basins, visible inlays.",
    },
    {
        "label": "PM45",
        "name": "Real Graphite B",
        "seed": None,
        "prompt": "Procedural physical board V2: larger outward basins, smaller center, subdued but visible inlays.",
    },
    {
        "label": "PM46",
        "name": "Real Graphite C",
        "seed": None,
        "prompt": "Procedural physical board V2: quietest graphite/inlay balance with exact functional pockets.",
    },
    {
        "label": "PM47",
        "name": "PM1 Clean Center",
        "seed": None,
        "prompt": "PM1 edit: preserve PM1 material, add center basin, subtle aligned basin rings, aligned gold dots.",
    },
    {
        "label": "PM48",
        "name": "PM47 Geometry Fix",
        "seed": None,
        "prompt": "PM47 refinement: exact 8+center, systematic 5 gold + 3 special inlays, reduced dots/ornament/glow.",
    },
    {
        "label": "PM49",
        "name": "Cockpit 8-Color",
        "seed": None,
        "prompt": "PM48 color study: exact same PM1/PM48 board, but 8 distinct subdued cockpit-derived inlay colors.",
    },
    {
        "label": "PM50",
        "name": "PM1 Original Color Layout",
        "seed": None,
        "prompt": "PM1-faithful retake: original material, large center basin, 4 alternating gold, 2 green opposite, 2 purple opposite.",
    },
    {
        "label": "PM51",
        "name": "PM50 Polish Rule Palette",
        "seed": None,
        "prompt": "Polished PM50: PM1 glossy-satin material, 5 gold + garnet + emerald + amethyst, aligned gold points.",
    },
    {
        "label": "PM52",
        "name": "PM1 Gloss 8-Color Study",
        "seed": None,
        "prompt": "PM1 glossy-satin 8-color study: gold, bronze, garnet, copper-rose, ochre, amethyst, emerald, petrol.",
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
    img.thumbnail((1000, 1000), Image.Resampling.LANCZOS)
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
    draw.text((106, 20), name, fill=(197, 160, 89), font=font_small)
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)


def generate(only: set[str]):
    log = json.loads(LOG.read_text()) if LOG.exists() else {}
    for job in JOBS:
        label = job["label"]
        if only and label not in only:
            continue
        raw_path = RAW / f"{label}.png"
        labeled_path = ART / f"{label}.png"
        if raw_path.exists() and not only:
            print(f"[{label}] exists, skip")
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
                    print("!!! Replicate payment/credit blockiert - Abbruch")
                    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False))
                    sys.exit(2)
                print(f"[{label}] Fehler {attempt + 1}: {msg[:220]}")
                time.sleep(4)
        else:
            print(f"[{label}] FEHLGESCHLAGEN")
    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False))


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def spec_svg(vivid: bool) -> str:
    colors = {
        "gold": "#f0ce7a" if vivid else "#c5a059",
        "rose": "#e24e7b" if vivid else "#8e2a43",
        "teal": "#2cd4a8" if vivid else "#1a5e4e",
        "amethyst": "#a06be0" if vivid else "#4a2e65",
        "platinum": "#e8edf4" if vivid else "#cfd8e3",
        "body": "#101016",
        "basin": "#050509",
        "line": "#34333a",
    }
    glow = "filter='url(#softGlow)'" if vivid else ""
    labels = [
        ("A", colors["gold"]), ("K", colors["gold"]), ("Q", colors["gold"]),
        ("MAR", colors["rose"]), ("J", colors["gold"]), ("10", colors["gold"]),
        ("SEQ", colors["teal"]), ("POCH", colors["amethyst"]),
    ]
    anchors = [
        (200, 48), (308, 92), (352, 200), (308, 308),
        (200, 352), (92, 308), (48, 200), (92, 92),
    ]
    parts = []
    for (label, color), (x, y) in zip(labels, anchors):
        parts.append(f"""
          <g>
            <circle cx="{x}" cy="{y}" r="37" fill="{colors['basin']}" stroke="{colors['line']}" stroke-width="7"/>
            <circle cx="{x}" cy="{y}" r="31" fill="none" stroke="{color}" stroke-width="{5 if vivid else 3}" opacity="{0.96 if vivid else 0.76}" {glow}/>
            <text x="{x}" y="{y + 5}" text-anchor="middle" font-size="{13 if len(label) > 2 else 18}" font-weight="700" fill="{color}">{label}</text>
          </g>
        """)
    return f"""
    <svg viewBox="0 0 400 400" role="img" aria-label="Poch-Ring {'Vivid' if vivid else 'Premium'}">
      <defs>
        <radialGradient id="bodyGrad" cx="46%" cy="38%" r="70%">
          <stop offset="0%" stop-color="#1a1820"/>
          <stop offset="78%" stop-color="{colors['body']}"/>
          <stop offset="100%" stop-color="#07070a"/>
        </radialGradient>
        <filter id="softGlow" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="3" result="blur"/>
          <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>
      <rect width="400" height="400" rx="24" fill="#08070b"/>
      <circle cx="200" cy="200" r="184" fill="url(#bodyGrad)" stroke="#2c2a31" stroke-width="3"/>
      <circle cx="200" cy="200" r="128" fill="none" stroke="#2e2b33" stroke-width="2"/>
      {''.join(parts)}
      <g>
        <circle cx="200" cy="200" r="58" fill="{colors['basin']}" stroke="#3b3940" stroke-width="8"/>
        <circle cx="200" cy="200" r="49" fill="none" stroke="{colors['platinum']}" stroke-width="{4 if vivid else 2.5}" opacity="{0.88 if vivid else 0.62}" {glow}/>
        <text x="200" y="192" text-anchor="middle" font-size="10" font-weight="700" fill="{colors['platinum']}" opacity=".72">MITTE</text>
        <text x="200" y="220" text-anchor="middle" font-size="34" font-weight="800" fill="{colors['platinum']}">4</text>
      </g>
    </svg>
    """


def m9_svg() -> str:
    pools = [
        ("K", "#c5a059", "+8", 3),
        ("Q", "#c5a059", "+8", 2),
        ("MAR", "#8e2a43", "+24", 5),
        ("POCH", "#4a2e65", "+8", 4),
        ("SEQ", "#1a5e4e", "+24", 5),
        ("10", "#c5a059", "+8", 3),
        ("J", "#c5a059", "+8", 2),
        ("A", "#c5a059", "+8", 4),
    ]
    anchors = []
    for idx in range(8):
        angle = -math.pi / 2 + idx * math.tau / 8
        anchors.append((450 + math.cos(angle) * 305, 450 + math.sin(angle) * 305))

    wells = []
    for idx, ((label, color, value, coins), (x, y)) in enumerate(zip(pools, anchors)):
        coin_markup = []
        for c in range(coins):
            ox = [-21, 10, -4, 24, -16][c % 5]
            oy = [18, 10, -3, -13, -17][c % 5] - c * 2
            rot = [-19, 12, -5, 21, 4][c % 5]
            coin_markup.append(f"""
              <ellipse cx="{x + ox:.1f}" cy="{y + oy:.1f}" rx="28" ry="14"
                transform="rotate({rot} {x + ox:.1f} {y + oy:.1f})"
                fill="url(#coinGrad)" stroke="#f0ce7a" stroke-width="2.2"/>
              <ellipse cx="{x + ox - 2:.1f}" cy="{y + oy - 3:.1f}" rx="17" ry="6"
                transform="rotate({rot} {x + ox:.1f} {y + oy:.1f})"
                fill="none" stroke="#ffe29b" stroke-opacity=".35" stroke-width="2"/>
            """)
        wells.append(f"""
          <g>
            <circle cx="{x:.1f}" cy="{y:.1f}" r="83" fill="#09090d" filter="url(#wellShadow)"/>
            <circle cx="{x:.1f}" cy="{y:.1f}" r="76" fill="url(#wellGrad)" stroke="#282731" stroke-width="9"/>
            <circle cx="{x:.1f}" cy="{y:.1f}" r="63" fill="none" stroke="{color}" stroke-width="8" stroke-opacity=".92"/>
            <circle cx="{x:.1f}" cy="{y:.1f}" r="53" fill="none" stroke="{color}" stroke-width="1.5" stroke-opacity=".45"/>
            <g>{''.join(coin_markup)}</g>
            <rect x="{x - 38:.1f}" y="{y - 32:.1f}" width="76" height="58" rx="16"
              fill="#050509" fill-opacity=".54" stroke="#ffffff" stroke-opacity=".06"/>
            <text x="{x:.1f}" y="{y - 8:.1f}" text-anchor="middle" class="poolLabel" fill="{color}">{label}</text>
            <text x="{x:.1f}" y="{y + 22:.1f}" text-anchor="middle" class="poolValue" fill="{color}">{value}</text>
          </g>
        """)

    return f"""
    <svg viewBox="0 0 900 900" role="img" aria-label="M9 spielbarer Poch-Ring mit Pigment-Rims und Muenzen">
      <defs>
        <radialGradient id="m9Bg" cx="50%" cy="28%" r="76%">
          <stop offset="0%" stop-color="#17131d"/>
          <stop offset="68%" stop-color="#08070b"/>
          <stop offset="100%" stop-color="#050409"/>
        </radialGradient>
        <radialGradient id="bodyGradM9" cx="42%" cy="32%" r="72%">
          <stop offset="0%" stop-color="#25242b"/>
          <stop offset="62%" stop-color="#111117"/>
          <stop offset="100%" stop-color="#07070a"/>
        </radialGradient>
        <radialGradient id="wellGrad" cx="42%" cy="28%" r="78%">
          <stop offset="0%" stop-color="#202027"/>
          <stop offset="56%" stop-color="#07070a"/>
          <stop offset="100%" stop-color="#000000"/>
        </radialGradient>
        <linearGradient id="coinGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#f4d78b"/>
          <stop offset="48%" stop-color="#b98932"/>
          <stop offset="100%" stop-color="#5a3911"/>
        </linearGradient>
        <filter id="drop" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="22" stdDeviation="22" flood-color="#000000" flood-opacity=".55"/>
        </filter>
        <filter id="wellShadow" x="-25%" y="-25%" width="150%" height="150%">
          <feDropShadow dx="0" dy="8" stdDeviation="7" flood-color="#000000" flood-opacity=".65"/>
        </filter>
        <style>
          .poolLabel {{ font: 800 24px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; paint-order: stroke; stroke: #050509; stroke-width: 5px; }}
          .poolValue {{ font: 800 20px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; paint-order: stroke; stroke: #050509; stroke-width: 5px; }}
          .centerSmall {{ font: 800 18px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; letter-spacing: 2px; }}
          .centerValue {{ font: 900 58px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; }}
        </style>
      </defs>
      <rect width="900" height="900" fill="url(#m9Bg)"/>
      <circle cx="450" cy="450" r="410" fill="url(#bodyGradM9)" filter="url(#drop)"/>
      <circle cx="450" cy="450" r="410" fill="none" stroke="#302e36" stroke-width="4"/>
      <circle cx="450" cy="450" r="392" fill="none" stroke="#08080b" stroke-width="5"/>
      <circle cx="450" cy="450" r="245" fill="none" stroke="#2b2932" stroke-width="3"/>
      {''.join(wells)}
      <g>
        <circle cx="450" cy="450" r="153" fill="#09090d" filter="url(#wellShadow)"/>
        <circle cx="450" cy="450" r="139" fill="url(#wellGrad)" stroke="#34323b" stroke-width="12"/>
        <circle cx="450" cy="450" r="122" fill="none" stroke="#d8dee8" stroke-width="6" stroke-opacity=".86"/>
        <circle cx="450" cy="450" r="108" fill="none" stroke="#ffffff" stroke-width="1.5" stroke-opacity=".28"/>
        <g>
          <ellipse cx="417" cy="462" rx="32" ry="16" transform="rotate(-18 417 462)" fill="url(#coinGrad)" stroke="#f0ce7a" stroke-width="2.4"/>
          <ellipse cx="455" cy="444" rx="32" ry="16" transform="rotate(12 455 444)" fill="url(#coinGrad)" stroke="#f0ce7a" stroke-width="2.4"/>
          <ellipse cx="482" cy="469" rx="32" ry="16" transform="rotate(5 482 469)" fill="url(#coinGrad)" stroke="#f0ce7a" stroke-width="2.4"/>
          <ellipse cx="448" cy="486" rx="32" ry="16" transform="rotate(-9 448 486)" fill="url(#coinGrad)" stroke="#f0ce7a" stroke-width="2.4"/>
        </g>
        <rect x="388" y="398" width="124" height="104" rx="22" fill="#050509" fill-opacity=".56" stroke="#ffffff" stroke-opacity=".07"/>
        <text x="450" y="434" text-anchor="middle" class="centerSmall" fill="#d8dee8">MITTE</text>
        <text x="450" y="486" text-anchor="middle" class="centerValue" fill="#d8dee8">38</text>
      </g>
    </svg>
    """


def write_html():
    locked_label = "PM49"
    archive_labels = {"PM1", "PM47", "PM48", "PM50", "PM51", "PM52"}
    locked_cards = []
    archive_cards = []
    notes = {
        "PM1": "Ziel: F-Lesbarkeit mit E/A-Ruhe. Achten auf: keine Schmuckpunkte, kein Gold-Vollring.",
        "PM2": "Test fuer matte Cabochon-Inlays. Achten auf: nicht zu Juwel/Bonbon.",
        "PM3": "Plaque-/Kachelmulden fuer kompakte Phase 2. Achten auf: noch rund genug fuer Poch-Signet?",
        "PM4": "Schweres ruhiges Siegel. Achten auf: markant genug ohne Ornament?",
        "PM5": "Final-Hybrid: PM4-Keramikkoerper + PM1-Farb-Rims. Hauptkandidat, wenn Glow wirklich raus bleibt.",
        "PM6": "Final-Hybrid aus PM1-Mulden + PM4-Masse. Hauptkandidat, wenn die Mulden funktionaler wirken sollen.",
        "PM7": "Finaler Zielretake: PM5-Farbe/Material + PM6-Koerper, exakt 8+Mitte, matte Inlays, kein Glow.",
        "PM8": "PM7-Fix: PM7-Koerper, PM5-Palette, exakt 8+Mitte, keine Ornamente, kein Kupfer/Bronze.",
        "PM9": "Finaler Pigment-Rim-Retake: Farbe am oberen Muldenrand, dunkle leere Böden, 8+Mitte.",
        "PM10": "PM1-Retake: alle 8 Mulden mit konsistenten matten Pigment-Bezels.",
        "PM11": "PM1-Retake: dezente Mineral-Ringe um jede Mulde, Center mit Platin-Bezel.",
        "PM12": "PM1-Retake: low-contrast Satin-Bezels, PM1-Materialruhe.",
        "PM13": "PM1-Material neu gesetzt: exakt 8 Außenmulden + echte Mittelmulde; dezente Ringe sitzen auf den Muldenlippen.",
        "PM14": "PM7-basierte Variante: symmetrische 8+Mitte, gedämpfter Metallglanz, Premium-Farbtöne.",
        "PM15": "PM7-basierte Variante: gebürstete Metallmulden, ruhiger Graphitkörper.",
        "PM16": "PM7-basierte Variante: herstellbares Spielbrett mit anodisierten Metallcups.",
        "PM17": "PM1-nah: echte Mittelmulde, sehr zurückhaltende Pigmentringe, PM1-Materialruhe.",
        "PM18": "PM1-nah: etwas tiefere Mulden und klarere Farbringe, weiterhin matt und gedämpft.",
        "PM19": "PM1-nah: ruhigste/edelste Variante, kleinere Mulden und minimale Farbkanten.",
        "PM20": "PM7-Muldenstudie: symmetrische Metallcups, gedämpfte unterschiedliche Farbtöne.",
        "PM21": "PM7-Muldenstudie: etwas stärkerer satinierter Metallglanz, aber ohne Glow.",
        "PM22": "PM7-Muldenstudie: dunkelste Metallfassung, maximal gedämpft und herstellbar.",
        "PM23": "Original-PM1 bleibt erhalten: nur echte Mittelmulde plus dezente Farbringe auf den vorhandenen Muldenlippen.",
        "PM24": "Original-PM1 bleibt erhalten: etwas deutlichere Ringe und tiefere Mittelmulde.",
        "PM25": "Original-PM1 bleibt erhalten: leiseste Variante, minimale Pigmentlippen und kleinere Mittelmulde.",
        "PM26": "Original-PM1 bleibt erhalten: Pigment auf dunkle Muldenlippen geclippt, keine Kreise auf der Oberfläche.",
        "PM27": "Original-PM1 bleibt erhalten: tiefere Mittelmulde, zurückhaltend geclippte Pigmentlippen.",
        "PM28": "Original-PM1 bleibt erhalten: leiseste geclippte Lip-Variante mit kleinerer Mitte.",
        "PM29": "Original-PM1 fast unangetastet: nur die fehlende Mittelmulde wurde ergänzt.",
        "PM30": "Original-PM1 bleibt erhalten: Mittelmulde plus kurze PM1-artige Pigmentkanten an allen Mulden.",
        "PM31": "Original-PM1 bleibt erhalten: leisere Pigmentkanten, keine vollständigen Zusatzkreise.",
        "PM32": "Original-PM1 bleibt erhalten: vollständige dünne Pigment-Inlays auf allen inneren Muldenlippen, nicht abgeplatzt.",
        "PM33": "Original-PM1 bleibt erhalten: leisere vollständige Pigment-Inlays, saubere durchgehende Kanten.",
        "PM34": "Original-PM1 bleibt erhalten: subtilste vollständige Inlays, kleinere Mittelmulde.",
        "PM35": "Original-PM1 bleibt erhalten: exakt zentrierte symmetrische Mittelmulde, klare Inlays.",
        "PM36": "Original-PM1 bleibt erhalten: exakt zentrierte Mittelmulde, ruhigere Inlays.",
        "PM37": "Original-PM1 bleibt erhalten: exakt zentrierte kleinere Mittelmulde, subtilste Inlays.",
        "PM38": "PM1 als Materialreferenz, Geometrie neu gebaut: echtes 8+Mitte-Spielfeld mit dezenten Inlays.",
        "PM39": "PM1 als Materialreferenz, funktionalere Münzmulden: größer, weiter außen, ruhige Inlays.",
        "PM40": "PM1 als Materialreferenz, konservativste Retake-Richtung: PM1-Look mit korrigiertem Layout.",
        "PM41": "Geometrie-Studie: echte Mulden mit flachem Münzboden, PM1-nahe Graphit-/Goldkante.",
        "PM42": "Geometrie-Studie: Außenmulden größer und weiter außen, Mitte kleiner und zentriert.",
        "PM43": "Geometrie-Studie: ruhigste Farbkanten, maximal physisches Spielfeld statt Overlay.",
        "PM44": "Geometrie-Studie V2: dunkler Graphit statt grauer Platte, echte 8+Mitte-Mulden, sichtbare Inlays.",
        "PM45": "Geometrie-Studie V2: großzügigere Münzmulden, kleinere Mitte, PM1-nahe dunkle Materialruhe.",
        "PM46": "Geometrie-Studie V2: subtilste Inlays, weiterhin vollständige Farbkanten und echte Mulden.",
        "PM47": "PM1 bleibt Ästhetikanker: Mittelmulde ergänzt, dezente Ringe auf den Mulden, Goldpunkte sauber ausgerichtet.",
        "PM48": "PM47-Finalisierung: exakt 8 Außenmulden + Mitte, systematische Palette, reduzierte Punkte/Ornamente/Kante.",
        "PM49": "Farbvergleich: acht unterschiedliche, gedämpfte Cockpit-Farben pro Mulde. Balancierter, aber weniger regelgetreu.",
        "PM50": "Zurück zu PM1: historisch gruppierte Farbverteilung, große Mittelmulde, Goldpunkte vor jeder Mulde.",
        "PM51": "Politur von PM50: PM1-Glanz/Textur stärker, regelgetreue 5-Gold-Palette plus drei Sonderfarben.",
        "PM52": "8-Farben-Studie mit PM1-Glanz: besser unterscheidbar, aber stärker System/Farbcode als historisches Brett.",
    }
    for job in JOBS:
        path = ART / f"{job['label']}.png"
        if not path.exists():
            continue
        if job["label"] != locked_label and job["label"] not in archive_labels:
            continue
        card_class = "card locked" if job["label"] == locked_label else "card archive-card"
        card = f"""
        <section class="{card_class}">
          <img src="data:image/png;base64,{b64(path)}" alt="{job['label']} {job['name']}">
          <h2>{job['label']} · {job['name']}</h2>
          <p>{notes[job['label']]}</p>
        </section>
        """
        if job["label"] == locked_label:
            locked_cards.append(card)
        else:
            archive_cards.append(card)

    html = f"""<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Precision Monolith · Poch-Ring Sichtung</title>
  <style>
    :root {{ color-scheme: dark; --bg:#08070b; --panel:#131018; --text:#e2e8f0; --muted:#9aa3af; --gold:#c5a059; }}
    body {{ margin:0; background:var(--bg); color:var(--text); font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif; }}
    header {{ max-width:1220px; margin:0 auto; padding:28px 22px 12px; }}
    h1 {{ margin:0 0 8px; font-size:29px; letter-spacing:.01em; }}
    .lead {{ margin:0; color:var(--muted); max-width:980px; line-height:1.45; }}
    .block {{ max-width:1220px; margin:0 auto; padding:14px 22px; }}
    .grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:18px; }}
    .card {{ background:linear-gradient(180deg,#17131d,#0f0d13); border:1px solid rgba(197,160,89,.22); border-radius:10px; padding:12px; }}
    .locked-grid {{ display:grid; grid-template-columns:minmax(280px,680px); gap:18px; }}
    .locked {{ border-color:rgba(197,160,89,.58); box-shadow:0 0 0 1px rgba(197,160,89,.12), 0 22px 70px rgba(0,0,0,.32); }}
    .archive {{ opacity:.72; }}
    .archive summary {{ cursor:pointer; color:var(--gold); font-weight:700; margin-bottom:14px; }}
    .archive-card {{ filter:saturate(.75); }}
    .badge {{ display:inline-block; margin:0 0 10px; padding:4px 8px; border:1px solid rgba(197,160,89,.45); border-radius:999px; color:var(--gold); font-size:12px; font-weight:700; letter-spacing:.03em; text-transform:uppercase; }}
    img {{ display:block; width:100%; border-radius:6px; background:#09070c; }}
    h2 {{ font-size:16px; margin:12px 2px 4px; color:var(--gold); }}
    h3 {{ margin:8px 0 12px; color:var(--gold); }}
    p, li {{ color:var(--muted); line-height:1.42; font-size:13px; }}
    ul {{ margin-top:0; }}
    .spec {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(320px,1fr)); gap:18px; }}
    .svgcard {{ background:linear-gradient(180deg,#17131d,#0f0d13); border:1px solid rgba(197,160,89,.22); border-radius:10px; padding:14px; }}
    svg {{ width:100%; height:auto; display:block; }}
    code {{ color:var(--gold); }}
  </style>
</head>
<body>
  <header>
    <h1>Precision Monolith · Poch-Ring Sichtung</h1>
    <p class="lead">PM49 ist als aktuelle Ring-Richtung eingeloggt: PM1-nahe Material-/Lichtwirkung, acht unterschiedliche gedämpfte Cockpit-Farben und echte 8+Mitte-Poch-Geometrie. Die älteren Varianten bleiben als Archiv referenzierbar, blockieren aber nicht mehr die Hauptentscheidung.</p>
  </header>

  <section class="block">
    <h3>Locked Direction</h3>
    <div class="locked-grid">{''.join(locked_cards)}</div>
  </section>

  <section class="block">
    <h3>PM49 Freeze-Notiz</h3>
    <ul>
      <li>Form: echtes Spielfeld, exakt 8 Außenmulden + zentrale Mittelmulde.</li>
      <li>Farbe: acht verschiedene, gedämpfte Cockpit-Töne pro Mulde; Farbe bleibt Label, nicht Dekoration.</li>
      <li>Material: PM1-Referenz bleibt maßgeblich, also dunkler Graphit, edle Lichtkante, keine Neon- oder Casino-Sprache.</li>
      <li>Goldpunkte: nur als präzise, gleichmäßige Orientierungspunkte vor den Mulden; keine zufälligen Schmuckpunkte.</li>
    </ul>
  </section>

  <section class="block">
    <h3>Design-Regel</h3>
    <ul>
      <li>Uebernehmen: dunkler Monolith, tiefe Mulden, matte Pigment-Rims, feine Graphit-/Platin-Bevels.</li>
      <li>Vermeiden: Gold-Vollring, Roulette-Segmente, Dauer-Glow, LEDs, glossy Edelsteine, Heraldik, Uhrwerk.</li>
      <li>Premium und Vivid nutzen dieselbe Geometrie. Vivid erhoeht Saettigung/Kantenlicht, nicht Casino-Formen.</li>
    </ul>
  </section>

  <section class="block archive">
    <details>
      <summary>Archivierte Varianten anzeigen</summary>
      <p>Speicherarm archiviert: keine Duplikate, nur Verweise auf die bestehenden Bilddateien. PM1 bleibt Stilreferenz; PM47/PM48/PM50/PM51/PM52 bleiben als Vergleichsfälle erhalten.</p>
      <div class="grid">{''.join(archive_cards)}</div>
    </details>
  </section>

  <section class="block">
    <h3>Code-/Vektor-Spec: gleiche Mulde, zwei Themes</h3>
    <div class="spec">
      <div class="svgcard"><h2>Premium matt</h2>{spec_svg(False)}</div>
      <div class="svgcard"><h2>Vivid</h2>{spec_svg(True)}</div>
    </div>
  </section>

  <section class="block">
    <p><span class="badge">PM49 locked</span><br>Rohbilder: <code>Assets_Raw/pochring/precision-monolith/</code> · gelabelte Sichtung: <code>artifacts/precision-monolith/</code> · Archiv-Manifest: <code>artifacts/precision-monolith/archive-manifest.md</code> · Log: <code>{LOG.relative_to(ROOT)}</code></p>
  </section>
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
