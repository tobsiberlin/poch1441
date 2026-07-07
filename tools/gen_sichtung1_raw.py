#!/usr/bin/env python3
"""Sichtung 1 (7.7.2026): Kartenrücken-Richtungen A-H + Charakter-Stil-Proben.

Generiert NUR die Roh-Atome (Atom-Prinzip) - Rahmen, Monogramm, Label kommen
im Compositing (gen_sichtung1_composite.py). Log mit Modell/Seed/Prompt je Bild.
Modelle: FLUX 1.1 Pro (Material/painterly/3D), Recraft V3 (Vektor/Linework).
"""
import json, os, sys, time
from io import BytesIO
from pathlib import Path

import replicate
import requests
from PIL import Image

ROOT = Path("/Users/tobsi/poch1441")
RAW = ROOT / "Assets_Raw" / "sichtung1" / "raw"
RAW.mkdir(parents=True, exist_ok=True)
LOG = ROOT / "Assets_Raw" / "sichtung1" / "log.json"

CLEAN = ", unsigned, no watermark, no text, no letters, no numbers, no typography, no logo"

BACK_STYLE = ("premium playing card back artwork, full-bleed symmetrical ornamental design, "
              "warm ink-black background, matte jewel tones, clean modern luxury, "
              "precise crisp detail, subject fully visible")

PORTRAIT_NOVA = ("a composed woman in her 30s with sharp intelligent eyes, sleek dark hair "
                 "pulled back, subtle silver earring, calm analytical expression")
PORTRAIT_BLADE = ("a confident sharp-featured man in his 40s, swept-back dark hair, trimmed "
                  "beard, intense direct gaze, faint knowing smirk")

JOBS = [
    # ---- Kartenrücken A-H (Hochformat 2:3) ----
    ("A", "flux", "2:3", 91441,
     "a perfectly centered circular emblem inspired by a luxury watch bezel: a ring divided "
     "into eight milled metal segments, each segment inlaid with a different matte jewel tone "
     "(matte gold, garnet rose, emerald green, amethyst violet, platinum), around a small "
     "platinum center disc, deep warm ink-black background with very subtle radial brushed "
     "texture, crisp machined edges, soft top light catching the metal rims, " + BACK_STYLE),
    ("B", "flux", "2:3", 91442,
     "an engine-turned guilloche pattern radiating from a small central circular medallion, "
     "fine interwoven engraved lines in dark graphite with delicate matte gold catching the "
     "light, luxury watch dial craftsmanship, fully symmetrical, " + BACK_STYLE),
    ("C", "flux", "2:3", 91443,
     "minimal concentric embossed ripple rings expanding from the center like a shockwave "
     "frozen in metal, matte black-on-black relief, one single thin ring inlaid in matte gold, "
     "extremely restrained, tactile embossed feel, " + BACK_STYLE),
    ("D", "flux", "2:3", 91444,
     "geometric marquetry lattice of small elongated diamond shapes inlaid in five matte jewel "
     "tones (gold, garnet rose, emerald, amethyst, platinum) set into warm ink-black stone, "
     "precise inlay craftsmanship, repeating symmetrical pattern, subtle depth, " + BACK_STYLE),
    ("E", "recraft", "1024x1434", None,
     "symmetrical art-deco sunburst fan geometry, thin elegant matte gold lines on deep "
     "ink-black, layered radiating arcs from the lower center, luxury nineteen-twenties "
     "inspired but reduced and modern, precise linework, " + BACK_STYLE),
    ("F", "recraft", "1024x1434", None,
     "abstract minimal line geometry with the radial symmetry of a rose window: thin platinum "
     "lines forming a circular tracery pattern, tiny jewel-tone dots at the intersections "
     "(gold, garnet, emerald, amethyst), pure flat abstract geometry, no architecture, no "
     "building, no sky, no stars, centered circular composition, " + BACK_STYLE),
    ("G", "flux", "2:3", 91447,
     "a vast empty matte ink-black field with one small centered emblem: a thin platinum line "
     "ring divided into nine segments, a single segment inlaid in subtle matte amethyst, "
     "enormous negative space, scandinavian luxury restraint, " + BACK_STYLE),
    ("H", "flux", "2:3", 91468,
     "a perfectly regular seamless geometric pattern of overlapping thin circles forming "
     "symmetrical interlocking geometry, debossed into matte black lacquer, tone-on-tone "
     "black-on-black shallow relief, no seams, no panels, one hair-thin matte amethyst "
     "accent ring near the center, deep luxury minimalism, " + BACK_STYLE),
    # ---- Charakter-Stil-Proben (1:1) ----
    ("O1", "recraft", "1024x1024", None,
     PORTRAIT_NOVA + ", warm gouache portrait with painterly textured brushwork, visible "
     "paint strokes, muted earthy palette, deep warm shadows, dark brown backdrop, dignified "
     "and human, contemporary game character art, head-and-shoulders composition"),
    ("O2", "flux", "1:1", 71442,
     PORTRAIT_BLADE + ", warm painterly portrait in oil and gouache, visible expressive "
     "brushwork, muted warm palette with deep shadows, dark neutral backdrop, soft window "
     "light, dignified and human, contemporary character design for a premium card game, "
     "head-and-shoulders composition, subject fully visible"),
    ("V1", "recraft", "1024x1024", None,
     PORTRAIT_NOVA + ", reduced expressive portrait, bold clean shapes, minimal facial "
     "features with strong character, restrained muted palette: warm desaturated skin tone, deep charcoal shadows, one single "
     "matte amethyst accent, background is flat near-black warm charcoal, elegant modern "
     "editorial illustration, head-and-shoulders"),
    ("V2", "recraft", "1024x1024", None,
     PORTRAIT_BLADE + ", reduced expressive portrait, bold clean shapes, minimal facial "
     "features with strong character, restrained muted palette: warm desaturated skin tone, deep charcoal shadows, one single "
     "matte garnet accent, background is flat near-black warm charcoal, elegant modern "
     "editorial illustration, head-and-shoulders"),
    ("S1", "flux", "1:1", 71445,
     PORTRAIT_NOVA + ", stylized sculptural 3d character portrait, matte clay-like materials "
     "with subtle warm subsurface glow, soft studio lighting, premium game character bust, "
     "refined not cartoonish, dark neutral backdrop, head-and-shoulders, subject fully visible"),
    ("S2", "flux", "1:1", 71446,
     PORTRAIT_BLADE + ", stylized sculptural 3d character portrait, matte clay-like materials "
     "with subtle warm subsurface glow, soft studio lighting, premium game character bust, "
     "refined not cartoonish, dark neutral backdrop, head-and-shoulders, subject fully visible"),
]


def gen_flux(prompt, aspect, seed):
    inp = {"prompt": prompt + CLEAN, "aspect_ratio": aspect, "output_format": "png",
           "output_quality": 100, "prompt_upsampling": False, "safety_tolerance": 2}
    if seed is not None:
        inp["seed"] = seed
    out = replicate.run("black-forest-labs/flux-1.1-pro", input=inp)
    return out, "black-forest-labs/flux-1.1-pro"


def gen_recraft(prompt, size, style):
    out = replicate.run("recraft-ai/recraft-v3",
                        input={"prompt": prompt + CLEAN, "size": size, "style": style})
    return out, "recraft-ai/recraft-v3"


def fetch(out):
    url = out[0] if isinstance(out, list) else out
    if hasattr(url, "url"):
        url = url.url
    r = requests.get(str(url), timeout=180)
    r.raise_for_status()
    return Image.open(BytesIO(r.content)).convert("RGB")


def main():
    only = set(sys.argv[1:])  # optional: nur bestimmte Labels (Retakes)
    log = json.loads(LOG.read_text()) if LOG.exists() else {}
    for label, model, fmt, seed, prompt in [(j[0], j[1], j[2], j[3], j[4]) for j in JOBS]:
        if only and label not in only:
            continue
        dest = RAW / f"{label}.png"
        if dest.exists() and not only:
            print(f"[{label}] existiert, skip")
            continue
        for attempt in range(3):
            try:
                t0 = time.time()
                if model == "flux":
                    out, mid = gen_flux(prompt, fmt, seed)
                else:
                    # Replicate-Wrapper kennt kein vector_illustration (Schema geprueft 7.7.)
                    style = "digital_illustration/2d_art_poster" if label == "V1" \
                        else "digital_illustration"
                    out, mid = gen_recraft(prompt, fmt, style)
                img = fetch(out)
                img.save(dest)
                log[label] = {"model": mid, "seed": seed, "prompt": prompt + CLEAN,
                              "format": fmt, "date": "2026-07-07"}
                print(f"[{label}] ok ({img.size[0]}x{img.size[1]}, {time.time()-t0:.0f}s)")
                break
            except Exception as e:
                msg = str(e)
                if "insufficient credit" in msg.lower() or "payment" in msg.lower():
                    print("!!! REPLICATE-GUTHABEN ERSCHÖPFT - Abbruch (Instrument down != weiter)")
                    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False))
                    sys.exit(2)
                print(f"[{label}] Fehler V{attempt+1}: {msg[:200]}")
                time.sleep(4)
        else:
            print(f"[{label}] FEHLGESCHLAGEN nach 3 Versuchen")
    LOG.write_text(json.dumps(log, indent=2, ensure_ascii=False))
    print("Log:", LOG)


if __name__ == "__main__":
    main()
