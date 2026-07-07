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
STAND = "8. Juli 2026, nachts &middot; Wappen/Brett-Runde (W/B/K) + Phase-3-Layout fertig"

JETZT = ("<b>Deine Gestalt-Kritik ist umgesetzt:</b> die X-Runde ist als &bdquo;dieselbe Rad-Gestalt in vier "
         "Materialst&auml;rken&ldquo; archiviert (dein Reviewer hatte recht - dokumentiert als Lesson inkl. "
         "Abbruchregel). Neu unten: <b>Runde 3</b> mit deinen drei Richtungen, alle deterministisch (G-Weg) auf "
         "ruhigem Lack: <b>W1/W2</b> Vertikal-Siegel (Facetten-Raute), <b>B1/B2</b> Brett als flache Pr&auml;gung, "
         "<b>K1</b> Farbe als Rahmen-Signal. Ungeprimter Assoziations-Test pro Kandidat liegt bei - "
         "<b>W2 ist der erste Kandidat mit dem Wunschprofil</b> (&bdquo;Spielkarten, luxuri&ouml;ses Accessoire, "
         "Mysterium&ldquo; - kein Rad, kein Tech). Nebenbei fertig: das <b>Phase-3-Layout (Ausspielen)</b> - "
         "Kaskade 180 ms, Beat-Drop 350 ms, goldener Stopper, Anspielrecht-Signal, live im Simulator verifiziert. "
         "Aktiv wartet nur: dein R&uuml;cken-Urteil (Runde 3).")

STRANDS = [
    ("done", "Regelwerk / Engine", "PochKit - Gate A, 55 Tests grün", 100),
    ("done", "Design-Kanon", "konzept.md - Kern-Trias, Farbhierarchie, Meta", 95),
    ("work", "Fundament / UI", "Ring, Themes, Material + Phase-2-Layout (Pochen)", 58),
    ("work", "Kunst / Assets", "Charakterstil O registriert; Rücken-Synthese X1-X4 wartet", 44),
    ("plan", "Game-Feel / Animation", "Deal/Meld-Juice, Phasen-Morph, Tells", 4),
    ("plan", "Sound / Haptik", "-", 0),
    ("plan", "Meta-Progression", "Design in §7, Code = 0%", 8),
    ("plan", "Monetarisierung", "StoreKit-2-Unlock 4,99 €", 0),
    ("plan", "Tutorial", "-", 0),
    ("plan", "Lokalisierung 7 Sprachen", "ab erstem String", 0),
    ("plan", "Beta / Release", "TestFlight, App Store", 0),
]
IN_ARBEIT = [
    ("ok", "Phase-3-Layout (Ausspielen): Ketten-Kaskade 180 ms, Beat-Drop 350 ms mit Gold-Stopper, Anspielrecht-Signal, Schiefer-Tokens, Rundenende-Banner - live verifiziert (-autoLead-QA)"),
    ("ok", "Rücken-Runde 3 (deine Richtungen): W1/W2 Siegel-Raute, B1/B2 Brett-Prägung, K1 Kanten-Farbe - deterministisch + ungeprimt getestet"),
    ("ok", "Phase-2-Layout (Pochen) + Charakterstil-O-Registrierung (Vorrunde)"),
    ("", "Phasen-Morph-Transitionen (.matchedGeometryEffect) - läuft als Nächstes"),
    ("", "Clean Karten-Vorderseiten (code-gerendert) - danach"),
    ("", "Feel-Polish P2/P3 (Slider-Materialität, Eiszeit-Vakuum, Straf-Strom) - Game-Feel-Pass"),
]

REGISTRIERT = [
    ("7.7.", "Rücken-Runde X (Synthese)", "VERWORFEN (deine Gestalt-Analyse): geschlossener Farbkreis = Rad, egal welches Material; X4 = Marke wegoptimiert. Runde 3 (W/B/K) beauftragt + Abbruchregel dokumentiert."),
    ("7.7.", "Charakter-Render-Stil", "O (Öl/Gouache painterly) - MIT Auflagen: Pflicht-Paintover pro Porträt, V bleibt Konsistenz-Fallback bis painterly über 1 Charakter x alle Emotionen bewiesen, Anker/LoRA. Garderobe-Test künftig entkoppelt vom Stil-Test."),
    ("7.7.", "Kartenrücken A", "VERWORFEN (dein Befund): gebürstetes Radial-Metall + Chrom-Dom = Roulette/Casino-Read. Marken-Logik bleibt, Synthese X beauftragt."),
    ("7.7.", "Kartenrücken nötig?", "Ja - Trumpf-Beat zeigt jede Runde 31 Rücken, Gegner-Hände, Cosmetic-Anker, Marke."),
    ("7.7.", "Auslieferungsweg Sichtungen", "Keine ZIPs mehr - alles ins Cockpit-HTML einbetten und öffnen."),
    ("6.7.", "Kartenindizes", "International A/K/Q/J/10 auf Karten + Ring; deutsche Prosa Dame/Bube."),
    ("6.7.", "Kern-Trias Feel-Specs", "Phase 1 (Melden), 2 (Pochen), 3 (Ausspielen) finalisiert + freigegeben."),
    ("6.7.", "Phasen-Morph + Präsenz", "Drei Akte, eine Bühne + Ansatz C (Kardinalpunkte-Kollaps)."),
    ("6.7.", "Style-Anker", "Clean-digitaler Mockup-Look; ohne All-in, Spielhalle, Cyber-Namen, Slop."),
]

# ---- Sichtung 1: Galerie-Daten ---------------------------------------------
WAPPEN_BACKS = [
    ("W1", "Siegel-Raute, 4 Quadranten", "Vertikale Achse killt die Rotation. Ungeprimt: Luxusartikel, Casino (Rest: helle Karo-Quadranten lesen Kartensymbol), Rollenspiel", False),
    ("W2", "Siegel-Raute, facettiert", "Fabergé-Querschnitt: dunklere Innen-Facetten, mehr Tiefe. Ungeprimt: SPIELKARTEN, luxuriöses Accessoire, MYSTERIUM - das Wunschprofil, kein Rad, kein Tech", True),
    ("B1", "Brett-Prägung, gefüllt", "Die echte Mulden-Geometrie flach intarsiert, großer Mitte-Pott. Ungeprimt: Smartwatch-Menü, Luxusauto-Bedienfeld - kein Rad, aber Tech-Drift", False),
    ("B2", "Brett-Prägung, Hairline", "Konturen statt Füllung. Ungeprimt: Smartwatch-Interface, Luxus-Kreditkarte - ruhig, aber Tech-Drift", False),
    ("K1", "Farbe als Rahmen-Signal", "Zentrum bleibt Material, Juwelen leben an der Kante. Ungeprimt: Luxus-Lederwaren, exklusive Lobbys - garantiert kein Rad, aber marken-leise", False),
]
SYNTH_BACKS = [
    ("X1", "Segment-Ring auf Prägung", "Volle Marken-Präsenz (Brett als Signet, Farbe=Label). Premium 9 · Ikonisch 8 - ABER ungeprimter Test: Rouletterad in den Top-3-Assoziationen (Treiber: gefüllte Farbsegmente + konzentrischer Grund)", False),
    ("X2", "Linien-Ring auf Prägung", "Feine Arcs statt Füllung - eleganter, aber der Prägungs-Grund wirkt als Radkranz-Echo: Casino-frei nur 3/10", False),
    ("X3", "Segment-Ring auf Lack", "Gleicher Ring auf ruhigem Leder-Lack - der Roulette-Read bleibt (Beleg: die Füllung ist der Treiber, nicht der Grund)", False),
    ("X4", "Signet-Größe, feine Linien", "G-Komposition in Marken-Farben: klein, ruhig, casino-frei bestätigt (ungeprimt: Smartwatch/High-End-Interface). Trade-off: liest eher Tech-Signet als Ornament-Rücken", True),
]
BACKS = [
    ("A", "Mulden-Ring", "VERWORFEN (dein Befund 7.7.): Radial-Metall + Chrom-Dom = Roulette/Lünetten-Read. Konzept lebt in X1-X4 weiter", False),
    ("B", "Guilloché", "Uhrwerk-Gravur als Gold-Mandala. Gemini 7/6 - feine Linien geraten etwas weich", False),
    ("C", "Schockwelle", "Der Poch-Schlag als Prägung: schwarz-auf-schwarz Ringe + ein Goldring. Gemini 9/7", False),
    ("D", "Juwel-Marketerie", "Rauten-Intarsien in 5 Juwelentönen. Gemini 6/5 - unruhigster Kandidat", False),
    ("E", "Art-Deco-Fächer", "Gold-Linien-Fächer, sehr elegant. Gemini 9/8 · GPT-Top-2 (edel, aber generischer)", False),
    ("F", "Rosette 1441", "Abstrakte Platin-Tracery + Juwelen-Punkte - Straßburg-Echo, modern reduziert. Gemini 9/7", False),
    ("G", "Minimal-Signet", "9-Segment-Ring auf leerem Schwarz, deterministisch gezeichnet. Gemini 9/4 (zu still) - Basis von X4", False),
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
p2_src = latest("artifacts/qa/it*-phase2-premium.png") or os.path.join(ROOT,"artifacts/qa/it4-phase2-premium.png")
p2     = b64(scale(p2_src,400,"/tmp/emb/p2.png"))
p3_src = latest("artifacts/qa/it*-phase3-premium.png") or os.path.join(ROOT,"artifacts/qa/it5-phase3-premium.png")
p3     = b64(scale(p3_src,400,"/tmp/emb/p3.png"))

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
    h = ['<div class="decide"><h3>AKTIV &middot; Kartenr&uuml;cken Runde 3 - die Rad-Gestalt aufgebrochen (deine 3 Richtungen)</h3>']
    h.append('<p class="muted">Deine Analyse ist als Lesson dokumentiert: <b>ein geschlossener Farbkreis um ein '
             'Zentrum IST ein Rad</b> - die X-Runde war viermal dieselbe Gestalt in vier Materialst&auml;rken. '
             'Runde 3 bricht die Gestalt statt das Material zu entkernen: <b>W</b> = heraldisches Vertikal-Siegel '
             '(Facetten-Raute, clean-modern, keine Schn&ouml;rkel), <b>B</b> = das Brett als flache Pr&auml;gung '
             '(echte Anker-Geometrie, gro&szlig;er Mitte-Pott bricht die Symmetrie, keine Umfassungslinie), '
             '<b>K</b> = Farbe raus aus dem Kreis (Rahmen-Signal). Alle deterministisch gezeichnet, Grund = ruhiger '
             'Lack. Bei jedem Kandidaten: der ungeprimte Assoziations-Test. <b>Empfehlung: W2</b> - als einziger '
             'liefert er &bdquo;Spielkarten + Mysterium&ldquo; zur&uuml;ck. <b>Abbruchregel (dokumentiert):</b> sitzt '
             'auch diese Runde nicht, wandert das R&uuml;cken-Signet auf ein anderes Marken-Element (Monogramm, '
             '1441-Relief) - der Mulden-Ring bleibt als spielbares Brett unschlagbar.</p><div class="gal">')
    for lb, title, desc, rec in WAPPEN_BACKS:
        img = emb(os.path.join(ROOT, f"artifacts/sichtung1/back-{lb}.png"))
        h.append(gal_item(img, f"{lb} &middot; {title}", desc, rec,
                          f"Antwort kopieren: {lb}", f"Kartenr&uuml;cken: {lb} - ausarbeiten."))
    h.append('</div><div class="copy">'
             '<button onclick="cp(\'Kartenr&uuml;cken: W2 - ausarbeiten (Facetten-Siegel).\')">W2 (Empfehlung)</button>'
             '<button onclick="cp(\'Kartenr&uuml;cken: Abbruchregel ziehen - Signet auf Monogramm/1441-Relief, neue Runde.\')">Abbruchregel ziehen</button>'
             '<button onclick="cp(\'Kartenr&uuml;cken: Mix aus __ und __ - [dein Wunsch].\')">Eigene Antwort (Vorlage)</button>'
             '</div>')
    h.append('<p class="muted" style="margin-top:14px"><b>Runde 2 (X, archiviert):</b> Rad-Gestalt in vier '
             'Materialst&auml;rken - X1/X3 ungeprimt &bdquo;Rouletterad&ldquo;, X4 casino-frei durch Marken-Verzicht '
             '(deine Gegenfallen-Analyse). <b>Runde 1 (A-H):</b> A verworfen (Casino-Read), FLUX-Entgiftungen '
             'drifteten erneut in Slop. B-H bleiben theoretisch w&auml;hlbar:</p><div class="gal">')
    for lb, title, desc, rec in SYNTH_BACKS + BACKS:
        img = emb(os.path.join(ROOT, f"artifacts/sichtung1/back-{lb}.png"))
        h.append(gal_item(img, f"{lb} &middot; {title}", desc, rec,
                          f"Antwort kopieren: {lb}", f"Kartenr&uuml;cken: {lb} ({title}) - ausarbeiten."))
    h.append('</div></div>')

    h.append('<div class="decide"><h3>REGISTRIERT &#10003; &middot; Charakterstil O (&Ouml;l/Gouache painterly) - mit deinen Auflagen</h3>')
    h.append('<p class="muted"><b>Entschieden (7.7. nachts):</b> O gewinnt - Menschlichkeit, Narben, Disco-Elysium-Vibe '
             'als das eine warme Material im cleanen Rahmen. <b>Deine Auflagen sind dokumentiert und bindend:</b> '
             '(1) Pflicht-<b>Paintover</b> pro finalem Portr&auml;t gegen den Midjourney-&Ouml;l-Tell, '
             '(2) <b>V bleibt als Konsistenz-/Slop-Fallback</b> am Leben, bis painterly &uuml;ber einen kompletten '
             'Charakter &times; alle Emotionen bewiesen ist (Konsistenztest VOR Vollproduktion), '
             '(3) Stil-Anker/LoRA f&uuml;r Konsistenz, (4) k&uuml;nftige Stil-Tests mit kanon-konformer Garderobe - '
             'Render-Stil und Kost&uuml;m-Fit werden nicht mehr vermischt, (5) Monogramm fliegt aus dem QA-Scoring. '
             'Referenz-Proben:</p><div class="gal">')
    for lb, title, desc, rec in CHARS:
        img = emb(os.path.join(ROOT, f"artifacts/sichtung1/char-{lb}.png"))
        h.append(gal_item(img, f"{lb} &middot; {title}", desc, rec))
    h.append('</div></div>')
    h.append('<p class="muted">Geparkt: <b>Theme-Held A/B</b> (live am Ende) &middot; <b>Garderobe-Frage</b> - ein '
             'Reviewer forderte periodenechte 1441-Kleidung (Leinen/Wolle); das widerspricht dem Modern-first-Kanon. '
             'Ich baue kanon-konform zeitlos-modern; willst du die 1441-Garderobe, ist das eine Kanon-&Auml;nderung.</p>')
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
    .replace("__P2__",p2)
    .replace("__P3__",p3)
    .replace("<!--STRANDS-->",STRANDS_HTML).replace("<!--INARBEIT-->",INARBEIT_HTML)
    .replace("<!--DECISIONS-->",build_decisions())
    .replace("<!--REGISTRIERT-->",reg_html(REGISTRIERT))
    .replace("__JETZT__",JETZT)
    .replace("__STAND__",STAND))

open(TEMP,"w",encoding="utf-8").write(html)
open(os.path.join(ROOT,"artifacts/poch-1441-cockpit.html"),"w",encoding="utf-8").write(html)
print("Cockpit aktualisiert:", round(len(html.encode('utf-8'))/1024),"KB")
