# Coin Persistent-Manifold Solver v4

Isolierter Swift-/headless-Spike. Kein Renderer, keine App-Abhängigkeit und
keine Drittengine.

Das Produktbudget ist im Code vor dem ersten Lauf fixiert:

- Solverstep `1/240 s`
- vier Solversteps pro 60-Hz-Renderframe
- maximale transiente Überlappung `0,150 mm`
- mechanisches Energiewachstum höchstens `1 %`
- 100 Wiederholungshashes je Pflichtfall
- 1.000 deterministische Startlagen
- 9-Münzen-Headless-Benchmark

Ausführen:

```sh
swift test -c release
swift run -c release CoinManifoldSpike runtime-result.json
```

Ein Exitstatus `1` ist bei einem ehrlich roten Gate beabsichtigt.
