# Poch 1441 - Verbindlicher Board-Brief

**Stand:** 10. Juli 2026
**Status:** Render- und Integrations-Gate. PM49 bleibt bis zur ausdrücklichen Freigabe das App-Board.

## 1. Regelgeometrie

- Exakt neun echte Mulden: acht Außenmulden plus eine größere Mittelmulde.
- außen, im Uhrzeigersinn ab 12 Uhr: `K`, `Q`, `MARIAGE`, `J`, `10`,
  `SEQUENZ`, `POCH`, `A`. Diese Reihenfolge entspricht `PochRing.anchors`.
- Keine weiteren Felder, Bonus-Pots, Segmente, Zeiger oder Roulette-Teilungen.
- Jede Mulde ist ein physischer Behälter mit flachem Boden, gerundeter Wand und
  sichtbarer Tiefe. Keine Linse, kein Knopf, kein Cabochon und keine aufgesetzte
  Scheibe.
- Die Mittelmulde ist ruhig, frei von Emblem und etwa 1,55 bis 1,75 mal so breit
  wie eine außenmulde. Sie nimmt den Gewinn aus Akt 3 auf.

## 2. Proportionen und Herstellbarkeit

Alle Maße sind relativ zum Brettdurchmesser `D`, damit dasselbe Objekt als
SwiftUI-Asset und als späteres reales Brett funktioniert.

| Element | Zielwert |
|---|---:|
| außenmulde, Öffnung | `0,15-0,17 D` |
| Mittelmulde, Öffnung | `0,24-0,27 D` |
| Radius der Außenmulden-Mittelpunkte | `0,33-0,35 D` |
| Flacher Muldenboden | `0,62-0,70` der Öffnung |
| Reale Tiefe bei `D = 200 mm` | außen `3,5-4,5 mm`, Mitte `4,5-6 mm` |
| Materialsteg zwischen Mulden | mindestens `0,025 D` |

Der Boden muss Chips flach oder leicht überlappend aufnehmen. Eine
halbkugelförmige Suppenschalen-Geometrie ist ausgeschlossen, weil Chips darin
verkanten und die digitale Stapelkomposition unglaubwürdig wird.

## 3. Material-DNA

- Körper: PM1/PM49-naher, seidenmatter Graphit oder schwarze Keramik mit feiner
  gebürsteter Mikrotextur und realistischen gefrästen Fasen.
- Akzente: haarfeines satiniertes Messing. Kein durchgehender heller Gold-Vollring.
- Muldenlippen: matte mineralische oder emaillierte Materialeinlagen, nie Licht.
- PM49-Achtfarbenfolge:
  - A Gold `#C69A4A`
  - K Bronze/Messing `#A87C3D`
  - Q Granat `#9E3B4E`
  - J Kupfer-Rose `#B06A4E`
  - 10 Bernstein/Ocker `#C08A2E`
  - Mariage Amethyst `#6B5AA6`
  - Sequenz Smaragd `#2E8B6B`
  - Poch Saphir/Petrol `#356B8A`
- Idle: Materialreflexion, Ambient Occlusion und Kontakt-Schatten. Keine Emission,
  kein Bloom, kein Neon und kein Edge-Glow.
- Vivid-Theme: dieselbe Geometrie und dieselben Materialien; nur die
  SwiftUI-Fokusfarbe wird satter. Das Brett wird nicht zu einem anderen Objekt.

## 4. Kartenhinweise und Beschriftung

Historische Pochbretter verbinden die Einsatzfächer mit Kartenfiguren oder
Kombinationen. Diese Regelklarheit wird übernommen, nicht ihre Ornamentik.

- Pro außenmulde genau ein eindeutiger Kartenhinweis: `A`, `K`, `Q`, `J`, `10`,
  `K+Q`, `7-8-9`, Klopf-/Poch-Signet.
- Hinweise sitzen auf dem inneren Steg oder im oberen, von Chips freien Drittel
  der Mulde. Sie dürfen niemals wie ein zehnter Pot wirken.
- KI-Render enthalten keine Schrift, Zahlen oder Logos. Finaler Text und finale
  Symbole sind Vektor-/SwiftUI-Overlays.
- Beschriftung bleibt auch bei belegter Mulde sichtbar. Chips nutzen primär das
  untere Mulden-Drittel.

## 5. Chip-Regel

`PM68 Glass Tokens In Pot` ist die verbindliche Referenz für belegte Mulden.

- Schwere Glas-/Metall-Tokens mit dunklem Kern und fein geriffelter Metallkante.
- Natürliche, leicht überlappende Kleingruppen statt mathematischer Punkte.
- Bis vier sichtbare Tokens: lockere Einzelgruppe. Ab fünf: maximal zwei kleine
  Stapel plus einzelne überlappende Tokens.
- Jeder sichtbare Token bleibt vollständig innerhalb der Muldenlippe.
- Zwei Schattenebenen: harter Kontakt-Schatten direkt unter dem Token und weicher
  Höhenschatten für Gewicht. Keine schwebenden Tokens.
- Animation und Endzustand verwenden dieselben Token-Proportionen und Materialien.

## 6. Kamera und UI-Eignung

- Primärasset: orthografische Top-down-Ansicht, exakt zentriert und radial
  symmetrisch. Keine perspektivische Ellipse.
- Das Brett belegt im Quellbild höchstens 88 Prozent der Breite; transparenter
  oder neutral dunkler Rand ermöglicht Schatten und SwiftUI-Crop.
- Beleuchtung weich von oben, ein kontrolliertes Streiflicht für Fasen. Keine
  dramatischen Hotspots, die Labels oder Chips verschlucken.
- Lesegates bei `360 px`, `180 px`, `120 px` und `64 px`: Silhouette, 8+1-Geometrie
  und Farbfolge müssen erhalten bleiben.

## 7. Phasenverhalten

- Akt 1 Melden: großes Hero-Board. Alle neun Mulden, Kartenhinweise und stehende
  Jackpots sind lesbar.
- Akt 2 Pochen: dasselbe Board kompakt; äußere Mulden entsättigt, Poch-Mulde und
  Poch-Pott bleiben prominent. Keine alternative Boardgrafik.
- Akt 3 Ausspielen: Board wird ruhiges funktionales Backdrop; Mittelmulde bleibt
  Ziel und Kartenfächer-Haltepunkt.
- Phasenwechsel verändern Position, Maßstab und Fokus, nicht die Objektidentität.

## 8. Harte Ausschlusskriterien

Ein Kandidat fällt sofort aus bei:

- nicht exakt acht Außenmulden plus Mitte;
- flacher oder erhabener Mittelknopf statt Mulde;
- Roulette-, Pokerchip-, Lautsprecher-, Objektiv- oder Uhrwerk-Lesart;
- Glow als Grundzustand, Chrom, Spiegelglas oder Hochglanz-Cabochons;
- KI-Schrift, falschen Kartenwerten oder dekorativen Zusatzsymbolen;
- Chips außerhalb der Mulden oder verdeckter Farb-/Wertcodierung;
- inkonsistenter Symmetrie oder nicht herstellbarer Wandstärke.

## 9. Bewertungsmatrix

Jeder Render erhält je `0-5` Punkte in: Regelkorrektheit, Münzphysik,
Mockup-Komposition, PM1/PM49-Materialtreue, Lesbarkeit klein, Anti-Casino,
Herstellbarkeit und Marken-Eigenständigkeit. Regelkorrektheit oder Münzphysik
unter `5` ist ein Ausschluss, kein Mittelwertproblem.

## Quellenanker

- `PochKit/Sources/PochKit/Board.swift` und `App/PochRing.swift` sind die
  verbindliche Produktregel.
- `tasks/konzept.md` definiert Material, Farben, Glow-Budget und Phasen-Morph.
- `PM49` bleibt Style- und App-Anker; `PM68` bleibt Token-Anker.
- Historische Referenz: acht Einsatzvertiefungen mit Kartenfiguren und
  Kombinationen; das Brett ist ein Funktionsobjekt, nicht nur ein Ringmotiv.
