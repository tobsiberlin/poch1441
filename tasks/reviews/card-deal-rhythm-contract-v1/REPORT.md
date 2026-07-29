# Card Deal Rhythm Contract V1

## Ergebnis

Der isolierte Scheduler-Vertrag ist implementiert und testbar. Er trennt den gewünschten Deal-Puls von der physikalischen Überlappungsgrenze:

```text
actualStart(i) = max(rhythmTarget(i), restWindowStart(i - 2))
```

`restWindowStart` beginnt erst nach Reise, Kontakt und Settle. Damit zählt das sichtbare Ausschwingen vollständig als Bewegung. Aktive Intervalle sind halb offen: `[actualStart, restWindowStart)`. Bei korrekten Dauern können deshalb zu keinem kontinuierlichen Zeitpunkt und auf keinem untersuchten Display-Sampling mehr als zwei Karten aktiv sein.

Keine Rendering- oder App-Datei wurde verändert.

## Rhythmusbegründung

Eine gleichmäßige Metronomfolge liest sich sofort als Schleife. V1 verwendet deshalb einen kleinen dramatischen Bogen:

1. **Anspannung**: Zwei klar lesbare erste Impulse etablieren Hand und Material.
2. **Beschleunigung**: Die Pulsabstände kontrahieren monoton bis zu einer Untergrenze.
3. **Kurze Erholung**: Der vorletzte Impuls öffnet einmal Luft, ohne die Sequenz anzuhalten.
4. **Release**: Der letzte Impuls schließt schneller und eindeutig ab.

Standardmodus:

- Anspannung ungefähr 312 bis 320 ms.
- Beschleunigung bis mindestens 242 ms.
- Erholung ungefähr 300 bis 308 ms.
- Release ungefähr 223 bis 229 ms.

Reduced Motion hat keinen unsichtbaren Standard-Flug als Wartezeit:

- Anspannung ungefähr 80,5 bis 83,5 ms.
- Beschleunigung bis mindestens 70 ms.
- kurze Erholung ungefähr 86,5 bis 89,5 ms.
- Release ungefähr 67 bis 69 ms.

Diese Werte sind Wunschpulse. Wenn eine zwei Karten zurückliegende Karte noch im Settle ist, gewinnt immer das physikalische Rest-Gate. Rhythmus darf die Physik nicht brechen.

## Kontrollierte Variation

- Seeded `SplitMix64` macht jeden Run exakt reproduzierbar.
- Verschiedene öffentliche Rundenseeds verändern Pulsfeinheit, Bahnklasse, Kontaktklasse und Gestenvariation.
- Kartenidentität ist kein Eingang des Profils.
- Drei aufeinanderfolgende identische Bahnklassen sind strukturell ausgeschlossen.
- Drei aufeinanderfolgende identische Kontaktklassen sind strukturell ausgeschlossen.
- Zwei direkt benachbarte Karten dürfen nicht die vollständige Kombination aus Bahn, Kontakt und Gestenvariation wiederholen.

Das ist deterministisch, aber nicht perzeptuell identisch. Für Wiederholungen sollte der Produktionsseed aus einer öffentlichen Präsentationsgeneration oder Rundennummer entstehen, nie aus verdeckten Kartenwerten.

## Adversariale Dauerbereiche

Die Tests mischen kurze und lange Bewegungsphasen absichtlich ungünstig:

| Modus | Reise | Kontakt | Settle | Gesamtbewegung |
| --- | --- | --- | --- | --- |
| Standard | 280 bis 500 ms | 60 bis 120 ms | 100 bis 180 ms | 440 bis 800 ms |
| Reduced Motion | 85 bis 140 ms | 40 bis 80 ms | 55 bis 100 ms | 180 bis 320 ms |

Vier gegeneinander verschobene Min-/Max-Muster prüfen, dass ein kurzer Folgedeal keinen langen Vorgänger überholt und keine dritte aktive Karte erzeugt.

## Tests

Der Vertrag wurde mit Swift und Warnings-as-errors kompiliert. Der Testlauf deckt ab:

- dramaturgische Phasen und monotone Beschleunigung,
- exakte Wiederholung desselben Seeds und Abweichung anderer Seeds,
- 1.024 Seeds in Standard und Reduced Motion auf Dreifachwiederholungen,
- 256 unterschiedliche vollständige Standard-Choreografien,
- exakte Startgleichung und Settle als Bewegung,
- 512 Seeds, zwei Modi, vier adversariale Dauermuster und 60/80/120-Hz-Sampling,
- lückenlose Reduced-Motion-Sequenz,
- ungültige Dauerlisten.

```text
swiftc -warnings-as-errors -parse-as-library DealRhythmContract.swift DealRhythmContractTests.swift
DealRhythmContractTests: PASS
```

`git diff --check` ist sauber.

## Kleinste Integrationsnaht

Die derzeitige Phase-1-Präsentation startet Karten in `GameState.dealLoop()` über einen festen `Tokens.p1DealStep` und pollt auf höchstens zwei noch nicht gelandete Karten (`App/GameState.swift:1264-1273`). `FlyingBack` berechnet die Flugdauer erst in der View aus der Distanz (`App/DealOverlay.swift:541-555`). Das ist zu spät für einen physisch informierten Rhythmusplan.

Der kleinste belastbare Schnitt ist ein reiner Präsentationsadapter zwischen diesen beiden Stellen:

1. Die bestehende Distanz-Dauer-Berechnung wird als reine, gemeinsam nutzbare Funktion verfügbar gemacht.
2. Der Adapter erzeugt vor dem Deal ein `DealRhythmProfile` und die `DealMotionDurations` für die öffentliche Reihenfolge.
3. `DealRhythmScheduler` liefert absolute Starts und die Bahn-/Kontaktklassen.
4. `dealLoop()` wartet auf die absoluten Starts statt jeweils erneut auf einen festen Delay.
5. Der spätere Bewegungscontroller meldet getrennt Kontakt und `restWindowStart` nach abgeschlossenem Settle. Ein später als geplant beobachteter Rest verschiebt die nächste betroffene Karte weiter nach hinten.
6. `FlyingBack` oder sein Nachfolger konsumiert nur den Plan. PochKit, Kartenreihenfolge und Regeln bleiben unverändert.

Der erste Integrationsversuch sollte nur acht Karten in einem DEBUG-Harness planen. Erst wenn Startgleichung, maximal zwei aktive Karten und Rest-Callback im echten Wallclock-Lauf stimmen, wird die bestehende Deal-Präsentation ersetzt.

## Offene Punkte

- Die Rhythmuswerte sind ein belastbarer Startvertrag, noch kein ästhetischer Hardware-Pass.
- Bahn- und Kontaktklassen brauchen später perspektivisch korrekte Track-A- und Track-B-Parameter.
- Der Rest-Callback muss aus dem tatsächlichen Physik-/Renderpfad kommen, nicht aus einer SwiftUI-Completion.
- Audio und Haptik müssen am Kontakt über den separaten Motion-Sync-Vertrag angebunden werden.
- Bei einem Abbruch müssen noch nicht gestartete Profileinträge verworfen werden; bereits kontaktierte Karten dürfen keinen zweiten Cue erzeugen.

## Entscheidung

**Technischer Vertrag: PASS. Produktionsintegration: noch nicht freigegeben.**

Der Scheduler löst Rhythmus, Zwei-Karten-Gate, Settle-Zählung und deterministische Nichtwiederholung ohne Rendering. Die physische und visuelle Qualität bleibt ein nachgelagertes Hardware- und Perspektivgate.
