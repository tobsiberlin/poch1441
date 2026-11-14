# Transcript Motion Player V1

Stand: 2026-07-20

## Ergebnis

**STAGE_2_GREEN**

Integrationsplan Stufe 2 ist als isolierter nativer iOS-/SwiftUI-DEBUG-Harness
umgesetzt und technisch sowie menschlich grün. Die ungeschnittene QuickTime-
Wiedergabe wurde bei nativer Größe geprüft: Quelle, Flug, Kontakt, Settle und
Ruhe bleiben aufrecht, räumlich kontinuierlich und lesbar. Stufe 3 darf damit als
eng begrenzter DEBUG-Hook beginnen; eine breite Produktionsintegration ist nicht
freigegeben.

Der Harness verändert weder `App/**` noch `GameState`, Audio, Haptik oder einen
Produktions-Hook.

## Scope und Provenienz

- `project.yml` kompiliert `../../../App/MotionPlaybackPlan.swift` direkt als
  Build-Quelle. Es existiert keine lokale Vertragskopie.
- Fail-fast SHA-256 des Produktvertrags:
  `8f50b68ff3141ad45f7d9eb751913c9c40af99678c15570a52821413561f6f16`.
- `Sources/**` instanziiert genau einen `MotionPlaybackPlan`:
  `card.deal.track-b.transcript-player.v1`.
- Der Plan ist über die echte Produktions-Property `isValid` validiert und besitzt
  Kontakt bei `0,54 s` sowie Ruhebeginn bei `0,72 s`.
- `TranscriptMotionPlayer` ist renderer-neutral. SwiftUI wird nur vom isolierten
  Diagnose-Stage und Evidence-Renderer importiert.

## Player-Vertrag

Der Player publiziert genau drei Callbacks:

- `onContact`
- `onRest`
- `onCancelBeforeRelease`

Standardwiedergabe tastet eine monotone Hostzeit ab. Der letzte Fortschritt wird
gespeichert, sodass eine rückläufige Uhr oder ein Cancel die Pose nicht
zurückspulen kann. Kontakt und Rest werden mit einer numerischen Grenztoleranz von
`1e-9 s` exakt einmal ausgelöst.

Settle bleibt bis einschließlich der Kante vor `onRest` ein bewegter Zustand.
Cancel vor Release liefert genau einmal `onCancelBeforeRelease` und weder Kontakt
noch Rest. Ein Cancel im committed Freiflug tastet zuerst den aktuellen
Hostzeitpunkt ab, ignoriert den räumlichen Abbruch und führt dieselbe Bahn bis
`onContact` und `onRest` fort.

Reduced Motion publiziert Kontakt und Rest synchron und endet auf demselben
kanonischen Sample wie die Standardwiedergabe. Gemessene Release-Latenz:
`0,0015 ms`. Eine versteckte Normalzeit-Wartefrist ist nicht vorhanden.

## Motion- und Diagnoseentscheidungen

Die Umsetzung folgt den eingesetzten `emil-design-eng`-Grundsätzen: Motion erklärt
den Zustandswechsel, committed Bewegung bleibt kontinuierlich und die Ansicht
enthält nur funktionale Diagnoseinformation.

| Before | After | Why |
| --- | --- | --- |
| Cancel konnte ohne gespeicherten Fortschritt auf ein älteres Sample zurückfallen. | Monotones `lastElapsedSeconds`; `cancel(at:)` tastet zuerst denselben Hostzeitpunkt ab. | Committed Bewegung bleibt räumlich kontinuierlich und wird nicht zurückgespult. |
| Exakte Double-Grenze konnte `onRest` um ungefähr `1e-15 s` verfehlen. | Markerprüfung mit `1e-9 s` Toleranz und kanonischem Endsample. | Kontakt und Rest sind deterministisch, ohne eine sichtbare Zusatzwartezeit. |
| Eine symmetrische Debug-Fläche machte den Encoding-Orientierungsabstand knapp uneindeutig. | Funktionale `SOURCE`- und `REST`-Marker verstärken die räumliche Leserichtung. | Der dekodierte Pixelvergleich kann einen Flip eindeutig erkennen, ohne dekorative Animation. |

## Technische Evidence

### XCTest

- Ergebnis: `7/7` bestanden, `0` fehlgeschlagen, `0` übersprungen.
- Swift 6 mit vollständiger Strict-Concurrency-Prüfung.
- Diagnostics bei Fehlern deaktiviert, pro Test `30 s` Timeout, damit ein
  fehlgeschlagener Simulator-Test nicht in einer 600-s-Diagnose hängen bleibt.
- Test-Source SHA-256:
  `160639cfa486464c90adf20952c66df2bcea9377349b15f5f7980e9bf6b0934e`.

Abgedeckt sind Planvalidierung, Callback-Einmaligkeit und -Reihenfolge, Settle als
Bewegung, Cancel vor Release, committed Cancel, Posekontinuität ohne vorheriges
Sampling, Schutz gegen rückläufige Hostzeit, Reduced-Motion-Endzustand und
renderer-neutrale Interpolation.

### Standard-Wallclock-Capture

- Viewport: exakt `402 x 874`.
- Frames: `61/61`, ungeschnitten, nominell `60 fps`, keine Audiospur.
- Median: `16,665 ms`.
- p95: `16,766 ms`.
- Maximum: `17,290 ms`.
- Callbacks: exakt `onContact -> onRest`.
- Als bewegt gezählte Settle-Frames: `11`.

### Reale Wallclock-Messsegmente

Die Segmente verwenden `CACurrentMediaTime` und absolute Zielraster. Sie beweisen
die Player-Abtastung und nicht die physische Bildwiederholrate eines Gerätepaneels.

| Zielrate | Intervalle | Median | p95 | Maximum |
| --- | ---: | ---: | ---: | ---: |
| 60 Hz | 48 | 16,660 ms | 17,666 ms | 17,722 ms |
| 80 Hz | 64 | 12,499 ms | 13,255 ms | 13,394 ms |
| 120 Hz | 96 | 8,332 ms | 8,988 ms | 9,196 ms |

Alle drei Segmente liefern exakt `onContact -> onRest`, erreichen `resting` und
enden bei derselben Position `(0,90; 0,86)`.

### Cancel und Reduced Motion

- Cancel vor Release: `1 x onCancelBeforeRelease`, `0 x onContact`, `0 x onRest`.
- Committed Cancel: als ignoriert markiert, danach exakt
  `onContact -> onRest`, Endphase `resting`.
- Reduced Motion: exakt `onContact -> onRest`, Endphase `resting`, bytegleiches
  kanonisches Endsample zur Standardbahn.

### Dekodierter Pixel-Gate

18 framegenaue H.264-Samples wurden gegen die vor dem Encoding gerenderten
Contact-Sheet-Zellen verglichen.

- Gewinner: `upright`.
- Upright MAE: `1,303`.
- Nächstbester Kandidat: horizontal gespiegelt mit MAE `3,381`.
- Winning Margin: `2,079`, Mindestwert `2,0`.
- Vertical Flip und 180-Grad-Drehung verlieren ebenfalls eindeutig.

Dieser Gate prüft die technische Orientierung. Das davon getrennte menschliche
Urteil über Rhythmus, räumliche Kontinuität und Lesbarkeit ist ebenfalls grün.

## Menschliche visuelle Prüfung

Am 20.07.2026 um 16:13 Uhr wurde die ungeschnittene Standardaufnahme in
QuickTime bei nativen `402 x 874` geprüft. Zusätzlich wurden Start, mittlerer
Freiflug, Kontakt/Settle und Endruhe framegenau angefahren.

- Karte, `W2`, `SOURCE` und `REST` bleiben in allen Phasen aufrecht.
- Der Pfad ist vom Quellstapel bis zum Ziel räumlich kohärent und zeigt keinen
  Sprung oder Rücklauf.
- Der Kontaktmarker schaltet am Ziel; die anschließende kurze Settle-Bewegung
  endet stabil in derselben Ruhepose.
- Die funktionale Diagnoseleiste ist lesbar und verdeckt weder Quelle noch Ziel.
- Das Kontaktblatt bestätigt denselben Verlauf über alle 18 Stichproben.

Menschlicher visueller Gate: **GREEN**.

## Receipts und Hashes

- `Evidence/test-verification.json`: XCTest-Receipt.
- `Evidence/manifest.json`: Wallclock-, Callback-, Cancel- und Reduced-Motion-Rohdaten.
- `Evidence/orientation-verification.json`: dekodierter Pixelvergleich.
- `Evidence/verification.json`: aggregierter technischer PASS.
- `Evidence/technical-verdict.json`: unverändertes technisches Vorab-Receipt
  `TECHNICAL_GREEN_HUMAN_PENDING`.
- `Evidence/human-visual-verdict.json`: getrenntes autoritatives
  `HUMAN_VISUAL_GREEN`-Receipt.
- `Evidence/SHA256SUMS`: Hashbindung aller Evidence-Dateien.

Wichtige SHA-256-Werte:

- Player: `428c2acfcb31573a54d67c75eae5e91fc2735e0fa8b2b0f4885939755e0f6d00`.
- Manifest: `faff2beb32bfa8f3dd1c23f61cf7dfb8bc272ede81ffcdef853f72a1fbfda194`.
- Aggregierte Verifikation:
  `cbf9e0a6ce506ce8cb09161989526b290be89420ba3ff25c9e44c0890fc3de61`.
- Orientierungsverifikation:
  `40d4fe404259cb5a6e9da3a4c7aeeaff52a4692d0853e85a8a9b7bb726ce699d`.
- MP4: `43bd2799681e7a2d27f5b3015d9b84d6905cd4c069fa372dc8eb0a5e6a7182ea`.

## Offene Gates und Risiken

1. **STUFE 3 PENDING:** Es existiert noch kein Hook in `FlyingBack`; die
   Produktionsansicht verwendet weiterhin ausschließlich den bisherigen Pfad.
2. Die 60/80/120-Hz-Evidence ist ein klarer monotonic-clock Messharness im
   Simulator, kein Hardware-ProMotion-Nachweis.
3. Der isolierte W2-Debugkörper ist keine Materialfreigabe; dafür bleibt das
   separate Card-Material-V5-Gate maßgeblich.
4. Jede Änderung an `App/MotionPlaybackPlan.swift` stoppt den Harness über die
   SHA-Bindung, bis die Änderung bewusst neu geprüft wird.
5. Stage 2 erlaubt nur den im Integrationsplan beschriebenen, schaltbaren
   Einzelkarten-Debug-Hook. GameState-, PochKit-, Audio- und Haptik-Umbauten sowie
   eine breite Produktionsfreigabe bleiben gesperrt.

## Reproduktion

```sh
cd /Users/tobsi/poch1441/tasks/reviews/transcript-motion-player-v1
./Scripts/run.sh
```

Der Lauf generiert das Xcode-Projekt, führt die sieben Tests aus, exportiert die
Wallclock-/Hz-Evidence, prüft Video-Metadaten und Pixelorientierung, schreibt alle
Receipts und entfernt anschließend ausschließlich die eigene `.derived` sowie den
eigenen temporären Inspector und das temporäre XCResult.

## Abschlussstatus

- Technischer Gate: **GREEN**.
- Menschlicher visueller Gate: **GREEN**.
- Stage-2-Produkt-Gate: **GREEN**.
- Nächster Schritt: **STUFE 3 DEBUG-HOOK ERLAUBT**.
- Breite Produktionsintegration: **BLOCKED**.
