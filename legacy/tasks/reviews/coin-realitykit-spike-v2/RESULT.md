# RealityKit Kontaktkalibrierung V2 - RED

## Urteil

**RED. Die Überschreitung ist kein fixer Convex-Hull-Margin und keine bloße
Anzeigeabweichung. Sie ist eine reale, transiente Solverüberlappung.**

RealityKits Eventmaximum stimmt in allen fünf Fällen mit der unabhängig aus
Transform und Nominalgeometrie beobachteten Maximalüberlappung überein. Der
größte Unterschied beider Messwege beträgt nur `0,0062 mm`. Im Ruhekontakt
fallen Eventwert und geometrische Überlappung dagegen praktisch auf null.

Maschinenlesbarer Bericht: `runtime-result.json`  
Unabhängiger Wiederholungslauf: `runtime-result-run2.json`  
Visueller Endlagenbeleg: `runtime-final.png`

## Messmatrix

Alle Angaben außer dem Ruhefenster sind Millimeter. `End-Gap` ist
vorzeichenbehaftet: positiv bedeutet Abstand, negativ Überlappung.

| Fall | Event max | Transform-Überlappung max | Event in Ruhe | End-Gap | Ergebnis |
| --- | ---: | ---: | ---: | ---: | --- |
| coin-convex12-face | `0,148981` | `0,152715` | `0,001598` | `-0,000224` | **FAIL** |
| coin-convex48-face | `0,026268` | `0,026174` | `0,000250` | `+0,000030` | PASS |
| coin-convex12-tilt3 | `0,359436` | `0,365630` | `0,000027` | `+0,000089` | **FAIL** |
| coin-convex48-tilt3 | `0,364431` | `0,365272` | `0,000102` | `-0,003755` | **FAIL** |
| box-control-face | `0,483032` | `0,483029` | `0,000527` | `-0,001475` | **FAIL** |

Alle fünf Fälle erreichten ohne Velocity-Zeroing mindestens `0,750 s` Ruhe.
Der Report bleibt RED, sobald entweder Eventmaximum oder maximale
Transform-Geometrieüberlappung das unveränderte `0,150-mm`-Limit verletzt.

## Was die Hypothesenprüfung zeigt

### Kein persistenter Collision-Margin

Die finalen signed gaps liegen zwischen `-0,003755 mm` und `+0,000089 mm`.
Die Eventwerte im Ruhekontakt liegen zwischen `0,000027 mm` und `0,001598 mm`.
Ein persistenter Margin im Bereich `0,98-1,62 mm` ist damit ausgeschlossen.

### Nicht auf Convex Hull oder Segmentzahl beschränkt

- Der Box-Kontrollkörper überschreitet das Gate mit `0,483 mm`, obwohl er keine
  Münz-Convex-Hull verwendet.
- Die geneigten 12- und 48-Segment-Münzen liegen mit `0,359 mm` und `0,364 mm`
  nahezu gleichauf.
- 48 Segmente verbessern den kontrollierten flachen Kontakt, lösen aber den
  geneigten Kontakt nicht.

### Transiente Solverüberlappung bestätigt

Beim ersten Aufprallschritt wird die negative Transform-Geometriedistanz direkt
beobachtet. Im folgenden Contact Event meldet RealityKit nahezu denselben Betrag
als `penetrationDistance`; danach korrigiert der Solver den Körper auf einen
nahezu überlappungsfreien Ruhekontakt. Das Event ist deshalb nicht nur eine
willkürliche Anzeigezahl. Es beschreibt die transiente Überlappung des
diskreten Kontaktschritts.

Die V1-Werte von `0,98-1,62 mm` sind damit plausibel als stärkere transiente
Überlappungen aus den dynamischeren Rotations-, Lippen- und Aufprallzuständen,
nicht als konstanter Shape-Margin. Das ist eine Inferenz aus beiden Spikes.

## Reproduzierbarkeit

Ausgeführt auf:

```text
Xcode 26.2 (17C52)
iPhone 17 Pro Simulator
UDID D1923D48-6E8D-4157-B703-8B05CC334D08
iOS 26.2
```

Build:

```sh
cd tasks/reviews/coin-realitykit-spike-v2
xcodegen generate --spec project.yml
xcodebuild \
  -project CoinRealityKitCalibration.xcodeproj \
  -scheme CoinRealityKitCalibration \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D1923D48-6E8D-4157-B703-8B05CC334D08' \
  -derivedDataPath .derived \
  build
```

Debug- und Release-Build: `** BUILD SUCCEEDED **`. Der dokumentierte Lauf nutzt
den Debug-Build. Der Wiederholungslauf reproduzierte sämtliche Eventmaxima und
transformbasierten Maximalüberlappungen exakt bis auf den im JSON gespeicherten
Float-Wert. Das Simulator-Frame-Pacing lag im finalen Lauf bei
`p95 = 16,716 ms` und ist kein Ersatz für einen Gerätetest.

## Empfehlung

RealityKit für die maßkritische Münzphysik weiterhin nicht freigeben. Der
48-Segment-Hull besteht nur den idealen flachen Kontrollfall; schon 3° Neigung
überschreitet das Gate um mehr als Faktor `2,4`. Eine Segmentierungswahl kann
den Vertrag daher nicht robust erfüllen.

Wenn `0,150 mm` als Maximum auch während des Aufpralls bindend bleibt, braucht
die Produktlösung entweder eine Physik mit kontrollierbarem Zeitschritt und
Solverparametern oder eine explizite Begrenzung der zulässigen
Aufprallgeschwindigkeiten und Orientierungen. Letzteres wäre eine Änderung des
Spielgefühlvertrags und darf nicht als Kalibrierung dieses Gates versteckt
werden.
