# Card Deal Rhythm - Wallclock V4 - GREEN

## Status

**TECHNICAL GREEN. HUMAN WALLCLOCK GREEN. PRODUKT-GATE GREEN.**

Der isolierte V4-Harness besteht Build, acht Tests, den unveränderten V3-Timing-Verifier und den neuen dekodierten Pixelorientierungs-Verifier. Der Lead hat anschließend alle drei MP4-Dateien vollständig in QuickTime geprüft. Standard, Reduced Motion und Cancellation sind aufrecht, visuell kontinuierlich und entsprechen den technischen Receipts. Der Produkt-Gate ist damit grün; Produktionscode wurde in diesem Review nicht geändert.

## Enger V4-Scope

V4 behebt ausschließlich den Encode-Orientierungsfehler aus V3:

- Die vorherige `CGContext`-Translation und Y-Skalierung vor `AVAssetWriter` wurde entfernt. Sie spiegelte die bereits aufrechte `UIImage` im geschriebenen Pixelbuffer vertikal.
- Der Ausgabeordner und die Harness-Namen wurden auf V4 umgestellt.
- Model, Scheduler, Cancellation-Semantik, Stage, W2, V1-Vertrag und der V3-Timing-Verifier sind byte-identisch zu V3 und werden vor Export und Verifikation fail-fast geprüft.
- `App/**` und ältere Review-Harnesses wurden nicht verändert.

## Eingefrorene Verträge

| Datei | SHA-256 |
| --- | --- |
| `Sources/DealRhythmContract.swift` | `2294f03d7fa1079b737ff6274aad36555d1a3acad018b8f0f0659a3251e8487c` |
| `Sources/RhythmHarnessModel.swift` | `37760e68efee123be56c6f9ae8e3a6ed06ed4ca2b16087c856082367544aacfe` |
| `Sources/RhythmHarnessStage.swift` | `48bc7fc8646b24b3ae847dbd660994ad2f0347950729d447843fe34b1916db85` |
| `Sources/W2CardBody.swift` | `b5c745e86aae6c3cab7ebb7cd43589885067db60612dc95b4ea38b7e6ad53aac` |
| `Scripts/verify_evidence.py` | `ef11bdb73f3212f1f14a7ab6549515bf6e62e567a4950cbb252453d9f52dd15b` |
| `Scripts/VideoInspector.swift` | `a86915e6ad6e207af688c98b34a78756fa844cbb5c58bb9a2dd80a1d572ca4bf` |
| `Scripts/make_encoded_review_strips.py` | `15dead7b50ea94d4c9b25833c14bb9c4e138ab7aef5d81db4855b64b3c903ee0` |

Der V4-Recorder hat SHA-256 `2ea0396f9bc7d7e731f604ffb972b8718416cd2994eeeba62aebcab90ca8070a`.

## Dekodierter Pixelvergleich

`Scripts/verify_orientation.py` prüft nicht nur Track-Metadaten:

1. Für jede Sequenz werden dieselben 24 gleichmäßig verteilten Frame-Indizes wie für den pre-encode Kontaktbogen berechnet.
2. OpenCV dekodiert die H.264-MP4 und skaliert jeden ausgewählten Frame mit `INTER_AREA` exakt auf seine Kontaktbogen-Zelle.
3. Der Vergleich läuft in Graustufen gegen vier Kandidaten: aufrecht, vertikal gespiegelt, horizontal gespiegelt und 180 Grad gedreht.
4. Pro Kandidat wird die mittlere absolute Pixelabweichung, P95 und Maximum berechnet.
5. Fail-fast gilt: Aufrecht muss gewinnen, seine mittlere Abweichung muss höchstens `5.0` betragen und der Abstand zum zweitbesten Kandidaten mindestens `2.0`.

| Sequenz | Aufrecht MAE | 180 Grad MAE | Zweitbeste MAE | Gewinnabstand | Ergebnis |
| --- | ---: | ---: | ---: | ---: | --- |
| Standard | 3,087 | 11,935 | 7,429 | 4,343 | PASS |
| Reduced Motion | 3,118 | 11,756 | 7,141 | 4,023 | PASS |
| Cancellation | 3,012 | 12,623 | 7,879 | 4,867 | PASS |

Die native Orientierung gewinnt damit in allen drei Sequenzen eindeutig und liegt auch deutlich vor der 180-Grad-Variante. Die anschließende QuickTime-Sichtprüfung bestätigt das Ergebnis.

## Wallclock- und Video-Verifikation

| Sequenz | Capture/Video-Frames | Nominale FPS | Median | P95 | Maximum | Max. aktive Karten | Unsichtbare Wartezeit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Standard | 196/196 | 60,000 | 16,662 ms | 17,498 ms | 17,704 ms | 2 | 0 s |
| Reduced Motion | 82/82 | 60,149 | 16,657 ms | 17,459 ms | 17,715 ms | 2 | 0 s |
| Cancellation | 121/121 | 60,050 | 16,664 ms | 17,381 ms | 17,744 ms | 2 | 0 s |

Alle drei Dateien haben genau einen 402x874-H.264-Videotrack, keinen Audiotrack und eine nominale Bildrate um 60 fps.

Cancellation bleibt committed free-flight:

- Karten 0 bis 4 sind vor Abbruch committed.
- Die aktiven Karten 3 und 4 durchlaufen nach Abbruch monoton `travel -> contact -> settle -> rest`.
- Karten 5 bis 7 starten nicht.
- Nach dem Abbruch werden keine Karten neu abgezogen.
- Drain vollständig bei `1,710632874808307 s`.

## Evidence

- [Standard MP4](Evidence/402x874-standard-uncut-60fps.mp4)
- [Reduced-Motion-MP4](Evidence/402x874-reducedMotion-uncut-60fps.mp4)
- [Cancellation-MP4](Evidence/402x874-cancellation-uncut-60fps.mp4)
- [Standard - dekodierter Review-Strip](Evidence/402x874-standard-encoded-review-strip.png)
- [Reduced Motion - dekodierter Review-Strip](Evidence/402x874-reducedMotion-encoded-review-strip.png)
- [Cancellation - dekodierter Review-Strip](Evidence/402x874-cancellation-encoded-review-strip.png)
- [Timing-Receipt](Evidence/verification.json)
- [Orientierungs-Receipt](Evidence/orientation-verification.json)
- [V4-Aggregat-Receipt](Evidence/v4-verification.json)
- [Menschlicher GREEN-Receipt](Evidence/human-wallclock-verdict.json)
- [SHA256SUMS](Evidence/SHA256SUMS)

Zentrale Hashes:

| Artefakt | SHA-256 |
| --- | --- |
| Manifest | `500c928619afb03cf7dbe07fde61840c19f033fcf77a0fbb0a6687e6e4e830ed` |
| Timing-Receipt | `aefa9d1da22b5d08b2f07c8a2228aac8f6c72b6b11c7be3cc335ef9907686cf8` |
| Orientierungs-Receipt | `8acee9a64ef3b5486fc938f3bcd9a673bba6dc3d73c9d6558f2b852628a79f0b` |
| V4-Aggregat-Receipt | `4e4fe8289381e6d80d13adff61b8811cd73cd01727bd180ea39aac58ce343d3d` |
| Standard MP4 | `f0b552ab6438976b2b63044e5ffa18dfcbed0809f6f2192694321248f00829d4` |
| Reduced-Motion-MP4 | `51df1f4f245be10c23e228402818df5899a16e4cca86e1dd5af38b9ff7c7c4bb` |
| Cancellation-MP4 | `9e048ef3c8cc703d4de82184a414925f0476b0d89256a8e6f6efc0391dab132b` |

## Checks

- `xcodebuild ... test`: Exit 0, acht Tests.
- Basis-Timing-Verifier: PASS.
- Dekodierter Orientierungs-Verifier: PASS für 3/3 Sequenzen.
- Native AVFoundation-Inspektion: 196/196, 82/82 und 121/121 Frames; 402x874; kein Audio.
- V3-Freeze: 7/7 Dateien byte-identisch und erwartungsgemäß gehasht.
- V4-`.derived`: entfernt.
- Temporärer Video-Inspector: entfernt.
- V4-App-Prozess: beendet.

## Menschliche Freigabe

Alle drei MP4-Dateien erscheinen in QuickTime aufrecht. Standard zeigt den
beabsichtigten Spannungs-, Beschleunigungs-, Recovery- und Release-Puls mit
maximal zwei bewegten Körpern. Reduced Motion erreicht denselben Endzustand
direkt und ohne versteckte Normalzeit. Cancellation lässt die fünf committed
Karten sichtbar bis Kontakt, Settle und Ruhe auslaufen; die drei zukünftigen
Karten bleiben im Deck, es gibt keinen Rückflug und keinen Fade-out. Der
Wallclock-Produkt-Gate ist grün. Damit ist die im Integrationsplan definierte
reine Datennaht zulässig; dieser Review selbst ändert weiterhin keinen
Produktionscode.
