# Transcript Coin Feedback - Stage 4

Stand: 20.07.2026, 20:56 Uhr

## Ergebnis

**STAGE_4_TECHNICAL_GREEN_HARDWARE_PENDING**

Der isolierte QA-Consumer spielt genau einen zertifizierten 6DoF-Cent-Drop
über der äußeren Queen-Mulde ab. Physikbindung, Lifecycle, Materialdarstellung,
Audio-Fingerprint und die gemeinsame Audio-/Haptik-Zeitkante sind technisch
grün. Der finale Simulatorclip hat den menschlichen visuellen Gate bestanden.

Stage 4 ist trotzdem **nicht als Produkt-Gate freigegeben**: Es ist kein
physisches iPhone verbunden. Das Lautsprecherurteil sowie die verpflichtende
240-fps/96-kHz-Synchronmessung und die Haptikbeurteilung bleiben pending. Eine
breite oder Release-Produktionsintegration bleibt gesperrt.

Der physische Test ist ohne Kabel über TestFlight möglich. Aktueller Kandidat:
Version `0.1.0`, Build `8` wurde von App Store Connect verarbeitet und an die
internen Tester verteilt. Der Export trägt
`testFlightInternalTestingOnly: true`; dieser Kandidat kann weder externes
TestFlight noch den App Store bedienen. Das ist ausschließlich ein Transportweg
für die weiterhin offenen Hardware-Gates und keine Produktfreigabe.

Build 6 war ebenfalls erfolgreich verteilt, Apple meldete danach jedoch den
nicht blockierenden Hinweis `ITMS-90730`: Die vom Debug-Preset geerbte Einstellung
`MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE` hatte Metal-Quell- beziehungsweise
Debuginformation in `default.metallib` eingebettet. InternalQA setzt seit Build 7
gezielt `MTL_ENABLE_DEBUG_INFO = NO`. Der archivierte Metal-Compile-Befehl enthält
dadurch weder `-g` noch `-frecord-sources`; normaler Debug und Release wurden nicht
umgestellt. Build 6 bleibt als historischer Warnbeleg erhalten und soll nicht mehr
für den Test verwendet werden.

Build 7 startete laut Nutzerbericht auf dem physischen iPhone über TestFlight
nicht, sondern beendete sich unmittelbar. Ein Geräte-Crashlog war nicht verfügbar;
deshalb wird keine konkrete Crash-Frame-Ursache behauptet. Der Artefaktaudit
belegte jedoch einen eigenständigen Lieferfehler: InternalQA erbte weiterhin das
Debug-Preset, war `-Onone`, testbar und verlinkte `DeveloperToolsSupport`. Build 8
ersetzt diesen Pfad durch ein optimiertes Release-Preset mit ausschließlich
`INTERNAL_QA`. Das signierte Archiv und die exportierte IPA enthalten weder
`DeveloperToolsSupport` noch eine Debug-Dylib. Build 7 ist rot und darf nicht mehr
getestet werden; der physische Start von Build 8 ist ein neuer offener Retest.

## Interner TestFlight-Gerätepfad

- Separates Xcode-Scheme `Poch1441InternalQA`, Konfiguration `InternalQA`.
- Die Konfiguration erbt Release und ergänzt ausschließlich `INTERNAL_QA`.
- `SWIFT_OPTIMIZATION_LEVEL = -O`, `ENABLE_TESTABILITY = NO` und
  `ENABLE_DEBUG_DYLIB = NO`.
- Der normale `Poch1441`-Release-Build bleibt ohne QA-Einstieg und baut grün.
- Im internen Build öffnet Einstellungen den Punkt
  „Münzkontakt auf diesem iPhone testen“.
- Der Gerätebildschirm spielt denselben zertifizierten Queen-Well-Drop ab und
  bietet Standard, Reduced Motion, Sound und Haptik getrennt an.
- App Store Connect: `0.1.0 (8)`, verarbeitet und intern verteilt.
- IPA SHA-256:
  `aa6bd56c7366276c1cad967ee7c069481c0384613de59241bf99bbee88b6c3d2`.
- Transportstatus: **DISTRIBUTED_INTERNAL_DEVICE_LAUNCH_RETEST_REQUIRED**.
- Hardwareurteil: weiterhin **PENDING**.

## Genaue Scope-Grenze

- `-transcriptCoinQA` aktiviert den Standardpfad ausschließlich in DEBUG.
- `-transcriptCoinReducedMotionQA` aktiviert denselben Endzustand synchron.
- Beide Schalter gelten nur für Track B (`theme == .unterwegs`).
- Ohne Schalter bleibt der Hook abwesend; der normale Release-Build enthält
  `TranscriptCoinDrop` und `CoinContactFeedbackEngine` nicht. Nur InternalQA
  kompiliert sie explizit über `INTERNAL_QA` mit Release-Optimierung.
- `GameState`, PochKit, `PochBetFlight`, `PochPayoutFlight`, `pochShock` und
  `R1ContactFeedback` wurden nicht auf den Player umgebaut.
- Der Beleg ist ein zertifizierter **Queen-Well-Drop**, der ungefähr 52 mm über
  der Mulde beginnt. Er ist ausdrücklich kein vollständiger Wurf vom
  Quellstapel und erfüllt nicht stillschweigend die gesamte Blueprint-Flugphase.

## Daten- und Physikbindung

`App/CertifiedCoinTranscriptSeed1441.json` ist ein deterministischer Auszug aus
dem 12-Seed-Quellbundle. Der Player konsumiert echte Position, Quaternion,
lineare und angulare Geschwindigkeit bei 240 Hz. Er interpoliert Quaternionen
über den kürzesten Slerp-Bogen und beendet die Bewegung am ersten zertifizierten
Ruhemarker.

- Quellbundle SHA-256:
  `76e883093a396548b07060d29d3f2149857240c1026cd1fefe35450de52d98be`
- App-Transcript SHA-256:
  `a7b3a945452b737d8e64d01bd12fab51689d1220406fd10044502f4ba8045ca7`
- Erster Kontakt: Sample 18 bei `0,075 s`.
- Zertifizierte Ruhe: Sample 387 bei `1,6125 s`.
- Maximale Kontaktenergiezunahme: `0`.
- Penetration: unter `0,5` physikalischen Pixeln.
- Auswahl: 12 Varianten, geschützte Historie 8, keine Wiederholung darin.

## Lifecycle und Abbruch

Karten- und Münzplayer verwenden dieselbe renderer-neutrale
`TranscriptPlaybackTimeline`. Der bestehende `CoinTransferTransaction` bleibt
der einzige Gate für den sichtbaren Zustand:

1. Release bindet Event-ID und Generation und betritt `departed`/`airborne`.
2. Der Transcript-Kontakt ruft `registerImpact` exakt einmal auf.
3. Settle bleibt bis `restCertified` sichtbar bewegt.
4. Erst danach folgen `beginSettling` und `complete`.
5. Reduced Motion durchläuft dieselbe kausale Kontakt-vor-Ruhe-Reihenfolge ohne
   unsichtbare Flugwartezeit.
6. Ein Teardown vor Kontakt storniert geplante physische Ausgaben. Nach Kontakt
   erzeugt ein Abbruch weder Rollback noch einen zweiten Kontakt.

Der UI-Lauf auf `Poch1441-QA-16Pro`, iOS-Simulator 26.2, bestand **3/3**:
Standard, Reduced Motion und standardmäßig abwesender Hook. Es gab keine
Fehler oder übersprungenen Tests und nach `@MainActor` keine Concurrencywarnung.

## Material- und visueller Gate

Der erste Runtime-Kandidat war rot: Er las als flache orange Scheibe, verlor die
V3-Relieftiefe und hatte eine zu schwache Vorderlippenwirkung. Video und
Kontaktbogen bleiben unter `Evidence/resolved-red-*` erhalten.

Der finale Consumer verwendet einen zur Buildzeit aus dem menschlich grünen
V3-Renderer erzeugten 7-x-14-Atlas mit 98 Frames. Der Atlas ist bei erneutem
Erzeugen bytegleich:

- `coin-transcript-sprite-atlas@3x.png`: 1344 x 2688 px,
  SHA-256 `74af07a0cdca4b4276e2b69eb0a2c5f40a586581bcbc0b393439798ecc52f0f9`.
- Die tatsächlichen Boardpixel werden über `QueenFrontLipMask` wieder vor die
  Münze gelegt.
- Der ungeschnittene Clip `queen-drop-final-uncut.mp4` dauert `31,1783 s` und
  wurde vollständig in QuickTime abgespielt.
- Genau ein Cent, plausible Größe, sichtbares Relief und Orientierung, kohärente
  Lippenverdeckung und stabiler Ruhepunkt wurden bestätigt.

Menschlicher visueller Teilgate: **GREEN**.

## Audio und gemeinsame Kontaktzeit

`cent-copper-polycarbonate-01.wav` ist ein deterministisch synthetisierter,
eigenständiger 96-kHz-Mono-Int16-Fingerprint. Eine erneute Erzeugung lieferte
bytegleich SHA-256
`b4ed82c4bddbf201f604aacede596555775981678e434c7bcf76bdcd5525b3d5`.

Technische Kennwerte:

- Dauer `0,18 s`, Peak `0,859985`, keine geclippten Samples.
- DC-Offset `0,00000658`.
- 10-Prozent-Onset nach `20,8 µs`.
- Early RMS `0,2130`, Tail RMS `0,0132`.
- Kleinster spektraler RMSE-Abstand zu den sechs Keramikassets: `27,66 dB`.

Ein `MotionContactCue` trägt dieselbe Event-/Generationsidentität und genau einen
zertifizierten `contactHostTime`:

- `AVAudioPlayerNode` plant den Buffer direkt mit `AVAudioTime(hostTime:)`.
- Core Haptics besitzt laut Apple eine unabhängige Engine-Zeit. Daher wird die
  verbleibende Host-Dauer auf `CHHapticEngine.currentTime` abgebildet.
- Sound und Haptik respektieren ihre Settings unabhängig auf demselben Cue.
- Simulator- oder Sessionfehler blockieren den visuellen State-Commit nicht.

Der Audio-Fingerprint ist technisch **GREEN**. Das menschliche
Lautsprecherurteil ist **PENDING**.

## Verifikation

- iOS-Debug-Build für `Poch1441-QA-16Pro`: **BUILD SUCCEEDED**.
- `CoinMotionTranscriptTests`: **PASS**.
- `TranscriptMotionPlayerTests`: **PASS**.
- `CoinTransferPlanTests`: **PASS**.
- `MotionContactCueTests`: **PASS**.
- `TranscriptCoinIntegrationContractTests`: **PASS**.
- `Phase2PresentationContractTests`: **PASS**.
- `TranscriptCoinDropUITests`: **3/3 PASS**.
- `InternalCoinQAUITests`: **3/3 PASS** - Einstieg über Einstellungen,
  Standard-Drop und Reduced-Motion-Drop bis Kontakt/Ruhe.
- Release-basierter `Poch1441InternalQA`-Simulatorbuild: **BUILD SUCCEEDED**.
- Normaler Start ohne QA-Argumente: **9/9 PASS** mit fortbestehendem Prozess.
- InternalQA-Compile mit Swift-/Clang-Warnungen als Fehler: **PASS**.
- Normaler `Poch1441`-Release-Simulatorbuild: **BUILD SUCCEEDED**; keine
  `DEBUG`-/`INTERNAL_QA`-Kompilierungsbedingung.
- Signiertes internes Archiv und IPA: **ARCHIVE/EXPORT SUCCEEDED**.
- Archiv und exportierte IPA: `DeveloperToolsSupport` **ABSENT**, Debug-Dylib
  **ABSENT**, Signatur **PASS**, `get-task-allow = false`.
- Fastlane verweigert künftige InternalQA-Uploads automatisch, wenn
  `DeveloperToolsSupport` oder eine Debug-Dylib wieder auftauchen.
- App Store Connect: Build `0.1.0 (8)` **PROCESSED + DISTRIBUTED TO INTERNAL TESTERS**.
- Metal-Archivcheck: `MTL_ENABLE_DEBUG_INFO = NO`; Compile-Befehl ohne
  Source-/Debug-Flags. `ITMS-90730` aus Build 6 damit an der Quelle behoben.
- PochKit-Regelkern: **63/63 PASS** (54 XCTest + 9 Swift Testing).
- `afinfo`: 1 Kanal, 96.000 Hz, Int16, 0,18 s.
- PochKit-Worktree: unverändert.

Xcodes einzige Meldung außerhalb des warnings-as-errors-Compiles ist die bereits
erwartete ausgelassene AppIntents-Metadatenextraktion, weil keine
AppIntents-Abhängigkeit existiert.

## Bewusst offene Gates

`xctrace list devices` meldet nur den Mac und Simulatoren. Deshalb fehlen noch:

1. 240-fps-Gerätevideo über die visuelle Kontaktkante.
2. 96-kHz-Geräteaufnahme desselben Kontakts.
3. Gemessener Audio-zu-Visual-Offset gegen den Produktgrenzwert.
4. On-device-Beurteilung von Haptikcharakter und Settings-off-Verhalten.
5. Menschliches Lautsprecherurteil für Kupfer auf Polycarbonat.

Bis alle fünf Belege grün sind, bleibt der Stage-4-Produkt-Gate
**BLOCKED_PENDING_HARDWARE** und jede Produktionsintegration **BLOCKED**.

## Historische rote Gates bleiben rot

Der frühere Bericht `coin-motion-transcript-gate-v1` besitzt einen roten
visuellen V1-Gate. Dessen Status wird durch diesen späteren V3-Materialconsumer
nicht umetikettiert. Ebenso bleibt der erste flache Stage-4-Runtime-Kandidat als
aufgelöstes rotes Evidence erhalten.

## Evidence

- `Evidence/ui-test-summary.json`
- `Evidence/technical-verdict.json`
- `Evidence/human-visual-verdict.json`
- `Evidence/audio-fingerprint-receipt.json`
- `Evidence/hardware-gate.json`
- `Evidence/resolved-red-visual.json`
- `Evidence/testflight-internal-build.json`
- `Evidence/testflight-internal-qa-screen.png`
- `Evidence/testflight-build6-itms-90730.png`
- `Evidence/testflight-build7-startcrash.json`
- `Evidence/queen-drop-final-uncut.mp4`
- `Evidence/queen-drop-final-contact-sheet.png`
- `Evidence/queen-drop-final-rest.png`
- `Evidence/resolved-red-flat-coin-uncut.mp4`
- `Evidence/resolved-red-flat-coin-contact-sheet.png`

## Abschlussstatus

- Technischer Implementierungs-Gate: **GREEN**.
- Physik-/Lifecycle-Gate: **GREEN**.
- Menschlicher visueller Teilgate: **GREEN**.
- Audio-Fingerprint technisch: **GREEN**.
- Human-Audio: **PENDING**.
- Physisches Sync-/Haptik-Gate: **PENDING_NO_DEVICE**.
- Stage-4-Produkt-Gate: **BLOCKED_PENDING_HARDWARE**.
- Release-Default und Produktionsintegration: **BLOCKED**.
