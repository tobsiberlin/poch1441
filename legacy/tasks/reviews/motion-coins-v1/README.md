# Münzbewegung V1

Deterministischer Canvas-Prototyp für Einwurf, Kollision, Settle und Stapelbildung.

## Start

```sh
python3 -m http.server 8765 --directory tasks/reviews/motion-coins-v1
```

Danach `http://127.0.0.1:8765/` öffnen.

## Prüfoberfläche

`window.__coinPrototype.snapshot()` liefert den aktuellen Seed-Zustand, FPS,
Settle-Zeit, Kontakte, Clip-Verstöße, Canvas-Abmessungen und Dokument-Overflow.
Szenen und Motion-Modus können außerdem deterministisch über
`selectScenario(key)` und `setMotion(mode)` gewechselt werden. Für Automation in
einem verdeckten Browser-Tab führt `advanceToSettle()` denselben festen
120-Hz-Schritt synchron bis zum Ruhezustand aus.
