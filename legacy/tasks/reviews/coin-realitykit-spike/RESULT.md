# Coin RealityKit Spike - RED

## Urteil

**RED. RealityKit ist mit dieser iOS-17-kompatiblen Anordnung nicht für die
Produktintegration freigegeben.**

Der Spike kompiliert als iOS-17-App und lief sichtbar auf einem iOS-26.2-
Simulator. Ruhe, Energie, echte 3D-Rotation, Containment und Lippenkontakt waren
grün. Alle vier Fälle verletzten jedoch unverändert das harte
Kontaktpenetrations-Gate.

Maschinenlesbarer Bericht: `runtime-result.json`  
Visueller Beleg: `runtime-final.png`

## Gemessene Ergebnisse

| Fall | RealityKit-Kontaktpenetration | Ruhefenster | 3D-Rotationsänderung | Energiegewinn | Lippe | Enthalten |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| central-face-0deg | `1,148 mm` | `0,517 s` | `121,99°` | `0,000 %` | n/a | ja |
| central-face-minus3deg | `1,616 mm` | `0,500 s` | `123,70°` | `0,000 %` | n/a | ja |
| central-face-plus3deg | `1,244 mm` | `0,517 s` | `178,97°` | `0,000 %` | n/a | ja |
| edge-lip-78deg | `0,980 mm` | nicht gefordert | `120,26°` | `0,000 %` | **echter Kontakt** | ja |

Frame-Pacing des Simulatorlaufs: `p95 = 16,704 ms`. Das ist ein diagnostischer
Wert, kein Ersatz für einen Energie-/60-FPS-Test auf dem ältesten realen Gerät.

## Harte Gates

1. **Kontaktpenetration:** RealityKits öffentlich gemeldete
   `CollisionEvents.*.penetrationDistance` muss `<= 0,150 mm` bleiben. Ergebnis:
   **FAIL in 4/4 Fällen**.
2. **Ruhe:** Die drei Face-Fälle müssen ohne eigenes Velocity-Zeroing mindestens
   `0,500 s` zusammenhängend unter `0,015 m/s` linear und `0,8 rad/s` angular
   bleiben. Ergebnis: **PASS in 3/3 Fällen**.
3. **Lippe:** Der 78°-Fall muss mit der statischen Entity `front-lip` kollidieren
   und in der Mulde bleiben. Ergebnis: **PASS**.
4. **Energie:** Der beobachtete mechanische Energiegewinn darf `1 %` der
   Initialenergie nicht überschreiten. Ergebnis: **PASS, 0 % in 4/4 Fällen**.
5. **Echte Rotation:** Die Solverorientierung muss sich um mindestens `5°`
   ändern. Ergebnis: **PASS, 120° bis 179°**.

Der Penetrationswert ist der von RealityKit gemeldete Kontaktüberlappungswert.
Er ist nicht mit der rohen V3-Penetration vor einer Solverkorrektur gleichgesetzt.
Der Spike bezeichnet ihn daher nicht als Rohpenetration. Für den hier gesetzten
Produktvertrag überschreitet aber bereits der öffentliche RealityKit-Wert die
Grenze um den Faktor `6,5` bis `10,8`.

## Reproduzierter Build und Lauf

Verwendeter Simulator:

```text
iPhone 17 Pro
UDID D1923D48-6E8D-4157-B703-8B05CC334D08
iOS 26.2
```

Kommandos:

```sh
cd tasks/reviews/coin-realitykit-spike
xcodegen generate --spec project.yml

xcodebuild \
  -project CoinRealityKitSpike.xcodeproj \
  -scheme CoinRealityKitSpike \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D1923D48-6E8D-4157-B703-8B05CC334D08' \
  -derivedDataPath .derived \
  build

xcrun simctl boot D1923D48-6E8D-4157-B703-8B05CC334D08
xcrun simctl bootstatus D1923D48-6E8D-4157-B703-8B05CC334D08 -b
xcrun simctl install D1923D48-6E8D-4157-B703-8B05CC334D08 \
  .derived/Build/Products/Debug-iphonesimulator/CoinRealityKitSpike.app
xcrun simctl launch D1923D48-6E8D-4157-B703-8B05CC334D08 \
  com.tobc.reviews.coin-realitykit-spike
```

Release-Build-Ergebnis für `arm64` und `x86_64`:
`** BUILD SUCCEEDED **`. Die einzige Meldung stammt aus dem App-Intents-Training:
`No AppShortcuts found - Skipping.`, weil der Spike AppIntents nicht verwendet.
Der dokumentierte Messlauf wurde mit dem Debug-Build ausgeführt; die
physikalischen Gates und ihr RED-Urteil stammen aus `runtime-result.json`.

## Architekturbeobachtungen

- Der Apple-Solver löst genau die in V3 fehlenden stabilen Face- und
  Lippenkontakte praktisch: Alle Face-Fälle erreichten Ruhe und keiner entkam.
- Der gemeldete Kontaktüberlappungswert ist für den unveränderten 0,15-mm-
  Vertrag zu groß. Er wurde weder versteckt noch nachträglich korrigiert.
- Der iOS-17-Fallback kann weder Dämpfung explizit auf null setzen noch die
  öffentliche Kontaktpenetration lesen. Ein iOS-17-GREEN wäre deshalb ohne
  Deployment- oder Gate-Änderung nicht belegbar.
- Die feste non-AR-Kamera rendert die reale Szene, bietet unter dem
  iOS-17-kompatiblen `ARView`-Pfad aber nur eine sehr flache Tischansicht. Das ist
  für einen Messspike ausreichend, nicht für die spätere Produktästhetik.

## Konsequenz

Nicht an Reibung, Restitution, Fällen oder Grenzwerten weiterdrehen, um GREEN zu
erzwingen. Vor einer Produktintegration braucht es eine bewusste Entscheidung:

- iOS-18+-Baseline mit `RealityView` und neuem Kamera-/Physikvertrag prüfen,
- den erlaubten Kontaktüberlappungsvertrag fachlich neu begründen, oder
- RealityKit für diese Münzphysik verwerfen.

Bis dahin bleibt der Spike RED und vollständig außerhalb der App.
