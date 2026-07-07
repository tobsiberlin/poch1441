#!/usr/bin/env python3
"""Generiert das lebende Cockpit + Kanon-Dokument (poch-1441-cockpit.html).

Wird nach jeder Loop-Iteration erneut ausgeführt: greift automatisch die neuesten
it{N}-Screenshots, bettet Sichtungs-Galerien ein (KEINE ZIPs - Tobsi 7.7.),
aktualisiert Fortschritt/Status und schreibt nach iCloud-TEMP + artifacts/.
Status-Daten stehen oben (STAND, JETZT, STRANDS, ...) - dort pflegen.
"""
import base64, subprocess, os, glob, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMP = "/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/poch-1441-cockpit.html"

# ---- Status (hier pflegen) ------------------------------------------------
STAND = "7. Juli 2026, abends &middot; Sichtung 1 (Kartenr&uuml;cken + Charakterstil) liegt vor"

JETZT = ("<b>Sichtung 1 ist da und QA-gepr&uuml;ft:</b> 8 Kartenr&uuml;cken-Richtungen + 6 Charakter-Stil-Proben, "
         "jede durch gemini-vision (3-Zeilen-Kritik) und GPT-Zweitmeinung gelaufen; 8 Retakes habe ich vorab "
         "selbst aussortiert. <b>Aktiv wartet nur Entscheidung 1 (Kartenr&uuml;cken)</b> - Entscheidung 2 "
         "(Charakterstil) steht direkt darunter bereit, du kannst beide in einer Antwort geben. "
         "Der Loop baut w&auml;hrenddessen das Phase-2-Layout (Pochen) weiter - au&szlig;er deinen zwei "
         "Urteilen wartet nichts auf dich.")

STRANDS = [
    ("done", "Regelwerk / Engine", "PochKit - Gate A, 55 Tests grün", 100),
    ("done", "Design-Kanon", "konzept.md - Kern-Trias, Farbhierarchie, Meta", 95),
    ("work", "Fundament / UI", "Ring, Engine-Bridge, 2 Themes, Material-Craft", 48),
    ("work", "Kunst / Assets", "Sichtung 1 (Rücken + Charakterstil) wartet auf dein Urteil", 40),
    ("plan", "Game-Feel / Animation", "Deal/Meld-Juice, Phasen-Morph, Tells", 4),
    ("plan", "Sound / Haptik", "-", 0),
    ("plan", "Meta-Progression", "Design in §7, Code = 0%", 8),
    ("plan", "Monetarisierung", "StoreKit-2-Unlock 4,99 €", 0),
    ("plan", "Tutorial", "-", 0),
    ("plan", "Lokalisierung 7 Sprachen", "ab erstem String", 0),
    ("plan", "Beta / Release", "TestFlight, App Store", 0),
]
IN_ARBEIT = [
    ("ok", "Sichtung 1: 8 Kartenrücken-Richtungen generiert (FLUX 1.1 Pro + Recraft V3 + 1x deterministisch gezeichnet), QA-gefiltert"),
    ("ok", "Sichtung 1: 6 Charakter-Stil-Proben (Öl/Gouache, Vektor, Stilisiert-3D) x (Nova, Blade), QA-gefiltert"),
    ("ok", "Auslieferung umgestellt: keine ZIPs mehr, alles direkt im Cockpit (deine Ansage, 7.7.)"),
    ("", "Phase-2-Layout (Biet-Slider, Limit-Wand, Poch-Pott, Kardinalpunkte-Präsenz) - läuft jetzt"),
    ("", "Phase-3-Layout + Phasen-Morph-Prototyp (.matchedGeometryEffect) - danach"),
    ("", "Clean Karten-Vorderseiten (code-gerendert) - danach"),
]

REGISTRIERT = [
    ("7.7.", "Kartenrücken nötig?", "Ja - Trumpf-Beat zeigt jede Runde 31 Rücken, Gegner-Hände, Cosmetic-Anker, Marke. Varianten-Sichtung angefordert."),
    ("7.7.", "Auslieferungsweg Sichtungen", "Keine ZIPs mehr - alles ins Cockpit-HTML einbetten und öffnen."),
    ("7.7.", "Charakterstil-Vorgehen", "Erst Visuals sehen - liegt jetzt unten als Entscheidung 2."),
    ("6.7.", "Kartenindizes", "International A/K/Q/J/10 auf Karten + Ring; deutsche Prosa Dame/Bube."),
    ("6.7.", "Kern-Trias Feel-Specs", "Phase 1 (Melden), 2 (Pochen), 3 (Ausspielen) finalisiert + freigegeben."),
    ("6.7.", "Phasen-Morph + Präsenz", "Drei Akte, eine Bühne + Ansatz C (Kardinalpunkte-Kollaps)."),
    ("6.7.", "Style-Anker", "Clean-digitaler Mockup-Look; ohne All-in, Spielhalle, Cyber-Namen, Slop."),
]

# ---- Sichtung 1: Galerie-Daten ---------------------------------------------
BACKS = [
    ("A", "Mulden-Ring", "Die Brett-Signatur als Uhren-Lünette: 8 Juwel-Segmente um Platin-Kern. Gemini 8/6 · GPT-Top-1 (Markenanker)", True),
    ("B", "Guilloché", "Uhrwerk-Gravur als Gold-Mandala. Gemini 7/6 - feine Linien geraten etwas weich", False),
    ("C", "Schockwelle", "Der Poch-Schlag als Prägung: schwarz-auf-schwarz Ringe + ein Goldring. Gemini 9/7", False),
    ("D", "Juwel-Marketerie", "Rauten-Intarsien in 5 Juwelentönen. Gemini 6/5 - unruhigster Kandidat", False),
    ("E", "Art-Deco-Fächer", "Gold-Linien-Fächer, sehr elegant. Gemini 9/8 · GPT-Top-2 (edel, aber generischer als A)", False),
    ("F", "Rosette 1441", "Abstrakte Platin-Tracery + Juwelen-Punkte - Straßburg-Echo, modern reduziert. Gemini 9/7", False),
    ("G", "Minimal-Signet", "9-Segment-Ring auf leerem Schwarz, deterministisch gezeichnet. Gemini 9/4 (zu still: wie Ladeanzeige)", False),
    ("H", "Obsidian-Mandala", "Schwarz-auf-schwarz Blüten-Relief. Gemini 9/7", False),
]
CHARS = [
    ("O1", "Nova · Öl/Gouache", "Painterly, warm, würdevoll. Gemini 9/7 (Premium/Wärme)", True),
    ("O2", "Blade · Öl/Gouache", "Painterly-Richtung, etwas glatter geraten. Gemini 6/7", True),
    ("V1", "Nova · Vektor", "Editorial reduziert - edel, aber kühl. Gemini 9/3", False),
    ("V2", "Blade · Vektor/Tusche", "Wärmste Vektor-Probe. Gemini 7/8", False),
    ("S1", "Nova · Stilisiert-3D", "Uncanny-Risiko bestätigt. Gemini 7/2", False),
    ("S2", "Blade · Stilisiert-3D", "Uncanny-Risiko bestätigt. Gemini 8/3", False),
]

# ---- Helfer -----------------------------------------------------------------
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

def emb(path, maxdim=460):
    return b64(scale(path, maxdim, f"/tmp/emb/{os.path.basename(path)}"))

def gal_item(img_b64, title, desc, rec, button_txt=None, copy_txt=None):
    rechtml = ' <span class="rec">empfohlen</span>' if rec else ""
    btn = (f'<button onclick="cp(\'{copy_txt}\')">{button_txt}</button>'
           if button_txt else "")
    return (f'<div class="g"><img class="big" loading="lazy" onclick="zm(this)" '
            f'src="data:image/png;base64,{img_b64}" alt="{title}">'
            f'<div class="cap"><b>{title}</b>{rechtml}<br>{desc}</div>'
            f'<div class="minirow">Spielgr&ouml;&szlig;e: <span class="minislot"></span></div>{btn}</div>')

def build_decisions():
    h = ['<div class="decide"><h3>AKTIV &middot; Entscheidung 1 - Das Kartenr&uuml;cken-Signet</h3>']
    h.append('<p class="muted">Dein Auftrag: ikonisch, wundersch&ouml;n, real-deck-tauglich - der R&uuml;cken IST die Marke '
             '(Trumpf-Beat, Gegner-H&auml;nde, Cosmetic-Anker). Alle 8 Richtungen sind durch die Gemini-QA (Scores = '
             'Premium/Ikonisch) und die GPT-Zweitmeinung gelaufen. <b>Empfehlung: A (Mulden-Ring)</b> - Markenlogik: '
             'der R&uuml;cken muss &bdquo;Poch 1441&ldquo; sagen, nicht nur &bdquo;Premium&ldquo; (GPT-Top-1 + Kanon &sect;4). '
             'St&auml;rkste Alternativen: <b>E</b> (elegantester) und <b>C</b> (Material-Understatement). '
             'GPT-Warnung f&uuml;r alle: Wirkung bei Spielgr&ouml;&szlig;e pr&uuml;fen - darum die Mini-Vorschau unter jedem '
             'Kandidaten. Klick aufs Bild = Vollbild. Das Monogramm P&middot;1441 ist &uuml;berall ein Vektor-Overlay '
             '(austauschbar), es z&auml;hlt die Fl&auml;chen-Sprache.</p><div class="gal">')
    for lb, title, desc, rec in BACKS:
        img = emb(os.path.join(ROOT, f"artifacts/sichtung1/back-{lb}.png"))
        h.append(gal_item(img, f"{lb} &middot; {title}", desc, rec,
                          f"Antwort kopieren: {lb}", f"Kartenr&uuml;cken: {lb} ({title}) - ausarbeiten."))
    h.append('</div><div class="copy">'
             '<button onclick="cp(\'Kartenr&uuml;cken: Mix aus __ und __ - [dein Wunsch].\')">Eigene Antwort (Vorlage)</button>'
             '<button onclick="cp(\'Kartenr&uuml;cken: keiner davon - neue Runde mit Richtung: [beschreiben].\')">Neue Runde anfordern</button>'
             '</div></div>')

    h.append('<div class="decide"><h3>DANACH &middot; Entscheidung 2 - Der Charakter-Render-Stil</h3>')
    h.append('<p class="muted">Gleiche Proben-Basis pro Richtung: Nova (Mathematikerin) + Blade (Draufg&auml;nger). '
             'Scores = Premium/Charakter-W&auml;rme. <b>Empfehlung: O (&Ouml;l/Gouache painterly)</b> - der Kanon will '
             'die Charaktere als das eine warme Material im cleanen Rahmen; GPT best&auml;tigt, und die W&auml;rme-Scores '
             'sprechen dieselbe Sprache (V = edel aber k&uuml;hl, S = uncanny best&auml;tigt). Die Proben zeigen die '
             '<i>Richtung</i>, nicht die finalen Gesichter - Feinschliff (LoRA/Anker) folgt nach deinem Urteil.</p><div class="gal">')
    for lb, title, desc, rec in CHARS:
        img = emb(os.path.join(ROOT, f"artifacts/sichtung1/char-{lb}.png"))
        h.append(gal_item(img, f"{lb} &middot; {title}", desc, rec))
    h.append('</div><div class="copy">'
             '<button onclick="cp(\'Charakterstil: O - &Ouml;l/Gouache painterly. So bauen.\')">Antwort: O (Empfehlung)</button>'
             '<button onclick="cp(\'Charakterstil: V - reduzierter Vektor.\')">Antwort: V</button>'
             '<button onclick="cp(\'Charakterstil: S - stilisiert-3D.\')">Antwort: S</button>'
             '<button onclick="cp(\'Charakterstil: anders - [beschreiben].\')">Eigene Antwort (Vorlage)</button>'
             '</div></div>')
    h.append('<p class="muted">Geparkt (kein Gate jetzt): <b>Theme-Held A/B</b> - entscheidest du live am Ende, '
             'wenn zwischen Premium-matt und Vivid flippbar.</p>')
    return "".join(h)

def strand_html(s):
    kind,name,sub,pct = s
    return (f'<div class="strand g-{kind}"><div class="name">{name}<small>{sub}</small></div>'
            f'<div class="bar"><i style="width:{pct}%"></i></div><div class="val">{pct}%</div></div>')
def li_html(items):
    return "".join(f'<li class="{c}">{t}</li>' for c,t in items)
def reg_html(rows):
    return "".join(f'<tr><td>{d}</td><td><b>{e}</b></td><td>{u}</td></tr>' for d,e,u in rows)

STRANDS_HTML = "\n  ".join(strand_html(s) for s in STRANDS)
INARBEIT_HTML = li_html(IN_ARBEIT)

TEMPLATE = open(os.path.join(ROOT,"tools/cockpit_template.html"),encoding="utf-8").read()
html = (TEMPLATE
    .replace("__MOCKUP__",mockup).replace("__PREM__",prem).replace("__NEON__",neon)
    .replace("<!--STRANDS-->",STRANDS_HTML).replace("<!--INARBEIT-->",INARBEIT_HTML)
    .replace("<!--DECISIONS-->",build_decisions())
    .replace("<!--REGISTRIERT-->",reg_html(REGISTRIERT))
    .replace("__JETZT__",JETZT)
    .replace("__STAND__",STAND))

open(TEMP,"w",encoding="utf-8").write(html)
open(os.path.join(ROOT,"artifacts/poch-1441-cockpit.html"),"w",encoding="utf-8").write(html)
print("Cockpit aktualisiert:", round(len(html.encode('utf-8'))/1024),"KB")
