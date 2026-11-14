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

- R1 misst rund 70-74 % der sichtbaren Außenmuldenöffnung und skaliert in Phase 2 mit der Disc.
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
  zusammen um `17,5°`. Dadurch bleiben Kontaktpunkte deckungsgleich; Track B erhält
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

## Siebter Integrationspunkt - direkter Nordstern und Asset-Normalisierung

**Ziel:** Der bestätigte Nordstern `SCR-20260718-jszw.png` ist der verbindliche
Maßstab für Disc, R1, Perspektive und Schatten. Der große transparente Rand des
1254-px-Produktionsassets darf den sichtbaren Scheibendurchmesser und die
semantischen Muldenanker nicht mehr voneinander trennen.

### Blast Radius und Dateihoheit

| Spur | Dateien | Status |
| --- | --- | --- |
| Lead | `App/DesignTokens.swift`, `App/PlayComponents.swift`, `App/PochRing.swift`, dieses Dokument | Integriert: gemeinsame Asset-Normalisierung für Basis und Frontlippe |
| Material | `Tests/R1MaterialContractTests.swift` und read-only Messung im Material-Worktree | Grün: fünf R1-Assets besitzen exakt dieselbe 340-px-Alpha-Silhouette |
| QA | read-only Simulatorlauf und exportierte Attachments | Grün: Phase 1/2 in Portrait und Landscape |
| Regel/Gegner | keine Produktänderung | Regeln und Informationsgrenzen unverändert; Wertlesbarkeit über 12 separat untersucht |

Die Änderung ist L2: Sie betrifft ausschließlich die physische Track-A-Darstellung
in First Run, Phase 1 und Phase 2. PochKit, Economy, Botlogik, Persistenz und Track B
liegen außerhalb des Blast Radius.

### Messung, Korrektur und Nachweis

- Die robuste Kreisdetektion misst den physischen Außenring bei `(626, 590)` mit
  Radius `489 px`. Die semantischen Muldenkoordinaten stimmen bereits mit den
  gemessenen neun Assetzentren überein; deshalb bleibt die gesperrte
  `PochDiscGeometry` unverändert.
- `pochDiscAssetScale = 1.26` sowie der kleine zentrale Y-Ausgleich richten den
  physischen Außenring auf den semantischen Disc-Raum aus. Boardbasis und
  `PochDiscFrontLipOverlay` verwenden denselben Modifier, damit Muldenkontakt,
  Maskierung und R1-Endlagen deckungsgleich bleiben.
- Der echte Phase-1-Portrait-Frame zeigt die Disc mit rund `92 %` Viewportbreite.
  R1 liegt in Außen- und Mittelmulde; die Karten bleiben der absichtliche vordere
  Tisch-Bleed und verdecken kein Bedienpanel.
- `R1MaterialContractTests` prüft zusätzlich Canvasformat, 8-bit RGBA,
  transparente Ecken und bytegenau identische Alpha-Silhouetten aller fünf
  R1-Materialvarianten. `R1TokenLayoutTests`, Swift-Parse und `git diff --check`
  bestehen ebenfalls.
- `TableWorldStageUITests/testPochDiscCompositionInPortraitAndLandscape` besteht
  in `34,129 s`: Phase 1 und Phase 2 jeweils in Portrait und echtem
  `667 x 375` Landscape, vier Screenshots, null Fehler. Ergebnisbundle:
  `/tmp/track-a-normalized-full-1.xcresult`.
- Das dauerhafte cmux-Statusfenster verwendet relative, lokal kopierte Bildassets;
  beide Bilder laden vollständig und die native Hilfs-Pane besitzt keinen
  horizontalen Overflow. Die unveränderte Ansichtskopie liegt zusätzlich unter
  `/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/`.

### Nächste priorisierte Integrationspunkte

1. Die bereits öffentliche Gegner-Tendenz nach der ersten verstandenen
   Poch-Entscheidung an `GameState` und UI anbinden.
2. Danach vollständigen GOTY-Status, Build und Evidenz erneut synchronisieren.

### Nachgelagerter P2 - öffentliche Werte über der physischen Kapazität

- Eine read-only Simulation über `117.077` Vier-Spieler-Runden zeigt, dass
  Bestände über zwölf regulär entstehen; Mariage und Sequenz erreichen dabei bis
  zu `48`. Der exakte Muldenstand ist öffentlich und wurde bereits vollständig
  über VoiceOver benannt.
- `PocketValueMarker` zeigt deshalb bis einschließlich zwölf nur die ruhige
  Muldennotation. Erst bei `chips > visiblePileCapacity` ergänzt er den exakten
  öffentlichen Wert. Track A und Track B leiten ihre Kapazität jeweils aus ihrem
  tatsächlichen deterministischen Layout ab.
- `GameState` besitzt für den Beleg ausschließlich im DEBUG-Build einen
  Präsentations-Override. Er mutiert weder `Round.board` noch PochKit und ist nur
  über `-boardOverflowQA` erreichbar.
- `testSaturatedPileRevealsItsPublicValue` bestätigt `SEQ, 13` im echten
  Phase-2-Portrait-Frame und hält den visuellen Beleg im Ergebnisbundle
  `/tmp/track-a-overflow-value-6.xcresult` fest. Die eingelassene Notation bleibt
  innerhalb des Rings und erzeugt weder Badge noch zusätzliche UI-Fläche.

## Achter Integrationspunkt - schweres R1 und heller Samtboden

**Ziel:** Die R1-Steine müssen der bestätigten Nahreferenz als schwere, wertige
Keramikkörper entsprechen, die textile Innenöffnung glaubwürdig belegen und nie
auf dem Metallring liegen. Leere Mulden zeigen kühlen, etwas helleren blauen Samt
ohne farbige UI-Marker.

### Parallele Spuren und Blast Radius

| Spur | Auftrag | Ergebnis |
| --- | --- | --- |
| Lead | `App/DesignTokens.swift`, `App/PlayComponents.swift`, `App/R1TokenLayout.swift`, Phase-Views | sichtbaren Körper normalisiert, Prägung und Containment integriert |
| Material | read-only Alpha-, Größen- und Referenzmessung | maximale Alpha-Hüllkurve `294 x 308 px` im `340 x 340 px` Produktionsrahmen belegt |
| QA | echter Simulatorvergleich und Vier-Zustands-Test | Phase 1/2 in Portrait und `667 x 375` Landscape, vier Screenshots, null Fehler |
| Contract | R1-Material-, Slot-, JSON- und Diff-Prüfung | alle Verträge grün; eine zu breite Zwischenlage wurde vor Integration verworfen |

Die Änderung ist L2 und rein präsentational. Sie betrifft die gemeinsame
Track-A-Darstellung in First Run, Phase 1 und Phase 2. PochKit-Regeln, Economy,
Botlogik, Persistenz, Track B und öffentliche Informationsgrenzen bleiben
unverändert.

### Soll-/Ist-Messung und Korrektur

- Die frühere Normierung ging fälschlich von einem `214-px`-Körper aus und
  vergrößerte R1 dadurch um rund `37 %`. Die aktuellen Assets besitzen eine
  maximale Alpha-Hüllkurve von `294 x 308 px`. Der abschließende Geometrieaudit
  korrigierte den Zwischenwert `1.10` auf `r1AssetScale = 1.085`; `size`
  bezeichnet damit die vollständige sichtbare Silhouette und bleibt auch mit
  maximalem Slot-Jitter im Fit-Kreis.
- R1 trägt die freigegebene zurückhaltende Materialsignatur aus zwei
  konzentrischen Blindringen, feinem Randdekor und deterministischen Chevron-,
  Quadrat- oder Rautenmotiven. Nur die Prägung rotiert; Seitenwand, Licht und
  Kontaktschatten behalten ihre gemeinsame Materialrichtung.
- `outerWellFloorRatio = 0.78` beschreibt die textile Innenöffnung statt des
  äußeren Metallrings. Mit `tableTokenDiameter = 32.3` bleibt derselbe physische
  R1-Stein in Außenmulde und Mitte gleich groß. Ein angeforderter Durchmesser ist
  nur noch Obergrenze und kann den Fit-Check nicht umgehen; eine Zweiergruppe
  nutzt den Boden sichtbar aus, ohne den Metallring zu schneiden.
- Die dichten Zweierlagen belegen nach der korrigierten Alpha-Normierung nahezu
  die gesamte textile Breite. Der deterministische
  `R1TokenLayoutTests`-Kreisvertrag beweist für alle neun Mulden und vier Seeds,
  dass jeder Körper vollständig innerhalb der Öffnung bleibt.
- Drei farbige Leerzustandskreise in Phase 1, Mitte und Phase 2 waren die
  gelblichen Punkte und wurden entfernt. Der bestehende Disc-Samt wird selektiv,
  weich maskiert angehoben; sein Median liegt im Simulator bei `31/36/47`, die
  Referenz bei `30/35/44`. Webung und Vignette des Originalassets bleiben erhalten.

### Nachweis

- `R1MaterialContractTests: PASS` und `R1TokenLayoutTests: PASS`.
- Debug-Simulatorbuild erfolgreich; keine Swift-Concurrency-Warnung. Die einzige
  Buildmeldung bleibt der bekannte AppIntents-Metadatenhinweis ohne Produktwirkung.
- `TableWorldStageUITests/testPhase1PortraitMaterialPresentation`: bestanden.
- `TableWorldStageUITests/testPochDiscCompositionInPortraitAndLandscape`:
  `33,848 s`, vier aktuelle Screenshots, null Fehler. Ergebnisbundle:
  `/tmp/poch-r1-full-ui-1.xcresult`.
- `App/Localizable.xcstrings` ist valides JSON; `git diff --check` besteht.
- Das dauerhafte cmux-Statusfenster wurde mit dem echten Nachher-Frame aktualisiert
  und meldet weder Browser- noch Konsolenfehler. Die Ansichtskopie und ihre
  Bildassets liegen zusätzlich im iCloud-Ordner `TEMP`.

Es wurde weder committet noch gepusht.

## Neunter Integrationspunkt - R1-Ante als physische Transaktion

**Ziel:** Die geführte Tischfinanzierung verwendet dieselben schweren R1 wie das
ruhende Brett. Quelle, Flug, Kontakt und sichtbarer Bestand bleiben kausal; bei
Reduced Motion oder Abbruch dürfen weder unsichtbare Wartezeit noch Geistersteine
entstehen.

### Umsetzung und Review

- Die abstrakte Goldlinie im Produktpfad ist entfernt. Jede Beitragsrunde startet
  nun die echte radiale `GuidedAnteWave`; die Coach-Aktion bleibt bis nach dem
  Settle-Rest gesperrt.
- `ImpactFlight` hält die Layoutposition statisch an der Quelle und animiert die
  quadratische Bahn per Offset. Linearer Fortschritt liefert zusammen mit der
  Parabel die ballistische Zeitbasis, ohne vor dem Kontakt künstlich abzubremsen.
- Schatten und Muldenreaktion wechseln keine Paint-Parameter mehr im Flug. Der
  kurze Kontaktimpuls animiert nur Scale und Opacity.
- Eine generationgebundene Funding-ID schützt Task-Cleanup und jeden einzelnen
  `landGuidedAnte`-Callback vor schnellen Neustarts. Coach-Schließen, neue Runde,
  Tutorialabschluss und Phasenwechsel brechen die aktuelle Generation ab.
- Das gebündelte Keramikfeedback wird vom letzten tatsächlichen R1-Aufprall
  ausgelöst, nicht erst nach dem zusätzlichen `guidedAnteWaveRest`.
- Ein laufender Flow prüft die Systempräferenz alle `50 ms`. Wird Bewegung
  reduziert, landen die verbleibenden Beiträge sofort und ohne unsichtbare Welle.

### Nachweis

- `R1MaterialContractTests: PASS`, einschließlich Produktpfad, transformbasierter
  Bahn, linearer Flugkurve, generationgebundenem Abbruch und Kontaktkopplung.
- `R1TokenLayoutTests: PASS`; `git diff --check` bestanden.
- Debug-Simulatorbuild erfolgreich; keine Swift-Concurrency-Warnung. Die einzige
  Meldung bleibt der bekannte AppIntents-Metadatenhinweis.
- `testGuidedTableFundingUsesVisibleR1WavesAndSettles` und
  `testGuidedTableFundingSettlesImmediatelyWithReducedMotion`: `2/2` bestanden,
  drei aktuelle Simulatorframes, null Fehler. Ergebnisbundle:
  `/tmp/poch-guided-r1-motion-ui-8.xcresult`.
- Der normale Endframe und der Reduced-Motion-Endframe sind identisch belegt:
  alle R1 liegen vollständig innerhalb ihrer Mulden, ohne Doppel- oder
  Geistersteine. Der Zwischenframe zeigt ausschließlich R1 auf dem Weg von der
  Spielerquelle zum Brett.

Es wurde weder committet noch gepusht.

## Zehnter Integrationspunkt - kausale Poch-Auszahlung

**Ziel:** Der Poch-Gewinn wird als sichtbarer materieller Transfer abgeschlossen.
Stack, Ergebnisaktionen und schneller Phasenwechsel dürfen der letzten schweren
R1-Scheibe weder vorauslaufen noch nach einem Neustart durch einen alten Callback
verändert werden.

### Parallele Prüfung und Integration

- `poch-material` prüfte Bahn, Kontaktbild und Materialgewicht; `poch-qa` prüfte
  Reduced Motion, Accessibility und kompakte Viewports; `poch-rules-opponents`
  prüfte Transfergeneration, Bot-Fortsetzung und Stack-Kausalität. Die Lead-Session
  integrierte die nicht überlappenden Findings und führte den Gesamtcheck aus.
- Die Prüfung fand eine echte Race Condition: Ein veralteter Ante-Callback konnte
  den bereits gestarteten Poch-Transfer erneut beeinflussen. `settledBetTransfer`
  und generationgebundene Kontakt-Callbacks koppeln die Auszahlung nun exakt an
  den letzten gültigen Ante-Aufprall.
- `ImpactFlight` berechnet die quadratische Bahn mit einem `GeometryEffect` in
  jedem Frame. Die fünf R1 fliegen vom tatsächlichen Mitteltopf zum Sieger; dessen
  sichtbarer Stack bleibt bis zum letzten Materialkontakt auf dem Vorwert.
- Bei Reduced Motion wird ohne unsichtbare Flug- oder Ruhezeit gesetzt. Der
  Phasenwechsel deaktiviert zugleich seine dekorative Transition.
- Der Einsatzregler unterstützt jetzt `accessibilityAdjustableAction`. Irrelevante
  Guided-Focus-Regionen sind aus dem Accessibility-Baum entfernt; ein Bot am Zug
  setzt nach Wiedererscheinen von Phase 2 die Partie fort.
- Das Ergebnislayout besitzt getrennte Bereiche für Resultat, Aktionen, Gegner und
  Hand. Zusätzlich wird das echte kompakte Landscape-Fenster mit 667 x 375 Punkten
  geprüft. Ein beim Start bereits gedrehtes Gerät wird in
  `applicationDidBecomeActive` synchronisiert; der UI-Test verwendet dafür einen
  strikt DEBUG-gebundenen Landscape-QA-Pfad.

### Nachweis

- `Phase2PresentationContractTests: PASS` und `R1MaterialContractTests: PASS`.
- `testPochPayoutLandsBeforeFastPhaseTransition`,
  `testPochPayoutReducedMotionDoesNotWaitForInvisibleFlight` und
  `testPochPayoutResultFitsCompactLandscape`: `3/3` bestanden, null Fehler.
  Ergebnisbundle: `/tmp/poch-payout-ui-final-race.xcresult`.
- Der Portrait-Zwischenframe zeigt fünf R1 am Sieger, während beide Aktionen noch
  gesperrt sind. Endframe und Reduced-Motion-Frame stimmen semantisch überein. Das
  Landscape-Bild misst tatsächlich 667 x 375 Punkte und hält Resultat, Aktionen,
  Brett, Gegner und Hand ohne Überschneidung auseinander.
- `App/Localizable.xcstrings` ist gültig; `git diff --check` bestanden.

Offen bleiben die Phase-1-Meld-Auszahlung unter Live-Reduced-Motion und Abbruch,
breite Dynamic-Type-QA in Phase 2 sowie die größere, matchweite Identitätsgrenze.

Es wurde weder committet noch gepusht.

## Elfter Integrationspunkt - kausale Meld-Auszahlung und korrigierte R1-Hüllkurve

**Ziel:** Meld-Gewinne verlassen die zugehörige Mulde als einzelne schwere R1,
landen erst sichtbar am Gewinner und bleiben bei Live-Reduced-Motion, Tutorial-
Abbruch oder schnellem Aktwechsel atomar. Die reale Asset-Silhouette darf weder
aus Mulden ragen noch als flacher rotierender Sticker erscheinen.

### Parallele Prüfung und Integration

- `poch-material` maß die aktuellen fünf R1-Assets erneut und fand den zentralen
  Altvertrag: Die Alpha-Hüllkurve beträgt `294 x 308 px`, nicht `214 x 214 px`.
  Die Normalisierung wurde von `1.59` zunächst auf `1.10` korrigiert. Ein
  unabhängiger Radialaudit fand an der strengsten Kante noch rund `0,2 pt`
  theoretischen Clip; der finale konservative Faktor ist deshalb `1.085`.
- Die ruhenden Slots nutzen dadurch die textile Muldenöffnung vollständig, ohne
  den Metallring zu schneiden. Der Samt wird leicht aufgehellt und neutraler
  entsättigt; leere Mulden besitzen keine gelblichen UI-Mittelpunkte.
- Chevron, verschachteltes Quadrat und doppelte Raute bilden die vereinbarte
  deterministische Relief-Familie. Fliegende R1 drehen nur ihre Prägung, nie das
  vorbeleuchtete Materialasset.
- Die Meldeauszahlung verwendet gestaffelte, seitlich getrennte R1-Bahnen. Der
  Gewinnerstand folgt erst dem letzten Kontakt; ein Generationstoken weist alte
  SwiftUI-Callbacks nach Reset oder Phasenwechsel ab.
- Der Guided-Meld-Task und sein Live-Interruption-Trigger besitzen explizite
  Inhaber. Neue Runde, neuer Match, Spielerzahlwechsel, Tutorial-X und Aktwechsel
  brechen sie ab; der sichtbare Phase-1-Zustand wird dabei atomar gesetzt.
- `-meldPayoutFastTransitionQA` startet im DEBUG-Build einen echten Transfer und
  wechselt nach `240 ms` strukturiert nach Pochen. Standard-Portrait und echtes
  `667 x 375` Landscape besitzen getrennte, reproduzierbare Orientierungs-Masken.

### Nachweis

- `Phase1MeldPresentationContractTests: PASS` und
  `R1MaterialContractTests: PASS`, einschließlich exakter `294 x 308`-Alpha-
  Hüllkurve, Reliefvarianten, Task-Inhaberschaft und Callback-Generation.
- `testMeldPayoutUsesVisibleHeavyR1AndSettlesAtContact`,
  `testMeldPayoutSettlesWhenReduceMotionChangesLive` und
  `testMeldPayoutFastTransitionRejectsStaleContactInCompactLandscape`: `3/3`
  bestanden, null Fehler. Ergebnisbundle:
  `/tmp/poch-meld-ui-final.xcresult`.
- Der normale Lauf belegt Quelle, einzelne R1-Bahnen und erst danach `5/5`;
  Live Reduced Motion setzt denselben Endzustand ohne Restwartezeit. Der schnelle
  Landscape-Wechsel entfernt den alten Phase-1-Flug vollständig aus Phase 2.
- Debug-Simulatorbuild erfolgreich; keine Swift-Concurrency-Warnung. PochKit-
  Regeln, Economy, Botlogik, Persistenz und Track B blieben unverändert.

Offen bleiben reale Geräteabnahme für Audio, Haptik und Keramikkontakt sowie die
größere matchweite Identitätsgrenze.

Es wurde weder committet noch gepusht.

## Zwölfter Integrationspunkt - öffentliche Gegner-Tendenz und echter Dynamic-Type-Reflow

**Ziel:** Die bereits katalogisierte Gegner-Tendenz wird erst nach einer
verstandenen öffentlichen Poch-Entscheidung sichtbar. Sie darf weder Handdaten
noch Botparameter oder eine Vorhersage des nächsten Zuges enthalten. Phase 2 muss
bei Accessibility XXXL zugleich wirklich wachsen und auf kompakten sowie
repräsentativen Geräten interaktiv bleiben.

### Parallele Prüfung und Integration

- `poch-opponents` ergänzte eine endliche `PublicTendencyID`-Registry, einen
  strikten ID-/Evidenzbasis-Vertrag und eine einmalige Disclosure-Session. Ein
  unbekannter Actor oder eine nicht freigegebene interne Metrik scheitert
  geschlossen und verbraucht den Disclosure-Slot nicht.
- Die Lead-Session band die Freigabe an eine tatsächlich abgeschlossene,
  öffentliche Gegneraktion im geführten Poch-Flow. Am beobachteten Gegner ersetzt
  der echte Tendenztitel den generischen Rollenbegriff; Erklärung und Caveat
  nutzen den vorhandenen Entscheidungsblock statt eines neuen schwebenden Cards.
- Neun Strings - drei Titel, drei Zusammenfassungen, Caveat und zwei kurze Labels -
  liegen vollständig in DE, EN, FR, IT, ES, NL und PL vor. Der Text beschreibt
  ausschließlich beobachtbares Tempo oder öffentliche frühe Initiative.
- `poch-dynamic-type` bewies zunächst, dass Standard und Accessibility XXXL
  pixelidentische Ergebnisframes besaßen. Die Aktionen verwenden nun skalierte
  Schrift und echte `56 pt` Touchhöhe; der `72 pt` Ergebnisstreifen rückt im
  Accessibility-Fall um `12 pt` nach oben und bleibt von Gegnern und Hand getrennt.
- Ein unabhängiger Materialaudit korrigierte zusätzlich den letzten R1-Fit:
  `32,3 pt` voller Durchmesser, `1.085` Assetfaktor und `0.78` Textilbodenratio
  ergeben dieselbe physische Größe in Außenmulde und Mitte. Der Test rechnet die
  gemessene `157,156 px` Radialhülle, alle Slot-Jitter und beide Boardmaßstäbe.

### Nachweis

- `OpponentRosterContractTests`, `R1MaterialContractTests` und
  `R1TokenLayoutTests`: PASS. `BotBrainTests`: `9/9` PASS.
- `OpponentTendencyUITests`: `1/1` bestanden. Der echte deutsche Simulatorframe
  zeigt genau Hanas „Bedachtes Tempo“, die öffentliche Zusammenfassung und
  „Eine Tendenz, kein Versprechen.“ Ergebnisbundle:
  `/tmp/poch-final-material-opponent-evidence.xcresult`.
- `Phase2DynamicTypeUITests` auf SE3: kompaktes Portrait reflowt sichtbar,
  `667 x 375` Landscape bleibt getrennt und führt nach Phase 3; `2/2` ausgeführte
  Gates bestanden, der Breiten-Gate wurde dort erwartungsgemäß übersprungen.
- Derselbe Breiten-Gate auf dem 402-pt-iPhone-16-Pro-Simulator: `1/1` bestanden.
  Ergebnisbundles: `/tmp/poch-phase2-dynamic-type-integrated-2.xcresult` und
  `/tmp/poch-phase2-dynamic-type-16pro-integrated-2.xcresult`.
- Finaler Debug-Simulatorbuild: `BUILD SUCCEEDED`. Der source-synchrone R1-/
  Tendenz-Lauf bestand `2/2`; `git diff --check`, JSON- und String-Catalog-
  Validierung bestanden.

Offen bleiben reale Geräteabnahme für Audio, Haptik und Keramikkontakt, der
Build-Time-Ersatz des derzeitigen Samt-Overlays und die größere matchweite
Identitätsgrenze. Das GOTY-2026-Goal bleibt aktiv.

Es wurde weder committet noch gepusht.

## Dreizehnter Integrationspunkt - matte R1-Keramik statt Kunststoffhaut

**Auslöser:** Der source-synchrone Simulatorbeleg zeigte trotz korrigierter
Geometrie eine zu glatte, helle und gleichförmige Oberfläche. Die R1 lasen als
spritzgegossenes Plastik statt als schweres historisches Spielmaterial.

### Materialkorrektur

- Zwei unabhängige Read-only-Audits bestätigten die Ursache in den fünf
  Material-PNGs und im Relieflicht, nicht in Durchmesser oder Muldenlayout. Die
  vier farbigen Oberflächen verloren beim Downsampling nahezu ihre gesamte
  Variation; generische Ellipsenschatten und ein mitrotierender Lichtversatz
  verstärkten den synthetischen Eindruck.
- `tools/build_r1_ceramic_assets.py` erzeugt die fünf 340er RGBA-Materialkörper
  jetzt reproduzierbar aus einer gesperrten Alpha-Hülle. Grobe und feine
  Mineralvariation, breite diffuse Beleuchtung, eine nur 4,5 Prozent tiefe Fase
  und eine dunkle gebrannte Seitenwand werden einmalig Build-Time gebacken.
- `tools/r1-material/r1-alpha-mask.png` hält die Geometrie als versionierbare
  Build-Eingabe getrennt vom
  Material. Alle fünf Ausgaben behalten exakt dieselbe 294-x-308-Hülle; die alte
  quantisierte Zweistufen-Franse wurde durch eine kontinuierliche
  Ein-Pixel-Kantenglättung ersetzt.
- Die Farben sind stumpfer und mineralischer. Naturweiß ist steinig statt
  pfirsichfarben, Ocker erdig statt orange; Slate, Terrakotta und Sage bleiben
  unterscheidbar, ohne Besitzer oder Wert zu codieren.
- `R1MintEmboss` rotiert nur noch seine Geometrie. Licht- und Schattenversatz
  werden danach angewendet und bleiben damit in der Tischwelt fixiert. Dunkle
  Nut, zurückhaltende Gegenkante und eine schmalere Linienhierarchie lesen als
  gepresstes Relief statt als UI-Stroke.
- Die zwei losgelösten Schattenellipsen wurden entfernt. Kontakt- und
  Wurfschatten werden nun aus der echten Asset-Silhouette erzeugt und bleiben
  beim Stapeln am Körperkontakt.

### Neue harte Gates

- Der Materialvertrag prüft zusätzlich den vorhandenen Build-Time-Generator,
  die gesperrte Quellmaske, mindestens 16 Alpha-Abstufungen, fehlende
  Glanzspitzen über 92 Prozent und messbare Luminanzvariation sowohl bei 340 px
  als auch nach echtem 32-px-Downsampling.
- `R1MaterialContractTests` und `R1TokenLayoutTests`: PASS. Geometrie, 32,3-pt-
  Durchmesser, 1.085-Normalisierung und 0.78-Bodenvertrag blieben unverändert.
- Phase-1-Portrait-Materialtest: `1/1` bestanden. Der Vierzustands-
  Kompositionstest für Phase 1/2 in Portrait und Landscape: `1/1` bestanden.
- Sechs Auszahlungs-, Reduced-Motion- und Landscape-Gates: `6/6` bestanden.
- Gegner-Tendenz und Dynamic Type wurden gegen die neue globale R1-Basis erneut
  ausgeführt: SE3 ohne Fehler, repräsentatives 402-x-874-Portrait auf iPhone 17
  Pro `1/1` bestanden.
- Aktuelle Bundles: `/tmp/poch-r1-matte-composition-v1.xcresult`,
  `/tmp/poch-r1-matte-motion-v1.xcresult`,
  `/tmp/poch-r1-matte-opponent-dynamic-se3-v1.xcresult` und
  `/tmp/poch-r1-matte-dynamic-17pro-v1.xcresult`.

Das cmux-Statusfenster verwendet ausschließlich neu exportierte Frames für die
sichtbaren Phase-1-/2-, Meld-, Poch-, Gegner- und Dynamic-Type-Belege. Die
Nutzerabnahme des neuen Materialcharakters bleibt der nächste ästhetische Gate;
das GOTY-2026-Goal bleibt aktiv.

Es wurde weder committet noch gepusht.

## Vierzehnter Integrationspunkt - Nordsternmaß und echte Asset-Muldenanker

**Auslöser:** Die matte Keramikbasis löste die Kunststoffwirkung, der letzte
Runtime-Beleg verwendete aber noch einen zu kleinen sichtbaren R1 und legte
mehrere Stapel auf idealisierte statt auf die tatsächlichen Asset-Mulden. Grüne
Containmenttests hatten den falschen gemeinsamen Maßstab `32,3 pt`/`0.78`
mitgeschützt.

### Korrektur

- `tableTokenDiameter = 39` und `outerWellFloorRatio = 0.95` stellen das
  direkte Nordsternmaß wieder her. Mit gemessenem Alpha-Radius `157,678/340`,
  R1-Assetfaktor `1.085` und Disc-Normalisierung `1.26` liegt die sichtbare
  Hülle bei `0,1074 D`; der gesperrte Korridor ist `0,102-0,110 D`.
- Die Zweierlage nutzt rechnerisch rund `93,9 %` der Textilbreite. Die neue
  Phase-1-Messung liegt bei rund `83 px` sichtbarem Face gegenüber rund
  `84 px` in der Referenz. Der frühere Ist-Beleg lag bei rund `59 px`.
- Eine Zwischenkorrektur mit `0.145` vertikalem Content-Inset wurde verworfen:
  Sie beseitigte zwar Außenpixel, beschnitt aber Sage und Ocker um 12-16 % und
  erzeugte sichtbare Maskenkerben. Der Produktwert bleibt deshalb beim kleinen
  Setzversatz `0.025`; es gibt keine kaschierende Rückskalierung.
- Eine Kreisdetektion auf `PochDisc2026` maß die acht Außenmitten und die Mitte
  direkt im 1254er Asset. `PochDiscGeometry` verwendet diese Werte jetzt nach
  der gemeinsamen Canvas-Normalisierung. Ruhende R1, Wertmarken, Flight-Ziele,
  Fokusmasken und Materialreaktionen liegen damit auf derselben 8+1-Geometrie.
- `PochDiscFrontLipOverlay` legt nicht mehr nur einen synthetischen unteren
  Bogen auf. Der vollständige, normalisierte Asset-Metallring liegt als
  Vordergrund über der Kreisgrenze. Die große R1-Hülle bleibt vollständig,
  während Clipkante und Alpha vom echten Ring räumlich gefasst werden.
- Die Disc-Schatten werden vor der Ambient-Ellipse ausgewertet. Dadurch sampelt
  der physische Schatten nicht länger den breiten Hintergrundlift.

### Harte Gates

- Der unabhängige Pixelgate meldet GO: In POCH, MAR, J und SEQ liegen null
  Farbpixel außerhalb des Metallrings; der kleinste gemessene Sicherheitsabstand
  beträgt `5,3 px`. Es gibt keine Chord-, Kerb- oder Clipkreis-Silhouette.
- `R1MaterialContractTests` und `R1TokenLayoutTests`: PASS. Der Layoutvertrag
  prüft jetzt zusätzlich `0,102-0,110 D`, `70-74 %` Einzelstein/Textilboden und
  `90-98 %` Zweiergruppen-Nutzung. Der Materialvertrag sperrt die neun
  gemessenen Assetanker und den vollständigen Asset-Ring.
- Phase-1-Portrait-Materialbeleg: `1/1` bestanden. Phase 1/2 in echtem Portrait
  und Landscape: `1/1` bestanden.
- Ante-, Meld- und Poch-Transaktionen einschließlich Reduced Motion, Live-
  Wechsel und kompaktem Landscape wurden nach der Anchor-Korrektur erneut
  ausgeführt: `8/8` bestanden.
- `audit_first_run.py`: strikter PASS mit null Fehlern.
  `audit_visual_contracts.py`: 14 PASS, 3 WARN, 0 FAIL. Swift-Parse und
  `git diff --check`: PASS.
- Aktuelle Bundles:
  `/tmp/poch-r1-scale39-anchors-phase1-v1.xcresult`,
  `/tmp/poch-r1-scale39-anchors-composition-v1.xcresult` und
  `/tmp/poch-r1-scale39-anchors-motion-v1.xcresult`.

Die Maßstabsangaben der Integrationspunkte acht, elf, zwölf und dreizehn sind
damit für den aktuellen Produktstand superseded. Die menschliche Abnahme von
R1, Samtboden und Disc bleibt offen; das GOTY-2026-Goal bleibt aktiv.

Es wurde weder committet noch gepusht.

## Fünfzehnter Integrationspunkt - Materialhierarchie und Phase-2-Freiraum

**Auslöser:** Der Nutzer verwarf die flache Kunststoffanmutung der R1, den
gleichförmigen Muldenstoff, das zu leuchtende Blau, die zu hellen Innenringe,
die violett gefüllte Phase-2-Mitte und die rechts klebende kompakte Disc.

### Korrektur

- Der R1-Generator verwendet feinere Mineralfrequenzen, eine deutlich dunklere
  projizierte Seitenwand, eine schmale gerollte Schulter und eine engere
  Kontaktfuge. Das gemeinsame W2-Signet ersetzt die zufällige
  Chevron-/Quadrat-/Rautenfamilie; die Außenrändelung wird im Build-Time-Körper
  erzeugt.
- `PochDiscMaterialGrade` trennt vier physische Zonen deterministisch:
  gedecktes Graphit-Nachtblau, helles satiniertes Außenmetall, mittleres
  Maus-/Edelstahlgrau der 8+1-Muldenringe und dunklen Samtflor. Der verworfene
  Runtime-Brightness-Pass wurde entfernt.
- Der finale Samtpass enthält keine großflächige BICUBIC-Helligkeitswolke. Nur
  feines Korn, kurze lokal gerichtete Fasern, kleine Poren und eine schmale
  Wand-AO bleiben sichtbar; der gelbliche Mittelpunkt kehrt nicht zurück.
- Acht dunkle, radial mitrotierende Kartenfarbensymbole sitzen als Vektorgravur
  im hellen Außenring. Raster-Artwork enthält weiterhin keine Schrift.
- Phase 2 lässt die echte mittlere Mulde materiell sichtbar. `POCH` und der
  Lichtsaum sind auf Track A neutral; nur der Zahlenwert bleibt Gold. Die Disc
  wird an der visuellen Freiraummitte zwischen Slider und rechtem Rand statt an
  der Bildschirmkante positioniert.

### Harte Gates

- Unabhängiges visuelles v6-Gate: GO für R1-Masse, Samt ohne Marmorwolke oder
  Mittelpunkt, gedecktes Graphit, satinierten Außenrahmen, abgestufte
  Innenringe, neutrale Phase-2-Mitte und Freiraumzentrierung.
- `R1MaterialContractTests`, `R1TokenLayoutTests` und
  `Phase2PresentationContractTests`: PASS. Swift-Parse und
  `git diff --check`: PASS.
- Phase 1/2 in Portrait und Landscape nach Material-/Zentrierungspass: `1/1`
  bestanden. Source-synchrone Portrait-Materialtests für Phase 1 und Phase 2:
  jeweils `1/1` bestanden.
- Aktuelle Bundles: `/tmp/poch-phase2-material-centering-v5.xcresult`,
  `/tmp/poch-phase1-material-v6.xcresult` und
  `/tmp/poch-phase2-material-v6.xcresult`.

Die technische Material- und Kompositionskorrektur ist damit belegt. Die
menschliche ästhetische Abnahme bleibt ausdrücklich offen; das
GOTY-2026-Goal bleibt aktiv.

Es wurde weder committet noch gepusht.
