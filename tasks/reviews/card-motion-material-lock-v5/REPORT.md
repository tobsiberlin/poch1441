# Card Motion Material Lock V5 - GREEN

## Ergebnis

**TECHNISCHER CAPTURE-/ENCODE-GATE PASS. MENSCHLICHER MATERIAL-GATE GREEN.
PRODUKTIONSÄNDERUNGEN NOCH NICHT AUSGEFÜHRT.** V5 entfernt ausschließlich die
zusätzliche vertikale Spiegelung im Pixelbuffer-Pfad von V4. Das neue MP4 wird
vollständig mit 82 Frames dekodiert; sein erster dekodierter Frame stimmt in
aufrechter Orientierung eindeutig mit dem gerenderten PNG überein.

Material, Model, Controller, Stage, W2-Vertrag und Timing wurden nicht geändert.
Kein Produktcode unter `App/**` wurde angefasst. Der Lead hat das ungeschnittene
MP4 anschließend in QuickTime vom aufrechten Quellframe über Freiflug und
Kontakt bis zur stabilen Ruhe geprüft. Orientierung, Material, Schatten und
Kartenfläche bleiben kohärent; der isolierte Material-Gate ist damit grün.

## Finding - vorher / nachher / warum

| Vorher | Nachher | Warum |
| --- | --- | --- |
| V4 spiegelte den bereits korrekt angeordneten `CGImage` vor `CGContext.draw` zusätzlich vertikal | V5 zeichnet den unveränderten `CGImage` direkt in den Pixelbuffer | Der zusätzliche Flip machte ausschließlich das kodierte MP4 vertikal gespiegelt; PNGs und Strips waren bereits aufrecht |
| V4 prüfte nur Trackdaten, Dimensionen und Framezahl | V5 dekodiert den MP4-Frame und vergleicht Identity, 180-Grad-Drehung sowie horizontale und vertikale Spiegelung gegen das gerenderte PNG | Ein formal gültiges, aber falsch orientiertes Video kann den technischen Gate nicht mehr passieren |
| V4 war wegen der Wiedergabeorientierung rot | V5 ist technisch und nach echter QuickTime-Sichtung menschlich grün | Automatische Pixelkorrespondenz und menschliche Wiedergabeprüfung stimmen überein |

## Harte Gates

| Gate | Ergebnis | Beleg |
| --- | --- | --- |
| V4 Material-/Motion-Lock | **PASS** | Sechs Quellen sind byte-identisch und auf ihre V4-SHA-256-Werte gebunden |
| Änderungsscope | **PASS** | Semantische Recorder-Änderung nur im Pixelbuffer-Encode-Pfad; keine Motion- oder Materialänderung |
| Statischer Realmaßstab | **PASS** | Exakt 402 x 874; Zielkarten-Kurzkante `54.85065110795071 px`; `motionAdvanced = false` |
| Wallclock-Evidence | **PASS** | 82 Frames, 60 fps, 240-Hz-Fixed-Step, kein synthetischer Fortschritt |
| Dekodierte Videoorientierung | **PASS** | Beste Zuordnung `identity`; MAE `6.3083`; Abstand zur nächstbesten Fehlorientierung `19.8989` |
| Videotrack | **PASS** | 402 x 874, 82 dekodierte Frames, 60 fps, 1,3667 s, kein Audiotrack |
| Plane Lock | **PASS** | Homography-RMS `6.355e-14 px`; stabile Restabweichung `0 px` |
| Kontakt/Rest | **PASS** | Erstkontakt Frame `47`; 28 stabile Restframes |
| QuickTime-Prüfung durch Lead | **GREEN** | Quelle, Freiflug, Kontakt und Ruhe aufrecht und visuell kohärent |
| Produktionsänderungen | **NICHT AUSGEFÜHRT** | Der grüne Gate erlaubt die geplante Datennaht; kein `App/**` wurde in diesem Review geändert |

## Eingefrorene V4-Quellen

| Quelle | SHA-256 |
| --- | --- |
| `FrozenMotionContract.swift` | `7aa0beebe0e505668f5f9c6fb933c323cad6bf93ba4ffd0398ed5d619199e0e1` |
| `MaterialLockController.swift` | `018504e26ab18f5605be1221d6d1022fcaf348ad943fa5d66c7ce7dbf9f075c6` |
| `MaterialLockModel.swift` | `57898a7157ca5e8c987021f4b412ca20d6daa402d84be066d732ffc07b59c32e` |
| `MaterialLockStage.swift` | `d6885cd33530a0f81876ca2af38499d49b56e72dde5f3f7768e6ef9c27cb08a3` |
| `ProductW2CardSurface.swift` | `c736fa2e6a01b75e55615b65a163366f5b22efcac4d59d4ce897767719e1e8b3` |
| `W2CardMaterialContract.swift` | `8d44945cd1b304442f331cd328bc34d94cf3ae5d907a457c8148e9e628a83573` |

## Verifikation

- Xcode iOS-Simulator: **18 Tests bestanden, 0 fehlgeschlagen, 0 übersprungen**
  auf iPhone 17 Pro mit iOS 26.2.
- Ein Build wurde für statische und vollständige Evidence wiederverwendet.
- Der native AVFoundation-Verifier reproduziert V4 als `verticalMirror` und
  akzeptiert V5 als `identity`.
- `shasum -a 256 -c Evidence/SHA256SUMS`: alle 11 ausgewählten Evidence-Dateien
  bestanden.
- JSON-Gates für Manifest und Orientierungsreceipt: bestanden.
- `cmp` für alle sechs eingefrorenen V4-Quellen: bestanden.
- `git diff --check` im V5-Scope: bestanden.

## Motion-Review-Verdikt

Es gibt keine neue Animation und keine Änderung an Ursprung, Timing, Easing,
Unterbrechbarkeit, Reduced Motion oder physikalischer Flugbahn. Der V4-Motion-
und Materialinhalt bleibt byte-identisch. Der technische Capture-Fix und der
übergeordnete menschliche Material-Gate sind damit **Approve/GREEN**.

## Evidence-Reihenfolge

1. `Evidence/wallclock-material-lock-v5-402x874.mp4`
2. `Evidence/decoded-first-frame-v5-402x874.png`
3. `Evidence/402x874-material-lock-v5-000.png`
4. `Evidence/video-orientation-verification.json`
5. `Evidence/uncut-material-lock-v5-sequence-402x874.png`
6. `Evidence/tight-first-edge-contact-v5-strip-402x874.png`
7. `Evidence/manifest.json`
8. `Evidence/SHA256SUMS`

## Verbleibendes Risiko

Der automatische Gate vergleicht den ersten dekodierten Frame und zählt alle
82 Frames. Da derselbe Pixelbuffer-Pfad für jeden Frame verwendet wird, deckt
dies den globalen Orientierungsfehler gezielt ab. Die anschließende vollständige
QuickTime-Sichtung zeigte keine spätere Orientierungs- oder
Wiedergabeauffälligkeit.

## Scope

Alle Änderungen liegen unter
`tasks/reviews/card-motion-material-lock-v5/**`. Es gab weder Commit noch Push.
