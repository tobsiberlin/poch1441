#!/usr/bin/env python3
"""Finale, konsistente Spielkarten-Vorderseiten (franzoesisches Blatt, 8.7.2026).

EINE deterministische Vorlage für alle 32 Karten - keine KI-Generierung:
- Karte: weiß, runde Ecken (Radius = 8/52 der Breite, deckungsgleich mit CardFace-Clip)
- Eck-Indizes: groß + fett (Helvetica Neue Bold), Pip darunter, oben-links + unten-rechts (180°)
- Hofkarten (J/Q/K): klassische Figuren aus htdebeer/SVG-cards (LGPL), extrahiert OHNE
  deren Basis/Eck-Indizes; Figurenrahmen nahezu vollflächig, Index mit weißem Knockout
- Asse: ein großes zentrales Pip
- Zahlkarten (7-10): klassisches Pip-Raster, untere Hälfte 180° gedreht
- Franzoesisches Blatt mit internationalen Indizes: A/K/Q/J/10/9/8/7.
- Klassische, klare Spielkartenfarben wie im Mockup: Rot/Schwarz fuer Indizes
  und Pips, Hofkarten mit Royal-Blau, Rot und Gold. Nicht deutsch/altdeutsch,
  nicht KI-illustriert.

Output: Master-PNGs (624x888) nach Assets_Raw/cards/final/,
Imagesets (@2x/@3x) nach App/Assets.xcassets/Cards/.
"""
import json
import os
import re
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Assets_Raw", "svg-cards", "svg-cards.svg")
OUT_MASTER = os.path.join(ROOT, "Assets_Raw", "cards", "final")
CATALOG = os.path.join(ROOT, "App", "Assets.xcassets", "Cards")

# Kartengeometrie (Master), Seitenverhältnis 52:74 wie CardFace
W, H = 624, 888
SS = 2  # Supersampling
CORNER_R = round(8 / 52 * W)  # 96 - deckungsgleich mit clipShape in CardFace

# Index (Ecke)
IDX_FONT_SIZE = 188          # gross, aber mit sicherer Index-Zone
TEN_IDX_FONT_SIZE = 150      # zweistellig: getrennt kleiner, keine Pip-Kollision
IDX_X = 28                   # linker Rand des Buchstabens
IDX_TOP = 30                 # obere Kante des Buchstabens
IDX_PIP_H = 60               # selbst gezeichnet, nie aus fremdem Karten-Sheet
IDX_PIP_GAP = 12
TEN_SQUEEZE = 0.80           # "10" horizontal gestaucht, aber lesbar

# Zentren
ACE_PIP_H = 330              # gross und ruhig, wie Mockup-Handkarten
NUM_PIP_H = 92               # kleiner als Indexzone, kein Eck-Kontakt
NUM_COL_X = 84               # linke Pips bleiben klar rechts der Indexzone
NUM_ROW_Y = 238              # Zahlenbild kompakter, oben nie im Index
COURT_BOX_W = 530            # Figurenrahmen 85% Breite (nahezu vollflächig, wie Quelle)
KNOCKOUT_PAD = 16
KNOCKOUT_R = 24

PAPER = (255, 255, 255, 255) # Mockup: klares, modernes Kartenweiss
RED = (204, 35, 52, 255)     # klares franzoesisches Kartenrot
BLACK = (0, 0, 0, 255)

# Quell-Palette (htdebeer, grell/flach) -> klassisches franzoesisches Blatt.
# #E61408 lebt NUR in den Figuren-Defs (Gewänder), #e6180a/#E6180A nur in
# Pips/Akzenten - der Split ist verifiziert (Strip-Skript 8.7.), daher getrennt mappbar.
REPAINT = {
    "#E61408": "#A8293B",  # Gewaender-Rot -> ruhiger, aber klar
    "#e6180a": "#CC2334",  # Pip-/Akzent-Rot -> Mockup-lesbar
    "#E6180A": "#CC2334",
    "#F8C20F": "#B88D34",  # Gelb -> Antikgold, nicht Primärgelb
    "#1C1585": "#314C78",  # Blau -> staubiges Royal, weniger gesättigt
}


def repaint(svg):
    for old, new in REPAINT.items():
        svg = svg.replace(f"fill:{old}", f"fill:{new}")
    return svg

SUITS = {"heart": "hearts", "diamond": "diamonds", "spade": "spades", "club": "clubs"}
RANKS = {"1": "ace", "king": "king", "queen": "queen", "jack": "jack",
         "10": "ten", "9": "nine", "8": "eight", "7": "seven"}
COURT_RANKS = ("jack", "queen", "king")
VIEWBOX = (169.075, 244.640)  # htdebeer-Kartenmaß

# Klassische Pip-Raster: (Spalte -1/0/+1, Reihe als Anteil von NUM_ROW_Y)
PIP_LAYOUT = {
    "7": [(-1, -1), (1, -1), (0, -0.5), (-1, 0), (1, 0), (-1, 1), (1, 1)],
    "8": [(-1, -1), (1, -1), (0, -0.5), (-1, 0), (1, 0), (0, 0.5), (-1, 1), (1, 1)],
    "9": [(-1, -1), (1, -1), (-1, -1 / 3), (1, -1 / 3), (0, 0),
          (-1, 1 / 3), (1, 1 / 3), (-1, 1), (1, 1)],
    "10": [(-1, -1), (1, -1), (0, -2 / 3), (-1, -1 / 3), (1, -1 / 3),
           (-1, 1 / 3), (1, 1 / 3), (0, 2 / 3), (-1, 1), (1, 1)],
}


def balanced_group(svg, gid):
    """(start, end) der <g id=gid>-Gruppe mit balanciertem Tag-Matching."""
    anchor = svg.index(f'id="{gid}"')
    gstart = svg.rindex("<g", 0, anchor)
    depth, i = 0, gstart
    pat = re.compile(r"<g[ >]|</g>")
    while True:
        m = pat.search(svg, i)
        depth += 1 if m.group(0).startswith("<g") else -1
        i = m.end()
        if depth == 0:
            return gstart, i


def strip_court_group(body):
    """Basis, Eck-Pips (groß+klein) und Buchstaben-Glyphen aus Hofkarten-Gruppe entfernen."""
    body = re.sub(r'<use xlink:href="#base"[^/]*/>', "", body)
    body = re.sub(
        r'<g><use xlink:href="#(?:heart|diamond|spade|club)"[^/]*/><rect[^/]*/></g>', "", body)
    body = re.sub(r'<use xlink:href="#(?:jack|queen|king)"[^/]*/>', "", body)
    body = re.sub(r'<use xlink:href="#(?:heart|diamond|spade|club)"[^/]*/>', "", body)
    return body


def court_frame_local(svg, gid):
    """Figurenrahmen-Box (lokale Kartenkoordinaten) aus den 4 Rahmen-Pfaden."""
    gstart, _ = balanced_group(svg, gid)
    head = svg[gstart:gstart + 1400]
    tr = re.search(r"translate\(([-\d.]+),([-\d.]+)\)", head)
    tx, ty = float(tr.group(1)), float(tr.group(2))
    paths = re.findall(r'<path d="m ([-\d.]+),([-\d.]+) ([-\d.]+),([-\d.]+)"', head)[:4]
    xs, ys = [], []
    for x0, y0, dx, dy in paths:
        x0, y0, dx, dy = map(float, (x0, y0, dx, dy))
        xs += [x0, x0 + dx]
        ys += [y0, y0 + dy]
    return min(xs) + tx, min(ys) + ty, max(xs) + tx, max(ys) + ty


def render_courts(tmpdir):
    """12 Hoffiguren (inkl. Rahmen, ohne Indizes) als RGBA rendern und exakt croppen."""
    src = open(SRC).read()
    figures = {}
    for suit in SUITS:
        for rank in COURT_RANKS:
            gid = f"{suit}_{rank}"
            gstart, gend = balanced_group(src, gid)
            stripped = src[:gstart] + strip_court_group(src[gstart:gend]) + src[gend:]
            # Standalone-SVG: fester viewBox = Kartenfläche -> lineare Pixel-Zuordnung
            doc = re.sub(r"<svg[^>]*>",
                         f'<svg xmlns="http://www.w3.org/2000/svg" '
                         f'xmlns:xlink="http://www.w3.org/1999/xlink" '
                         f'viewBox="0 0 {VIEWBOX[0]} {VIEWBOX[1]}">', stripped, count=1)
            doc = doc.replace("</svg>", f'<use xlink:href="#{gid}"/></svg>')
            doc = repaint(doc)
            svg_path = os.path.join(tmpdir, f"{gid}.svg")
            png_path = os.path.join(tmpdir, f"{gid}.png")
            open(svg_path, "w").write(doc)
            subprocess.run(["rsvg-convert", "-w", "1600", "-o", png_path, svg_path],
                           check=True, capture_output=True)
            im = Image.open(png_path).convert("RGBA")
            sx, sy = im.width / VIEWBOX[0], im.height / VIEWBOX[1]
            fx0, fy0, fx1, fy1 = court_frame_local(src, gid)
            pad = 0.75  # halbe Strichstärke + Rundung: Rahmen vollständig mitnehmen
            box = (round((fx0 - pad) * sx), round((fy0 - pad) * sy),
                   round((fx1 + pad) * sx), round((fy1 + pad) * sy))
            figures[gid] = im.crop(box)
    return figures


def render_pips(tmpdir):
    """4 Farb-Pips rendern - aus der umgefärbten Quelle (tiefes Karmesin)."""
    recolored = os.path.join(tmpdir, "recolored.svg")
    open(recolored, "w").write(repaint(open(SRC).read()))
    pips = {}
    for suit in SUITS:
        png_path = os.path.join(tmpdir, f"pip_{suit}.png")
        subprocess.run(["rsvg-convert", f"--export-id={suit}", "-w", "900",
                        "-o", png_path, recolored], check=True, capture_output=True)
        im = Image.open(png_path).convert("RGBA")
        pips[suit] = im.crop(im.getbbox())
    return pips


def pip_depth(pip):
    """Dezenter vertikaler Tiefengradient (Licht von oben) - nach der Rotation
    anwenden, damit die Lichtrichtung auf allen Pips identisch bleibt."""
    a = np.asarray(pip, dtype=np.float32)
    grad = np.linspace(1.06, 0.93, a.shape[0], dtype=np.float32)[:, None, None]
    a[:, :, :3] = np.clip(a[:, :, :3] * grad, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def draw_suit_symbol(size, suit, color):
    """Mathematisch saubere Eckindex-Pips.

    Die grossen Kartenpips kommen aus der SVG-Quelle. Die kleinen Eckpips zeichnen
    wir bewusst selbst, damit dort nie fremde Sheet-Artefakte, falsche Farben oder
    deformierte gedrehte Symbole landen.
    """
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = color
    s = size
    cx = s / 2
    if suit == "heart":
        d.ellipse([0.12*s, 0.08*s, 0.52*s, 0.48*s], fill=c)
        d.ellipse([0.48*s, 0.08*s, 0.88*s, 0.48*s], fill=c)
        d.polygon([(0.10*s, 0.32*s), (0.90*s, 0.32*s), (cx, 0.95*s)], fill=c)
    elif suit == "diamond":
        d.polygon([(cx, 0.04*s), (0.92*s, cx), (cx, 0.96*s), (0.08*s, cx)], fill=c)
    elif suit == "spade":
        d.ellipse([0.12*s, 0.32*s, 0.52*s, 0.72*s], fill=c)
        d.ellipse([0.48*s, 0.32*s, 0.88*s, 0.72*s], fill=c)
        d.polygon([(0.10*s, 0.50*s), (0.90*s, 0.50*s), (cx, 0.02*s)], fill=c)
        d.polygon([(0.39*s, 0.66*s), (0.61*s, 0.66*s), (0.72*s, 0.94*s), (0.28*s, 0.94*s)], fill=c)
    else:  # club
        d.ellipse([0.30*s, 0.02*s, 0.70*s, 0.42*s], fill=c)
        d.ellipse([0.08*s, 0.34*s, 0.48*s, 0.74*s], fill=c)
        d.ellipse([0.52*s, 0.34*s, 0.92*s, 0.74*s], fill=c)
        d.polygon([(0.39*s, 0.58*s), (0.61*s, 0.58*s), (0.74*s, 0.95*s), (0.26*s, 0.95*s)], fill=c)
    return im.filter(ImageFilter.GaussianBlur(0.15))


def scaled_pip(pips, suit, target_h, rotated=False):
    pip = pips[suit]
    w = round(pip.width * target_h / pip.height)
    pip = pip.resize((w, target_h), Image.LANCZOS)
    if rotated:
        pip = pip.rotate(180)
    return pip_depth(pip)


_TEXTURE = None


def paper_texture():
    """Sehr dezenter Papier-Feel: keine Cremefaerbung, kein Pergament.
    Die Karte bleibt im UI klar weiss; nur minimale Schattierung verhindert
    flache Clip-Art-Flaechen."""
    global _TEXTURE
    if _TEXTURE is None:
        rng = np.random.default_rng(1441)
        small = rng.normal(0.0, 1.0, (H // 2, W // 2)).astype(np.float32)
        grain = np.asarray(Image.fromarray(small, mode="F").resize((W, H), Image.BILINEAR))
        y = np.arange(H, dtype=np.float32)[:, None]
        x = np.arange(W, dtype=np.float32)[None, :]
        linen = 0.22 * (np.sin(y * 2 * np.pi / 4.3) + np.sin(x * 2 * np.pi / 5.9))
        sheen = 1.012 - 0.022 * ((x / W) * 0.45 + (y / H) * 0.55)
        tex = sheen + (grain * 1.15 + linen) / 255.0
        warm = np.array([1.0, 1.0, 1.0], dtype=np.float32)
        _TEXTURE = tex[:, :, None] * warm[None, None, :]
    return _TEXTURE


def make_index_tile(font, ten_font, rank_key, suit, pips):
    """Index-Block (Buchstabe + Pip darunter) als RGBA-Tile, Ursprung = Buchstaben-Top-Left."""
    label = {"1": "A", "king": "K", "queen": "Q", "jack": "J"}.get(rank_key, rank_key)
    color = RED if suit in ("heart", "diamond") else BLACK
    active_font = ten_font if label == "10" else font
    bbox = active_font.getbbox(label)
    lw, lh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    letter = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    ImageDraw.Draw(letter).text((-bbox[0], -bbox[1]), label, font=active_font, fill=color)
    if label == "10":
        letter = letter.resize((round(lw * TEN_SQUEEZE), lh), Image.LANCZOS)
    pip = draw_suit_symbol(IDX_PIP_H * SS, suit, color)
    tile_w = max(letter.width, pip.width)
    tile_h = letter.height + IDX_PIP_GAP * SS + pip.height
    tile = Image.new("RGBA", (tile_w, tile_h), (0, 0, 0, 0))
    tile.alpha_composite(letter, ((tile_w - letter.width) // 2, 0))
    tile.alpha_composite(pip, ((tile_w - pip.width) // 2, letter.height + IDX_PIP_GAP * SS))
    return tile


def compose_card(suit, rank_key, figures, pips, font, ten_font):
    cw, ch = W * SS, H * SS
    img = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([0, 0, cw - 1, ch - 1], radius=CORNER_R * SS,
                           fill=PAPER)

    tile = make_index_tile(font, ten_font, rank_key, suit, pips)
    tl = (IDX_X * SS, IDX_TOP * SS)
    br = (cw - tl[0] - tile.width, ch - tl[1] - tile.height)

    if rank_key in COURT_RANKS:
        fig = figures[f"{suit}_{rank_key}"]
        box_w = COURT_BOX_W * SS
        box_h = round(box_w * fig.height / fig.width)
        fig = fig.resize((box_w, box_h), Image.LANCZOS)
        # Mockup-Deck: Hofkarten bleiben klassisch, aber weniger Primärfarben/
        # Strichrauschen als die rohe Quelle. Das Bild wird nur beruhigt, nicht
        # semantisch verändert.
        rgb = fig.convert("RGB")
        alpha = fig.getchannel("A")
        rgb = ImageOps.posterize(rgb, 4)
        fig = rgb.convert("RGBA")
        fig.putalpha(alpha)
        fig = ImageEnhance.Color(fig).enhance(0.72)
        fig = ImageEnhance.Contrast(fig).enhance(0.98)
        fig = ImageEnhance.Sharpness(fig).enhance(0.74)
        fx, fy = (cw - box_w) // 2, (ch - box_h) // 2
        img.alpha_composite(fig, (fx, fy))
        # Weißes Knockout hinter beiden Indizes (klassisch, wie Quelle - nur größer)
        for x, y in (tl, br):
            draw.rounded_rectangle(
                [x - KNOCKOUT_PAD * SS, y - KNOCKOUT_PAD * SS,
                 x + tile.width + KNOCKOUT_PAD * SS, y + tile.height + KNOCKOUT_PAD * SS],
                radius=KNOCKOUT_R * SS, fill=PAPER)
    elif rank_key == "1":
        pip = scaled_pip(pips, suit, ACE_PIP_H * SS)
        img.alpha_composite(pip, ((cw - pip.width) // 2, (ch - pip.height) // 2))
    else:
        for col, row in PIP_LAYOUT[rank_key]:
            pip = scaled_pip(pips, suit, NUM_PIP_H * SS, rotated=row > 0)
            px = cw // 2 + col * NUM_COL_X * SS - pip.width // 2
            py = ch // 2 + round(row * NUM_ROW_Y) * SS - pip.height // 2
            img.alpha_composite(pip, (px, py))

    img.alpha_composite(tile, tl)
    img.alpha_composite(tile.rotate(180), br)
    out = img.resize((W, H), Image.LANCZOS)
    a = np.asarray(out, dtype=np.float32)
    a[:, :, :3] = np.clip(a[:, :, :3] * paper_texture(), 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def write_imageset(name, master):
    d = os.path.join(CATALOG, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    for old in os.listdir(d):
        if old.endswith(".png"):
            os.remove(os.path.join(d, old))
    master.resize((312, 444), Image.LANCZOS).save(os.path.join(d, f"{name}@2x.png"))
    master.resize((468, 666), Image.LANCZOS).save(os.path.join(d, f"{name}@3x.png"))
    json.dump({
        "images": [
            {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": f"{name}@3x.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }, open(os.path.join(d, "Contents.json"), "w"), indent=2)


def main():
    os.makedirs(OUT_MASTER, exist_ok=True)
    font = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc",
                              IDX_FONT_SIZE * SS, index=1)  # Helvetica Neue Bold
    ten_font = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc",
                                  TEN_IDX_FONT_SIZE * SS, index=1)
    with tempfile.TemporaryDirectory() as tmpdir:
        figures = render_courts(tmpdir)
        pips = render_pips(tmpdir)
        for suit, suit_name in SUITS.items():
            for rank_key, rank_name in RANKS.items():
                name = f"card_{suit_name}_{rank_name}"
                master = compose_card(suit, rank_key, figures, pips, font, ten_font)
                master.save(os.path.join(OUT_MASTER, f"{name}.png"))
                write_imageset(name, master)
    print(f"32 Karten -> {OUT_MASTER} + {CATALOG}")


if __name__ == "__main__":
    main()
