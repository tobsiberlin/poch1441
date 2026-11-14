# RealityKit Kontaktkalibrierung V2

Isolierte iOS-App zur Herkunftsbestimmung von RealityKits gemeldeter
`penetrationDistance`. Der Spike enthält keine App-Integration, kein Slotting
und kein eigenes Velocity-Zeroing.

## Fragestellung

Der V1-Spike meldete Kontaktpenetrationen von `0,98-1,62 mm`. V2 trennt drei
mögliche Erklärungen experimentell:

1. Convex-Hull- oder Segmentierungseffekt
2. persistenter Collision-Margin
3. tatsächliche transiente Solverüberlappung beziehungsweise reine
   Event-Messsemantik

Das Limit bleibt unverändert bei `0,150 mm`.

## Matrix

Alle dynamischen Körper haben `22,0 x 2,2 x 22,0 mm` Nominalabmessungen,
`4,5 g` Masse, Gravitation, CCD, null Restitution und denselben Startabstand.

- 12-Segment-Convex-Hull, flach
- 48-Segment-Convex-Hull, flach
- 12-Segment-Convex-Hull, 3° geneigt
- 48-Segment-Convex-Hull, 3° geneigt
- maßgleich hoher `ShapeResource.generateBox`-Kontrollkörper, flach

Die Münzen nutzen dasselbe 64-Segment-Sichtmesh. Nur ihre Collision Shapes
unterscheiden sich. Der Boden ist ein kalibrierter statischer Boxkörper mit
bekannter Oberkante.

## Getrennte Messgrößen

- `maximumReportedContact`: Maximum aus
  `CollisionEvents.*.penetrationDistance`
- `minimumTransformGeometrySignedGapMeters`: kleinster analytischer Abstand
  der Körperstützfläche zur bekannten Bodenoberkante, direkt aus Position und
  Quaternion berechnet; ein negativer Wert ist reale geometrische Überlappung
- `settledReportedContact`: Eventwert während des natürlichen Ruhefensters
- `finalTransform`: unveränderte RealityKit-Endposition und Quaternion
- `finalGeometry`: analytischer Endabstand und Endüberlappung
- `runtime-final.png`: sichtbare Endlagen aller fünf echten Physikkörper

Der Screenshot ist ein visueller Beleg, aber kein Längenmessgerät. Die
maßgeblichen Transform- und Geometriedaten stehen vollständig im JSON-Bericht.

## Voraussetzungen und Build

- Xcode 26.2 mit iOS-26.2-Simulator
- XcodeGen

```sh
cd tasks/reviews/coin-realitykit-spike-v2
xcodegen generate --spec project.yml
xcodebuild \
  -project CoinRealityKitCalibration.xcodeproj \
  -scheme CoinRealityKitCalibration \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath .derived \
  build
```

Das Deployment-Target ist iOS 17.0. `penetrationDistance` sowie die expliziten
Dämpfungs-Properties sind erst ab iOS 18 öffentlich verfügbar und deshalb mit
Availability Checks gekapselt.

## Frischer Lauf und Bericht

```sh
xcrun simctl boot <UDID>
xcrun simctl bootstatus <UDID> -b
xcrun simctl uninstall <UDID> \
  com.tobc.reviews.coin-realitykit-calibration || true
xcrun simctl install <UDID> \
  .derived/Build/Products/Debug-iphonesimulator/CoinRealityKitCalibration.app
xcrun simctl launch <UDID> \
  com.tobc.reviews.coin-realitykit-calibration

CALIBRATION_DATA=$(xcrun simctl get_app_container \
  <UDID> com.tobc.reviews.coin-realitykit-calibration data)
cp "$CALIBRATION_DATA/Documents/coin-realitykit-calibration-result.json" \
  runtime-result.json
xcrun simctl io <UDID> screenshot runtime-final.png
```

Der aktuelle Befund und die reproduzierten Werte stehen in `RESULT.md`.

