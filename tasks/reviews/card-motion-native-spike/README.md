# Card Motion Native Spike

Isolierte iOS-17-SwiftUI/XcodeGen-App für den nativen Card-Motion-Vertrag. Sie
ändert keine Produktdatei und besitzt keinen App-Callsite.

## Enthaltene Verträge

- per-card Zustandsmaschine für Deal, Fan, öffentliches Reveal, Play, Return
  vor Kontakt und Settled
- generation-sichere Kontakte und Completions
- exakt ein Haptikereignis am akzeptierten Kontakt
- kein Feedback bei Abbruch, stale Completion oder Reduce-Motion-Settle
- zwei SwiftUI-Geschwisterebenen: lineare, nicht kippende Bodenprojektion und
  separat gebogene beziehungsweise rotierte Kartenfläche
- live wirksames Reduce Motion mit 100-ms-Ausfade, stillem Settle und
  120-ms-Einblende
- deterministischer Export bei festen Progresswerten
- `CADisplayLink`-Echtzeitprobe

Audio ist absichtlich nicht enthalten: Im Produktbestand existiert kein
freigegebenes Kartenkontakt-Audio. Die R1-Keramikgeräusche werden nicht
zweckentfremdet. Der Kontaktvertrag kapselt deshalb Haptik und lässt einen
späteren synchronen Audiosink nur am selben akzeptierten Kontakt zu.

## Reale Referenzen

Die App verwendet keine generische Platzhalterkarte:

- W2-Rückseite: eingefrorene Geometrie aus `App/CardBack.swift`, lokale
  identitätsneutrale Patina und kopierte Produktionslage
  `card_back_damage_04`
- öffentliche V10-Vorderseite: kopiertes Produktionsasset
  `card_hearts_ace`

Die Kopien liegen ausschließlich in `Resources/Assets.xcassets` dieses Spikes.

## Vollständiger reproduzierbarer Lauf

Voraussetzungen: Xcode 26.2, XcodeGen 2.45.4 und ein verfügbarer
iPhone-Simulator.

```sh
cd tasks/reviews/card-motion-native-spike
./Scripts/run.sh
```

Optional kann ein bestimmter Simulator verwendet werden:

```sh
SPIKE_SIMULATOR_UDID=<UDID> ./Scripts/run.sh
```

Der Lauf generiert das Projekt, baut mit iOS-17-Deployment-Target, führt die
Unit-Tests aus, installiert die App, exportiert 15 progressinjizierte PNGs und
führt die Echtzeitprobe aus. Ergebnisse landen unter `Evidence/`.

## Einzelkommandos

```sh
xcodegen generate --spec project.yml
xcodebuild \
  -project CardMotionNativeSpike.xcodeproj \
  -scheme CardMotionNativeSpike \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath .derived \
  test
```

Die progressinjizierten PNGs belegen Geometrie und z-order reproduzierbar. Die
Echtzeitprobe ist getrennt und misst Display-Link-Intervalle. Ein Simulatorlauf
ist kein Nachweis für ein reales iOS-17-Gerät; `RESULT.md` weist diese Grenze
explizit aus.

