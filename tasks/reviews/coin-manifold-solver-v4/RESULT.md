# Persistent-Manifold-Solver v4 - RED

**Ausgeführt:** 20. Juli 2026  
**Plattform:** macOS arm64, Swift 6.2.3, Release  
**Produktvertrag:** vier feste `1/240-s`-Steps je 60-Hz-Frame,
maximal `0,150 mm` transiente Überlappung

## Urteil

**RED.** Der eigene Solver besteht Determinismus, Energie, Ruhe und das
Headless-Performancebudget, aber nicht den unveränderten Geometrievertrag.

- Beide ruhigen 3°-Pflichtfälle überschreiten das Gate mit `1,324067 mm` und
  `1,359357 mm`.
- Der echte Frontlippenkontakt findet statt, erreicht dabei aber
  `6,597863 mm` maximale analytische Überlappung.
- 248 der 1.000 deterministischen Startlagen überschreiten ausschließlich das
  Penetrationsgate; das Maximum beträgt `2,868689 mm`.
- Alle 900 Pflichtfallwiederholungen sind je Fall hashidentisch. Kein Lauf
  verletzt Energie-, Ruhe-, Containment- oder Finite-Gates.
- Der 9-Münzen-Benchmark ist mit `1.871,917 µs` p99 für alle vier Solversteps
  deutlich innerhalb des vorab festgelegten `16.666,667-µs`-Renderframebudgets.

Das Ergebnis rechtfertigt keine Renderer- oder App-Integration. Der Spike wird
nicht durch nachträgliche Iterations-, Slop-, Step- oder Grenzwertänderungen
grün gerechnet.

## Vor dem ersten Lauf fixiertes Budget

| Parameter | Wert |
| --- | ---: |
| Solverstep | `1/240 s` |
| Steps pro 60-Hz-Frame | `4` |
| Velocity-Iterationen | `18` |
| Kontaktband | `0,150 mm` |
| Penetration-Slop | `0,015 mm` |
| Baumgarte-Faktor | `0,16` |
| Rollwiderstandsgrenze | `0,012 × Normalimpuls × Radius` |
| Sleep-Verzögerung | `0,500 s` |
| geforderte Ruhe | `0,750 s` |
| Penetrationsgate | `0,150 mm` |
| Energiewachstum | `<= 1 %` |

Diese Werte stehen in `SolverBudget.v4` und wurden nach dem Lauf nicht
verändert.

## Implementierter Solverumfang

- maßhaltige Münze mit `22 mm` Durchmesser, `2,2 mm` Dicke und `4,5 g` Masse;
- 12-/48-/64-Punkt-Zylinderprismen und maßgleiche Box-Kontrolle;
- endliche, einseitige Plane-Patches für Boden und die um `-25°` geneigte
  Frontlippe;
- stabile `ContactID` aus Body, Surface und Convex-Feature;
- bis zu vier räumlich verteilte Kontaktpunkte je Plane-Patch;
- über Steps persistierte Normal- und Tangentialimpulse;
- Warm Start und 18 sequentielle Impulsiterationen;
- Coulomb-Reibung als geklemmter zweidimensionaler Tangentialimpuls;
- begrenzter Rollwiderstand als Angular-Impulse, nie als Velocity-Zeroing;
- Quaternion-Integration und orientierte inverse Trägheit;
- konservative TOI-Bisektion für Translation und Rotation gegen Boden/Lippe;
- natürliche Sleep-Logik, die den Zustand mit gemessener nicht-null gesetzter
  Restgeschwindigkeit einfriert;
- keine direkte Positionskorrektur, Teleports, Slots oder Renderkorrekturen.

Sechs Release-Tests belegen Budget, vierpunktiges Face-Manifold, stabile IDs,
Warm Start, schnellen Boden-CCD, Sleep ohne Nullsetzen und identische Hashes.

## Pflichtfälle

| Fall | maximale Überlappung | Energieanstieg | Ruhe | Lippe | Hashes | Urteil |
| --- | ---: | ---: | ---: | --- | ---: | --- |
| coin-convex12-face | `0,000009 mm` | `0` | `0,750 s` | n/a | `1 / 100` | GREEN |
| coin-convex48-face | `0,000009 mm` | `0` | `0,750 s` | n/a | `1 / 100` | GREEN |
| box-control-face | `0,000009 mm` | `0` | `0,750 s` | n/a | `1 / 100` | GREEN |
| coin-convex12-tilt3 | `1,324067 mm` | `0` | `0,750 s` | n/a | `1 / 100` | **RED** |
| coin-convex48-tilt3 | `1,359357 mm` | `0` | `0,750 s` | n/a | `1 / 100` | **RED** |
| central-face-0deg | `0,000040 mm` | `0` | `0,750 s` | n/a | `1 / 100` | GREEN |
| central-face-minus3deg | `0,000022 mm` | `0` | `0,750 s` | n/a | `1 / 100` | GREEN |
| central-face-plus3deg | `0,000003 mm` | `0` | `0,750 s` | n/a | `1 / 100` | GREEN |
| edge-lip-78deg | `6,597863 mm` | `0` | nicht gefordert | ja | `1 / 100` | **RED** |

`1 / 100` bedeutet ein eindeutiger Zustandssequenz-Hash in 100 vollständigen
Wiederholungen. Alle Ruhefälle schlafen mit erhaltenen nicht-null gesetzten
Residualgeschwindigkeiten. Die Pflichtfälle erzeugen tatsächlich persistente
IDs, Warm-Start-Anwendungen und CCD-Impacts; Details stehen im JSON.

## 1.000 deterministische Startlagen

Seed `1441`, 64-Punkt-Münze, zufällige Lage, Höhe, Translation und Rotation:

| Gate | Fehler |
| --- | ---: |
| Penetration `<= 0,150 mm` | `248` |
| Energie `<= 1 %` | `0` |
| Ruhe `>= 0,750 s` | `0` |
| Containment | `0` |
| finite Werte | `0` |

Maximum: `2,868689 mm`; kombinierter deterministischer Hash:
`0xfe7c1cb217db2f78`. Das Frühgate ist damit RED, obwohl die übrigen
Invarianten halten.

## 9-Münzen-Performance

600 simulierte 60-Hz-Frames, jeweils vier Solversteps und neun unabhängige
Münzen gegen Boden/Lippe:

| Messung | Ergebnis |
| --- | ---: |
| Solverstep p50 | `0,083 µs` |
| Solverstep p95 | `367,167 µs` |
| Solverstep p99 | `465,709 µs` |
| Solverstep Maximum | `596,666 µs` |
| Vier-Step-Frame p99 | `1.871,917 µs` |
| Vier-Step-Frame Maximum | `2.061,625 µs` |
| 60-Hz-Budget | `16.666,667 µs` |

Performance ist GREEN. Der Benchmark enthält absichtlich keine Coin-Coin-
Kontakte; der geforderte Scope dieses Spikes ist Münze gegen statischen Boden
und Frontlippe. Deshalb ist er kein allgemeiner Stapel- oder Haufenbenchmark.

## Reportingkorrektur

Der erste Lauf deckte zwei reine Reportfehler auf, ohne Solverparameter oder
Produktgate zu ändern:

1. Der Manifold-Zähler summierte mehrere Solve-Phasen eines Steps; er berichtet
   jetzt das Maximum einer Phase. Das bestätigt höchstens vier Punkte je Plane
   und höchstens acht bei gleichzeitigem Boden-/Lippenkontakt.
2. Der Performance-Verdict verglich irrtümlich mit `1 ms`, obwohl das bereits
   ausgegebene und vorab definierte Vier-Step-Produktbudget `16,667 ms` beträgt.
   Die Vergleichszeile wurde an dieses unveränderte Budget angeglichen.

Danach wurden Tests und die gesamte Matrix erneut ausgeführt. Physikresultate
und Hashes blieben unverändert; nur Zähler und Performance-Verdict wurden
korrigiert.

## Grenzen und nächste Entscheidung

Der Spike bildet Boden und Lippe als endliche einseitige Flächen, nicht als
geschlossene Tray-Solids. Die Fehler konzentrieren sich auf rotierende
Featurewechsel bei flach geneigtem Kontakt und den gleichzeitigen dynamischen
Boden-/Lippenfall. Das ist eine Inferenz aus der Fallmatrix, kein bewiesener
Einzeldefekt.

Eine weitere Iteration wäre eine neue Version mit neuem Vorabplan, insbesondere
konservativem Advancement für rotierende Support-Features und einem gekoppelten
Mehrflächen-TOI/Position-Solver. v4 selbst bleibt RED. Eine Änderung auf einen
visuellen Vertrag wäre weiterhin eine separate Produktentscheidung.

## Reproduktion

```sh
cd tasks/reviews/coin-manifold-solver-v4
./run.sh
```

`run.sh` baut in einem temporären `/private/tmp/poch-manifold-v4-*`-Scratch,
führt Release-Tests und Matrix aus und entfernt den Buildcache beim Verlassen.
Ein erfolgreich gebauter, aber physikalisch roter Lauf endet absichtlich mit
Exitstatus `1`.

Belege:

- `runtime-result.json` - vollständige maschinenlesbare Ergebnisse;
- `runtime.log` - finales Laufurteil;
- `test.log` - Release-Testlauf;
- `Sources/CoinManifoldSolver/CoinManifoldSolver.swift` - Solver;
- `Sources/CoinManifoldSpike/main.swift` - eingefrorene Fälle und Gates.
