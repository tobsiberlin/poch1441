#!/usr/bin/env python3
"""Generiert das lebende Cockpit + Kanon-Dokument (poch-1441-cockpit.html).

Wird nach jeder Loop-Iteration erneut ausgeführt: greift automatisch die neuesten
it{N}-Screenshots, aktualisiert Fortschritt/Status und schreibt nach iCloud-TEMP
+ artifacts/. Status-Daten stehen oben (STAND, STRANDS, IN_ARBEIT) - dort pflegen,
nicht im HTML-Template unten.
"""
import base64, subprocess, os, glob, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMP = "/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/poch-1441-cockpit.html"

# ---- Status (hier pflegen) ------------------------------------------------
STAND = "7. Juli 2026, nachts &middot; Iterationen 1-3 (Material-Fundament) fertig"
STRANDS = [
    ("done", "Regelwerk / Engine", "PochKit - Gate A, 47 Tests grün", 100),
    ("done", "Design-Kanon", "konzept.md - Kern-Trias, Farbhierarchie, Meta", 95),
    ("work", "Fundament / UI", "Ring, Engine-Bridge, 2 Themes, Material-Craft", 48),
    ("work", "Kunst / Assets", "painterly Deck + Gesichter, Integration wartet auf Entscheidung", 30),
    ("plan", "Game-Feel / Animation", "Deal/Meld-Juice, Phasen-Morph, Tells", 4),
    ("plan", "Sound / Haptik", "-", 0),
    ("plan", "Meta-Progression", "Design in §4, kein Code", 8),
    ("plan", "Monetarisierung", "StoreKit-2-Unlock 4,99 €", 0),
    ("plan", "Tutorial", "-", 0),
    ("plan", "Lokalisierung 7 Sprachen", "ab erstem String", 0),
    ("plan", "Beta / Release", "TestFlight, App Store", 0),
]
IN_ARBEIT = [
    ("ok", "Warmes Tinten-Schwarz + Vignette (Iteration 1)"),
    ("ok", "Metallkanten fangen Licht oben statt Dauer-Glow (Iteration 2)"),
    ("ok", "Ring-Linie + Mitte-Pott gefräst, Material-Sprache vereinheitlicht (Iteration 3)"),
    ("", "Glow als Belohnung (Stich, Bluff erkannt) - folgt mit Game-Feel"),
    ("", "Phasen-2/3-Layouts (Pochen, Ausspielen) - nächste grosse Iterationen"),
    ("", "Kartenkunst + Charaktere - warten auf deine 2 Entscheidungen oben"),
]

# ---- Bilder (neueste it{N}-Screenshots automatisch) -----------------------
def latest(pattern):
    files = glob.glob(os.path.join(ROOT, pattern))
    if not files: return None
    def num(f):
        m = re.search(r"it(\d+)-", os.path.basename(f))
        return int(m.group(1)) if m else -1
    return max(files, key=num)

def scale(src, maxdim, out):
    subprocess.run(["sips","-Z",str(maxdim),src,"--out",out],capture_output=True)
    return out
def b64(p): return base64.b64encode(open(p,"rb").read()).decode()

os.makedirs("/tmp/emb", exist_ok=True)
prem_src = latest("artifacts/qa/it*-premium.png") or os.path.join(ROOT,"artifacts/qa/theme-premium.png")
neon_src = latest("artifacts/qa/it*-neon.png") or os.path.join(ROOT,"artifacts/qa/theme-neon.png")
mockup = b64(scale(os.path.join(ROOT,"artifacts/style-ref/mockup-anchor.png"),1100,"/tmp/emb/m.png"))
prem   = b64(scale(prem_src,400,"/tmp/emb/p.png"))
neon   = b64(scale(neon_src,400,"/tmp/emb/n.png"))

def strand_html(s):
    kind,name,sub,pct = s
    return (f'<div class="strand g-{kind}"><div class="name">{name}<small>{sub}</small></div>'
            f'<div class="bar"><i style="width:{pct}%"></i></div><div class="val">{pct}%</div></div>')
def li_html(items):
    return "".join(f'<li class="{c}">{t}</li>' for c,t in items)

STRANDS_HTML = "\n  ".join(strand_html(s) for s in STRANDS)
INARBEIT_HTML = li_html(IN_ARBEIT)

TEMPLATE = open(os.path.join(ROOT,"tools/cockpit_template.html"),encoding="utf-8").read()
html = (TEMPLATE
    .replace("__MOCKUP__",mockup).replace("__PREM__",prem).replace("__NEON__",neon)
    .replace("<!--STRANDS-->",STRANDS_HTML).replace("<!--INARBEIT-->",INARBEIT_HTML)
    .replace("__STAND__",STAND))

open(TEMP,"w",encoding="utf-8").write(html)
open(os.path.join(ROOT,"artifacts/poch-1441-cockpit.html"),"w",encoding="utf-8").write(html)
print("Cockpit aktualisiert:", round(len(html.encode('utf-8'))/1024),"KB")
print("Screenshots:", os.path.basename(prem_src), "/", os.path.basename(neon_src))
