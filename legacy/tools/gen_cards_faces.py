#!/usr/bin/env python3
"""Poch 1441 - Kartenvorderseiten-Generierung (Sichtung 2).

Generiert:
- Bildkarten J/Q/K × 4 Farben = 12 Portraits (Atom: kein Text, keine Zahlen)
- Asse × 4 Farben = 4 Ornament-Pips

Atom-Prinzip: Rahmen, Rang-Indizes, Suit-Symbole kommen im SwiftUI-Compositing.
"""
import json, os, time
from pathlib import Path
import replicate, requests

ROOT  = Path("/Users/tobsi/poch1441")
RAW   = ROOT / "Assets_Raw" / "cards" / "raw"
RAW.mkdir(parents=True, exist_ok=True)
LOG   = ROOT / "Assets_Raw" / "cards" / "log.json"

KEY   = Path("~/.config/replicate.key").expanduser().read_text().strip()
os.environ["REPLICATE_API_TOKEN"] = KEY

CLEAN = (", unsigned, no watermark, no text, no letters, no numbers, "
         "no suit symbols, no typography, no logo, no border lines")

CARD_STYLE = (
    "premium playing card illustration, warm ivory cream card background, "
    "traditional court card portrait style, centered half-length figure facing forward, "
    "clean crisp illustration, matte gouache style, symmetrical composition, "
    "rich jewel tones, soft studio lighting, regal period costume details"
    + CLEAN
)

ACE_STYLE = (
    "premium playing card center illustration, warm ivory cream card background, "
    "single large ornate central motif, symmetrical luxury ornament, "
    "clean and bold, no figure, no portrait, matte premium illustration"
    + CLEAN
)

# Rank-Beschreibungen
RANK_DESC = {
    "king":  "a dignified middle-aged king, regal crown, noble robes, authoritative calm gaze",
    "queen": "an elegant composed queen, jewelled crown, graceful poise, serene expression",
    "jack":  "a youthful energetic page, feathered cap, courtly attire, confident look",
}

# Farb-Akzente
SUIT_ACC = {
    "hearts":   "warm ruby red and rose gold accent tones",
    "diamonds": "warm ruby red and rose gold accent tones",
    "spades":   "cool sapphire blue and silver accent tones",
    "clubs":    "deep forest green and platinum accent tones",
}

SEED_BASE = 14410

jobs = []
idx  = 0
for rank in ["king", "queen", "jack"]:
    for suit in ["hearts", "diamonds", "spades", "clubs"]:
        label = f"{rank}_{suit}"
        prompt = f"{CARD_STYLE}, {RANK_DESC[rank]}, {SUIT_ACC[suit]}"
        jobs.append((label, prompt, SEED_BASE + idx))
        idx += 1

# Asse
ACE_MOTIF = {
    "hearts":   "large ornate heart motif, warm rose-gold filigree, centered on ivory, premium luxury",
    "diamonds": "large ornate diamond rhombus motif, warm rose-gold filigree, centered on ivory, premium luxury",
    "spades":   "large ornate spade motif, cool sapphire and silver filigree, centered on ivory, premium luxury",
    "clubs":    "large ornate trefoil club motif, deep green and platinum filigree, centered on ivory, premium luxury",
}
for suit in ["hearts", "diamonds", "spades", "clubs"]:
    label = f"ace_{suit}"
    prompt = f"{ACE_STYLE}, {ACE_MOTIF[suit]}"
    jobs.append((label, prompt, SEED_BASE + idx))
    idx += 1

log = []
print(f"Generiere {len(jobs)} Karten-Assets …")

for label, prompt, seed in jobs:
    out_path = RAW / f"{label}.png"
    if out_path.exists():
        print(f"  SKIP (exists): {label}")
        log.append({"label": label, "status": "skip"})
        continue

    print(f"  → {label} (seed {seed})")
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
        # FileOutput API
        img_data = output.read()
        out_path.write_bytes(img_data)
        log.append({"label": label, "seed": seed, "prompt": prompt, "status": "ok"})
        print(f"    ✓ gespeichert ({len(img_data)//1024} KB)")
        time.sleep(0.5)
    except Exception as e:
        print(f"    ✗ Fehler: {e}")
        log.append({"label": label, "seed": seed, "status": "error", "error": str(e)})

LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False))
print(f"\nFertig. Log: {LOG}")
