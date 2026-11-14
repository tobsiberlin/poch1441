# Poch 1441 - Masterplan für maximalen Spielspaß

Stand: 24.07.2026
Status: P0-Produktprogramm, noch keine Produktionsfreigabe

## Entscheidung

Poch braucht nicht mehr Spiel um das Spiel herum. Es braucht mehr lesbare Gegnerschaft, mehr persönliche Konsequenz und einen stärkeren Zug von einer Runde in die nächste.

Die interne Leitidee lautet:

> Poch ist das Spiel der offenen Rechnungen am Tisch.

Das ist keine sichtbare Werbezeile. Es ist die Regie für den Core Loop: Ein Rückzug lässt einen Topf wachsen, ein Gegner nimmt dir die Führung, eine verpasste Reihe wird zur Revanche. Jede neue Runde beantwortet etwas, das am Tisch offen geblieben ist.

## Was heute nachgewiesen ist

| Befund | Ergebnis | Bedeutung |
| --- | ---: | --- |
| Vorsichtiger Quick-Match | 12 Runden, etwa 13,7 bis 14,1 Minuten | Eine Unterbrechung ohne Save/Resume ist inakzeptabel |
| Größter Rundengewinn durch Melden | 29 % | Sofortgewinne tragen relevant bei |
| Größter Rundengewinn durch Pochen | 20 % | Risiko ist wichtig, aber nicht allein dominant |
| Größter Rundengewinn durch Ausspielen | 50 % | Phase 3 ist der größte strategische Spaßhebel |
| Runden mit Poch-Sieger | 99 % | Showdown und Rückzug müssen emotional unterscheidbar bleiben |
| Carry-over am Rundenanfang | p50 32, p90 60, max. 104 Chips | Das Spiel besitzt bereits einen natürlichen Revanchemotor |
| Passive Hand am Vierertisch | 0,46 % ohne Meldung und Paar | Vier Spieler bleiben der sichere Standard |
| Passive Hand am Sechsertisch | 11,82 % | Sechs Spieler erst nach eigenem Pacing-Test |
| Phase-3-Bots | alle wählen die niedrigste legale Startkarte | Größter nachgewiesener Langzeitmangel |
| Match-Fortsetzung | nicht vorhanden | Mobile P0-Lücke |

## Konsens der externen Reviews

Gemini und GPT wurden unabhängig mit demselben Code- und Simulationsstand beauftragt.

Beide stimmen in den entscheidenden Punkten überein:

1. Unterschiedliche, menschlich erkennbare Ausspielstile sind der größte Spaßhebel.
2. Ein einziger heißer Topf muss die nächste Runde emotional aufladen.
3. Das Rundenende braucht eine kurze Kausalgeschichte, keine weitere Datentafel.
4. Metriken wie Entscheidungen pro Minute oder „zweite Runde gestartet“ lassen sich leicht schönoptimieren.
5. Charakter entsteht zuerst durch Verhalten, erst danach durch seltene Reaktionen.
6. Daily Rewards, Grind und frühe Meta-Systeme würden das Kernproblem verdecken.

Die einzige relevante Gewichtungsdifferenz:

- Gemini priorisiert Save/Resume als erstes Mobile-P0.
- GPT bezeichnet Save/Resume korrekt als Schutz vor Spaßverlust, nicht als eigentlichen Spaßgenerator.

Die Auflösung: Gegnerprototyp und Save/Resume werden als zwei getrennte P0-Stränge geplant. Der eine erzeugt Spieltiefe, der andere schützt eine laufende Partie.

## North-Star-Erlebnis

Nach drei freien Runden soll ein Spieler aus eigenem Antrieb sagen können:

- „Hana geht früh ins Risiko. Diesmal lasse ich sie zahlen.“
- „Der König-Topf ist jetzt richtig voll. Den will ich in der nächsten Runde.“
- „Ich hätte die andere Reihe eröffnen sollen.“
- „Noch eine Runde. Das war knapp.“

Nicht ausreichend sind:

- „Ich weiß jetzt, welche Taste ich drücken muss.“
- „Die Animation war schön.“
- „Die App hat fast alles selbst gemacht.“
- „Ich habe weitergespielt, weil der Test noch lief.“

## P0-Strang A - Lebendige Gegner

### Ziel

Gegner werden nicht über Beschreibungen behauptet, sondern innerhalb von ein bis zwei Runden am Verhalten erkannt.

### Technischer Ansatz

Die bestehende Informationsgrenze ist bereits geeignet: Ein Bot kennt nur eigene legale Karten, offene Trumpfkarte, bereits gespielte Karten und öffentliche Resthandgrößen. Fremde Hände bleiben strukturell unzugänglich.

`BotBrain.lead` wird von einer einheitlichen Niedrigste-Karte-Regel zu einer profilierten, deterministischen Bewertung ausgebaut. `PlayoutBotObservation` erhält nur die zusätzlich notwendige eigene Sitzidentität, niemals fremde Karten.

### Vier Prototypstile

| Stil | Lesbares Verhalten | Öffentliche Heuristik | Ehrliche Schwäche |
| --- | --- | --- | --- |
| Läufer | versucht mehrere eigene Karten in einer Folge loszuwerden | eigene Anschlusskarten und eigene Handstruktur | gibt die Führung häufiger ab |
| Anker | startet an Assen, offenen oder bereits gespielten Bruchstellen | bekannte Kettenstopps | wird langsam leer |
| Jäger | verschärft das Spiel, wenn ein Gegner nur noch wenige Karten hält | öffentliche Resthandgrößen und bekannte Karten | nimmt dafür riskantere Starts |
| Opportunist | wechselt zwischen Tempo und Führung | eigener Rückstand, Matchstand, Hot-Pot-Lage | weniger klar spezialisiert |

Die Namen sind zunächst interne Begriffe. Die UI zeigt nicht „Hana ist ein Jäger“. Der Spieler soll es selbst erkennen. Erst nach mehrfach beobachtetem Verhalten darf eine knappe, faktenbasierte Tendenz erscheinen.

### Maschinen-Gates

- Mindestens 50.000 deterministische Matches über Sitzpositionen und Profile.
- Keine Nutzung oder Rekonstruktion fremder Hände.
- Pro Stil messbar unterschiedliche Verteilung von Startkartenrang, sofortigem Kettenstopp, Führungsbehalt, eigener Folgekartenquote und Risikowert.
- Unterschied statistisch sichtbar, aber kein Profil dauerhaft dominant.
- Sitzpositionen bleiben im langfristigen Fairnesskorridor.
- 60 FPS und keine zusätzliche Arbeit im Frame-Pfad.

## P0-Strang B - Eine offene Rechnung pro Runde

### Ziel

Zwischen zwei Runden bleibt genau eine verständliche Spannung offen.

### Vor der Runde

Maximal eine ruhige Tischzeile, zum Beispiel:

- „König: 12 Chips. Seit zwei Runden offen.“
- „Hana führt mit 8 Chips.“
- „Noch eine Runde bis zum Matchende.“

Keine Sport-TV-Tafel, kein erklärender Absatz und keine erfundene Dramatik.

### Während der Runde

Reaktionen erscheinen nur bei echten Wendepunkten:

- riskantes Erhöhen,
- aufgeflogener Bluff,
- unerwarteter Showdown,
- Reihenbruch bei nur einer Restkarte,
- Führungswechsel,
- Matchball.

Mimik und Körperreaktion kommen vor Text. Text bleibt selten, kurz und konkret.

### Nach der Runde

Der Rückblick dauert sechs bis acht Sekunden und beantwortet vier Dinge:

1. Wer gewann die Runde?
2. Welcher Zug entschied sie?
3. Was bleibt auf dem Brett?
4. Warum ist die nächste Runde interessant?

Beispielstruktur:

> Hana gewinnt die Mitte. Deine Kreuz-Reihe riss an der Dame. Der König-Topf wächst auf 12 Chips.

Danach direkt die nächste Handlung. Kein zusätzlicher „Verstanden“-Dialog.

### Datenmodell

PochKit erzeugt aus dem bestehenden Eventstrom ein wertfreies `RoundStory`-Modell:

- größte Auszahlung,
- Poch-Ausgang,
- knappster Resthandabstand,
- längste Reihe,
- entscheidender Reihenbruch,
- stärkster Carry-over,
- Führungswechsel im Match.

Die App formuliert daraus lokalisierbare UI-Texte. Regeln und Wertung bleiben im Kern.

## P0-Strang C - Mobile Kontinuität

### Ziel

Eine 14-minütige Partie überlebt Sperrbildschirm, Hintergrund, Prozessende und Neustart ohne Chip- oder Orientierungverlust.

### Architektur

Kein blindes Serialisieren lebender SwiftUI- oder Task-Zustände. PochKit erhält einen versionierten `MatchSnapshot`:

- Regelversion,
- Seed und Dealer,
- Matchmodus und Rundenzahl,
- Stacks und ausgeschiedene Sitze,
- Board und Carry-over,
- aktuelle Rundensitze,
- Poch-Aktionsfolge,
- Ausspiel-Aktionsfolge,
- Prüfsumme der Chipinvariante.

Die Runde wird deterministisch rekonstruiert und validiert. Die Präsentation springt auf einen stabilen Ruhepunkt, statt halb geflogene Karten oder Chips zu speichern.

### Gates

- Resume in jeder Phase und direkt vor sowie nach einem High-Impact-Moment.
- Exakte Übereinstimmung von Board, Stacks, Dealer, Händen, legalen Aktionen und Eventstrom.
- Ungültige oder alte Snapshots werden sicher verworfen und verständlich behandelt.
- Kein Verlust des Matches bei normalem iOS-Lifecycle.

## P0-Strang D - Agency ohne Bedienarbeit

### Leitregel

Drei gewichtige Entscheidungen sind besser als zwölf Bestätigungsbuttons.

### Interner Agency-Trace

Nur in InternalQA und zunächst lokal:

- Zeit bis zur ersten verstandenen Entscheidung,
- Zahl echter Wahlmöglichkeiten,
- automatische Zeit zwischen Entscheidungen,
- Entscheidung zurückgenommen oder wiederholt,
- Phasendauer,
- Abbruchpunkt,
- freiwilliger Start der nächsten Runde.

Der Trace zählt keine Weiter-Buttons als Agency. Er dient der Diagnose, nicht als Zielzahl.

### UI-Regel

Vor einer echten Wahl müssen erkennbar sein:

- Einsatz oder Gewinn,
- legale Optionen,
- unmittelbares Risiko,
- aktueller Gegenspieler.

Die UI darf keine „beste Karte“ markieren, sobald das Tutorial vorbei ist. Hilfen erklären Konsequenzen, lösen aber nicht die Strategie.

## Matchlänge

Der bestehende 12-Runden-Abend dauert etwa 14 Minuten. Das ist als vollständige Partie plausibel, aber nicht automatisch der beste Erstkontakt.

Zu testen sind genau zwei Varianten:

- Revanche: 6 Runden, Ziel etwa 7 Minuten.
- Abend: 12 Runden, Ziel etwa 14 Minuten.

Das wird zunächst als Testkonfiguration und nicht als überladenes Startmenü umgesetzt. Nach dem Tutorial führt ein einziger klarer CTA in die Revanche. Der längere Abend wird erst angeboten, wenn der Spieler das Spiel kennt.

## Menschliche Testregie

### Welle 0 - Build 13 als Baseline

Parallel zur technischen Arbeit werden fünf Poch-Neulinge beobachtet. Kein Coaching nach Start. Dokumentiert werden konkrete Aussagen, Abbruchpunkte und freiwillige Folgehandlungen. Prozentwerte aus fünf Personen werden nicht als Produktbeweis verwendet.

### Welle 1 - Kernprototyp

Mindestens zwölf neue Tester, zufällig auf Baseline und Prototyp verteilt. Aufgabenstellung und Beobachtertext bleiben identisch.

Grüne Signale:

- mindestens 9 von 12 starten aus eigenem Antrieb eine zweite freie Runde,
- mindestens 8 von 12 nennen einen konkreten Grund dafür,
- mindestens 8 von 12 beschreiben nach zwei Runden einen Gegner korrekt,
- mindestens 8 von 12 nennen einen eigenen Zug, den sie beim nächsten Mal ändern wollen,
- höchstens 2 von 12 sagen sinngemäß „die App spielt für mich“,
- mindestens 10 von 12 können nach dem Rundenrückblick Führung, heißen Topf und Grund der Auszahlung benennen.

### Welle 2 - Rückkehrsignal

Der grüne Prototyp geht an mindestens zwölf Personen für 24 Stunden. Keine Erinnerung, kein Bonus, keine Push-Nachricht. Eine freiwillige Rückkehr von mindestens sechs Personen ist ein starkes internes Signal, aber noch kein statistischer Retention-Claim.

## Was ausdrücklich nicht gebaut wird

- Daily Rewards, Energie oder Login-Serien,
- Grind-Währung,
- zufällige Beutekisten,
- versteckte Kartenvorteile,
- Gummiband-KI,
- Spruchgeneratoren für Gegner,
- ein großes Achievement-System vor grünem Core Loop,
- zusätzliche Regelmechaniken nur für künstliche Dramatik.

## Umsetzungsreihenfolge

1. Minimalen Agency-Trace spezifizieren, ohne den Botprototyp zu verzögern.
2. Vier Phase-3-Botstile in PochKit prototypisieren.
3. Profile headless simulieren und unfairen oder nicht unterscheidbaren Stil verwerfen.
4. `RoundStory` und einen einzigen Hot-Pot-Hook bauen.
5. Rundenende auf sechs bis acht Sekunden Kausalgeschichte verdichten.
6. Versioniertes Match-Snapshot und Resume implementieren.
7. Baseline und Prototyp mit Neulingen vergleichen.
8. Nur nachgewiesene Gewinner integrieren und Texte sowie Reaktionsfrequenz hart kürzen.
9. 12-Personen-Gate plus 24-Stunden-Rückkehrsignal durchführen.
10. Erst danach über Tischbuch, neue Gegnergruppen oder Schwierigkeitsstufen entscheiden.

## Blast Radius

| Bereich | Risiko | Hauptdateien |
| --- | --- | --- |
| Bot-Ausspielen | L2 | `PochKit/BotProfile.swift`, `GameState.swift`, Bot- und Simulatortests |
| RoundStory | L2 | neuer PochKit-Deriver, `Phase3View.swift`, Ergebnisdarstellung |
| Save/Resume | L3 | `Match`, `Round`, `Board`, App-Lifecycle, Migrationstests |
| Matchlänge | L2 | `BotMatchSource`, Match-Ende, Simulation |
| Reaktionen | L2 | Gegnerpräsentation, Audio/Haptik, Lokalisierung |

Save/Resume bleibt der einzige L3-Strang. Vor Dateiedits braucht er einen eigenen Snapshot-Vertrag, Migrationsstrategie und Fuzz-Test.

## Definition of Done

„Maximaler Spielspaß“ ist nicht erreicht, wenn zwei KIs den Plan gut finden. Er ist erreicht, wenn:

- der Regelkern und die Ökonomie simulationsgrün bleiben,
- Gegner für Menschen erkennbar verschieden spielen,
- Spieler konkrete eigene Absichten und Revanchegründe äußern,
- die App nie das Gefühl erzeugt, allein zu spielen,
- eine Partie Unterbrechungen zuverlässig überlebt,
- und echte Neulinge ohne Belohnungstricks freiwillig zurückkehren.

Bis dahin bleibt Langzeitmotivation ein offenes P0-Produkt-Gate.
