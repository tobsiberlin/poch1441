# Poch 1441 - Parallele Orchestrierung First Run

**Stand:** 17. Juli 2026
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
| QA | neue Dateien unter `tools/qa/`, `tasks/evidence/` und reine Test-/Auditdateien | Produktcode außerhalb eines koordinierten Integrationsfensters | Grün: Static Gate, UI-Interaktion, drei iPhone-Klassen, SE-Intro P/L und AX-Lernbühne P |
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
- Accessibility-XXXL-Gate: iPhone-SE-Intro in Portrait/Landscape grün; die neue
  sequenzielle Lernbühne ist in Portrait grün. Der separate strenge Landscape-Test
  bleibt offen, weil zwei SE-Simulatoren das App-Fenster nicht rotierten; er wurde
  nicht als Produkt-Pass umgedeutet. Vollständiger Standard-SE-Flow mit zwei Tests
  und Pro-Max-Rotation sind grün.

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
- Der zweite Integrationspunkt ist damit verifiziert und wird mit diesem Commit auf
  `main` veröffentlicht. Die offene Landscape-Wiederholung der AX-Lernbühne bleibt
  als strenger QA-Gate erhalten und blockiert keine falsche Designfreigabe.
