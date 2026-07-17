# Ästhetik-QA-Gate - First Run und Tischwelten

**Stand:** 17. Juli 2026
**Status:** Abnahmeraster; keine automatische Designfreigabe

## Design Read

Poch 1441 ist im First Run ein dunkles, ruhiges Strategieprodukt für neue Spieler.
Die Poch Disc ist der materielle Hauptdarsteller, Gold markiert sparsam Fokus und
Handlung. Die warm-editoriale Produkthülle liefert Hierarchie, großzügige Controls
und ruhige Informationsgruppen. Sie ersetzt nicht die dunkle Material- und
Juwelensprache des Spieltischs.

## Trennung von statischem Gate und menschlicher Abnahme

`tools/qa/audit_visual_contracts.py` darf nur objektive Verträge prüfen:

- 8+1-Reihenfolge und echte Track-A-Disc im First Run;
- vorhandene, lokalisierbare Label-Ebene;
- Bildauflösung für die vorgesehenen Boardgrößen;
- R1-Grundbausteine und First-Run-Nutzung;
- alte Premium-/Neon-/Vivid-Begriffe in aktiven Swift-Dateien;
- erreichbare verworfene Konzeptpfade;
- technische Vollständigkeit von Track B;
- reproduzierbare Risikosignale zu festen Schriftgrößen, Schrumpfung, Text-Alpha
  und Capsule-Dichte.

Der Check bewertet ausdrücklich nicht, ob eine Komposition schön, ausgewogen,
materiell glaubwürdig oder emotional richtig ist. Ein grüner Lauf ersetzt deshalb
niemals die folgende Screenshot-Abnahme.

## Aktuelle belastbare Findings

### Kanon- und Track-B-Status

- Aktiver Code und sichtbares Einstellungsmenü verwenden keine alten
  `Premium`-, `Vivid`- oder `Neon`-Weltnamen mehr. Der PM100-/PM68-Debugpfad ist
  nicht mehr erreichbar.
- Der am 17. Juli geöffnete braune Track-B-Rohentwurf ist ästhetisch verworfen und
  vollständig aus dem sichtbaren sowie ausführbaren Renderer entfernt. Er wird
  weder integriert noch als Ausgangsasset weiterbearbeitet.
- Erhalten bleiben ausschließlich die geprüfte 8+1-Domäne, stabile Fachanker,
  deterministische Münzvarianten und natürliche Endlagen. Bis eine neue Probe die
  Materialabnahme besteht, zeigt das Produkt ausschließlich Track A.
- Die neue v3-Richtung wurde aus der verworfenen Probe neu aufgebaut und anschließend
  in eine leere 8+1-Schale sowie sechs freigestellte 1-Cent-Varianten zerlegt. Die App
  rendert daraus einen dynamischen Zustand; die statische v3-Szene wird nicht referenziert.
- Alpha, transparente Ecken, Chroma-Reste und 64-px-Lesbarkeit der Einzelassets sind
  technisch geprüft. Gemini Vision bewertet Topologie, Transluzenz, Münzmaterial,
  Kontakt und dynamische Belegbarkeit mit `PASS`. Die echte Runtime-Probe besteht
  iPhone SE und iPhone 17 Pro Max jeweils in Portrait und Landscape.
- Die verworfenen PM100-/PM68- und `GameTokenGlass`-Studien sind vollständig aus
  App-Baum, Live-Code und Lokalisierung entfernt; der visuelle Vertragscheck sperrt
  ebenso die Rückkehr der verworfenen Krypta-/Gilde-/Liga-/Prestige-Richtung.

### First Run nach der Lead-Korrektur

- Titel, Erklärung, Ziel, Aktionen und Gegnernamen verwenden semantische
  Dynamic-Type-Stile. Es gibt keinen `minimumScaleFactor` mehr im First Run und
  keine künstliche Landscape-Begrenzung auf `accessibility1`.
- Hana ist ohne zusätzlichen Badge-Stapel größer, gold gerahmt und typografisch
  priorisiert. Noah und Jonas bleiben sichtbar, aber klar sekundär.
- Die drei schwarzen Gegnernamen-Pills und die Zielkapsel wurden entfernt.
  Whitespace, Textgewicht und eine einzige goldene Primäraktion tragen die
  Hierarchie.
- Elf verbleibende feste Schriftgrößen gehören zu Board-Mikrolabels und anderen
  räumlich gebundenen Lernelementen. Vier Text-Alpha-Stellen und fünf
  Capsule-Flächen bleiben bewusste Screenshot-Prüfpunkte.

### Sichtprüfung iPhone SE, Standardtext

Geprüfte Belege:

- `artifacts/integration-20260717/first-run-se-portrait.png`, `750 x 1334 px`;
- `artifacts/integration-20260717/first-run-se-landscape.png`, `1334 x 750 px`.

Bestanden:

- Portrait: klare Blickfolge Marke, Titel, Erklärung, Coach/Gegner, Disc, Ziel,
  Primäraktion und ruhige Sekundäraktion; keine Überlagerung.
- Landscape: vollständige Disc ohne unfertigen Anschnitt, drei getrennte Zonen,
  natürliche Zeilenumbrüche und stabile Gegnerachse.
- Gameplay-Hintergrund bleibt ruhiges Graphit ohne Betonporen. Die Disc ist in
  beiden Orientierungen materieller Hauptdarsteller.
- Zwei SE-UI-Tests mit acht Zustandsbildern und Rotation sind grün. R1- und
  Track-B-Semantik-Vertragstests sowie vollständiger Simulatorbuild sind grün.

Externe Sichtung:

- Gemini Vision bewertet den finalen Portraitbeleg in Hierarchie, Typografie,
  Komposition, Materialwirkung, Verständlichkeit und Gegnerkohärenz jeweils mit
  `PASS`.
- Nach einer gezielten Landscape-Korrektur bewertet Gemini Disc-Crop,
  Zonenbalance, Zeilenumbrüche, Hana-Hierarchie, Primäraktion, Leerraum und
  Overlaps jeweils mit `PASS`.

Noch offen:

- Das Intro bei Accessibility XXXL ist auf iPhone SE in Portrait und Landscape mit
  tatsächlich vergrößerten Textframes, Scroll-Erreichbarkeit und vollständigen
  VoiceOver-Labels belegt. Ab den drei größten Stufen verhindert kürzere lokalisierte
  Sichtcopy Ellipsen, ohne den gesprochenen Volltext zu verkürzen.
- Die Lernbühne bei Accessibility XXXL ist in Portrait interaktiv belegt: Gegner,
  Board, Coach-Aktion und Hand liegen in einer sequenziellen Scrollkomposition ohne
  Überlagerung. Der gleichlautende strenge Landscape-Test bleibt bestehen, konnte
  auf zwei SE-Simulatoren aber nicht ausgeführt werden, weil deren App-Fenster trotz
  bestätigter Geräteorientierung bei `375 x 667` blieb. Das ist kein Landscape-Pass.
- Portrait-Grading und Augenhöhe der drei Gegner bleiben eine spätere gemeinsame
  Asset-Abnahme, obwohl die aktuelle Komposition funktioniert.
- Die 360-/180-/120-/64-px-Disc-Matrix und physisches Klang-/Haptikgefühl auf
  Hardware sind getrennte Abnahmen.

### Track-B-Runtime und extern bestätigte Ausschlusskriterien

Geprüfte Runtime-Belege unter `artifacts/track-b-runtime-20260717/`:

- `final-se-portrait.png` und `final-se-landscape.png`;
- `final-large-portrait.png` und `final-large-landscape.png`;
- `final-board-360.png`, `final-board-180.png`, `final-board-120.png`,
  `final-board-64.png` und `final-board-readability-strip.png`.

Bestanden:

- 8+1-Topologie, transparente Schale, dynamische Münzbelegung und natürliche
  Endlagen ohne Abschneidung auf beiden Geräteklassen und Orientierungen;
- keine Kollision von `EHE`, `FOLGE`, `POCH`, `K`, `Q`, `J`, `A` oder `10` mit
  Wulst oder Münzen nach radialer Labelkorrektur;
- 360 px vollständig lesbar und 180 px brauchbar. Bei 120 px bleiben Topologie und
  Besatz, bei 64 px die unterscheidbare 8+1-Silhouette; den vollständigen Feldnamen
  liefert dort absichtlich Accessibility statt unlesbarer Mikroschrift.

Noch nicht freigegeben sind die produktive Tischwahl nach der ersten Partie,
physischer Münzklang/Haptik auf Hardware sowie die iPad-Matrix.

Gemini Vision bestätigt die Ablehnung der ersten Probe: fehlende Transparenz und
Wandstärke, Plastik- statt Metallmünzen, inkonsistentes Licht, fehlende
Kontakt-AO und 2D-Layering waren die Hauptfehler. Der nächste Entwurf scheitert
automatisch bei einem dieser Punkte:

- Schale ohne sichtbare Fase, Wandstärke, Kantenreflexion und Lichtbrechung;
- Münze ohne Metallreflexion, Kante, glaubwürdige Prägung und individuelle Patina;
- generische braune Verläufe, weiche undefinierte Kanten oder aufgeklebte Kreise;
- unlogische Schatten, fehlende Kontaktverdunklung oder schwebende Stapel;
- Spieltoken-, Pokerchip-, Camping- oder künstlich verwahrloste Anmutung.

## Menschliche Screenshot-Matrix

Jede Zelle wird in Portrait und Landscape geprüft. Ein einzelner Hero-Screenshot
reicht nicht.

| Geräteklasse | Standardtext | Accessibility XXXL | DE | längste EN/FR/IT/ES/NL/PL-Variante |
|---|---:|---:|---:|---:|
| iPhone SE | Intro und Track B bestanden | Intro P/L, Lernbühne P bestanden | DE bestanden | offen |
| iPhone Standard | First-Run-Flow bestanden | offen | DE bestanden | offen |
| iPhone Pro Max | Intro und Track B bestanden | offen | DE bestanden | offen |
| iPad mini | offen | offen | offen | offen |

Pro Zelle werden mindestens diese Zustände belegt:

1. First-Run-Intro;
2. Orientieren;
3. Verbinden mit erster Karte und Trumpf;
4. Beweisen mit Meldung und höchstens einer Hairline;
5. Loslassen als regulär spielbereiter Tisch;
6. Pochen mit Entscheidung, Gegnern, Disc und Hand;
7. Ausspielen mit Kartenfolge als Hauptbühne.

## Board-Lesegates

Für beide Tischwelten werden identische, unverzerrte Boardausschnitte bei
`360 px`, `180 px`, `120 px` und `64 px` exportiert. Jeder Export zeigt einmal ein
leeres und einmal ein realistisch belegtes Feld.

| Gate | Verbindliche menschliche Prüfung |
|---:|---|
| 360 px | Material, Fasen, 8+1-Topologie und alle Labels sofort lesbar; keine dekorative Konkurrenz. |
| 180 px | Außenfelder, Mitte, relevantes Label und Spielsteinlagen bleiben getrennt. |
| 120 px | Feldidentität und aktuelles Ziel bleiben ohne Farbcodierung verständlich. |
| 64 px | Disc beziehungsweise Schale bleibt als 8+1-Spielobjekt erkennbar; Accessibility liefert den vollständigen Namen. |

Zusätzliche Ausschlusskriterien:

- Label wird von Spielsteinen oder Münzen verdeckt;
- Spielstein liegt sichtbar außerhalb seines Felds oder scheint zu schweben;
- Graphitkörper und Mulde laufen zu einer schwarzen Fläche zusammen;
- Aluminium wird als Chrom, R1 als Pokerchip oder 1-Cent als Spielgeld gelesen;
- Track B verwendet gemischte Nennwerte, Eurobeträge, Marke oder Camping-Requisitenwand;
- Betonporen oder harte Hotspots konkurrieren im laufenden Track-A-Gameplay.

## Kompositions- und Typografieabnahme

Eine Aufnahme besteht nur, wenn alle Punkte mit einem konkreten visuellen Beleg
beantwortet werden können:

- Innerhalb von drei Sekunden sind Lernzustand, nächster Schritt und Primäraktion
  in dieser Reihenfolge verständlich.
- Disc, Gegner, Coach, Entscheidung und Hand besitzen getrennte, stabile Zonen.
- Kein sichtbarer Text wird abgeschnitten, unfreiwillig geschrumpft oder durch eine
  einzelne sehr lange Zeile dominant.
- Dynamic Type verändert tatsächlich Schrift und Reflow, nicht nur die Höhe eines
  Scrollcontainers.
- Gegnerporträts teilen Crop, Augenhöhe, Lichttemperatur und Kontrast, ohne ihre
  Individualität zu verlieren.
- Hana liest sich als aktuelle Begleitung, ohne einen zusätzlichen dekorativen
  Badge-Stapel zu erzeugen.
- Eine Primäraktion dominiert; Sekundäraktion und Statusflächen bleiben auffindbar,
  aber ruhig.
- Gold, Amethyst und Smaragd vermitteln Fokus beziehungsweise Phase und sind nie
  die einzige Information.
- Reduce Motion erhält Ursache, Kontakt und Ergebnis ohne räumlichen Sprung.
- VoiceOver folgt derselben semantischen Reihenfolge wie die sichtbare Komposition.

## Abnahmeprotokoll

Für jede geprüfte Aufnahme werden festgehalten:

- Commit, Gerät, Orientierung, Sprache, Dynamic-Type-Stufe und Reduce-Motion-Status;
- Screenshot-Pfad;
- `bestanden` oder `nicht bestanden` je Prüfpunkt;
- ein priorisiertes Finding mit Ort, Wirkung und konkretem Änderungsvorschlag;
- Vergleichsscreenshot nach der Korrektur.

Subjektive 0-5-Wertungen werden erst nach dieser binären Ausschlussprüfung vergeben.
Regelkorrektheit, Spielsteinphysik und Verständlichkeit müssen dabei jeweils `5`
erreichen; schöne Materialbilder können keinen dieser Punkte kompensieren.
