#!/usr/bin/env python3
"""Kessel-Runde (Tobsi 8.7. spät): Zentralmotiv-Varianten mit Poch-Kessel-Anklang -
stilisiert/abstrahiert, Gestalt-Regel beachtet (kein geschlossener Farbkreis).
Rezept fix: GR2-Grund, Graphit-Kante, 1441-Signet-Paar, Fächer mit Kontaktschatten.
KA = gespiegelter Kessel-Querschnitt (Hofkarten-Spiegelung), KB = angeschnittene
Mulden-Bögen, KC = vertikale Mulden-Prägung. Alle punktsymmetrisch konstruiert."""
import importlib.util
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

spec = importlib.util.spec_from_file_location(
    "sch", Path("tools/gen_faecher_schatten.py").resolve())
sch = importlib.util.module_from_spec(spec)
sch.__name__ = "sch"
spec.loader.exec_module(sch)
k, w, comp = sch.k, sch.k.w, sch.k.comp
OUT, S, W, H = comp.OUT, w.S, w.W, w.H
GRAPHIT = (98, 98, 104)


def half_canvas():
    return Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))


def mirror_compose(top_overlay):
    """Hofkarten-Prinzip: Motiv oben + 180-Grad-Kopie unten = exakt punktsymmetrisch."""
    full = half_canvas()
    full.paste(top_overlay, (0, 0), top_overlay)
    rot = top_overlay.rotate(180)
    full.paste(rot, (0, 0), rot)
    base = w.symmetrize(w.ground())
    small = full.resize((W, H), Image.LANCZOS)
    base.paste(small, (0, 0), small)
    return w.symmetrize(base)


def kessel_querschnitt():
    """KA v2: EIN zentrales Gefäß, Hofkarten-Spiegelung durch die Mitte - der
    gedrechselte Kessel und sein Spiegelbild bilden ein geschlossenes Ornament."""
    ov = half_canvas()
    d = ImageDraw.Draw(ov)
    cx, cyc = W * S // 2, H * S // 2
    bw = 190 * S  # halbe Öffnungsbreite
    top = cyc - 240 * S
    # Körper: gefüllte Schale (warmes Fast-Schwarz) mit Platin-Kontur
    body = [cx - bw, top, cx + bw, cyc + 150 * S]
    mask = Image.new("L", ov.size, 0)
    md = ImageDraw.Draw(mask)
    md.pieslice(body, 0, 180, fill=255)
    ov.paste(Image.new("RGBA", ov.size, (26, 22, 31, 255)), (0, 0), mask)
    d.arc(body, 0, 180, fill=w.PLATIN, width=4 * S)
    # Öffnung: Ellipse am oberen Rand des Körpers
    open_h = 46 * S
    mid_y = (body[1] + body[3]) // 2
    d.ellipse([cx - bw, mid_y - open_h, cx + bw, mid_y + open_h],
              outline=w.PLATIN, width=4 * S)
    # Drechsel-Rillen im Körper
    d.arc([cx - bw + 34 * S, top + 60 * S, cx + bw - 34 * S, cyc + 116 * S], 20, 160,
          fill=w.PLATIN, width=2 * S)
    d.arc([cx - bw + 74 * S, top + 130 * S, cx + bw - 74 * S, cyc + 80 * S], 30, 150,
          fill=w.PLATIN, width=2 * S)
    # 4 Mulden-Juwelen auf der vorderen Öffnungs-Kante
    cols = [w.GOLD, w.ROSE, w.SMARAGD, w.AMETHYST]
    for i, col in enumerate(cols):
        t = -0.66 + i * 0.44
        px = cx + int(bw * t)
        py = mid_y + int(open_h * math.sqrt(max(0.0, 1 - t * t)))
        r = 11 * S
        d.ellipse([px - r, py - r, px + r, py + r], fill=col,
                  outline=w.PLATIN, width=2 * S)
    return mirror_compose(ov)


def mulden_boegen():
    """KB: Kessel-Rand von oben, angeschnitten - zwei Bogenscharen, kein Rad."""
    ov = half_canvas()
    d = ImageDraw.Draw(ov)
    ccx, ccy = 150 * S, 120 * S  # Zentrum nahe Ecke oben links
    for ridx, rad in enumerate([260, 330, 400]):
        r = rad * S
        d.arc([ccx - r, ccy - r, ccx + r, ccy + r], 12, 78,
              fill=w.PLATIN, width=(3 if ridx != 1 else 2) * S)
    # Mulden-Punkte auf dem mittleren Bogen
    cols = [w.GOLD, w.ROSE, w.SMARAGD, w.AMETHYST]
    for i, col in enumerate(cols):
        ang = math.radians(20 + i * 17)
        px = ccx + int(330 * S * math.cos(ang))
        py = ccy + int(330 * S * math.sin(ang))
        r = 10 * S
        d.ellipse([px - r, py - r, px + r, py + r], fill=col,
                  outline=w.PLATIN, width=1 * S)
    return mirror_compose(ov)


def mulden_spalte():
    """KC: drei konkave Mulden-Dellen als vertikale Spalte (taktil, kein Rad).
    Punktsymmetrie: oben Gold, Mitte Amethyst (selbst-symmetrisch), unten via Spiegelung."""
    ov = half_canvas()
    d = ImageDraw.Draw(ov)
    cx = W * S // 2

    def dimple(cy, col, radius):
        r = radius * S
        # Konkav: dunkler Kern, Juwel-Rand unten, Licht-Bogen oben
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(14, 12, 16))
        d.arc([cx - r, cy - r, cx + r, cy + r], 200, 340,
              fill=w.darker(col, 0.9), width=5 * S)
        d.arc([cx - r, cy - r, cx + r, cy + r], 20, 160,
              fill=col, width=6 * S)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=w.PLATIN, width=2 * S)

    dimple(330 * S, w.GOLD, 62)
    dimple(500 * S, w.AMETHYST, 78)  # Mitte oben - Spiegel erzeugt Mitte unten? nein:
    return ov  # KC baut eigen (s.u.)


def kc_compose():
    """KC vollständig: Gold-Delle oben, Amethyst-Delle exakt im Zentrum
    (selbst-punktsymmetrisch), Spiegelung liefert Gold unten."""
    ov = half_canvas()
    d = ImageDraw.Draw(ov)
    cx, cyc = W * S // 2, H * S // 2

    def dimple(cy, col, radius):
        r = radius * S
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(30, 26, 36))
        d.arc([cx - r, cy - r, cx + r, cy + r], 15, 165, fill=col, width=11 * S)
        d.arc([cx - r, cy - r, cx + r, cy + r], 195, 345,
              fill=w.darker(col, 0.45), width=8 * S)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=w.PLATIN, width=3 * S)

    dimple(360 * S, w.GOLD, 72)
    full = half_canvas()
    full.paste(ov, (0, 0), ov)
    rot = ov.rotate(180)
    full.paste(rot, (0, 0), rot)
    # Zentrum: Amethyst-Delle (selbst-symmetrisch nach symmetrize)
    d2 = ImageDraw.Draw(full)
    r = 96 * S
    d2.ellipse([cx - r, cyc - r, cx + r, cyc + r], fill=(32, 27, 40))
    d2.arc([cx - r, cyc - r, cx + r, cyc + r], 15, 165, fill=w.AMETHYST, width=12 * S)
    d2.arc([cx - r, cyc - r, cx + r, cyc + r], 195, 345,
           fill=w.darker(w.AMETHYST, 0.45), width=9 * S)
    d2.ellipse([cx - r, cyc - r, cx + r, cyc + r], outline=w.PLATIN, width=3 * S)
    base = w.symmetrize(w.ground())
    small = full.resize((W, H), Image.LANCZOS)
    base.paste(small, (0, 0), small)
    return w.symmetrize(base)


if __name__ == "__main__":
    variants = {
        "KA": kessel_querschnitt(),
        "KB": mulden_boegen(),
        "KC": kc_compose(),
    }
    rows = []
    for name, art in variants.items():
        comp.card_back(name, art=art, save_card=True, sym=True, edge=GRAPHIT)
        rows.append((name, Image.open(OUT / f"card-{name}.png")))
    rows.append(("W2", Image.open(OUT / "card-W2.png")))  # Referenz (hat Kante schon)

    strip = Image.new("RGB", (1170, len(rows) * 660 + 30), (16, 13, 18))
    d = ImageDraw.Draw(strip)
    titles = {"KA": "KA - Kessel-Querschnitt (Hofkarten-Spiegelung)",
              "KB": "KB - angeschnittene Mulden-Bögen",
              "KC": "KC - vertikale Mulden-Prägung",
              "W2": "Referenz - W2-Facette (Freeze)"}
    for idx, (name, card) in enumerate(rows):
        f = sch.fan(sch.rounded_card(card), shadow=True)
        f.save(OUT / f"faecher-kessel-{name}.png")
        strip.paste(f, (0, idx * 660 + 26))
        d.text((28, idx * 660 + 6), titles[name], fill=(212, 206, 192))
    strip.save(OUT / "faecher-kessel.png")
    print("Kessel-Runde gebaut")


# ---- Runde 2 (Tobsi 8.7. nachts: "noch paar mehr Varianten") -----------------
def kessel_stapel():
    """KD: drei gestapelte Kessel-Schalen (Seitenansicht, gedrechselt) - vertikale
    Achse, Hofkarten-Spiegelung."""
    ov = half_canvas()
    d = ImageDraw.Draw(ov)
    cx = W * S // 2
    cols = [w.GOLD, w.SMARAGD, w.AMETHYST]
    for k, col in enumerate(cols):
        cy = (230 + k * 128) * S
        bw = (150 - k * 18) * S
        d.arc([cx - bw, cy - 40 * S, cx + bw, cy + 76 * S], 10, 170,
              fill=w.PLATIN, width=3 * S)
        d.ellipse([cx - bw, cy - 22 * S, cx + bw, cy + 22 * S],
                  outline=w.PLATIN, width=3 * S)
        r = 8 * S
        d.ellipse([cx - r, cy + 22 * S - r, cx + r, cy + 22 * S + r],
                  fill=col, outline=w.PLATIN, width=1 * S)
    return mirror_compose(ov)


def kessel_angeschnitten():
    """KE: der Kessel-Rand von oben, GROSS angeschnitten - nur ein Bogen-Ausschnitt
    mit Mulden-Kerben läuft durch die Ecke (kein geschlossener Kreis)."""
    import math
    ov = half_canvas()
    d = ImageDraw.Draw(ov)
    ccx, ccy = -80 * S, 60 * S
    for rad, wd in [(430, 4), (500, 3)]:
        r = rad * S
        d.arc([ccx - r, ccy - r, ccx + r, ccy + r], 5, 80, fill=w.PLATIN, width=wd * S)
    cols = [w.GOLD, w.ROSE, w.SMARAGD, w.AMETHYST]
    for i, col in enumerate(cols):
        ang = math.radians(16 + i * 18)
        px = ccx + int(465 * S * math.cos(ang))
        py = ccy + int(465 * S * math.sin(ang))
        r = 13 * S
        d.ellipse([px - r, py - r, px + r, py + r], fill=col,
                  outline=w.PLATIN, width=2 * S)
    return mirror_compose(ov)


def kessel_silhouette():
    """KF: die Kessel-Silhouette als tone-on-tone Prägung (fast schwarz-auf-schwarz),
    nur die 4 Mulden-Punkte tragen Farbe - C-Materialsprache pur."""
    ov = half_canvas()
    d = ImageDraw.Draw(ov)
    cx, cy = W * S // 2, 420 * S
    bw = 190 * S
    body = [cx - bw, cy - 120 * S, cx + bw, cy + 140 * S]
    mask = Image.new("L", ov.size, 0)
    ImageDraw.Draw(mask).pieslice(body, 0, 180, fill=255)
    ov.paste(Image.new("RGBA", ov.size, (30, 26, 34, 255)), (0, 0), mask)
    d.arc(body, 0, 180, fill=(58, 53, 64, 255), width=4 * S)
    d.ellipse([cx - bw, cy - 34 * S, cx + bw, cy + 34 * S],
              outline=(58, 53, 64, 255), width=4 * S)
    cols = [w.GOLD, w.ROSE, w.SMARAGD, w.AMETHYST]
    for i, col in enumerate(cols):
        t = -0.6 + i * 0.4
        px = cx + int(bw * t)
        import math
        py = cy + int(34 * S * math.sqrt(max(0.0, 1 - t * t)))
        r = 10 * S
        d.ellipse([px - r, py - r, px + r, py + r], fill=col,
                  outline=w.PLATIN, width=1 * S)
    return mirror_compose(ov)
