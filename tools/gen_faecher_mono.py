#!/usr/bin/env python3
"""Fächer-Test Monogramm-Konstellationen (Tobsi 8.7. spät):
A = P·1441 Paar, B = 1441 Paar (aktueller Final), C = P·1441 einzeln, D = 1441 einzeln.
Einzeln bricht die Punktsymmetrie -> sym=False (ehrlich), Paar-Fassungen sym=True."""
import importlib.util
from pathlib import Path
from PIL import Image, ImageDraw

here = Path(__file__).parent
spec_w = importlib.util.spec_from_file_location("w", here / "gen_sichtung2_wappen.py")
w = importlib.util.module_from_spec(spec_w); spec_w.loader.exec_module(w)
spec_f = importlib.util.spec_from_file_location("f", here / "gen_faecher_test.py")
# gen_faecher_test rendert beim Import seine Varianten - vermeiden: fan() hier duplizieren
comp, OUT = w.comp, w.comp.OUT


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


VARIANTS = [
    ("FMA", "A · P·1441 als Paar", "P1441", True),
    ("FMB", "B · 1441 als Paar (aktueller Final)", "1441", True),
    ("FMC", "C · P·1441 einzeln (bricht Print-Symmetrie)", "P1441", False),
    ("FMD", "D · 1441 einzeln (bricht Print-Symmetrie)", "1441", False),
]

art = w.lozenge_final()
strip = Image.new("RGB", (1170, 4 * 660 + 30), (16, 13, 18))
d = ImageDraw.Draw(strip)
for k, (name, title, style, pair) in enumerate(VARIANTS):
    comp.card_back(name, art=art, save_card=True, sym=pair,
                   mono_style=style, mono_pair=pair)
    f = fan(Image.open(OUT / f"card-{name}.png"))
    strip.paste(f, (0, k * 660 + 24))
    d.text((28, k * 660 + 4), title, fill=(210, 204, 190))
strip.save(OUT / "faecher-monogramm.png")
print("Fächer-Matrix:", OUT / "faecher-monogramm.png")
