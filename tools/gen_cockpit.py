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
STAND = "8. Juli 2026, sp&auml;t &middot; Phasen-Morph l&auml;uft (QA 9/9, 8/7) &middot; W2 final &middot; als N&auml;chstes: Karten-Vorderseiten"

JETZT = ("<b>Der Phasen-Morph steht:</b> die drei Akte sind jetzt eine B&uuml;hne - Tokens fliegen von der "
         "Top-Bar an die Kardinalpunkte und weiter in die Schiefer-Reihe, die Poch-Mulde l&ouml;st sich aus dem "
         "Ring und w&auml;chst zum Pott (Signatur-Flug &sect;5b), die Mulden konvergieren zu Echo-Dots. "
         "Bewegungs-QA vor dem Commit: Morph 1 = Kontinuit&auml;t 9/10 + Premium 9/10, Morph 2 = 8/10 + 7/10 "
         "(Befunde f&uuml;r den Feel-Pass notiert). Das neue taste-gate lief als Erst-Check: sein FAIL zeigt exakt "
         "die bekannten Platzhalter - die <b>clean Karten-Vorderseiten sind gerade im Bau</b> (Elfenbein-Karton, "
         "Serif-Indizes, punktsymmetrischer Zweit-Index). Deine <b>F&auml;cher-Wette ist entschieden und umgesetzt</b> "
         "(Details unten). Deine zwei Umsetzungs-To-dos sind verankert (Vektor-Monogramm in der App immer "
         "crisp, Schatten-x-Kerzenlicht-Check am SpriteKit-Tisch im Game-Feel-Gate). "
         "F&uuml;r dich zu tun: Monogramm-Urteil (B) + Kessel-Runde oben.")

STRANDS = [
    ("done", "Regelwerk / Engine", "PochKit - Gate A, 55 Tests grün", 100),
    ("done", "Design-Kanon", "konzept.md - Kern-Trias, Farbhierarchie, Meta", 95),
    ("work", "Fundament / UI", "Ring, Themes, Material + Phase-2-Layout (Pochen)", 58),
    ("work", "Kunst / Assets", "Kartenrücken W2 final (Freeze); Charakterstil O registriert", 52),
    ("work", "Game-Feel / Animation", "Phasen-Morph steht (QA 9/9, 8/7); Juice-Pass folgt", 22),
    ("plan", "Sound / Haptik", "-", 0),
    ("plan", "Meta-Progression", "Design in §7, Code = 0%", 8),
    ("plan", "Monetarisierung", "StoreKit-2-Unlock 4,99 €", 0),
    ("plan", "Tutorial", "-", 0),
    ("plan", "Lokalisierung 7 Sprachen", "ab erstem String", 0),
    ("plan", "Beta / Release", "TestFlight, App Store", 0),
]
IN_ARBEIT = [
    ("ok", "Phasen-Morph: matchedGeometryEffect über alle drei Akte, Bewegungs-QA 9/9 und 8/7 (Frame-Serien, Feel-Regel)"),
    ("ok", "Phase-3-Layout: Kaskade 180 ms, Beat-Drop 350 ms, Gold-Stopper - live verifiziert"),
    ("ok", "Rücken-Runde 3 (deine Richtungen): W1/W2 Siegel-Raute, B1/B2 Brett-Prägung, K1 Kanten-Farbe - deterministisch + ungeprimt getestet"),
    ("ok", "Phase-2-Layout (Pochen) + Charakterstil-O-Registrierung (Vorrunde)"),
    ("", "Clean Karten-Vorderseiten (Premium-Material statt weißer Platzhalter) - läuft jetzt"),
    
    ("", "Feel-Polish P2/P3 (Slider-Materialität, Eiszeit-Vakuum, Straf-Strom) - Game-Feel-Pass"),
]

REGISTRIERT = [
    ("8.7.", "Fächer-Wette (Kanten-Mechanik)", "Tobsis Hypothese gewinnt: Kontaktschatten + Graphit-Hairline schlägt Farbrand (WK2 verworfen, letzter Platz). W2-Facette bleibt Freeze; Graphit-Kante in Master + CardBack.swift, Schatten = Render-Eigenschaft."),
    ("7.7.", "Kartenrücken FINAL", "W2 Facetten-Siegel - Asset-Freeze per Exekutions-Befehl. Auflagen erfüllt: Punktsymmetrie (Pixel-Beweis 0/0/0), crisp Vektor-Monogramm, Engine-Branding (CardBack.swift aus DesignTokens), Provenance-Sidecar. Restrisiken (Karo-As, Spielgröße) dokumentiert -> Tisch-Test."),
    ("7.7.", "Rücken-Runde X (Synthese)", "VERWORFEN (deine Gestalt-Analyse): geschlossener Farbkreis = Rad, egal welches Material; X4 = Marke wegoptimiert. Runde 3 (W/B/K) brachte W2."),
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
    h = []
    h.append('<div class="decide"><h3>NEU &middot; Kessel-Runde - Zentralmotive mit Poch-Kessel-Anklang (dein Zuruf, 8.7. sp&auml;t)</h3>')
    h.append('<p class="muted">Rezept fix (Schatten + Graphit-Kante + 1441-Signet), nur das Motiv variiert - '
             'stilisiert, punktsymmetrisch konstruiert, Gestalt-Regel beachtet. Ungeprimte Assoziationen: '
             '<b>KA</b> = Tarot/Geheimgesellschaft (Mysterium-Nachbarschaft, kein Kessel-Read), '
             '<b>KB</b> = SPIELKARTE + Klangbild (bestes Profil der Runde), '
             '<b>KC</b> = Spielkarte, aber CASINO-Setting kehrt zur&uuml;ck - raus. '
             '<b>Ehrliches Fazit:</b> keiner schl&auml;gt W2s Profil (&bdquo;Spielkarten + Mysterium&ldquo;) - '
             'die Kessel-Abstraktion verliert den Kessel oder holt das Casino zur&uuml;ck. '
             '<b>Empfehlung:</b> Default bleibt W2; KA/KB wandern als Kandidaten in den '
             'Unlock-Deck-Pool (&sect;7.2 braucht ohnehin mehrere R&uuml;cken).</p><div class="gal">')
    KESSEL = [
        ("back-KA.png", "KA &middot; Kessel-Querschnitt gespiegelt", "Ungeprimt: Tarot, Sci-Fi, Geheimgesellschaft", False),
        ("back-KB.png", "KB &middot; angeschnittene Mulden-B&ouml;gen", "Ungeprimt: Spielkarte, Klangbild - bestes Profil", False),
        ("back-KC.png", "KC &middot; vertikale Mulden-Pr&auml;gung", "Casino-R&uuml;ckfall im ungeprimten Test - raus", False),
        ("faecher-kessel-KA.png", "KA im Schatten-F&auml;cher", "", False),
        ("faecher-kessel-KB.png", "KB im Schatten-F&auml;cher", "", False),
        ("faecher-kessel-W2.png", "Referenz: W2 im Schatten-F&auml;cher", "Der Freeze - weiter die Messlatte", True),
    ]
    for fname, title, desc, rec in KESSEL:
        img = emb(os.path.join(ROOT, f"artifacts/sichtung1/{fname}"), 900)
        rechtml = ' <span class="rec">Messlatte</span>' if rec else ""
        wide = ' style="grid-column:1/-1"' if fname.startswith("faecher") else ""
        h.append(f'<div class="g"{wide}><img class="big" onclick="zm(this)" '
                 f'src="data:image/png;base64,{img}" alt="{title}">'
                 f'<div class="cap"><b>{title}</b>{rechtml}<br>{desc}</div></div>')
    h.append('</div><div class="copy">'
             '<button onclick="cp(\'Kessel-Runde: Default bleibt W2; KA/KB in den Unlock-Pool.\')">W2 bleibt, KA/KB in den Pool (Empfehlung)</button>'
             '<button onclick="cp(\'Kessel-Runde: [KA/KB] als neuer Default ausarbeiten.\')">Kessel-Motiv als Default</button>'
             '<button onclick="cp(\'Kessel-Runde: neue Richtung - [beschreiben].\')">Neue Richtung</button>'
             '</div></div>')

    h.append('<div class="decide"><h3>DEINE NACHPR&Uuml;FUNG &middot; Monogramm-Konstellationen im F&auml;cher (8.7. sp&auml;t)</h3>')
    h.append('<p class="muted">Dein Auftrag: F&auml;cher-Test der Konstellationen <b>P&middot;1441 vs. 1441</b> und '
             '<b>einzeln vs. Paar</b>. Wichtig: im F&auml;cher zeigt jede &uuml;berlappte Karte ihre linke obere Ecke - '
             'das Monogramm wiederholt sich 5x. Befund (Gemini-Ranking D &gt; B &gt; C &gt; A + eigener Zoom-Blick): '
             '<b>1441 schl&auml;gt P&middot;1441 klar</b> (die P-Fassungen sind im F&auml;cher die geschw&auml;tzigsten); '
             '<b>einzeln (D) vs. Paar (B) ist im F&auml;cher praktisch identisch</b>, weil das zweite Signet unten '
             'rechts in der &Uuml;berlappung verschwindet. <b>Empfehlung: B behalten (1441 als Paar, der aktuelle '
             'Final)</b> - gleiche Ruhe wie D, aber der Print-Symmetrie-Beweis bleibt intakt (ein einzelnes Signet '
             'w&auml;re auf dem physischen Deck der Orientierungs-Leak; digital w&auml;re es egal, weil die App '
             'Karten nie gedreht rendert - zwei Master widerspr&auml;chen aber dem Ein-Design-Freeze).</p><div class="gal">')
    FANS = [
        ("faecher-FMA.png", "A &middot; P&middot;1441 als Paar", "Geschw&auml;tzigste Fassung im 5x-Repeat", False),
        ("faecher-FMB.png", "B &middot; 1441 als Paar", "Der aktuelle Final - ruhig, Symmetrie-Beweis intakt", True),
        ("faecher-FMC.png", "C &middot; P&middot;1441 einzeln", "Bricht Print-Symmetrie, kaum ruhiger als A", False),
        ("faecher-FMD.png", "D &middot; 1441 einzeln", "Hauchd&uuml;nn ruhigster - aber Orientierungs-Leak im Print", False),
        ("faecher-mono-zoom.png", "Ecken-Zoom aller 4", "Die 5x-Wiederholungszone im Detail", False),
    ]
    for fname, title, desc, rec in FANS:
        img = emb(os.path.join(ROOT, f"artifacts/sichtung1/{fname}"), 900)
        rechtml = ' <span class="rec">empfohlen</span>' if rec else ""
        h.append(f'<div class="g" style="grid-column:1/-1"><img class="big" onclick="zm(this)" '
                 f'src="data:image/png;base64,{img}" alt="{title}">'
                 f'<div class="cap"><b>{title}</b>{rechtml}<br>{desc}</div></div>')
    h.append('</div><div class="copy">'
             '<button onclick="cp(\'Monogramm: B best&auml;tigt - 1441 als Paar bleibt der Final.\')">B best&auml;tigen (Empfehlung)</button>'
             '<button onclick="cp(\'Monogramm: D - 1441 einzeln, nur digital; Print beh&auml;lt das Paar.\')">D digital / B print</button>'
             '<button onclick="cp(\'Monogramm: anders - [beschreiben].\')">Eigene Antwort</button>'
             '</div></div>')

    h.append('<div class="decide"><h3>WETTE ENTSCHIEDEN &#10003; &middot; Kontaktschatten + Graphit-Kante schl&auml;gt alles (8.7. sp&auml;t)</h3>')
    h.append('<p class="muted"><b>Deine Hypothese hat gewonnen:</b> Ranking <b>4 &gt; 3 &gt; 1 &gt; 2</b> - '
             'Kontaktschatten + neutrale Graphit-Hairline trennt die Karten am besten UND sieht am teuersten aus; '
             'der Juwelen-Farbrand (WK2) landet auf dem letzten Platz und ist VERWORFEN. Bonus-Befund aus Reihe 4: '
             'die <b>W2-Facetten-Raute tr&auml;gt deine Mechanik noch besser als die W1-Quadranten</b> - der Freeze '
             'bleibt also bestehen. Umgesetzt: Graphit-Hairline jetzt in Print-Master + CardBack.swift '
             '(Symmetrie-Beweis erneut [0, 0, 0]); der Kontaktschatten wird Render-Eigenschaft der '
             'F&auml;cher-Darstellung im Spiel (nie ins Asset eingebacken - Lesbarkeits-Licht-Regel).</p><div class="gal">')
    WETTE = [
        ("faecher-wette-R1.png", "1 &middot; reines W2", "verschwimmt - dein Befund best&auml;tigt", False),
        ("faecher-wette-R2.png", "2 &middot; WK2 Farbrand", "trennt farbig, aber Label-Rauschen - letzter Platz, verworfen", False),
        ("faecher-wette-R3.png", "3 &middot; W1 + Schatten + Graphit", "dein Kandidat - Platz 2", False),
        ("faecher-wette-R4.png", "4 &middot; W2 + Schatten + Graphit", "SIEGER - deine Mechanik auf der Freeze-Raute", True),
    ]
    for fname, title, desc, rec in WETTE:
        img = emb(os.path.join(ROOT, f"artifacts/sichtung1/{fname}"), 900)
        rechtml = ' <span class="rec">Sieger</span>' if rec else ""
        h.append(f'<div class="g" style="grid-column:1/-1"><img class="big" onclick="zm(this)" '
                 f'src="data:image/png;base64,{img}" alt="{title}">'
                 f'<div class="cap"><b>{title}</b>{rechtml}<br>{desc}</div></div>')
    h.append('</div><div class="copy">'
             '<button onclick="cp(\'Wette-Ergebnis best&auml;tigt - W2 + Graphit-Kante + Render-Schatten ist final.\')">Ergebnis best&auml;tigen</button>'
             '<button onclick="cp(\'R&uuml;cken-Kante: anders - [beschreiben].\')">Eigene Antwort</button>'
             '</div></div>')
    h.append('</div><div class="copy">'
             '<button onclick="cp(\'R&uuml;cken: WK2 - Rahmen kommt dazu; mit Symmetrie-Paarung ausarbeiten und neu beweisen.\')">WK2 ausarbeiten</button>'
             '<button onclick="cp(\'R&uuml;cken: W2 bleibt rahmenlos - Freeze unver&auml;ndert.\')">W2 rahmenlos bleibt</button>'
             '<button onclick="cp(\'R&uuml;cken: WK1-Richtung - [Anpassung beschreiben].\')">WK1-Richtung</button>'
             '</div></div>')

    h.append('<div class="decide"><h3>REGISTRIERT &#10003; &middot; Kartenr&uuml;cken W2-FINAL - Asset-Freeze (dein Exekutions-Befehl)</h3>')
    h.append('<p class="muted"><b>Alle drei Finalisierungs-Auflagen erf&uuml;llt:</b> '
             '(1) <b>Punktsymmetrie</b> - die 8 Facetten sind konstruktiv gepaart (Facette i = i+4), Grund und Karte '
             'mathematisch symmetrisiert; harter Beweis: <b>Pixel-Diff der 180-Grad-gedrehten Karte = [0, 0, 0]</b> - '
             'kein Orientierungs-Leak (der E-Fehler ist strukturell unm&ouml;glich). '
             '(2) <b>Monogramm crisp</b> - Vektor-Overlay (Didot), 4x supersampled, nie generiert. '
             '(3) <b>Engine-Branding</b> - <code>App/CardBack.swift</code> rendert die Facetten direkt aus den '
             'DesignTokens (Code = Source of Truth der Label-Farben); Print-Master + Provenance-Sidecar eingecheckt. '
             '<b>Dokumentierte Restrisiken</b> (deine Kritik 2): Karo-As-/Luxusartikel-Assoziation und Wirkung bei '
             'Spielgr&ouml;&szlig;e - harter Test am echten Tisch-Layout vor Release (Mini-Vorschau unten gibt den '
             'ersten Eindruck).</p><div class="gal">')
    img_final = emb(os.path.join(ROOT, "artifacts/sichtung1/back-W2.png"))
    h.append(gal_item(img_final, "W2-FINAL &middot; Facetten-Siegel",
                      "Punktsymmetrisch, crisp, eingefroren. Ungeprimt: Spielkarten, Luxus-Accessoire, Mysterium", True))
    for lb, title, desc, rec in WAPPEN_BACKS:
        if lb == "W2":
            continue
        img = emb(os.path.join(ROOT, f"artifacts/sichtung1/back-{lb}.png"))
        h.append(gal_item(img, f"{lb} &middot; {title}", desc, False))
    h.append('</div><p class="muted">Runde 1 (A-H) und Runde 2 (X1-X4) sind archiviert (git + Assets_Raw); '
             'die Gestalt-Lesson (&bdquo;geschlossener Farbkreis = Rad&ldquo;) und die Abbruchregel stehen in '
             'tasks/lessons.md.</p></div>')

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
