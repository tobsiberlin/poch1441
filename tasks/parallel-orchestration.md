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
| Gegner | `App/BotProfiles.json`, neue datengetriebene Gegner-/Besetzungsmodule und eigene Tests | Lead-Dateien, verdeckte Karten oder Timeline | Integriert: Hana/Noah/Jonas, feste Sitze und öffentliche Tendenzen |
| QA | neue Dateien unter `tools/qa/`, `tasks/evidence/` und reine Test-/Auditdateien | Produktcode außerhalb eines koordinierten Integrationsfensters | Grün: Static Gate, UI-Interaktion und drei iPhone-Klassen |
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
