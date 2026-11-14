# Native Card Motion V3 - Abschluss

**Stand:** 2026-07-20 06:02 CEST  
**Technischer Vertrag:** **RED**  
**Ästhetischer Vertrag:** **RED**  
**App-Integration:** **BLOCKIERT**

V3 ist ein isolierter iOS-17-Prototyp. Es wurde nichts in die App integriert.
Der Prototyp behebt mehrere strukturelle Fehler von V2, erreicht aber sichtbar
nicht den geforderten Qualitätsstandard. Insbesondere liest die Bewegung noch
als saubere UI-Trajektorie statt als glaubwürdige physische Karte.

## Part 1 - Findings

| Before | After | Why |
| --- | --- | --- |
| Eine öffentliche Vorderseite kehrt bis zum Hand-Slot zurück; danach rendert `handCards` ausschließlich `W2CardBack` (`Sources/CardMotionStage.swift:112-123`). | Derselbe Karten-Datensatz einschließlich Surface muss nach Return in den ruhenden Hand-Layer übergehen. | Im letzten Wallclock-Frame springt die Karte ohne Drehung von Herz-Ass auf Rückseite. Das ist ein sichtbarer Zustands-Teleport und ein harter Blocker. |
| Der Schatten ist mathematisch eine projizierte Vierpunkt-Kartenkontur, wird aber als Schwarz mit nur `0.17...0.30` Opazität auf fast schwarzem Tisch gerendert (`Sources/CardMotionStage.swift:147-152`). | Licht-/Materialkontrast gegen den realen Tisch kalibrieren und in engen Kontakt-Crops auf wahrnehmbare Auflage prüfen. | Im Echtzeit-Sheet ist der Schatten praktisch nicht lesbar. Die Karte wirkt dadurch weiterhin freischwebend, obwohl die Geometrie technisch besser ist. |
| Erstkontakt und 86-ms-Settle existieren im Modell, der volle Contact-Sheet zeigt jedoch nahezu keine erkennbare Kompression, Restitution oder Rotation. | Settle aus der tatsächlich sichtbaren Kartenkante und Kontaktgeschwindigkeit ableiten und den Beat bei 60/120 Hz in einem engen Crop freigeben. | Ein numerischer Beat ohne wahrnehmbare Formänderung liefert weder Gewicht noch taktiles Feedback. |
| Zehn Deals starten im Abstand von 135 ms (`Sources/CardMotionController.swift:37-41`) und erreichen fünf parallele Flüge. | Deal-Rhythmus an Lesbarkeit und Tischkapazität koppeln; maximalen sichtbaren Overlap erst nach Motion-Review festlegen. | Das Sheet zeigt eine mechanische Karten-Förderkette. Die identischen Flugbahnen verstärken das synthetische Gefühl. |
| Alle Deals verwenden dieselbe Hermite-Grundbahn und variieren nur den End-Offset (`Sources/CardMotionModel.swift:495-501`). | Kleine deterministische Unterschiede in Release-Winkel, Yaw, Flugzeit und Settle aus Slot/Seed ableiten, ohne Zufallszittern. | Wiederholung macht die Künstlichkeit sofort sichtbar; zehn Karten lesen wie geklonte Layer. |
| Pitch wird physikalisch aus Bewegungsrichtung und vertikaler Geschwindigkeit berechnet, bleibt in der Vollansicht jedoch kaum erkennbar (`Sources/CardMotionStage.swift:164-173`). | Kamera-, Karten- und Lichtwinkel gemeinsam kalibrieren, bis Pitch ohne Größen-Trick räumlich lesbar ist. | Korrekte Parameter allein genügen nicht, wenn das resultierende Bild weiterhin flach aussieht. |
| Der technische Testlauf war vor dem finalen Evidence-Scheduler 13/13 grün; der finale Build ist grün, aber die komplette Testsuite wurde nach der letzten Evidence-Änderung nicht erneut ausgeführt. | Vor einer erneuten Freigabe alle Tests gegen exakt den finalen Stand ausführen und einen physischen iOS-17-Performancebeleg ergänzen. | Ein früher grüner Lauf darf nicht als Freigabe für später geänderten Code ausgegeben werden. |

## Part 2 - Verdict

### Feel-breaking regressions

- Der Surface-Wechsel am Return-Ende ist ein klarer Teleport.
- Die kaum sichtbare Bodenprojektion lässt die Karte schweben.
- Der Erstkontakt besitzt im Beleg keine überzeugende Masse oder Restitution.
- Der Zehn-Karten-Deal liest als mechanische Conveyor-Animation.

### Performance

- Der finale Simulator-Build ist grün.
- Es gibt keinen belastbaren physischen iOS-17-Frame-Time-Beleg.
- Die Evidence-Pipeline speichert echte Wallclock-Snapshots und rendert sie
  danach. Dadurch beeinflusst PNG-Kompression die Controller-Zeit nicht.

### Interruptibility & timing

- Play wird in allen drei Viewports exakt bei Controller-Progress `0.58`
  abgebrochen.
- Return übernimmt Position, horizontale Geschwindigkeit, Höhe und vertikale
  Geschwindigkeit am Abbruch (`Sources/CardMotionModel.swift:452-487`).
- Die Retarget-Dauer ist distanz- und geschwindigkeitsabhängig.
- Der sichtbare Surface-Teleport am Ende verletzt trotzdem die durchgängige
  Zustandskontinuität.

### Origin, physicality & cohesion

- Schatten und Karte sind echte Stage-Siblings; alle Schatten liegen unter
  allen ruhenden Karten, alle Flugkarten darüber (`Sources/CardMotionStage.swift:31-47`).
- Die Schattenkontur wird aus vier rotierten und gepitchten Kartenecken sowie
  einer festen Lichtachse projiziert.
- Die visuelle Wirkung bleibt deutlich hinter dem mathematischen Vertrag
  zurück. Der Prototyp darf deshalb nicht integriert werden.

### Accessibility

- Reduced Motion setzt aktive Flüge ohne verzögertes Ease-in direkt in den
  Zielzustand (`Sources/CardMotionModel.swift:505-517`).
- Dieser Vertrag war im früheren 13/13-Testlauf grün, wurde nach dem finalen
  Evidence-Scheduler jedoch nicht erneut ausgeführt.

## Belege

- Ungeschnittener Wallclock-Play/Cancel/Return:
  `Evidence/realtime-interrupted-play-contact-sheet-402x874.png`
- Derselbe Lauf als Video:
  `Evidence/wallclock-play-cancel-return-402x874.mp4`
- Erstkontakt und Settle:
  `Evidence/first-contact-settle-sheet-402x874.png`
- Zehn echte Deals, maximal fünf gleichzeitig:
  `Evidence/realtime-10-deal-overlap-sheet-402x874.png`
- Maschinenlesbarer Zeitvertrag: `Evidence/manifest.json`

Manifest:

- `syntheticProgressUsed = false`
- 153 echte Controller-Snapshots
- Abbruch `0.58` in 390x844, 402x874 und 667x375
- vollständige Szenen exakt 390x844, 402x874 und 667x375
- Erstkontakt-Settle 86 ms
- maximaler Deal-Overlap 5
- echte W2-/V10-Assets

## Entscheidung

**Block.** Die Architektur ist gegenüber V2 substanziell ehrlicher, aber der
sichtbare Beleg besteht den Qualitätsmaßstab nicht. Kein App-Merge, kein
visuelles GREEN und keine weitere Iteration ohne Lead-Sichtprüfung des
ungeschnittenen Sheets.
