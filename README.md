# Poch 1441

Modernes Premium-Strategie-/Bluffspiel für iOS - der Urahn des Pokers (1441 in Straßburg erstmals erwähnt), in eine zeitgemäße, clean-moderne Produktästhetik übersetzt. Modern-first; die Herkunft ist Prestige-Reveal, nicht das Hauptargument. 18+, kein Zock-Marketing.

- **Design-Kanon 2026:** `tasks/design-canon-2026.md` · **Produkt und Regeln:** `tasks/konzept.md` · **Kurzfassung:** `CLAUDE.md §0`
- **Regelwerk & Roadmap:** `tasks/poch-spec.md` · **Status/Cockpit:** lokal generiert über `tools/gen_cockpit.py`
- **Stack:** Swift, SwiftUI + PochKit (Engine als UI-freies, deterministisches Swift Package); SpriteKit für die Spieltisch-Juice-Ebene geplant
- **Status:** Engine (Gate A) eingefroren · First-Run-Vertical-Slice auf der echten Poch Disc integriert und auf SE, Standard und Pro Max in Portrait/Landscape geprüft · Produktwelt bleibt Poch Disc plus regelidentisches Unterwegs-Set

## Struktur

```
App/        SwiftUI-Fundament
PochKit/    Engine (UI-frei, deterministisch, headless testbar)
tasks/      Kanon (konzept), Regelwerk (poch-spec), Todo, Lessons
tools/      Cockpit-Generator
artifacts/  lokal generierte Cockpits und QA-Sichtungen, nicht versioniert
```
