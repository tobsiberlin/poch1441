# Poch 1441 - GOTY-2026-Masterplan

Stand: 11. Juli 2026

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
   Glas-Token. Quelle, Flug, Kontakt und endgültige Muldenposition sind nicht sauber
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
- Glas-Token bleiben flache Scheiben, keine Kugeln, Bonbons oder Pokerchips.
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

1. **Stille vor dem Spiel:** dunkler Tisch, Mitte und genau eine relevante
   Außenmulde, ein ruhender Glas-Token. Kein Phasenlabel, keine Gegnerwerte, keine
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
- Spieler legt den ersten eigenen Glas-Token selbst in eine Mulde.
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

## 8. Gate 4 - Glas-Token und Münzwanderung

### Verbindliches Tokenmodell

- Flache, schwere Glas-Spielsteine, etwa 22 mm Durchmesser und 4 mm Stärke im
  gedachten physischen Maßstab.
- Leicht transluzenter Körper, matter Kern, kontrollierte Kantenreflexion.
- Keine Kugeln, keine Jetons mit Casino-Streifen, keine perfekten Stapelsäulen.

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

- Eigene akustische Identität pro Material: Karte, Glas-Token, Keramikmulde,
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

- Karten, Glas-Token, Kontakt, Audio, Haptik und Phasenübergänge.
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
| Kettenkarte | 460-560 ms | 180 ms Takt | Kartenkontakt | 0-40 ms |
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

- Kartenflug und Glas-Token mit echten Zielslots.
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

## 25. Umsetzungsstand 12. Juli 2026

Technisch und visuell abgeschlossen:

- `PochKit.Match` treibt zwölf Runden, Geberrotation, stehende Mulden und Partieende.
- Bots erhalten eine eingeschränkte öffentliche Beobachtung statt fremder Hände.
- First Run beginnt am Tisch, formuliert das Ziel und startet die geführte Runde.
- Der erste Lernbeat zeigt nur Mitte und eine relevante Außenmulde; Fortschritt ist
  tap-gesteuert.
- Glassteine verwenden deterministische Ablageplätze innerhalb der Mulden. Flüge sind
  flach, Kontakt und Zustandsmutation zeitlich gekoppelt.
- Pochen besitzt getrennte Zonen für Range, Brett, Entscheidung, Aktionen, Gegner und
  Hand. 3 bis 6 Personen sind ohne Überlauf darstellbar.
- Ausspielen nutzt die Mockup-Hierarchie mit zentraler Kartenkomposition, Kettenstatus,
  Gegnerrahmen und Hand am unteren Rand.
- Hilfe, Tutorial-Hub, Einstellungen und Partieabschluss sind als gemeinsame
  Overlay-Familie umgesetzt.
- Kritische Karten-, Mulden- und Gegnerinformationen besitzen VoiceOver-Namen.
- iPhone 16 Pro und iPhone SE wurden per Simulator-Screenshot geprüft; der kompakte
  First Run besitzt ein eigenes Höhenlayout.
- Build, 50 XCTest-Fälle, 5 Swift-Testing-Fälle und die sieben Zielsprachen sind grün.

Noch nicht seriös als abgeschlossen markierbar:

- Der Anfänger-Blindtest mit mindestens fünf echten, unvorbereiteten Personen.
- Ein vollständiger VoiceOver- und Dynamic-Type-Durchlauf auf realer Hardware.
- Instruments-Messungen der vier High-Impact-Sequenzen auf 60- und 120-Hz-Geräten.
- Audio-Endmischung und Kontakt-Haptik auf einem physischen iPhone.
- App-Store-Preview und externe Anti-Casino-Assoziationsmessung.

Diese Punkte sind Release-Gates. Ein sauberer Simulator-Build ersetzt sie nicht.
