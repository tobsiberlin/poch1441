# Architekturentscheidung: nächste 3D-Münzphysik für iOS 17

**Status:** vorgeschlagen, noch keine Produktionsfreigabe  
**Belegstand:** 19. Juli 2026  
**Scope:** Architekturentscheidung und kleinster falsifizierbarer Spike. Keine App-Änderung.

## Entscheidung

Als nächster technischer Schritt wird **Jolt Physics 5.6.0 in einem isolierten
iOS-17-Spike** geprüft. Jolt ist dabei ausschließlich die Physik; RealityKit
rendert eine kleine 3D-Insel und erhält pro Renderframe unveränderliche
Transform-Snapshots aus dem Solver. PochKit bleibt alleinige Quelle für
Spielregeln, Chips und fachliche Replays.

Das ist noch **keine Freigabe von Jolt für die App**. Jolt wird nur dann GREEN,
wenn der Spike sämtliche unten definierten Gates erfüllt. Besonders bleibt das
bisherige physische Gate unverändert:

> Die maximale transiente geometrische Überlappung darf in keinem Pflichtfall
> `0,150 mm` überschreiten. Velocity-Zeroing, Teleportieren, Slotting oder ein
> nachträgliches Korrigieren der Renderposition zählen nicht als Physiklösung.

RealityKit allein bleibt für diesen Vertrag RED. Es kann nur durch eine
**separate, bewusste Produktentscheidung** wieder Kandidat werden, die den
transienten Millimetervertrag durch den unten beschriebenen visuellen Vertrag
ersetzt. Das wäre eine Vertragsänderung, kein nachträgliches GREEN des
vorhandenen Spikes.

SceneKit wird trotz lokaler Kompilierbarkeit nicht neu eingeführt, weil Apple
das Framework offiziell als deprecated markiert und zur Migration auf
RealityKit auffordert. Ein eigener Persistent-Manifold-Solver bleibt Plan B,
falls Jolt am Pflichtgate scheitert oder sein Integrations- und Binary-Risiko
nicht akzeptabel ist.

## Lokaler Projekt- und SDK-Befund

- `project.yml` setzt iOS `17.0`, Swift `5.0` und Strict Concurrency auf
  `complete`. Die App hängt derzeit nur vom lokalen Paket PochKit ab; eine
  fremde C++- oder Binärabhängigkeit existiert nicht.
- Der aktuelle App-Code ist SwiftUI-basiert (`ContentView`,
  `TravelTableRenderer`, die Phasenansichten); UIKit wird bereits an der
  App-Grenze importiert. Apples `UIViewRepresentable` ist der offizielle Weg,
  eine UIKit-View in SwiftUI einzubetten. Damit sind `ARView` und `SCNView`
  technisch integrierbar, aber nicht automatisch architektonisch sinnvoll.
- `BoardSpaceProjection` bildet den normalisierten Board-Raum deterministisch
  auf Screen-Koordinaten ab. Eine 3D-Insel muss diese bestehende Projektion
  übernehmen und darf keine zweite, driftende Board-Geometrie etablieren.
- PochKit dokumentiert Runden als deterministisch aus Seed und Aktionsliste;
  sein Event-Strom ist Quelle für UI und Replays. `SeededRNG` implementiert
  SplitMix64 sowie einen stdlib-unabhängigen Fisher-Yates-Shuffle. Der Test
  `testSimulationIsDeterministicPerSeed` belegt gleichen Match-Verlauf für
  gleichen Seed. Die 3D-Physik darf diese fachliche Deterministik nicht
  beeinflussen.
- Geprüft wurde das lokal installierte Xcode `26.2 (17C52)` mit iOS-SDK `26.2`.
  Dessen RealityKit-Interface deklariert `ARView` ab iOS 13 und
  `PhysicsBodyComponent` samt CCD ebenfalls für iOS 13. Damping,
  `isAffectedByGravity`, `Contact.penetrationDistance` und konfigurierbare
  `PhysicsSimulationComponent.solverIterations` sind dort jedoch erst ab
  iOS 18 verfügbar. Sie können daher keinen iOS-17-Vertrag tragen.
- Die lokalen SceneKit-Header enthalten weiterhin `SCNPhysicsWorld.timeStep`,
  `SCNPhysicsContact.penetrationDistance`, dynamische Körper, Reibung,
  Dämpfung, Ruhemodus und CCD. Die geprüften Kernklassen sind im lokalen Header
  nicht mit `API_DEPRECATED` annotiert. Dies belegt Verfügbarkeit im lokalen
  SDK, widerspricht aber nicht Apples frameworkweiter Dokumentationsmarkierung
  als deprecated.

Lokale Belegpfade:

- `project.yml`
- `PochKit/Sources/PochKit/SeededRNG.swift`
- `PochKit/Sources/PochKit/Round.swift`
- `PochKit/Tests/PochKitTests/MatchTests.swift`
- `App/BoardSpaceProjection.swift`
- `iPhoneOS.sdk/System/Library/Frameworks/RealityKit.framework/Modules/RealityKit.swiftmodule/arm64e-apple-ios.swiftinterface`
- `iPhoneOS.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-ios.swiftinterface`
- `iPhoneOS.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNPhysicsWorld.h`
- `iPhoneOS.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNPhysicsContact.h`
- `iPhoneOS.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNPhysicsBody.h`

## Vergleich

| Option | iOS 17 / SwiftUI | Replay und Determinismus | 60 FPS / Energie | Lizenz / Binary | Kamera / Rendering | Urteil |
| --- | --- | --- | --- | --- | --- | --- |
| RealityKit-Physik | Systemframework; `ARView` ab iOS 13 über `UIViewRepresentable`. Wichtige Mess- und Solverregler des aktuellen SDK erst ab iOS 18. | Keine offizielle Zusage für bitidentische Physik. PochKit-Replay bleibt sicher; exakte visuelle Replays benötigen aufgezeichnete Transform-Keyframes. | Voriger Spike erreichte im Simulator `p95 = 16,716 ms`; das ist kein Energie- oder Gerätebeleg. Wenige Körper sind plausibel günstig, aber ungeprüft. | Keine Drittanbieter-Lizenz und kein eingebettetes Engine-Binary. | Renderer, Material, Licht und Kamera aus einem System; geringstes Integrationsrisiko. | **RED** für transient `0,150 mm`; nur mit ausdrücklich neuem visuellen Vertrag erneut prüfbar. |
| SceneKit | Im lokalen SDK vollständig nutzbar, `SCNView` wäre ebenfalls ein UIKit-Wrapper. Apple markiert SceneKit offiziell als deprecated. | `timeStep` ist steuerbar, aber Apple gibt keine deterministische Replay-Garantie; Engine und Kontaktordnung bleiben undurchsichtig. | Reife integrierte Engine, aber ohne projektspezifischen Geräte- und Energiebeleg. Ein guter Messwert rechtfertigt keine neue Abhängigkeit von einem deprecated Framework. | Systemframework, daher kein Drittanbieter-Binary. Zukunfts- und Migrationsrisiko ist dennoch hoch. | Vollständiger Renderer und Kamera; zweiter Szenengraph neben SwiftUI. | **RED** für Neuintegration, unabhängig vom Physikergebnis. Allenfalls Wegwerf-Kontrollmessung. |
| Jolt Physics 5.6.0 + RealityKit-Renderer | Upstream nennt iOS x64/ARM64 und dokumentiert einen Xcode/CMake-iOS-Build. Ein schmaler eigener Objective-C++-C-ABI-Adapter ist nötig; es gibt keinen offiziellen Swift-Binding-Pfad. | Deterministisch bei identischer Aufrufreihenfolge und gleichem Binary. Cross-Platform-Modus kostet laut Upstream ungefähr 8 %, hat aber Caveats; iOS steht nicht in der veröffentlichten Determinismus-Testmatrix. `SaveState`/`RestoreState` unterstützt Rollback, ersetzt keine Versionsstrategie. | Echte Mehrkern-Engine; für die wenigen Münzen muss der Spike eine begrenzte Job-Konfiguration gegen Main-Thread- und Energie-Overhead messen. | MIT mit Notice-Pflicht. Statisches Binary/Quellbuild vergrößert App und Build-Matrix; Defines, RTTI und LTO müssen zwischen Wrapper und Library übereinstimmen. | Jolt rendert nicht. RealityKit läuft ohne eigenen PhysicsBody und übernimmt ausschließlich Jolt-Transforms; Kamera und Board-Projektion bleiben App-Verantwortung. | **Bevorzugter Spike**, bis zu allen Gates **AMBER**. |
| Eigener Persistent-Manifold-Solver | Swift-native, kleinste Sprach- und Bridge-Distanz. | Fester Takt, feste Kontaktreihenfolge und eigene Zustandsserialisierung wären vollständig kontrollierbar. Diese Eigenschaften entstehen aber erst durch Implementierung und Tests. | Für Münze plus statische Ablage potentiell klein; Narrow Phase, CCD, Warm Start, Reibung, Sleep und Stabilisierung sind dennoch zeitkritisch. | Keine Fremdlizenz und kein Fremdbinary; dafür volles Wartungs-, Sicherheits- und Korrektheitsrisiko im Projekt. | Wie Jolt ohne Renderer; RealityKit oder Metal müsste Transform-Snapshots darstellen. | **Plan B nach Jolt-RED**, nicht erste Wahl. |

## Option 1: RealityKit nur mit neuem visuellem Vertrag

Der vorhandene V2-Spike ist belastbar RED. Eventmaximum und unabhängig aus
Transform plus Nominalgeometrie berechnete Überlappung stimmen in allen fünf
Fällen eng überein. Gemessen wurden unter anderem:

| Pflichtfall | Eventmaximum | Geometrisches Maximum | Ergebnis bei `0,150 mm` |
| --- | ---: | ---: | --- |
| 12-Segment-Münze, flach | `0,148981 mm` | `0,152715 mm` | FAIL |
| 48-Segment-Münze, flach | `0,026268 mm` | `0,026174 mm` | PASS |
| 12-Segment-Münze, 3° | `0,359436 mm` | `0,365630 mm` | FAIL |
| 48-Segment-Münze, 3° | `0,364431 mm` | `0,365272 mm` | FAIL |
| Box-Kontrolle, flach | `0,483032 mm` | `0,483029 mm` | FAIL |

Die End-Gaps lagen dagegen zwischen `-0,003755 mm` und `+0,000089 mm`. Damit
ist die Abweichung keine dauerhafte Convex-Hull-Marge, sondern reale transiente
Solverüberlappung. Segmentzahl oder eine andere Auswertung lösen sie nicht.

Ein möglicher **neuer visueller Vertrag** müsste vor einem weiteren
RealityKit-Spike schriftlich als Produktentscheidung angenommen werden:

1. Das physische `0,150-mm`-Transientengate entfällt ausdrücklich für diese
   Option; sein bisheriges Ergebnis bleibt RED.
2. In jedem tatsächlich gerenderten Frame darf an Münze, Boden und Lippe keine
   sichtbare Durchdringung von mehr als `0,5` physischem Pixel auftreten.
3. Nach Eintritt des bestehenden Ruhefensters bleibt die analytische
   Überlappung bei maximal `0,150 mm`.
4. Kein Tunneling, kein Verlassen der Ablage, kein Energiegewinn, kein
   Velocity-Zeroing und keine Transformkorrektur nach der Simulation.
5. Alle Pflichtfälle werden auf dem ältesten unterstützten realen iOS-17-Gerät
   sowie in Portrait und Landscape geprüft. Auf iOS 17 erfolgt die Messung aus
   Transform und Nominalgeometrie, weil `penetrationDistance` dort öffentlich
   nicht verfügbar ist.

**Kleinster falsifizierbarer RealityKit-Spike:** denselben V2-Aufbau unverändert
rendern, jede Display-Frame-Geometrie analytisch und als 3x-Pixel-Crop erfassen
und nur die obigen visuellen Gates auswerten. Ein einziger Frame über `0,5 px`,
ein Ruhewert über `0,150 mm` oder ein Geräte-Frametime-/Energie-RED beendet die
Option. Ohne vorherige Vertragsannahme wird dieser Spike nicht gestartet.

## Option 2: SceneKit

Der lokale Befund ist differenziert: Xcode 26.2 liefert die Kernphysik-Header
ohne lokale `API_DEPRECATED`-Annotation. `timeStep` ist schreibbar, standardmäßig
`1/60 s`; `penetrationDistance` beschreibt direkt die Überlappung im
Szenenkoordinatenraum. Apple kennzeichnet jedoch die gesamte SceneKit-
Dokumentation als **Deprecated** und verweist auf die Migration zu RealityKit.
Die API-Verfügbarkeit erlaubt Wartung bestehender SceneKit-Apps, rechtfertigt
aber keine neue Projektabhängigkeit.

**Kleinster falsifizierbarer SceneKit-Spike:** keiner im Produktpfad. Das
Deprecation-Gate ist bereits RED. Nur wenn ein engine-unabhängiger Kontrollwert
benötigt wird, darf ein wegwerfbarer, nicht verlinkter Test die fünf V2-Fälle
mit `timeStep = 1/120 s` ausführen. Auch ein physisches GREEN würde SceneKit
nicht zur Produktionsoption machen.

## Option 3: Jolt Physics 5.6.0

Jolt ist eine aktiv gepflegte echte 3D-Rigid-Body-Engine. Release `5.6.0` wurde
am 11. Juli 2026 veröffentlicht. Upstream nennt Zylinder, Convex Hulls, Ebenen,
Compound Shapes und CCD, iOS x64/ARM64, C++17, Clang 16+, ausschließlich die
Standardbibliothek sowie einen Build ohne RTTI und Exceptions. Die offiziellen
Bindings verweisen auf Drittprojekte und enthalten kein Swift-Binding. Deshalb
ist ein projektspezifischer, sehr schmaler Objective-C++-Adapter weniger
Lieferkettenrisiko als ein weiteres inoffizielles Binding.

Jolt ist nicht unverändert auf die vorhandene Geometrie anwendbar. Upstream
empfiehlt dynamische Körper in einer Größenordnung von `0,1` bis `10 m`; die
Spike-Münze hat `22 mm` Durchmesser und `2,2 mm` Dicke. Außerdem sind
`mPenetrationSlop` und `mSpeculativeContactDistance` standardmäßig jeweils
`0,02 m` - weit oberhalb des Produktgates. Der Spike muss daher eine einheitliche
Längenskalierung als Hypothese prüfen. Bei Faktor `50` werden Durchmesser und
Dicke zu `1,1` und `0,11` Solver-Einheiten; das Produktgate entspricht
`0,0075` Solver-Einheiten. Alle Längen, linearen Geschwindigkeiten und die
Gravitation werden konsistent skaliert. Slop, speculative distance,
Iterationszahl und CCD werden als vorab begrenzte Testmatrix variiert, nicht
nach einzelnen Seeds handgetunt.

Die Replay-Zusage bleibt enger als PochKits fachlicher Vertrag. Jolt verlangt
gleiche Mutationsreihenfolge und dasselbe Binary; Cross-Platform-Determinismus
muss explizit aktiviert werden. Kontakt-Listener können aus mehreren Threads
in nichtdeterministischer Reihenfolge kommen und müssen vor fachfreier
Auswertung stabil sortiert werden. Langfristige visuelle Replays speichern
deshalb entweder versionierte Physics-Inputs plus Engine-/Define-Fingerprint
oder Transform-Keyframes. Niemals darf ein Jolt-Ergebnis eine PochKit-
Entscheidung verändern.

### Kleinster falsifizierbarer Jolt-Spike

Der Spike bleibt außerhalb der App und enthält nur:

- Jolt `v5.6.0` als statische Distribution, ohne GPU-/Hair-/Debug-Renderer,
  plus einen C-ABI-Adapter für World-Lifecycle, Body-Erzeugung, Step und
  Transform-Snapshot;
- einen dynamischen Zylinder/Convex-Hull und statische Boden-/Lippenkörper mit
  den exakten V2-Maßen, Massen und Anfangszuständen;
- festen `1/120-s`-Physikschritt mit höchstens zwei Schritten je 60-Hz-Frame;
- `CROSS_PLATFORM_DETERMINISTIC=ON`, identische Defines, präzises
  Floating-Point und `-ffp-contract=off`;
- dieselben fünf V2-Kontaktfälle plus den dynamischsten Lippenfall aus V1;
- einen headless Messpfad und einen dünnen `ARView`-Renderer ohne
  RealityKit-Physikkörper. Der Renderer interpoliert nur zwischen zwei
  bestätigten Jolt-Snapshots; Messwerte stammen immer aus dem Solverzustand,
  nie aus der interpolierten Darstellung.

Ein Faktor-50-Lauf und höchstens sechs vorab deklarierte Kombinationen aus
Slop, speculative distance, Position-/Velocity-Iterationszahl und CCD genügen.
Kein Pflichtfall darf nach Sichtung der Resultate individuell kalibriert werden.

### Jolt RED/GREEN-Gates

Jolt ist nur GREEN, wenn **alle** folgenden Gates erfüllt sind:

1. **Build und Plattform:** Distribution baut und linkt für iOS-17-Simulator
   und ein echtes arm64-Gerät. Keine undefinierten Symbole, Define-/RTTI-/LTO-
   Mismatches oder App-Store-untaugliche Architektur. RED bei Simulator-only.
2. **Unveränderte Kontaktgeometrie:** In jedem Pflichtfall maximal
   `0,150 mm` transiente geometrische Überlappung, gemessen unabhängig aus
   Solvertransform und Nominalshape. Ein einzelner Überschreitungsframe ist RED.
3. **Dynamik:** Kein Tunneling oder Entkommen an Boden/Lippe; mindestens
   `0,750 s` natürliche Ruhe innerhalb von `5,0 s`; kein künstliches Nullsetzen
   von Geschwindigkeit; keine positive Gesamtenergie-Drift über `1 %` zwischen
   kontaktfreien Vergleichszeitpunkten. Jeder Verstoß ist RED.
4. **Determinismus:** Für jeden Pflichtfall liefern 100 Wiederholungen desselben
   Release-Binaries exakt denselben Hash über quantisierte Position,
   Orientierung sowie lineare und Winkelgeschwindigkeit jedes Steps. Mit
   Cross-Platform-Modus müssen iOS-17-Gerät und arm64-Simulator denselben Hash
   liefern. Abweichung ist RED; eine Upstream-Zusage ersetzt die Messung nicht.
5. **Replay-Grenze:** Engineversion, Commit, Compiler, Defines,
   Skalierungsfaktor, Settings und Inputreihenfolge werden im Replay-Fingerprint
   gespeichert. Ein Replay mit anderem Fingerprint wird nicht still neu
   simuliert. Fehlende Versionierung ist RED.
6. **60 FPS:** Auf dem ältesten verfügbaren unterstützten realen iOS-17-Gerät
   bleibt der Physikschritt bei neun gleichzeitig aktiven Münzen bei
   `p99 <= 1,0 ms`; der integrierte 10-Minuten-Flow verfehlt weniger als `1 %`
   der 60-Hz-Frames und zeigt keinen fortlaufenden Backlog. Simulatorwerte
   genügen nicht.
7. **Energie:** Im gleichen 10-Minuten-Flow bleibt der thermische Zustand
   `nominal`; mittlere CPU-Nutzung steigt gegenüber demselben Renderflow mit
   eingefrorenen Münztransforms um höchstens fünf Prozentpunkte. RED bei
   `fair/serious/critical` oder größerem Delta.
8. **Binary und Lizenz:** Der gemessene Anstieg des entpackten Release-App-
   Bundles bleibt `<= 5 MiB`; MIT-Copyright und Lizenztext sind im
   Drittanbieter-Nachweis enthalten. Größeres Delta oder fehlende Notice ist RED.
9. **SwiftUI, Kamera und Rendering:** Fünf Board-Anker stimmen in Portrait,
   Landscape und iPad an der nativen Pane-Größe jeweils auf höchstens
   `1,0` physisches Pixel mit `BoardSpaceProjection` überein. Kein doppelter
   Physiklauf, kein Touch-/Accessibility-Blocker und kein sichtbarer
   Compositing-Rand. Ein Verstoß ist RED.
10. **Concurrency:** C++-World und Step haben genau einen Besitzer. Swift erhält
    nur `Sendable`-Wertsnapshots; RealityKit-Updates laufen `@MainActor`. Thread
    Sanitizer, Address Sanitizer und Undefined Behavior Sanitizer melden im
    Spike keinen Fehler. Ein Finding ist RED.

Die numerischen Performance-, Energie- und Binary-Grenzen sind
Akzeptanzkriterien für den Spike, keine Behauptung über Jolt. Werden sie als
Produktbudget geändert, muss diese Entscheidung vor dem Lauf versioniert
werden; nachträgliches Verschieben zum Retten eines Resultats ist nicht erlaubt.

## Option 4: eigener Persistent-Manifold-Solver

Ein eigener Solver ist nur dann rational, wenn der Scope dauerhaft auf wenige
konvexe Münzen gegen statischen Boden und statische Lippe begrenzt bleibt. Der
Minimalumfang ist dennoch erheblich: Cylinder-/Convex-vs-Plane/Lip-Narrowphase,
stabile Kontakt-IDs, Mehrpunkt-Manifold, Warm Start, sequentielle Impulse,
Reibung und Rollwiderstand, Positionskorrektur, CCD, Sleep sowie konsistente
Trägheit und Quaternion-Integration. Ein Solver ohne persistente Kontakte wäre
keine Ausführung dieser Option.

**Kleinster falsifizierbarer eigener Spike:** headless Swift-Modul mit einem
dynamischen Münzkörper und statischem Boden/Lippenprofil, festem `1/120-s`-
Schritt, persistenten Kontakt-IDs und Warm Start. Zuerst die sechs identischen
Jolt-Pflichtfälle, danach 10.000 deterministisch erzeugte Startlagen. GREEN nur,
wenn die Jolt-Gates 2 bis 7 und 10 unverändert erfüllt werden und zusätzlich
für alle 10.000 Seeds keine NaNs, kein Escape, kein Tunneling und keine
zustandsabhängige Kontaktreihenfolge auftreten. Erst danach darf Kamera/
Rendering angebunden werden. Ein Fehler ist RED; der Solver wird nicht durch
seed-spezifische Sonderfälle erweitert.

## Zielarchitektur bei Jolt-GREEN

```text
PochKit Seed + Aktionen
        |
        v
fachlicher Event-Strom  -----------------> SwiftUI-Overlays
        |
        v
versionierter CoinPhysicsInput
        |
        v
JoltWorld (Objective-C++ besessen, fester Takt)
        |
        v
Sendable TransformSnapshot + Messwerte
        |
        v
@MainActor RealityKit-Renderinsel
        |
        v
BoardSpaceProjection / SwiftUI-Compositing
```

Die Physik ist eine austauschbare Präsentationskomponente. Bei Reduce Motion,
Unterbrechung oder Replay darf SwiftUI die Inszenierung verkürzen oder gespeicherte
Keyframes abspielen, ohne PochKit-Zustand zu ändern. RealityKit-Entities haben
im Hybrid keine dynamischen Physikkomponenten; damit existiert genau ein Solver.

## Abschlusskriterium

Die nächste Architekturentscheidung wird erst nach dem Jolt-Spike getroffen:

- **Jolt GREEN:** Hybrid Jolt + RealityKit als kleinste Produktionsintegration
  planen; Binary- und Notice-Artefakte versionieren.
- **Jolt RED am `0,150-mm`- oder Determinismus-Gate:** eigenen
  Persistent-Manifold-Spike ausführen.
- **Jolt RED nur an Binary/Energie/Integration:** zuerst den nachweislich roten
  Kostenblock isolieren; nicht automatisch einen Solver neu schreiben.
- **Produkt akzeptiert stattdessen den visuellen Vertrag:** RealityKit-only
  separat neu prüfen. Das bestehende physische RED bleibt dokumentiert.
- **SceneKit:** bleibt unabhängig von allen Messergebnissen RED für eine
  Neuintegration.

## Offizielle Primärquellen

Alle Webquellen wurden am **19. Juli 2026** abgerufen.

### Apple

- [RealityKit: PhysicsBodyComponent](https://developer.apple.com/documentation/realitykit/physicsbodycomponent) - Physikkörper, CollisionComponent, Material, Masse und CCD.
- [RealityKit: ARView](https://developer.apple.com/documentation/realitykit/arview) - UIKit-basierter 3D-Renderer, Szene und Kameraoptionen.
- [SwiftUI: UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable) - offizieller UIKit-in-SwiftUI-Integrationsweg.
- [SceneKit](https://developer.apple.com/documentation/scenekit/) - Apple markiert das Framework als deprecated und verweist auf RealityKit.
- [Bringing your SceneKit projects to RealityKit](https://developer.apple.com/documentation/realitykit/bringing-your-scenekit-projects-to-realitykit) - Apples Migrationspfad und Einordnung als soft-deprecated.
- [SceneKit: SCNPhysicsWorld.timeStep](https://developer.apple.com/documentation/scenekit/scnphysicsworld/timestep) - steuerbarer Physikschritt und Kosten-/Genauigkeitsabwägung.
- [SceneKit: SCNPhysicsContact.penetrationDistance](https://developer.apple.com/documentation/scenekit/scnphysicscontact/penetrationdistance) - öffentliche Überlappungsdistanz.

### Jolt Physics, Upstream

- [Release 5.6.0](https://github.com/jrouwe/JoltPhysics/releases/tag/v5.6.0) - aktueller unveränderlicher Release vom 11. Juli 2026.
- [README v5.6.0](https://raw.githubusercontent.com/jrouwe/JoltPhysics/v5.6.0/README.md) - iOS-Support, Shapes, CCD, Compileranforderungen, Dependencies, Bindings und Lizenz.
- [Build-Dokumentation v5.6.0](https://raw.githubusercontent.com/jrouwe/JoltPhysics/v5.6.0/Build/README.md) - iOS-CMake/Xcode-Pfad sowie Risiken durch Defines, RTTI und LTO.
- [CMake-Konfiguration v5.6.0](https://raw.githubusercontent.com/jrouwe/JoltPhysics/v5.6.0/Build/CMakeLists.txt) - Cross-Platform-Determinismus standardmäßig aus, Shared-Library- und LTO-Optionen.
- [Architecture and API documentation](https://jrouwe.github.io/JoltPhysics/) - Maßstabsempfehlung, Determinismusbedingungen und Caveats sowie SaveState/RestoreState.
- [PhysicsSettings](https://jrouwe.github.io/JoltPhysics/struct_physics_settings.html) - Default-Slop, speculative contact distance, Solveriterationszahl, Warm Start und Determinismusflag.
- [MIT-Lizenz v5.6.0](https://raw.githubusercontent.com/jrouwe/JoltPhysics/v5.6.0/LICENSE) - Rechte, Notice-Pflicht und Haftungsausschluss.

## Projektspezifische Messquellen

- `tasks/reviews/coin-realitykit-spike-v2/RESULT.md`
- `tasks/reviews/coin-realitykit-spike-v2/runtime-result.json`
- `tasks/reviews/coin-realitykit-spike-v2/runtime-result-run2.json`
- `tasks/reviews/coin-realitykit-spike/RESULT.md`
