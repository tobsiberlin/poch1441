#!/usr/bin/env python3
"""Fächer-Wette (Tobsi 8.7. spät): Trennungs-Mechanismen im Vergleich.
Reihe 1: reines W2 (rahmenlos). Reihe 2: WK2 (Farbrand). Reihe 3: W1-Quadranten +
Kontaktschatten + neutrale Graphit-Hairline (Tobsis Kandidat). Reihe 4 (Bonus):
W2-Facetten mit demselben Schatten+Graphit-Mechanismus (isoliert die Rauten-Frage)."""
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

spec = importlib.util.spec_from_file_location(
    "k", Path("tools/gen_kombi_sichtung.py").resolve())
k = importlib.util.module_from_spec(spec)
spec.loader.exec_module(k)
w, comp = k.w, k.comp
OUT = comp.OUT
GRAPHIT = (98, 98, 104)
RADIUS = 34


def rounded_card(path_or_img, edge=None):
    """Karte mit runden Ecken als RGBA; optional Graphit-Hairline auf der Kante."""
    img = (Image.open(path_or_img) if not isinstance(path_or_img, Image.Image)
           else path_or_img).convert("RGBA")
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.width - 1, img.height - 1], RADIUS * 2, fill=255)
    img.putalpha(mask)
    if edge:
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([1, 1, img.width - 2, img.height - 2], RADIUS * 2,
                            outline=edge + (255,), width=4)
    return img


def fan(card_rgba, shadow=False, n=5, spread=44, card_h=340):
    scale = card_h / card_rgba.height
    c = card_rgba.resize((int(card_rgba.width * scale), card_h), Image.LANCZOS)
    canvas = Image.new("RGB", (1170, 640), (16, 13, 18))
    pivot_y = 760
    for i in range(n):
        ang = -spread / 2 + i * spread / (n - 1)
        rot = c.rotate(-ang, expand=True, resample=Image.BICUBIC)
        px = int(585 + (pivot_y - 420) * (ang / 60) * 2.2 - rot.width / 2)
        py = int(180 - abs(ang) * 1.1)
        if shadow and i > 0:
            # Kontaktschatten: Silhouette der Karte faellt weich auf die darunterliegende
            sil = Image.new("RGBA", rot.size, (0, 0, 0, 0))
            alpha = rot.split()[3].point(lambda a: int(a * 0.62))
            sil.paste((0, 0, 0, 255), (0, 0), alpha)
            sil = sil.filter(ImageFilter.GaussianBlur(16))
            canvas.paste(Image.new("RGB", sil.size, (0, 0, 0)), (px - 18, py + 10),
                         sil.split()[3])
        canvas.paste(rot, (px, py), rot)
    return canvas


if __name__ == "__main__":
    # SG1: W1-Quadranten + Graphit-Kante; SG2: W2-Facetten + Graphit-Kante
    art_w1 = k.compose(k.w1_lozenge_overlay())
    comp.card_back("SG1", art=art_w1, save_card=True, mono_style="1441")
    art_w2 = k.compose(k.w2_lozenge_overlay())
    comp.card_back("SG2", art=art_w2, save_card=True, mono_style="1441")

    rows = [
        ("R1", "1 - reines W2 (rahmenlos, Final)", rounded_card(OUT / "card-W2.png"), False),
        ("R2", "2 - WK2 (Juwelen-Farbrand)", rounded_card(OUT / "card-WK2.png"), False),
        ("R3", "3 - W1 + Kontaktschatten + Graphit-Kante (Tobsis Kandidat)",
         rounded_card(OUT / "card-SG1.png", edge=GRAPHIT), True),
        ("R4", "4 - Bonus: W2-Facetten + Schatten + Graphit-Kante",
         rounded_card(OUT / "card-SG2.png", edge=GRAPHIT), True),
    ]
    strip = Image.new("RGB", (1170, len(rows) * 660 + 30), (16, 13, 18))
    d = ImageDraw.Draw(strip)
    for idx, (name, title, card, sh) in enumerate(rows):
        f = fan(card, shadow=sh)
        f.save(OUT / f"faecher-wette-{name}.png")
        strip.paste(f, (0, idx * 660 + 26))
        d.text((28, idx * 660 + 6), title, fill=(212, 206, 192))
    strip.save(OUT / "faecher-wette.png")
    print("Wette gebaut:", OUT / "faecher-wette.png")
