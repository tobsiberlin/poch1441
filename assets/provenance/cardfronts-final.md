# Provenance - Kartenvorderseiten „Final-Template" (32 Karten)

**Status:** Aktiv (8.7.2026, Tobsi-Auftrag: „genau wie Mockup, 100% Konsistenz")
**Dateien:** `Assets_Raw/cards/final/*.png` (Master 624x888),
`App/Assets.xcassets/Cards/*.imageset` (@2x 312x444 + @3x 468x666)
**Generator:** `tools/gen_cards_final.py` (deterministisch, reproduzierbar, kein Seed nötig)

## Konstruktion (deterministisch, keine KI-Generierung)
- EINE Vorlage für alle 32 Karten: weiße Karte, Eckradius 8/52 der Breite
  (deckungsgleich mit CardFace-Clip), große fette Eck-Indizes (Helvetica Neue Bold,
  Cap ~12.5% Kartenhöhe) mit Pip darunter, oben-links + unten-rechts (identisches
  Tile, 180° gedreht - Verschiebung mathematisch ausgeschlossen).
- Asse: ein großes zentrales Pip (34% Kartenhöhe, geometrisch zentriert, Beweis
  Pixel-Messung 443.5/444). Zahlkarten 7-10: klassisches Pip-Raster, untere
  Hälfte 180° gedreht. Farben: Rot #E6180A (exakt Quell-Rot), Schwarz #000000.
- Hoffiguren J/Q/K: extrahiert aus htdebeer/SVG-cards (LGPL, bereits im Repo
  `Assets_Raw/svg-cards/svg-cards.svg`) - Basis, Eck-Indizes und Eck-Pips der
  Quelle entfernt (SVG-Chirurgie, Strip-Zählung 1/2/2/2 uniform über alle 12
  verifiziert), Figur inkl. klassischem Rahmen nahezu vollflächig platziert,
  weißes Knockout hinter den Indizes (wie Quelle, nur größer).

## KI-Anteil
- Keiner. Referenz-Mockup (Tobsi, iCloud TEMP 935b2c31) diente nur als
  Layout-Vorgabe für die Vorlagen-Parameter.

## Menschliche Entscheidungsschritte
- Tobsi 8.7.: bisherige Karten „völlig inkonsistent" (Rahmen mal ja/mal nein,
  Indizes zu randnah) → Neuaufbau aus einer Vorlage nach Mockup-Vorbild.
- gemini-vision-QA gegen 32er-Montage: 3 Hauptbefunde als Falschmeldungen
  widerlegt (Pixel-Messung); Font-Empfehlung „Serif" bewusst verworfen -
  Mockup zeigt Bold-Sans, Mockup gewinnt.
