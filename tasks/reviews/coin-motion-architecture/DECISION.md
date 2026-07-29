# Coin Motion - Architekturentscheidung nach V3

## Entscheidung

Als nächster Schritt wird **ein isolierter RealityKit-Spike mit genau einer
dynamischen Münze und genau einer statischen Mulde** empfohlen. Er ist eine
begrenzt laufende Präsentationsschicht, kein Regel- oder Economy-System.

Der Spike verwendet wegen des bestehenden iOS-17-Deployment-Targets nicht
`RealityView`, sondern ein in SwiftUI eingebettetes `ARView` im Modus `.nonAR`
mit deaktivierter automatischer AR-Session. Erst wenn dieser Spike die
Kontakt-, Framerate- und Energie-Gates besteht, ist eine Produktintegration mit
maximal zwei gleichzeitig fliegenden Münzen vertretbar.

SpriteKit wird für physisches Münzkippen verworfen. Ein eigener
Persistent-Manifold-Solver bleibt eine spätere Ausweichoption, ist nach V3 aber
nicht der kleinste risikoarme nächste Schritt.

## Belegte Ausgangslage

- Der aktuelle Produktpfad ist SwiftUI, nicht SpriteKit. `ImpactFlight` bewegt
  eine View über einen `GeometryEffect` und meldet den Einschlag nach Abschluss
  einer SwiftUI-Animation
  ([ImpactFlight.swift:103](/Users/tobsi/poch1441/App/ImpactFlight.swift:103),
  [ImpactFlight.swift:142](/Users/tobsi/poch1441/App/ImpactFlight.swift:142)).
  Im App-Verzeichnis gibt es keinen `import SpriteKit`, keine `SKScene` und
  keinen `SKPhysicsBody`.
- Der vorhandene Integrationsvertrag ist bereits gut: Die regelneutrale
  `CoinTransferTransaction` besitzt die Zustände `prepared` bis `completed` und
  führt die fachliche Mutation ausschließlich beim ersten akzeptierten
  `registerImpact` aus
  ([CoinTransferPlan.swift:118](/Users/tobsi/poch1441/App/CoinTransferPlan.swift:118),
  [CoinTransferPlan.swift:152](/Users/tobsi/poch1441/App/CoinTransferPlan.swift:152)).
  Der konkrete Phase-2-Pfad folgt dieser Naht bereits
  ([Phase2View.swift:1604](/Users/tobsi/poch1441/App/Phase2View.swift:1604),
  [Phase2View.swift:1621](/Users/tobsi/poch1441/App/Phase2View.swift:1621)).
- Reduce Motion ist kein verkürzter unsichtbarer Flug, sondern ein synchroner
  Durchlauf derselben fachlichen Transaktion
  ([CoinTransferPlan.swift:196](/Users/tobsi/poch1441/App/CoinTransferPlan.swift:196)).
  Diese Eigenschaft ist bereits durch einen Vertragstest abgesichert
  ([CoinTransferPlanTests.swift:119](/Users/tobsi/poch1441/Tests/CoinTransferPlanTests.swift:119)).
- Board- und Muldengeometrie sind regelneutral und normalisiert vorhanden. Das
  Profil liefert Boden, Innenrand, Frontlippe, Ruheplätze und Overflow-Kontakt
  ([TravelTrayProfile.swift:42](/Users/tobsi/poch1441/App/TravelTrayProfile.swift:42));
  `BoardSpaceProjection` bildet diesen Board-Raum deterministisch in Screen-Space
  ab ([BoardSpaceProjection.swift:23](/Users/tobsi/poch1441/App/BoardSpaceProjection.swift:23)).
- Das Projekt zielt in Debug und Release auf iOS 17.0
  ([project.pbxproj:441](/Users/tobsi/poch1441/Poch1441.xcodeproj/project.pbxproj:441),
  [project.pbxproj:498](/Users/tobsi/poch1441/Poch1441.xcodeproj/project.pbxproj:498)).
- V3 hat freie 3D-Rotation bestanden, ist aber bei einer nur um `±3°` geneigten
  zentralen Fläche mit bis zu `10,169 mm` roher Penetration und künstlichem
  Energiegewinn gescheitert
  ([RESULT.md:20](/Users/tobsi/poch1441/tasks/reviews/motion-coins-v3/RESULT.md:20),
  [RESULT.md:33](/Users/tobsi/poch1441/tasks/reviews/motion-coins-v3/RESULT.md:33)).
  Die Ursache ist der fehlende persistente Kontaktmanifold, nicht ein schlecht
  gewählter Grenzwert
  ([RESULT.md:44](/Users/tobsi/poch1441/tasks/reviews/motion-coins-v3/RESULT.md:44)).

## Verifizierte SDK-Basis

Geprüft wurde das lokal installierte `iPhoneOS26.2.sdk`.

- `ARView` ist seit iOS 13 eine `UIView`. Der Initializer nimmt `cameraMode` und
  `automaticallyConfigureSession` entgegen; `.nonAR` ist ein öffentlicher
  Kameramodus
  ([RealityKit.swiftinterface:674](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityKit.framework/Modules/RealityKit.swiftmodule/arm64e-apple-ios.swiftinterface:674),
  [RealityKit.swiftinterface:716](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityKit.framework/Modules/RealityKit.swiftmodule/arm64e-apple-ios.swiftinterface:716),
  [RealityKit.swiftinterface:1107](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityKit.framework/Modules/RealityKit.swiftmodule/arm64e-apple-ios.swiftinterface:1107)).
- `RealityView` mit virtueller Kamera ist erst ab iOS 18 verfügbar. Es ist daher
  ohne Deployment-Änderung oder zusätzlichen Fallback nicht der kleinste
  Produktpfad
  ([_RealityKit_SwiftUI.swiftinterface:588](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/_RealityKit_SwiftUI.framework/Modules/_RealityKit_SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:588),
  [_RealityKit_SwiftUI.swiftinterface:619](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/_RealityKit_SwiftUI.framework/Modules/_RealityKit_SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:619)).
- RealityKit bietet dynamische, kinematische und statische Körper, explizite
  Masse beziehungsweise Trägheit, Material, Continuous Collision Detection und
  seit iOS 18 auch konfigurierbare lineare und angulare Dämpfung
  ([RealityFoundation.swiftinterface:2275](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:2275),
  [RealityFoundation.swiftinterface:2299](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:2299),
  [RealityFoundation.swiftinterface:14592](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:14592),
  [RealityFoundation.swiftinterface:14606](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:14606)).
- Startgeschwindigkeit und Rotation sind über `PhysicsMotionComponent`
  zugänglich
  ([RealityFoundation.swiftinterface:9958](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:9958)).
- Kollisionsereignisse liefern Entitäten, Position und Impuls. Ab iOS 18 sind
  zusätzlich Kontaktpunkte, Normalen, Einzelimpulse und Penetrationsdistanz
  verfügbar
  ([RealityFoundation.swiftinterface:7703](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:7703),
  [RealityFoundation.swiftinterface:7714](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:7714),
  [RealityFoundation.swiftinterface:7733](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:7733)).
- `SceneEvents.Update` stellt nur die tatsächlich vergangene `deltaTime` bereit.
  Im geprüften öffentlichen Interface ist kein vom Client gesetzter fester
  Physikschritt ausgewiesen
  ([RealityFoundation.swiftinterface:7637](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:7637)).

## Optionen im Vergleich

| Option | Physikalischer Fit | Integration | Determinismus | 60-FPS-/Energierisiko | Entscheidung |
| --- | --- | --- | --- | --- | --- |
| RealityKit in begrenztem `ARView` | Echte 3D-Körper, Masse, Trägheit, Reibung, Restitution, CCD und Kontaktimpulse sind vorhanden. Der Apple-Solver übernimmt den in V3 fehlenden persistenten Kontakt. | Passt unter die vorhandene `CoinTransferTransaction`; Regeln bleiben außerhalb. iOS 17 bleibt möglich. | Solver nicht als bitgenau oder fixed-step öffentlich vertraglich zugesichert. Determinismus muss oberhalb der Physik hergestellt werden. | Zusätzlicher 3D-Renderer und Physikwelt sind das größte Risiko, aber bei 1 bis 2 aktiven Körpern klar mess- und begrenzbar. | **Empfohlener Spike.** |
| SpriteKit | Reife 2D-Physik, genaue 2D-Kollision und Kontaktimpuls. | Wäre ebenfalls eine neue Renderfläche; im aktuellen App-Code existiert kein SpriteKit-Pfad. | Ein manueller Render-Update-Zeitpunkt existiert, die interne Physik ist dennoch nicht als Replay-Format spezifiziert. | Voraussichtlich günstiger als RealityKit, aber der Nutzen verfehlt das Ziel. | **Verwerfen für 3D-Münzen.** |
| Eigener Persistent-Manifold-Solver | Maximale Kontrolle über Geometrie, Energieledger, Schrittweite und Replay. | Headless und PochKit-nah testbar, aber Kollisions-, Solver- und Renderintegration wären Eigenentwicklung. | Als einzige Option grundsätzlich seed- und fixed-step-deterministisch machbar. | CPU-Risiko bei Manifold-Aufbau, Warm Starting, CCD, Stapeln und mehreren Münzen; Korrektheitsrisiko deutlich höher als Renderkosten. | **Nicht als nächster Schritt.** Erst wieder prüfen, wenn seed-only Replay zwingend ist oder RealityKit die Gates verfehlt. |

### Warum SpriteKit hier nicht genügt

Das lokale SDK beschreibt eine globale **2D**-Gravitation und Abfragen über
`CGPoint`, `CGRect` und Rays
([SKPhysicsWorld.h:23](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/SpriteKit.framework/Headers/SKPhysicsWorld.h:23)).
Körper sind Kreis, Rechteck, Polygon, Kantenkette oder Texture-Silhouette
([SKPhysicsBody.h:30](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/SpriteKit.framework/Headers/SKPhysicsBody.h:30),
[SKPhysicsBody.h:50](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/SpriteKit.framework/Headers/SKPhysicsBody.h:50)).
Geschwindigkeit ist `CGVector`, Rotation nur ein skalarer Winkel
([SKPhysicsBody.h:202](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/SpriteKit.framework/Headers/SKPhysicsBody.h:202)).
Eine optisch kippende 3D-Münze hätte damit weiterhin eine unabhängige 2D-
Kollisionsscheibe. Genau Face-/Edge-/Lippenkontakte, an denen V3 scheiterte,
würden nur kaschiert.

Zusätzlich besitzt SpriteKit standardmäßig Ruhelogik sowie lineare und angulare
Dämpfung
([SKPhysicsBody.h:108](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/SpriteKit.framework/Headers/SKPhysicsBody.h:108),
[SKPhysicsBody.h:132](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/SpriteKit.framework/Headers/SKPhysicsBody.h:132)).
Das ist für ein stilisiertes 2D-Spiel nützlich, aber kein Beleg für die in V3
geforderte 3D-Energie- und Kontaktqualität.

## Kleinster ausführbarer Spike

### Umfang

Ein Debug-only Probe-Screen beziehungsweise separates Spike-Target zeigt:

1. eine vorgebaute 3D-Münze,
2. einen Boden mit einer Frontlippe,
3. eine feste perspektivische Tischansicht,
4. genau einen Launch gleichzeitig,
5. die V3-Matrix aus zentralem Face-Kontakt, `±3°`-Perturbation und
   Edge-/Lippenkontakt.

Nicht enthalten sind PochKit-Regeln, mehrere Münzen, Stapel, Shop-/Menü-UI,
finale Beleuchtung, Partikel, Audio oder ein Austausch aller bestehenden
`ImpactFlight`-Stellen.

### Asset- und Kollisionsbedarf

- **Münze:** ein Build-Time-USDC/USDZ-Modell mit echter Zylindergeometrie,
  getrennt brauchbarer Vorderseite, Rückseite und Kante. Das iOS-17-kompatible
  SDK kann ein Model laden und dessen Mesh über `ModelComponent.mesh` zugänglich
  machen
  ([RealityFoundation.swiftinterface:12975](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:12975),
  [RealityFoundation.swiftinterface:8257](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:8257)).
  Daraus wird einmalig eine konvexe `ShapeResource` erzeugt
  ([RealityFoundation.swiftinterface:13264](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:13264)).
  `MeshResource.generateCylinder` ist im lokalen SDK erst ab iOS 18 verfügbar
  ([RealityFoundation.swiftinterface:15059](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:15059));
  es ist deshalb keine iOS-17-Produktbasis.
- **Mulde:** ein statischer Boden plus vier Randsegmente. Für den Spike genügen
  Boxen und eine konvexe Lippenform; beide Shape-Wege sind seit iOS 13 vorhanden
  ([RealityFoundation.swiftinterface:13269](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:13269)).
  Abmessungen stammen aus `WellProfile`, werden aber einmal in Meter skaliert.
  Eine neue parallele Layoutquelle ist nicht erlaubt.
- **Körper:** Münze dynamisch, Mulde statisch, reale Münzmasse und aus der
  Kollisionsform abgeleitete Trägheit. Reibung und Restitution werden explizit
  gesetzt; Dämpfung bleibt null, sofern die OS-Verfügbarkeit das Property bietet.
  CCD ist für die fliegende Münze aktiv. Die einschlägigen Initializer nehmen
  Shapes und Masse direkt entgegen
  ([RealityFoundation.swiftinterface:2284](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:2284)).

### Kamera und begrenzte Renderfläche

- `ARView(frame:cameraMode:.nonAR, automaticallyConfigureSession:false)` wird
  nur innerhalb der bestehenden Board-/Flugfläche eingebettet. Kamera-Feed,
  World Tracking und Berechtigungen sind nicht beteiligt.
- Ein `AnchorEntity` nimmt ausschließlich Münze, Muldenkollision und Licht auf;
  die Scene kann einen Anchor öffentlich hinzufügen
  ([RealityFoundation.swiftinterface:5918](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:5918),
  [RealityFoundation.swiftinterface:9355](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:9355)).
- Weil `ARView.cameraTransform` nur lesbar ausgewiesen ist
  ([RealityKit.swiftinterface:701](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityKit.framework/Modules/RealityKit.swiftmodule/arm64e-apple-ios.swiftinterface:701)),
  wird für den Spike der gesamte Root-Anchor relativ zur festen non-AR-Kamera
  kalibriert. Öffentliche Position, Orientierung und Transformmatrix sind am
  Entity verfügbar
  ([RealityFoundation.swiftinterface:6227](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface:6227)).
- Die Kalibrierung muss die vier bekannten Board-Ecken gegen die bestehende
  `BoardScreenQuadrilateral` prüfen. Ein maximaler Screenfehler wird zum Gate;
  ein optisch ähnlicher, aber geometrisch abweichender zweiter Tisch ist nicht
  akzeptabel.

### Exakte Integrationsnaht

Der Renderer erhält ausschließlich eine unveränderliche Präsentationsanweisung:
Event-ID, Generation, Seed, Quell- und Zielpunkt im normalisierten Board-Raum,
Startorientierung, Startgeschwindigkeit und Motion-Präferenz. Diese Werte sind
keine Spielregeln.

Der Renderer gibt genau drei fachfreie Ereignisse zurück:

1. **erster Materialkontakt** mit Kontaktposition und Impuls,
2. **zur Ruhe gekommen** mit finaler Transform,
3. **abgebrochen**.

Die bestehende `CoinTransferTransaction` bleibt Besitzerin des Zustands:

```text
prepared -> depart -> airborne
                       |
RealityKit CollisionEvents.Began
                       v
                 registerImpact (genau einmal)
                       |
        Geschwindigkeitsfenster über mehrere Updates
                       v
              beginSettling -> complete
```

Nur ein akzeptiertes `registerImpact` darf die bestehende `onImpact`-Closure
ausführen. Weitere Kontaktupdates, Bounces oder stale Generationen sind inert.
Beim Entfernen der View wird wie heute `cancel` aufgerufen. PochKit und
`GameState` kennen weder RealityKit-Entitäten noch Physikmaterialien.

### Reduce Motion und Haptik

- Bei Reduce Motion wird `ARView` für den Transfer nicht gestartet. Der
  bestehende synchrone Pfad `performReducedMotionTransfer` bleibt maßgeblich;
  Quelle, Ziel, Crossfade, logischer Materialkontakt und Settle bleiben erhalten.
- Haptik wird nicht auf jedes rohe RealityKit-Kollisionsereignis gelegt. Genau
  der erste von `registerImpact` akzeptierte Materialkontakt erhöht den bereits
  vorhandenen SwiftUI-Trigger. Die App prüft weiterhin die Nutzerpräferenz, wie
  beim bestehenden `.sensoryFeedback`-Pfad
  ([Phase2View.swift:176](/Users/tobsi/poch1441/App/Phase2View.swift:176)).
- Der RealityKit-Impuls darf später eine kleine, begrenzte Auswahl an
  Haptikstärken informieren. Er darf weder Economy noch Transaktionsreihenfolge
  ändern.

## Deterministischer Replay-Vertrag

RealityKit-Physik wird ausdrücklich **nicht** zur autoritativen Simulation und
nicht als seed-only deterministisch angenommen. Das geprüfte SDK stellt
`deltaTime`, aber keinen öffentlichen fixed-step-Treiber bereit.

Der Produktvertrag trennt daher zwei Modi:

1. **Live:** Seed und Anweisung bestimmen die initiale Transform sowie lineare
   und angulare Geschwindigkeit. RealityKit erzeugt nur die Präsentation.
   `CoinTransferTransaction` garantiert weiterhin genau einen fachlichen Impact.
2. **Replay/Test:** Der erste Live-Lauf zeichnet relative Zeit, Transform,
   akzeptierten Kontakt und finale Ruhetransform in einem kleinen
   Motion-Transcript auf. Replay setzt die Münze kinematisch und interpoliert
   ausschließlich dieses Transcript; die Physik wird nicht erneut ausgewertet.
   Golden-Transcripts machen UI-Tests wiederholbar.

Wenn ein Replay allein aus Seed und Inputs auf jedem Gerät bitgleich neu
simuliert werden muss, ist der RealityKit-Weg nicht ausreichend. Dann ist ein
eigener fixed-step Persistent-Manifold-Solver zwingend - einschließlich der in
V3 noch fehlenden Manifold-, Warm-Starting-, CCD- und Energiearbeit.

## Spike-Gates

Der Spike darf nur dann in eine Produktplanung übergehen, wenn alle folgenden
Punkte auf dem ältesten unterstützten realen iPhone und zusätzlich auf einem
aktuellen Gerät belegt sind:

1. **Kontaktqualität:** zentrale Fläche, `±3°` sowie Edge/Lippe bleiben in der
   Mulde, tunneln nicht und erzeugen genau einen akzeptierten fachlichen Impact.
   Auf iOS 18+ werden die verfügbaren Kontakt- und Penetrationsdaten protokolliert;
   diese sind nicht automatisch mit der V3-Rohpenetration gleichzusetzen.
2. **Rest:** Keine eigene Velocity-Zeroing- oder Sleep-Entscheidung beweist Ruhe.
   Abschluss erfolgt erst nach einem benannten linearen und angularen
   Geschwindigkeitsfenster über eine zusammenhängende Prüfdauer. Die gemessenen
   Werte kommen aus `PhysicsMotionComponent`.
3. **Framerate:** Ein wiederholter 60-Sekunden-Launch-Loop hält im kompakten
   Board-Viewport 60 FPS ohne wiederkehrende Frame-Spikes. Gemessen werden
   Baseline, eine Münze und zwei Münzen getrennt; SwiftUI-State wird nicht pro
   Frame aktualisiert.
4. **Energie:** Derselbe Loop zeigt gegenüber der heutigen SwiftUI-Baseline
   keinen dauerhaften thermischen Abfall. Assets und Collision Shapes werden
   einmal geladen beziehungsweise erzeugt; es gibt keine Laufzeit-Mesh-Pipeline.
5. **Lebenszyklus:** Abbruch, stale Generation, doppelter Kontakt und schneller
   Reduce-Motion-Wechsel bleiben inert und führen `onImpact` höchstens einmal aus.
6. **Kamera:** Board-Ecken, Zielmulde und Kontaktpunkt bleiben bei kleiner und
   repräsentativer großer Zielbreite innerhalb des festgelegten Projektionsfehlers.
7. **Replay:** Ein aufgezeichnetes Transcript liefert bei 30, 60 und 120 Hz
   denselben akzeptierten Impact, dieselbe finale Transform und dieselbe
   Transaktionsreihenfolge.

Ein Fail in Kontaktqualität, 60 FPS, Energie oder Lebenszyklus beendet den
RealityKit-Pfad. Dann folgt kein visuelles Tuning, sondern erst eine neue
Architekturentscheidung zwischen vereinfachter 2.5D-Präsentation und einem
vollständigen Persistent-Manifold-Solver.

## Produktionsrisiken und Begrenzungen

- **Deployment:** `RealityView`, pro-Kontakt-Penetration und einige neue
  Dämpfungsproperties beginnen erst bei iOS 18. Der iOS-17-Produktpfad muss auf
  `ARView` und die dort verfügbare Ereignismenge beschränkt bleiben oder das
  Deployment-Target wird separat entschieden. Insbesondere kann der Spike unter
  iOS 17 die Dämpfung nicht über die erst ab iOS 18 öffentlich ausgewiesenen
  Properties auf null setzen. Wenn die gemessene freie Flugenergie deshalb den
  Vertrag verfehlt, ist das ein echter iOS-17-Blocker und kein Anlass, das Gate
  zu lockern.
- **Physik als Black Box:** Solveriterationszahl, Step-Policy und bitgenaue
  Stabilität sind kein öffentlich belegter Vertrag. Deshalb bleiben Regeln und
  Replay außerhalb.
- **Kamera-Parität:** Eine zweite perspektivische Projektion kann sichtbar gegen
  SwiftUI driften. Der Spike muss diese Naht messen, nicht nach Augenmaß tunen.
- **Asset-Kosten:** Ein realistisches Relief darf nicht die Collision Shape
  aufblasen. Sichtmesh und einfache konvexe Physikform bleiben getrennt.
- **Idle-Energie:** Eine permanente zusätzliche 3D-Fläche wäre unnötig teuer.
  Der Spike misst explizit aktive und inaktive Zeit und darf keine unbemerkte
  Dauerlast einführen.
- **Mehrere Münzen:** Die vorhandene Produktpolicy begrenzt gleichzeitige Flüge
  bereits auf zwei
  ([CoinTransferPlan.swift:40](/Users/tobsi/poch1441/App/CoinTransferPlan.swift:40)).
  Der Spike bleibt zunächst bei einer Münze; zwei sind ein separates
  Freigabe-Gate, nicht stiller Scope.

## Abschlusskriterium der Architekturprobe

Die Empfehlung bedeutet nicht, dass RealityKit bereits gewählt ist. Gewählt ist
nur der **kleinste falsifizierbare Spike**. RealityKit wird Produktionspfad,
wenn es die unveränderte Face-/Lippenmatrix, die Lebenszyklusnaht, Kamera-Parität,
Replay-Entkopplung und reale Gerätebudgets erfüllt. Andernfalls ist die Antwort
RED und der nächste Schritt keine Testlockerung.
