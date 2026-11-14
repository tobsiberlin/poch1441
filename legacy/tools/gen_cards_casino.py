#!/usr/bin/env python3
"""Poch 1441 - Bildkarten Clean Casino Vector Style (8.7.2026).

Visual DNA laut Tobsi:
- Clean vector illustration, standard casino/tournament playing card graphic
- Thin precise ink outlines, flat color fills, minimalistic retro shading
- Bright friendly faces, NO dark shading
- Classic French color palette: Royal Blue + Vibrant Red + Marigold Yellow + Cream BG
- Symmetrical double-ended (Zweiköpfig): figure top + mirrored figure bottom
- Plain cream-white background, no borders, no vignettes, no patterns
- Negative: no text, no letters, no numbers, no corner indices
"""
import json, os, time
from pathlib import Path
import replicate

ROOT = Path("/Users/tobsi/poch1441")
RAW  = ROOT / "Assets_Raw" / "cards" / "casino"
RAW.mkdir(parents=True, exist_ok=True)
LOG  = ROOT / "Assets_Raw" / "cards" / "casino_log.json"

os.environ["REPLICATE_API_TOKEN"] = \
    Path("~/.config/replicate.key").expanduser().read_text().strip()

# Kern-Stil (wird in jeden Prompt eingebaut)
STYLE = (
    "clean vector illustration style, standard casino tournament playing card graphic, "
    "thin precise ink outlines, flat color fills, minimalistic retro shading, "
    "bright clear friendly face, no dark facial shading, "
    "symmetrical double-ended court card layout: "
    "figure in upper half and same figure rotated 180 degrees in lower half, "
    "traditional French playing card style, "
    "color palette strictly: royal blue, vibrant red, bright marigold yellow, cream white only, "
    "solid plain cream-white card background, "
    "no decorative borders, no vignettes, no background patterns, no ornamental frames, "
    "no text, no letters, no numbers, no corner indices, no suit symbols drawn in image, "
    "no watermark, no signature, no dark shadows"
)

# Rang-Figuren (casino-kartentypisch, klar lesbar)
RANK_DESC = {
    "king":  ("König",
              "king figure: crown on head, holding sword in one hand and orb in other, "
              "royal tunic and mantle, friendly dignified expression"),
    "queen": ("Dame",
              "queen figure: elegant crown, holding a flower or small scepter, "
              "graceful gown, serene friendly expression"),
    "jack":  ("Bube",
              "jack figure: feathered cap or hat, holding lance or sword at side, "
              "courtly doublet, youthful friendly energetic expression"),
}

# Farb-Codierung in Kleidung (rot für Herz/Karo, blau/schwarz für Pik/Kreuz)
SUIT_COLOR = {
    "hearts":   "costume primary color: vibrant red tunic with marigold yellow and cream details",
    "diamonds": "costume primary color: vibrant red tunic with marigold yellow and cream details",
    "spades":   "costume primary color: royal blue tunic with marigold yellow and cream details",
    "clubs":    "costume primary color: royal blue tunic with marigold yellow and cream details",
}

SEED_BASE = 14460
jobs = []
idx = 0
for rank_key in ["king", "queen", "jack"]:
    rank_de, rank_desc = RANK_DESC[rank_key]
    for suit in ["hearts", "diamonds", "spades", "clubs"]:
        label = f"{rank_key}_{suit}"
        prompt = f"{STYLE}, {rank_desc}, {SUIT_COLOR[suit]}"
        jobs.append((label, prompt, SEED_BASE + idx))
        idx += 1

log = []
print(f"Generiere {len(jobs)} Bildkarten (Clean Casino Vector) …")
for label, prompt, seed in jobs:
    out_path = RAW / f"{label}.png"
    if out_path.exists():
        print(f"  SKIP: {label}")
        continue
    print(f"  → {label}")
    try:
        output = replicate.run(
            "black-forest-labs/flux-1.1-pro",
            input={"prompt": prompt, "aspect_ratio": "2:3",
                   "output_format": "png", "output_quality": 95,
                   "seed": seed, "safety_tolerance": 2}
        )
        img_data = output.read()
        out_path.write_bytes(img_data)
        log.append({"label": label, "seed": seed, "status": "ok"})
        print(f"    ✓ {len(img_data)//1024} KB")
        time.sleep(0.4)
    except Exception as e:
        print(f"    ✗ {e}")
        log.append({"label": label, "status": "error", "error": str(e)})

LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False))
print("Fertig.")
