#!/usr/bin/env python3
"""Fächer-Test (Tobsi 8.7.): 5 überlappende W2-Rücken als Gegnerhand - der ehrliche
Spielgrößen-Test. Drei Fassungen: A = Final, B = Sättigung -12%, C = dunkle
Innenfacetten vergrößert (mehr Schwarzanteil). Flimmert der Fächer, gewinnt B oder C."""
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location("w", Path(__file__).parent / "gen_sichtung2_wappen.py")
w = importlib.util.module_from_spec(spec)
spec.loader.exec_module(w)
comp, S, W, H = w.comp, w.S, w.W, w.H
OUT = comp.OUT


def muted(col, f=0.12):
    lum = int(0.299 * col[0] + 0.587 * col[1] + 0.114 * col[2])
    return tuple(int(c * (1 - f) + lum * f) for c in col)


def lozenge_variant(cols, inner_t):
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
    inner = [(int(cx + (p[0] - cx) * inner_t), int(cy + (p[1] - cy) * inner_t)) for p in rim]
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
    base = w.symmetrize(w.ground())
    small = img.resize((W, H), Image.LANCZOS)
    base.paste(small, (0, 0), small)
    return w.symmetrize(base)


def build_card(art, name):
    comp.card_back(name, art=art, save_card=True, sym=True)
    return Image.open(OUT / f"card-{name}.png")


def fan(card, n=5, spread=44, card_h=340):
    scale = card_h / card.height
    c = card.resize((int(card.width * scale), card_h), Image.LANCZOS).convert("RGBA")
    canvas = Image.new("RGB", (1170, 640), (16, 13, 18))
    ImageDraw.Draw(canvas).rectangle([0, 0, 1170, 640], fill=(16, 13, 18))
    pivot_y = 760
    for i in range(n):
        ang = -spread / 2 + i * spread / (n - 1)
        rot = c.rotate(-ang, expand=True, resample=Image.BICUBIC)
        px = int(585 + (pivot_y - 420) * (ang / 60) * 2.2 - rot.width / 2)
        py = int(180 - abs(ang) * 1.1)
        canvas.paste(rot, (px, py), rot)
    return canvas


base_cols = [w.GOLD, w.ROSE, w.SMARAGD, w.AMETHYST]
variants = {
    "FA": (base_cols, 0.5),                       # Final wie eingefroren
    "FB": ([muted(c) for c in base_cols], 0.5),   # Saettigung -12%
    "FC": (base_cols, 0.64),                      # dunkle Innenfacetten groesser
}
strip = Image.new("RGB", (1170, 3 * 660 + 40), (16, 13, 18))
d = ImageDraw.Draw(strip)
for k, (name, (cols, t)) in enumerate(variants.items()):
    card = build_card(lozenge_variant(cols, t), name)
    f = fan(card)
    strip.paste(f, (0, k * 660 + 20))
    d.text((28, k * 660 + 30), name, fill=(201, 194, 180))
strip.save(OUT / "faecher-test.png")
print("Fächer-Test:", OUT / "faecher-test.png")
