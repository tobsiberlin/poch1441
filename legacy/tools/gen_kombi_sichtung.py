#!/usr/bin/env python3
"""Kombi-Sichtung (Tobsi 8.7. spät): W2-Facette + K1-Rahmen sowie W1 + K1-Rahmen,
einzeln und als Fächer. Achtung (im Cockpit vermerkt): K1-Rahmen und W1-Quadranten
sind NICHT punktsymmetrisch - Gewinner bräuchte vor Freeze die Paarungs-Behandlung.
Zusätzlich: Einzel-Fächer FMA-FMD in voller Auflösung (Cockpit-Auflösungs-Fix)."""
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location(
    "w", Path("tools/gen_sichtung2_wappen.py").resolve())
w = importlib.util.module_from_spec(spec)
spec.loader.exec_module(w)
comp, S, W, H = w.comp, w.S, w.W, w.H
OUT = comp.OUT


def fan(card, n=5, spread=44, card_h=340):
    scale = card_h / card.height
    c = card.resize((int(card.width * scale), card_h), Image.LANCZOS).convert("RGBA")
    canvas = Image.new("RGB", (1170, 640), (16, 13, 18))
    pivot_y = 760
    for i in range(n):
        ang = -spread / 2 + i * spread / (n - 1)
        rot = c.rotate(-ang, expand=True, resample=Image.BICUBIC)
        px = int(585 + (pivot_y - 420) * (ang / 60) * 2.2 - rot.width / 2)
        py = int(180 - abs(ang) * 1.1)
        canvas.paste(rot, (px, py), rot)
    return canvas


def k1_frame_overlay():
    img = w.overlay()
    d = ImageDraw.Draw(img)
    inset, wdt = 26 * S, 5 * S
    x0, y0, x1, y1 = inset, inset, W * S - inset, H * S - inset
    gap = 60 * S
    d.line([(x0 + gap, y0), (x1 - gap, y0)], fill=w.GOLD, width=wdt)
    d.line([(x1, y0 + gap), (x1, y1 - gap)], fill=w.ROSE, width=wdt)
    d.line([(x1 - gap, y1), (x0 + gap, y1)], fill=w.SMARAGD, width=wdt)
    d.line([(x0, y1 - gap), (x0, y0 + gap)], fill=w.AMETHYST, width=wdt)
    for pts in [
        [(x0, y0 + gap), (x0, y0), (x0 + gap, y0)],
        [(x1 - gap, y0), (x1, y0), (x1, y0 + gap)],
        [(x1, y1 - gap), (x1, y1), (x1 - gap, y1)],
        [(x0 + gap, y1), (x0, y1), (x0, y1 - gap)],
    ]:
        d.line(pts, fill=w.PLATIN, width=3 * S)
    return img


def w1_lozenge_overlay():
    img = w.overlay()
    d = ImageDraw.Draw(img)
    cx, cy = W * S // 2, H * S // 2
    rw, rh = 200 * S, 280 * S
    top, right = (cx, cy - rh), (cx + rw, cy)
    bottom, left = (cx, cy + rh), (cx - rw, cy)
    center = (cx, cy)
    quads = [(top, right, w.GOLD), (right, bottom, w.ROSE),
             (bottom, left, w.SMARAGD), (left, top, w.AMETHYST)]
    for a, b, col in quads:
        d.polygon([a, b, center], fill=col)
    for a, b, _ in quads:
        d.line([a, center], fill=w.PLATIN, width=2 * S)
        d.line([a, b], fill=w.PLATIN, width=3 * S)
    d.line([right, center], fill=w.PLATIN, width=2 * S)
    kr = 32 * S
    d.polygon([(cx, cy - kr), (cx + kr, cy), (cx, cy + kr), (cx - kr, cy)],
              fill=(24, 21, 27), outline=w.PLATIN, width=3 * S)
    return img


def w2_lozenge_overlay():
    """W2-Final-Geometrie (8 Facetten punktsymmetrisch, 0.64-Innenring) als Overlay."""
    img = w.overlay()
    d = ImageDraw.Draw(img)
    cx, cy = W * S // 2, H * S // 2
    rw, rh = 200 * S, 280 * S
    corners = [(cx, cy - rh), (cx + rw, cy), (cx, cy + rh), (cx - rw, cy)]
    rim = []
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        rim.append(a)
        rim.append(((a[0] + b[0]) // 2, (a[1] + b[1]) // 2))
    inner = [(int(cx + (p[0] - cx) * 0.64), int(cy + (p[1] - cy) * 0.64)) for p in rim]
    cols = [w.GOLD, w.ROSE, w.SMARAGD, w.AMETHYST]
    for i in range(8):
        j = (i + 1) % 8
        col = cols[i % 4]
        d.polygon([rim[i], rim[j], inner[j], inner[i]], fill=col)
        d.polygon([inner[i], inner[j], (cx, cy)], fill=w.darker(col, 0.55))
    for i in range(8):
        j = (i + 1) % 8
        d.line([rim[i], rim[j]], fill=w.PLATIN, width=3 * S)
        d.line([rim[i], inner[i]], fill=w.PLATIN, width=2 * S)
        d.line([inner[i], inner[j]], fill=w.PLATIN, width=2 * S)
    kr = 32 * S
    d.polygon([(cx, cy - kr), (cx + kr, cy), (cx, cy + kr), (cx - kr, cy)],
              fill=(24, 21, 27), outline=w.PLATIN, width=3 * S)
    return img


def compose(*overlays):
    base = w.symmetrize(w.ground())
    for ov in overlays:
        small = ov.resize((W, H), Image.LANCZOS)
        base.paste(small, (0, 0), small)
    return base


if __name__ == "__main__":
    # Kombis (sym=False: K1-Rahmen/W1 sind nicht punktsymmetrisch - Sichtungs-Fassung)
    combos = {
        "WK2": compose(k1_frame_overlay(), w2_lozenge_overlay()),
        "WK1": compose(k1_frame_overlay(), w1_lozenge_overlay()),
    }
    for name, art in combos.items():
        comp.card_back(name, art=art, save_card=True, mono_style="1441")
        card = Image.open(OUT / f"card-{name}.png")
        fan(card).save(OUT / f"faecher-{name}.png")
        print(name, "einzeln + Fächer ok")
    # Auflösungs-Fix: Monogramm-Fächer einzeln in voller Auflösung
    for name in ("FMA", "FMB", "FMC", "FMD"):
        card = Image.open(OUT / f"card-{name}.png")
        fan(card).save(OUT / f"faecher-{name}.png")
        print(name, "Einzel-Fächer ok")
