# Card Motion Material Lock V5

Isolierter Capture-/Encode-Fix auf Basis von V4. Material, Model, Controller,
Stage, W2-Vertrag und alle Bewegungsparameter bleiben byte-identisch zu V4.
Die App unter `App/**` bleibt unangetastet.

V5 entfernt ausschließlich die zusätzliche vertikale Core-Graphics-Spiegelung
beim Schreiben der AVAssetWriter-Pixelbuffer. Ein nativer AVFoundation-Prüfer
dekodiert das MP4 anschließend und vergleicht dessen ersten Frame pixelbasiert
mit dem aufrechten gerenderten PNG. Identität muss gegenüber 180-Grad-Drehung
und horizontaler sowie vertikaler Spiegelung eindeutig gewinnen.

Gezielter Build, Tests und statischer Export:

```sh
./Scripts/run.sh static
```

Vollständiger Wallclock-Export mit demselben Build und technischem
Orientierungs-Gate:

```sh
MATERIAL_LOCK_SKIP_BUILD=1 ./Scripts/run.sh full
```

Ein technischer PASS ersetzt nicht die menschliche Prüfung des ungeschnittenen
MP4 in QuickTime. Bis dahin bleibt der Produkt-Gate `HUMAN_PENDING`.
