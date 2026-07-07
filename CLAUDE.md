# Poch 1441 - Projekt-CLAUDE.md

**Projekt:** Premium-iOS-Kartenspiel (Poch, 1441) | **Repo:** github.com/tobsiberlin/poch1441
**Letzte Aktualisierung:** 7. Juli 2026

> Basis-Regeln stehen in `~/.claude/CLAUDE.md` und gelten zusätzlich. Diese Datei enthält nur Poch-1441-spezifische Ergänzungen (destilliert aus den earned Regeln von hot take, kwittung, pawbie, hottake-web). Bei Konflikt gewinnt die spezifischere Regel hier. Spec + Regelwerk: `tasks/poch-spec.md`.

---

## 0. Die Seele des Spiels

Poch 1441 ist ein modernes Premium-Strategie-/Bluffspiel - der Urahn des Pokers, in eine zeitgemäße Produktästhetik übersetzt. Diese Bullets sind bindend. Vollständiger Kanon: `tasks/konzept.md`.

- **Drei Phasen = drei Gefühle:** Melden (Lotterie-Freude), Pochen (Bluff-Spannung), Ausspielen (Renn-Taktik). Jede Phase hat ihre eigene Dramaturgie, Komposition und Energie-Richtung - keine Phase fühlt sich wie Verwaltung an.
- **Clean-modern-premium, dunkel:** warmes Tinten-Schwarz, matte/pigmentierte Farben, gefräste Ringe. Kein Mittelalter, kein Holztisch, kein Casino-Neon, nichts Verwaschenes. Referenz-Feel: Apple-Watch-Ultra-Premium, nicht Gaming-RGB. **Visueller Style-Anker: `artifacts/style-ref/mockup-anchor.png`** (Layout-/Kompositions-Sprache übernommen; NICHT: All-in-Button, Arcade-/Spielhallen-Raum, Cyber-Namen, AI-Slop).
- **Material > Glow:** Premium entsteht aus Material, Kante, Tiefe, Schatten - nicht aus Dauer-Leuchten. Glow ist eine Belohnung (Stich gewonnen, Bluff erkannt), kein Grundzustand.
- **Farbe = Label (Balatro-Prinzip):** jede Mulden-Kategorie hat eine feste Farbe - in Juwelen-Tönen (Gold/Rose/Smaragd/Amethyst/Platin), NIE grelles Neon. Zwei Themes teilen dieselbe Geometrie: **Premium-matt** und **Vivid-Electronic** (dieselben Juwelen, matt vs. strahlend); der Held wird live gewählt.
- **Der Poch-Ring** (rundes 9-Fächer-Brett) ist die Signatur - Layout und Kartenrücken-Signet sprechen dieselbe Sprache. Karten international A/K/Q/J/10; deutsche Prosa „Dame/Bube".
- **Balatro-Feel, nicht -Struktur:** Eskalations-Drama, Juice, Kaskaden-Payoff, cleane Optik - aber kein Joker/Draft. Der Jackpot IST der native Multiplikator, der Bluff die native Tiefe. Balatro ist Messlatte für Feel-Qualität, nie Referenz für Stil oder Inhalt.
- **Menschen statt Systeme:** Gegner sind Charaktere mit Wärme (Tells, Erinnerungen, Geplauder) - das eine warme, painterly Material im cleanen Rahmen; der Kontrast ist die Eigenständigkeit. Presence-over-Persistence: groß am Entscheidungs-Beat, ruhiger Token sonst. **Bluff-Integrität (eiserne Regel):** kein UI-Element - auch kein Tell - korreliert je mit der echten Handstärke (die Tell-Funktion bekommt die Karten nicht als Input).
- **Positionierung modern-first:** „Das Strategiespiel, aus dem Poker wurde." 1441/Straßburg ist Prestige-Reveal (Trojanisches Pferd im Splash/Onboarding), nie das Hauptargument. 18+, kein Zock-/Casino-Marketing.
- **Detailverliebtheit (bindend):** JEDES Element - Zähler, Badge, Trennlinie, Button, Empty State - wird maximal schön und detailverliebt gestaltet; Platzhalter sind Zwischenstände, nie Endzustände. Cozy Wording: warmes, einladendes Deutsch („Ein neuer Abend" statt „Neues Spiel"), charmant, nie verstaubt; Transcreation in alle 7 Sprachen (§8), dieselbe Wärme statt wörtlicher Übersetzung.
- **GOTY-Messlatte:** jede Interaktion hat Gewicht (Animation, Sound, Haptik) unter High-Fidelity-Optik - nicht Effekt-Gewitter.
- **Spaß, Tonalität und Geschmack sind Tobsi-Gates** - nie an einen Score oder Judge delegieren.

## 1. Tech Stack

- **Sprache:** Swift (Toolchain 6.2, Language-Mode 5 + `SWIFT_STRICT_CONCURRENCY: complete` als Warnings; Flip auf Mode 6 später möglich)
- **Frameworks:** SpriteKit (Spieltisch) + GameplayKit (State-Machines) + SwiftUI (Menüs/HUD-Overlays) - der `SpriteView`-Hybrid. AVFoundation + CoreHaptics für Audio/Haptik.
- **Engine:** `PochKit` als eigenes Swift Package - UI-frei, deterministisch (seeded RNG), Event-emittierend, headless simulierbar. Bots nutzen dieselbe öffentliche State-API wie der Mensch (nie Karteneinsicht).
- **Persistenz:** `UserDefaults` fürs MVP (Fortschritt, Settings, Statistiken). SwiftData nur wenn wirklich nötig - und dann: neue `@Model`-Properties IMMER optional (sonst Startup-Crash bei Tester-Bestandsdaten).
- **Keine externen Dependencies** - alles Apple-nativ.
- **Projektgenerierung:** XcodeGen (`project.yml`) - deklarativ + reproduzierbar, kein GUI-Klicken.
- **Target:** iOS 17+, Universal. Bundle-ID `com.tobc.poch1441`, Team `GWP236628H`.

## 2. Performance-Constraints (bindend)

1. **SpriteKit/SwiftUI-Nadelöhr vermeiden:** Die `SKScene` läuft autark. `GameState` (`@Observable`) triggert SwiftUI nur bei Makro-Events (Phasenwechsel, Showdown, Partie-Ende, Kauf) - nie pro Frame aus `update(_:)`. Chip-Zähler, Pott-Anzeigen und alles Echtzeit-Animierte wird in SpriteKit gezeichnet, nicht als SwiftUI-Element.
2. **Draw-Calls minimieren:** Alle Sprites in `.spriteatlas` (Batching je Atlas). Placeholder-Phase: `SKShapeNode`s reichen; Atlas-Pflicht ab echten Assets.
3. **60fps + schneller Cold-Start sind Pflicht**, nicht Polish. Kein blockierender I/O auf dem Main-Thread beim Start.

## 3. Architektur-Regeln

- **UI = SwiftUI-Overlays, Spieltisch = `SKScene`.** Klare Trennung, keine Vermischung.
- **Spiellogik ausschließlich in PochKit** - kein Regel-Code in Nodes, Views oder ViewModels.
- **Datengetrieben statt hardcoded:** Bot-Profile (Bluff-Frequenz, Risikokurven), Tutorial-Seeds und Economy-Parameter als JSON/Plist, nie im Code verstreut.
- **Design-Tokens aus `DesignTokens.swift`** (Farben, Spacing, Radii, Timing) - keine Magic Numbers.
- **Kein Force-Unwrap (`!`), kein `print()`** (→ `os.Logger`).
- **Tests prüfen das Warum:** Jeder PochKit-Test benennt die Spielregel aus der Spec, die er absichert (z.B. „Cap-Neuberechnung nach Passen"). Kein „läuft durch"-Test.

## 4. Game-Feel-Disziplin (aus pawbie earned)

- Kern-Interaktionen (Karte ziehen/spielen, Chips kassieren, Poch-Schlag, Kettenbruch) werden als **Phasen-Enums mit ms-Timing** definiert und stehen unter **Parameter-Lock**: Timing-Änderungen nur nach Vorher/Nachher-Vergleich, jede Änderung ist eine große Änderung (ankündigen, nicht nebenbei).
- Animation-Tuning ist Kernarbeit, nicht Nebensache.
- **Balance nie per LLM-Judge:** PochKit ist deterministisch - Economy/Balance-Ziele als Headless-Simulations-Metriken formulieren (Partiedauer, Bankrottquote, Jackpot-Verteilung).

## 5. Asset-Pipeline (Replicate/FLUX)

- **Alle Assets Build-Time generiert**, nichts zur Laufzeit. Script-Gerüst: `/Users/tobsi/pawbie/artifacts/generate_*.py` als Vorlage (Modell + Prompts tauschen).
- **IP-Caveat (bindend):** Nie Künstler-, Studio- oder Spielenamen in Prompts oder Store-Texten („Carcassonne", „Ghibli" etc.). Beschreibend prompten („clean modern premium, matte jewel tones on warm ink-black, milled metal edges, soft studio light"). Eigener, benannter Stil = ownable + PR-sicher.
- **Konsistenz ist KEIN End-Task:** Stil früh festnageln (Stil-Referenzbilder, feste Seeds, ggf. LoRA), 5-Karten-Konsistenztest VOR Vollproduktion (Spec Phase 2).
- **Ablage:** Rohbilder nach `Assets_Raw/`, Katalog-Skript sortiert in `.spriteatlas`. Pro finalem Asset ein Provenance-Sidecar in `assets/provenance/` (Modell+Version/Hash, Lizenz-PDF-Verweis, Datum, Seed, Prompt, menschliche Bearbeitungsschritte).
- **Musik nur Replicate** (Tobsi-Entscheidung 5.7.): Lizenznachweis ist Release-Blocker; IP-Caveat gilt auch für Musik-Prompts. SFX dezent (max. 60% Default-Volume), in Settings stummschaltbar.
- **Replicate-Token:** `~/.config/replicate.key` (chmod 600) bzw. Env-Var im Aufruf - nie im Repo, nie in Xcode-Configs, die committet werden.
- **QA-Loop pro Asset (verschärft, Tobsi 5.7.):** Jedes Bild durchläuft VOR jeder Tobsi-Sichtung harte externe Kritik: gemini-vision (Gemini 2.5 Flash) mit expliziter Was-ist-falsch-Frage (3-Zeilen-Format, Kriterien: clean-modern-premium, Material>Glow, Farbe=Label (Juwelen, kein Neon), Slop-Schrift/Signatur, Motiv-Treue) → Mängel selbständig beheben (bis zu 3 Retake-Iterationen, dann Hebelwechsel) → nur bereinigte, gebündelte Chargen an Tobsi. Design-/Konzeptfragen zusätzlich regelmäßig mit gemini-review + gpt-review sparren (Regel-7-Geist auch im laufenden Betrieb).
- **Lesbarkeits-Licht-Regel (Tobsi, 5.7.):** Auf Spiel-Assets (Brett, Mulden, Karten, Chips) liegt NIE ein inhaltsverdeckender Schlagschatten - Stimmungslicht gehört an Rand und Umfeld, die Spielfläche bleibt gleichmäßig lesbar. Licht/Schatten ist in der Ebenen-Komposition ein EIGENER Layer (Stimmungslicht als Overlay), niemals ins Artwork eingebacken. gemini-vision-QA prüft „Inhalt durch Schatten verdeckt?" als Pflichtkriterium.
- **Anti-Slop-Auflagen (Tobsi, 5.7.):** Nichts Verwaschenes ausliefern; NIEMALS Schrift oder Zahlen im Artwork generieren lassen (KI-Schrift = Slop-Erkennungsmerkmal) - jede Beschriftung kommt als Vektor-Overlay oder menschliches Compositing. gemini-vision-QA prüft jedes Asset explizit auf Verwaschenheit und Slop-Schriften.

## 6. Monetarisierung (bindend, Kwitto-Bug-Prävention)

- 4,99 € Non-Consumable-Unlock. **Unlock-Guardrail (eiserne Regel):** Freischaltung wird ausnahmslos über verifizierte StoreKit-2-Entitlements geprüft (`Transaction.currentEntitlements`, `case .verified`) - niemals über ein persistiertes Bool. Lokales Caching nur als Optimierung mit Live-Revalidierung beim Start, nie als Quelle der Wahrheit.
- **Preis-Source-of-Truth:** `.storekit`-Datei + `Product.displayPrice`; Konstanten nur als Pre-Load-Fallback.
- **3.1.1-Falle:** Kaufbutton zeigt glasklar den Preis („Für 4,99 € freischalten"), Restore-Button Pflicht.
- **Pro/Free-Test-Toggle und Review-Seed-Loader existieren nur in DEBUG-Builds** (`#if DEBUG`), nie im Release-Binary - versteckte Features sind ein 2.3.1-Rejection-Risiko, ein Pro-Toggle im Shipping-Build ein Unlock-Bypass.

## 7. Verifikations-Loop (iOS-Rhythmus, aus hot take/kwittung earned)

Pro Feature: Implementieren → Build-Gate → Simulator-Run → Screenshot → Selbst-Check → gemini-vision bei Visuellem → CHANGELOG/README → Commit + Push.

**Zero-Warnings-Gate (muss vor „fertig"/Commit leer sein):**
```bash
xcodebuild -project Poch1441.xcodeproj -scheme Poch1441 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 \
  | grep -E "warning:|error:" | grep -v "appintentsmetadata"
```
- `appintentsmetadataprocessor`-Hinweise sind kein Bug (ignorieren); SourceKit-IDE-Warnings sind oft Indexing-Glitches - `xcodebuild` sauber = Code ok.
- **Swift-6-Concurrency-Warnings sind nie Noise** - immer fixen (werden in Mode 6 harte Errors).

**Build → Install → Launch (DerivedData-Pfad IMMER dynamisch auflösen, nie hardcoden):**
```bash
DEST='platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild -project Poch1441.xcodeproj -scheme Poch1441 -destination "$DEST" build
SETTINGS="$(xcodebuild -project Poch1441.xcodeproj -scheme Poch1441 -destination "$DEST" -showBuildSettings 2>/dev/null)"
DIR="$(printf '%s' "$SETTINGS" | sed -n 's/^ *BUILT_PRODUCTS_DIR = //p' | head -1)"
NAME="$(printf '%s' "$SETTINGS" | sed -n 's/^ *FULL_PRODUCT_NAME = //p' | head -1)"
xcrun simctl install booted "$DIR/$NAME" && xcrun simctl launch booted com.tobc.poch1441
```
- Nur die anchored-sed-Variante nutzen - awk über `-showBuildSettings` griff zweimal die falsche Zeile („YES/Poch1441.app", 5.7.).
- **Jeder Screenshot** (`xcrun simctl io booted screenshot`) wird unmittelbar per Read verifiziert - nicht stichprobenhaft.
- **Preview vor Simulator** bei reinen SwiftUI-Änderungen (#Preview, Feedback in <5s).
- **Tap-/Gesture-Bugs:** zuerst View-Hierarchie nach dekorativen `.overlay`-Layern durchsuchen (schlucken Taps) → `.allowsHitTesting(false)`.
- Layout-Werte messen (Pillow/DevTools-Prinzip), nicht in 20er-Schritten raten - max. 2 Iterationen pro Wert.

## 8. Lokalisierung (7 Sprachen, aus hottake-web/ChatStory earned)

- `String(localized:)` + `Localizable.xcstrings` ab dem allerersten String. **Hierarchische Keys** (`poch.bet.raise`, `tutorial.phase2.hint`), nicht flach.
- **Checkliste pro neuem String:** DE ✅ EN ✅ FR ✅ IT ✅ ES ✅ NL ✅ PL ✅ - kein Feature ist fertig ohne 100% Katalog-Parität (Xcode-Lokalisierungsanzeige prüfen). Lesson aus ChatStory: Features ohne Übersetzungen deployed → 254 Issues.
- **Transcreation statt Übersetzung:** FR/EN erzählen die Poque→Poker-Story mit; Ton-Referenz sind bestehende Einträge derselben Sprache.
- Sprachnamen als Text im Switcher, keine Flaggen (Flaggen sind keine Sprachen).

## 9. Design-Leitplanken für SwiftUI-Overlays (aus kwittung/Views earned)

- **4pt-Raster** (mit Halbschritten), keine willkürlichen Werte (13/17/37pt).
- **High-Impact-Moments animieren, nicht alles.** `accessibilityReduceMotion` immer respektieren - auch am Spieltisch (Juice-Reduktion, nicht Juice-Ausfall).
- In SwiftUI nur `.offset`/`.opacity`/`.scaleEffect` animieren - kein Layout-Thrashing. Keine Bounce/Elastic-Easings in Menüs (der SpriteKit-Tisch darf mehr, aber nur unter Parameter-Lock, §4).
- **AI-Slop-Verbote:** keine farbigen Seitenstreifen an Cards, kein Gradient-Text, kein Glassmorphism-Overuse. 60/30/10-Farbbalance.
- **Keine Einweg-Abstraktionen:** Drei ähnliche Zeilen schlagen eine voreilige Abstraktion.

## 10. Tobsi-Kommunikation im Loop (earned 5.7., Tobsi-Feedback)

- `artifacts/poch-1441-cockpit.html` (auch nach iCloud-TEMP gespiegelt, Generator `tools/gen_cockpit.py`) ist das lebende Status-Cockpit: nach jeder Loop-Iteration aktualisieren. Offene Tobsi-Entscheidungen stehen immer als oberster Block - **jede mit kopierbarem Antwort-Prompt** (Copy-Button, vorformulierte Antwort zum Einfügen in den Chat; earned 5.7., Tobsi kam ohne nicht mehr mit). Bei neuem Entscheidungsbedarf die Datei per `open` öffnen. Chat-Zusammenfassungen ersetzen das Cockpit nicht. **Chat-zuerst-Regel (earned 5.7.):** Fragen und Entscheidungen werden IMMER direkt im Chat gestellt - mit fertigen Antwortzeilen zum Kopieren; das Cockpit spiegelt sie nur. **Eine-Frage-Regel (earned 5.7., Tobsi: „alles verwirrend"):** Immer nur EINE aktive Tobsi-Entscheidung, alle weiteren explizit als geparkt führen; wartet der Loop auf Tobsi, endet die Nachricht mit „Ich warte auf: X - solange passiert nichts."
- Auswahl-Artefakte (Stil-Kandidaten etc.) werden NICHT als ZIP geliefert (Tobsi 7.7.): gelabelte Bilder (Kandidaten-Buchstabe im Bild) direkt ins Cockpit-HTML einbetten (Base64), Cockpit nach `~/Library/Mobile Documents/com~apple~CloudDocs/TEMP/` spiegeln und per `open` öffnen.

## 11. Commits & Secrets

- Commits Deutsch, `<type>: <summary>`. Vor Commit: CHANGELOG.md + README.md prüfen. Push direkt chainen.
- **Nie committen:** Replicate-Token, Gemini-Key, `.p8`-Keys (App Store Connect-Keys nach `~/.appstoreconnect/`, außerhalb des Repos).
- Subagent-generierte UI-Strings nach Umlaut-Fehlern greppen (ae/oe/ue/ss), bevor sie ins Repo gehen.
