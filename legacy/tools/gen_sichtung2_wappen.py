#!/usr/bin/env python3
"""Sichtung 2 (7.7. nachts, Tobsi-Richtungen): die Rad-Gestalt aufbrechen.

W1/W2 - heraldisches Vertikal-Siegel (Raute, Facetten in Juwel-Tönen, clean-modern,
KEINE Heraldik-Schnörkel). B1/B2 - das Brett als flache Prägung (echte Ring-Geometrie,
großer Mitte-Pott bricht die Rad-Symmetrie, KEINE Umfassungslinie). K1 - Farbe raus
aus dem Kreis: ruhiges Relief, Juwel-Farben nur als Rahmen-Signal.
Alles deterministisch (G-Weg), Grund = ruhiger Lack (GR2, C-Materialsprache).
"""
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location(
    "comp", Path(__file__).parent / "gen_sichtung1_composite.py")
comp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(comp)

S = 4
W, H = 900, 1300
GOLD, ROSE = comp.JEWEL_GOLD, comp.JEWEL_ROSE
SMARAGD, AMETHYST = comp.JEWEL_SMARAGD, comp.JEWEL_AMETHYST
PLATIN = comp.PLATIN


def ground():
    g = Image.open(comp.RAW / "GR2.png").convert("RGB")
    scale = max(W / g.width, H / g.height)
    g = g.resize((int(g.width * scale) + 1, int(g.height * scale) + 1), Image.LANCZOS)
    gx, gy = (g.width - W) // 2, (g.height - H) // 2
    return g.crop((gx, gy, gx + W, gy + H))


def overlay():
    return Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))


def mount(img_rgba):
    base = ground()
    small = img_rgba.resize((W, H), Image.LANCZOS)
    base.paste(small, (0, 0), small)
    return base


def darker(col, f=0.62):
    return tuple(int(c * f) for c in col)


def lozenge(facetted):
    """W1 (facetted=False): 4 Quadrant-Facetten + Platin-Kern. W2: 8 Facetten
    (außen Juwel, innen abgedunkelt) - Fabergé-Querschnitt, vertikale Achse."""
    img = overlay()
    d = ImageDraw.Draw(img)
    cx, cy = W * S // 2, H * S // 2
    rw, rh = 170 * S, 250 * S
    top, right = (cx, cy - rh), (cx + rw, cy)
    bottom, left = (cx, cy + rh), (cx - rw, cy)
    center = (cx, cy)
    quads = [(top, right, GOLD), (right, bottom, ROSE),
             (bottom, left, SMARAGD), (left, top, AMETHYST)]
    if not facetted:
        for a, b, col in quads:
            d.polygon([a, b, center], fill=col)
    else:
        for a, b, col in quads:
            mid = ((a[0] + b[0]) // 2, (a[1] + b[1]) // 2)
            d.polygon([a, b, mid], fill=col)          # Außen-Facette
            d.polygon([a, mid, center], fill=darker(col))
            d.polygon([mid, b, center], fill=darker(col, 0.5))
    # Hairline-Trennungen + Kontur (Platin)
    for a, b, _ in quads:
        d.line([a, center], fill=PLATIN, width=2 * S)
        d.line([a, b], fill=PLATIN, width=3 * S)
    d.line([right, center], fill=PLATIN, width=2 * S)
    # Platin-Kern (kleine Raute, 9. Mulde)
    kr = 34 * S
    d.polygon([(cx, cy - kr), (cx + kr, cy), (cx, cy + kr), (cx - kr, cy)],
              fill=(24, 21, 27), outline=PLATIN, width=3 * S)
    return mount(img)


def board(hairline):
    """B1 (hairline=False): das Brett als flache Intarsie - 8 Mulden-Tiles in echter
    Anker-Geometrie + großer Platin-Mitte-Pott. B2: nur Konturen. Keine Umfassungslinie,
    keine konzentrischen Rillen - die Asymmetrie (8 klein + 1 groß) bricht das Rad."""
    import math
    img = overlay()
    d = ImageDraw.Draw(img)
    cx, cy = W * S // 2, H * S // 2
    ring_r = 200 * S
    tile = 68 * S       # Kantenlänge (Verhältnis ~54/130 wie im Spiel)
    corner = 18 * S
    order = comp.RING_ORDER  # K Q MAR J 10 SEQ POCH A ab 12 Uhr
    for i, col in enumerate(order):
        ang = math.radians(-90 + i * 45)
        tx = cx + ring_r * math.cos(ang)
        ty = cy + ring_r * math.sin(ang)
        box = [tx - tile / 2, ty - tile / 2, tx + tile / 2, ty + tile / 2]
        if hairline:
            d.rounded_rectangle(box, corner, outline=col, width=5 * S)
        else:
            d.rounded_rectangle(box, corner, fill=col,
                                outline=darker(col, 0.55), width=2 * S)
    # Mitte-Pott: deutlich größer (bricht die Rad-Uniformität), Platin
    pr = 62 * S
    if hairline:
        d.ellipse([cx - pr, cy - pr, cx + pr, cy + pr], outline=PLATIN, width=5 * S)
    else:
        d.ellipse([cx - pr, cy - pr, cx + pr, cy + pr],
                  fill=(30, 27, 33), outline=PLATIN, width=4 * S)
    return mount(img)


def edge_frame():
    """K1: Zentrum bleibt ruhiges Material, die 9 Label-Farben leben als Rahmen-Signal
    (4 Juwel-Seiten + Platin-Ecken) - garantiert kein Rad."""
    img = overlay()
    d = ImageDraw.Draw(img)
    inset, wdt = 26 * S, 5 * S
    x0, y0, x1, y1 = inset, inset, W * S - inset, H * S - inset
    gap = 60 * S  # Platin-Ecken
    d.line([(x0 + gap, y0), (x1 - gap, y0)], fill=GOLD, width=wdt)
    d.line([(x1, y0 + gap), (x1, y1 - gap)], fill=ROSE, width=wdt)
    d.line([(x1 - gap, y1), (x0 + gap, y1)], fill=SMARAGD, width=wdt)
    d.line([(x0, y1 - gap), (x0, y0 + gap)], fill=AMETHYST, width=wdt)
    for corner_pts in [
        [(x0, y0 + gap), (x0, y0), (x0 + gap, y0)],
        [(x1 - gap, y0), (x1, y0), (x1, y0 + gap)],
        [(x1, y1 - gap), (x1, y1), (x1 - gap, y1)],
        [(x0 + gap, y1), (x0, y1), (x0, y1 - gap)],
    ]:
        d.line(corner_pts, fill=PLATIN, width=3 * S)
    # kleines zentriertes Platin-Karo als stiller Anker (kein Kreis)
    cx, cy, kr = W * S // 2, H * S // 2, 26 * S
    d.polygon([(cx, cy - kr), (cx + kr, cy), (cx, cy + kr), (cx - kr, cy)],
              outline=PLATIN, width=3 * S)
    return mount(img)


if __name__ == "__main__":
    jobs = {
        "W1": lozenge(facetted=False),
        "W2": lozenge(facetted=True),
        "B1": board(hairline=False),
        "B2": board(hairline=True),
        "K1": edge_frame(),
    }
    for label, art in jobs.items():
        comp.card_back(label, art=art)
        comp.card_back(label, mono=False, suffix="-qa", art=art)


# ---- W2-FINAL (Tobsi-Auflagen 7.7. nachts) ---------------------------------
def symmetrize(img):
    return Image.blend(img, img.rotate(180), 0.5)


def lozenge_final():
    """W2-final: 8 Facetten PUNKTSYMMETRISCH (Facette i = Facette i+4 in Farbe) -
    gedrehte Karte ist identisch, kein Orientierungs-Leak (E-Fehler behoben).
    Größen-Bump gegen Spielgrößen-Verlorenheit (Kritik 2). Grund + Artwork werden
    zusätzlich mathematisch symmetrisiert."""
    img = overlay()
    d = ImageDraw.Draw(img)
    cx, cy = W * S // 2, H * S // 2
    rw, rh = 200 * S, 280 * S
    corners = [(cx, cy - rh), (cx + rw, cy), (cx, cy + rh), (cx - rw, cy)]
    rim = []
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        rim.append(a)
        rim.append(((a[0] + b[0]) // 2, (a[1] + b[1]) // 2))

    def to_center(p, t):
        return (int(cx + (p[0] - cx) * t), int(cy + (p[1] - cy) * t))

    # 0.64 statt 0.5 (Fächer-Test 8.7.: FC gewinnt - mehr Schwarzanteil = ruhiger Fächer)
    inner = [to_center(p, 0.64) for p in rim]
    cols = [GOLD, ROSE, SMARAGD, AMETHYST]  # i%4 -> punktsymmetrisch (i und i+4 gleich)
    for i in range(8):
        j = (i + 1) % 8
        col = cols[i % 4]
        d.polygon([rim[i], rim[j], inner[j], inner[i]], fill=col)
        d.polygon([inner[i], inner[j], (cx, cy)], fill=darker(col, 0.55))
    for i in range(8):
        j = (i + 1) % 8
        d.line([rim[i], rim[j]], fill=PLATIN, width=3 * S)
        d.line([rim[i], inner[i]], fill=PLATIN, width=2 * S)
        d.line([inner[i], inner[j]], fill=PLATIN, width=2 * S)
    kr = 32 * S
    d.polygon([(cx, cy - kr), (cx + kr, cy), (cx, cy + kr), (cx - kr, cy)],
              fill=(24, 21, 27), outline=PLATIN, width=3 * S)
    base = symmetrize(ground())
    small = img.resize((W, H), Image.LANCZOS)
    base.paste(small, (0, 0), small)
    return symmetrize(base)
