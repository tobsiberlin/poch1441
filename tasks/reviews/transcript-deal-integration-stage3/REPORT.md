# Transcript Deal Integration - Stage 3

Stand: 20.07.2026, 16:42 Uhr

## Ergebnis

**STAGE_3_GREEN**

Genau ein Consumer ist integriert: `FlyingBack` kann den in Stage 2 technisch
und menschlich freigegebenen Kartenplan hinter einem DEBUG-Launch-Schalter
abspielen. Ohne diesen Schalter - und in jedem Release-Build - bleibt
`ImpactFlight` der unveränderte Standardpfad.

`GameState`, PochKit, Kartenidentität und Zielstapel wurden nicht für den Player
umgebaut. Audio und Haptik sind weiterhin nicht angebunden. Stage 4 darf beginnen;
eine breite Produktionsintegration bleibt gesperrt.

## Schaltergrenze und Blast Radius

- `-transcriptDealQA` wählt Standardwiedergabe.
- `-transcriptDealReducedMotionQA` wählt den synchronen Reduced-Motion-Endzustand.
- `CertifiedDealTranscript.requestedDebugMode` liefert außerhalb von `#if DEBUG`
  immer `nil`.
- Der alte `ImpactFlight`-Zweig bleibt im selben `FlyingBack` als unmittelbarer
  Fallback bestehen.
- `App/GameState.swift` ist gegenüber dem Stage-3-Ausgangszustand bytegleich;
  SHA-256: `38672f537a0c049d403e41b34b3062d1fdea187270ab5efa9e2c937501f53e81`.
- Unter `PochKit/**` existiert keine Worktree-Änderung.

## Lifecycle-Vertrag

Der renderer-neutrale `TranscriptMotionPlayer` tastet `CACurrentMediaTime()` ab.
Der SwiftUI-Consumer aktualisiert nur seine Pose. Der bestehende
`CardFlightTransaction`-Gate bleibt die einzige Brücke zum Produktzustand:

1. `onContact` registriert den generationgebundenen Kontakt und ruft danach
   exakt einmal `game.markDealLanded(_:)` auf.
2. `onRest` schließt erst anschließend die lokale Transaktion ab.
3. Settle zählt bis `onRest` als Bewegung.
4. Entfernt Skip oder ein Generationstausch die View, beendet Task-Cancellation
   die Abtastung ohne einen nachträglichen Callback.
5. `GameState.presentation.impact` weist doppelte oder durch Skip abgebrochene
   Events weiterhin zurück und ordnet Kontakte über `landedDealIndices`.

Der Transcript-Zweig hält die zwei zuletzt kontaktierten View-Identitäten noch
bis zur lokalen Ruhe vor. Nach Ruhe sind sie unsichtbar; dadurch wird Settle
nicht am Kontakt abgeschnitten, ohne den GameState um einen zweiten Zähler zu
erweitern.

## Acht-Karten- und Reduced-Motion-Gates

Der reine Scheduler-Test verwendet für acht Karten weiterhin
`actualStart(i) = max(rhythmTarget(i), restWindowStart(i-2))`. In jeder
Millisekundenprobe sind einschließlich Settle höchstens zwei Karten bewegt.

Auf einem iPhone-17-Pro-Simulator mit iOS 26.2 bestanden anschließend drei echte
UI-Flows:

- Standard: mindestens acht tatsächliche Kontaktmarker, während jeder Probe
  höchstens zwei `inFlight`- oder `settling`-Karten.
- Reduced Motion: mindestens acht identische Kontaktmarker, keine räumlich
  bewegte Karte und keine normale Flugzeit pro Transfer.
- Skip: ein sichtbarer Flug wird über das echte Board abgebrochen, die
  Präsentation atomar abgeschlossen und nach einer weiteren Sekunde weder ein
  Flug noch ein später State-Write beobachtet.

Ergebnis: **3/3 PASS**, keine Fehler, keine übersprungenen Tests. Der finale Lauf
war ohne Compilerwarnung. Das iOS-Simulator-Generic-Build für arm64 und x86_64
endete ebenfalls mit **BUILD SUCCEEDED**. Xcodes alleinige Buildnotiz ist das
erwartete Überspringen der AppIntents-Metadaten, weil keine AppIntents-Abhängigkeit
existiert.

## Transparenz zum ersten roten UI-Lauf

Der erste Lauf war `1 PASS / 2 FAIL`: Die Abfrage wartete auf die flüchtige exakte
Zeichenfolge `deal 8/`. Während Accessibility pollte, liefen Standard und Reduced
Motion bereits bis `deal 23/31` beziehungsweise `deal 26/31` weiter. Der Test
wurde auf numerisches `>= 8` umgestellt und prüft während des Wartens zugleich
die Zahl bewegter Karten. Für diese Korrektur wurde kein Produktcode geändert.
Das rote Receipt bleibt als `Evidence/resolved-red-run.json` erhalten.

## Menschliche visuelle Prüfung

Die eigenständigen Simulatoraufnahmen wurden vollständig und ungeschnitten in
QuickTime geprüft:

- Standard: `7,68 s`, `1206 x 2622`, H.264. Rücken bleiben aufrecht; Quelle,
  Tischquerung, Gegnerziele und Handziele sind kohärent; Kontakt und Settle zeigen
  keinen Teleport oder Rücklauf; maximal zwei Karten bewegen sich sichtbar.
- Reduced Motion: `5,5917 s`, `1206 x 2622`, H.264. Kein räumlicher Flug bleibt
  sichtbar; dieselben Zielstapel und die Hand wachsen über den Kontaktpfad.

Menschlicher visueller Gate: **GREEN**.

## Evidence und Hashanker

- `Evidence/ui-test-summary.json`: finaler 3/3-Simulatorlauf.
- `Evidence/resolved-red-run.json`: bewahrter erster roter Testlauf.
- `Evidence/technical-verdict.json`: technischer Stage-3-Receipt.
- `Evidence/human-visual-verdict.json`: getrenntes menschliches Urteil.
- `Evidence/standard-eight-card-wallclock.mp4`: ungeschnittener Standardbeleg.
- `Evidence/reduced-motion-eight-card-wallclock.mp4`: ungeschnittener
  Reduced-Motion-Beleg.
- `Evidence/standard-eight-contact.png` und
  `Evidence/reduced-motion-eight-contact.png`: Screens des finalen UI-Laufs.

Wichtige Source-SHA-256:

- `App/MotionPlaybackPlan.swift`: `8f50b68ff3141ad45f7d9eb751913c9c40af99678c15570a52821413561f6f16`
- `App/TranscriptMotionPlayer.swift`: `de6fe033b167015cf81695e6decac588756191d70b799539228b1e4d6ff50acb`
- `App/CertifiedDealTranscript.swift`: `31ec2da33aa6e270180d5ca12ee17b60d6d9b9644c41d7635bffc76e3df48e24`

## Abschlussstatus

- Technischer Gate: **GREEN**.
- Menschlicher visueller Gate: **GREEN**.
- Stage-3-Produkt-Gate: **GREEN**.
- Stage 4: **ERLAUBT**.
- Release-Default und breite Produktionsintegration: **BLOCKED**.

