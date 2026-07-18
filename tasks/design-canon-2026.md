# Poch 1441 - Designkanon 2026

**Stand:** 17. Juli 2026
**Status:** verbindliche, neueste Designgrundlage

Dieser Kanon ersetzt alle älteren visuellen Richtungsentscheidungen, soweit sie ihm
widersprechen. Frühere PM-Varianten, Mockups, Render, Materialstudien und
Feel-Spezifikationen sind nur noch Herkunft und Vergleichsmaterial. Sie sind keine
Gestaltungsvorgabe.

Die Spielregeln in PochKit bleiben unberührt und haben bei Regelfragen Vorrang.

## 1. Anspruch

Poch 1441 wird nicht als historisches Brettspiel und nicht als Casino-Spiel
interpretiert. Es ist ein außergewöhnlich hochwertiges Strategieprodukt für 2026,
als wäre Poch heute zum ersten Mal erfunden worden.

Das Qualitätsziel ist ein Produkt mit glaubwürdigem Potenzial für:

- einen Apple Design Award;
- internationale Anerkennung als Referenz für digitale Karten- und Brettspiele;
- ein physisches Produkt in hochwertigen Designstores.

Der Anspruch rechtfertigt keine Effekthascherei. Jede Entscheidung muss mindestens
einen dieser Punkte nachweisbar verbessern:

1. Bedienbarkeit;
2. Verständlichkeit;
3. strategische Spielbarkeit;
4. glaubwürdige Emotion und Spannung.

## 2. Verbindliche Philosophie

| Nicht | Sondern |
|---|---|
| Effekte | Präzision |
| Luxusinszenierung | außergewöhnlich gutes Produktdesign |
| Dekoration | Funktion |
| Lautstärke | Selbstverständlichkeit |
| historisches Kostüm | zeitgenössische Erfindung mit Herkunft |
| Casino- und Gaming-Codes | Werkzeug für strategisches Spielen |

Das Ergebnis ist zeitlos, modern, ruhig, präzise, hochwertig, funktional,
langlebig, physisch glaubwürdig, ergonomisch und sofort verständlich.

Nichts ist zufällig gestaltet. Radius, Fase, Abstand, Animation, Schatten, Farbe,
Typografie, Klang und Haptik brauchen einen funktionalen Grund.

## 3. Entscheidungsfilter

Eine Lösung wird verworfen, wenn mindestens einer dieser Punkte zutrifft:

- Sie sieht nur im Standbild gut aus, verschlechtert aber den Spielfluss.
- Sie braucht eine Erklärung, obwohl die räumliche oder visuelle Logik sie zeigen könnte.
- Sie zitiert Casino, Roulette, Spielautomaten, Poker-UI oder Gaming-RGB.
- Sie simuliert Luxus durch Chrom, Glanz, Glow, Ornament oder Überinszenierung.
- Sie wäre als reales Produkt konstruktiv oder materiell unglaubwürdig.
- Sie konkurriert mit Karten, Spielsteinen, Gegnern oder der aktuellen Entscheidung.
- Sie bricht bei kleiner Darstellung, langen Übersetzungen, VoiceOver oder Reduce Motion.

## 4. Materialität

Materialien werden so eingesetzt, wie ein heutiges Produkt sie glaubwürdig nutzen
würde: präzisionsgefrästes Aluminium, massives Holz, hochwertiges Textil, Keramik,
Glas, Leder und fein strukturierte Verbundstoffe.

Verboten sind Fake-Luxus, unnötige Chromflächen, Hochglanzplastik, permanent
leuchtende Kanten, dekorative Materialmischungen und eingebrannte KI-Schrift.

Materialreflexion ersetzt Glow. Kontakt, Gewicht, Reibung und Klang müssen zum
sichtbaren Material passen.

## 5. Zwei Tischwelten

Beide Tischwelten verwenden dieselben Regeln, dieselbe Informationshierarchie und
dieselbe 8+1-Topologie: acht äußere Gewinnfelder und eine größere Mitte. Keine Welt
erhält spielerische Vorteile.

### Track A - Poch Disc

Die primäre Produktidentität und der Standard für Tutorial, Marketing und
Wettkampfmodus.

- Ein herstellbares Designobjekt statt eines illustrierten Spielbretts.
- Satinierter Aluminiumrahmen, ruhiger graphit- oder nachtblauer Körper,
  präzise eingelassene Mulden und hochwertige textile oder keramische Böden.
- Exakt acht Außenmulden plus größere Mitte.
- Beschriftungen als scharfe, lokalisierbare UI-Ebene, nie im Render.
- Aktive Zustände als wandernde Materialreflexion, Kontrast und Fokus - nie Neon.
- Sichtbeton oder Waschbeton ist eine emotionale Bühne für Splash, Store und
  Abschlussmomente. Im wiederholten Gameplay wird er zu einem ruhigen,
  kontrastarmen Graphitgrund reduziert.

### Track B - Unterwegs

Eine optionale, authentische Gegenwelt. Sie zeigt, dass Poch überall aus wenigen
Gegenständen entstehen kann, ohne trashig oder nostalgisch verkleidet zu wirken.

- Das Feld darf unrund sein. Bindend ist die 8+1-Funktion, nicht die Kreisform.
- Primärer Ansatz ist eine generische transparente oder leicht getönte
  Servier-/Snackschale mit acht äußeren Fächern und einer Mitte. Keine Marke,
  Verpackungsschrift oder Produktkopie.
- Provisorische Bezeichnungen erscheinen als sauber gesetzte, lokalisierbare
  UI-Overlays mit der Anmutung präzise beschrifteten Kreppbands.
- Kontextobjekte sind sparsam und funktional. Kein Camping-Klischee, keine
  Schmutzromantik und keine dekorative Requisitenwand.
- Splash, Tischwahl und Ergebnis dürfen die Umgebung erzählen. Während des Spiels
  wird enger und ruhiger komponiert.

### Auswahl

- Die erste geführte Partie verwendet immer Track A. Der Einstieg darf keine
  Stilentscheidung vor das Verständnis stellen.
- Nach der ersten abgeschlossenen Partie erscheint einmalig `Wähle deinen Tisch`.
- Die Auswahl zeigt zwei große visuelle Vorschauen und jeweils einen sachlichen
  Ein-Satz-Unterschied. Kein Modal mit kleinen Radio-Buttons.
- Nach der Tischwahl folgt eine kompakte Gültigkeitsauswahl als Segment:
  `Nur diese Partie` oder `Als Standard`. Vorausgewählt ist `Nur diese Partie`.
- Eine einzige Primäraktion `Mit diesem Tisch spielen` bestätigt Tisch und
  Gültigkeit. Es gibt keine zwei konkurrierenden Startbuttons.
- `Nur diese Partie` setzt einen Session-Override und verändert den gespeicherten
  Standard nicht. Nach dem Partieende fällt die App auf den bisherigen Standard zurück.
- `Als Standard` verwendet den Tisch sofort und speichert ihn für künftige Partien,
  bis der Spieler die Einstellung erneut ändert.
- Der Standard bleibt unter `Tisch & Material` jederzeit reversibel. Die UI verwendet
  deshalb nicht die absolute Formulierung `für immer`.

## 6. Spielsteine

### Track A - R1 ist festgelegt

- 36 mm Durchmesser, 3 mm Stärke, gedachtes Gewicht 9 bis 10 g.
- Mattes Clay-Composite oder durchgefärbte Keramik mit warmer, steiniger Haptik.
- Große tonale Blindprägung des geometrischen Kartenrücken-Signets.
- Feine umlaufende Präzisionsrändelung.
- Palette: Naturweiß, Terrakotta, Salbeigrün, Schiefergrau und gedecktes Ocker als
  gemeinsame materielle Board-Palette der bestätigten Produktreferenz.
- Die Farben liegen innerhalb derselben Partie gemeinsam auf der Disc. Ihre
  deterministische Verteilung bezeichnet niemals Besitzer, Wert oder verdeckte
  Information und verändert weder Zähler noch Regeln.
- Herkunft wird während einer Bewegung kurz über Sitz, Flugbahn und einen
  nichtfarbigen Fokusindikator gezeigt. Der ruhende Stein bleibt neutral zur Person.
- Es gibt kein Umfärben oder Morphen gewonnener Steine. Digitales Verhalten und
  glaubwürdiges physisches Produkt bleiben dadurch identisch.
- Alle Steine haben denselben Wert. Keine Zahlen, Dollarzeichen oder Edge-Spots.

### Track B - echte Cent-Münzen

- Ausschließlich gleichwertige 1-Cent-Münzen; keine gemischten Nennwerte.
- Jede sichtbare Münze darf sich in Rotation, Patina, Oxidation, Kratzern,
  Kantenabrieb und Restglanz unterscheiden.
- Die Auswahl der Varianten und die endgültige Lage sind deterministisch, damit
  Animation, Tests und Wiederholungen stabil bleiben.
- Die UI zeigt Anzahlen, niemals Eurobeträge oder Echtgeldsprache.

### Gemeinsame Physik

- Spielsteine landen vollständig innerhalb ihres Zielfelds.
- Kleine Gruppen wirken natürlich und leicht zufällig, aber nie chaotisch.
- Kontakt-, Überlappungs- und Höhenschatten stimmen mit der realen Lage überein.
- Quelle, Flug, Kontakt, sichtbarer Zähler und Ruheposition bilden eine einzige
  kausale Sequenz.
- Beim tatsächlichen Kontakt erzeugt R1 ein trockenes, sattes Keramikklacken mit
  kurzer Körperresonanz und einen exakt synchronisierten Taptic-Impuls. Material,
  Zielfeld und Gruppengröße bestimmen die Intensität.
- Kein Sound und keine Haptik starten beim Abflug. Tokenströme bündeln untergeordnete
  Kontakte, damit weder Klicksalve noch Vibrationsdauerfeuer entstehen.

## 7. Karten und Signet

Das facettierte, rotationssymmetrische Kartenrücken-Signet bleibt das gemeinsame
Markenzeichen von Karten, R1-Spielsteinen und Produkthülle.

- Die Geometrie bleibt, die Materialausführung darf gezielt weiterentwickelt werden.
- Karten sind steif, gut lesbar und bewegen sich wie Karton, nicht wie Stoff oder UI.
- Kleine kontrollierte Abweichungen in Fächer, Rotation und Kontakt lassen jede
  Partie frisch wirken. Keine flatternden Zufallsbewegungen.
- Funktionale Kartenindizes haben Vorrang vor Illustration und Textur.

## 8. Benutzererlebnis

- Eine Bühne, ein Gedanke, eine erkennbare Primäraktion.
- Ursache erscheint vor Wirkung. Zahlen ändern sich beim Kontakt, nicht beim Start.
- Das Tutorial ist eine spielbare Lehrpartie und enthüllt Elemente erst bei ihrer
  ersten Bedeutung.
- Das Tutorial verwendet immer dieselbe Poch Disc wie das freie Spiel. Es gibt kein
  vereinfachtes Ersatzbrett, keine technische Tutorialscheibe und keine abweichende
  Regelgeometrie. Lernen verändert Fokus und Sichtbarkeit, niemals das Objekt.
- Im Lernmodus bleibt die vollständige 8+1-Disc räumlich stabil. Noch nicht erklärte
  Bereiche treten durch Licht, Kontrast und leichte Defokussierung zurück; sie werden
  bei ihrer ersten Bedeutung aus demselben Material heraus sichtbar.
- Temporäre Hairlines und scharfe UI-Beschriftungen dürfen Karte, Feld und Wirkung
  verbinden. Sie verschwinden nach dem Lernmoment vollständig. Platzhalter,
  Messlinien, technische Variablennamen und Text im Board-Render sind verboten.
- Karten, Spielsteine und Gegner besitzen immer eine sichtbare räumliche Herkunft.
- Gegner bleiben am Tisch räumlich stabil und reagieren auf öffentliche Zustände,
  niemals auf verdeckte Handstärke.
- Die erste geführte Partie besitzt eine feste, kuratierte Besetzung. Gegner werden
  zuerst als Menschen mit Name, Portrait und Sitz eingeführt; Spieltendenzen folgen
  erst nach der ersten verstandenen Poch-Entscheidung.
- Freie Partien werden standardmäßig automatisch besetzt. Eine manuelle Auswahl ist
  freiwillig und zeigt nur wenige verständliche Tendenzen, keine RPG-Werte,
  Seltenheiten oder garantierten Verhaltensversprechen.
- Motion erklärt Zustand und Zusammenhang. Häufige Aktionen bleiben direkt.
- Sound und Haptik verstärken Materialkontakt; sie ersetzen keine visuelle Klarheit.
- Reduce Motion, VoiceOver, große Schrift und lange Übersetzungen sind Teil der
  Gestaltung, keine nachträgliche Prüfung.

### Adaptive Komposition

Poch 1441 ist in Portrait und Landscape vollständig spielbar. Landscape ist keine
gedrehte oder verkleinerte Portrait-Ansicht, sondern eine eigenständige Komposition
derselben Spielzustände, Hierarchie und Regeln.

- Portrait bleibt die vertikale, intime Einhand-Komposition mit Hand am unteren Rand.
- Landscape nutzt die Breite als Tisch: feste Gegnerachse links, Entscheidung in der
  ruhigen Mitte, Disc rechts und die eigene Hand groß am unteren Rand.
- In Phase 2 darf die Einsatzsteuerung links erscheinen, ohne Gegner, Entscheidung
  oder Hand zu überdecken. Ihre konkrete Form bleibt eine UX-Entscheidung und wird
  nicht durch den alten vertikalen Mockup-Regler festgelegt.
- In Phase 3 übernimmt die Kartenfolge die Hauptbühne; die Disc wird kleiner und bleibt
  als räumliches Ziel sichtbar.
- Gegnerplätze bleiben zwischen Phasen und Orientierungen semantisch stabil. Karten
  fliegen immer zu einem sichtbaren Sitz, nie ins Leere.
- Rotation während einer laufenden Kontaktanimation wird erst nach dem Impact in die
  neue Komposition überführt. Es gibt keinen Sprung, keine doppelte Karte und keinen
  verlorenen Tutorialschritt.
- Für beide Orientierungen gelten dieselben Regeln für Safe Areas, Dynamic Type,
  Lokalisierung, VoiceOver-Reihenfolge und Reduce Motion.

## 9. Geschichte und Positionierung

`1441` und die Herkunft von Poch geben Tiefe, nicht die Formensprache vor.
Historische Referenzen erklären Regeln und Bedeutung, rechtfertigen aber keine
mittelalterliche Ornamentik, künstliche Patina oder altertümliche Sprache.

Die Positionierung lautet weiterhin:

> Das Strategiespiel, aus dem Poker wurde.

Poker ist Herkunft und strategischer Kontext, keine visuelle Lizenz für Casinochips,
All-in-Sprache, Spieltischfilz oder Wettästhetik im Standardprodukt.

## 10. Review-Fragen

Vor Freigabe jedes sichtbaren Elements wird geprüft:

1. Versteht ein neuer Spieler seine Funktion ohne Vorwissen?
2. Ist es im echten Spiel ruhiger und klarer als im Standbild?
3. Sind Material, Bewegung, Sound und Haptik physisch konsistent?
4. Würde dieselbe Form als reales Produkt überzeugen?
5. Bleibt sie ohne Farbe, Motion und Ton verständlich?
6. Vermeidet sie Casino-, Luxus- und Gaming-Klischees?
7. Ist sie besser als die naheliegende Standardlösung - und warum?

Die Zielreaktion lautet nicht `sieht teuer aus`, sondern:

> Warum hat das nicht schon immer genau so ausgesehen?
