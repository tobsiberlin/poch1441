# Poch 1441 - Parallele Orchestrierung First Run

**Stand:** 18. Juli 2026
**Basis:** `1e2e6da` auf `main`
**Ziel:** belastbarer Track-A-First-Run bis zur ersten selbst ausgelösten Meldung

Verbindlich sind in dieser Reihenfolge `tasks/HANDOFF-2026-07-17.md`,
`tasks/design-canon-2026.md`, `tasks/board-art-direction.md`, die Abschnitte 26-35
des GOTY-Masterplans und PochKit für jede Regelfrage. Alte Mockups und Render sind
nur Kompositions- beziehungsweise Regiereferenzen.

## Dateihoheit

| Spur | Exklusive Dateien | Darf nicht ändern | Status |
| --- | --- | --- | --- |
| Lead | `App/ContentView.swift`, `App/GameState.swift`, `App/ImpactFlight.swift`, `App/DesignTokens.swift`, `App/DealOverlay.swift`, `project.yml`, Integrationsdokumente | PochKit-Regeln ohne Regel-Spur-Review | Integriert: Director, acht Beats, adaptive Bühne und UI-Test-Target |
| Material | `App/PlayComponents.swift`, `App/Effects.swift`, neue Material-/Audio-/Haptikmodule und zugehörige Assets | Lead-Dateien, Timeline und PochKit | Integriert: R1, Endlagen, Keramikkontakt und gebündelte Haptik |
| Gegner | `App/BotProfiles.json`, neue datengetriebene Gegner-/Besetzungsmodule und eigene Tests | Lead-Dateien, verdeckte Karten oder Timeline | Teilintegriert: Hana/Noah/Jonas produktiv; Tendenzen und Auswahlmodule getestet, UI noch offen |
| QA | neue Dateien unter `tools/qa/`, `tasks/evidence/` und reine Test-/Auditdateien | Produktcode außerhalb eines koordinierten Integrationsfensters | Grün für den Integrationspunkt: Standardflows, echte Orientierungen und gehärteter AX-XXXL-Landscape-Gate |
| Regel | `PochKit/**`, `App/TutorialScenarios.json`, eigene Regeltests und Simulationswerkzeuge | Views, Nodes, Presentation Director und Layout | Grün: Seed 19, Meldungsbeleg und Bot-Informationsgrenzen |

Nur die Lead-Spur integriert Änderungen in `ContentView`, `GameState`,
`PresentationDirector` oder andere zentrale Ablaufdateien. Benötigte Hooks werden als
kleine Schnittstellen an Lead übergeben; keine Spur führt dort eigenständig Edits aus.

## Abhängigkeiten und Übergaben

1. Regel liefert einen reproduzierbaren Vier-Spieler-Seed und beweist die erste
   Meldung ohne Sonderregel sowie die bestehende Bot-Informationsgrenze.
2. Lead friert semantische Bühnenzonen, Lernzustände und Impact-Schnittstelle ein.
3. Material integriert R1-Darstellung, deterministische Endlagen und das
   Kontaktfeedback gegen diese Schnittstelle.
4. Gegner liefert feste Sitze sowie öffentliche, nicht handabhängige Tendenzen als
   Datenmodell; Lead bindet nur die sichtbaren Sitze ein.
5. QA prüft nach der zentralen Integration kompakte und große Geräte in Portrait und
   Landscape sowie Lokalisierung, VoiceOver, Reduce Motion und Overlaps.

## Abnahmekriterien erster Integrationspunkt

- Echte Track-A-Poch-Disc mit unveränderter 8+1-Geometrie in allen Lernzuständen.
- `Orientieren`, `Verbinden`, `Beweisen` und `Loslassen` sind semantische,
  reproduzierbare Director-Zustände ohne zeitgesteuertes Auto-Advance.
- Erster Kontakt, erste Karte, Trumpf und erste Meldung bilden je eine sichtbare
  Ursache-Ziel-Impact-Wirkung-Kette ohne Doppelobjekt oder Overlay-Kollision.
- Portrait und Landscape zeigen denselben bestätigten Lernzustand; Gegner bleiben auf
  stabilen Sitzen und Karten fliegen nie ins Leere.
- R1 landet in deterministischen natürlichen Endlagen; sichtbare Kompression,
  Zählermutation, Keramikkontakt und Taptic-Impuls liegen auf demselben Impact.
- Reduce Motion behält Quelle, Ziel, Impact und Ergebnissatz. VoiceOver benennt
  Lernziel, Primäraktion und Wirkung in sinnvoller Reihenfolge.
- Neue sichtbare Texte sind in DE, EN, FR, IT, ES, NL und PL vollständig.
- PochKit-Tests, App-Build, String-Audit und visuelle Interaktion auf mindestens einer
  kompakten und einer großen Geräteklasse bestehen; Landscape wird separat belegt.

## Integrationsreihenfolge

1. Lead: Director-/Lernzustand und adaptive Bühnenzonen.
2. Regel: Tutorial-Seed und Fairnessbelege.
3. Material und Gegner: kleine datengetriebene Schnittstellen, dann Lead-Anbindung.
4. QA: gezielte Assertions und Screenshotmatrix.
5. Vollständiger Build, Simulatorinteraktion, Portrait-/Landscape-Screenshots,
   Statusabgleich, Commit und Push auf `main`.

## Red-Team vor Implementierung

- Fragile Annahme: Die vorhandene geführte Runde lässt sich ohne Neuaufbau in echte
  Landscape-Zonen überführen. Früher Gegenbeleg ist ein kompakter Landscape-Screenshot.
- Kritischer Failure Case: Rotation während eines Impacts dupliziert Karte oder Token.
  Deshalb wird der semantische Zustand erst nach Impact umgelegt und per Timeline
  geprüft.
- Kritischer Regel-Fall: Ein scheinbar geeigneter Seed garantiert nur durch UI-
  Sonderlogik eine Meldung. Der Seed muss ausschließlich durch PochKit belegt sein.
- Aufwandsrisiko: `ContentView.swift` bündelt zu viele Zustände. Der Slice extrahiert
  nur datengetriebene Modelle und Layouthelfer; kein stilles App-weites Redesign.

## Laufender Status

- [x] Verbindliche Dokumente und Referenzscreens gelesen.
- [x] Worktree sauber; `HEAD`, `main` und `origin/main` stehen auf `1e2e6da`.
- [x] Dateihoheiten und Integrationsreihenfolge festgelegt.
- [x] Semantische First-Run-Zustände und adaptive Zonen integriert.
- [x] Material-, Gegner- und Regelübergaben integriert.
- [x] Gezielte Tests grün.
- [x] Vollständiger Build und visuelle QA bestanden.
- [x] Integrationspunkt committed und auf `main` gepusht.
- [x] Statuscockpit auf Designkanon 2026 reduziert; verworfene historische Meta aus
  Generator, Template und aktuellem Konzeptabschnitt entfernt.
- [x] Intro-Overlap auf kompaktem Portrait entfernt; Gegner, Disc, Ziel und Aktionen
  sind bei Accessibility XXXL getrennt und über Rotation getestet.

## Belege des ersten Integrationspunkts

- Statisches Strict-Gate: `python3 tools/qa/audit_first_run.py` - 0 Fehler,
  40 First-Run-Schlüssel in sieben Sprachen und acht Layoutkonfigurationen grün.
- UI-Test Standardgerät: zwei Tests, sieben Zustandsbilder, echte Scheibenaktivierung
  und Rotation von 402 x 874 auf 874 x 402 ohne Zustandsverlust.
- Geräte-Smokes: iPhone SE 375 x 667 / 667 x 375 und iPhone Pro Max
  440 x 956 / 956 x 440 jeweils in Portrait und Landscape grün.
- Visuell bestätigt: erster Kontakt mit Zähler 1, erste sichtbare Karte, volle Hand,
  Trumpf, Verbindungslinie, Meldungsbeweis und gelandete Meldung ohne Überlagerung.
- Noch physisch offen: Klang/Haptik auf echter Hardware sowie 60-/120-Hz-Profiling;
  Mapping, Lautstärkegrenze und gemeinsamer Impact-Trigger sind im Build integriert.
- Cockpit-Gate: 7-KB-Gegenwartsansicht aus fünf aktuellen Quellen; kein Treffer für
  verworfene Liga-, Gilden-, Prestige- oder alte Gegnerbegriffe.
- Accessibility-XXXL-Gate: Der frühere falsche Landscape-Pass wurde widerrufen und
  durch einen gehärteten Gate ersetzt. Der aktuelle Lauf belegt ein echtes
  `667 x 375`-Fenster, initiales Viewport-Containment, eine auf `68 pt` begrenzte
  Coach-Aktion sowie vollständiges Reveal. Der direkte Simulator-Framebuffer wird
  während des laufenden Tests erfasst und nur um die Metadrehung normalisiert.

## Zweiter Integrationspunkt - Tischwelten und Materialproben

**Ziel:** Das verworfene `Premium/Neon`-System wird durch die beiden kanonischen
Tischwelten `Poch Disc` und `Unterwegs` ersetzt. Vor der breiten Bühnenpolitur
entstehen zwei regelidentische, abnahmefähige Materialproben mit passenden
Spielsteinen und objektiven QA-Verträgen.

### Dateihoheit

| Spur | Exklusive Dateien | Darf nicht ändern | Status |
| --- | --- | --- | --- |
| Lead | `App/ContentView.swift`, `App/Theme.swift`, `App/TableWorld.swift`, `App/Phase2View.swift`, `App/Phase3View.swift`, `project.yml`, zentrale Integrationsdokumente | PochKit-Regeln ohne Regelreview | Integriert: Tischwelt-Seam, kanonische Migration und isolierter Track-B-QA-Pfad |
| R1-Material | `App/PlayComponents.swift`, `App/Effects.swift`, neue `Tests/R1Material*` | Lead-Dateien, Phase-Views, `GameState`, Track-B-Dateien | Integriert: R1-Verträge, Endlagen und kontaktgebündeltes Feedback |
| Track-B-Material | neue `App/TravelTableComponents.swift`, `App/TravelTableRenderer.swift`, `App/Assets.xcassets/Travel*`, neue `Tests/TravelTable*` | bestehende App-Dateien, Lead-Dateien, R1-Dateien | Runtime-QA: getrennte Schale/Münzen, deterministische Belegung; Produktauswahl noch offen |
| Ästhetik-QA | neue Dateien unter `tools/qa/` und `tasks/evidence/` | Produktcode, zentrale Tests und Projektkonfiguration | First Run und Track-B-Runtime auf kompakter/großer iPhone-Klasse grün |

Nur Lead integriert neue Komponenten in sichtbare Bühnen und migriert Aufrufer.
Nebenstränge committen und pushen nicht eigenständig.

### Abhängigkeiten

1. Lead definiert die kleine Tischwelt-Schnittstelle für Board, Spielstein,
   Hintergrund und Kontaktmaterial ohne Regelzustand.
2. R1 und Track B liefern isolierte Komponenten gegen diese Semantik; beide teilen
   ausschließlich die 8+1-Regelgeometrie und deterministische Slotanforderungen.
3. Ästhetik-QA prüft objektive Quellverträge und beschreibt getrennt die notwendige
   menschliche Material-, Typografie- und Kompositionsabnahme.
4. Lead integriert zuerst zwei Materialproben, danach die produktiven Bühnen. Der
   First Run bleibt bis zur ersten abgeschlossenen Partie fest auf Track A.

### Abnahmekriterien

- Keine sichtbare oder gespeicherte Produktoption `Premium`, `Vivid` oder `Neon`.
- Track A zeigt die echte Poch Disc auf ruhigem Graphitgrund; Waschbeton bleibt
  Splash, Store, Tischwahl und Abschluss vorbehalten.
- Track B besitzt eine markenfreie, glaubwürdig transparente oder leicht getönte
  8+1-Schale ohne Schrift im Artwork.
- R1 und 1-Cent-Münzen besitzen unterscheidbare Materialien, deterministische
  natürliche Endlagen sowie kontaktgenaues, materialspezifisches Feedback.
- Keine gemischten Nennwerte, Eurobeträge, Spielerfarben oder verdeckte Information
  durch Materialvarianten.
- Beide Materialproben bestehen die Größen 360, 180, 120 und 64 px sowie kompakte
  und große Geräteklassen in Portrait und Landscape.
- Typografie skaliert tatsächlich; ein Accessibility-Test darf nicht nur identische
  feste Punktgrößen in einem größeren Systemzustand bestätigen.
- Subjektive Qualität wird nicht durch statische Tests behauptet: Screenshots werden
  zusätzlich nach Hierarchie, Rhythmus, Materialglaubwürdigkeit, Kontrast und Ruhe
  menschlich abgenommen.

### Integrationsreihenfolge

1. Lead: `TableWorld`-Seam und Entfernung der alten Theme-Semantik.
2. R1 und Track B: isolierte Materialkomponenten und Vertragstests.
3. Lead: zwei DEBUG-Materialproben und produktive Anbindung ohne Regeländerung.
4. QA: Größenmatrix, Dynamic Type, Reduce Motion, Kontrast und Screenshots.
5. Vollständiger Build, Statusabgleich, Commit und Push auf `main`.

### Sichtentscheidungen

Wenn menschliche Material-, Kompositions- oder Freigabeentscheidungen anstehen,
erzeugt Lead eine kompakte HTML-Abnahme, kopiert sie nach
`/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/` und öffnet sie
automatisch. Chatbeschreibungen ersetzen keine sichtbare Abnahme.

### Aktueller Nachweis

- First-Run-Intro auf iPhone SE bei Accessibility XXXL in Portrait und Landscape:
  kompakte lokalisierte Sichtcopy, vollständige VoiceOver-Labels, keine Ellipsen,
  erreichbare getrennte Aktionen und konfliktfreie Gegner-/Disc-Zonen. Die
  AX-XXXL-Lernbühne nutzt für Board, Coach und Hand eine sequenzielle Scrollachse;
  Portrait ist interaktiv grün, der separate Landscape-Gate bleibt streng offen.
- Phase 3 verwendet `PlayoutBotObservation`; zwei verborgene Welten mit derselben
  öffentlichen Observation erzeugen nachweislich dieselbe Botentscheidung.
- Track B besitzt keine statische Münzszene: Schale und sechs 1-Cent-Varianten liegen
  getrennt mit Alpha vor, Belegung und Endlagen entstehen deterministisch im Renderer.
- Die Track-B-Runtime-Probe besteht iPhone SE und iPhone 17 Pro Max jeweils in
  Portrait und Landscape. Bei 360 px sind Material, 8+1-Topologie und Labels lesbar;
  bei 180 px bleibt die Belegung brauchbar, 120 px trägt Topologie und Münzen, 64 px
  bewusst nur die über Accessibility vollständig benannte Silhouette.
- `audit_travel_assets.py` meldet 72 bestandene Assetverträge ohne Fehler;
  `audit_visual_contracts.py` meldet 11 bestandene Verträge und keine Fehler. R1-
  und Track-B-Vertragstests sowie der vollständige Debug-Simulatorbuild sind grün.
- Die verworfene PM100-/PM68-Boardstudie und das ungenutzte `GameTokenGlass`-Material
  sind nicht nur unerreichbar, sondern aus dem produktiven App-Baum entfernt; das
  visuelle Gate behandelt jede Rückkehr als Fehler.
- Die Track-B-Runtime-Probe ist ausschließlich über `-travelTableProbe` in DEBUG
  erreichbar. Die kanonische Auswahl nach der ersten abgeschlossenen Partie ist der
  nächste Produktintegrationspunkt und wird nicht in den First Run vorgezogen.
- Der zweite Integrationspunkt ist damit verifiziert und auf `main` veröffentlicht.
  Die frühere AX-Landscape-Lücke ist inzwischen durch einen separaten strengen Gate
  mit echtem Landscape-Frame geschlossen.

## Dritter Integrationspunkt - Daten- und Informationsgrenzen

- Tutorial-Seeds werden im PochKit-Test direkt aus `App/TutorialScenarios.json`
  geladen. Vier Verträge prüfen Schema, Vollständigkeit und die semantischen
  Meldungs-, Poch- und Ausspielziele; insgesamt sind 54 XCTest- und acht
  Swift-Testing-Fälle grün.
- Intro und geführte Partie lesen Hana, Noah und Jonas aus demselben validierten
  Gegnerkatalog. Fehlerhafte oder unvollständige Daten starten keine zufällige
  Ersatz-Tutorialrunde; der Director wechselt erst nach erfolgreicher Übernahme.
- App-Views erhalten nur die eigene sichtbare Hand, gegnerische Kartenanzahlen und
  bereits enthüllte Spielereignisse. Vollständige Gegnerhände und zukünftige
  Zwangskarten bleiben hinter `GameState`; ein eigenständiger Quellvertrag sperrt
  die Rückkehr der früheren breiten APIs.
- Der vollständige First-Contact-/Lernzustands-UI-Test ist nach der Migration grün;
  der Simulatorbuild und der eigenständige Gegnerkatalog-Contract bestehen.
- Als nächster Produktintegrationspunkt folgt die gemeinsame Board-/Material-
  Rendererschnittstelle. Erst danach wird `Wähle deinen Tisch` freigeschaltet, damit
  Track B niemals Track-A-Geometrie oder R1-Steine mit Cent-Material mischt.

## Vierter Integrationspunkt - gemeinsame Materialkante der Tischwelten

**Ziel:** Phase 1, Phase 2 und Phase 3 verwenden für Brett, ruhende Steine und
Steinflüge dieselbe erschöpfende `TableWorld`-Schnittstelle. Track B bleibt bis zum
materialspezifischen Audio-/Haptik-Gate ausschließlich über DEBUG erreichbar.

### Dateihoheit und Status

| Spur | Exklusive Dateien | Abhängigkeit | Status |
| --- | --- | --- | --- |
| Lead | `App/ContentView.swift`, `App/Phase2View.swift`, `App/Phase3View.swift`, `App/TableWorld.swift`, `project.yml`, dieses Dokument | Material-Seam und QA-Verträge | Integriert: zentrale Phasen 1-3 und DEBUG-Weltwahl |
| Material | `App/PlayComponents.swift`, `App/TravelTableRenderer.swift`, `App/R1TokenLayout.swift`, zugehörige Materialtests | kanonische 2026-Disc, R1- und Travel-Renderer | Integriert: 2026-Disc statt PM49, zwölf deterministische R1-Endlagen und getrennte Travel-Münzen |
| QA | `Tests/Poch1441UITests/TableWorldStageUITests.swift`, `Tests/Poch1441UITests/FirstRunUITests.swift`, `tools/qa/`, `tasks/evidence/` | Lead-Accessibility-Identifier und generiertes UI-Test-Target | Grün: Track A und B in Phase 1/2, echte 667 x 375-Fenster sowie AX-XXXL-Landscape |
| Regel | keine Änderung | unveränderte Pool-/Zählersemantik aus PochKit | Unberührt; Material erhält nur vorhandene Counts und Compartments |
| Gegner | keine Änderung | stabile öffentliche Sitze aus dem dritten Integrationspunkt | Unberührt; Phase-2-Sitze im Runtime-Beleg sichtbar |

### Abhängigkeiten und Abnahmekriterien

1. `TableWorldBoardBase` enthält ausschließlich die nackte 2026-Poch-Disc oder die
   freigegebene TravelTray-Schale. Semantische Zählstände bleiben in zentralen
   Overlays und werden nicht in Assets dupliziert.
2. `TableWorldPiece` und `TableWorldPiecePile` wählen erschöpfend R1-Naturweiß oder
   eine deterministische der sechs freigegebenen 1-Cent-Oberflächen. Es gibt keinen
   Track-B-Fallback auf R1 und keine Veränderung des semantischen Counts.
3. Phase 1, kompakter Phase-2-Ring, Poch-Flüge sowie Phase-3-Ergebnis- und
   Strafströme führen die gewählte Welt durchgehend mit. Der geführte erste Tisch
   bleibt unabhängig vom DEBUG-Probeparameter fest Track A.
4. Der echte UI-Test startet Track B getrennt in Melden und Pochen, verlangt das
   jeweilige Board im Fenster und hält beide Render als Screenshot fest. Die
   visuelle Abnahme prüft Material, Lesbarkeit, Karten-/Board-Rhythmus und
   Kollisionen; der optionale freie Zug-Begleiter wird für diese Materialprobe
   explizit deaktiviert und nicht fälschlich als Boardbestandteil bewertet.
5. `TravelTray` deckt die heutige iPad-2x- und große iPhone-3x-Matrix ab. Die knappe
   iPad-Reserve und der nicht gedeckte zukünftige volle 620-pt-3x-Cap bleiben als
   zwei explizite Risiken sichtbar und werden bei `--require-full-cap-3x` hart.
6. Die AX-XXXL-Lernbühne muss in echtem SE-Landscape `667 x 375`, mit vollständiger
   deutscher Semantik, erreichbarer Coach-Aktion, drei stabilen Gegnern und ohne
   paarweise Overlaps bestehen.

### Integrationsreihenfolge und aktueller Nachweis

1. Material-Seam isoliert implementieren und durch Quellverträge absichern.
2. Lead migriert Phase 1, Phase 2 und Phase 3 ohne Regel- oder Zähleränderung.
3. QA verankert UI-Tests über das versionierte `project.yml`, führt echte Runtime-
   Starts aus und nimmt die Screenshots menschlich ab.
4. Vollständigen App-Build, Material-/Asset-/Visual-Audits und relevante First-Run-
   Regressionen ausführen; danach Status synchronisieren, committen und pushen.
5. Nächster Integrationspunkt: kupferspezifisches Kontakt-Audio und Haptik-Mapping.
   Erst danach folgt die produktive Tischwahl nach der ersten abgeschlossenen Partie.

Aktuell belegt: Track-B-UI-Test `1/1` in Phase 1 und 2; Gravuren liegen auf dem
inneren Steg statt auf Münzhaufen oder außerhalb der Schale. Track A nutzt die neue
satinierte 2026-Disc in First Run sowie Phase 1-3. Der Standard-Track-A-Test belegt
Portrait und ein echtes `667 x 375`-Landscape-Fenster in Melden und Pochen ohne
Überlagerung. Der AX-XXXL-Gate belegt auf demselben SE-Fenster einen initial
vollständigen Gegner-/Disc-Frame, eine auf `68 pt` begrenzte Coach-Aktion und die
vollständig revealbare Hand. Der direkte Simulator-Framebuffer wird während des
laufenden Tests aufgenommen und nur um die Simulator-Metadrehung normalisiert.
Die Tischwahl ist weiterhin absichtlich nicht produktiv sichtbar.

## Fünfter Integrationspunkt - R1-Maßstab und natürliche Endlagen

**Ziel:** Die R1-Steine lesen sich auf großer und kompakter Track-A-Disc als dasselbe
physische 36-mm-Objekt. Kein Stein wird durch Muldenmasken abgeschnitten; Licht,
Kontakt und Haufenform bleiben materiell plausibel statt wie ein UI-Overlay.

### Dateihoheit und Abhängigkeiten

| Spur | Dateien | Abhängigkeit | Status |
| --- | --- | --- | --- |
| Lead | `App/ContentView.swift`, `App/Phase2View.swift`, `App/DesignTokens.swift`, dieses Dokument | übergibt denselben Disc-Maßstab an Außenmulden und Mitte | Integriert |
| Material | `App/PlayComponents.swift`, `App/R1TokenLayout.swift` | kanonische R1-Geometrie und bestehende 8+1-Topologie | Integriert |
| QA | `Tests/R1MaterialContractTests.swift`, `Tests/R1TokenLayoutTests.swift`, Track-A-UI-Test | vier echte Phase-1/2-Simulatorzustände | Grün |

Nur Lead änderte die zentralen Phase-Views. Material blieb auf Darstellung,
deterministische Slots und die kleine Durchmesserübergabe begrenzt; PochKit,
`GameState` und der Presentation Director blieben unverändert.

### Abnahmekriterien und Nachweis

- R1 misst rund 41 % der Außenmuldenöffnung und skaliert in Phase 2 mit der Disc.
  Außenmulden und Mitte verwenden innerhalb derselben Disc denselben Durchmesser.
- Vier vorbereitete kompakte Haufentypen liefern unter den vier belegten
  Startmulden mindestens drei nicht-kongruente Silhouetten. Bereits gelandete
  Positionen bleiben bei `n -> n+1` unverändert und vollständig im Boden.
- Signet und materialgebundene Details rotieren, Weltlicht und Kontaktschatten nicht.
  Das breite Gruppenschatten-Oval ist entfernt; die vordere Muldenlippe bleibt lokal.
- Der unabhängige P0-Bildvergleich besteht relative Größe, Phase-2-Clipping,
  Schattenoval, Lippe und Haufenvariation in Portrait. Die finalen Landscape-Bilder
  wurden zusätzlich menschlich auf dieselben Kriterien geprüft.
- `R1TokenLayoutTests`, `R1MaterialContractTests`, Swift-Parse und `git diff --check`
  sind grün. Der echte Phase-1/2-UI-Test besteht Portrait und `667 x 375` Landscape
  mit vier Screenshots. Ein XCTest-Leerlaufproblem verlängerte den finalen Lauf auf
  1.250 Sekunden, ohne Assertion-, Layout- oder Buildfehler; das bleibt als
  Infrastruktur-Risiko sichtbar.

Noch offen für den nächsten Integrationspunkt: Die R1-Oberfläche braucht eine echte
Build-Time-Mikrotextur statt weiterer prozeduraler Effekte. Der erste KI-Assetlauf
wurde wegen eingebranntem Checkerboard und fehlendem Alpha verworfen und nicht ins
Repo übernommen. Die zuvor offene linke Fläche in Phase-1-Landscape wird im sechsten
Integrationspunkt als feste Gegnerachse aufgelöst.

## Sechster Integrationspunkt - räumliche Track-A-Disc

**Ziel:** Die kanonische Disc übernimmt Materialität, Feinheit und leichte Bauhöhe
der bestätigten Nahreferenz, bleibt aber als orthografische 8+1-Basis exakt genug
für kontaktgenaue Overlays. Der Gameplay-Grund bleibt ruhiges Graphit; Sichtbeton
bleibt der emotionalen Produktinszenierung vorbehalten.

### Dateihoheit, Abhängigkeiten und Status

| Spur | Dateien | Abhängigkeit | Status |
| --- | --- | --- | --- |
| Lead | `App/ContentView.swift`, `App/Phase2View.swift`, `App/DesignTokens.swift`, `tasks/reviews/track-a-current-state-2026-07-18.html`, dieses Dokument | zentrale Board-Komposition, gemeinsame räumliche Kamera, Gegnerachse | Integriert |
| Material | `App/PlayComponents.swift`, `App/Assets.xcassets/PochDisc2026.imageset/poch-disc-2026.png` | gesperrte 8+1-Geometrie und Referenz `SCR-20260718-iilg.png` | Integriert: RGBA-Disc mit satinierter Deckkante, dunkler Unterkante und lokaler Mulden-AO |
| QA | `Tests/Poch1441UITests/TableWorldStageUITests.swift`, `Tests/TableWorldMaterialSeamContractTests.swift`, `tools/qa/audit_visual_contracts.py` | stabile Accessibility-Identifier und Material-Seam | Grün: Phase 1/2 in Portrait und echtem `667 x 375` Landscape |
| Gegner | keine zentrale Dateiänderung | öffentliche Namen und Stapelstände aus bestehender Präsentation | Integriert: feste linke Phase-1-Landscape-Achse |
| Regel | keine Änderung | unveränderte Pool-Anker und Zählstände | Unberührt |

### Abnahmekriterien und Nachweis

- Das Rasterasset ist `1254 x 1254` RGBA mit transparenten Ecken, acht leeren
  Außenmulden, leerer Mitte und zwei feinen konzentrischen Führungslinien. Es trägt
  weder Text noch Spielsteine; Semantik und Zustand bleiben in der UI-Ebene.
- Der äußere satinierte Aluminiumring besitzt eine sichtbare geschichtete Unterkante
  auf dem unteren Bogen. Muldenringe erhalten lokales Kantenlicht und
  Kontaktverschattung statt Neon-Glow oder pauschalem Schlagschatten.
- Eine gemeinsame `TableWorldSpatialPresentation` kippt Asset, Gravuren und Steine
  zusammen um `5,2°`. Dadurch bleiben Kontaktpunkte deckungsgleich; Track B erhält
  diese Track-A-Kamera nicht.
- Die Muldenzentren der finalen Materialbasis weichen gegenüber der gesperrten
  1254-px-Basis im Median um `3 px`, maximal um `5,83 px` ab. Der visuelle
  300-px-Vergleich bestätigt, dass Unterkante und Materialtiefe erhalten bleiben.
- Phase 1 besitzt in Landscape eine stabile linke Gegnerachse, eine getrennte
  Kartenherkunft und die Disc rechts. Der UI-Vertrag prüft alle drei Zonen auf
  Existenz und paarweise Trennung.
- Der vollständige vierteilige Simulatorlauf besteht in `34,363 s` ohne Fehler.
  `audit_visual_contracts.py` meldet `14 PASS`, `3 WARN`, `0 FAIL`; die Warnungen
  verlangen weiterhin menschliche Dynamic-Type-, Kontrast- und Größenabnahme und
  behaupten keine automatische Ästhetiknote.

### Integrationsreihenfolge

1. Materialbasis gegen die Nahreferenz erzeugen und Geometrie sowie Alpha prüfen.
2. Lead bindet die gemeinsame physische Kamera und die zurückgenommenen
   gravurartigen Labels in First Run, Phase 1 und Phase 2 ein.
3. QA prüft Phase 1/2 in Portrait und Landscape, einschließlich Gegner-, Hand- und
   Board-Zonen, und exportiert die echten Simulatorbilder.
4. HTML-Abnahme synchronisieren, vollständige relevante Checks ausführen, danach
   committen und auf `main` pushen.

Als nächster priorisierter Materialpunkt bleibt die R1-Mikrooberfläche samt echter
Hardware-Abnahme für Keramikklang und Taptic-Charakter. Sie darf die nun gesperrte
Disc-Geometrie und die ruhige Track-A-Komposition nicht erneut verändern.
