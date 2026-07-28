# Motion-Sync-Messvertrag

## Ergebnis

Der Messvertrag ist als isolierter, kompilierbarer Prototyp umgesetzt. Er definiert ein gemeinsames Ereignismodell, trennt Software-Scheduling strikt von physischer Ausgabe und macht die geforderten p95-Grenzen sowie refresh-rate-aware p99-Rendering-Gates automatisiert prüfbar.

Eine Produktionsintegration wurde absichtlich nicht vorgenommen.

## Artefakte

- `MotionSyncContract.swift`: Codable-Ereignisse, Clock-Domains, Run-Metadaten, Haptik-Clock-Brücke, tatsächliche Refresh-Rate-Erkennung, Frame-Segmente sowie p95-/p99-Evaluator.
- `MotionSyncContractTests.swift`: JSON-Roundtrip, Zeitbrücke, Refresh-Segment-, Rendering-Grenzwert-, Regressions-, Duplikat-, Telemetrie- und Reduced-Motion-Tests.
- `INTEGRATION_CONTRACT.md`: spätere Adapter für Simulation, Display, AVAudioEngine, Core Haptics, Signposts, Abbruch und Reduced Motion.
- `HARDWARE_PROTOCOL.md`: reproduzierbarer 240-fps-, Akustik- und Kontaktmikrofon-Aufbau.

## Aktueller App-Befund

Der vorhandene `ImpactFlight` meldet den Impakt über das Ende einer SwiftUI-Animation mit `completionCriteria: .logicallyComplete` und ruft danach `impactOnce()` auf (`App/ImpactFlight.swift:150-169`). Das ist ein brauchbarer genau-einmal-Transaktionsschutz, aber kein framegenauer physischer Kontaktzeitpunkt. Bild, Audio und Haptik können damit weder vorab auf eine gemeinsame Host-Time geplant noch am echten Ausgabegerät nachgewiesen werden.

Die vorhandenen globalen Dauern für Münzen und Karten (`App/DesignTokens.swift:206-214`) beschreiben Reisezeit, aber noch keinen gemeinsamen Kontaktclock. Die neue Messschicht darf diese Werte beobachten, nicht als parallele Regeln duplizieren.

## Umsetzbarkeit

Technisch umsetzbar, mit mittlerem Integrationsrisiko:

1. Niedriges Risiko: Ereignis- und JSONL-Modell, Signposts, Run-Metadaten und Offline-Auswertung.
2. Mittleres Risiko: Render-Sampling auf `CADisplayLink` oder dem späteren SpriteKit-/Metal-Renderpfad und AVAudioTime-Host-Scheduling.
3. Mittleres bis hohes Risiko: stabile Host-Time-Brücke für Core Haptics über Engine-Resets sowie echte physische Kalibrierung über mehrere Geräte.
4. Mittleres Risiko: GPU-Renderdauer. Wenn SpriteKit den Command Buffer verbirgt, braucht das Messharness `SKRenderer` mit einem kontrollierten Metal-Renderpfad.

Die entscheidende Architekturänderung ist klein, aber grundlegend: Kontakt ist künftig ein vorhersehbarer Zeitwert der Simulation und nicht der Completion-Callback einer Ansicht. Erst danach können Audio und Haptik mit Vorlauf geplant werden.

## Freigabewerte

- Audio zu Bild: absolute Abweichung p95 höchstens 16,7 ms.
- Haptik zu Bild: absolute Abweichung p95 höchstens 20 ms.
- Mindestens 30 vollständige Ereignisse je Gerät, Objektart und Motion-Variante.
- Keine Ausreißerbereinigung.
- Software-Timestamps allein können das Gate nicht bestehen.
- 120 Hz: Renderzeit p99 strikt kleiner als 8,33 ms.
- 80 Hz: Renderzeit p99 strikt kleiner als 12,5 ms.
- 60 Hz: Renderzeit p99 strikt kleiner als 16,67 ms.
- Der aktive Takt stammt aus tatsächlichen CADisplayLink-Intervallen. Jeder bestätigte Rate-Wechsel wird als eigenes Segment bewertet.

## Offene Hardwareabhängigkeiten

- Reales 60-Hz- und ProMotion-iPhone sowie ältestes unterstütztes Modell.
- Zweites iPhone mit original auslesbarem 240-fps-Slo-Mo-Asset.
- 96-kHz-Zweikanalrecorder für akustisches und Kontaktmikrofon.
- Wiederholbare Kontaktmikrofon-Halterung und sicht-/hörbarer Sync-Slate.
- Finale Festlegung unterstützter Audio-Routen. Bluetooth kann nicht mit Built-in-Speaker-Limits gleichgesetzt werden.
- Messung des Haptic-Engine-Verhaltens nach App-Resume, Audio-Route-Wechsel und Engine-Reset.
- Prüfung, ob die gewählte Rendering-Technik einen verlässlichen DEBUG-Messkeil im echten Kontaktframe erlaubt.
- Instrumentierbarer GPU-Abschlusszeitpunkt für die Renderdauer.
- Reale Runs mit Low Power Mode an/aus sowie nominalem und fairen Thermal State. Serious/critical werden als ungültiger Belastungszustand separat untersucht.

## Verifikation

Der isolierte Vertrag wurde mit Swift und aktivierten Warnings-as-errors kompiliert und ausgeführt:

```text
swiftc -warnings-as-errors -parse-as-library MotionSyncContract.swift MotionSyncContractTests.swift
MotionSyncContractTests: PASS
```

`git diff --check` meldet für den Ordner keine Whitespace-Fehler.

## Nicht behauptet

- Kein Nachweis auf echter Hardware liegt vor.
- Keine Aussage, dass die aktuelle Münz- oder Kartenanimation die Grenzwerte erreicht.
- Kein Sound- oder Haptikdesign wurde erstellt.
- Kein Produktionscode wurde verändert.

## Nächster kleinster Falsifikationstest

Eine einzige Münze und eine einzige Karte erhalten in einem DEBUG-Harness einen vorhergesagten Host-Kontakt, einen Rand-Messkeil, einen vorgerenderten Audio-Transient und ein kurzes vorerzeugtes Haptik-Pattern. Je 30 Impakte werden auf einem 60-Hz- und einem ProMotion-iPhone gemessen. Wenn bereits dieser isolierte Pfad die p95-Grenzen nicht hält, wird nicht weiter an Choreografie poliert, sondern zuerst Clock-Brücke, Scheduling-Vorlauf und Render-Sampling korrigiert.
