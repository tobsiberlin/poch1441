# Poch 1441 - Aggregation der externen GOTY-Reviews

Stand: 11. Juli 2026

## 1. Bewertungsgrundlage

Fünf externe Reviews wurden gegen `poch-spec.md`, den aktuellen Code, den
GOTY-Masterplan und die aktuellen Simulator-Screens geprüft. Mehrheitsmeinung ist
kein Freigabekriterium. Ein Finding wird nur übernommen, wenn es regelkonform,
projekttreu und durch Test oder Codebefund begründbar ist.

## 2. Starker Konsens - übernehmen

### P0 - echte Partie vor weiterer Meta-Politur

Der wichtigste technische Befund ist real: `BotMatchSource` erzeugt bei jeder
`newRound` eine neue Runde mit 60 Chips und leerem Board. Dadurch fehlen genau die
emotionalen Träger, die mehrere Reviews verlangen: stehende Mulden, gewachsener
Poch-Pott, Geberrotation, stabile Gegner und ein klares Matchende.

Entscheidung:

- `PochKit.Match` über den bestehenden Mapping-Plan integrieren.
- Quick-Partie bleibt regelkonform bei 12 Runden; Classic endet bei weniger als
  drei zahlungsfähigen Sitzen.
- Kein Rebuy, kein Echtgeld, keine persistente kaufbare Spielwährung.
- Gegneridentitäten bleiben über die ganze Partie an stabilen UI-Sitzen.

### P0 - Ist-Zustand gegen den eigenen Plan auditieren

Die aktuellen Screens verletzen Teile des Masterplans:

- numerische Tutorialbadges wie `1/5` und `3/5`, obwohl Erkenntnisfortschritt
  gefordert ist,
- zu viele bereits sichtbare Muldenlabels im ersten Lernbeat,
- Phase 2 zeigt mehrere konkurrierende Erklärungsebenen,
- Ergebnis nennt Zahlen, erklärt aber die Kausalität noch zu schwach.

Entscheidung: Schleife 1 beginnt mit einer vollständigen Zustandsinventur. Ein Todo-
Haken gilt nicht als UX-Beleg.

### P0 - Phase 2 radikal entstapeln

Alle Reviews identifizieren Pochen als kognitiv schwierigste Bühne. Gleichzeitig
sind Range, Brett, Pott, Konsequenz, Aktionen, Gegner und Hand sichtbar.

Entscheidung:

- pro Moment eine primäre Entscheidung,
- Range nur bei eigenem Zug und nur wenn eine freie Betragswahl existiert,
- Konsequenz vor der Aktion in einem Satz,
- Gegnerantworten seriell statt gleichzeitig,
- sichtbarer eigener Gesamtbestand getrennt vom bereits gesetzten Betrag,
- Antwortreihenfolge und Limit-Halter räumlich eindeutig.

### P0 - emotionaler Hook vor Regelvollständigkeit

Der First Run erklärt bereits Struktur, aber noch nicht ausreichend, warum der
Spieler den Tisch gewinnen will.

Entscheidung:

- ein sichtbarer, regelkonformer Carry-over wird früh als begehrenswertes Ziel
  inszeniert,
- keine erfundene Dramatik und kein Casino-Vokabular,
- die erste Belohnung bleibt unter 45 Sekunden,
- der Spieler erfährt früh: Außenmulden tragen weiter, die Mitte gehört zum
  Ausspielen.

### P0 - kognitive Accessibility

Dynamic Type und Reduce Motion reichen nicht. Neue Begriffe, Entscheidungen und
Modelle müssen dosiert werden.

Entscheidung:

- maximal ein neuer Kernbegriff pro Beat,
- Mulden lazy einführen, nicht alle neun frontal benennen,
- nach jedem Akt eine kurze aktive Rückversicherung statt Quizwand,
- Reduce Motion erhält eine eigene Quelle-Ziel-Pädagogik: Quelle markieren, Ziel
  markieren, Zustandswechsel, Impact-Haptik.

### P1 - Signature Moment festlegen

Der Poch-Tischschlag ist bereits im Projektkanon und der stärkste Kandidat für eine
unverwechselbare Signatur.

Entscheidung:

- expliziter Button bleibt für Auffindbarkeit und Accessibility,
- optionaler Doppeltap auf den Tisch kann nach dem Erlernen als direkte Geste dienen,
- tiefer Poch-Klang, schwerer Haptikimpuls, kurzer Tisch-Impact; HUD bleibt ruhig,
- nur bei Eröffnung oder charakterstarker Erhöhung, nicht inflationär.

### P1 - Gegner als Tischpräsenz, nicht als Mood-Sammlung

Porträts allein erzeugen keine soziale Spannung. Sitz, Blick, Antwortreihenfolge und
öffentliche Reaktion müssen gemeinsam erzählen.

Entscheidung:

- Gegner bleiben über eine Partie räumlich stabil,
- Reaktionen nur auf öffentliche Ereignisse,
- keine sichtbare Mimik darf mit verdeckter Handstärke korrelieren,
- seltene Blick-, Atem- und Haltungsmomente statt dauernder Sprechblasen,
- sechs Zustände bleiben Assetpool; im Spiel wird nur ein kleiner semantischer Satz
  davon verwendet.

### P1 - Bot-Glaubwürdigkeit als eigenes Gate

`BotBrain.action` greift aktuell nur auf die eigene Hand zu, erhält technisch aber
den vollständigen `Round` inklusive aller Hände. Die Fairness ist durch die aktuelle
Implementierung, nicht durch die API-Grenze garantiert.

Entscheidung:

- `BotObservation` einführen: eigene Hand, eigene Werte und ausschließlich öffentliche
  Informationen,
- BotBrain darf künftig keinen vollständigen Round erhalten,
- Entscheidungslogs beweisen 0 Fremdhandzugriffe,
- erfahrene Kartenspieler bewerten mindestens 80 Prozent der Gebote als plausibel.

### P1 - Dead Hands messen und gestalten

Hände ohne Meldung und ohne Poch-Berechtigung können bis Phase 3 passiv wirken. Die
Rate wurde am 11.7. mit je 100.000 deterministischen Deals gemessen:

- 3 Spieler: 0,00 %,
- 4 Spieler: 0,46 %,
- 5 Spieler: 4,20 %,
- 6 Spieler: 11,82 %.

Entscheidung:

- Messung als reproduzierbares `pochsim dead-hands`-Kommando erhalten,
- keine Regeländerung als automatische Antwort,
- bei fünf und sechs Spielern: Beobachtungsziele, Gegnerlesen, Carry-over-Spannung
  und schneller, klarer Übergang statt Fake-Entscheidung.

### P1 - Ergebnis erklärt Fairness

Rundenergebnis muss Gewinnherkunft getrennt zeigen:

1. Mitte,
2. Restkartenstrafen,
3. eigene Melde-/Pochbilanz,
4. neuer Matchstand.

## 3. Experimentieren - kleine falsifizierbare Tests

### Phase-2-Eingabe

Der vertikale Range-Regler ist eine bewusste Mockup-/Feel-Entscheidung und wird nicht
auf Zuruf entfernt. Verglichen werden:

- materialiger Slider mit harter Limit-Wand,
- diskrete Betragsstufen plus optionaler Feinschritt.

Messgrößen: erste korrekte Aktion, Fehlbedienung, Verständnis des Caps, empfundene
Wertigkeit. Kein Chip-Schnippen als einzige Eingabe.

### Tutorial-Bestätigung

- Variante A: expliziter Bestätigungstap pro Erkenntnis.
- Variante B: Fortschritt durch die tatsächliche Spielaktion.

Ziel: Verständnis ohne Tap-Through-Blindheit oder Bevormundung.

### Melden ohne Fake-Agency

Melden bleibt regelkonform automatisch. Im Tutorial kann vor der Auflösung eine
optionale Vorhersagefrage getestet werden. Sie darf nicht wie eine strategische
Entscheidung im echten Spiel dargestellt werden.

### Anfänger-Kettentakt

180, 240 und 300 ms werden als Video verglichen. Anfänger erhalten den langsamsten
Takt, bei dem 4 von 5 eine Sechserkette korrekt nacherzählen. Expertenmodus darf
schneller werden.

### Gegner-Art-Direction

Ein identischer Charakter wird photoreal und kontrolliert painterly mit denselben
sechs Zuständen geprüft. Kriterien: Identitätstreue, Uncanny Valley, Premiumwirkung,
Morphstabilität und Dateigröße.

### Premium und Vivid

Vivid bleibt eine explizite Nutzeranforderung, wird aber nicht als unabhängiges
Designsystem parallel erfunden. Premium wird zuerst abgenommen; Vivid leitet
Geometrie und Hierarchie ab. Semantiktest: Pott, aktiver Zug und Primäraktion müssen
gleich schnell gefunden werden.

### Suit-Accessibility

Das gelockte Standarddeck bleibt. Experimentiert wird mit optionalem
Vierfarben-/High-Contrast-Modus oder zusätzlichen Form-/Texturmerkmalen, nicht mit
einem ungefragten Austausch des Standarddecks.

## 4. Verwerfen oder korrigieren

### Verwerfen

- Gyroskop-Schatten auf Karten: Gimmick, Motion-/Performance-Risiko, kein zentraler
  Verständnisgewinn.
- Freies Token-Schnippen als Hauptsteuerung: unpräzise, schwer barrierefrei und
  widerspricht dem kalkulierbaren Bietsystem.
- Doppeltap als einzige Poch-Aktion: nicht auffindbar und nicht barrierearm.
- sichtbare Gegnerreaktionen auf `starke Hand`: wäre ein Hand-Leak. Reaktionen
  bleiben strikt öffentlichkeitsbasiert.
- passive 20-Sekunden-Demorunde vor der ersten Handlung: widerspricht direkter
  Beteiligung und Value-before-Explanation.
- vorgeschaltete Drei-Satz-Regelkarte: kann als optionale Schnellhilfe existieren,
  nicht als First-Run-Wand.
- `0 % Casino-Assoziation` als Metrik: unrealistisch für ein historisches Bietspiel
  mit Spielsteinen. Gemessen wird primäre Einordnung als Strategie-/Brettspiel und
  keine dominante Slot-/Roulette-Assoziation.
- Reaktionszeit unter 300 ms als Fitts-Law-Gate: vermischt Motorik und Verständnis.

### Bereits gelöst oder falsch gelesen

- Board-Texte sind SwiftUI-Overlays, nicht in das PM49-Artwork gebacken.
- `All-in` ist keine aktuelle Aktion; PochKit kennt nur Passen, Eröffnen, Mitgehen
  und Erhöhen innerhalb des Caps.
- Quick-Partie (12 Runden) und Classic-Modus sind im Regelkern definiert.
- Das Spielhallen-/Datenstrom-Mockup ist nur eine alte Layoutquelle und keine aktuelle
  Markenrichtung.
- Screens im Reviewpaket wurden als getrennte Debug-Zustände aufgenommen. Verschiedene
  Namen zwischen Bildern beweisen deshalb keinen Sitzsprung innerhalb einer Partie;
  der aktuelle Runden-Neustart mischt Gegner jedoch tatsächlich neu und wird durch
  Match-Integration behoben.

### Bewusste Nutzerentscheidungen bleiben bestehen

- sieben Sprachen bleiben Zielumfang; QA wird risikobasiert zuerst mit DE, EN und PL
  durchgeführt,
- elf produzierte Gegnerassets werden nicht gelöscht; für Tutorials und erste
  Partien wird ein kleiner kuratierter Satz eingesetzt,
- Vivid bleibt, folgt aber Premium statt parallel zu divergieren,
- die Slider-Richtung bleibt bis zu einem echten Vergleich offen, nicht aufgrund
  externer Geschmacksaussage verworfen.

## 5. Konsolidierte neue Reihenfolge

### Gate 0 - Fundament und Wahrheit

1. Ist-Screen-Inventur gegen `eine Bühne, ein Gedanke`.
2. [x] MatchSource auf echte `PochKit.Match`-Partien umgestellt.
3. [x] stabile UI-Sitzzuordnung und Gegneridentitäten.
4. [x] Dead-Hand-Simulation mit 400.000 Deals.
5. [x] `BotObservation` als Fairnessgrenze.

### Gate 1 - preiswürdige erste Minute

1. emotionaler Carry-over-Hook,
2. Tutorial ohne numerische Fortschrittsbadges,
3. lazy eingeführte Mulden,
4. erste selbst ausgelöste Meldung mit klarer Gewinnherkunft,
5. Sicherheitsnetz für Tutorial-Skipper.

### Gate 2 - Pochen verständlich machen

1. ein eigener Zug, eine Konsequenz, eine Primäraktion,
2. eigener Gesamtbestand sichtbar,
3. Range-/Stufen-Experiment,
4. Gegnerantworten und Limit-Halter räumlich stabil,
5. Poch-Tischschlag als Signatur.

### Gate 3 - Material und Timing

1. Kartenflug,
2. deterministische Token-Slots,
3. Impact-synchrone Mutation, Audio und Haptik,
4. Reduce-Motion-Kausalität,
5. 60-/120-Hz-Frame-Audit.

### Gate 4 - Ausspielen und Fairnessabschluss

1. getesteter Anfänger-Kettentakt,
2. Herkunft des neuen Anspielrechts,
3. letzte Karte als eigener Beat,
4. Ergebnis in kausalen Takten,
5. Matchstand statt isolierter Rundenzahl.

### Gate 5 - Bindung und Releasebreite

1. glaubwürdige Gegner und Stats-Chronik,
2. Premium zuerst, Vivid danach,
3. sieben Sprachen und Accessibility-Matrix,
4. Meisterschaftsaufgaben ohne Grind/FOMO,
5. breiter Blindtest.

## 6. Neue harte Abnahmekriterien

- 8 von 10 Neulingen erklären drei Akte und Mitte korrekt.
- 90 Prozent finden die Primäraktion in zwei Sekunden; Median unter einer Sekunde.
- Fehl-Taps im Tutorial unter einem pro Beat im Median.
- Dead-Hand-Rate ist dokumentiert und besitzt bei relevanter Höhe eine UX-Mitigation.
- 0 Fremdhandzugriffe in Bot-Entscheidungslogs.
- 80 Prozent plausible Botgebote im Expertenreview.
- Reduce Motion besteht denselben Verständnischeck wie Vollbewegung.
- 4 von 5 Erstsehern können eine Sechserkette korrekt nacherzählen.
- Jeder Impact ist im Stummtest eindeutig.
- Keine Layoutbrüche in sieben Sprachen und drei Geräteklassen.
- Testpersonen beschreiben Poch primär als Strategie-/Brettspiel, nicht als Slot-
  oder Rouletteprodukt.

## 7. Härteste Schlussfolgerung

Der größte nächste Qualitätssprung ist nicht mehr ein schönerer Shader. Er ist die
Verbindung aus echter mehr-rundiger Partie, verständlicher erster Minute und
glaubwürdiger Phase-2-Entscheidung. Erst diese drei Elemente geben Materialphysik,
Gegnern und Langzeitmotivation einen emotionalen Grund.
