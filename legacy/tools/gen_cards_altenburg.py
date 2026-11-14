#!/usr/bin/env python3
"""Poch 1441 - Bildkarten im Altenburger-Stil (8.7.2026).

Stil-Referenz: Altenburger Blatt (klassisches deutsches Skatkartenspiel).
Eigenständige Interpretation: Holzschnitt-Ästhetik, fette Linienführung,
flache Farbflächen, mittelalterliche Hoffiguren.
Atom-Prinzip: kein Text, keine Eck-Indizes im Bild.
"""
import json, os, time
from pathlib import Path
import replicate

ROOT = Path("/Users/tobsi/poch1441")
RAW  = ROOT / "Assets_Raw" / "cards" / "altenburg"
RAW.mkdir(parents=True, exist_ok=True)
LOG  = ROOT / "Assets_Raw" / "cards" / "altenburg_log.json"

os.environ["REPLICATE_API_TOKEN"] = \
    Path("~/.config/replicate.key").expanduser().read_text().strip()

NO_TEXT = (", no text, no letters, no numbers, no corner indices, no rank labels, "
           "no suit symbols drawn in image, no border lines, no card frame, "
           "unsigned, no watermark, no signature")

# Kern-Stil: Altenburger-inspiriert, eigenständig
STYLE = (
    "traditional German playing card court figure illustration, "
    "inspired by classic Altenburger Skat deck woodcut engraving style, "
    "bold confident black ink outlines, flat clean color fills, "
    "stylized medieval German court figure, full centered portrait composition, "
    "ornamental folk illustration aesthetic, cream white card background, "
    "strong graphic quality, NOT photorealistic, NOT oil painting, "
    "woodcut print tradition, clear readable silhouette"
    + NO_TEXT
)

# Rang-Beschreibungen (Altenburger-konform)
RANK = {
    "king":  ("König", "mature dignified king with ornate crown, holding sword and orb, "
              "fur-trimmed royal mantle, authoritative frontal pose"),
    "queen": ("Dame", "elegant queen with crown, holding flower bouquet or scepter, "
              "flowing gown with decorative trim, composed graceful pose"),
    "jack":  ("Bube", "young courtier with feathered hat, holding lance or sword, "
              "doublet and hose, energetic stance, clean-shaven youthful face"),
}

# Farb-Codierung NUR in Kleidung (nicht Hintergrund)
SUIT_COLOR = {
    "hearts":   "costume accent colors: warm red and rose tones in clothing details",
    "diamonds": "costume accent colors: warm golden amber tones in clothing details",
    "spades":   "costume accent colors: deep blue and silver tones in clothing details",
    "clubs":    "costume accent colors: deep green and black tones in clothing details",
}

SEED_BASE = 14441
jobs = []
idx = 0
for rank_key, (rank_de, rank_desc) in RANK.items():
    for suit in ["hearts", "diamonds", "spades", "clubs"]:
        label = f"{rank_key}_{suit}"
        prompt = f"{STYLE}, {rank_desc}, {SUIT_COLOR[suit]}"
        jobs.append((label, prompt, SEED_BASE + idx))
        idx += 1

log = []
print(f"Generiere {len(jobs)} Bildkarten (Altenburger-Stil) …")
for label, prompt, seed in jobs:
    out_path = RAW / f"{label}.png"
    if out_path.exists():
        print(f"  SKIP: {label}")
        continue
    print(f"  → {label} (seed {seed})")
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
