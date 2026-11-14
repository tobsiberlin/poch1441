#!/usr/bin/env python3
"""M9 kontrollierter Poch-Ring-Render.

Kein KI-Bild: deterministische Raster-Skizze aus Geometrie, Materiallicht und
Muenzen. Ziel: PM8/PM7-Art-Direction in spielbarer Form pruefen:
8 Aussenmulden + Mitte, Pigment-Rims statt Bodenbuttons, Muenzen verdecken
die Farblogik nicht.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/Users/tobsi/poch1441")
ART = ROOT / "artifacts" / "m9"
TEMP = Path("/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP")
ART.mkdir(parents=True, exist_ok=True)

S = 3
W = H = 980
CX = CY = W // 2
R_OUT = 390
R_IN = 167
R_POOL = 72
R_RING = 295

BG = (7, 6, 10)
BODY_DARK = (13, 13, 17)
BODY_LIFT = (28, 27, 33)
BASIN = (3, 3, 5)
EDGE = (56, 54, 62)
PLATIN = (216, 222, 232)
GOLD = (197, 160, 89)
ROSE = (142, 42, 67)
TEAL = (26, 94, 78)
AMETHYST = (74, 46, 101)


def sc(v):
    return int(round(v * S))


def ellipse(draw, cx, cy, r, fill, outline=None, width=1):
    box = [sc(cx - r), sc(cy - r), sc(cx + r), sc(cy + r)]
    draw.ellipse(box, fill=fill, outline=outline, width=sc(width) if outline else 1)


def radial_disc(size, center, radius, inner, outer):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    px = img.load()
    cx, cy = center
    for y in range(max(0, cy - radius), min(size[1], cy + radius)):
        for x in range(max(0, cx - radius), min(size[0], cx + radius)):
            dx = x - cx
            dy = y - cy
            d = math.sqrt(dx * dx + dy * dy)
            if d <= radius:
                # top-left light, bottom-right falloff
                t = min(1, d / radius)
                light = max(0, (-dx - dy) / (radius * 1.5))
                shade = 1 - 0.45 * t + 0.18 * light
                col = tuple(max(0, min(255, int(outer[i] + (inner[i] - outer[i]) * shade))) for i in range(3))
                px[x, y] = (*col, 255)
    return img


def coin_layer(cx, cy, n, seed):
    rng = random.Random(seed)
    layer = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    for i in range(n):
        ox = rng.uniform(-25, 25)
        oy = rng.uniform(-17, 17)
        rx = rng.uniform(22, 28)
        ry = rng.uniform(12, 15)
        angle = rng.uniform(-26, 26)
        coin = Image.new("RGBA", (sc(70), sc(44)), (0, 0, 0, 0))
        d = ImageDraw.Draw(coin)
        box = [sc(8), sc(8), sc(62), sc(36)]
        d.ellipse(box, fill=(183, 132, 43, 255), outline=(242, 207, 122, 255), width=sc(2))
        d.arc(box, 205, 338, fill=(90, 58, 18, 255), width=sc(3))
        d.arc([box[0] + sc(5), box[1] + sc(4), box[2] - sc(5), box[3] - sc(4)],
              25, 155, fill=(255, 226, 142, 180), width=sc(2))
        coin = coin.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
        x = sc(cx + ox) - coin.width // 2
        y = sc(cy + oy) - coin.height // 2 - sc(i * 2.2)
        shadow = Image.new("RGBA", coin.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.ellipse([sc(8), sc(12), coin.width - sc(8), coin.height - sc(8)], fill=(0, 0, 0, 115))
        layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(sc(2))), (x + sc(2), y + sc(3)))
        layer.alpha_composite(coin, (x, y))
    return layer


def draw_ring():
    img = Image.new("RGBA", (W * S, H * S), (*BG, 255))
    bg_lift = radial_disc((W * S, H * S), (sc(CX), sc(CY - 90)), sc(620), (34, 28, 38), BG)
    img.alpha_composite(bg_lift)

    # outer drop shadow
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([sc(CX - R_OUT), sc(CY - R_OUT + 28), sc(CX + R_OUT), sc(CY + R_OUT + 28)],
               fill=(0, 0, 0, 190))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(sc(18))))

    body = radial_disc(img.size, (sc(CX - 80), sc(CY - 105)), sc(R_OUT), BODY_LIFT, BODY_DARK)
    body_mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(body_mask)
    md.ellipse([sc(CX - R_OUT), sc(CY - R_OUT), sc(CX + R_OUT), sc(CY + R_OUT)], fill=255)
    img.alpha_composite(Image.composite(body, Image.new("RGBA", img.size), body_mask))

    d = ImageDraw.Draw(img)
    ellipse(d, CX, CY, R_OUT, None, (42, 40, 48), 4)
    ellipse(d, CX, CY, R_OUT - 12, None, (12, 12, 16), 2)
    ellipse(d, CX, CY, R_RING - 92, None, (41, 39, 46), 2)

    pools = [
        ("K", GOLD, 2), ("Q", GOLD, 1), ("MAR", ROSE, 4), ("POCH", AMETHYST, 3),
        ("SEQ", TEAL, 4), ("10", GOLD, 2), ("J", GOLD, 1), ("A", GOLD, 3),
    ]
    anchors = []
    for idx in range(8):
        angle = -math.pi / 2 + idx * math.tau / 8
        x = CX + math.cos(angle) * R_RING
        y = CY + math.sin(angle) * R_RING
        anchors.append((x, y, angle))

    # recessed wells
    for (label, color, coins), (x, y, _angle) in zip(pools, anchors):
        # outer bevel lip
        ellipse(d, x, y, R_POOL + 13, (14, 14, 18), (35, 34, 40), 2)
        # bowl shadow
        ellipse(d, x, y, R_POOL, BASIN, (7, 7, 10), 1)
        # concave highlight crescent
        crescent = Image.new("RGBA", img.size, (0, 0, 0, 0))
        cd = ImageDraw.Draw(crescent)
        cd.arc([sc(x - R_POOL + 10), sc(y - R_POOL + 10), sc(x + R_POOL - 10), sc(y + R_POOL - 10)],
               205, 338, fill=(0, 0, 0, 145), width=sc(14))
        cd.arc([sc(x - R_POOL + 14), sc(y - R_POOL + 12), sc(x + R_POOL - 16), sc(y + R_POOL - 18)],
               25, 145, fill=(180, 185, 192, 62), width=sc(7))
        img.alpha_composite(crescent)
        # pigment rim - always visible above coins
        ellipse(d, x, y, R_POOL - 8, None, color, 7)
        ellipse(d, x, y, R_POOL - 17, None, tuple(min(255, c + 38) for c in color), 1)
        img.alpha_composite(coin_layer(x, y, coins, 1441 + int(x) + int(y)))

    # center pot
    ellipse(d, CX, CY, R_IN + 18, (10, 10, 14), (48, 46, 54), 5)
    ellipse(d, CX, CY, R_IN, BASIN, (12, 12, 16), 1)
    d.arc([sc(CX - R_IN + 18), sc(CY - R_IN + 14), sc(CX + R_IN - 18), sc(CY + R_IN - 26)],
          25, 150, fill=(210, 216, 226, 60), width=sc(8))
    ellipse(d, CX, CY, R_IN - 10, None, PLATIN, 4)
    img.alpha_composite(coin_layer(CX, CY, 5, 91441))

    # labels as vector UI overlay
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", sc(27))
        font_small = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", sc(18))
        font_center = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", sc(42))
    except OSError:
        font = font_small = font_center = ImageFont.load_default()
    for (label, color, _coins), (x, y, _angle) in zip(pools, anchors):
        f = font_small if len(label) > 2 else font
        text = "+24" if label in {"MAR", "SEQ"} else "+8"
        for ty, text_value, ff, alpha in [(y - 16, label, f, 235), (y + 23, text, font_small, 220)]:
            bbox = d.textbbox((0, 0), text_value, font=ff)
            d.text((sc(x) - (bbox[2] - bbox[0]) // 2, sc(ty) - (bbox[3] - bbox[1]) // 2),
                   text_value, fill=(*color, alpha), font=ff)

    for text, yy, ff, fill in [("MITTE", CY - 22, font_small, (*PLATIN, 205)),
                               ("38", CY + 25, font_center, (*PLATIN, 240))]:
        bbox = d.textbbox((0, 0), text, font=ff)
        d.text((sc(CX) - (bbox[2] - bbox[0]) // 2, sc(yy) - (bbox[3] - bbox[1]) // 2),
               text, fill=fill, font=ff)

    return img.resize((W, H), Image.Resampling.LANCZOS)


def write_html(png_path):
    html = f"""<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>M9 · Poch-Ring Render</title>
  <style>
    :root {{ color-scheme: dark; --bg:#07060a; --text:#e2e8f0; --muted:#9aa3af; --gold:#c5a059; }}
    body {{ margin:0; background:radial-gradient(circle at 50% 12%, #17131c, var(--bg) 58%); color:var(--text); font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif; }}
    main {{ max-width:980px; margin:0 auto; padding:28px 22px 40px; }}
    h1 {{ margin:0 0 8px; font-size:28px; }}
    p {{ color:var(--muted); line-height:1.45; }}
    .frame {{ border:1px solid rgba(197,160,89,.28); border-radius:12px; background:#0f0d13; padding:14px; margin-top:18px; }}
    img {{ display:block; width:100%; border-radius:8px; }}
    .note {{ margin-top:14px; font-size:14px; }}
    code {{ color:var(--gold); }}
  </style>
</head>
<body>
  <main>
    <h1>M9 · Pigment-Rim + Münzen</h1>
    <p>Kontrollierter Render nach PM8-Art-Direction: Farbe sitzt als Pigment-Rim am oberen Innenrand, Münzen liegen im dunklen Schalenraum. Labels und Werte sind Vektor/UI-Overlays.</p>
    <div class="frame"><img src="m9-ring.png" alt="M9 Poch-Ring Render"></div>
    <p class="note">Wichtig: Das ist kein finaler Asset-Stil, sondern ein spielbarer Material-/Geometrie-Test. Final würden die Münzen als Sprite/Particle-Layer und der Ring als SwiftUI/SpriteKit-Geometrie gebaut.</p>
  </main>
</body>
</html>
"""
    (ART / "m9-ring.html").write_text(html, encoding="utf-8")
    (TEMP / "m9-ring.html").write_text(html, encoding="utf-8")
    # copy png next to temp html for relative img src
    (TEMP / "m9-ring.png").write_bytes(png_path.read_bytes())


def main():
    img = draw_ring()
    png = ART / "m9-ring.png"
    img.save(png)
    write_html(png)
    print("PNG:", png)
    print("HTML:", ART / "m9-ring.html")
    print("TEMP:", TEMP / "m9-ring.html")


if __name__ == "__main__":
    main()
