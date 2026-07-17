# Poch 1441 - GOTY-2026-Masterplan

Stand: 17. Juli 2026

## 1. Zielbild

Poch 1441 soll kein schönes Regelbuch mit Spielfunktion sein, sondern ein sofort
verständliches, körperlich glaubwürdiges und langfristig motivierendes Kartenspiel.
Das Ziel ist ein Kandidat für Apple App of the Day und relevante Mobile-Game-
Auszeichnungen. Das ist kein garantierbarer Titel, sondern ein Qualitätsniveau mit
messbaren Abnahmekriterien.

North Star:

> Nach 60 Sekunden versteht ein neuer Spieler, was er gerade erreichen will. Nach
> einer Runde kann er Melden, Pochen und Ausspielen in eigenen Worten erklären. Jede
> Karte und jeder Spielstein besitzt nachvollziehbare Herkunft, Flugbahn, Material,
> Ziel und Wirkung.

Verbindlicher Designfilter: `tasks/design-canon-2026.md`. Bei visuellen
Widersprüchen gewinnen dessen neueste Festlegungen gegen ältere Mockups, PM-Render,
Materialstudien und Timing-Ideen. Das Qualitätsziel ist nicht sichtbarer Luxus,
sondern eine so präzise und verständliche Produktlösung, dass die Alternative
altmodisch wirkt.

Tischpräferenzen besitzen zwei getrennte Zustände: einen gespeicherten Standard und
einen optionalen Override für die laufende Partie. Ein Session-Override darf den
gespeicherten Standard niemals still verändern.

## 2. Red-Team-Befund

Die größten Risiken sind nicht fehlende Effekte, sondern fehlende Kausalität und
fehlende Priorisierung:

1. Der erste Start springt unmittelbar in eine geführte Runde. Der Spieler kennt
   Tisch, Ziel und Coach noch nicht und erlebt den Deal als unkommentierte Aktivität.
2. Tutorialtexte liegen über einem weiterlaufenden Spiel. Zeitgesteuerte Schritte
   können enden, bevor der Spieler ihre Bedeutung verstanden hat.
3. Deal, Meldeauszahlung, Gebot, Gegnerreaktion und Phasenwechsel besitzen jeweils
   eigene Timer, aber noch keinen gemeinsamen dramaturgischen Taktgeber.
4. Karten bewegen sich teilweise wie weiche UI-Kacheln statt wie steife Karten.
   Rotation, Translation, Wölbung und Zielausrichtung erzählen nicht dieselbe Physik.
5. Spielsteine bewegen sich über zu große Wege und landen nicht wie reale flache
   Keramiksteine beziehungsweise Cent-Münzen. Quelle, Flug, Kontakt und endgültige Position sind nicht sauber
   gekoppelt.
6. Mehrere lokale Buttonstile, kleine Schriftgrade und feste Frames erzeugen
   Überläufe, zu kleine Tap-Ziele und eine uneinheitliche Hierarchie.
7. Vorhandene Screenshot-Checks beweisen Layoutzustände, aber nicht Verständnis,
   Motionqualität oder tatsächliche Interaktion.
8. Das umfangreiche Todo markiert einige Bereiche als erledigt, obwohl die reale
   Nutzung weiterhin unverständlich ist. Ab jetzt zählt Nutzerverständnis vor
   Implementierungsstatus.
9. Die App nutzt noch isolierte `Round`-Instanzen statt `PochKit.Match`. Dadurch
   fehlen stehende Mulden, Geberrotation, stabile Gegneridentitäten und ein echtes
   Partieende - also genau die emotionale Makrostruktur des Spiels.
10. Hände ohne Meldung und ohne Poch-Berechtigung sind als Erlebnisrisiko nicht
    gemessen. Nach einem erfolgreichen Tutorial kann die erste freie Runde deshalb
    ohne eigene Entscheidung bis Akt 3 verlaufen.
11. `BotBrain` liest aktuell zwar nur die eigene Hand, erhält technisch aber den
    vollständigen `Round`. Fairness muss durch eine engere Beobachtungs-API statt
    nur durch Implementierungsdisziplin garantiert werden.
12. Aktuelle Screens widersprechen einzelnen Planregeln: numerische Tutorialbadges,
    zu viele Muldenbegriffe im ersten Beat und konkurrierende Erklärungsebenen in
    Phase 2.

Frühes Falsifikationsexperiment:

- Eine einzige gescriptete Anfängerpartie wird vollständig tap-gesteuert aufgebaut.
- Drei unvorbereitete Personen spielen sie ohne Erklärung von außen.
- Wenn nicht mindestens zwei Personen anschließend die drei Akte und die Bedeutung
  der Mitte erklären können, wird keine weitere Meta-Funktion gebaut.

## 3. Verbindliche Erlebnisregeln

### 3.1 Eine Bühne, ein Gedanke

- Jeder Moment besitzt genau ein dominantes Hauptelement.
- Tutorial: maximal eine Erklärung und eine primäre Aktion gleichzeitig.
- Kein Textpanel darf Brett, Hand, Gegner oder Aktionsziel verdecken.
- Nicht relevante Bereiche werden ruhig abgedunkelt, nicht stark unscharf gemacht.
- Bewegungen enden vollständig, bevor neue Erklärungen oder Aktionen erscheinen.

### 3.2 Ursache vor Wirkung

Jede relevante Aktion folgt demselben Rhythmus:

1. Quelle sichtbar machen.
2. Ziel sichtbar machen.
3. Entscheidung in einem kurzen Satz erklären.
4. Spieler tippt selbst.
5. Bewegung zeigt Quelle zu Ziel.
6. Kontakt und Materialfeedback.
7. Zahlen ändern sich erst nach dem Kontakt.
8. Ein kurzer Ergebnissatz benennt die Wirkung.
9. Erst danach wird der nächste Schritt freigegeben.

### 3.3 Material vor Effekt

- Kein Dauer-Glow.
- Karten bleiben steife Körper mit geringer elastischer Verformung.
- Spielsteine folgen dem aktuellen Materialsystem aus `tasks/design-canon-2026.md`:
  R1-Keramiksteine in Track A, individuelle 1-Cent-Münzen in Track B.
- Haptik und Audio liegen exakt auf Materialkontakt, nicht auf Animationsstart.
- Reduce Motion ersetzt Flug durch klare Quelle-Ziel-Überblendung und Kontaktfeedback.

## 4. Gate 0 - Messbarkeit und Präsentationsarchitektur

### Ziel

Ein zentraler Presentation Director orchestriert Lernschritte und High-impact-Momente,
ohne PochKit-Regeln zu übernehmen.

### Umsetzung

- Präsentationszustände datengetrieben modellieren:
  `prepare`, `explain`, `awaitInput`, `travel`, `impact`, `result`, `continue`.
- Tutorialschritte aus JSON laden: Text-IDs, Fokusziel, erlaubte Aktion,
  Mindesthaltezeit, Auto-Advance-Verhalten und Erfolgsbedingung.
- Timer nur für Bewegungsdauer und Mindestlesezeit verwenden. Fortschritt entsteht
  grundsätzlich durch abgeschlossene Engine-Ereignisse oder bewussten Tap.
- Bestehende unabhängige Tasks für Deal, Bots, Meldungen und Phasenwechsel über
  Cancellation-IDs beziehungsweise einen Actor serialisieren.
- DEBUG-Timeline einbauen, die Ereignisname, Start, Impact, State-Mutation und Ende
  protokolliert. Kein `print()`, ausschließlich `os.Logger`.
- Vor weiterer Politur alle aktuellen Kernzustände gegen Kapitel 3 inventarisieren.
  Ein alter Todo-Haken ist kein Abnahmebeleg.
- [x] `MatchSource` nutzt echte `PochKit.Match`-Partien mit stabiler UI-Sitzzuordnung.
  Gegner, Konten, Geber und stehende Mulden bleiben über Runden erhalten; Quick endet
  nach 12 Runden mit einer eigenen Partieabrechnung.
- [x] `BotObservation` begrenzt den Bot auf eigene Hand und öffentliche Informationen.
  `BotBrain` erhält keinen vollständigen `Round` mehr.
- [x] Dead-Hand-Rate mit je 100.000 Deals gemessen. Anteil `keine Meldung + kein Paar`:
  3 Spieler 0,00 %, 4 Spieler 0,46 %, 5 Spieler 4,20 %, 6 Spieler 11,82 %.
  Konsequenz: keine Regeländerung; ab fünf Spielern braucht die UX ein explizites
  Beobachtungsziel und einen zügigen Übergang in Akt 3.

### Done

- Keine Tutorialsequenz läuft allein wegen abgelaufener Zeit zum nächsten Lernziel.
- Schnelle Mehrfachtaps erzeugen keine doppelten Flüge oder übersprungenen Zustände.
- Unterbrechung durch Pause, Hilfe oder App-Hintergrund setzt den Beat sauber fort.
- Mehrere Runden rotieren den Geber, ohne Namen, Hände, Zahlungen oder Portraits den
  falschen Tischsitzen zuzuordnen.

## 5. Gate 1 - Neuer erster Start

### Ziel

Der Spieler landet nicht in Einstellungen und nicht unvorbereitet in einem laufenden
Deal. Er versteht vor dem ersten Geben, worum es am Tisch geht, und möchte eine
konkrete stehende Belohnung gewinnen.

### Ablauf

1. Ruhiger Tisch-Reveal mit Logo, Brett und bereits sichtbaren Gegnerplätzen.
2. Ein sichtbarer Carry-over zeigt regelkonform, warum dieser Tisch begehrenswert
   ist. Ein Satz verbindet Ziel und Geschichte, ohne Casino-Vokabular.
3. Eine einzige Primäraktion: `Am Tisch Platz nehmen`.
4. Coach tritt als Person auf: `Ich zeige dir immer nur den nächsten Zug.`
5. Standardtisch mit vier Spielern startet. Spielerzahl und Einstellungen bleiben
   später im Tischmenü erreichbar.
6. Vor dem ersten Einsatz wird das Ziel der Runde in höchstens zwei Sätzen gezeigt.

### Qualitätsregeln

- Kein Carousel, keine Featureliste, keine Berechtigungswand.
- Einstieg bis zur ersten sinnvollen Interaktion: maximal 20 Sekunden inklusive
  freiwilliger Lesedauer.
- Wiederkehrende Spieler starten direkt am letzten beziehungsweise neuen Tisch.
- Tutorial überspringen ist sichtbar, aber nicht gleichwertig zur Primäraktion.

## 6. Gate 2 - Tutorial als spielbare Lehrpartie

### Dramaturgische Leitidee: Der Tisch erwacht

Das Tutorial ist eine eigene, inszenierte Partie und kein Text-Layer über dem
vollständigen Spiel. Ein neuer Spieler sieht immer nur das, was er bereits versteht.
Der Tisch wächst mit seinem Wissen.

`Der Tisch wächst` bedeutet keinen Austausch des Spielfelds. Das Tutorial verwendet
die echte Track-A-Poch-Disc in identischer Geometrie, Materialität und Orientierung.
Nur Fokus, Materialkontrast und temporäre UI-Hilfen verändern sich. Damit überträgt
jede gelernte räumliche Beziehung direkt in die erste freie Partie.

1. **Stille vor dem Spiel:** dunkler Tisch, Mitte und genau eine relevante
   Außenmulde, ein ruhender R1-Spielstein. Kein Phasenlabel, keine Gegnerwerte, keine
   Range und keine Aktionswand.
2. **Erster eigener Kontakt:** Der Spieler legt den Token selbst. Erst beim Kontakt
   erscheinen die acht äußeren Mulden aus dem Material. Damit wird das Brett durch
   eine Handlung statt durch einen Absatz erklärt.
3. **Die Hand entsteht:** Deck und Kartenrückseite werden groß inszeniert. Eine Karte
   fliegt langsam zum Gegner, eine zum Spieler. Erst danach wächst der eigene Fächer.
4. **Das erste Erfolgserlebnis:** Das Tutorial garantiert früh eine sichtbare
   Meldung. Passende Karten und Zielmulde werden räumlich verbunden; der Spieler
   löst die Auszahlung selbst aus.
5. **Erste echte Entscheidung:** Pochen beginnt nur mit `Passen` und `Pochen 1`.
   Einsatz, möglicher Gewinn und Verlust werden direkt an Quelle und Ziel gezeigt.
   Range, Erhöhen und Gegnerdaten erscheinen erst, wenn sie benötigt werden.
6. **Der Rhythmus trägt:** Beim Ausspielen werden zwei langsame Kartenfolgen erklärt,
   danach darf der Spieler die Beschleunigung der Kette erleben.
7. **Verdienter Abschluss:** Abrechnung in drei Takten statt als Zahlenwand. Der
   Spieler sieht erst den Gewinn, dann dessen Herkunft, dann den neuen Kontostand.

### Progressive Disclosure

- Nicht erklärte Mulden und Elemente werden bevorzugt gar nicht gerendert. Die neun
  Kategorien werden niemals als frontaler Memory-Dump vorgestellt. Nur Elemente, die
  für räumliches Verständnis erhalten bleiben müssen, werden auf 35-45 Prozent
  abgedunkelt und leicht defokussiert.
- Fokusflächen bleiben vollständig scharf und erhalten keinen Dauer-Glow. Eine
  kurze Materialkante und eine leichte Tiefenanhebung reichen.
- Der Coach sitzt an einem festen Platz und spricht in maximal zwei Zeilen. Längere
  Hintergründe liegen freiwillig hinter `Warum?`.
- Jeder Schritt besitzt `Zurück`, `Noch einmal` und eine einzige primäre Aktion.
- Fortschritt zeigt nie `3/6`, `1/5` oder ähnliche Zähler, sondern benennt den nächsten Erkenntnisgewinn,
  beispielsweise `Als Nächstes: deine erste Meldung`.

### Verbindliche Lernzustände der Disc

1. `Orientieren`: Mitte plus ein Außenfeld, eine kurze Aussage, eine Aktion.
2. `Verbinden`: passende Karte und Zielfeld gleichzeitig scharf; übrige Bühne ruhig.
3. `Beweisen`: eine Hairline zeigt Quelle zu Ziel, der Spieler löst die Wirkung aus.
4. `Loslassen`: Hilfen verschwinden, die reguläre Disc und Komposition bleiben.

Die Lernzustände sind keine vier automatischen Folien. Jeder Zustand endet durch eine
verständliche Nutzerhandlung oder eine explizite Bestätigung. Die Darstellung aus
technischen Konzeptbildern mit `[VAR_*]`, englischen Platzhaltern oder Konstruktions-
beschriftung ist ausschließlich internes Storyboarding und niemals Produkt-UI.

### Portrait und Landscape im Tutorial

- Derselbe Beat, Fokuszustand und Fortschritt gelten in beiden Orientierungen.
- Portrait reserviert den unteren Bereich für Hand und Primäraktion. Lerntexte dürfen
  weder die Hand noch die Disc überdecken.
- Landscape nutzt links die stabile Gegnerachse, mittig die Lernhandlung und rechts
  die Disc. Die Hand bleibt groß am unteren Rand.
- Eine Rotation pausiert die Regie, übernimmt den letzten bestätigten Beat und ordnet
  nur die Bühnenzonen neu. Sie startet keinen Beat neu und überspringt keine Wirkung.
- Screenshots und Interaktionstests für Tutorial-Beats werden in beiden Orientierungen
  auf kompakter und großer Geräteklasse abgenommen.

### Begriffe werden über ihren Zweck eingeführt

Eine externe Gegenprüfung am 11. Juli bestätigt: Die bisherige Dramaturgie ist
visuell gedacht, erklärt einem völligen Neuling aber die Bedeutung der drei Akte
noch zu spät. Deshalb gilt für den ersten Kontakt:

- **Melden:** `Deine Trumpfkarten holen feste Belohnungen aus den äußeren Mulden.`
- **Pochen:** `Mit einem Paar oder besser forderst du die anderen um die Poch-Mulde.`
- **Ausspielen:** `Lege in derselben Farbe aufwärts. Wer zuerst leer ist, gewinnt die Mitte.`
- **Trumpf:** wird nicht als allgemein "stärkste Farbe" erklärt. Regelkorrekt heißt:
  Die offene letzte Karte bestimmt die Trumpffarbe für Meldewerte und Tiebreaks.
- **Außenmulden:** sind benannte, stehende Belohnungen für Kartenwerte und
  Kombinationen. **Mitte:** ist der getrennte Preis des Ausspielens.

Diese Sätze sind kein vorgeschaltetes Regelmodal. Jeder erscheint erst unmittelbar
vor der Handlung, die ihn beweist.

### Spannungsbogen der ersten 90 Sekunden

- 0-10 s: Tisch-Reveal und eigener erster Token.
- 10-28 s: große Kartenrückseite, erste langsame Austeilrunde, eigene Hand.
- 28-45 s: Trumpf und sichere erste Meldung.
- 45-68 s: erste Poch-Entscheidung mit klarer Konsequenz.
- 68-90 s: kurze Ausspielkette und sichtbarer Mini-Abschluss.
- Keine Phase startet, solange der vorige Erkenntnissatz nicht bestätigt wurde.

### Lern- und Begeisterungsmetriken

- Time-to-first-meaningful-action unter 12 Sekunden.
- Time-to-first-reward unter 45 Sekunden.
- Kein Tutorialpanel verdeckt Quelle, Ziel oder eigene Karten.
- Nach jedem Beat kann der Spieler in einem Satz beantworten: `Was wollte ich?`,
  `Was habe ich entschieden?`, `Was hat sich verändert?`.
- Abbruch, App-Hintergrund und Pause setzen exakt am letzten bestätigten Beat fort.

### Beat 1: Der Tisch

- Mitte und genau eine aktuell relevante Außenmulde werden über ihren Zweck
  eingeführt. Die übrigen Kategorien erscheinen erst bei ihrer ersten Relevanz.
- Nur die aktuell erklärte Mulde erhält Materialkontrast.
- Spieler legt den ersten eigenen R1-Spielstein selbst in eine Mulde.
- Danach übernimmt eine ruhige, beschleunigte Ante-Sequenz die restlichen Einzahlungen.

### Beat 2: Geben und Trumpf

- Erste Karte wird langsam vom klar sichtbaren Deck zum ersten Gegner gegeben.
- Zweite Karte geht zum Spieler; Coach benennt den eigenen Kartenbereich.
- Eine komplette Austeilrunde bleibt langsam, danach darf die Kadenz anziehen.
- Trumpfkarte erhält einen eigenen Halt; erst danach erscheint die Erklärung.

### Beat 3: Melden

- Eigene relevante Karten werden angehoben, passende Mulde gleichzeitig markiert.
- Coach: `Diese Kombination gewinnt diese Mulde.`
- Spieler bestätigt den Claim.
- Token bewegen sich aus exakt dieser Mulde zum eigenen Konto.
- Ergebnissatz: `Du erhältst 4. Die Mitte bleibt liegen.`

### Beat 4: Pochen

- Handpaar sichtbar rahmen, Range und Einsatzgrenze nacheinander einführen.
- Zuerst nur zwei Aktionen: `Passen` und `Pochen 1`.
- Konsequenz vor dem Tap zeigen, nicht danach erklären.
- Gegner reagieren nacheinander mit Name, Mimik und kurzem Verb.
- Erst in einer zweiten Entscheidung kommen `Mitgehen` und `Erhöhen` hinzu.

### Beat 5: Ausspielen

- Ziel zuerst: `Werde als Erster alle Karten los.`
- Nur legal anspielbare Karten bleiben voll gesättigt.
- Spieler wählt die erste Karte selbst.
- Zwei Karten einer Kette langsam zeigen, dann Kaskade behutsam beschleunigen.
- Beim Kettenriss vollständiger Halt, Quelle des neuen Anspielrechts markieren.

### Beat 6: Abschluss

- Letzte Karte bleibt stehen.
- Gewinner, Mitte und Restkartenstrafe werden getrennt abgerechnet.
- Drei klare Rückblicke: `Das hast du gemeldet`, `So hast du gepocht`,
  `So endete die Kette`.
- Primäraktion: `Eine freie Runde spielen`.

### Done

- Spieler kann jeden Beat wiederholen und einen Schritt zurückgehen.
- Keine Coach-Erklärung enthält mehr als 100 Zeichen im Hauptsatz.
- Optionale Vertiefung liegt hinter `Warum?`, niemals im Hauptfluss.
- Drei Anfänger bestehen einen Verständnischeck ohne externe Hilfe.

## 7. Gate 3 - Kartenbewegung und Deal

### Physikmodell

- Karten sind starre Rechtecke. Wölbung ist eine subtile Materialreaktion, keine
  flatternde Gesamtbewegung.
- Flugbahn: eine kontrollierte kubische Bézierkurve mit klarer Quelle und Ziel.
- Drehung folgt der Flugrichtung und nähert sich monoton der Zielrotation.
- Keine Richtungsumkehr, kein Overshoot über das Ziel, keine dauernde Z-Achsen-Rotation.
- Maximal 3-6 Grad elastischer Wobble beim Kontakt, innerhalb 140 ms gedämpft.
- Kartenränder behalten den dunklen Kontur-/Schlagschatten aus dem Mockup.

### Deal-Kadenz für die erste Runde

- Erster Flug: 700-850 ms, danach 450 ms Halt.
- Erste komplette Runde über alle Spieler: 560-680 ms pro Karte.
- Restlicher Deal: 240-320 ms Takt, ohne überlagerte unlesbare Flugfenster.
- Trumpf-Freeze: 650-900 ms, bis Symbol und Bedeutung gelesen wurden.

### Freies Spiel

- Deutlich schneller als Tutorial, aber weiterhin physisch nachvollziehbar.
- Option `Schnelles Geben`, niemals automatisch beim ersten Spiel aktiv.

### Done

- Frame-Audit bei 60 FPS zeigt keine doppelte Karte und keinen Positionssprung.
- Zielkarte endet pixelgenau im Handfächer beziehungsweise Gegnerstapel.
- Phase 1 und Phase 2 verwenden identische Handgröße und Bottom-Bleed-Geometrie.

## 8. Gate 4 - Spielsteine und glaubwürdige Bewegung

### Verbindliches Spielsteinmodell

- Track A verwendet R1: flache, matte Keramik-/Clay-Steine mit tonaler
  Signet-Blindprägung und feiner Rändelung.
- Track B verwendet individuell gealterte, gleichwertige 1-Cent-Münzen.
- Keine Kugeln, Pokerchips, Candy-Glassteine oder perfekten Stapelsäulen.

### Ablagepositionen

- Pro Mulde deterministische, handgesetzte Slots für 1-12 Token.
- Kleine Mengen liegen einzeln und leicht überlappend.
- Große Mengen bilden einen natürlichen Haufen mit begrenzter Rotation.
- Jeder Mittelpunkt bleibt mindestens einen Tokenradius innerhalb der nutzbaren
  Muldenkontur.
- Keine SwiftUI-Zufallsposition bei jedem Rendern.

### Bewegungsmodell

- Kurze Quelle-Ziel-Wege. Einzahlungen starten am sichtbaren Spielerkonto oder
  Sitz, Auszahlungen in der konkreten Mulde.
- Flache ballistische Kurve mit 12-24 pt optischer Höhe, keine weiten Fontänen.
- Flug 520-760 ms abhängig von Distanz; zwei bis vier Token leicht versetzt.
- Kein kontinuierliches Rotieren. Maximal 20 Grad Lageänderung während des Flugs.
- Kontakt: 70-110 ms Kompression, ein kleiner Seitenschlupf, dann Stillstand.
- Zähleränderung und Klang exakt beim ersten Materialkontakt.
- Nachfolgende Token stoßen den bestehenden Haufen nur minimal an.

### Audio und Haptik

- Kurzer Glas-/Metallkontakt mit 3-4 Tonvarianten gegen Wiederholung.
- Tieferer Kontakt in der großen Mitte, leichterer Kontakt in Außenmulden.
- `light` für einzelnen Token, `medium` für Haufen, `heavy` ausschließlich für
  den Poch-Tischschlag.

### Done

- Video-Frame-Audit für Ante, Meldegewinn, Poch-Einsatz und Endabrechnung.
- Kein Token verlässt in irgendeinem Frame die Zielmulde nach dem Kontakt.
- Fünf aufeinanderfolgende Transfers wirken unterschiedlich, aber nicht zufällig.

## 9. Gate 5 - UI-System, Buttons und Text

### Eine gemeinsame Komponente

- `GameActionButton` für alle Spielaktionen mit Varianten `primary`, `secondary`,
  `destructive`, `disabled` und `compact`.
- `MaterialButton` für Menüs und Overlays, getrennt von Spielaktionen.
- Keine lokal erfundenen Buttonhöhen oder Corner-Radien mehr.

### Verbindliche Maße

- Mindest-Tapziel 44 x 44 pt, primäre Spielaktion 52-58 pt hoch.
- Primärtext 16-17 pt semibold; kompakte Aktionen mindestens 14 pt.
- Einzeilige Aktionsnamen. Konsequenztext steht außerhalb des Buttons.
- Text darf nie durch fixe Breite abgeschnitten werden; adaptive Grids und
  `ViewThatFits` vor aggressivem `minimumScaleFactor`.
- Disabled bleibt lesbar und unterscheidbar, nicht fast unsichtbar.
- Kontrast für alle Zustände mindestens WCAG AA, soweit auf Spielgrafik anwendbar.

### Auditmatrix

- iPhone SE, Standard-iPhone, Pro Max.
- DE, EN, FR, IT, ES, NL, PL.
- Standardtext und größere Bedienungshilfeschrift.
- Premium und Vivid.
- Alle legalen und illegalen Aktionskombinationen.

### Done

- Kein abgeschnittener oder überlaufender String in automatisierten Screenshots.
- Keine Überlappung von Hand, Gegnern, Buttons, Coach und System-Safe-Areas.
- Primäraktion ist in jedem Zustand in unter einer Sekunde visuell auffindbar.

## 10. Gate 6 - Die drei Akte als Spannungskurve

### Melden - Entdecken

- Großes Brett, wenig UI, klare Lesbarkeit stehender Muldenwerte.
- Meldungen als einzelne verständliche Claims, nicht als schneller Zahlenregen.
- Spannung entsteht durch stehende Mulden und seltene hohe Auszahlungen.

### Pochen - Psychologie

- Range links, Poch-Pott rechts, Gegner als Gesichter nahe der Entscheidung.
- Antwortreihenfolge ist immer sichtbar.
- Tischschlag ist der seltene Signaturmoment, nicht jede Erhöhung.
- Sprechblasen nur bei charakterstarken Momenten, nicht bei jedem Bot-Tap.
- Ein eigener Zug zeigt genau eine Konsequenz und eine Primäraktion. Range erscheint
  nur, wenn tatsächlich ein Betrag gewählt werden kann.
- Eigener Gesamtbestand und bereits gesetzter Betrag bleiben klar getrennt.
- Der Poch-Tischschlag ist die Signaturbewegung: explizite Aktion bleibt sichtbar,
  eine erlernte Doppeltap-Geste darf optional denselben Beat auslösen.

### Ausspielen - Beschleunigung

- Kartenfächer ist die Hauptbühne, Gegner bilden einen ruhigen Rahmen.
- Ketten werden mit wachsendem Tempo befriedigend, bleiben aber mitlesbar.
- Riss erzeugt kurze Stille und räumlich eindeutigen Fokuswechsel.
- Letzte Karte und Zieleinlauf erhalten einen eigenen Abschlussbeat.

### Done

- Jede Phase ist ohne Überschrift anhand von Komposition, Farbe und Bewegung erkennbar.
- Kein Screen fühlt sich wie ein Formular oder Debug-Dashboard an.

## 11. Gate 7 - Gegner als spielerische Persönlichkeiten

- Gegneridentitäten bleiben während einer gesamten Partie auf stabilen UI-Sitzen.
- Sichtbare Tells reagieren ausschließlich auf öffentliche Ereignisse und erhalten
  niemals die verdeckte Hand als Eingabe.
- `BotObservation` begrenzt den Informationszugriff strukturell; Tests und Logs
  beweisen null Fremdhandzugriffe.
- Bot-Glaubwürdigkeit ist ein Produktgate: erfahrene Kartenspieler bewerten mindestens
  80 Prozent der Gebote in einem kuratierten Sample als plausibel.

- 11 freigegebene Charaktere mit normalisiertem Ausschnitt und stabilem Rahmen.
- Zustände: neutral, denkt, Druck, überrascht, siegt, verliert.
- Mimikwechsel als kurzer Cross-Dissolve/Morph mit identischer Blickrichtung und
  unverändertem Kopfmaß. Rahmen und Layout bewegen sich nicht.
- Mikrogesten: Blick zur Mulde, Einatmen vor Erhöhung, kurzes Zurücklehnen nach Pass.
- Kein Handstärke-Leak durch überdeutliche Reaktionen.
- Pro Tisch zufälliger Pool nach festgelegter Geschlechter- und Diversitätslogik.
- Namen und kulturelle Herkunft respektvoll und datengetrieben.

Done:

- Alle Charaktere bleiben über sechs Stimmungen identifizierbar.
- Kreisrahmen springt bei keinem Wechsel mehr als 1 px.
- Reaktion, Sprechblase und Botaktion ergeben einen einzigen zeitlichen Beat.

## 12. Gate 8 - Audio, Haptik und Ruhe

- Eigene akustische Identität pro Material: Karte, R1-Stein, Cent-Münze, Spielfeld,
  Messingkante, Poch-Schlag.
- Musik reagiert subtil auf Akt und Spannung, ohne Casino-Fanfaren.
- Stille wird bewusst vor Kettenriss, Showdown und letzter Karte eingesetzt.
- Audio, Haptik und sichtbarer Kontakt werden framegenau gekoppelt.
- Einstellungen: Musik, Effekte, Haptik, reduzierte Bewegung und reduzierte Effekte.

## 13. Gate 9 - Langzeitmotivation ohne Manipulation

### Kern

- Grundlage ist zuerst eine echte Partie: Quick über 12 Runden oder Classic bis
  weniger als drei zahlungsfähige Sitze verbleiben.
- Stehende Mulden, Geberrotation, stabiler Gegnerkreis und Matchstand erzeugen die
  kurzfristige Rückkehrmotivation innerhalb einer Partie.
- Es gibt keinen Rebuy, keine kaufbaren Chips und keine persistente Einsatzwährung.

- Gegnerkenntnis: Profile und faire Tells werden durch Spielen verständlicher.
- Tischchronik: stärkste Kette, größter Poch, knappster Sieg, besondere Runden.
- Meisterschaft statt Grind: Herausforderungen trainieren konkrete Poch-Fähigkeiten.
- Kuratierte Tagespartie mit gleichem Seed für alle, ohne künstliche Verknappung.
- Freischaltbare Kartenrücken, Tokenmaterialien und Bretter ohne Regelvorteil.
- Replay des besten Rundenmoments als kurze hochwertige Tischchronik.

### Überraschende Premium-Momente

- Das Brett merkt sich stehende Muldenwerte visuell über mehrere Runden.
- Gegner verfolgen einen großen Poch-Pott mit Blicken, bevor jemand bietet.
- Die Kartenhand sortiert sich auf Wunsch mit einer einzigen ruhigen Geste.
- Nach einer außergewöhnlichen Partie entsteht eine sammelbare Chronik-Plakette.
- Eine spätere physische Collector-Ansicht kann Maße und Materialien des realen
  Bretts zeigen. Sie ist kein Core-Loop- oder Launch-Gate.

Nicht übernehmen:

- Lootboxen, Fake-Fortschritt, Streak-Zwang, manipulatives FOMO, Energie-Timer,
  künstliche Wartezeiten oder Casino-Belohnungsloops.

## 14. Gate 10 - Technische und redaktionelle Exzellenz

- 60 FPS auf unterstützten Geräten; Instrumentation für Frame Drops bei Deal,
  Tokenhaufen und Kartenstrom.
- Swift-6-Concurrency ohne Warnungen.
- Deterministische Replays und Tutorial-Seeds.
- Vollständige DE/EN/FR/IT/ES/NL/PL-Lokalisierung aller sichtbaren Strings.
- VoiceOver-Reihenfolge entspricht visueller Hierarchie.
- Reduce Motion, Differentiate Without Color und Dynamic Type werden geprüft.
- Speicherbudget für Gegnerstimmungen, Karten und Boardassets definieren.
- Keine Runtime-KI, keine Runtime-Assetgenerierung.

## 15. Reihenfolge für die größten Sprünge

### Sprint A - Verständnis vor Schönheit

1. Ist-Zustandsinventur gegen Kapitel 3.
2. Echte MatchSource, stabiles Sitzmapping und Dead-Hand-Simulation.
3. BotObservation als Fairnessgrenze.
4. Presentation Director und tap-gesteuerte Tutorialbeats.
5. Neuer erster Start mit regelkonformem emotionalem Hook.
6. Erster kompletter Melden-Lernbeat inklusive Tokenkontakt.
7. Anfänger-Test und Korrektur.

### Sprint B - Pochen verständlich machen

1. Phase-2-Informationsarchitektur auf eine Entscheidung pro Moment reduzieren.
2. Eigener Gesamtbestand, gesetzter Betrag, möglicher Gewinn und Limit-Halter.
3. Materialiger Slider gegen diskrete Betragsstufen testen.
4. Gegnerantworten seriell und Poch-Tischschlag als Signatur.

### Sprint C - Physik glaubwürdig machen

1. Kartenflug neu modellieren.
2. Deterministische Token-Slots und kurze Transferwege.
3. Audio/Haptik auf Kontakt.
4. 60-FPS-Video- und Frame-Audit.

### Sprint D - Interaktion aufräumen

1. Buttonsystem vereinheitlichen.
2. Text-/Touch-/Localization-Matrix.
3. Phase-2-Komposition entstapeln.
4. Tutorial-Fokus ohne Überlagerungen.

### Sprint E - Drei Akte perfektionieren

1. Melden als Entdeckung.
2. Pochen als psychologisches Duell.
3. Ausspielen als lesbare Beschleunigung.
4. Rundenabschluss und Replaymoment.

### Sprint F - Charakter und Bindung

1. Gegner-Morphs und Gesten.
2. Audioidentität.
3. Tischchronik und Meisterschaftsziele.
4. Premium/Vivid-Abnahme.

## 16. Abnahme vor Award-Einreichung

- 10 unvorbereitete Spieler, davon mindestens 8 ohne externe Erklärung durch die
  erste Runde.
- Mindestens 8 können danach alle drei Akte korrekt beschreiben.
- Kein kritischer Layoutfehler in 7 Sprachen und 3 Geräteklassen.
- Keine Animation ohne Zweck; jede High-impact-Sequenz besitzt Frame-Audit.
- Stabile 60 FPS in Deal, Pochen, Kaskade und Endabrechnung.
- Tutorial in unter 8 Minuten, erste sinnvolle Entscheidung in unter 60 Sekunden.
- Freie Runde bleibt ohne Coach vollständig spielbar.
- App-Store-Screens und Preview zeigen echtes Gameplay, keine Marketingfiktion.

## 17. Sofortige nächste Arbeit

1. Bestehende First-Run-Automatik vor dem Deal durch einen ruhigen Einstieg ersetzen.
2. Tutorial-Melden in explizite, tappbare Subschritte zerlegen.
3. Deal im Tutorial nach der ersten Runde beschleunigen statt konstant durchzulaufen.
4. `GameActionButton` und `MaterialButton` einführen und alle sichtbaren Aktionen
   schrittweise migrieren.
5. `CoinStream` durch deterministische Token-Transfers mit realen Mulden-Slots ersetzen.
6. `FlyingBack` auf monotone Rotation und gedämpften Kontakt umstellen.
7. Danach Simulator-Video, Screenshots und Anfänger-Testskript erstellen.

## 18. Ausführungsarchitektur und Abhängigkeiten

Der Ausbau wird nicht als Folge isolierter Schönheitskorrekturen geführt. Vier
Arbeitsströme laufen parallel, besitzen aber feste Übergabepunkte:

### Strom A - Verständnis und Zustandslogik

- Presentation Director, Tutorialbeats, erlaubte Aktionen und Erfolgsbedingungen.
- Liefert stabile Zustände an alle anderen Ströme.
- Darf keine PochKit-Regel duplizieren oder verändern.

### Strom B - Bühne und Interaktion

- Mockup-nahe Komposition, gemeinsame Buttons, Coach, Gegnerplätze, Kartenhand.
- Arbeitet ausschließlich gegen reproduzierbare Zustände aus Strom A.
- Jede Änderung wird auf Standard-iPhone und kleinem iPhone geprüft.

### Strom C - Material und Bewegung

- Karten, Spielsteine, Kontakt, Audio, Haptik und Phasenübergänge.
- Beginnt erst, wenn Quelle und Ziel aus Strom B geometrisch stabil sind.
- Liefert Frame-Audits und Parameterwerte, keine frei verteilten lokalen Timer.

### Strom D - Bindung und Produktqualität

- Gegnerpersönlichkeiten, Chronik, Herausforderungen, Hilfe, Einstellungen,
  Premium/Vivid, Accessibility und Lokalisierung.
- Darf den ersten vollständigen Lern- und Spielloop nicht blockieren.

### Übergabegates

1. A -> B: Zustand besitzt eindeutige Primäraktion und sichtbare Ursache/Wirkung.
2. B -> C: Quelle, Ziel, Endframe und Z-Ebene sind eingefroren.
3. C -> QA: Dauer, Impact-Zeit, Mutation, Audio und Haptik sind protokolliert.
4. QA -> D: Drei Anfänger verstehen den Zustand ohne externe Erklärung.

## 19. Verbindliches Orchestrierungsregister

Alle Werte sind Startkorridore für Tests, keine Behauptung perfekter Millisekunden.
Der Presentation Director hält die final gewählten Werte zentral. Eine Änderung
braucht Vorher-/Nachher-Video und eine benannte Verbesserung.

| Moment | Tutorial | Freies Spiel | Impact | Ruhe danach |
| --- | ---: | ---: | ---: | ---: |
| Erster Kartenflug | 760-860 ms | 420-520 ms | bei Zielkontakt | 420-520 ms |
| Weitere Austeilkarte | 560-680 ms | 280-360 ms | bei Zielkontakt | 80-140 ms |
| Trumpf-Flip | 520-660 ms | 360-480 ms | bei 55-65 % | 650-900 ms |
| Einzelner Token | 620-760 ms | 480-620 ms | erster Muldenkontakt | 180-260 ms |
| Token-Gruppe | 720-920 ms | 580-760 ms | erster Kontakt | 260-420 ms |
| Gegnerentscheidung | 700-1.800 ms | 450-1.450 ms | Aktionsverb erscheint | 260-420 ms |
| Phasenwechsel | 900-1.300 ms | 680-960 ms | neue Bühne steht | 350-550 ms |
| Kettenkarte | 460-560 ms | 240-300 ms Einstieg, 180-220 ms geübt | Kartenkontakt | 0-60 ms |
| Kettenriss | 520-700 ms | 350 ms Freeze | mechanischer Stopp | 350-520 ms |
| Letzte Karte | 700-900 ms | 520-720 ms | Hand wird leer | 650-950 ms |

Regeln:

- Text erscheint nicht während des schnellsten Bewegungsdrittels.
- Zahlen mutieren beim Impact, nie am Start der Bewegung.
- Zwei High-impact-Sounds liegen nie näher als 120 ms zusammen.
- Jede Sequenz bleibt pausierbar; Fortsetzung startet vom sichtbaren Zustand.
- Reduce Motion behält Ursache, Ziel, Impact und Ergebnissatz, entfernt aber Flug,
  Shake, Parallaxe und unnötige Skalierung.

## 20. Zustands- und Abnahmematrix

Jeder Kernscreen wird nicht nur als Idealzustand geprüft, sondern mindestens in:

- leer, minimale Einsätze, hohe Einsätze und maximal plausible Tokenzahl,
- 3 und 4 Spieler; 5/6 erst nach eigenem Layout-Gate,
- menschlicher Zug, Botzug, alle passen, Erhöhung, Limit-Wand verschiebt sich,
- kurze und lange übersetzte Texte,
- Premium und Vivid,
- Standardtext, große Schrift, VoiceOver, Reduce Motion,
- Pause während Flug, Hintergrundwechsel, schneller Mehrfachtap,
- iPhone SE-Klasse, Standard-iPhone und Pro-Max-Klasse.

Automatisierbare Belege:

- Screenshot-Zustände über DEBUG-Launch-Argumente.
- Timeline-Logs mit Event, Quelle, Ziel, Impact und Mutation.
- Pixel-/Bounding-Box-Prüfung gegen Safe Areas und definierte Bühnenzonen.
- 60-FPS-Frame-Extraktion für Deal, Token, Kette und Abrechnung.
- String-Audit für DE, EN, FR, IT, ES, NL und PL.

## 21. Anfänger- und Spielgefühltests

### Verständnisstest

- Fünf unvorbereitete Personen für den ersten Iterationszyklus, später zehn.
- Kein mündliches Coaching durch das Team.
- Beobachtet werden Fehlertaps, Lesepausen, Rückfragen und falsche mentale Modelle.
- Nach jeder Phase: `Was war dein Ziel?`, `Was konntest du entscheiden?`,
  `Was hat sich verändert?`.

### Spielgefühltest

- Paarvergleich mit identischem Zustand und nur einer Timingänderung.
- Bewertung: verständlicher, gewichtiger, spannender, schneller wahrgenommen.
- Keine Änderung wird allein aufgrund eines Beauty-Screens freigegeben.

### Bindungstest

- Motivation entsteht aus Können, Gegnerkenntnis, Variation und Sammlung.
- Gemessen werden freiwillige nächste Runde, Wiederholung einer Lektion,
  Nutzung der Chronik und Rückkehr zu Herausforderungen.
- Keine Daily-Streak-Strafe, künstliche Verknappung, Lootbox oder Beinahe-Gewinn-
  Inszenierung.

## 22. Externes Review-Protokoll

Gemini wird als Sparringspartner eingesetzt, nicht als Art Director mit Vetorecht.
Jeder Review erhält Regeln, Mockup-Zweck, Anti-Casino-Kanon und einen konkreten
Screenshot beziehungsweise eng umrissenen Planabschnitt.

Getrennte Reviews:

1. FTUE und Tutorial aus Sicht eines völligen Poch-Neulings.
2. Phase-1/2/3-Komposition gegen das Mockup und `eine Bühne, ein Gedanke`.
3. Karten-/Tokenphysik und zeitliche Kausalität.
4. UI-System, Kontrast, Touch, Dynamic Type und Accessibility.
5. Gegnerpersönlichkeit und faire, nicht handabhängige Reaktionen.
6. Ethische Langzeitbindung und Meta-Progression.

Jedes Finding wird klassifiziert:

- `übernehmen`: regelkonform, belegbar und im Projektkanon.
- `experimentieren`: plausible Hypothese, braucht kleinen Prototyp.
- `verwerfen`: Regelbruch, Casino-/Dark-Pattern-Risiko, Scope-Bloat oder reine
  Geschmacksbehauptung.

## 23. Priorisierte Umsetzung in sechs Releaseschleifen

### Schleife 1 - Verstehen

- Presentation Director minimal einführen.
- Melden-Tutorial vollständig tap-gesteuert und wiederholbar machen.
- First Run bis erster Meldegewinn fertigstellen.

### Schleife 2 - Gewicht

- Kartenflug und Spielsteine mit echten Zielslots.
- Impact-synchrone Mutation, Audio und Haptik.
- Video-/Frame-Audit auf Standard-iPhone.

### Schleife 3 - Entscheiden

- Phase 2 auf eine Entscheidung pro Moment reduzieren.
- Range-Wand, Konsequenzvorschau und Gegnerantwort verständlich machen.
- Gemeinsames Buttonsystem ausrollen.

### Schleife 4 - Beschleunigen

- Phase 3 als lesbare Kette mit sauberem Riss und letzter Karte.
- Mockup-nahe zentrale Kartenkomposition.
- Abrechnung in drei kausalen Takten.

### Schleife 5 - Binden

- Gegnerreaktionen, Chronik, Herausforderungen und kosmetische Identität.
- Ethische Progression ohne FOMO oder Glücksspielverstärkung.

### Schleife 6 - Auszeichnen

- Sieben Sprachen, drei Geräteklassen, Accessibility, 60 FPS und Unterbrechungen.
- App-Store-Preview aus echtem Gameplay.
- Externer Blindtest und finaler Red-Team-Audit.

## 24. Definition des nächsten belastbaren Meilensteins

Der nächste Meilenstein ist nicht `mehr Screens`, sondern eine preiswürdige erste
Minute:

- ruhiger Einstieg ohne Einstellungen,
- erster eigener Tokenkontakt,
- verständlicher Deal mit großem Kartenrücken,
- Trumpf wird korrekt erklärt,
- sichere erste Meldung wird selbst ausgelöst,
- Herkunft, Bewegung und Gewinn sind ohne Zusatztext verständlich,
- alles ist pausierbar, wiederholbar und unter Reduce Motion nachvollziehbar.

Erst wenn dieser Meilenstein im Anfänger-Test besteht, beginnt die breite
Politur der restlichen Phasen.

## 25. Korrigierter Umsetzungsstand 12. Juli 2026

Vorhandenes Fundament, aber noch kein bestandenes Erlebnisgate:

- `PochKit.Match` treibt zwölf Runden, Geberrotation, stehende Mulden und Partieende.
- Bots erhalten eingeschränkte öffentliche Beobachtungen statt fremder Hände.
- First Run, geführte Runde, drei Akt-Screens, Hilfe, Einstellungen und Ergebnis sind
  technisch vorhanden.
- Der frühere Board-Stand, Kartensatz, Kartenrücken und Gegnerporträts sind technisch eingebaut; das Board ist kein aktueller Designanker mehr.
- Build, 50 XCTest-Fälle, 5 Swift-Testing-Fälle und 85 explizite Strings in sieben
  Zielsprachen sind grün.
- Simulatorzustände existieren für wesentliche Phasen und Geräteklassen.

Nach Code- und Erlebnisreview ausdrücklich wieder offen:

- Der First Run besitzt noch keine souveräne, selbstverständliche erste Minute.
- Gestartete und gelandete Karten beziehungsweise Token sind nicht sauber getrennt.
- Deal-Kadenz, Flugdauer und sichtbarer Kartenstand erzeugen überlappende Doppelbilder.
- Haptik und Zähler mutieren teilweise beim Start statt beim Materialkontakt.
- Token sitzen geometrisch besser in den Mulden, besitzen aber noch keine überzeugende
  überzeugende R1-/Cent-Materialität und Übergabe vom Flugobjekt in den ruhenden Haufen.
- Kartenmotiv und Kartenrücken sind brauchbar, die Bewegungs- und Kontaktphysik nicht.
- Curtain, Coach, HUD und Aktinformationen können zeitlich miteinander konkurrieren.
- Vivid-Farben, Kollaps-Burst, Floating Gain, Flash und Shake verletzen im Premium-Pfad
  teilweise den Material- und Anti-Casino-Kanon.
- Phase 2 besitzt noch zu viele gleichzeitig sichtbare Informationen.
- Anfänger-, VoiceOver-, Hardware-Haptik-, Audio- und Performance-Gates fehlen weiterhin.

Ab jetzt gilt: Kein Bereich ist wegen vorhandener Views oder grüner Builds fertig. Ein
Erlebnisgate ist erst bestanden, wenn der zugehörige Nutzerflow per Video, Timeline,
Frame-Audit und externem Verständnistest belegt ist.

## 26. Recovery-Ziel: der preiswürdige 60-Sekunden-Vertical-Slice

Die Abschnitte 26-35 ersetzen bei Widersprüchen die früheren Sprint- und
Statusformulierungen dieses Dokuments.

Bis dieses Gate bestanden ist, pausieren neue Meta-Funktionen, weitere Bretter,
zusätzliche Gegner, neue Kosmetik, Replay, Chronik-Ausbau und breite Vivid-Politur.

Der Slice umfasst ausschließlich:

1. App-Start und ruhiger Tisch-Reveal.
2. Bewusstes Platznehmen statt automatisch gestarteter Runde.
3. Erster eigener Glasstein mit Quelle, Fingeraktion, Kontakt und Ruhe.
4. Langsame erste Austeilrunde mit maximal zwei Karten gleichzeitig in der Luft.
5. Eigene Hand entsteht ausschließlich durch gelandete Karten.
6. Trumpf erhält einen eigenständigen Reveal mit anschließender Stille.
7. Eine garantierte, verständliche Meldung wird selbst erkannt und bestätigt.
8. Token verlassen die benannte Mulde, landen beim Gewinner und bleiben dort.
9. Ein Ergebnissatz erklärt Ursache und Wirkung in einem Satz.
10. Erst danach wird der Übergang zu `Pochen` angeboten.

North-Star-Satz:

> Der Spieler sieht jederzeit genau eine Ursache, verfolgt genau eine Bewegung, spürt
> genau einen Kontakt und versteht genau eine Wirkung.

## 27. Technische Transaktionsarchitektur

### 27.1 `PresentationDirector`

Eine zentrale `@MainActor`-Instanz besitzt die Präsentations-Timeline. Views rendern
Zustand und senden Intents, starten aber keine eigenständigen Sequenz-Timer.

Verantwortung:

- exklusiver Ablauf von Reveal, Flug, Impact, Mutation, Ruhe und Freigabe,
- Cancellation bei Pause, Hintergrundwechsel, Neustart und Aktwechsel,
- genau ein aktiver High-impact-Beat,
- Timeline-Logging mit Event-ID, Quelle, Ziel, Start, Impact, Mutation und Ende,
- Reduce-Motion-Ersatzablauf mit derselben Kausalität.

### 27.2 `ImpactFlight`

Gemeinsames Primitiv für Karten und Token:

- Start- und Zielgeometrie werden vor Start eingefroren,
- monotone, unterbrechbare Progression,
- `onImpact` feuert exakt einmal,
- kein Opacity-Verdunsten kurz vor dem Ziel,
- Flugobjekt und Zielobjekt wechseln im selben Frame,
- Audio und Haptik werden vom Impact ausgelöst,
- Cancellation kann weder doppelte Mutation noch verlorene Spielobjekte erzeugen.

### 27.3 Präsentierter Zustand

Engine-Wahrheit und sichtbare Wahrheit bleiben getrennt:

- `startedDeals` und `landedDeals`,
- gestartete und gelandete Melde-Token pro Quelle und Ziel,
- gestartete und gelandete Poch-Einsätze,
- gestartete und gelandete Kettenkarten,
- ausstehende und gelandete Straf-Token.

Regel: Engine-Zustand darf sofort korrekt sein. Sichtbare Hand, Haufen, Zähler und
Haptik ändern sich ausschließlich beim zugehörigen Impact.

### 27.4 Verbotene Muster

- kein neuer `Task.sleep` in SwiftUI-Views,
- kein lokaler Timer pro Flugobjekt,
- keine sichtbare Mutation beim Bewegungsstart,
- kein `opacity = 0` als Ersatz für Landung,
- keine Zufallsoffsets für Endpositionen,
- keine parallelen Coach-/Curtain-/Reward-Sequenzen ohne Director-Freigabe.

## 28. Parallele Arbeitsströme

### Strom A - Kausalität und Zustandsübergabe

Kritische Kette, hat Vorrang vor allen anderen Strömen:

1. `ImpactFlight` und Eventmodell.
2. Presented-Counter für Deal.
3. FlyingBack-Handoff in Hand und Gegnerstapel.
4. Presented-Counter und Handoff für Melde-Token.
5. Poch-Einsätze und Phase-3-Ströme migrieren.
6. Pause, Cancellation, Background und schneller Mehrfachtap absichern.

### Strom B - First Run und Tutorialregie

Kann parallel zu A mit statischen Zuständen und Mock-Daten arbeiten:

1. Startscreen auf eine Einladung und eine Primäraktion reduzieren.
2. Tisch zunächst ohne HUD, Hand, Gegnerwerte und Phasenlabel zeigen.
3. Relevante Elemente erst nach ihrer Erklärung einblenden.
4. Jeder Lernbeat besitzt Ziel, erlaubte Aktion, Erfolg und Rückholhinweis.
5. Fehler lassen das Objekt zurückkehren und formulieren denselben Gedanken neu.
6. Kein Auto-Advance; Weiter nur nach Impact und bewusster Bestätigung.
7. Skip-Pfad erhält einmalige kontextuelle Hinweise in der ersten freien Partie.

### Strom C - Materialsystem für Karten und Spielsteine

Kann parallel zu A experimentieren, integriert aber erst nach eingefrorener Geometrie:

1. `TableChip` bildet R1-Keramik beziehungsweise individuelle Cent-Münzen aus
   demselben Materialasset wie die Endlage ab.
2. Ein kontrollierter Materialreflex und harter Kontaktschatten statt Candy-Gradient.
3. Maßstab aus dem Board-Brief; identische Sprache im Flug und im Haufen.
4. Deterministische Slots für 1-12 Token pro äußerer Mulde und Mitte.
5. Vorderlippen-Occlusion und Innenmaskierung werden an die neue Poch Disc und die
   Unterwegs-Schale kalibriert.
6. Kartenwölbung reduzieren: Steifigkeit, dunkle Kontur, Kontakt statt Flattern.
7. Kartenfläche auditieren: reines Weiß ohne Grauschleier, sattes Rubinrot, kräftige
   Eckindizes, sichere Randabstände und lesbare Hofkarten in kleinster Spielgröße.
8. Kartenrücken groß und ruhig inszenieren; keine zusätzliche Art-Exploration.
9. Verbindlich sind die 8+1-Regelgeometrie und die beiden Tischwelten aus dem neuen
   Designkanon. Alte PM-Geometrie und Farbverteilung sind nicht eingefroren.

### Strom D - Komposition und progressive Disclosure

1. Zonen pro Gerät definieren: Header, Hauptbühne, Entscheidung, Gegner, Hand.
2. Phase 1: großes Brett, ruhiger Rand, Hand erst nach Deal sichtbar.
3. Phase 2: Brett oben rechts, Range links, eine Konsequenz und maximal zwei Aktionen.
4. Phase 3: zentrale Kartenkomposition, ruhige Gegner, Hand am unteren Rand.
5. Curtain endet vollständig, bevor Coach oder Entscheidung erscheint.
6. Geführte Runde ersetzt Curtain durch den Coach-Beat.
7. Kein Text verdeckt Quelle, Ziel, Hand, Mulde oder aktive Karte.
8. Buttonsystem auf Mindesthöhe, Textreserve und eindeutige Hierarchie prüfen.

### Strom E - Audio, Haptik und Rhythmus

Beginnt mit temporären, trockenen Sounds parallel; finale Mischung nach A/C:

1. getrennte Klangfamilien für Karte, Glas, Mulde, Tisch und UI,
2. Audio, Haptik und visueller Kontakt im selben Frame,
3. `heavy` ausschließlich für Poch-Tischschlag und große Abschlussmomente,
4. bewusste Stille nach erstem Token, Trumpf, Meldung, Kettenriss und letzter Karte,
5. Stummtest: jeder Impact bleibt visuell verständlich,
6. Hardwaretest: kein Haptik-Dauerfeuer bei Deal oder Strafstrom.

### Strom F - Produktqualität und Testsystem

Läuft ab dem ersten integrierten Slice kontinuierlich:

1. DEBUG-Zustände und reproduzierbare Seeds,
2. Timeline-Assertions für Impact vor Mutation,
3. Screenshotmatrix ohne generierte Dateien im Git-Archiv,
4. Frame-Extraktion für Deal, Meldung, Poch und Kette,
5. Layoutprüfung auf SE, Standard und Pro Max,
6. 60- und 120-Hz-Profiling,
7. VoiceOver-, Dynamic-Type-, Kontrast- und Reduce-Motion-Durchlauf,
8. DE/EN zuerst redaktionell perfektionieren; übrige Sprachen technisch grün halten.

## 29. Verbindliche Umsetzung des Vertical Slice

### Welle 0 - Baseline und Falsifikation

- Aktuellen First Run als 60-FPS-Video sichern.
- Timeline von App-Start bis erster Meldung protokollieren.
- Frames mit Doppelkarte, verschwindendem Token und überlagertem Text markieren.
- Fünf konkrete Verständnisfragen und den bisherigen Ausgangswert erfassen.
- Die bestehende erste Minute nicht weiter kosmetisch patchen.

### Welle 1 - Deal-Transaktion

- `ImpactFlight` einführen.
- Deal-Fenster von vier auf maximal zwei Karten reduzieren.
- Freies Spiel: Startkorridor 320 ms Kadenz, 420 ms Flug.
- Geführtes Spiel: erste Karten 760-860 ms, danach 560-680 ms.
- Rotation während Flug unter 12 Grad halten; kein Bounce.
- Zielkarte erscheint exakt im Impact-Frame.
- Haptik und sichtbarer Deal-Zähler wandern auf `landedDeals`.

### Welle 2 - Token-Transaktion

- `CoinStream` und alte Flying-Chip-Sonderlogik entfernen.
- Nächsten freien Zielslot vor Flugbeginn reservieren.
- Token fliegt flach, ändert maximal 20 Grad Lage und landet in Zielgröße.
- Erster Kontakt aktualisiert Zahl und Haptik; weitere Kontakte setzen den Haufen.
- Kompression 70-110 ms, maximal kleiner Seitenschlupf, danach Stillstand.
- Kein Ripple, kein Floating Gain, kein Partikel-Burst.

### Welle 3 - First-Run-Regie

- App startet nicht mit einer laufenden Runde.
- Primäraktion: `Am Tisch Platz nehmen` oder gleichwertig kurze Formulierung.
- Nur Tisch, eine Mulde und ein Token werden zuerst sichtbar.
- Spieler platziert den Token selbst.
- Nach Kontakt 420-600 ms Ruhe, dann erscheint der nächste Gedanke.
- Gegner, Hand, Trumpf und Regeln erscheinen erst nacheinander.
- Garantierter Tutorial-Seed liefert innerhalb von 45 Sekunden eine Meldung.

### Welle 4 - Markenbereinigung

- `Balatro`, `jackpot`, Kollaps-Burst, Floating Gain und Melde-Shake entfernen.
- Große Auszahlung nur durch Materialkontakt, Haufen-Setzen, Lichtkante und Ruhe zeigen.
- Vivid-Farben ausschließlich über die Theme-Auflösung beziehen.
- Premium nutzt matte Juwelentöne ohne Neon-Glow.
- Tisch-Shake bleibt exklusiv dem bewussten Poch-Klopfen vorbehalten.

### Welle 5 - Integrierter Slice

- Deal, Trumpf, Meldung und Tokengewinn über den Director verbinden.
- Kein neuer Text im schnellsten Bewegungsdrittel.
- Coach bestätigt Erlebtes, erklärt nicht vorab mehrere Regeln.
- Pause und Resume in jedem Beat testen.
- Reduce Motion nutzt Quelle-Puls, Ziel-Puls, Crossfade und Kontakt statt Flug.

## 30. Gates des Vertical Slice

### Gate VS1 - Räumliche Eindeutigkeit

- Quelle und Ziel sind vor jeder Bewegung sichtbar.
- Kein Ziel liegt unter Text oder Overlay.
- Keine Karte und kein Token existiert gleichzeitig als Flug- und Zielobjekt.

### Gate VS2 - Zeitliche Eindeutigkeit

- Mutation liegt im Impact-Frame plus/minus einen Frame.
- Maximal zwei Deal-Karten gleichzeitig in der Luft.
- Nach jedem High-impact-Moment existiert ein messbarer Ruhebeat.

### Gate VS3 - Materialglaubwürdigkeit

- Blindvergleich bewertet neue Karte und neuen Token häufiger als schwerer,
  physischer und hochwertiger als den Baseline-Stand.
- Kein Token überschreitet Muldenmaske oder Vorderlippe.
- Keine Karte flattert, verdunstet oder springt am Ziel.

### Gate VS4 - Verständnis

- 8 von 10 unvorbereiteten Personen erklären Melden, Pochen, Ausspielen und Mitte.
- 9 von 10 finden die Primäraktion innerhalb von zwei Sekunden.
- Erste sinnvolle Belohnung liegt innerhalb von 45 Sekunden.
- Median maximal ein Fehlertap pro Lernbeat.

### Gate VS5 - Zugänglichkeit und Technik

- Reduce Motion besteht denselben Verständnisstest.
- Slice ist mit VoiceOver vollständig bedienbar.
- Keine abgeschnittenen Texte auf drei Geräteklassen und sieben Sprachen.
- p95-Frametime bleibt unter 16,7 ms beziehungsweise 8,3 ms auf ProMotion.

Kein Gate darf durch subjektives `sieht besser aus` ersetzt werden.

## 31. Ausbau nach bestandenem Vertical Slice

### Akt 2 - Pochen

- Eine Entscheidung pro Moment: passen, mitgehen oder erhöhen.
- Risiko und möglicher Gewinn werden vor der Aktion in einem Satz sichtbar.
- Diskrete Einsätze gegen Slider im Nutzertest vergleichen.
- Gegnerantworten folgen räumlich und zeitlich der Tischreihenfolge.
- Poch-Klopfen als optionale Signaturgeste prototypen und auf Hardware testen.
- Botentscheidungen werden auf Plausibilität und Informationsleaks geprüft.

### Akt 3 - Ausspielen

- Nur legale Karten bleiben voll präsent.
- Spielkarte fliegt mit demselben Impact-Handoff wie im Deal.
- Kettentakt startet lesbar und beschleunigt erst nach sicherem Verständnis.
- Kettenriss nennt Herkunft des neuen Anspielrechts.
- Letzte Karte erhält einen eigenen Halt; Abrechnung startet danach.

### Partieabschluss

- Ergebnis erklärt Meldung, Poch, Mitte und Strafe kausal.
- Eine klare nächste Aktion, keine Kennzahlenwand.
- Partieökonomie bleibt geschlossen: keine Rebuys, keine persistente Einsatzwährung.

### Gegner

- Feste Sitzpositionen über alle Akte.
- Zustandswechsel behalten Ausschnitt, Blickrichtung und Kopfgeometrie.
- Reaktionen nur auf öffentliche Information.
- Mikroreaktionen selten, lesbar und unterbrechungsfrei.
- Sprechblasen nur für Signaturmomente, nicht als Dauerkommentar.

### Hilfe, Einstellungen und Tutorial-Hub

- Hilfe erklärt mit interaktiven Zuständen statt Textwänden.
- Einstellungen priorisieren Sound, Haptik, Assistenz, Motion und Kartenlesbarkeit.
- Tutoriallektionen sind einzeln wiederholbar.
- Kein Einstieg in die erste Partie über Einstellungen oder Menüs.

### Langzeitmotivation

- Meisterschaft, Gegnerkenntnis, Tisch-Chronik und Kosmetik statt FOMO.
- Tagesseed ohne Verluststrafe und zunächst ohne Leaderboard.
- Keine Streakpflicht, Lootbox, Beinahe-Gewinn-Inszenierung oder künstliche Knappheit.
- Meta-Ausbau erst nach bestandenem Core-Loop-Retentionstest.

## 32. Release- und Award-Reife

1. Vollständiger Motion-Audit jeder High-impact-Sequenz.
2. Audio-Endmischung auf Lautsprecher, Kopfhörer und Stummbetrieb.
3. Haptikabnahme auf mindestens zwei physischen iPhones.
4. Accessibility-Audit mit VoiceOver, Dynamic Type, Reduce Motion, Contrast und
   Reduce Transparency.
5. Lokalisierungsreview aller sieben Sprachen im echten Layout.
6. 30-Minuten-Soak-Test, Unterbrechung, Hintergrund, Speicherwarnung und Wiederaufnahme.
7. Externer Anti-Casino-Blindtest: häufiger `Strategiespiel`, `handwerklich`,
   `hochwertig` als `Casino`, `Slot`, `Poker-App`.
8. TestFlight-Kohorte mit Tutorialabschluss, Fehlertaps, freiwilliger nächster Runde
   und Rückkehr ohne manipulative Push- oder Streakmechanik.
9. App-Store-Video ausschließlich aus echtem Gameplay und bestandenen Gates.
10. Finales Red-Team-Review gegen Regeln, Architektur, Performance und Produktkanon.
11. Offline-Start, Save-Migration, Crash-Recovery, Speicher- und Thermiktest.
12. Privacy Manifest, Export Compliance, Altersfreigabe, StoreKit-Preis, Restore und
    Store-Metadaten gegen den produktiven Build prüfen.
13. App-Icon, Launch-Erlebnis und erster Store-Screenshot erzählen dieselbe ruhige
    Premium-Geschichte wie der Vertical Slice.

## 33. Parallelisierungs- und Merge-Regeln

- A besitzt `PresentationDirector`, Presented-State und Flugprotokoll.
- B besitzt Tutorialdaten, First-Run-Copy und Fokuszustände.
- C besitzt Token-/Kartenmaterial und Motionparameter, nicht die Timeline.
- D besitzt Layout und Komponenten, nicht Spielregeln oder Timer.
- E besitzt Sound-/Haptikbibliothek, ausgelöst ausschließlich durch A.
- F besitzt Tests, QA-Skripte und Abnahmebelege.
- Gemeinsame Dateien werden in kurzen Integrationsfenstern koordiniert geändert.
- Jeder Strom arbeitet auf einem reproduzierbaren DEBUG-Zustand.
- Integration erfolgt in der Reihenfolge A -> D -> C/E -> B -> F.
- Ein grüner Build ohne Gate-Beleg ist kein sinnvoller Merge-Meilenstein.

## 34. Abnahmebelege pro Meilenstein

Jeder sinnvolle Commit-/Push-Punkt enthält mindestens einen passenden Beleg:

- Logik: Test oder Timeline-Assertion,
- Layout: Screenshot auf SE, Standard und Pro Max,
- Motion: 60-FPS-Video plus Frame-Stichprobe,
- Audio/Haptik: Kontaktprotokoll und Hardwarecheck,
- Tutorial: Beobachtungsprotokoll eines unvorbereiteten Nutzers,
- Accessibility: dokumentierter Bedienpfad,
- Performance: Instruments-Messung der betroffenen Sequenz.

Die Umsetzung beginnt mit Welle 0 und endet nicht mit `alle Features vorhanden`,
sondern mit nachweisbar verständlichem, physischem und emotional geschlossenem Spiel.

## 35. Erste ausführbare Tickets und Parallelstart

Kritische Kette:

1. `A1` Baseline-Video und Timeline vom aktuellen First Run.
2. `A2` Eventmodell und `PresentationDirector`-Skeleton ohne sichtbare Änderung.
3. `A3` `ImpactFlight` mit Unit-Test für exakt einen Impact.
4. `A4` Deal auf started/landed umstellen und maximal zwei Flüge begrenzen.
5. `A5` Tokenflug und Zielhaufen auf dasselbe Handoff-Modell migrieren.
6. `A6` Deal, Trumpf und erste Meldung als eine pausierbare Sequenz verbinden.
7. `A7` Vertical-Slice-Gates VS1-VS5 ausführen.

Parallel ab `A1`:

- `B1` statischer First-Run-Storyboard-Prototyp mit exakt zehn Beats,
- `C1` drei codebasierte R1-/Cent-Materialproben im identischen Zielfeldzustand,
- `C2` Kartenlesbarkeitsmatrix in kleinster, normaler und Hero-Größe,
- `D1` Zonen- und Overlap-Audit für SE, Standard und Pro Max,
- `E1` trockene Kontaktklänge und Haptik-Mapping ohne Integration,
- `F1` DEBUG-Seed, Screenshotzustand und Timeline-Assertion für den Slice.

Integration:

- `B1`, `C1`, `C2`, `D1`, `E1` dürfen keinen eigenen Timer einführen.
- A friert die Transaktionsschnittstelle ein, danach integrieren C und E.
- D friert Zielgeometrien ein, danach wird die Flugbahn kalibriert.
- B setzt den Director-Ablauf zusammen, F prüft jeden Übergabepunkt.
- Nach `A7` entscheidet ein Anfänger-Test über Phase 2, nicht das Teamgefühl.

Stop-the-line-Kriterien:

- eine doppelte Karte oder ein verschwundener Token,
- sichtbare Mutation vor Kontakt,
- Text über Quelle, Ziel oder Hand,
- Premium-Screen mit unbeabsichtigtem Vivid-Glow,
- ununterbrechbare Sequenz,
- nicht reproduzierbarer Timingfehler,
- neuer Scope vor bestandenem Vertical Slice.
