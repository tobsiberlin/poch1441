# Card Deal Rhythm Wallclock V3 - RED

## Urteil

**Cancel-Semantik GREEN. Technische Evidence PASS. Gesamter Produkt-Lock RED. Nicht integrieren.**

V3 behebt isoliert den roten V2-Cancelpfad. Ab Cancel startet kein neuer Peel.
Alle Karten, deren geplanter Start bereits vor dem Cancel liegt, bleiben auf derselben
monotonen Wallclock-Zeitbasis und laufen ohne Retarget, Rückflugbahn oder Fade bis
Kontakt, Settle und Ruhe. Die beim Cancel noch bewegten Karten 4 und 5 zeigen in der
Capture beide vollständig `travel → contact → settle → rest`; maximal zwei Körper
bleibt in jedem Frame bindend.

Die tatsächlichen encodierten MP4-Dateien offenbaren jedoch einen separaten
menschlichen Produktfehler: Standard, Reduced Motion und Cancellation stehen sowohl
in Quick Look als auch im direkten Frame-Decode vertikal gespiegelt. Die vor dem Encoding
gerenderten Kontaktbögen stehen korrekt. Weil der Auftrag die Capture-Mechanik
ausdrücklich einfriert, wurde dieser geerbte Pipelinefehler nicht still mitbehoben.
Damit ist V3 trotz grüner Cancel-Korrektur insgesamt **RED**.

Der bindende menschliche Receipt liegt in
[human-wallclock-verdict.json](Evidence/human-wallclock-verdict.json).
`verification.json` und `verified.complete` bescheinigen nur den technischen Umfang
des Verifiers und sind keine Produktfreigabe.

## Isolierte V3-Korrektur

- `HarnessCardPhase.cancelling` und der Rendererpfad zurück zur Quelle wurden entfernt.
- Für Cancellation werden nur Karten mit `actualStartSeconds < cancellationSeconds`
  committed. Karten ab Cancel bleiben unsichtbar und reduzieren den Deckzähler nicht.
- Committed Karten benutzen nach Cancel unverändert ihre geplanten Marker
  `contactStartSeconds`, `settleStartSeconds` und `restWindowStartSeconds`.
- Das Evidence-Ende liegt jetzt 280 ms hinter dem letzten Restmarker einer committed
  Karte, statt 140 ms nach Cancel künstlich leerzuräumen.
- Der Verifier verlangt für jede committed Karte Start, Kontakt, Settle und Rest
  innerhalb von zwei Capture-Frames. Für künftige Karten müssen alle Capture-Marker
  fehlen. Für die beim Cancel aktiven Karten muss die Post-Cancel-Phasenfolge vollständig
  und monoton sein. Ein `.cancelling`-Marker, ein neuer Peel oder ein dritter Körper
  schlägt fehl.

Keine Datei in `App/**`, V1 oder V2 wurde geändert.

## Eingefrorene Verträge

| Vertrag | SHA-256 / Nachweis |
| --- | --- |
| V1-Source und lokale V3-Kopie | beide `2294f03d7fa1079b737ff6274aad36555d1a3acad018b8f0f0659a3251e8487c` |
| W2-Body V2 und V3 | beide `b5c745e86aae6c3cab7ebb7cd43589885067db60612dc95b4ea38b7e6ad53aac` |
| W2 Damage 2x V2 und V3 | beide `6bd5fe1d61e256f9833ffc02340f51e6560164e12827f5b6ac274ada5af5040c` |
| W2 Damage 3x V2 und V3 | beide `d9d5faa5ce1a2314c0a00a1ea48c06954afbb400509def2ae8f1c5c2c37bba21` |
| Native VideoInspector V2 und V3 | byte-identisch |
| Standard / Reduced Motion | dieselben Profile, Seeds, Dauern, Scheduler und Rendererpfade wie V2 |

## Test und technischer Verifier

Der gezielte Lauf erfolgte auf einem iPhone 17 Pro Simulator mit iOS 27.0
(`304220D7-C4FB-4994-A1A4-9BD1D4AA9E9D`). Vor Installation und nach Export wurde die
Prozess- und Bundle-Identität geprüft. `xcodebuild test` bestand **8/8 Tests**, ohne
Fehler oder Skips. Danach lief der native Export genau einmal; ein reiner
Verifier-Keyfehler für von Swift ausgelassene `nil`-Optionals wurde korrigiert und
der vorhandene Evidence-Satz ohne zweiten Build oder Export erneut verifiziert.

Ergebnis: `CardDealRhythmEvidenceV3: PASS`.

| Sequenz | Capture / Video | Median | p95 | Maximum | max. aktiv | unsichtbare Wartezeit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Standard | `196 / 196` Frames | `16.664 ms` | `17.409 ms` | `17.731 ms` | `2` | `0 s` |
| Reduced Motion | `82 / 82` Frames | `16.663 ms` | `17.411 ms` | `17.695 ms` | `2` | `0 s` |
| Cancellation | `121 / 121` Frames | `16.667 ms` | `17.358 ms` | `17.751 ms` | `2` | `0 s` |

Alle drei Dateien besitzen eine stumme Videospur, `402 x 874 px`, fortlaufende
Frameindizes und nominal etwa 60 fps. Die MP4-Orientierung ist nicht Bestandteil des
technischen Verifiers; genau deshalb bleibt der menschliche RED-Receipt notwendig.

## Cancellation-Nachweis

Cancel liegt bei `1.176197159949348 s`.

| Karten | Ergebnis |
| --- | --- |
| 1 bis 5 / Indizes `0...4` | vor Cancel committed; alle vier Capture-Marker vorhanden |
| 4 und 5 / Indizes `3, 4` | nach Cancel vollständig `travel → contact → settle → rest` |
| 6 bis 8 / Indizes `5...7` | kein sichtbarer Frame, kein Capture-Marker, kein Peel |
| letzter committed Rest | `1.710632874808307 s` |
| Post-Cancel-Peels | `0` |
| Maximum aktive Körper | `2` |

Die encodierten Review-Strips stammen direkt aus den MP4-Dateien:

- [Standard](Evidence/402x874-standard-encoded-review-strip.png)
- [Reduced Motion](Evidence/402x874-reducedMotion-encoded-review-strip.png)
- [Cancellation](Evidence/402x874-cancellation-encoded-review-strip.png)

Sie belegen zugleich den korrekten Cancel-Auslauf und den blockierenden
Spiegelungsfehler an der horizontalen Achse.

## Maßgebliche Hashes

| Datei | SHA-256 |
| --- | --- |
| `manifest.json` | `624eacd95745ae419029fd3e05e942f374d47e385559910c691f6ac504699332` |
| `verification.json` | `cda95a269db387c46dce41b64d576f92771ea53ec532a55d74dfe6228379fc16` |
| Standard MP4 | `85f35f20a5d71e18c71b4363461071248c926d93f5b7db5023e36cff69e2c14c` |
| Reduced Motion MP4 | `9d555042598f3697bb27a51f5475200b82d7c7288c2e5b86e21ccd10814825c0` |
| Cancellation MP4 | `145d55ec3658824f4a3c93f3c3dde474cbbf1ab51facf068d83b406005249c37` |
| Standard encoded strip | `031f0dc4df9b47acfda646aca08934a7396f63db19decdea5eba95508d39d16f` |
| Reduced Motion encoded strip | `cea942b9b4782fe7ba3119545fc1f33139839e5b108e6e78a52fb5466235ee82` |
| Cancellation encoded strip | `b8b049047c22a490bd5247d49b7d4a7e80d73787ba0efa30c5e5755b3794827f` |

## Nächster Gate-Schritt

Eine nachfolgende Iteration muss ausschließlich den Pixelbuffer-/Video-
Orientierungspfad korrigieren und danach alle drei ungeschnittenen MP4s erneut
exportieren. Erst wenn Quick Look und direkter Decode aufrecht stehen und die hier
grüne Cancel-Semantik weiterhin besteht, kann der Wallclock-Produkt-Lock grün werden.
Bis dahin bleibt jede Produktionsintegration gesperrt.
