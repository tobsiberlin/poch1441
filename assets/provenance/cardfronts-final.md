# Provenance - Kartenvorderseiten „Final-Template" (32 Karten)

**Status:** Eingeloggt / final aktiv (8.7.2026, Tobsi-Freigabe: „perfekt!
einlocken!")
**Dateien:** `Assets_Raw/cards/final/*.png` (Master 624x888),
`App/Assets.xcassets/Cards/*.imageset` (@2x 312x444 + @3x 468x666)
**Generator:** `tools/gen_cards_vector_public_domain.py` (deterministisch,
reproduzierbar, kein KI-/Sheet-Slicing)
**Quelle:** `Assets_Raw/vector-playing-cards/cards-svg/*.svg`, Public Domain /
WTFPL laut `Assets_Raw/vector-playing-cards/README.md`, Original: Byron Knoll

## Konstruktion (deterministisch, keine KI-Generierung)
- Quelle sind 32 einzelne Public-Domain-SVGs, kein KI-Sheet und kein Slicing.
- Das originale Kartenlayout bleibt erhalten: Werte, Suit-Pips, Zahlkarten,
  Asse und Hofkarten werden nicht mit einem zweiten Label übermalt.
- Eigene Poch-Kartenbasis: klares Weiss, App-Eckradius, mehr Rand-Padding als
  die Quelle. Die originale weisse SVG-Basis wird entfernt, damit kein
  Karte-in-Karte-Rand entsteht.
- Ecktypografie wird in der SVG-Stufe verstaerkt: groesser, bold, Helvetica
  Neue/Arial-Fallback. Kein Overlay.
- Farbgrading: Gelb -> mattes Gold, Royalblau -> Graphit/Navy, Rot -> Rubinrot
  `#D93650`, Grau -> kuehleres Off-White.
- Rote Asse bleiben im originalen Design, aber der zentrale rote As-Verlauf wird
  gezielt gegen Blässe geboostet.
- Kartenstock-Finish: reines Weiss mit sehr dezenter Leinen-/Air-Cushion-
  Mikrostruktur und minimaler Wölbungs-Schattierung. Kein Gelbstich, kein Grunge.
- Sichtbare Kartenwölbung und Schatten bleiben UI-/Shader-Aufgabe in
  `CardFace`, nicht hart ins PNG gebacken.

## KI-Anteil
- Keiner. Referenz-Mockup (Tobsi, iCloud TEMP 935b2c31) diente nur als
  Layout-Vorgabe für die Vorlagen-Parameter.

## QA
- `tools/gen_card_fronts_qa.py` erzeugt `artifacts/sichtung-karten-franzoesisch.html`.
  Die HTML-Datei referenziert speicherarm direkt die App-Assets.
- `artifacts/card-vector-intermediate-8x4.png` ist die aktuelle Kontrollmontage.
- `artifacts/card-vector-styled-8x4.png` und `artifacts/card-qa-8x4.png` sind
  ältere Kontrollmontagen: Zeilen =
  Pik/Herz/Kreuz/Karo, Spalten = A/K/Q/J/10/9/8/7.

## Menschliche Entscheidungsschritte
- Tobsi 8.7.: KI-/Sheet-Ansätze verworfen. Professioneller Weg:
  freies, sauberes SVG-Kartendeck aus dem Netz als Basis.
- Tobsi 8.7.: Zwischenstand mit originalem SVG-Layout bevorzugt; übermalte
  Bold-Indizes verworfen.
- Tobsi 8.7.: mehr Rand-Padding, saftigeres Rot, rote Asse weniger blass,
  Ecktypografie groesser/fetter.
- Tobsi 8.7.: finaler Stand freigegeben: „perfekt! einlocken!"
