# Card Motion Native Spike - Ergebnis

**Ausgeführt:** 2026-07-19  
**Spike-Vertrag auf Simulator:** **GREEN**  
**App-Approval:** **RED / WITHHELD**

## Kurzentscheidung

Der kleinste native Card-Motion-Pfad ist als isolierter SwiftUI-Spike technisch
belegt. Zustandsmaschine, Generation, einmaliger Kontakt, stilles Reduce-Motion-
Settle, Abbruch vor Kontakt, lineare nicht kippende Tischschattenprojektion und
gebogene Kartenfläche bestehen ihre Tests. Die festen Bildbelege zeigen echte
W2- und öffentliche V10-Materialien in allen drei Zielgrößen.

Eine Produktfreigabe wäre trotzdem unehrlich: Der verfügbare Lauf erfolgte auf
einem iPhone-17-Pro-Simulator mit iOS 26.2, nicht auf physischer Hardware und
nicht auf einer iOS-17-Runtime. Deshalb bleibt App-Approval RED.

## Umgebung

- Xcode 26.2, Build 17C52
- XcodeGen 2.45.4
- `IPHONEOS_DEPLOYMENT_TARGET = 17.0`
- Swift 6.0, `SWIFT_STRICT_CONCURRENCY = complete`
- iPhone 17 Pro Simulator, iOS 26.2
- Simulator-UDID: `D1923D48-6E8D-4157-B703-8B05CC334D08`

## Build und Tests

Reproduzierbarer Lauf:

```sh
cd tasks/reviews/card-motion-native-spike
SPIKE_SIMULATOR_UDID=D1923D48-6E8D-4157-B703-8B05CC334D08 ./Scripts/run.sh
```

Ergebnis:

- XcodeGen-Projekt erfolgreich erzeugt
- App und Unit-Test-Bundle erfolgreich für iOS-17-Deployment-Target gebaut
- 8 Tests, 0 Fehler
- keine Swift-6-Concurrency-Warnung
- zwei harmlose Xcode-Hinweise, dass ohne AppIntents-Abhängigkeit keine
  AppIntents-Metadaten extrahiert wurden

Die Tests decken ab:

- erlaubte und illegale Zustandsübergänge
- kein `settled -> return`
- genau ein Kontaktfeedback pro akzeptierter Generation
- Duplicate- und stale Kontakte bleiben inert
- Abbruch vor Kontakt invalidiert die alte Generation
- Reduce Motion settelt ohne Feedback
- 1.001 Samples einer exakt linearen Schattenbahn
- Schattenrotation für jedes Sample exakt 0
- gemeinsame Karten-/Schattenendpunkte und sichtbare Bogenabhebung
- symmetrische Return-Endpunkte
- beide kopierten Produktionsassets sind wirklich im App-Bundle kompiliert

## Reale Materialien

Die W2-Rückseite nutzt die eingefrorene Geometrie aus `App/CardBack.swift`, die
exakten Poch-Juweltokens, denselben festen W2-Patina-Generator mit
180-Grad-Paaren, das skalengleiche `1441`-Monogramm und die kopierte
identitätsneutrale Schadenslage `card_back_damage_04`.

Die Vorderseite ist das öffentliche Produktionsasset `card_hearts_ace` aus der
V10-Kartenserie. Es gibt keine generische Platzhalterkarte.

SHA-256 der kopierten Referenzen:

| Asset | 2x | 3x |
|---|---|---|
| W2-Schadenslage | `6bd5fe1d61e256f9833ffc02340f51e6560164e12827f5b6ac274ada5af5040c` | `d9d5faa5ce1a2314c0a00a1ea48c06954afbb400509def2ae8f1c5c2c37bba21` |
| V10 Herz Ass | `bcd0f4cb2b7aecea2048de5b95d1924fee6eae6b02b5123a69cafd9c55877e99` | `9430caf718cf8f92e38f30f62f164ee2a182d1ce698cb54eb10537e8a3f95a1b` |

## Feste Framebelege

`Evidence/manifest.json` enthält 15 deterministisch über `ImageRenderer`
erzeugte PNGs:

- 390 x 844 px
- 667 x 375 px
- 402 x 874 px als aktuelle iPhone-17-Pro-Breite
- feste Progresswerte 0,00, 0,25, 0,50, 0,75 und 1,00

Visuelle Prüfung:

- W2-Quelle, aktiver Flug und Ziel-Fächer sind in Portrait und Landscape klar
  getrennt.
- Die aktive Karte liegt über dem statischen Fächer.
- Der Schatten bleibt als flache Projektion auf der linearen Bodenbahn und
  übernimmt weder Kartenrotation noch 3D-Flip.
- Bei Progress 0,50 steht die Karte absichtlich nahezu kantenparallel im
  Reveal-Flip; die separate Bodenprojektion bleibt sichtbar.
- Bei Progress 0,75 ist die öffentliche V10-Vorderseite vollständig sichtbar.
- Kein Clipping oder horizontaler Überlauf in den drei geprüften Größen.

## Echtzeitprobe

Frischer `CADisplayLink`-Lauf mit Deal, Reveal, Play, Return-Abbruch und live
Reduce Motion:

| Messwert | Ergebnis | Simulator-Gate |
|---|---:|---:|
| Samples | 330 | mindestens 180 |
| Dauer | 5,575 s | mindestens 5 s |
| p95 Frameintervall | 16,667 ms | höchstens 17,417 ms inklusive Messtoleranz |
| Maximum | 19,960 ms | informativ |
| Frames im 60-Hz-Budget | 99,697 % | mindestens 95 % |
| aufeinanderfolgende Paare über 33,3 ms | 0 | exakt 0 |
| Probe-Verdict | GREEN | GREEN |

Der Echtzeitlauf belegt nur die Simulatorimplementierung. Er ersetzt keine
Instruments-Messung auf einem thermisch stabilisierten realen Gerät.

## Offene App-Gates

Vor einem GREEN für die Produktintegration fehlen weiterhin:

1. derselbe Lauf auf einem physischen Gerät mit iOS 17,
2. ein physischer 60-Hz-Lauf unter realer GPU-, Haptik- und Thermallast,
3. Integration in `DealOverlay` mit maximal zwei parallelen Flügen,
4. stilles Accessibility-Settle in den echten `GameState`-Callsites,
5. Phase-3-Prüfung gegen öffentliche `revealedPlayEvents`,
6. Regressionstests gegen die App-eigene Informationsgrenze.

## Scope-Nachweis

Der Spike liegt vollständig unter
`tasks/reviews/card-motion-native-spike/**`. Es wurden keine Produkt-, Status-
oder cmux-Dateien geändert und weder Commit noch Push ausgeführt.

