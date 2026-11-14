# Poch 1441 - Verbindlicher Board-Brief

**Stand:** 17. Juli 2026
**Status:** Render-, Implementierungs- und Integrations-Gate

Dieser Brief setzt `tasks/design-canon-2026.md` für Spielfeld und Spielsteine um.
Ältere PM-Nummern und Render sind nur noch Provenienz. Sie definieren weder Form,
Material noch Token.

## 1. Gemeinsame Regelgeometrie

- Exakt neun funktionale Bereiche: acht äußere Gewinnfelder plus eine größere Mitte.
- Außen, im Uhrzeigersinn ab 12 Uhr: `K`, `Q`, `MARIAGE`, `J`, `10`,
  `SEQUENZ`, `POCH`, `A`. Die Reihenfolge entspricht `PochRing.anchors`.
- Keine weiteren Felder, Bonus-Pots, Segmente, Zeiger oder Roulette-Teilungen.
- Jedes Feld nimmt reale Spielsteine vollständig auf. Die Mitte nimmt den Gewinn
  aus Akt 3 auf und ist größer als ein Außenfeld.
- Beschriftungen, Zahlen und Symbole sind lokalisierbare SwiftUI-/Vektor-Ebenen.
  Sie werden nie in KI-Artwork eingebrannt.

Die 8+1-Topologie ist verbindlich. Nur Track A muss kreisförmig sein; Track B darf
eine glaubwürdig improvisierte, unrunde 8+1-Geometrie besitzen.

## 2. Track A - Poch Disc

### Produktidee

Ein herstellbares Designobjekt, das in App und Realität identisch gedacht wird.
Kein historisches Brett, kein Casino-Tray und kein Luxus-Requisit.

### Form und Material

- Nahezu geschlossene, kreisförmige Disc mit präziser, ruhiger Silhouette.
- Satinierter Aluminiumrahmen ohne Chrom- oder Spiegelwirkung.
- Körper in Graphit oder tiefem Nachtblau, matt und fein strukturiert.
- Muldenböden aus hochwertigem Textil, matter Keramik oder einem glaubwürdigen
  Verbundmaterial. Keine Hochglanzschalen.
- Fasen und Hairlines dienen Orientierung und Herstellbarkeit, nicht Dekoration.
- Akzente entstehen durch Materialreflexion. Kein Dauer-Glow, Bloom oder Neon.

### Zielproportionen

Alle Maße beziehen sich auf den Brettdurchmesser `D`.

| Element | Zielwert |
|---|---:|
| Außenmulde, Öffnung | `0,15-0,17 D` |
| Mitte, Öffnung | `0,24-0,27 D` |
| Radius der Außenmittelpunkte | `0,33-0,35 D` |
| Flacher Muldenboden | `0,62-0,70` der Öffnung |
| Reale Tiefe bei `D = 200 mm` | außen `3,5-4,5 mm`, Mitte `4,5-6 mm` |
| Steg zwischen Mulden | mindestens `0,025 D` |

Mulden haben einen flachen Boden und gerundete Wände. Halbkugelförmige Schalen,
Linsen, Knöpfe und Cabochons sind ausgeschlossen.

### Bühne

- Splash, Store und Ergebnis dürfen die Disc auf hellem Sicht- oder Waschbeton mit
  weichem seitlichem Tageslicht zeigen.
- Im wiederholten Gameplay liegt sie auf einem sehr ruhigen, kontrastarmen
  Graphitgrund. Keine sichtbaren Poren, Hotspots oder harten Schlagschatten unter
  funktionalen Informationen.

## 3. Track B - Unterwegs

### Produktidee

Poch entsteht glaubwürdig aus verfügbaren Gegenständen. Die Welt ist warm,
unmittelbar und menschlich, aber weder trashig noch nostalgisch kostümiert.

### Form und Material

- Bevorzugt eine generische transparente oder leicht getönte Servier-/Snackschale
  mit acht Außenfächern und einer Mitte.
- Das Feld darf rund, oval oder organisch segmentiert sein, solange 8+1 eindeutig
  lesbar und regelkonform bleibt.
- Keine reale Marke, Verpackungsgrafik oder Produktkopie.
- Bezeichnungen können wie präzise handbeschriftetes Kreppband aussehen, bleiben
  aber scharfe, lokalisierbare UI-Ebenen.
- Kratzer und Gebrauchsspuren sind plausibel und zurückhaltend. Schmutz,
  künstliche Vintage-Filter und absichtliche Verwahrlosung sind ausgeschlossen.

### Bühne

- Die konkrete Umgebung bleibt bis zum eigenen Vergleichsartefakt eine
  Explorationsfrage.
- Zulässig sind wenige funktionale Hinweise auf einen improvisierten Spielort.
- Laterne, Emaillebecher, Flasche, gefaltete Karte und Camping-Klischees sind keine
  Pflicht und werden nicht gleichzeitig als Requisitenwand eingesetzt.
- Im Gameplay wird eng auf Schale, Karten, Hände und aktuelle Entscheidung
  komponiert; die Umgebung tritt zurück.

## 4. Spielsteine

### Track A - R1

- 36 mm Durchmesser, 3 mm Stärke, gedachtes Gewicht 9 bis 10 g.
- Mattes Clay-Composite oder durchgefärbte Keramik.
- Große tonale Blindprägung des geometrischen Kartenrücken-Signets.
- Feine umlaufende Präzisionsrändelung.
- Naturweiß, Terrakotta, Salbeigrün, Schiefergrau und gedecktes Ocker bilden
  gemeinsam die feste materielle Referenzpalette der Poch Disc. Sie sind keine
  Spieler-, Besitzer- oder Wertfarben und tragen keine verdeckte Information.
- Herkunft wird nur während Quelle-Ziel-Bewegung und am stabilen Sitz gezeigt.
- Kein Stein morpht nach einem Gewinn seine Farbe.
- Ein Wert pro Stein; keine Ziffern, Währungszeichen oder Poker-Edge-Spots.

### Track B - 1-Cent-Münzen

- Ausschließlich 1-Cent-Münzen als gleichwertige Einsatzeinheit.
- Varianten unterscheiden sich kontrolliert in Rotation, Oxidation, Patina,
  Kratzern, Kantenabrieb und Restglanz.
- Keine gemischten Nennwerte und keine Eurobeträge im Interface.

### Lage und Physik

- Endlagen werden deterministisch aus vorbereiteten Slots und Varianten gewählt.
- Kleine Gruppen liegen natürlich, leicht überlappend und nicht wiederholt in
  derselben Rosette.
- Jeder Stein bleibt vollständig innerhalb der Mulde beziehungsweise des Fachs.
- Zwei Schattenebenen zeigen Kontakt und Höhe; nichts schwebt.
- Animation und Endzustand verwenden exakt dasselbe Asset, denselben Maßstab und
  dieselbe Orientierung.
- Sichtbarer Zähler und Haptik ändern sich erst beim Kontakt.
- Der erste Kontakt einer Gruppe trägt das Hauptfeedback: trockenes Keramikklacken,
  kurze glaubwürdige Resonanz und synchroner Taptic-Impuls. Weitere Kontakte bleiben
  akustisch und haptisch untergeordnet. Kein Casino-Chip-Klappern.

## 5. Beschriftung und Lesbarkeit

- Kartenwerte sind international: `A`, `K`, `Q`, `J`, `10`.
- Kombinationen werden in Prosa als `Mariage`, `Sequenz` und `Poch` erklärt.
- Auf dem Brett dürfen kompakte Zeichen stehen, wenn Tutorial und Accessibility
  die vollständige Bedeutung liefern.
- Labels bleiben bei belegtem Feld sichtbar und stehen orthogonal zum Spieler.
- Reine Farbcodierung ist nie die einzige Information.
- Lesegates: `360 px`, `180 px`, `120 px`, `64 px`, iPhone SE, Standard und Pro Max.

## 6. Phasenverhalten

- **Melden:** großes, zentral gesetztes Feld; 8+1-Geometrie und relevante Gewinne
  sind lesbar.
- **Pochen:** dasselbe Objekt wird kleiner, bleibt aber bewusst positioniert. Poch,
  Einsatzwahl und Gegnerentscheidung bilden eine klare Dreierhierarchie.
- **Ausspielen:** das Feld wird ruhiger Hintergrund und die Karten übernehmen die
  Hauptbühne. Die Mitte bleibt räumliches Ziel.
- Phasen verändern Kamera, Maßstab und Fokus, niemals Regelgeometrie oder
  Objektidentität.

## 7. Lernmodus der echten Disc

Es gibt kein separates Tutorialbrett. Die echte Track-A-Disc führt durch vier
reversible Darstellungszustände, ohne Form, Material oder 8+1-Topologie zu wechseln:

1. **Orientieren:** Mitte und genau ein relevantes Außenfeld sind scharf und gut
   beleuchtet. Die übrigen Felder bleiben an ihrer realen Position, treten aber stark
   zurück. Noch keine Gegnerdaten, Einsatzsteuerung oder Aktionsmatrix.
2. **Zusammenhang:** Die passende Handkarte und ihr Feld werden gleichzeitig gezeigt.
   Weitere Felder gewinnen erst bei ihrer Bedeutung Materialkontrast.
3. **Verstehen:** Lokalisierbare UI-Labels und höchstens eine Hairline verbinden
   Quelle, Zielfeld und konkrete Wirkung. Eine einzige Aktion beweist den Satz.
4. **Spielen:** Hairline und Lernlabel verschwinden. Die unveränderte Disc bleibt in
   der regulären Spielkomposition zurück.

Die Lernansicht darf niemals `[VAR_*]`, `BET`, Maße, Konstruktionslinien oder andere
Werkstattnotation zeigen. Sie ist Produkt-UI, keine technische Explosionszeichnung.

## 8. Portrait und Landscape

Die Disc verwendet dieselbe Geometrie und dieselben Assets in beiden Orientierungen.
Nur Maßstab, Kamera und Bühnenposition ändern sich.

- **Portrait, Melden:** Disc groß und zentral, mit sichtbarer Hand am unteren Rand.
- **Portrait, Pochen:** Disc kompakter im oberen Bühnenbereich; Entscheidung und Hand
  erhalten eigene, kollisionsfreie Zonen.
- **Landscape, Melden:** Disc groß auf der rechten beziehungsweise mittleren
  Spielfeldhälfte; Gegner liegen an einer stabilen linken Sitzachse.
- **Landscape, Pochen:** Gegner und Einsatzsteuerung links, Entscheidung mittig, Disc
  rechts, Hand unten. Keine Zone darf eine andere überlagern.
- **Landscape, Ausspielen:** zentrale Kartenkomposition gewinnt Breite; Disc bleibt
  kleiner als räumliches Ziel sichtbar.
- Die Disc darf nie an den rechten Displayrand gequetscht werden. Außenabstand und
  optisches Gewicht müssen links und rechts ausgewogen sein.
- Auf Geräten mit Dynamic Island, Home Indicator oder Landscape-Sensorausschnitt
  richten sich Zonen nach Safe Areas, nicht nach den Rohmaßen des Displays.

## 9. Harte Ausschlusskriterien

Ein Kandidat fällt aus bei:

- nicht exakt acht Außenfeldern plus Mitte;
- Casino-, Roulette-, Spielautomaten- oder generischer Poker-Tray-Lesart;
- Glow, Chrom, Spiegelglas, Hochglanzplastik oder Ornament als Grundzustand;
- KI-Schrift, falschen Kartenwerten oder dekorativen Zusatzfeldern;
- Spielsteinen außerhalb der Zielfläche oder ohne glaubwürdigen Kontakt;
- UI-Informationen, die mit Spielfeld, Karten oder Gegnern kollidieren;
- einer Form, die nur im Hero-Render, aber nicht im wiederholten Spiel funktioniert.

## 10. Abnahme

Jeder Kandidat erhält `0-5` Punkte in:

1. Regelkorrektheit;
2. Spielsteinphysik;
3. Verständlichkeit;
4. Herstellbarkeit;
5. Ergonomie;
6. kleine Lesbarkeit;
7. Anti-Casino-Eigenständigkeit;
8. Markenidentität;
9. Qualität im echten Spielfluss.

Zusätzlich werden alle drei Phasen und alle vier Lernzustände auf mindestens einer
kompakten und einer großen Portrait- sowie Landscape-Größe geprüft. Kein Element darf
abgeschnitten werden, Text ungewollt umbrechen oder Quelle, Ziel und Primäraktion
gleichzeitig verdecken.

Regelkorrektheit, Spielsteinphysik oder Verständlichkeit unter `5` sind ein
Ausschluss und werden nicht durch schöne Materialbilder kompensiert.

## Quellen

- `tasks/design-canon-2026.md` - neueste visuelle Grundlage.
- `tasks/konzept.md` - Produkt, Regeln, Phasen und Positionierung.
- `PochKit/Sources/PochKit/Board.swift` und `App/PochRing.swift` - technische
  Regelgeometrie.
