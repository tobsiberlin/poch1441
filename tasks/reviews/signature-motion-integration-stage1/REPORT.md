# Signature Motion Integration - Stufe 1 GREEN

Stand: 20.07.2026, 15:52 Uhr

## Ergebnis

Die reine, regelneutrale Motion-Datennaht ist integriert und verifiziert. Alle
drei vorgeschalteten Produktgates waren vor dem ersten Produktionsedit technisch
und menschlich grün. Stufe 1 verändert keine View, keinen Game State, keinen
Regeltyp, kein Audio und keine Haptik.

Neu sind ausschließlich:

- `App/MotionPlaybackPlan.swift`
- `Tests/MotionPlaybackPlanTests.swift`

## Freigebende Produktgates

| Gate | Menschliches Urteil | Receipt SHA-256 |
| --- | --- | --- |
| Coin Material V3 | GREEN | `3585269a11ad7eb8507e4877f23af5c26c456bbb58ae253684eb34764f66fa96` |
| Card Material V5 | GREEN | `469ec048c4df3125c98f5882d2c6c17cfb4eaffbb1047c3c8e40d2b36a9b0095` |
| Deal Wallclock V4 | GREEN | `344b7ddd3a4d5398ea197b62674fa7277873ed7f5c3b54aa0de71340800c2b39` |

## Datenvertrag

- `MotionSample` trägt normalisierte Zeit, Position, Tiefe, Rotation, Curl und
  Schatten ohne Renderer- oder Regeltyp.
- `MotionContactMarker` bindet Sample-Index, physische Kontaktzeit und
  Surface-ID.
- `MotionRestWindow` bindet ersten Ruhezeitpunkt und Mindestdauer.
- `MotionCancelPolicy.committedFlight` hält vor Release an der sichtbaren
  Quelle, lässt Freiflug auf dem zertifizierten Pfad auslaufen und erlaubt erst
  nach Kontakt sichtbare Gegenbewegung.
- `MotionPlaybackPlan` bindet stabile ID, Materialfamilie, World-Light-ID,
  Samples, Kontakt, Ruhe und Cancel-Policy und weist nicht-finite oder
  widersprüchliche Daten ab.
- `MotionVariantSelector` verlangt mindestens neun eindeutige Varianten. Ein
  deterministischer vollzyklischer Modulschritt verhindert exakte Wiederholung
  in jedem Fenster aus acht Transfers.
- `DealRhythmSchedule` implementiert
  `actualStart(i) = max(rhythmTarget(i), restWindowStart(i-2))`.
- `MotionTranscriptCodec` serialisiert JSON mit stabil sortierten Keys.

## Verifikation

- Eigenständiger Swift-6-Vertragstest mit vollständiger Strict Concurrency und
  warnings-as-errors: **PASS**.
- Kanonische Serialisierung: gleicher Seed ergibt bytegleiche Auswahl und einen
  identischen Decode-Roundtrip.
- 90 Auswahlen aus einem Neuner-Bucket: in jedem gleitenden Achterfenster acht
  verschiedene Plan-IDs.
- Invalides Kontakt-Sample, zu kleiner Bucket und nicht-finite Schedule-Daten
  scheitern geschlossen.
- Regelneutralitätscheck: kein `PochKit`, `GameState` oder `SwiftUI` im
  Datenvertrag.
- Vollständiger iOS-Simulator-Build für arm64 und x86_64: **BUILD SUCCEEDED**.
- Der temporäre Stage-1-DerivedData-Cache wurde anschließend entfernt.

SHA-256:

| Datei | SHA-256 |
| --- | --- |
| `App/MotionPlaybackPlan.swift` | `8f50b68ff3141ad45f7d9eb751913c9c40af99678c15570a52821413561f6f16` |
| `Tests/MotionPlaybackPlanTests.swift` | `7f80851aba04ce597fac98950dd670a8cc53ddafdf6409f7324c42a9e6986623` |

## Nächste Schranke

Stufe 2 bleibt isoliert und DEBUG-only. Erst ein eigener Player-Beleg darf
Kontakt, Ruhe, Cancel und Reduced Motion als Callbacks aus dem Transcript
publizieren. `FlyingBack`, `GameState`, `ImpactFlight`, Audio und Haptik bleiben
bis zu ihren jeweiligen späteren Stufen unverändert.

Es wurde weder committed noch gepusht.
