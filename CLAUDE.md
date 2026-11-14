# CLAUDE.md - POCH 1441

Kompletter Neubau eines iOS-Kartenspiels (historisches Poch + moderner Run-Layer). Produktkonzept: `docs/CONCEPT.md`. Regeln: `docs/RULES.md`.

## Sprache & Stil
- Doku, Commit-Messages und Code-Kommentare auf Deutsch, immer mit korrekten Umlauten (ä, ö, ü, ß). Bindestriche statt Gedankenstriche.
- Bezeichner im Code auf Englisch.

## Stack
- Swift 6 (strict concurrency), SwiftUI, Swift Packages, iOS 26+.
- SpriteKit nur dort, wo ein Performance-Test belegt, dass SwiftUI nicht reicht.
- Keine Third-Party-Dependencies ohne Rückfrage.
- Builds, Simulator, Screenshots und Logs über XcodeBuildMCP. Nach UI-Änderungen immer bauen, im Simulator starten und Screenshot prüfen.

## Architektur - harte Regeln
1. `PochCore` importiert niemals SwiftUI, UIKit oder SpriteKit.
2. Der einzige Weg, den Spielzustand zu ändern: `apply(state:action:) throws -> Transition` (neuer State + Events).
3. `PochCore` ist deterministisch. Zufall nur über den injizierten Seeded RNG, nie `random()` global.
4. `PochStage` liest State und spielt Events aus einer Queue ab. Es mutiert niemals den State.
5. Visuelle Zustandsänderungen passieren beim Aufprall eines Objekts, nie beim Abflug. Nichts teleportiert, nichts verschwindet mitten in der Luft.
6. Chips sind bilanzerhaltend. Jeder Engine-Test prüft diese Invariante.
7. Reduced Motion / Schnellmodus: dieselben Events, sofort dargestellt. Keine zweite Logik.

## Arbeitsweise
- Größere Aufgaben zuerst im Plan Mode: Plan zeigen, dann umsetzen.
- Core-Arbeit test-first: erst Tests, dann Implementierung.
- Aufgaben eng schneiden: ein Paket, ein Feature, klare Abnahme. Kein "baue das ganze Spiel".
- Regeln nie raten. Ist in `docs/RULES.md` etwas offen: stoppen und fragen.
- Balancing-Werte gehören in eine zentrale Config (`PochCore/Config`), nicht hartcodiert verstreut.
- Das alte Projekt (`legacy/`) ist nur Referenz zum Lesen. Kein Code wird ungeprüft übernommen.

## Definition of Done
- Tests grün, keine neuen Warnings.
- Für Core: Sim-Lauf mit `PochSim` (mind. 10k Partien) ohne ungültigen Zustand.
- Für UI: Screenshot im Simulator geprüft, Dynamic Type und Reduced Motion getestet.
- Kurzer Eintrag in `docs/CHANGELOG.md`.
