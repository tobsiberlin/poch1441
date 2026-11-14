# Card Motion V3 - iOS-Integrationsentscheidung

**Stand:** 2026-07-19  
**Zielplattform:** iOS 17, SwiftUI mit Core-Animation-Compositing  
**App-Entscheidung:** **REVIEW - noch keine Freigabe zur Produktintegration**  
**Webstudie:** **APPROVED als Bewegungs- und Bildvertrag, nicht als App-Implementierung**

## Entscheidung in einem Satz

Card Motion V3 wird als visuelle Spezifikation für Flugbahn, Fächer, Tiefenstaffelung, Kontakt und Live Reduce Motion übernommen. Die App darf sie aber erst nach einem isolierten nativen Spike integrieren, weil die aktuellen SwiftUI-Callsites den Kartenschatten mit der Karte kippen, Reduce-Motion-Settles teils Feedback ohne sichtbaren Kontakt auslösen und V3-`Return` beziehungsweise `Reveal` nicht unverändert zur Spielsemantik passen.

## Was aus V3 übernommen wird

Die folgenden V3-Eigenschaften sind als Designvertrag belastbar:

- Die Kartenfläche und ihre Bodenprojektion sind zwei getrennte Ebenen.
- Die Karte darf einer Bogenbahn folgen und um ihre eigene Achse kippen; der Tischschatten folgt einer flachen, linearen Bodenbahn und kippt nie mit.
- Aktive Karten liegen eindeutig über statischen Fächern und unter HUD, Meldungen und modalen Bedienelementen.
- `Deal`, `Fan`, `Reveal`, `Play` und ein vor Kontakt abgebrochener `Return` besitzen erkennbare Zustände statt lose verketteter Einzelanimationen.
- Haptik und Audio entstehen höchstens einmal am tatsächlich akzeptierten Kontakt, nicht bei Abflug, Scheitelpunkt, Flip, Abbruch oder einem rein barrierebedingten Settle.
- Ein während der Bewegung aktiviertes Reduce Motion führt über einen kurzen Opazitätsübergang in einen gültigen Endzustand. Es startet keine verbleibende räumliche Sequenz neu.

Die V3-Belege bleiben dafür die maßgeblichen visuellen Referenzen:

- `tasks/reviews/motion-cards-v3/evidence/contact-sheet-390x844.png`
- `tasks/reviews/motion-cards-v3/evidence/contact-sheet-667x375.png`

Die Kontaktbögen belegen die gewünschte Silhouette in beiden geprüften Viewports und die V3-QA belegt die Webverträge. Sie belegen jedoch weder native Framezeiten noch SwiftUI-Unterbrechbarkeit, VoiceOver, Rotation, thermische Stabilität oder korrektes Verhalten auf einem echten iOS-17-Gerät. Die Webfreigabe darf deshalb nicht als Appfreigabe zitiert werden.

## Kritische Grenzen der V3-Framebelege

1. CSS- und Web-Animationsfortschritt sind kein Nachweis für SwiftUI- oder Core-Animation-Presentation-Values.
2. Die 16 aufgenommenen Zustände zeigen Geometrie, aber keine durchgehenden 60 FPS und keine ausgelassenen Frames zwischen den Aufnahmen.
3. V3 verwendet synthetische Reveal- und Return-Beats. Im Spiel dürfen sie weder verdeckte Kartenidentitäten offenlegen noch einen bereits regelwirksam gespielten Stich zurück in die Hand bewegen.
4. Web-Blur und Web-Shadow haben andere Rasterisierungs- und Offscreen-Kosten als SwiftUI-`shadow` und `CALayer.shadowPath`.
5. Die Webgrößen bilden weder die realen `CardBack`-/`CardFace`-Materialkosten noch die Metal-`layerEffect`-Pipeline der App ab.
6. Die Webstudie prüft keine Unterbrechung durch Phasewechsel, Skip, erneuten Start, Reduce Motion oder veraltete Completion-Callbacks.

## Ist-Zustand und exakte Callsite-Karte

| Datei | Aktuelle Verantwortung | Integrationsbefund |
|---|---|---|
| `App/ContentView.swift:102` | Liest `accessibilityReduceMotion` live. | Das Signal existiert bereits und muss die aktive Card-Motion-Transaktion retargeten. |
| `App/ContentView.swift:129` | Kombiniert Guided Reduce Motion und deaktivierte Tischeffekte zu sofortigem Settle. | Die visuelle Präferenz und die Sequenzsteuerung sind gekoppelt; Feedback darf dabei nicht automatisch ausgelöst werden. |
| `App/ContentView.swift:181` | Bindet `DealOverlay` nur in Phase `.melden` ein. | Phase 1 kann isoliert migriert werden, ohne Spieltisch oder PochKit anzufassen. |
| `App/ContentView.swift:259` | Übersetzt jedes `game.hapticTick` in `sensoryFeedback(.impact(weight: .light))`. | Der globale Tick kennt keinen Auslösertyp. Für Card Motion muss zwischen räumlichem Kontakt und stillem Accessibility-Settle unterschieden werden. |
| `App/ContentView.swift:277` | Settelt Phase 1 bei live geändertem Reduce Motion. | Richtiger Einstiegspunkt, aber der aktuelle Settle-Pfad erzeugt unerwünschtes Feedback. |
| `App/DealOverlay.swift:36` | Leitet aktive Flüge aus `landedDeals..<startedDeals` ab. | Gute deterministische Grenze; maximal zwei aktive Flüge bleiben erhalten. |
| `App/DealOverlay.swift:229` | Baut Gegnerfächer mit Rotation, Offset und angehängtem Schatten. | Statische Fächer dürfen ihren Materialschatten behalten; der bewegte Bodenschatten braucht eine eigene Ebene. |
| `App/DealOverlay.swift:323` | Zeichnet den Kartenstapel und seine Schichten. | Quelle für Deal, aber keine neue Regelverantwortung. |
| `App/DealOverlay.swift:374` | Wählt identitätsneutrales Rückseitenmaterial. | Unverhandelbare Informationsgrenze; Card Motion darf keine Vorderseite in Phase 1 materialisieren. |
| `App/DealOverlay.swift:391` | Berechnet Deck- und Fächerpose. | Geeignete Quelle für Zielpose; Flug- und Schattenpfad müssen getrennt werden. |
| `App/DealOverlay.swift:496` | `FlyingBack` führt den Deal-Flug aus. | Primärer Phase-1-Migrationspunkt. |
| `App/DealOverlay.swift:560` | Bewegte `CardBack` trägt einen angehängten SwiftUI-Schatten. | Verletzt V3: Der Schatten erbt Kartenrotation und Bogenbahn. |
| `App/ImpactFlight.swift:30` | `PresentationDirector` schützt Begin, Impact, Complete und Cancel. | Semantik wiederverwenden, aber nicht den generischen Renderer ändern. |
| `App/ImpactFlight.swift:106` | `ImpactFlight` startet eine feste Progress-Animation und meldet einmaligen Impact. | Callback-Guard ist nützlich; die View-Identität und Presentation-Continuity sind für echtes Retargeting noch nicht als Vertrag getestet. |
| `App/ImpactFlight.swift:183` | `FlightPathEffect` setzt eine quadratische Translation. | Die Karte besitzt einen Bogen, der Schatten benötigt dagegen einen separaten linearen Effekt. |
| `App/Effects.swift:7` | `PhysicalMotion` definiert Dauer und Pfad. | Kann mathematische Hilfen liefern; der R1-Coin-Feedbackpfad darf nicht für Karten umgedeutet werden. |
| `App/Effects.swift:104` | `R1ContactFeedback` koppelt Haptik und Audio an Kontakt. | Gutes Kontaktprinzip, aber falsche Oberfläche und falsche Audiodateien für Karten. |
| `App/DesignTokens.swift:171` | Deal-Cadence ist 0,32 Sekunden. | V3 verwendet 0,36 Sekunden. Dieser Produktwert wird nicht stillschweigend geändert, sondern im Spike A/B-geprüft. |
| `App/DesignTokens.swift:177` | Baseline für Phase-1-Flug ist 0,42 Sekunden. | Aktueller Deal-Pfad erweitert distanzabhängig bis ungefähr 0,58 Sekunden. Das ist ein brauchbarer nativer Ausgangskorridor. |
| `App/GameState.swift:1146` | Startet die Deal-Präsentation oder settelt sofort. | Der reduzierte Pfad erhöht aktuell `hapticTick`, obwohl keine räumliche Landung sichtbar war. |
| `App/GameState.swift:1237` | `skipDeal` storniert Task und Präsentationen. | Generation und Cancel sind richtig; der abschließende Haptik-Tick ist für Card Motion semantisch falsch. |
| `App/GameState.swift:1264` | Deal-Loop begrenzt auf maximal zwei gleichzeitige Flüge. | Gute Performancegrenze und Teil des nativen Vertrags. |
| `App/GameState.swift:1295` | `markDealLanded` akzeptiert den Kontakt und erhöht den Tick. | Das ist der einzige normale Phase-1-Zeitpunkt für Kartenfeedback. |
| `App/Phase3View.swift:39` | Erzeugt die aktive gespielte Kartenankunft. | Primärer Phase-3-Migrationspunkt; benötigt explizites z-order. |
| `App/Phase3View.swift:233` | Zeichnet den gesettelten Stichfächer mit slotbasiertem z-order. | Der statische Zielcontainer bleibt SwiftUI. |
| `App/Phase3View.swift:635` | Erfasst die exakte Handkarten-Quellpose vor `humanLead`. | Gute Quelle für `Fan -> Play`; die Regel wird weiterhin sofort von PochKit/GameState verarbeitet. |
| `App/Phase3View.swift:858` | `Phase3CardArrival` führt den Spielkartenflug aus. | Primärer Phase-3-Renderer für V3-`Play`. |
| `App/Phase3View.swift:883` | Bewegte `CardFace` trägt 3D-Rotation und angehängten Schatten. | Verletzt V3 aus demselben Grund wie `FlyingBack`. |
| `App/GameState.swift:811` | `markPlayLanded` akzeptiert Kontakt und erzeugt Feedback. | Normaler Phase-3-Kontaktpunkt. |
| `App/GameState.swift:828` | Reduce-Motion-Settle ruft `markPlayLanded` auf. | Muss später still setteln, weil ein Accessibility-Wechsel kein physischer Kontakt ist. |
| `Tests/CardVisualInformationBoundaryContractTests.swift:11` | Schützt verdeckte Kartenidentitäten in Phase 1. | Muss für jede Integration grün bleiben. |
| `Tests/ImpactFlightContractTests.swift` | Schützt Impact- und Cancel-Verträge. | Darf durch eine kartenlokale Lösung nicht regressieren. |

## Semantisch zulässige Zustandsmaschine

Die Zustandsmaschine gehört zur Präsentation, nicht zu den Spielregeln. Sie wird pro sichtbarer Karte geführt; ein phasenspezifischer Adapter entscheidet, welche Übergänge überhaupt zulässig sind. Es gibt keinen globalen, phasenübergreifenden Kartenautomaten.

```swift
enum CardMotionPhase: Equatable, Sendable {
    case idle
    case deal(sequence: Int)
    case fan(slot: Int)
    case reveal(publicEventID: Int)
    case play(publicEventID: Int)
    case `return`(reason: CardReturnReason)
    case settled(container: CardContainer, slot: Int)
}

enum CardReturnReason: Equatable, Sendable {
    case cancelledBeforeContact
    case invalidatedPresentation
}
```

Zulässige Übergänge:

| Von | Nach | Phase 1 | Phase 3 | Bedingung |
|---|---|---:|---:|---|
| `idle` | `deal` | ja | nein | Deal-Sequenz wurde vom bestehenden Presenter gestartet. |
| `deal` | `fan` | ja | nein | `markDealLanded` hat genau diesen Kontakt akzeptiert. |
| `fan` | `reveal` | nein | ja, nur Bot/öffentlich | Die Vorderseite stammt aus `revealedPlayEvents`, niemals aus verdecktem Deal-State. |
| `reveal` | `play` | nein | ja | Öffentlicher Bot-Play-Event ist aktiv. |
| `fan` | `play` | nein | ja, Mensch | Quellpose wurde vor `humanLead` erfasst. |
| `play` | `settled` | nein | ja | `markPlayLanded` akzeptiert den Kontakt. |
| `play` | `return` | nein | ja | Nur Abbruch oder Invalidation vor akzeptiertem Kontakt. |
| `return` | `fan` | nein | ja | Die lokale Präsentation kehrt zur bereits vorhandenen Handdarstellung zurück. |
| beliebig räumlich | gültiger Endzustand | ja | ja | Live Reduce Motion: kurzer Fade, stilles atomisches Settle, veraltete Completion invalidieren. |

Nicht zulässig:

- `settled -> return` nach einem akzeptierten Stichkontakt.
- Ein Phase-1-`reveal` der ausgeteilten Handkarten.
- Ein Rückflug, der eine bereits durch `humanLead` oder Botlogik festgeschriebene Regelaktion rückgängig zu machen scheint.
- Ein Haptik- oder Audioereignis bei `reveal`, `return`, Reduce-Motion-Settle oder stale Completion.

V3-`Return` wird damit als Präsentationsabbruch vor Kontakt interpretiert, nicht als neue Undo-Spielregel.

## Empfohlener iOS-17-Renderpfad

### 1. SwiftUI bleibt Eigentümer von Komposition und Zustand

`CardBack`, `CardFace`, statische Handfächer und der gesettelte Stich bleiben SwiftUI. Die Kartenbewegung bleibt ein Overlay über dem SpriteKit-Tisch. PochKit und `SKScene` werden nicht erweitert.

Eine neue kartenlokale Flight-Komponente besitzt eine stabile Identität aus Präsentationsgeneration, Sequenz und Karten-/Event-ID. Sie rendert zwei Geschwister im selben `ZStack`:

1. `CardGroundProjection`: flacher, vorgerasterter Schatten mit eigenem linearem `GeometryEffect`.
2. `CardSurface`: bestehende SwiftUI-Kartenansicht mit Bogenpfad, Rotation, Flip und Griffpunktwechsel.

Der bestehende generische `ImpactFlight` wird im ersten Slice nicht verändert. Er wird auch für Münzen und weitere Präsentationen verwendet; eine Schattenkorrektur dort hätte unnötigen Blast Radius.

### 2. Karte und Bodenschatten teilen nur den normierten Fortschritt

Für Quelle `S`, Ziel `T` und normierten Fortschritt `t` gilt:

```text
ground(t) = mix(S, T, t)
lift(t)   = 4 * t * (1 - t)
card(t)   = ground(t) + lateralBias(t) + (0, -arcHeight * lift(t))
```

Der Schatten darf nur `ground(t)`, eine geringe kontaktabhängige Skalierung und Opazität verwenden. Er erhält niemals:

- `rotationEffect`
- `rotation3DEffect`
- den Karten-Bogenoffset
- den Bottom-Grip-Anker des Fächers

Der Schatten nutzt einen expliziten Pfad beziehungsweise eine vorgerasterte weiche Form. Ein dynamischer SwiftUI-Schatten auf der transformierten Kartenfläche ist für aktive Flüge verboten.

### 3. Unterbrechbarkeit

Solange reine SwiftUI-Transformationen auf dem Zielgerät die Performancegrenze halten, bleibt die View-Identität stabil und nur `animatableData` wird retargetet. SwiftUI/Core Animation startet eine neue Interpolation vom aktuellen Presentation-Value. Completion-Callbacks tragen zusätzlich die bestehende Präsentationsgeneration; alte Generationen dürfen weder landen noch Feedback auslösen.

Für Abbruch vor Kontakt:

1. laufenden Event im `PresentationDirector` invalidieren,
2. denselben sichtbaren Flight auf Fortschritt 0 retargeten,
3. für die Rückbewegung eine kritisch gedämpfte Feder oder eine gleichwertig monotone iOS-17-Spring ohne Bounce verwenden,
4. erst nach Rückkehr die Flight-Ebene entfernen.

Für Live Reduce Motion:

1. aktive Flight-Ebene in 80 bis 120 ms ausblenden,
2. während Opazität praktisch 0 ist Aufgaben und alte Generation invalidieren,
3. den gültigen Endzustand ohne räumliche Animation setzen,
4. Zielzustand in 100 bis 140 ms einblenden,
5. weder Haptik noch Audio auslösen.

Wenn der native Spike trotz stabiler Identität sichtbare Sprünge oder Framehitches zeigt, ist ein gezielter `UIViewRepresentable`-Fallback zulässig: zwei Geschwister-`CALayer`, `presentation()?.position` und `presentation()?.transform` vor dem Entfernen laufender Animationen in das Model-Layer übernehmen, danach vom sichtbaren Zustand retargeten. Dieser Fallback wird erst durch Messwerte aktiviert, nicht vorsorglich in alle Kartenansichten eingebaut.

### 4. z-order als explizite Bänder

Numerische Einzelwerte werden nicht in Views verteilt. Die Integration braucht zentrale Bänder, später in `DesignTokens.swift` oder einem Card-Motion-Namespace:

| Band | Inhalt |
|---|---|
| `table` | Tisch und ruhende Dekoration |
| `staticCards` | Hand-, Gegner- und Stichfächer mit slotbasiertem Unterindex |
| `groundProjection` | Schatten aktiver Karten, über dem Tisch, unter allen Kartenflächen |
| `activeCard` | Deal-, Reveal-, Play- oder Return-Flug |
| `phaseChrome` | Status, Meldungen und phasenspezifische Controls |
| `modal` | Dialoge und blockierende Overlays |

Beim Kontakt wird nicht die z-order des Fluges animiert. Stattdessen wird zuerst der gesettelte Zielslot committed und im selben Präsentationstakt die aktive Flight-Ebene entfernt. Dadurch gibt es keinen Frame, in dem die Karte unter ihren Zielnachbarn fällt.

### 5. Kontaktfeedback

Normaler Deal-Kontakt wird ausschließlich von `markDealLanded` akzeptiert, normaler Play-Kontakt ausschließlich von `markPlayLanded`. Beide brauchen langfristig eine Herkunft statt eines undifferenzierten Ticks, beispielsweise:

```swift
enum CardSettlementSource: Sendable {
    case spatialContact
    case accessibilitySettle
    case cancellation
}
```

Nur `.spatialContact` darf den Card-Feedback-Sink triggern. Ein Sink bündelt optional Haptik und Audio im selben Main-Actor-Turn. Die App besitzt derzeit keine passende Kartenkontakt-Audiodatei; die keramischen R1-Münzgeräusche werden nicht wiederverwendet. Der kleinste Spike prüft deshalb den Ereignisvertrag mit einem Spy und höchstens systemischer Haptik. Eine eigene kurze Karten-Audiodatei ist ein separater Asset- und Produktentscheid.

## Phasenspezifische Abbildung

### Phase 1 - Deal und Fan

- Quelle: `DealDeckAnchor` und `DealCardPose`.
- Aktive Identität: Deal-Sequenz plus Presentation-Generation.
- Bewegung: `idle -> deal -> fan`.
- Sichtbarer Inhalt: ausschließlich `CardBack` und identitätsneutrales Material.
- Gleichzeitigkeit: bestehendes Limit von maximal zwei aktiven Karten.
- Kontakt: bestehender akzeptierter `markDealLanded`-Event.
- Reduce Motion: verbleibende Flüge still setteln, ohne den heutigen zusätzlichen Haptik-Tick.

Die V3-Cadence von 0,36 Sekunden ersetzt die vorhandenen 0,32 Sekunden nicht automatisch. Der native Spike rendert beide Varianten mit realen App-Karten. Erst ein direkter Vergleich darf `Tokens.p1DealStep` ändern.

### Phase 3 - Fan, Reveal, Play und eingeschränkter Return

- Mensch: `fan -> play -> settled`.
- Bot: öffentlicher Event `reveal -> play -> settled`.
- `Return`: ausschließlich `play -> return -> fan` bei Invalidation vor akzeptiertem Kontakt.
- Quelle Mensch: `Phase3HumanFlightSource`, bereits vor dem Regelaufruf erfasst.
- Quelle Bot: nur `revealedPlayEvents`; keine Ableitung aus privater Handidentität.
- Ziel: `Phase3CardGeometry.playedCardTarget` und der gesettelte Stichfächer.
- Kontakt: bestehender akzeptierter `markPlayLanded`-Event.

Da `humanLead` die Regelaktion bereits vor dem sichtbaren Flug ausführt, darf ein optischer Return nicht behaupten, die Regelaktion rückgängig gemacht zu haben. Ein echter interaktiver Undo-Flow wäre neuer Produktscope und ist von dieser Entscheidung ausgeschlossen.

## Kleinster isolierter Swift-Spike

Der erste Spike besitzt **keinen Produkt-Callsite** und ändert weder PochKit noch GameState. Er besteht aus genau drei neuen Swift-Dateien und einem Preview-/Test-Host:

1. `App/CardMotionPlan.swift`
   - reine `Sendable`-/`Equatable`-Typen für Phase, Pose, erlaubte Transition und Progress-Sampling,
   - keine Regeln, keine Kartenidentitätsableitung, kein Audio,
   - deterministische Funktionen für Kartenbogen und lineare Bodenprojektion.
2. `App/CardMotionFlight.swift`
   - iOS-17-SwiftUI-Renderer mit zwei Geschwisterebenen,
   - stabiler Flight-Key und injizierbarer Progress,
   - `#Preview` mit realem `CardBack` und öffentlichem Test-`CardFace`,
   - live umschaltbares Reduce Motion und Abbruch vor Kontakt.
3. `Tests/CardMotionPlanTests.swift`
   - harte Zustands-, Geometrie-, Feedback- und Invalidation-Verträge.

Der Preview-Host wird nicht aus `ContentView` erreichbar gemacht. Das hält den Spike isoliert und reversibel. Erst nach Freigabe dieses Spikes folgt als eigener Slice die Phase-1-Anbindung in `DealOverlay`.

## Harte Spike-Tests

### Zustands- und Semantiktests

- Jede erlaubte Tabellenkante wird akzeptiert; jede andere Kante wird abgewiesen.
- `settled -> return` ist immer illegal.
- Phase 1 kann keinen `reveal(publicEventID:)` erzeugen.
- Ein stale Completion-Callback mit alter Generation ändert keinen Zustand.
- Ein akzeptierter Kontakt erzeugt exakt ein Feedbackereignis.
- Abbruch, Return, Duplicate-Impact und Accessibility-Settle erzeugen exakt null Feedbackereignisse.

### Geometrie- und Schattenverträge

Für mindestens 1.001 gleichmäßig verteilte `t`-Samples pro Deal-, Play- und Return-Pfad:

- Schattenstart und -ende stimmen innerhalb 0,01 pt mit Quelle und Ziel überein.
- Die Schattenpunkte liegen mit maximal 0,01 pt Abweichung auf der Geraden zwischen Quelle und Ziel.
- Der Kartenscheitel liegt sichtbar über der Schattenbahn; Quelle und Ziel der Kartenbahn stimmen innerhalb 0,01 pt.
- Schattenrotation ist für jedes Sample exakt 0.
- Schatten- und Karten-z-order bleiben in ihren definierten Bändern.
- Der Schattenpfad enthält keine 3D-Transformation und keinen Fächer-Grip-Offset.

### Informationsgrenze

- Bestehende `CardVisualInformationBoundaryContractTests` bleiben grün.
- `DealOverlay` und der Phase-1-Spike enthalten weiterhin weder `CardFace` noch Rank/Suit-Zugriff.
- Phase-3-Reveal kann ausschließlich mit einer ID aus dem öffentlichen `revealedPlayEvents`-Strom initialisiert werden.

### Live Reduce Motion und Unterbrechung

- Bei Umschaltung bei Fortschritt 0,15, 0,50 und 0,85 wird der aktive Flight innerhalb 120 ms unsichtbar.
- Während sichtbarer Opazität über 0,02 gibt es keinen Positionssprung größer als 1 pt zwischen zwei 60-Hz-Samples.
- Nach dem Fade existiert genau ein gültiger Zielzustand, keine doppelte Karte und kein aktiver Presentation-Event.
- Drei schnelle Folgen `play -> return -> play` enden deterministisch im letzten Ziel; alte Completions landen nicht.
- Reduce Motion ist live, nicht nur beim ersten Erzeugen der View ausgewertet.

### Native visuelle Belege

Der Spike erzeugt deterministische, progressinjizierte Kontaktbögen für dieselben sichtbaren Flächen wie V3:

- 390 x 844 pt
- 667 x 375 pt
- zusätzlich eine repräsentative aktuelle iPhone-Breite im nativen Simulator

Die Frames werden nicht mit Wall-Clock-Timern aufgenommen, sondern mit festen Progresswerten. Damit vergleichen die Belege Geometrie und z-order reproduzierbar. Ein eigener Echtzeitlauf prüft danach Unterbrechung und Timing.

### 60-FPS-Gate

Auf einem realen iOS-17-Referenzgerät, nicht nur im Simulator:

- maximal zwei gleichzeitige Deal-Flüge,
- mindestens 95 Prozent der 60-Hz-Frameintervalle bei höchstens 16,67 ms,
- kein aufeinanderfolgendes Paar von Frames über 33,3 ms,
- keine Layout- oder Textmessung im `animatableData`-/per-frame-Pfad,
- keine neue Kartenansicht oder neue Shadow-Path-Allokation pro Frame,
- Test mit normaler und reduzierter Bewegung sowie unmittelbar nach Rotation.

Der Lauf erhält ein eigenes `os_signpost`-Intervall und wird mit Core Animation Instruments gegengeprüft. Wenn der reine SwiftUI-Renderer das Gate verfehlt, wird nur die aktive Flight-Ebene auf den beschriebenen Geschwister-`CALayer`-Fallback umgestellt. Statische Fächer bleiben SwiftUI.

## Blast Radius der späteren Produktintegration

### Erster Produkt-Slice: Phase 1

| Risiko | Datei | Geplante Änderung |
|---|---|---|
| L1 | neu `App/CardMotionPlan.swift` | Präsentationszustand und Pfadmathematik. |
| L1 | neu `App/CardMotionFlight.swift` | Kartenlokaler Renderer, ohne Änderung am generischen `ImpactFlight`. |
| L2 | `App/DealOverlay.swift` | `FlyingBack` durch getrennte Card-/Shadow-Ebenen ersetzen; bestehende Posen und Identitätsneutralität bewahren. |
| L2 | `App/CardFace.swift` | Noch nicht für Phase 1 nötig. Später optionaler, standardmäßig unveränderter Shadow-Style. |
| L2 | `App/DesignTokens.swift` | Erst nach Spike freigegebene Timing-, z-order- und Schattenwerte zentralisieren. |
| L3 | `App/GameState.swift` | Räumlichen Kontakt von stillem Accessibility-Settle trennen; Generation und maximal zwei Flüge bewahren. |
| L2 | `App/ContentView.swift` | Live Reduce Motion und globales Feedback auf den neuen Herkunftsvertrag abbilden. |
| L1-L2 | vorhandene Tests plus neue Card-Motion-Tests | Informationsgrenze, Kontakt, Invalidation, Reduce Motion und Geometrie. |

### Zweiter Produkt-Slice: Phase 3

| Risiko | Datei | Geplante Änderung |
|---|---|---|
| L3 | `App/Phase3View.swift` | `Phase3CardArrival`, explizite z-Bänder, Reveal/Play und Abbruch vor Kontakt integrieren. |
| L2 | `App/CardFace.swift` | Materialschatten für aktive Flights gezielt deaktivierbar machen; Default bleibt unverändert. |
| L3 | `App/GameState.swift` | `markPlayLanded` und Accessibility-Settle nach Feedbackherkunft trennen. |
| L2 | `App/ContentView.swift` | Card-spezifischen Kontakttrigger statt undifferenziertem Tick anbinden. |
| L2 | neue beziehungsweise erweiterte UI- und Performance-Tests | Öffentliche Reveal-Quelle, Doppelbild, Rotation, Unterbrechung, 60 FPS. |

### Explizit nicht im Blast Radius

- PochKit-Regeln und deterministischer Kern
- SpriteKit-Tischszene
- Kartenidentitäts- und Materialplanung
- StoreKit, Economy oder Persistenz
- der generische `ImpactFlight` im ersten Slice
- R1-Münzfeedback und keramische Audiodateien
- neue Undo- oder Rückhol-Spielregel

## Freigabereihenfolge

1. **Jetzt:** V3 bleibt als Web-Bewegungsvertrag freigegeben; Appstatus bleibt REVIEW.
2. **Spike:** Die drei isolierten Swift-Dateien plus harte Tests und native Belege erstellen.
3. **Gate A:** Zustands-, Informations-, Schatten-, Unterbrechungs- und 60-FPS-Tests müssen vollständig grün sein.
4. **Phase 1:** Nur Deal/Fan integrieren und im echten Nutzerflow inklusive live Reduce Motion prüfen.
5. **Gate B:** Keine Haptik bei Skip oder Accessibility-Settle, keine verdeckte Vorderseite, keine Doppelkarte, keine Schattenkippung.
6. **Phase 3:** Reveal/Play und ausschließlich vor Kontakt zulässigen Return separat integrieren.
7. **App-Approval:** Erst nach realem iOS-17-Gerätetest, Interruption-Matrix und kombinierten Regressionstests von Phase 1 und Phase 3.

## Schlussstatus

**Webstudien-Approval:** APPROVED. V3 beschreibt die gewünschte Bewegungsgrammatik und liefert brauchbare visuelle Referenzen.

**App-Approval:** WITHHELD / REVIEW. Die native Integration ist noch nicht freigegeben. Die Blocker sind konkret und klein genug für einen isolierten Spike: getrennte Bodenprojektion, deterministischer per-card Zustandsvertrag, stilles Accessibility-Settle, generation-sichere Unterbrechung und ein gemessenes 60-FPS-Ergebnis auf iOS 17.
