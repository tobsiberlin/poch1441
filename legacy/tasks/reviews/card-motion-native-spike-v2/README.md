# Card Motion Native Spike V2

Isolierte iOS-17-SwiftUI/XcodeGen-App für die visuelle Korrektur des V1-Spikes.
Sie besitzt keinen Produkt-Callsite und ändert keine App-Datei.

## V2-Vertrag

- getrennte Segmente Deal, Reveal, Play und Return mit eigenem Fortschritt
- Deal startet deckungsgleich auf `deckTop` und endet exakt in `handSlot`
- Reveal bleibt im Hand-Slot und ändert nur Oberfläche plus geringe Abhebung
- Play startet exakt im Hand-Slot und endet exakt in `playTarget`
- Return tastet dieselbe Play-Trajektorie rückwärts ab und ist nur für
  `interruptionProgress < 1` erzeugbar
- Schatten und Kartenfläche sind Geschwisterebenen
- Schatten folgt linearer Tischbahn, übernimmt nie Kartenrotation oder Flip
- perspektivischer Kartenfußabdruck statt Ellipse; Breite, Länge, Blur und
  Opazität reagieren auf die normierte Flughöhe
- Haptik nur am akzeptierten Deal-/Play-Kontakt, nie bei Return oder Reduce Motion

## Reale Kartenreferenzen

- W2: exakte Poch-Juweltokens, W2-Geometrie, fester Patina-Generator,
  `1441`-Monogramm und kopierte Schadenslage `card_back_damage_04`
- V10: kopiertes öffentliches Produktionsasset `card_hearts_ace`

## Reproduktion

```sh
cd tasks/reviews/card-motion-native-spike-v2
./Scripts/run.sh
```

Optional:

```sh
SPIKE_SIMULATOR_UDID=<UDID> ./Scripts/run.sh
```

Der Lauf erzeugt und testet das Projekt, exportiert 60 feste Segmentframes,
einen aus 64 zeitgetakteten Frames zusammengesetzten Echtzeit-Contact-Sheet und
eine separate `CADisplayLink`-Frameprobe. Ergebnisse liegen in `Evidence/`.

Die technische und visuelle Entscheidung wird in `RESULT.md` getrennt. Eine
visuelle Selbstfreigabe ist ausdrücklich ausgeschlossen.

