# Changelog

## [0.5.1] - Sichtung 1: Kartenrücken + Charakterstil (7.7.2026, abends)

### Hinzugefügt
- Asset-Pipeline neu (clean-modern-jewel): `tools/gen_sichtung1_raw.py` (FLUX 1.1 Pro + Recraft V3 via Replicate, Modellwahl live geprüft) + `tools/gen_sichtung1_composite.py` (Atom-Prinzip: Artwork + Vektor-Rahmen + Didot-Monogramm P·1441 + Kandidaten-Label; G-Signet deterministisch in PIL gezeichnet).
- Sichtung 1 generiert + QA-gefiltert (gemini-vision 3-Zeilen-Kritik pro Bild, GPT-Zweitmeinung zur Markenlogik, 8 Retakes inkl. Hebelwechsel): 8 Kartenrücken-Richtungen (A-H) + 6 Charakter-Stil-Proben (Öl/Gouache, Vektor, Stilisiert-3D je Nova/Blade) in `artifacts/sichtung1/`.
- Cockpit-Umbau: feste Struktur (Jetzt gerade / Wartet auf dich / Entscheidungen-registriert / Gesamtbild), eingebettete Sichtungs-Galerien mit Lightbox, Mini-Vorschau in Spielgröße (GPT-Hinweis: Skalierungs-Realität) und Antwort-Kopier-Buttons pro Kandidat.

### Geändert
- Auslieferungsweg Sichtungen (Tobsi-Ansage): keine ZIPs mehr - alles direkt ins Cockpit-HTML, per `open` geöffnet (CLAUDE.md §10, lessons.md, Memory aktualisiert).

## [0.5.0] - Fundament (7.7.2026)

### Engine
- PochKit: alle 3 Phasen (Melden / Pochen / Ausspielen), Combos, Dealing (8/8/8/7), Match-Modi, Bot-Profile. Deterministisch, headless simulierbar. 55 Tests grün.
- **Plattform-stabile RNG-Primitive** (`SeededRNG.nextUInt/nextInt/nextDouble01/shuffled`, Fisher-Yates) ersetzen stdlib-`shuffled(using:)`/`random(in:using:)` in Dealing/BotProfile/MatchSimulator - Voraussetzung für autoritative Server-Nachrechnung (v2). Golden-Master-Test pinnt die Sequenz.
- **Bluff-Integrität als Code-Garantie:** `TellGenerator` erzeugt Tells rein aus öffentlichem Zustand + Profil + RNG - die Signatur kann Karten strukturell nicht sehen. Test sichert Hand-Unabhängigkeit.
- Combos-Iteration nach Rang sortiert (Determinismus strukturell statt zufällig).

### Behoben (Audit-Konsistenz)
- `poch-spec.md` Art-Direction auf den Kanon (`konzept.md`, clean-digital, Material>Glow, 2 Themes) angeglichen - der alte Holztisch-/3-Themes-Widerspruch ist raus.
- Glow-Budget-Regel ergänzt (Emission = rarer Akzent, nie Grundstimmung); „Jackpot-Finale"/Hausregel-Toggles ehrlich als „geplant, nicht Gate A" gelabelt; Meta-Progression als „Design steht, Code = 0%".

### App
- SwiftUI-Fundament: Poch-Ring-Geometrie (8 Mulden + Mitte), GameState←PochKit-Bridge (echte Werte), MatchSource-Seam (Multiplayer-vorbereitet).
- 2-Theme-System: Premium-matt + Vivid-Electronic (dieselben Juwelen-Töne, matt vs. strahlend).
- Material-Fundament: warmes Tinten-Schwarz + Vignette, Metallkanten statt Dauer-Glow, gefräste Ring-Linie + Mitte-Pott.

### Docs
- Design-Kanon `tasks/konzept.md`, Kurzfassung `CLAUDE.md §0`, lebendes Cockpit `artifacts/poch-1441-cockpit.html` (auch in iCloud-TEMP).
