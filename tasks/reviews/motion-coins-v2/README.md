# Motion Coins V2 - Einzelmünzen-Experiment

## Architekturentscheidung vor Implementierung

Der aktuelle Apple-Zielstack für eine spätere Produktdarstellung ist RealityKit.
SceneKit ist deprecated und wird für diesen Versuch weder neu eingeführt noch als
Fallback verwendet.

RealityKit übernimmt später ausschließlich Darstellung, Kamera, Licht und die
Anbindung an die App. Die elf Abnahme-Gates benötigen reproduzierbare Messwerte;
deshalb besitzt dieser isolierte Versuch einen kleinen, kopflosen 3D-Rigid-Body-
Kern in Swift. Er arbeitet in SI-Einheiten, integriert eine echte
Quaternion-Orientierung und kollidiert einen dreidimensionalen Zylinder mit einer
analytischen, räumlichen Muldenoberfläche. Der feste äußere Physikschritt beträgt
1/120 s. Ein RealityKit-Adapter darf erst entstehen, nachdem dieser Kern alle
Gates bestanden hat.

Ein Browser-Proof wäre höchstens eine mathematische Referenzprojektion. Für V2
wird kein Browser geöffnet und keine Browseranimation implementiert.

## Harte Abbruchgrenze

Der Versuch darf keine Feder, vorberechnete Slots, Snap-Position, Magnetkraft oder
zeitgesteuertes Einrasten enthalten. Falls kontinuierliche 3D-Kollision,
Quaternion-Dynamik, belastbarer Support und die elf Gates in diesem isolierten
Scope nicht gemeinsam nachweisbar sind, endet V2 mit einem dokumentierten
Blocker. Eine 2.5D-Ersatzanimation ist ausdrücklich kein zulässiges Ergebnis.

## Abnahme

Die einzige zulässige Szene enthält eine Münze und eine Außenmulde. Vor einem
späteren visuellen Adapter müssen maschinell bestehen:

1. Apex 55-70 mm.
2. Erster Kontakt nach 0,18-0,26 s.
3. Kein Tunneling durch Tisch oder Mulde.
4. Mindestens ein Edge-on-Verhältnis unter 0,35 aus echter 3D-Orientierung.
5. Ein bis vier neu beginnende Kontakte.
6. Keine Feder, Slots, Snaps oder Timeouts.
7. Settle spätestens 1,25 s nach dem ersten Kontakt.
8. Ruhestellung mit echtem Support-Kontakt.
9. Penetration höchstens 0,15 mm und Support-Lücke höchstens 0,20 mm.
10. Zehn Wiederholungen innerhalb eines Physikschritts, 0,20 mm und 0,5 Grad.
11. 390x844 und 667x375 verändern nur die Projektion, nie Physik oder Timing.

Der Gate-Runner gibt erst nach Abschluss aller Prüfungen einen Gesamtstatus aus.

## Verifizierter Stand

Ausgeführt mit:

```sh
swift build --package-path tasks/reviews/motion-coins-v2 \
  -c release -Xswiftc -warnings-as-errors
swift run --package-path tasks/reviews/motion-coins-v2 \
  -c release motion-coins-v2-gates
```

Alle elf Gates bestehen. Der feste Lauf liefert Apex 61,1992 mm, ersten Kontakt
bei 0,2083 s, genau einen Kontaktbeginn und Ruhe bei 0,6667 s. Die letzte Münzpose
besitzt einen echten Oberflächenkontakt; nicht aufgelöste Penetration und
Support-Lücke liegen im quantisierten Report bei 0 mm. Gate 10 wiederholt den
vollständigen Lauf zehnmal und vergleicht zusätzlich einen Digest aller
Welttrajektorien.

Es existiert bewusst kein RealityKit-, Browser- oder sonstiger visueller Adapter.
