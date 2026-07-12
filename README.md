# Poch 1441

Modernes Premium-Strategie-/Bluffspiel für iOS - der Urahn des Pokers (1441 in Straßburg erstmals erwähnt), in eine zeitgemäße, clean-moderne Produktästhetik übersetzt. Modern-first; die Herkunft ist Prestige-Reveal, nicht das Hauptargument. 18+, kein Zock-Marketing.

- **Design-Kanon:** `tasks/konzept.md` (Kurzfassung in `CLAUDE.md §0`)
- **Regelwerk & Roadmap:** `tasks/poch-spec.md` · **Status/Cockpit:** lokal generiert über `tools/gen_cockpit.py`
- **Stack:** Swift, SwiftUI + PochKit (Engine als UI-freies, deterministisches Swift Package); SpriteKit für die Spieltisch-Juice-Ebene geplant
- **Status:** Engine (Gate A) eingefroren, 55 Tests grün · SwiftUI-Fundament (Poch-Ring, 2 Themes Premium-matt/Vivid, Material-Basis) in Arbeit · Gate 0.5 (Naming/Rating) offen

## Struktur

```
App/        SwiftUI-Fundament
PochKit/    Engine (UI-frei, deterministisch, headless testbar)
tasks/      Kanon (konzept), Regelwerk (poch-spec), Todo, Lessons
tools/      Cockpit-Generator
artifacts/  lokal generierte Cockpits und QA-Sichtungen, nicht versioniert
```
