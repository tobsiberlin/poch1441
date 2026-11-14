# Coin Jolt Spike

Isolierter, headless Architektur- und Solvergate-Spike gegen den offiziellen
Jolt-Physics-Tag `v5.6.0`. Der Ordner enthält ausschließlich Projektquellen,
Resultate und die MIT-Notice. Jolt selbst wird zur Reproduktion nur temporär
unter `/private/tmp/poch-jolt-spike-*` geklont und nicht vendort.

Das Ergebnis und die Grenzen stehen in `RESULT.md`; die vollständigen Messwerte
stehen in `runtime-result.json`.

Ausführen:

```sh
./run.sh
```

Ein Exitstatus `1` ist bei einem erfolgreich gebauten, aber physikalisch roten
Solvergate beabsichtigt.
