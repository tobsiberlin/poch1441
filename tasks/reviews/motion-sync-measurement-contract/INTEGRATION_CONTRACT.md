# Integrationsvertrag für physische Synchronität

## Ziel

Münz- und Kartenimpakte teilen eine einzige kausale Kontaktzeit. Bild, Audio und Haptik werden nicht mit voneinander unabhängigen Delays gestartet. Sie werden vorab auf denselben Kontaktzeitpunkt geplant und tragen dieselbe `eventID` plus `generation`.

Der Vertrag trennt zwei Ebenen:

1. Softwarediagnose auf der Geräte-Host-Time erklärt Scheduling-Fehler.
2. Externe Messung prüft, wann Licht, Schalldruck und mechanische Vibration das echte iPhone tatsächlich verlassen.

Nur Ebene 2 kann das Freigabegate bestehen.

## Gemeinsame Zeitbasis

### Gerätezeit

- Autoritative Uhr ist `mach_absolute_time()`.
- Roh-Ticks bleiben für `AVAudioTime(hostTime:)` erhalten.
- Für JSONL und Statistik werden die Ticks mit `mach_timebase_info` einmalig in Nanosekunden normalisiert.
- `CACurrentMediaTime()` oder `ContinuousClock` dürfen nicht als zweite Scheduling-Uhr nebenher laufen.
- `CADisplayLink.timestamp` und `targetTimestamp` werden beim Render-Sampling auf die Host-Time bezogen.

### Aktiver Displaytakt und Frame-Segmente

`CAFrameRateRange` beziehungsweise `CADisplayLink.preferredFrameRateRange` beschreibt nur die angeforderte Spanne. Der aktive Takt wird ausschließlich aus aufeinanderfolgenden tatsächlichen `CADisplayLink.timestamp`-Intervallen bestimmt. Das Gerätemodell ist keine Messquelle.

Der Capture-Adapter puffert drei gleich klassifizierte Intervalle, bevor er 120, 80 oder 60 Hz bestätigt. Diese drei Frames werden rückwirkend dem neuen Segment zugeordnet, nicht verworfen. Ein Wechsel des bestätigten Takts erhöht `segmentIndex`. Auch ein Wechsel von Low Power Mode oder Thermal State erhöht den Segmentindex, damit Betriebsbedingungen nicht in einem p99-Wert vermischt werden. Nicht klassifizierbare Intervalle bleiben als eigenes ungültiges Segment sichtbar.

Jeder `MotionSyncFrameSample` enthält:

- tatsächliches Displayintervall,
- CPU-plus-GPU-Renderdauer,
- daraus bestätigten aktiven Takt,
- Low-Power-Zustand,
- Thermal State,
- Run- und Segmentindex.

Wo der Renderpfad einen `MTLCommandBuffer` besitzt, endet die Renderdauer am Completion-Handler dieses Buffers. Ein SpriteKit-Pfad, der den Command Buffer vollständig verbirgt, benötigt für dieses Gate einen instrumentierbaren `SKRenderer`-/Metal-Harness. Ein bloßes Ende des Scene-Updates ist keine GPU-Framezeit.

Frame-Gate pro Segment mit mindestens 120 Frames und Nearest-Rank-p99 ohne Ausreißerbereinigung:

| Tatsächlich gemessener Takt | Renderzeit p99 |
| --- | --- |
| 120 Hz | kleiner als 8,33 ms |
| 80 Hz | kleiner als 12,5 ms |
| 60 Hz | kleiner als 16,67 ms |

Die Ungleichung ist strikt. Ein Wert exakt auf dem Budget besteht das Gate nicht. Eine adaptive 120-Hz-Hardware darf in einem Run zwischen diesen Takten wechseln, aber jeder Abschnitt wird gegen sein eigenes Budget geprüft.

Die initial angeforderte `CAFrameRateRange`, der initial gemessene Takt, Low Power Mode und Thermal State stehen in `MotionSyncRunMetadata`. Tatsächliche Änderungen werden frameweise in den Segmenten festgehalten. `ProcessInfo.thermalState` und `ProcessInfo.isLowPowerModeEnabled` werden beim Start sowie bei ihren Systembenachrichtigungen neu gelesen.

### Core-Haptics-Brücke

`CHHapticEngine.currentTime` liegt in einer engine-relativen Sekundenbasis. Nach jedem Start, Reset, Audio-Route-Wechsel und App-Resume wird deshalb ein neuer Anker aufgenommen:

1. Host-Time `before` lesen.
2. `engine.currentTime` lesen.
3. Host-Time `after` lesen.
4. `(before + after) / 2` als Host-Anker verwenden.
5. Die Brückenunsicherheit `(after - before) / 2` protokollieren.

Eine Brücke mit mehr als 1 ms Unsicherheit wird verworfen und erneut aufgenommen. Der kleine Swift-Typ `MotionSyncHapticClockAnchor` bildet nur die lineare Umrechnung ab; Resets und Erneuerung bleiben Aufgabe des späteren Adapters.

## Ereignisfolge

Ein deterministischer Bewegungscontroller liefert einen zukünftigen `contactHostTime` möglichst vor dem Kontakt. Für nicht vorhersagbare Kollisionen muss die Simulation einen kurzen Rollhorizont besitzen. Audio-Engine, Samples und Haptik-Pattern sind bereits warm und geladen.

1. `simulationContact`: Die physikalische Simulation bestätigt oder korrigiert den geplanten Kontakt.
2. `visualSubmitted`: Der erste Renderzustand mit geschlossenem Kontakt wird für den passenden Display-Tick eingereicht.
3. `audioScheduled`: Der vorgerenderte PCM-Transient wird per `AVAudioPlayerNode.scheduleBuffer(..., at: AVAudioTime(hostTime: ...))` auf dieselbe Host-Time gelegt.
4. `audioRenderObserved`: Ein Render-Tap markiert den ersten Buffer mit dem Cue. Das diagnostiziert den Audiopfad, beweist aber nicht den DAC- oder Lautsprecherzeitpunkt.
5. `hapticScheduled`: Ein vorerzeugter `CHHapticAdvancedPatternPlayer` startet an der über den Anker berechneten Engine-Time.
6. Kamera und Mikrofone liefern die drei physischen Onsets.

Engine-Start, Dateidekodierung, Sample-Rate-Konvertierung, Pattern-Erzeugung und Audio-Session-Aktivierung sind im Kontaktpfad verboten.

## Transaktions- und Abbruchregeln

- Jede Bewegung hat eine stabile `eventID` und eine steigende `generation`.
- Ein Impakt darf pro Generation höchstens einmal auftreten.
- Unterbrechung vor dem Kontakt storniert alle noch nicht ausgegebenen Cues und schreibt `cancelled`.
- Ein Cue einer alten Generation darf niemals nach einem Retarget oder Szenenwechsel hörbar beziehungsweise fühlbar werden.
- Unterbrechung nach einem bereits physisch begonnenen Impakt darf dessen Ausschwingen verkürzen, aber keinen zweiten Impakt erzeugen.
- Mehrere Münzen dürfen zeitlich überlappen. Jeder physische Kontakt bleibt dennoch ein eigenes Ereignis. Ein zusammengelegter Klangteppich ohne Ereignisidentität ist nicht mess- oder steuerbar.

## Signposts

Eine spätere App-Integration verwendet `OSSignposter` mit konstanten Namen und der gleichen `OSSignpostID` pro Ereignis:

| Signpost | Zeitpunkt | Pflichtfelder |
| --- | --- | --- |
| `SimulationContact` | fester Simulationsschritt | `eventID`, `generation`, `object`, `variant`, Host-Ticks |
| `VisualSubmitted` | Render-Sampling für Kontaktframe | Ziel-VSync, Host-Ticks |
| `AudioScheduled` | Buffer erfolgreich geplant | Ziel-Host-Ticks, Sample-ID |
| `AudioRenderObserved` | erster Buffer mit Cue | Render-Host-Ticks, Sample-Time |
| `HapticScheduled` | Player erfolgreich geplant | Engine-Time, konvertierte Host-Ticks, Ankerunsicherheit |
| `MotionCancelled` | Generation ungültig | Grund und Host-Ticks |
| `FrameSegmentStart` | bestätigter Takt oder Betriebszustand ändert sich | Segment, gemessene Hz, angeforderte Range, Low Power, Thermal State |
| `FrameRender` | Renderarbeit beginnt und GPU-Arbeit endet | Segment, Frameindex, Renderdauer, Displayintervall |

Zusätzlich wird pro Run eine JSONL-Datei aus `MotionSyncObservation` geschrieben. Signpost-Namen bleiben konstant; IDs und Zeitwerte gehören in die Payload, nicht in dynamische Namen.

## Bildkontakt

Ein Kontakt ist nicht das Ende einer SwiftUI-Completion. Er ist der erste gerenderte Zustand, in dem die Projektionsgeometrie des Objekts die Kontaktfläche erreicht und die Kontaktschatten- oder Okklusionsbedingung geschlossen ist. Ein DEBUG-only Messkeil am äußersten Bildschirmrand wechselt exakt in diesem Frame von Schwarz auf Weiß. Er liegt außerhalb von App-Screenshots und wird in Release-Builds ausgeschlossen.

Dieser Messkeil macht den Kontakt bei 240 fps objektiv erkennbar. Die sichtbare Objektgeometrie wird zusätzlich frameweise kontrolliert, damit ein falsch gesetzter Keil keinen guten Messwert vortäuschen kann.

## AVAudioEngine

- Built-in-Speaker ist die primäre Freigaberoute. Bluetooth ist wegen variabler Route-Latenz ein eigener, nicht vergleichbarer Lauf.
- PCM-Varianten liegen vollständig dekodiert im Speicher.
- Audio-Session und Engine laufen vor Beginn der Sequenz.
- Die Zielzeit wird direkt als `AVAudioTime(hostTime:)` gesetzt.
- Ein kurzer, materialgerechter Attack definiert den messbaren Onset. Ein schleichend eingeblendeter Sound ist nicht synchron messbar und physikalisch falsch.
- Scheduling-, Render- und externer Audio-Onset werden getrennt aufgezeichnet.

## Core Haptics

- Haptik-Pattern und Player werden vor der Bewegung angelegt.
- Der scharfe Anfangsimpuls liegt auf dem Kontakt. Nachlauf darf Material und Masse tragen, aber nicht den Onset verschleiern.
- Haptic Engine Reset und Stop invalidieren den Zeitanker und alle geplanten Generationen.
- `supportsHaptics == false` oder deaktivierte Systemhaptik wird als Hardwarezustand protokolliert. Ein solcher Lauf kann das physische Haptikgate nicht bestehen, ist aber kein App-Absturz.

## Reduced Motion

Reduced Motion ändert die Choreografie, nicht die Kausalität:

- Keine große ballistische Flugbahn, kein Kameraschwenk, kein Parallax- oder Motion-Blur-Ersatz.
- Der Zielort bleibt verständlich, etwa durch einen sehr kurzen lokalen Settle und Materialkontakt statt einer Reise über den Bildschirm.
- `eventID`, `generation`, Kontaktdefinition und Messgrenzen bleiben identisch.
- Audio und Haptik dürfen dezenter sein, aber ihr Attack bleibt auf dem Kontakt. Sie werden nicht verstärkt, um fehlende Bewegung zu kompensieren.
- Abbruch, schnelle Wiederholung und Szenenwechsel müssen auch in dieser Variante ohne verwaiste Cues funktionieren.

Standard und Reduced Motion werden als getrennte Messzellen mit jeweils mindestens 30 vollständigen Ereignissen geprüft.

## Freigabegate

Für jede Kombination aus Gerät, Objektart und Motion-Variante:

- mindestens 30 vollständige physische Ereignisse,
- keine Ausreißerbereinigung,
- absolute Audio-Bild-Abweichung p95 höchstens 16,7 ms,
- absolute Haptik-Bild-Abweichung p95 höchstens 20 ms,
- jede fehlende oder doppelte physische Markierung verwirft das Ereignis und wird gezählt,
- mehr als ein verworfenes Ereignis pro 30er-Lauf blockiert die Freigabe und verlangt einen Wiederholungslauf.

Zusätzlich werden Median und Vorzeichen der Abweichung berichtet, damit eine systematische Früh- oder Spätlage korrigiert werden kann. Sie ersetzen das p95-Gate nicht.

Das physische Sync-Gate und das Rendering-Gate müssen beide bestehen. Gute Audio-Haptik-Synchronität darf keinen ruckelnden Bildpfad verdecken und eine glatte Animation darf keine zeitlich entkoppelten Ausgabekanäle entschuldigen.
