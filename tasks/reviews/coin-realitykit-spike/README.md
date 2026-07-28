# Coin RealityKit Falsifikationsspike

Isolierte iOS-App für eine maßhaltige 3D-Münze in einer statischen Mulde mit
geneigter Frontlippe. Der Spike enthält keine PochKit-Regeln, keine Slot-
Animation und keine App-Integration.

## Voraussetzungen

- Xcode 26.2 mit iOS-26.2-Simulator
- XcodeGen

## Build

```sh
cd tasks/reviews/coin-realitykit-spike
xcodegen generate --spec project.yml
xcodebuild \
  -project CoinRealityKitSpike.xcodeproj \
  -scheme CoinRealityKitSpike \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath .derived \
  build
```

Das Target hat `IPHONEOS_DEPLOYMENT_TARGET = 17.0`. Der ausgewertete Lauf fand
auf iOS 26.2 statt, weil RealityKit die benötigte öffentliche
Kontaktpenetration erst ab iOS 18 bereitstellt.

## Run und Bericht

```sh
xcrun simctl boot <UDID>
xcrun simctl bootstatus <UDID> -b
xcrun simctl install <UDID> \
  .derived/Build/Products/Debug-iphonesimulator/CoinRealityKitSpike.app
xcrun simctl launch <UDID> com.tobc.reviews.coin-realitykit-spike

APP_DATA=$(xcrun simctl get_app_container \
  <UDID> com.tobc.reviews.coin-realitykit-spike data)
cp "$APP_DATA/Documents/coin-realitykit-spike-result.json" runtime-result.json
```

Die App führt automatisch vier Fälle aus:

- zentrale Fläche 0°
- zentrale Fläche -3°
- zentrale Fläche +3°
- Edge-/Lippenkontakt bei 78°

Sie zeigt GREEN nur, wenn sämtliche harten Gates bestanden sind. Der aktuelle
Messlauf ist in `RESULT.md` dokumentiert.

## Physikalischer Umfang

- Münzradius: `0,011 m`
- Münzdicke: `0,0022 m`
- Masse: `0,0045 kg`
- 48-segmentiges konvexes Zylindermesh
- exakte Zylinderträgheit als `PhysicsMassProperties`
- dynamischer `PhysicsBodyComponent`, Gravitation und CCD
- nicht null gesetzte 3D-Startrotation über `PhysicsMotionComponent`
- statischer Boden, Seiten- und Rückwände sowie geneigte Frontlippe
- `ARView(frame:cameraMode:.nonAR, automaticallyConfigureSession:false)`
- keine AR-Session, kein Camera Feed und keine Fake-Flugkurve

Unter iOS 18+ setzt der Spike `linearDamping` und `angularDamping` explizit auf
null. Unter iOS 17 sind diese Properties sowie die Kontaktpenetration nicht
öffentlich verfügbar. Der Code kompiliert dort, ein vollständiger Mess-GREEN-
Nachweis ist unter iOS 17 deshalb absichtlich unmöglich.
