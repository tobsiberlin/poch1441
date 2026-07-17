# Regel-, Seed- und Informationsgrenzen-Audit

Stand: 17. Juli 2026

## Ergebnis

Der aktuelle First-Run-Melden-Slice bleibt in der Engine regelkonform. Ante, Deal,
Trumpf und Meldungen stammen aus `PochKit.Round`; die App rekonstruiert lediglich
den noch nicht gelandeten sichtbaren Zustand. Beide ausgelieferten Meldeseeds
erzeugen eine frühe menschliche Meldung. Die feste Tutorialbesetzung und die
öffentlichen Tendenzmetadaten sind datengetrieben und handunabhängig.

Noch nicht vollständig integriert sind zwei Architekturgrenzen:

1. Die First-Run-Beatfolge ist semantisch korrekt, aber als Swift-Array und
   `switch` verdrahtet, nicht aus datengetriebenen Tutorialschritten geladen.
2. Die Regeltests pinnen die ausgelieferten Meldeseeds, lesen sie aber noch nicht
   direkt aus `TutorialScenarios.json`; eine abweichende JSON-Änderung würde daher
   erst im UI-/Integrationsgate auffallen.

## Regel- und Seed-Belege

- `PochKit/Sources/PochKit/Round.swift:25-67` zieht regelkonform neun Antes pro
  Spieler ein, erzeugt den Deal und zahlt Meldungen ausschließlich aus
  `Melding.meldOrder` aus.
- `App/GameState.swift:310-318` startet die Lernrunde über die normale Match-Quelle;
  kein View-Code erzeugt Karten oder Meldungen.
- `App/GameState.swift:956-993` trennt Engine-Wahrheit und sichtbare Wahrheit:
  gestartete Meldesteine verlassen ihre Mulde, Konten wachsen erst mit
  `meldShown`.
- `App/GameState.swift:1173-1197` mutiert `meldShown` erst nach dem vom
  `PresentationDirector` akzeptierten Impact.
- `App/TutorialScenarios.json:5-14` enthält die Meldeseeds `1444` für drei und
  `19` für vier Personen sowie getrennte Seeds für Pochen und Ausspielen.
- `PochKit/Tests/PochKitTests/TutorialScenarioTests.swift:8-32` belegt für Seed
  `1444` eine zuerst vom Menschen gewonnene Bube- und Zehn-Mulde.
- `PochKit/Tests/PochKitTests/TutorialScenarioTests.swift:38-80` belegt für Seed
  `19` Herz-Bube als offene Trumpfkarte sowie König, Dame und Mariage beim
  Menschen. Alle Auszahlungen entstehen aus unveränderten Runderegeln.
- Der First Run setzt vor der Lernrunde bewusst auf vier Personen
  (`App/ContentView.swift:833-840`), daher ist Seed `19` der aktive Produktpfad.

## Gegner- und Bluff-Integrität

### Bestanden

- Phase 2 besitzt eine echte strukturelle Grenze. `Round.botObservation(for:)`
  liefert nur für den aktuell handelnden Sitz eigene Hand, Trumpf, öffentliches
  Höchstgebot und eigenen Einsatz. Der `BotObservation`-Initializer ist
  PochKit-intern; `BotBrain.action` erhält keinen `Round`.
- Der Mirror-Vertrag in
  `PochKit/Tests/PochKitTests/BotBrainTests.swift:152-191` pinnt exakt diese vier
  Felder und die deterministische Entscheidung.
- Tells sind compile-time von Karten getrennt: `TellGenerator.PublicContext`
  enthält nur öffentliche Gebotswerte; die zugehörigen drei Tests sind grün.
- Die sichtbaren Phase-2-Moods werden aus `seatActions`, Zugstatus und öffentlichen
  Erhöhungen abgeleitet, nicht aus einer Hand.
- Die feste Besetzung Hana, Noah, Jonas liegt in
  `App/BotProfiles.json:93-97`; `GameState.applyCuratedTutorialLineup` lädt sie
  vor dem Tutorial (`App/GameState.swift:320-333`).
- `PublicOpponentTendency` erlaubt nur aggregiertes Entscheidungstempo oder
  Initiative und erzwingt Disclosure erst nach der ersten verstandenen
  Poch-Entscheidung (`App/OpponentRosterCatalog.swift:29-67`).
- Automatische und manuelle Auswahl sind als deterministische, stabile Module
  vorhanden (`App/OpponentRosterCatalog.swift:182-226`) und ihr isolierter
  Contract-Test ist grün. Die freie Tisch-UI integriert diese Auswahl noch nicht.

### Phase-3-Grenze Ende-zu-Ende aktiv

- `PlayoutBotObservation` enthält nur legale eigene Anspielkarten, offene
  Trumpfkarte, gespielte Karten und öffentliche Restkartenanzahlen
  (`PochKit/Sources/PochKit/BotProfile.swift:53-72`). Der Initializer bleibt
  PochKit-intern, damit App-Code keine beliebige Kartenmenge einschleusen kann.
- `PlayoutPhase.botObservation(for:)` gibt nur für den aktuellen Führer eine
  Observation aus und hält fremde Karten in der Engine
  (`PochKit/Sources/PochKit/Playout.swift:39-50`).
- `BotBrain.lead(observation:)` ist rein und bildet unverändert die bisherige
  Baseline `niedrigste legale Karte` ab (`BotProfile.swift:132-137`).
- Der Mirror-Test pinnt die vier erlaubten Felder. Ein zweiter Test baut zwei
  Welten mit verschiedenen Fremdhänden, aber identischer Observation, und beweist
  dieselbe Entscheidung (`BotBrainTests.swift:194-248`).
- `GameState.cascadeLoop` ruft ausschließlich
  `current.botObservation(for:)` und `BotBrain.lead(observation:)` auf. Pause und
  `round.applyLead` bleiben im App-Orchestrator; eine direkte Fremdhandabfrage im
  Entscheidungszweig existiert nicht mehr.
- Auch `MatchSimulator`, `pochsim balance` und `pochsim kollaps` wählen Karten nur
  aus `PlayoutBotObservation`; kein produktiver oder Headless-Botpfad entscheidet
  mehr direkt aus `PlayoutPhase.hands`.

## Tutorialregie-Abweichung

Die vier kanonischen Lernzustände und ihre Reihenfolge sind vorhanden
(`App/FirstRunPresentation.swift:3-77`). Der Ablauf ist jedoch doppelt im Code
verdrahtet:

- `FirstRunScript.steps` ist ein statisches Swift-Array
  (`App/FirstRunPresentation.swift:43-77`).
- `advanceGuidedMeld` ordnet Beatnummern per `switch` den Aktionen und Folgezuständen
  zu (`App/ContentView.swift:1334-1365`).

Damit ist die Handoff-Anforderung `datengetriebene Presentation-Director-Zustände`
noch nicht erfüllt. Der sichere nächste Schritt ist kein Regelumbau, sondern ein
versioniertes Tutorial-Szenario mit Beat-ID, Lernzustand, Fokus, erlaubter Aktion
und Erfolgsereignis. Seed und Beatregie können danach aus derselben Build-Time-Datei
geladen werden; PochKit bleibt alleinige Regelwahrheit.

## Ausgeführte Checks

- `swift test --package-path PochKit`: 52 XCTest- und 8 Swift-Testing-Fälle grün.
- `swift test --package-path PochKit --filter TutorialScenarioTests`: 2 Tests grün
  nach Ergänzung des Drei-Personen-Seeds.
- `swift test --package-path PochKit --filter BotBrainTests`: 8 Tests grün.
- `swift test --package-path PochKit --filter TellGeneratorTests`: 3 Tests grün.
- `swiftc App/OpponentRosterCatalog.swift Tests/OpponentRosterContractTests.swift`
  plus Ausführung: `PASS`.

Hardware-, VoiceOver-, Motion- und visuelle Gates gehören nicht zu diesem
Regelaudit und werden dadurch nicht ersetzt.
