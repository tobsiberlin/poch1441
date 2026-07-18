# Handoff - Kontextreset 2026-07-18

## 1. Sofortiger Einstieg

Neue Session zuerst vollständig lesen:

1. diese Datei,
2. `tasks/HANDOFF-2026-07-17.md`,
3. `tasks/design-canon-2026.md`,
4. `tasks/board-art-direction.md`,
5. `tasks/parallel-orchestration.md`,
6. `AGENTS.md` und `CLAUDE.md`.

Danach `git status`, letzten Commit und den aktuellen Goal-Status prüfen. Nicht bei
einem Plan stehen bleiben. Die aktuelle Nutzerkorrektur ist: Disc und R1-Steine
müssen möglichst präzise dem direkten Mockup entsprechen.

## 2. Verbindliche visuelle Referenz

Soll:

`/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/Screenshots/SCR-20260718-jszw.png`

Zu korrigierender früherer Ist-Beleg:

`/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/Screenshots/SCR-20260718-jtfk.png`

Der Nutzer hat ausdrücklich bestätigt, dass Board und Steine hinsichtlich Farbe,
Größe, Material, Perspektive und Schatten möglichst genau wie im Soll aussehen
sollen. Das aktualisiert die frühere Ein-Farbwelt-Annahme: Die gedeckten R1-Farben
werden gemeinsam als rein materielle Produktpalette verwendet. Sie codieren weder
Besitzer noch Wert oder verdeckte Information und verändern keine Regeln.

Gemessene Zielwerte:

- Pitch `17-18°`, Startwert `17,5°`; vorher waren `5,2°` deutlich zu frontal.
- Boardbreite im Vergleichscrop rund `92 %` des Viewports; Startskalierung `1,06`.
- Körper-Albedo etwa `#303B49` bis `#34404F`, klar nachtblauer als der alte graue Ist-Stand.
- Metall-Median etwa `#B1B3B8`, kühl satiniert statt warm/chromig.
- Muldenboden etwa `#1F242F`, textil und nachtblau.
- sichtbare Seitenwand `2,5-3,1 % D`.
- weicher Wurfschatten bis etwa `9-10 % D` unter der Brettfläche.
- Außenmuldenöffnung etwa `0,156 D`, Mitte `0,245-0,255 D`.
- R1-Durchmesser `0,102-0,110 D` beziehungsweise `70-74 %` der Muldenöffnung;
  ungefähr `1,7 x` größer als der verworfene weiße Ist-Stand.
- Zweierlage: Mittelpunktabstand `0,28-0,40` Steindurchmesser; keine Rosette.

## 3. Aktueller Checkpoint

Ausgangspunkt vor dieser Korrektur: `0cfbcba Track-A-Disc räumlich an Referenz angleichen`.

Der aktuelle Korrekturstand umfasst:

- neue nachtblaue Disc-Basis in
  `App/Assets.xcassets/PochDisc2026.imageset/poch-disc-2026.png`;
- neue einheitlich normalisierte RGBA-Materialkörper:
  `R1NaturalWhite`, `R1Terracotta`, `R1Sage`, `R1Slate`, `R1Ochre`;
- `39 pt` R1-Zielmaß, Floor-Ratio `0,95`, Token/Floor `0,74`;
- gemeinsame Track-A-Kamera mit `17,5°`, Skalierung `1,06`, getrenntem Kontakt-
  und großem Wurfschatten sowie lokalem Graphit-Lift;
- Build-Time-Tokenmaterial plus rotierende SwiftUI-Blindprägung und getrennte
  Welt-/Kontaktschatten;
- deterministische materielle Palette nach Fach: unter anderem K Terrakotta/Slate,
  MAR Sage, J Ocker, 10 Terrakotta/Naturweiß, SEQ Slate/Naturweiß;
- dichte gerichtete Endlagen statt Mittelpunkt-Rosetten;
- Flight-Farben im geführten Ante an dieselbe Fach-/Indexauflösung angebunden;
- Handoff, Designkanon und Board-Art-Direction auf die bestätigte gemeinsame
  Referenzpalette aktualisiert.

Quellmaterial und verworfene Varianten liegen hier:

`/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/Track-A-northstar-assets-20260718/`

Wichtig:

- akzeptierte Disc-Quelle: `disc-rgba.png`;
- `disc-geometry-lock-1254.png` ist nur ein Messdiagramm, kein Produktasset;
- `tokens-embossed-rejected/` ist verworfen, weil Prägung und Schatten eingebrannt waren;
- die finalen Repo-Token verwenden dieselbe normalisierte Naturweiß-Silhouette und
  eine explizit übernommene, bereinigte Alpha-Maske für alle fünf Farben.

## 4. Belege und noch nicht abgeschlossene QA

Bestanden:

- `R1TokenLayoutTests: PASS`;
- `R1MaterialContractTests: PASS`;
- Swift-Parse für die geänderten App-Dateien;
- `git diff --check`;
- gezielter UI-Test
  `TableWorldStageUITests/testPhase1PortraitMaterialPresentation`: `PASS`,
  `7,787 s` Testdauer.

Xcode-Ergebnisbundle:

`/tmp/track-a-northstar-phase1-portrait-2.xcresult`

Noch zwingend offen:

- Screenshot aus dem Ergebnisbundle exportieren und menschlich prüfen. Der Export
  wurde beim angeforderten Stopp nicht mehr durchgeführt.
- Besonders auf Übergröße/Clipping der neuen 39-pt-Steine, Doppel-Schatten durch
  Asset plus SwiftUI, Labelkontrast und Kartenüberdeckung achten.
- Danach Phase 1 und 2 vollständig in Portrait und `667 x 375` Landscape testen.
- R1-Asset-Audit um 340-x-340-RGBA, Alpha-Ecken und identische Silhouette ergänzen.
- HTML-Abnahme mit direktem Soll-Ist-Vergleich aktualisieren, nach TEMP kopieren und öffnen.
- `tasks/parallel-orchestration.md` um diesen Integrationspunkt ergänzen.

Keine Aussage wie „perfekt“ oder „genau getroffen“ machen, bevor der neue echte
Simulatorbeleg neben `SCR-20260718-jszw.png` menschlich bestanden hat.

## 5. Verbindliche cmux-Orchestrierung für die neue Session

Arbeit möglichst in getrennte parallele cmux-Sessions gliedern. Die Sessions dürfen
nicht gleichzeitig dieselben Dateien ändern. Für jede schreibende Spur bevorzugt
einen eigenen Git-Worktree und einen klar benannten Arbeitsbranch verwenden; eine
read-only QA-Session darf den Integrationsworktree beobachten.

### `poch-lead`

- einziger Integrator und einzige Session für `main`;
- Hoheit über `ContentView`, `Phase2View`, `GameState`, Presentation Director,
  `DesignTokens`, zentrale Doku und Integrationsreihenfolge;
- übernimmt Material-/QA-Ergebnisse, führt den vollständigen Build aus, erstellt
  den Integrationscommit und pusht;
- keine zweite Session darf parallel zentrale Views anfassen.

### `poch-material`

- eigener Worktree;
- Hoheit über Disc-/R1-/Travel-Assets, `PlayComponents.swift`,
  `R1TokenLayout.swift`, Materialprofile sowie isolierte Materialtests;
- keine Änderungen an `ContentView`, `GameState` oder Presentation Director;
- liefert einen kleinen überprüften Commit an `poch-lead`.

### `poch-qa`

- bevorzugt read-only gegen den Lead-Build oder eigener Worktree für reine Tests;
- Hoheit über UI-Tests, Audit-Skripte, Screenshot-Export und HTML-Evidenz;
- bewertet Ästhetik nicht automatisch als bestanden; meldet konkrete P0/P1-Befunde
  mit Screenshotpfaden und Reproschritten;
- ändert keine Produktkomposition.

### `poch-rules-opponents`

- eigener Worktree nur wenn Änderungen nötig sind, sonst read-only;
- Hoheit über PochKit-Regeltreue, Tutorial-Seeds, Bot-Informationsgrenzen,
  Gegnerdaten und öffentliche Tendenzen;
- keine visuellen Material- oder zentralen Viewänderungen.

### Integrationsprotokoll

1. Jede Session startet mit `git status`, nennt Branch/Worktree und Dateihoheit.
2. Keine Session setzt fremde Änderungen zurück.
3. Material, Regeln und QA liefern kleine, testbare Commits; nur `poch-lead`
   integriert sie in festgelegter Reihenfolge.
4. Vor einem Lead-Commit: Diff-Herkunft prüfen, gezielte Verträge, echter Simulator,
   menschliche Screenshot-QA, dann Doku synchronisieren.
5. Nur Lead pusht `main`. Danach selbstständig mit dem nächsten priorisierten
   Goal-Punkt fortfahren, bis der Nutzer ausdrücklich stoppt.

## 6. Goal-Zustand

Das langfristige Goal wurde zuvor technisch als `blocked` geführt, obwohl kein
aktueller Produktblocker bestand. Der Nutzer hat es ausdrücklich wieder aufgenommen.
Die neue Session soll deshalb praktisch weiterarbeiten und das Goal erst bei echter
Gesamterfüllung als abgeschlossen markieren. Ein bestandener Einzelcommit ist kein
Endpunkt. Der aktuelle Nutzerwunsch ist jedoch ein bewusster Stopp für Kontextreset;
erst in der neuen Session fortfahren.
