#!/usr/bin/env python3
"""Sichtung 1 - Compositing: Roh-Atome -> präsentierbare Kandidaten.

Kartenrücken: Artwork + Tinten-Rahmen + Hairline + gespiegeltes P·1441-Monogramm
(Vektor-Overlay, Didot - nie generierte Schrift). Porträts: Tile + Label.
Jeder Kandidat bekommt sein Label ins Bild (Cockpit-Regel §10).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/Users/tobsi/poch1441")
RAW = ROOT / "Assets_Raw" / "sichtung1" / "raw"
OUT = ROOT / "artifacts" / "sichtung1"
OUT.mkdir(parents=True, exist_ok=True)

DIDOT = "/System/Library/Fonts/Supplemental/Didot.ttc"
INK = (18, 15, 20)          # warmes Tinten-Schwarz (Kartenrand)
TILE_TOP = (33, 30, 36)     # Präsentations-Hintergrund oben
TILE_BOT = (23, 21, 26)     # unten
PLATIN = (201, 194, 180)


def font(size):
    return ImageFont.truetype(DIDOT, size)


def tile_bg(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / h
        c = tuple(int(a + (b - a) * t) for a, b in zip(TILE_TOP, TILE_BOT))
        for x in range(w):
            px[x, y] = c
    return img


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return m


def label_badge(draw, label):
    draw.ellipse([46, 46, 138, 138], outline=PLATIN, width=3)
    f = font(56 if len(label) > 1 else 64)
    bb = draw.textbbox((0, 0), label, font=f)
    draw.text((92 - (bb[2] - bb[0]) / 2 - bb[0], 92 - (bb[3] - bb[1]) / 2 - bb[1]),
              label, font=f, fill=PLATIN)


def g_artwork():
    """G wird NICHT generiert, sondern deterministisch gezeichnet (Hebelwechsel 7.7.:
    FLUX lieferte 2x kein sichtbares Emblem). Neun-Segment-Ring, ein Amethyst-Segment."""
    S = 4  # Supersampling
    w, h = 900 * S, 1300 * S
    img = Image.new("RGB", (w, h), (20, 17, 23))
    d = ImageDraw.Draw(img)
    cx, cy, r = w // 2, h // 2, 150 * S
    box = [cx - r, cy - r, cx + r, cy + r]
    gap, seg = 5, (360 - 9 * 5) / 9
    for i in range(9):
        a0 = -90 + i * (seg + gap)
        col = (122, 86, 168) if i == 2 else (170, 164, 152)
        d.arc(box, a0, a0 + seg, fill=col, width=7 * S)
    d.ellipse([cx - 4 * S, cy - 4 * S, cx + 4 * S, cy + 4 * S], fill=(170, 164, 152))
    return img.resize((900, 1300), Image.LANCZOS)


# DesignTokens.swift-Farben (Farbe = Label, konzept §5) - matte Juwelen.
JEWEL_GOLD = (197, 160, 89)      # C5A059
JEWEL_ROSE = (142, 42, 67)       # 8E2A43
JEWEL_SMARAGD = (26, 94, 78)     # 1A5E4E
JEWEL_AMETHYST = (74, 46, 101)   # 4A2E65
# Brett-Reihenfolge ab 12 Uhr im Uhrzeigersinn (PochRing.anchors): K Q MAR J 10 SEQ POCH A.
RING_ORDER = [JEWEL_GOLD, JEWEL_GOLD, JEWEL_ROSE, JEWEL_GOLD,
              JEWEL_GOLD, JEWEL_SMARAGD, JEWEL_AMETHYST, JEWEL_GOLD]


def ring_signet(style, scale=1.0):
    """Der 9-Mulden-Ring als deterministischer Vektor (Synthese 7.7.: A-Konzept x
    G-Produktion x C-Material). 8 Juwel-Segmente + Platin-Mitte (9. Mulde), kein Metall,
    kein Dom - Juwelen sind die einzige Farbe."""
    S = 4
    w, h = 900 * S, 1300 * S
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    gap = 5
    seg = 45 - gap
    if style == "sector":
        r_out, r_in = int(212 * S * scale), int(160 * S * scale)
        for i, col in enumerate(RING_ORDER):
            a0 = -90 + i * 45 - seg / 2
            mask = Image.new("L", (w, h), 0)
            md = ImageDraw.Draw(mask)
            md.pieslice([cx - r_out, cy - r_out, cx + r_out, cy + r_out], a0, a0 + seg, fill=255)
            md.ellipse([cx - r_in, cy - r_in, cx + r_in, cy + r_in], fill=0)
            img.paste(Image.new("RGBA", (w, h), col + (255,)), (0, 0), mask)
        d.ellipse([cx - 62 * S, cy - 62 * S, cx + 62 * S, cy + 62 * S],
                  outline=PLATIN, width=4 * S)
    else:  # "lines" - feine Arcs
        r = int(176 * S * scale)
        box = [cx - r, cy - r, cx + r, cy + r]
        for i, col in enumerate(RING_ORDER):
            a0 = -90 + i * 45 - seg / 2
            d.arc(box, a0, a0 + seg, fill=col, width=11 * S)
        rc = int(52 * S * scale)
        d.ellipse([cx - rc, cy - rc, cx + rc, cy + rc],
                  outline=PLATIN, width=3 * S)
    return img.resize((900, 1300), Image.LANCZOS)


# Synthese-Varianten: Vektor-Ring auf schwarz-auf-schwarz-Grund (GR1 Schockwellen-Prägung,
# GR2 ruhiger Lack).
SYNTH = {"X1": ("GR1", "sector", 1.0), "X2": ("GR1", "lines", 1.0),
         "X3": ("GR2", "sector", 1.0),
         # X4: G-Komposition (duenn, klein, ruhiger Grund) in Marken-Farben -
         # ungeprimter QA-Befund: gefuellte Segmente + konzentrischer Grund = Roulette-Read.
         "X4": ("GR2", "lines", 0.55)}


def synth_artwork(label):
    ground_name, style, scale = SYNTH[label]
    ground = Image.open(RAW / f"{ground_name}.png").convert("RGB")
    scale = max(900 / ground.width, 1300 / ground.height)
    ground = ground.resize((int(ground.width * scale) + 1, int(ground.height * scale) + 1),
                           Image.LANCZOS)
    gx, gy = (ground.width - 900) // 2, (ground.height - 1300) // 2
    ground = ground.crop((gx, gy, gx + 900, gy + 1300))
    signet = ring_signet(style, scale)
    ground.paste(signet, (0, 0), signet)
    return ground


def card_back(label, mono=True, suffix="", art=None, save_card=False, sym=False):
    if art is None:
        if label == "G":
            art = g_artwork()
        elif label in SYNTH:
            art = synth_artwork(label)
        else:
            src = RAW / f"{label}.png"
            if not src.exists():
                print(f"[{label}] fehlt, skip")
                return
            art = Image.open(src).convert("RGB")
    if label == "E":
        # eigene Eck-Marken des Artworks wegzoomen (QA: wirken wie Signaturen)
        zx, zy = int(art.width * 0.08), int(art.height * 0.08)
        art = art.crop((zx, zy, art.width - zx, art.height - zy))

    cw, ch = 1000, 1400
    card = Image.new("RGB", (cw, ch), INK)
    inset = 50
    aw, ah = cw - 2 * inset, ch - 2 * inset
    # Artwork mittig beschneiden (cover)
    scale = max(aw / art.width, ah / art.height)
    art = art.resize((int(art.width * scale) + 1, int(art.height * scale) + 1), Image.LANCZOS)
    ax, ay = (art.width - aw) // 2, (art.height - ah) // 2
    art = art.crop((ax, ay, ax + aw, ay + ah))
    card.paste(art, (inset, inset), rounded_mask((aw, ah), 28))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle([inset, inset, inset + aw - 1, inset + ah - 1], 28,
                        outline=PLATIN + (0,), width=0)
    d.rounded_rectangle([inset - 6, inset - 6, inset + aw + 5, inset + ah + 5], 32,
                        outline=(184, 178, 166), width=2)

    # Monogramm-Overlay: P·1441 oben links + 180 Grad gespiegelt unten rechts.
    # QA-Fassungen (mono=False) scoren ohne Overlay - das Monogramm ist austauschbar
    # und gehoert nicht in die Artwork-Bewertung (Tobsi-Feedback 7.7.).
    if mono:
        SS = 4  # supersampled - nie matschig (Tobsi-Auflage 7.7.: Monogramm immer crisp)
        layer = Image.new("RGBA", (cw * SS, ch * SS), (0, 0, 0, 0))
        md = ImageDraw.Draw(layer)
        md.text(((inset + 38) * SS, (inset + 30) * SS), "P · 1441",
                font=font(58 * SS), fill=(224, 218, 204, 240))
        layer = layer.resize((cw, ch), Image.LANCZOS)
        card.paste(layer, (0, 0), layer)
        card.paste(layer.rotate(180), (0, 0), layer.rotate(180))

    if sym:
        # Punktsymmetrie mathematisch erzwungen (Tobsi-Auflage 7.7.: Karte gedreht =
        # identisch, kein Orientierungs-Leak). Blend mit der 180-Grad-Rotation.
        card = Image.blend(card, card.rotate(180), 0.5)
    if save_card:
        card.save(OUT / f"card-{label}{suffix}.png")

    # Präsentations-Tile mit Schatten + Label
    tw, th = 1240, 1720
    tile = tile_bg(tw, th)
    cx, cy = (tw - cw) // 2, (th - ch) // 2 + 20
    shadow = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [cx + 4, cy + 22, cx + cw + 4, cy + ch + 22], 56, fill=(0, 0, 0, 165))
    tile.paste(Image.new("RGB", (tw, th), (0, 0, 0)), (0, 0),
               shadow.filter(ImageFilter.GaussianBlur(38)).split()[3])
    tile.paste(card, (cx, cy), rounded_mask((cw, ch), 56))
    label_badge(ImageDraw.Draw(tile), label)
    tile.save(OUT / f"back-{label}{suffix}.png")
    print(f"[{label}] Kartenrücken komponiert")


def portrait(label):
    src = RAW / f"{label}.png"
    if not src.exists():
        print(f"[{label}] fehlt, skip")
        return
    art = Image.open(src).convert("RGB")
    if label == "O1":
        # generierte Signatur unten links wegschneiden (Anti-Slop, 7.7.)
        art = art.crop((110, 0, 1024, 914))
    art = art.resize((1024, 1024), Image.LANCZOS)
    tw, th = 1240, 1240
    tile = tile_bg(tw, th)
    cx, cy = (tw - 1024) // 2, (th - 1024) // 2 + 10
    shadow = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [cx + 4, cy + 18, cx + 1028, cy + 1042], 32, fill=(0, 0, 0, 160))
    tile.paste(Image.new("RGB", (tw, th), (0, 0, 0)), (0, 0),
               shadow.filter(ImageFilter.GaussianBlur(30)).split()[3])
    tile.paste(art, (cx, cy), rounded_mask((1024, 1024), 28))
    label_badge(ImageDraw.Draw(tile), label)
    tile.save(OUT / f"char-{label}.png")
    print(f"[{label}] Porträt komponiert")


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        for lb in sys.argv[1:]:
            card_back(lb)
    else:
        for lb in ["A", "B", "C", "D", "E", "F", "G", "H", "X1", "X2", "X3", "A1", "A3"]:
            card_back(lb)
        for lb in ("O1", "O2", "V1", "V2", "S1", "S2"):
            portrait(lb)
