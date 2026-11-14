# Card Motion Native Spike V2 - Ergebnis

**Ausgeführt:** 2026-07-19  
**Technischer Spike-Vertrag:** **GREEN**  
**Visuelles Approval:** **RED / REVIEW REQUIRED**  
**App-Approval:** **RED / WITHHELD**

## Entscheidung

V2 behebt die drei konkret benannten V1-Blocker auf Implementierungs- und
Belegebene:

1. Der Schatten ist kein Kreis oder Ellipsen-Blob mehr, sondern ein weicher,
   perspektivischer Kartenfußabdruck auf einer eigenen linearen Tischbahn.
2. Deal und Play besitzen exakte Quell-/Zielposen einschließlich Größe und
   Winkel. Deal startet auf `deckTop`, endet in `handSlot`; Play startet dort
   und endet in `playTarget`.
3. Deal, Reveal, Play und Return sind getrennte Segmente mit eigenem lokalen
   Fortschritt und eigenen Framebelegen.

Das ist keine visuelle Selbstfreigabe. Die erzeugten Belege sind zur externen
Prüfung bereit, der visuelle Status bleibt bis zu diesem Review RED.

## Technische Verifikation

Umgebung:

- Xcode 26.2, Build 17C52
- XcodeGen 2.45.4
- iOS-Deployment-Target 17.0
- Swift 6.0 mit Strict Concurrency `complete`
- iPhone 17 Pro Simulator, iOS 26.2
- Simulator-UDID `D1923D48-6E8D-4157-B703-8B05CC334D08`

Reproduzierbarer Lauf:

```sh
cd tasks/reviews/card-motion-native-spike-v2
SPIKE_SIMULATOR_UDID=D1923D48-6E8D-4157-B703-8B05CC334D08 ./Scripts/run.sh
```

Ergebnis:

- Build erfolgreich
- 13 Tests, 0 Fehler
- keine Swift-6-Concurrency-Warnung
- einziger Xcode-Hinweis: übersprungene AppIntents-Metadaten ohne
  AppIntents-Abhängigkeit

Die Tests belegen:

- vier eigenständige Segmentpläne
- exakte Deal-/Play-Endpunkte in 390x844, 667x375 und 402x874
- Reveal bleibt räumlich im Hand-Slot
- Return beginnt exakt an der abgebrochenen Play-Pose und tastet dieselbe
  Trajektorie bis zum Hand-Slot rückwärts ab
- Return-Plan ist bei oder nach Kontaktfortschritt 1 nicht erzeugbar
- 1.001 lineare Schatten-Samples je Deal, Play und Return
- Schattenrotation immer exakt 0
- Schatten wird mit Höhe größer, weicher und heller
- Renderer enthält `PerspectiveCardFootprint`, aber weder `Ellipse` noch `Circle`
- Generation, Duplicate Contact, stale Contact, Abbruch und stilles Reduce
  Motion erfüllen den Kontaktvertrag
- echte W2-/V10-Assets sind im Bundle kompiliert

## Feste Segmentbelege

`Evidence/manifest.json` enthält 60 feste PNGs:

| Segment | 390x844 | 667x375 | 402x874 | Gesamt |
|---|---:|---:|---:|---:|
| Deal | 5 | 5 | 5 | 15 |
| Reveal | 5 | 5 | 5 | 15 |
| Play | 5 | 5 | 5 | 15 |
| Return | 5 | 5 | 5 | 15 |

Jedes Segment besitzt die lokalen Progresswerte 0,00, 0,25, 0,50, 0,75 und
1,00. Dadurch kann kein einzelner globaler Fortschritt mehr unterschiedliche
Beats vermischen.

Kritische Reviewframes:

- `Evidence/402x874-deal-progress-000.png`
- `Evidence/402x874-deal-progress-100.png`
- `Evidence/402x874-play-progress-000.png`
- `Evidence/402x874-play-progress-100.png`
- `Evidence/402x874-return-progress-000.png`
- `Evidence/402x874-return-progress-100.png`
- `Evidence/667x375-deal-progress-050.png`
- `Evidence/667x375-play-progress-050.png`

## Hochfrequenter Echtzeit-Contact-Sheet

Beleg: `Evidence/realtime-contact-sheet-402x874.png`

- 64 zeitgetaktete Frames
- 16 Frames je Segment
- Sollfrequenz 24 FPS
- effektive Frequenz 23,981 FPS
- Dauer 2,627 s
- 0 verpasste Deadlines
- maximale Verspätung 2,646 ms
- Sheetgröße 1072x2331 px

Der Contact-Sheet zeigt die Segmente blockweise in der Reihenfolge Deal,
Reveal, Play und Return. Er wurde aus wall-clock-getakteten Einzelrenderings
erzeugt, nicht aus nachträglich interpolierten Zwischenbildern.

## Echtzeit-Frameprobe

Separater `CADisplayLink`-Lauf mit Deal, Reveal, Play, Return-Abbruch und live
Reduce Motion:

| Messwert | Ergebnis |
|---|---:|
| Samples | 344 |
| Dauer | 5,761 s |
| p95 | 16,667 ms |
| Maximum | 16,667 ms |
| Frames im 60-Hz-Budget | 100 % |
| aufeinanderfolgende Paare über 33,3 ms | 0 |
| Simulator-Verdict | GREEN |

Das ist ein Simulatorbeleg, kein physischer iOS-17-Performancebeleg.

## Visuelles Review-Gate

Der externe Reviewer muss insbesondere entscheiden:

1. Liest der Schatten in Deal- und Play-Mitte als weicher Kartenfußabdruck und
   nicht mehr als amorpher Blob?
2. Wirken Blur-, Größen- und Opazitätsänderung über die Flughöhe plausibel?
3. Ist Deal bei t=0 deckungsgleich mit dem Decktop und bei t=1 deckungsgleich
   mit dem mittleren Fächerslot?
4. Ist Play bei t=0 deckungsgleich mit demselben Slot und bei t=1 mit der
   gestrichelten Zielpose?
5. Liest Return als echte Umkehr vor Kontakt und nicht als nachträgliches Undo?
6. Bleiben die Übergänge im 64-Frame-Sheet ohne Größen- oder Positionssprung?

Bis diese Fragen extern positiv beantwortet sind, bleibt **Visual RED**.

## App-Gates

Auch bei visueller Spike-Freigabe bleiben vor Produktintegration offen:

- physisches Gerät mit iOS 17
- echte App-Callsites und maximal zwei parallele Deal-Flüge
- stilles Reduce-Motion-Settle in `GameState`
- Phase-3-Informationsgrenze über öffentliche `revealedPlayEvents`
- kombinierte App-Regressions- und Performanceprüfung

## Scope

Alle neuen beziehungsweise geänderten Dateien liegen ausschließlich unter
`tasks/reviews/card-motion-native-spike-v2/**`. Es gab keine App-, Status- oder
cmux-Änderung und weder Commit noch Push.

