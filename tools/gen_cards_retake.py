#!/usr/bin/env python3
"""Poch 1441 - Karten-Retakes nach Tobsi-Feedback (8.7.2026).

Fixes:
- Ass Herz/Karo: Stil-Referenz = Ass Pik (monochrom, filigree, kein Rahmen)
- Dame Karo: weißer BG → warmes Beige mit Vignette
- Bube Kreuz: orientalischer Prinz → europäischer Renaissance-Bursche
- Alle Chars: suit-Farbe NUR in Kleidung, nicht Hintergrund
"""
import json, os, time
from pathlib import Path
import replicate

ROOT = Path("/Users/tobsi/poch1441")
RAW  = ROOT / "Assets_Raw" / "cards" / "raw"
RAW.mkdir(parents=True, exist_ok=True)
LOG  = ROOT / "Assets_Raw" / "cards" / "retake_log.json"

os.environ["REPLICATE_API_TOKEN"] = \
    Path("~/.config/replicate.key").expanduser().read_text().strip()

NO_TEXT = (", no text, no letters, no numbers, no card corner indicators, "
           "no rank labels, no suit symbols, no UI elements, no borders, "
           "no frame lines, unsigned, no watermark, no signature")

# Basis-Hintergrund für ALLE Charaktere (Tobsi: einheitliche Helligkeit)
CHAR_BG = ("solid muted warm ivory-beige background with a subtle soft vignette, "
           "medium warm brightness consistent across all cards")

# Suit-Farbe NUR in Kleidung/Accessoires, NICHT im Hintergrund
SUIT_CLOTH = {
    "hearts":   "ruby red and rose-gold accents in costume details and jewellery only",
    "diamonds": "warm amber and rose-gold accents in costume details and jewellery only",
    "spades":   "sapphire blue and silver accents in costume details and jewellery only",
    "clubs":    "deep forest green and platinum accents in costume details and jewellery only",
}

CHAR_STYLE = (
    "premium playing card illustration, renaissance oil painting style, "
    "medium shot half-length portrait facing forward, centered composition, "
    "classic 15th century Alsatian court costume, matte gouache illustration quality, "
    "rich detail, symmetrical framing" + NO_TEXT
)

RANK_DESC = {
    "king":  "dignified middle-aged king with a jewelled crown and fur-trimmed royal robe, "
             "authoritative calm gaze, regal bearing",
    "queen": "elegant composed queen with a delicate jewelled crown, graceful poise, "
             "serene and intelligent expression",
    "jack":  "youthful european pageboy with a classic feathered cap, "
             "15th century Alsatian court attire, confident energetic look, "
             "NOT oriental, NOT peacock feathers, classic western european style",
}

# Ass-Stil-Referenz (Tobsi: Ass Pik als Masterpiece-Anker)
ACE_REF = (
    "monochrome ornamental filigree design centered on a cream background, "
    "historical playing card Ace ornament style, single large central motif "
    "with elegant negative space all around, lightweight delicate linework, "
    "no thick borders, no heavy rectangular frames, no full-bleed texture" + NO_TEXT
)

ACE_MOTIF = {
    "hearts":   "single large ornate heart motif, warm rose-red monochrome filigree on cream, "
                "matching the visual weight and delicacy of a classic Ace of Spades",
    "diamonds": "single large ornate diamond rhombus motif, warm amber monochrome filigree on cream, "
                "matching the visual weight and delicacy of a classic Ace of Spades, "
                "no thick gold frames, no heavy borders",
}

RETAKES = [
    # (label, prompt, seed)
    ("ace_hearts",
     f"{ACE_REF}, {ACE_MOTIF['hearts']}",
     14430),
    ("ace_diamonds",
     f"{ACE_REF}, {ACE_MOTIF['diamonds']}",
     14431),
    ("queen_diamonds",
     f"{CHAR_STYLE}, {RANK_DESC['queen']}, {CHAR_BG}, {SUIT_CLOTH['diamonds']}",
     14432),
    ("jack_clubs",
     f"{CHAR_STYLE}, {RANK_DESC['jack']}, {CHAR_BG}, {SUIT_CLOTH['clubs']}",
     14433),
]

log = []
print(f"Retakes: {len(RETAKES)} Karten …")

for label, prompt, seed in RETAKES:
    out_path = RAW / f"{label}_r2.png"  # _r2 = Retake 2
    print(f"  → {label}")
    try:
        output = replicate.run(
            "black-forest-labs/flux-1.1-pro",
            input={
                "prompt": prompt,
                "aspect_ratio": "2:3",
                "output_format": "png",
                "output_quality": 95,
                "seed": seed,
                "safety_tolerance": 2,
            }
        )
        img_data = output.read()
        out_path.write_bytes(img_data)
        log.append({"label": label, "seed": seed, "status": "ok"})
        print(f"    ✓ {len(img_data)//1024} KB")
        time.sleep(0.5)
    except Exception as e:
        print(f"    ✗ {e}")
        log.append({"label": label, "seed": seed, "status": "error", "error": str(e)})

LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False))
print("Fertig.")
