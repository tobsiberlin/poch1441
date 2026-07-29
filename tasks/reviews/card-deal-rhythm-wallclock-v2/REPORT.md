# Card Deal Rhythm Wallclock V2 - RED

## Verdict

**Technische Evidence PASS. Menschlicher Produkt-Lock RED. Nicht integrieren.**

Standard und Reduced Motion bestehen den sichtbaren Rhythmuscheck. Der
Cancellation-Beleg verletzt jedoch die verbindliche Commit- und Cancel-Policy:
Der Abbruch liegt mitten im Freiflug der vierten Karte. Noch bewegte Karten
werden danach innerhalb von `140 ms` räumlich zur Quelle zurückgeführt und
gleichzeitig ausgeblendet. Ab Release ist ein solcher Teleport-Cancel verboten.
Der Ballistikkörper muss seinen zertifizierten Pfad bis Kontakt und Ruhe
fortsetzen; nur zukünftige Peels dürfen entfallen.

Zusätzlich sind die drei kodierten MP4-Dateien in QuickTime sichtbar vertikal
gespiegelt. Die vor dem Encode erzeugten Kontaktbögen sind aufrecht; damit ist
dies ein eigenständiger Capture-/Encode-Fehler und kein Fehler der
Rhythmusdarstellung. Auch deshalb sind die Videos nicht als menschlicher
Produktnachweis freigegeben.

`verification.json` und `verified.complete` bleiben gültige technische
Nachweise für Dateivollständigkeit, Wallclock-Cadence und maximal zwei aktive
Karten. Sie sind ausdrücklich kein menschliches Produkturteil. Der bindende
Review-Receipt liegt in
[human-wallclock-verdict.json](Evidence/human-wallclock-verdict.json).

## Vollständiger Verifier-Lauf

Der native AVFoundation-Inspector wurde neu aus
[VideoInspector.swift](Scripts/VideoInspector.swift) kompiliert. Danach lief
[verify_evidence.py](Scripts/verify_evidence.py) gegen den bestehenden
Evidence-Satz. `Scripts/run.sh` wurde nicht aufgerufen, es gab keinen neuen
Build, keinen Simulator-Export und keine Mutation des Manifests oder der drei
Videos.

Ergebnis: `CardDealRhythmEvidenceV2: PASS`.

| Sequenz | Capture / Video | Median | p95 | Maximum | max. aktiv | unsichtbare Wartezeit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Standard | `196 / 196` Frames | `16.664 ms` | `17.601 ms` | `17.742 ms` | `2` | `0 s` |
| Reduced Motion | `82 / 82` Frames | `16.659 ms` | `17.658 ms` | `17.726 ms` | `2` | `0 s` |
| Cancellation | `97 / 97` Frames | `16.674 ms` | `17.554 ms` | `23.780 ms` | `2` | `0 s` |

Alle drei Clips besitzen genau eine stumme Videospur, `402 x 874 px` und eine
nominale Bildrate um `60 fps`. Der Verifier bindet weiterhin den unveränderten
V1-Source-Vertrag über
`2294f03d7fa1079b737ff6274aad36555d1a3acad018b8f0f0659a3251e8487c`.

SHA-256 der maßgeblichen Evidence:

| Datei | SHA-256 |
| --- | --- |
| `manifest.json` | `d20c7bda4e402d02553db394d7c35a97e5452f83d01d5166fe0e338fd37838ce` |
| `verification.json` | `e3ce7c842b8cec02ab004487d0feb632d30535c8137bc55286c3df142114f867` |
| Standard MP4 | `59001a4a4fa1ea6db2112e1b77eb19e0731ce04cfe0e4b0aba6f056f20648bb2` |
| Reduced Motion MP4 | `dbb72da537997a8962c27d6b277192ba2a2d4744baba49b391600135e2c5d1d0` |
| Cancellation MP4 | `d7d896f2c27798f9ae0ac0c34bd38401fb376da908db44c4816dc10214bfc17d` |

## Menschliche Sichtprüfung

| Before | After | Why |
| --- | --- | --- |
| Standard zeigt die ersten zwei Karten mit spürbarer Spannung und baut danach Tempo auf. | **GREEN.** Tension, Acceleration, Recovery und Release sind als ein zusammenhängender Puls lesbar. | Der Deal wirkt komponiert, ohne dass mehr als zwei Körper gleichzeitig bewegt werden. |
| Settle könnte technisch aus dem Aktivzähler fallen und einen dritten Peel erlauben. | **GREEN.** Die Standbilder und die Timeline zeigen Settle weiterhin als Bewegung; der dritte Körper erscheint nicht. | Die sichtbare Ruhe, nicht nur der erste Kontakt, begrenzt den Rhythmus. |
| Reduced Motion könnte dieselben langen Wege unsichtbar abwarten. | **GREEN.** Kurze lokale Offsets, Settle und Target-Crossfades liefern alle acht Karten in `1.363 s`; `invisibleWaitSeconds = 0`. | Weniger räumliche Bewegung bleibt direkt und informativ, ohne Zeitstrafe. |
| Cancellation stoppt neue Peels, räumt aber aktive Karten sofort weg. | **RED.** Bereits gestartete Karten fahren zur Quelle zurück und blenden aus. | Das ist eine neue räumliche Exit-Bahn mitten im committed Freiflug und verletzt den zertifizierten Cancel-Vertrag. |
| Die vor dem Encode erzeugten Kontaktbögen sind aufrecht. | **RED.** Alle drei kodierten MP4-Dateien erscheinen in QuickTime an der horizontalen Achse gespiegelt. | Der technische Inspector bestätigt Pixelmaß und Framezahl, aber nicht die visuell korrekte Orientierung. |

Die sichtbare Problemstelle wird in
[RhythmHarnessModel.swift:66](Sources/RhythmHarnessModel.swift#L66) absichtlich
mitten in den Travel-Abschnitt gelegt. Danach ersetzt `snapshot` jede noch nicht
ruhende Karte durch `.cancelling`
([RhythmHarnessModel.swift:91](Sources/RhythmHarnessModel.swift#L91)). Der
Renderer interpoliert diese Karte zur Quelle zurück und reduziert ihre Opacity
auf null
([RhythmHarnessStage.swift:219](Sources/RhythmHarnessStage.swift#L219)).

Der technische Verifier prüft derzeit nur, dass nach dem Cancel kein neuer Peel
beginnt und dass nach `cancellationClearSeconds` keine Karte mehr aktiv ist
([verify_evidence.py:109](Scripts/verify_evidence.py#L109)). Genau diese
erfolgreiche Prüfung zertifiziert daher die falsche Produktsemantik.

## Unveränderte grüne Teilverträge

- `actualStart(i) = max(rhythmTarget(i), restWindowStart(i-2))` bleibt für alle
  Sequenzen erfüllt
  ([DealRhythmContract.swift:244](Sources/DealRhythmContract.swift#L244)).
- Standard und Reduced Motion zeigen acht Karten, kontinuierliche 60-Hz-
  Wallclock-Samples und maximal zwei aktive Körper.
- Reduced Motion enthält keine versteckte Wartephase.
- Die W2-Kartenkörper im Harness beanspruchen weiterhin kein Materialurteil und
  die Videos enthalten absichtlich kein Produkt-Audio.

## Erforderliche Folgekorrekturen

Die nächste Rhythmusiteration darf Standard, Reduced Motion, W2-Körper und
V1-Provenienz nicht verändern. Die Cancel-Semantik wird ersetzt:

1. Ab Cancel dürfen keine noch nicht gestarteten Karten peelen.
2. Karten vor Release dürfen ohne neue Flugbahn an der sichtbaren Quelle
   bleiben.
3. Karten im Freiflug laufen auf derselben monotonen Zeitbasis bis Kontakt,
   Settle und Ruhe weiter.
4. Bereits kontaktierte Karten beenden ebenfalls ihr Ruhefenster.
5. Der Verifier muss nach Cancel nicht `activeCount == 0` erzwingen, sondern
   dieselben geplanten Kontakt-, Settle- und Restmarker für alle vor Cancel
   gestarteten Karten nachweisen.
6. Der neue ungeschnittene Clip muss sichtbar zeigen: keine neuen Peels, keine
   Rückflugbahn, kein Fade-out, maximal zwei Körper und ein kausal vollständiger
   Auslauf.

Separat muss die Capture-/Encode-Pipeline korrigiert werden. Die neuen MP4s
müssen in QuickTime und bei direkter Frame-Dekodierung aufrecht erscheinen,
ohne Model, Scheduler, Rhythmus oder Cancel-Vertrag erneut zu verändern.

Es wurden keine App-Dateien und keine produktiven Bewegungswege geändert.
