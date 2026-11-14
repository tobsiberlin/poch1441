# 240-fps- und Kontaktmikrofon-Protokoll

## Zweck

Das Protokoll misst die physische Synchronität am echten iPhone. Simulator, Instruments und Audio-Render-Taps können Schedulingfehler finden, aber weder Display-Scanout noch Lautsprecher- noch Taptic-Engine-Latenz beweisen.

## Benötigte Hardware

Minimal belastbar:

- echtes Ziel-iPhone,
- zweites iPhone im nativen 240-fps-Slo-Mo-Modus als Messkamera,
- Piezo-Kontaktmikrofon an der Rückseite des Test-iPhones nahe der Taptic Engine,
- akustisches Messmikrofon nahe dem unteren Lautsprecher,
- zweikanaliger 96-kHz-Recorder oder Audio-Interface für Akustik- und Kontaktmikrofon,
- sicht- und hörbarer Sync-Slate für zweites iPhone und Audiorecorder,
- starre Halterung, markierte Sensorposition und resonanzarme Unterlage.

Das originale Slo-Mo-Asset des zweiten iPhones wird direkt ausgelesen. Messenger-Export, Bildschirmaufnahme oder eine auf 30/60 fps transkodierte Kopie ist nur Sichtprüfung, kein Freigabebeleg. Audio und Haptik stammen aus dem separaten 96-kHz-Zweikanalrecorder, nicht aus der Slo-Mo-Tonspur.

## Kalibrierung

1. Zweites iPhone fest montieren, 240-fps-Slo-Mo wählen und AE/AF sperren. HDR beziehungsweise automatische Nachbearbeitung soweit im gewählten Aufnahmepfad möglich deaktivieren.
2. Reale Bildrate aus den Sample-Timestamps des originalen Slo-Mo-Assets bestimmen, nicht pauschal 240,000 fps annehmen.
3. Displayhelligkeit und Lautstärke festsetzen. Auto-Helligkeit, Low Power Mode und Audio-Route protokollieren.
4. Kontaktmikrofon mit einer wiederholbaren Schablone befestigen. Position fotografieren.
5. Einen Audio-only- und einen Haptic-only-Lauf aufzeichnen. Damit Übersprechen und die jeweiligen Onset-Schwellen bestimmen.
6. Vor und nach jedem 30er-Lauf den sicht- und hörbaren Sync-Slate vor der Slo-Mo-Kamera auslösen. Eine harte sichtbare Kante und derselbe Klick müssen in Video, akustischem Kanal und Kontaktkanal erkennbar sein. Drift zwischen Anfang und Ende wird linear korrigiert.
7. Wenn die beiden Slate-Messungen um mehr als einen Kameraframe von der linearen Zuordnung abweichen, wird der Lauf verworfen.

## Aufnahme

- Kamera frontal genug positionieren, dass der DEBUG-Messkeil und der reale Objektkontakt zugleich scharf erkennbar sind.
- Belichtungszeit so kurz wählen, dass ein Kontaktframe keine starke Bewegungsunschärfe hat.
- Mindestens zwei Sekunden Vorlauf und Nachlauf aufnehmen.
- Pro Messzelle 30 vollständige Ereignisse aufzeichnen. Messzellen sind Objektart `coin` oder `card` und Variante `standard` oder `reducedMotion`.
- Warmzustand und erster Lauf nach Engine-Start getrennt kennzeichnen. Kalte Starts zählen nicht heimlich in einen warmen Lauf.
- Keine Ereignisse wegen schlechter Werte entfernen. Nur objektiv unvollständige Aufnahmen werden als verworfen dokumentiert.
- Parallel schreibt der DEBUG-Harness `MotionSyncFrameSample` für jeden Displayframe. Tatsächliche `CADisplayLink`-Intervalle, Renderdauer, Low Power Mode und Thermal State dürfen nicht aus dem Video geschätzt werden.

## Rendering-Segmente

- Die angeforderte `CAFrameRateRange` wird als Metadatum gespeichert, aber nicht als aktiver Takt gewertet.
- Der aktive Takt entsteht aus den tatsächlichen Display-Link-Intervallen.
- Bestätigte Wechsel 120 zu 80, 80 zu 60 oder zurück erzeugen neue Segmente.
- Wechsel von Low Power Mode oder Thermal State erzeugen ebenfalls ein neues Segment.
- Jedes auswertbare Segment enthält mindestens 120 Frames.
- Pro Segment gilt Renderzeit p99 strikt kleiner als 8,33 ms bei 120 Hz, 12,5 ms bei 80 Hz und 16,67 ms bei 60 Hz.
- Ein Run mit unklassifizierbaren, verlorenen oder einem falschen Segment zugeordneten Frames bleibt rot, bis die Ursache geklärt ist.

## Onset-Ermittlung

### Bild

`physicalVisualContact` ist der erste Kameraframe mit weißem Messkeil und visuell geschlossenem Objektkontakt. Die Framezeit ergibt sich aus den gemessenen Frame-Timestamps. Bei nominell 240 fps beträgt die Quantisierung etwa 4,17 ms.

### Audio

`physicalAudioOnset` ist der erste Sample-Block des akustischen Mikrofons, der die im Audio-only-Lauf definierte Rausch- und Template-Schwelle überschreitet. Der Wert kommt aus dem Recorder, nicht aus `AVAudioEngine.lastRenderTime`.

### Haptik

`physicalHapticOnset` ist der erste Sample-Block des Kontaktmikrofons, der die im Haptic-only-Lauf definierte Rausch- und Template-Schwelle überschreitet. Audioübersprechen wird mit beiden Kalibrierläufen geprüft. Bleiben Audio und Haptik auf einem Kanal nicht trennbar, ist die Sensorplatzierung ungültig.

Jeder automatisch erkannte Onset wird in einer Kontaktansicht mit Video und beiden Waveforms manuell bestätigt. Die Person, die bestätigt, sieht die App-Scheduling-Timestamps nicht.

## Auswertung

Für jedes Ereignis:

```text
audioBildMs  = abs(audioOnset  - visualContact)
haptikBildMs = abs(hapticOnset - visualContact)
```

p95 ist der Nearest-Rank-Wert ohne Ausreißerbereinigung. Der mitgelieferte Swift-Evaluator setzt genau diese Regel um.

Freigabe pro Messzelle:

- `audioBildMs p95 <= 16,7 ms`
- `haptikBildMs p95 <= 20 ms`
- mindestens 30 vollständige Ereignisse
- höchstens ein verworfenes Ereignis pro 30er-Lauf
- alle Refresh-Rate-Segmente bestehen ihr jeweiliges p99-Rendering-Gate

Die 240-fps-Quantisierung wird nicht vom Ergebnis abgezogen. Das Gate enthält diese Messunsicherheit bereits und bleibt dadurch konservativ.

## Gerätematrix

Mindestens:

- ein unterstütztes 60-Hz-iPhone,
- ein unterstütztes ProMotion-iPhone mit adaptiver Bildrate,
- das älteste offiziell unterstützte iPhone.

Jedes Gerät wird mit Built-in-Speaker, Standard und Reduced Motion geprüft. Bluetooth, AirPlay und Kopfhörer sind getrennte Routen mit eigener Latenzcharakteristik und dürfen nicht mit Built-in-Speaker-Daten vermischt werden.

## Abbruchkriterien

Ein Lauf ist ungültig bei:

- Kamera-Drops oder variabler Bildrate ohne verwertbare Frame-Timestamps,
- Audio-Recorder-Dropout,
- verrutschtem Kontaktmikrofon,
- nicht trennbarem Audio-Haptik-Übersprechen,
- Audio-Route-Wechsel, Haptic-Engine-Reset oder App-Unterbrechung ohne neue Run-ID,
- thermischem Zustandswechsel zu `serious` oder `critical` während des Laufs,
- einem DEBUG-Messkeil, der nicht mit dem sichtbaren Kontaktframe übereinstimmt.

Ungültige Läufe werden vollständig wiederholt und bleiben im Laborlog sichtbar.
