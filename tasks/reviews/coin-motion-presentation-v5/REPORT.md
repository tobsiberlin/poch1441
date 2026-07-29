# Coin Motion Presentation V5 - Physically Calibrated Choreography

Datum: 20. Juli 2026  
Zielplattform: iOS 17+  
Gesamturteil: **RED - nicht integrieren**

## Kurzurteil

Der isolierte Spike implementiert einen klar benannten, deterministischen
Choreografieansatz statt eines weiteren Kontaktsolvers. Er hat jedoch keinen
belastbaren visuellen Runtime-Beleg erzeugt. Der erste Simulatorlauf zeigte nur
einen schwarzen Fallback, weil die Rasterressourcen nicht in das App-Bundle
kopiert worden waren. Die Paketierung wurde anschließend korrigiert und der
native Build wurde erfolgreich, aber auf Anweisung des Leads wurde keine neue
Ausführung begonnen. Damit ist nicht belegt, dass V5 die aktuell beanstandete
2D-Produktionsanimation in Originalgröße visuell übertrifft.

## Was gebaut wurde

- Native Swift-6-/UIKit-/SwiftUI-Test-App mit Deployment Target iOS 17.
- Vier explizite Zustände in `CoinMotionPlan`:
  1. `ballisticFlight`: analytische Gravitation, stetige Geschwindigkeit und
     Quaternion-Integration.
  2. `firstContact`: normaler und tangentialer Kontaktimpuls mit Restitution,
     Reibungsgrenze, Masse und Trägheit.
  3. `afterrun`: ein Folgekontakt, ein kleiner zweiter Kontakt und linearer
     Coulomb-Nachlauf.
  4. `rest`: aus dem Reibungsverlauf erreichter Ruhezustand.
- Zielpunkt wird vor dem Start deterministisch innerhalb der 12,5-mm-Safe-Zone
  der Mulde gewählt. Der Startpunkt wird aus der gesamten analytischen
  Weglänge zurückgerechnet. Es gibt keine nachträgliche Slot-Animation und
  keinen Ziel-Crossfade.
- Reale 1-Cent-Abmessungen im Modell: Radius 8,125 mm, Dicke 1,67 mm,
  Masse 2,30 g.
- Aktuelle Projektquellen wurden nur lesend übernommen:
  `world-master-snackbox-v3-clean-mug.png` sowie `TravelCent0...5`.
- Der Renderer besitzt eine getrennte, bodengebundene Schattenprojektion; der
  Schatten hängt nicht an der angehobenen Münze.
- Geplante Belegpipeline für `390x844`, `402x874` und `667x375`, ungeschnittene
  60-Hz-Sequenzen, Kontaktcrops, zehn Seeds und Reduced Motion ist im Code
  vorhanden, wurde aber nicht erfolgreich ausgeführt.

## Verifikation

| Gate | Ergebnis | Beleg |
|---|---|---|
| iOS-17-/Swift-6-Build | **GREEN** | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build`, Exit 0 nach korrigierter Ressourcen-Paketierung |
| Ressourcen im App-Bundle | **GREEN (statisch)** | `world-master.png` und `travel-cent-0...5.png` lagen nach dem Build im `.app`-Bundle |
| Modelltests | **RED / nicht aktuell** | Letzter vollständig ausgewerteter Lauf: 5/7 bestanden. Danach Kontaktimpuls korrigiert, aber gemäß Stop-Anweisung nicht erneut getestet |
| Vollständiger Runtime-Render | **RED** | Erster Lauf war schwarz; nach Paketierungsfix keine neue Ausführung |
| Originalgrößen-Contact-Sheet | **RED** | Nicht vorhanden |
| Ungeschnittene Sequenzen je Viewport | **RED** | Nicht vorhanden |
| Zehn unterschiedliche Seeds | **RED** | Exportcode vorhanden, kein Runtime-Artefakt |
| 60-Hz-Wallclock | **RED** | Kein abgeschlossener `wallclock.json`-Beleg |
| Kein Schweben/Clipping/Doppelbild | **RED / unbelegt** | Statische Invarianten im Code reichen für eine visuelle Freigabe nicht aus |
| Geschwindigkeits- und Energieabfall | **RED / unbelegt** | Modellwerte nicht durch den finalen, erneut ausgeführten Testlauf bestätigt |
| Ruhe innerhalb der Safe-Zone | **RED / unbelegt** | Konstruktion und Tests existieren, finaler Testlauf fehlt |
| Reduced Motion ohne unsichtbare Wartezeit | **RED / unbelegt** | Sofortzustand implementiert, aber kein finaler Runtime-Beleg |
| Übertrifft aktuellen `ImpactFlight` sichtbar | **RED** | Keine belastbare Originalgrößen-Gegenüberstellung |

## Animationsreview

| Before | After | Why |
|---|---|---|
| Produktionspfad: reine 2D-Translation, tokengebundener Schatten und direkter Zielzustandswechsel | V5-Modell: ballistischer Flug, unabhängiger Bodenschatten, impulsbasierter Kontakt und kontinuierlicher Nachlauf | Die räumliche Ursache ist jetzt im Modell vorhanden; ohne Runtime-Beleg ist die Wirkung trotzdem nicht freigegeben |
| Schwarzer erster Simulatorlauf ohne Münz- oder Brettdarstellung | Erneuter Originalgrößen-Runtime-Beleg erforderlich | Ein technisch vorhandener Renderer kann Gewicht, Kontakt und Richtung nicht beweisen, wenn seine Ressourcen nicht sichtbar sind |
| Kein finaler 60-Hz- und Zehn-Seed-Beleg | Freigabe erst nach vollständigem, ungeschnittenem Export | Einzelne Keyframes würden Rhythmus, Wiederholungsmüdigkeit, Frame-Pacing und Kontaktfehler verschleiern |
| Kontaktmodell nach letztem Testlauf verändert | Gesamte Modelltests erneut ausführen | Der letzte 5/7-Lauf darf nach einer Physikänderung nicht als teilweise Freigabe umgedeutet werden |

### Feel-breaking regressions

- Der schwarze Runtime-Ausfall ist ein vollständiger visueller Blocker.
- Ohne Sequenz kann nicht ausgeschlossen werden, dass die analytische Münze
  trotz korrekter Formeln klein, leicht, hektisch oder vom Hintergrund gelöst
  wirkt.

### Origin, physicality & cohesion

- Die beabsichtigte Schattenentkopplung und die vier Segmente sind gegenüber
  `ImpactFlight` konzeptionell richtig.
- Die zusätzliche algorithmische Frontlippen-Occlusion wurde nicht gegen die
  tatsächliche Muldenkante in Originalgröße geprüft. Auch deshalb ist keine
  Freigabe möglich.

### Accessibility

- Reduced Motion setzt den semantischen Endzustand im initiierenden Frame und
  vermeidet absichtlich eine unsichtbare Flugdauer. Die Runtime-Wirkung blieb
  ungeprüft.

## Entscheidung

**Block / RED.** Kein App-Code wurde geändert, nichts wurde integriert und es
gibt keinen Commit. Der Spike darf erst wieder bewertet werden, wenn derselbe
Stand ohne weitere gestalterische Änderung einen vollständigen nativen Lauf,
Originalgrößen-Sheets, ungeschnittene Sequenzen, zehn Seeds und 60-Hz-Metriken
liefert. Bis dahin ist V5 eine unbewiesene Architekturprobe, keine
Produktionskandidatin.

## V5.1 - Finaler unveränderter Testlauf

Datum: 20. Juli 2026, 06:24 Uhr  
Urteil: **RED - Export gemäß Abbruchvertrag nicht gestartet**

Der Lead gab genau einen finalen Testlauf des unveränderten Build-Fix- und
Modellstands frei. Ausgeführt wurde:

```text
xcodebuild \
  -project CoinMotionPresentationV5.xcodeproj \
  -scheme CoinMotionPresentationV5 \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D1923D48-6E8D-4157-B703-8B05CC334D08' \
  -derivedDataPath .derived \
  test
```

Ergebnis: Exit 65, sieben Tests, fünf bestanden, zwei Testfälle mit insgesamt
101 fehlgeschlagenen Assertions.

| Gate | Ergebnis | Messwert |
|---|---|---|
| Energie sinkt beim ersten Kontakt | **RED** | 100 von 100 geprüften Seeds verletzt; beispielhaft Seed 7: `0,057529 J` nach Kontakt gegenüber `0,009317 J` davor |
| Ruhe wird kontinuierlich erreicht | **RED** | `0,007153 rad/s` unmittelbar vor Ruhe, Grenzwert `< 0,002 rad/s` |
| Positionskontinuität am Erstkontakt | GREEN | Test bestanden |
| Kein Floor-Clipping in den gesampelten Sequenzen | GREEN | Test bestanden |
| Quaternion bleibt normiert | GREEN | Test bestanden |
| Reduced Motion setzt sofort den Ruhezustand | GREEN | Test bestanden |
| Zehn Seed-Endpunkte bleiben in der Safe-Zone | GREEN | Test bestanden |

Der massive Energiegewinn widerlegt den aktuellen impulsbasierten
Manifold-Support. Deshalb wurde der nachgelagerte native Export nicht gestartet;
es existiert weiterhin kein 402-x-874-Gesamtsheet. Es wurden weder Modell noch
Design verändert oder nachgetunt. V5.1 bestätigt das bestehende
**Block-/RED-Urteil**.
