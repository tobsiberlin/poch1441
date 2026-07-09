#!/usr/bin/env python3
"""Minimal PM1 edits: keep PM1 image/material, add only center pot + rings.

The PM1 raw render already has the right graphite/engraved material language.
These variants intentionally do not rebuild the board. They only paint subtle
pigment on the existing basin lips and carve a PM1-like basin into the center.
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/Users/tobsi/poch1441")
SRC = ROOT / "Assets_Raw" / "pochring" / "precision-monolith" / "PM1.png"
RAW = ROOT / "Assets_Raw" / "pochring" / "precision-monolith"
ART = ROOT / "artifacts" / "precision-monolith"

GOLD = (197, 158, 82)
GOLD_SOFT = (178, 138, 66)
GARNET = (128, 38, 56)
EMERALD = (34, 128, 104)
AMETHYST = (90, 49, 126)
PLATINUM = (184, 190, 202)

# Centers measured from the PM1 raw image. This keeps the rings on the existing
# PM1 basins instead of imposing a new idealized circle.
WELLS = [
    ((512, 204), GOLD),      # top
    ((348, 279), GOLD_SOFT), # upper left
    ((674, 279), GOLD_SOFT), # upper right
    ((790, 451), EMERALD),   # right
    ((674, 740), GARNET),    # lower right
    ((512, 808), GOLD),      # bottom
    ((348, 740), GOLD_SOFT), # lower left
    ((234, 451), AMETHYST),  # left
]


def subtle_ring(size, center, radius, color, width, alpha, highlight_alpha):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer, "RGBA")
    x, y = center
    box = [x - radius, y - radius, x + radius, y + radius]
    dark = tuple(max(0, int(c * 0.45)) for c in color)
    light = tuple(min(255, int(c + 30)) for c in color)

    # Ring sits exactly on PM1's inner lip: low opacity pigment, no glow blur.
    d.ellipse(box, outline=(*dark, int(alpha * 0.7)), width=width + 2)
    d.ellipse(box, outline=(*color, alpha), width=width)
    d.arc(box, 25, 148, fill=(*light, highlight_alpha), width=max(1, width - 1))
    d.arc(box, 205, 338, fill=(0, 0, 0, int(alpha * 0.55)), width=width + 1)
    return layer


def clipped_ring(src: Image.Image, center, radius, color, width, alpha, highlight_alpha):
    ring = subtle_ring(src.size, center, radius, color, width, alpha, highlight_alpha)

    # PM1's rings live in the dark cut edge of each basin. Clip the pigment to
    # dark local pixels so a full mathematical circle cannot appear on the
    # graphite surface between pockets.
    gray = src.convert("L")
    local = Image.new("L", src.size, 0)
    d = ImageDraw.Draw(local)
    x, y = center
    d.ellipse([x - radius - 18, y - radius - 18, x + radius + 18, y + radius + 18], fill=255)
    dark = gray.point(lambda p: 255 if p < 95 else 0)
    mask = ImageChops.multiply(local, dark).filter(ImageFilter.GaussianBlur(0.6))
    ring.putalpha(ImageChops.multiply(ring.getchannel("A"), mask))
    return ring


def center_pot(size, variant, *, precise: bool = False):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer, "RGBA")
    cx, cy = 512, 512
    if variant == "small":
        outer_r, inner_r, alpha = 143, 127, 150
    elif variant == "deep":
        outer_r, inner_r, alpha = 158, 138, 174
    else:
        outer_r, inner_r, alpha = 151, 132, 162

    # Optical cut into PM1 center plate. Precise variants avoid asymmetric arcs
    # because those made the center read visually off-center.
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow, "RGBA")
    if precise:
        sd.ellipse([cx - outer_r - 4, cy - outer_r + 8, cx + outer_r + 4, cy + outer_r + 16], fill=(0, 0, 0, 122))
        layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(12)))
    else:
        sd.ellipse([cx - outer_r - 6, cy - outer_r + 10, cx + outer_r + 6, cy + outer_r + 20], fill=(0, 0, 0, 150))
        layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))

    outer = [cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r]
    inner = [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r]
    d.ellipse(outer, fill=(5, 5, 7, alpha), outline=(26, 26, 31, 150), width=9)
    d.ellipse(inner, fill=(6, 6, 9, int(alpha * 0.92)))
    if precise:
        d.ellipse([cx - inner_r + 18, cy - inner_r + 18, cx + inner_r - 18, cy + inner_r - 18],
                  outline=(92, 94, 102, 42), width=3)
        d.ellipse([cx - outer_r + 20, cy - outer_r + 20, cx + outer_r - 20, cy + outer_r - 20],
                  outline=(0, 0, 0, 82), width=8)
    else:
        d.arc(inner, 22, 150, fill=(158, 160, 168, 54), width=12)
        d.arc(inner, 205, 342, fill=(0, 0, 0, 130), width=16)
    d.ellipse([cx - outer_r + 8, cy - outer_r + 8, cx + outer_r - 8, cy + outer_r - 8],
              outline=(*PLATINUM, 86), width=4)
    if not precise:
        d.arc([cx - outer_r + 8, cy - outer_r + 8, cx + outer_r - 8, cy + outer_r - 8],
              24, 146, fill=(230, 234, 240, 54), width=3)
    return layer


def pm1_lip_arc(size, center, color, alpha):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer, "RGBA")
    x, y = center
    radius = 82
    box = [x - radius, y - radius, x + radius, y + radius]
    light = tuple(min(255, c + 24) for c in color)
    dark = tuple(max(0, int(c * 0.4)) for c in color)
    # PM1-like material catch: partial pigment on the visible lip, not a full UI circle.
    d.arc(box, 198, 340, fill=(*dark, int(alpha * 0.65)), width=5)
    d.arc(box, 214, 322, fill=(*color, alpha), width=3)
    d.arc(box, 28, 92, fill=(*light, int(alpha * 0.35)), width=2)
    return layer


def pm1_inset_ring(size, center, color, radius, width, alpha):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer, "RGBA")
    x, y = center
    box = [x - radius, y - radius, x + radius, y + radius]
    dark = tuple(max(0, int(c * 0.38)) for c in color)
    light = tuple(min(255, c + 22) for c in color)
    # Continuous but very thin inlay. No clipping, so it cannot look chipped.
    # Radius is smaller than PM1's visible rim, so the line sits in the basin lip.
    d.ellipse(box, outline=(*dark, int(alpha * 0.55)), width=width + 1)
    d.ellipse(box, outline=(*color, alpha), width=width)
    d.arc(box, 25, 142, fill=(*light, int(alpha * 0.32)), width=max(1, width - 1))
    d.arc(box, 205, 338, fill=(0, 0, 0, int(alpha * 0.38)), width=width + 1)
    return layer


def label_image(src: Image.Image, label: str, name: str):
    img = src.convert("RGB")
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
    draw.text((120, 20), name, fill=GOLD, font=font_small)
    return out


def make(label: str, name: str, *, ring_radius: int, ring_width: int, ring_alpha: int, center_variant: str, clipped: bool = False):
    img = Image.open(SRC).convert("RGBA")
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))

    for center, color in WELLS:
        if clipped:
            layer = clipped_ring(img, center, ring_radius, color, ring_width, ring_alpha, int(ring_alpha * 0.42))
        else:
            layer = subtle_ring(img.size, center, ring_radius, color, ring_width, ring_alpha, int(ring_alpha * 0.42))
        overlay.alpha_composite(layer)
    overlay.alpha_composite(center_pot(img.size, center_variant))

    out = Image.alpha_composite(img, overlay)
    RAW.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    raw_path = RAW / f"{label}.png"
    art_path = ART / f"{label}.png"
    out.convert("RGB").save(raw_path, quality=95)
    label_image(out, label, name).save(art_path, quality=95)
    print("RAW:", raw_path)
    print("ART:", art_path)


def make_arc_variant(label: str, name: str, *, alpha: int, center_variant: str):
    img = Image.open(SRC).convert("RGBA")
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for center, color in WELLS:
        overlay.alpha_composite(pm1_lip_arc(img.size, center, color, alpha))
    overlay.alpha_composite(center_pot(img.size, center_variant))
    out = Image.alpha_composite(img, overlay)
    RAW.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    raw_path = RAW / f"{label}.png"
    art_path = ART / f"{label}.png"
    out.convert("RGB").save(raw_path, quality=95)
    label_image(out, label, name).save(art_path, quality=95)
    print("RAW:", raw_path)
    print("ART:", art_path)


def make_center_only(label: str, name: str, *, center_variant: str):
    img = Image.open(SRC).convert("RGBA")
    overlay = center_pot(img.size, center_variant)
    out = Image.alpha_composite(img, overlay)
    RAW.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    raw_path = RAW / f"{label}.png"
    art_path = ART / f"{label}.png"
    out.convert("RGB").save(raw_path, quality=95)
    label_image(out, label, name).save(art_path, quality=95)
    print("RAW:", raw_path)
    print("ART:", art_path)


def make_inset_variant(label: str, name: str, *, radius: int, width: int, alpha: int, center_variant: str, precise_center: bool = False):
    img = Image.open(SRC).convert("RGBA")
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for center, color in WELLS:
        overlay.alpha_composite(pm1_inset_ring(img.size, center, color, radius, width, alpha))
    overlay.alpha_composite(center_pot(img.size, center_variant, precise=precise_center))
    out = Image.alpha_composite(img, overlay)
    RAW.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    raw_path = RAW / f"{label}.png"
    art_path = ART / f"{label}.png"
    out.convert("RGB").save(raw_path, quality=95)
    label_image(out, label, name).save(art_path, quality=95)
    print("RAW:", raw_path)
    print("ART:", art_path)


def main():
    make("PM23", "PM1 True Edit A", ring_radius=83, ring_width=4, ring_alpha=72, center_variant="normal")
    make("PM24", "PM1 True Edit B", ring_radius=82, ring_width=5, ring_alpha=90, center_variant="deep")
    make("PM25", "PM1 True Edit C", ring_radius=81, ring_width=3, ring_alpha=58, center_variant="small")
    make("PM26", "PM1 Lip Edit A", ring_radius=76, ring_width=4, ring_alpha=92, center_variant="normal", clipped=True)
    make("PM27", "PM1 Lip Edit B", ring_radius=73, ring_width=3, ring_alpha=76, center_variant="deep", clipped=True)
    make("PM28", "PM1 Lip Edit C", ring_radius=78, ring_width=3, ring_alpha=62, center_variant="small", clipped=True)
    make_center_only("PM29", "PM1 Center Only", center_variant="deep")
    make_arc_variant("PM30", "PM1 Lip Arcs A", alpha=72, center_variant="deep")
    make_arc_variant("PM31", "PM1 Lip Arcs B", alpha=48, center_variant="normal")
    make_inset_variant("PM32", "PM1 Clean Inlay A", radius=72, width=3, alpha=82, center_variant="deep")
    make_inset_variant("PM33", "PM1 Clean Inlay B", radius=70, width=2, alpha=66, center_variant="normal")
    make_inset_variant("PM34", "PM1 Clean Inlay C", radius=74, width=3, alpha=58, center_variant="small")
    make_inset_variant("PM35", "PM1 Center Fixed A", radius=72, width=3, alpha=82, center_variant="deep", precise_center=True)
    make_inset_variant("PM36", "PM1 Center Fixed B", radius=70, width=2, alpha=66, center_variant="normal", precise_center=True)
    make_inset_variant("PM37", "PM1 Center Fixed C", radius=74, width=3, alpha=58, center_variant="small", precise_center=True)


if __name__ == "__main__":
    main()
