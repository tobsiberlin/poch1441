# RealityKit Visual Contract V3 - Ergebnis

Datum: 20. Juli 2026  
Runtime: iOS Simulator 26.2  
Urteile: **Technik GREEN**, **automatisiertes Pixel-Gate RED**

## Abgrenzung

Dieser Spike ist ausschließlich ein visueller Vertrag unter `coin-realitykit-visual-v3`. Das frühere physische V2-RED bei einem Grenzwert von 0,150 mm bleibt unverändert und maßgeblich. V3 benennt es weder um noch ersetzt es. Der aktuelle Lauf meldet weiterhin bis zu 1,244 mm transiente RealityKit-Kontaktpenetration.

## Aufbau

- Echte RealityKit-Dynamik mit 48-Segment-Render- und Collision-Mesh
- Echte 3D-Rotation, CCD, geneigte physische Lippe bei -25 Grad
- Identische Weltkamera in allen Läufen: FOV 52 Grad, Position `(0, 0.200, 0.100)`, Ziel `(0, -0.119, -0.360)`
- Native Ausgabegrößen `390x844`, `667x375`, `402x874`, `contentScaleFactor = 1`
- 571 von 571 Displayupdates transform- und pixelprojiziert vermessen
- 134 native Lauf-Frames plus 134 zugehörige 128-x-128-Kontaktcrops
- Sechs vollständige `display-frame-trace.json`-Spuren; Bildgrößenprüfung ohne Abweichung

Die Pixelzahl ist die Distanz der analytischen Kontaktüberlappung nach Projektion durch die tatsächlich aktive RealityKit-Kamera. Sie wird für jedes Displayupdate berechnet. Die fortlaufenden PNGs und Kontaktcrops sind der Renderbeleg; sie sind nicht bloß Endscreens.

## Messwerte

| Viewport | Fall | Displayframes | Sequenz-PNGs | Max. Überlappung | Ruheüberlappung | Max. Projektion | Pixel-Gate |
|---|---|---:|---:|---:|---:|---:|---|
| 390x844 | floor-convex48-tilt3 | 153 | 35 | 0,072 mm | 0,000 mm | 0,088 px | GREEN |
| 390x844 | edge-lip-convex48-78deg | 40 | 10 | 0,383 mm | n/a | 0,501 px | RED |
| 667x375 | floor-convex48-tilt3 | 166 | 36 | 0,072 mm | 0,000 mm | 0,039 px | GREEN |
| 667x375 | edge-lip-convex48-78deg | 42 | 10 | 0,982 mm | n/a | 0,564 px | RED |
| 402x874 | floor-convex48-tilt3 | 135 | 34 | 1,264 mm | 0,000 mm | 1,644 px | RED |
| 402x874 | edge-lip-convex48-78deg | 35 | 9 | 0,982 mm | n/a | 1,314 px | RED |

Die drei Ruhefälle enden bei 0,000 mm analytischer Überlappung und erfüllen damit den Grenzwert von höchstens 0,150 mm. Vier der sechs Lauf-/Viewport-Kombinationen überschreiten jedoch 0,5 projizierte physische Pixel. 390x844 am Lippenkontakt liegt mit 0,5013 px nur knapp, aber eindeutig über dem Gate.

## Technisches Urteil - GREEN

- Alle sechs Läufe hatten physischen Kontakt; alle drei Lippenläufe meldeten echten Lippenkontakt.
- Kein Tunneling beziehungsweise Verlassen des definierten Containments.
- Kein Energiegewinn; gemessener Maximalwert 0,0 Prozent.
- Keine nachträglichen Velocity-Schreibzugriffe, kein Velocity-Zeroing.
- Keine nachträglichen Transform-Schreibzugriffe und keine Transformkorrektur.
- CCD war aktiv.
- Alle erforderlichen Ruhefenster lagen über 0,75 Sekunden; Ruheüberlappung jeweils 0,000 mm.

Dieses GREEN gilt nur für den ausdrücklich definierten V3-Technikteil. Die weiterhin gemeldete transiente Kontaktpenetration ist der Grund, warum das frühere 0,150-mm-Physikurteil RED bleibt.

## Visuelles Urteil

- **Pixelpenetration: RED.** Die konservative Kamera-Projektion überschreitet 0,5 px in vier Läufen. Die Beauty-Crops zeigen keine grobe Durchdringung, liefern aber keinen Grund, den strengeren Messwert zu überstimmen.
- **Silhouette: GREEN.** Die 48-Segment-Kontur wirkt in allen nativen Viewports rund; auch bei der 78-Grad-Rotation bleibt die Kante stabil und ohne sichtbares Polygonflattern.
- **Schattenkontakt: GREEN.** Der Münzschatten sitzt nachvollziehbar auf dem Brett, nähert sich beim Fall und verhindert den Eindruck einer schwebenden Scheibe.
- **Lippe: GREEN.** Neigung, Materialtrennung und Tiefenverdeckung sind klar lesbar. Beim Kontakt verschwindet die Münze räumlich plausibel hinter der Vorderkante.

Gesamt bleibt das visuelle Vertragsurteil **RED**, weil der harte 0,5-Pixel-Grenzwert Vorrang vor den drei qualitativen GREENs hat.

## Belege

- Maschinenlesbares Ergebnis: `artifacts/runtime-result.json`
- Lückenlose Displayframe-Spuren: `artifacts/frames/<viewport>/<fall>/display-frame-trace.json`
- Laufsequenzen und Pixelcrops: `artifacts/frames/<viewport>/<fall>/`
- Je Lauf ein `contact-sheet.png`
- Prüfsummen: `artifacts/SHA256SUMS`

## Verifikation

- `xcodebuild`: erfolgreich mit Swift 6 und iOS-Simulator-SDK 26.2
- Simulatorlauf: sechs von sechs Läufen abgeschlossen
- Trace-Anzahl entspricht pro Lauf exakt `displayFramesEvaluated`
- PNG-Größen: null Abweichungen von den drei Sollgrößen
- 134 Vollframes und 134 Kontaktcrops vorhanden
