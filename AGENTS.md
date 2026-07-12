# Codex Regeln - Poch 1441

Swift/SpriteKit/SwiftUI-Spiel mit deterministischem PochKit-Kern. Historischer Premium-Brettspiel-Charakter ist wichtiger als schnelle Effekthascherei.

## Architektur

- Spielregeln ausschliesslich in PochKit, nicht in Nodes, Views oder ViewModels.
- UI = SwiftUI-Overlays, Spieltisch = `SKScene`.
- Datengetrieben arbeiten: Bot-Profile, Tutorial-Seeds und Economy-Parameter in JSON/Plist.
- Design-Tokens aus `DesignTokens.swift`; keine Magic Numbers.
- Keine Force-Unwraps und kein `print()`; `os.Logger` nutzen.

## Performance und Game Feel

- 60 FPS ernst nehmen; keine teuren Layout-/Rendering-Loops in Frame-Pfaden.
- Balance nie per LLM-Judge. Headless-Simulationsmetriken verwenden.
- High-impact Momente animieren, nicht alles; `accessibilityReduceMotion` respektieren.

## Warm-editoriale Produkthülle

- Den globalen Skill `warm-editorial-mobile-ui` für Menüs, Onboarding, Tutorial, Ergebnis-, Gegner-, Shop-, Profil- und Einstellungsflächen nutzen.
- Nicht auf Spieltisch, Poch-Ring, Karten oder High-Impact-Spielmomente als neues Designsystem übertragen; dort gelten die dunkle Juwelen-/Materialsprache und die phasenspezifische Dramaturgie.
- Aus dem Skill vor allem editoriale Hierarchie, warme Ton-in-Ton-Flächen, klare Fokusführung, native Controls und ruhige Informationsgruppen übernehmen.
- Poch-Tokens und Produktidentität haben Vorrang: kein pauschales Korallen-Orange, kein beiges Light-Theme und keine fremden Marken oder Mockup-Kompositionen übernehmen.

## Asset-Pipeline

- Assets Build-Time generieren, nicht zur Laufzeit.
- Keine Künstler-, Studio- oder Spielenamen in Prompts oder Store-Texten.
- Schrift/Zahlen nicht ins KI-Artwork prompten; Beschriftungen als Vektor/Overlay.
- Replicate-Token nur aus `~/.config/replicate.key` oder Env, nie ins Repo.

## Monetarisierung

- StoreKit-Preis aus `.storekit`/`Product.displayPrice`.
- Kaufbutton zeigt klar den Preis.
- Restore-Button Pflicht.
- Debug-Toggles und Review-Seed-Loader nur in DEBUG-Builds.

## Verifikation

- Swift-6-Concurrency-Warnings sind nicht Noise.
- Jeder neue sichtbare String braucht DE, EN, FR, IT, ES, NL, PL.
- Build/Tests/Simulator passend zur Änderung ausführen.
- Keine Commits oder Pushes ohne explizite Nutzeranweisung.
