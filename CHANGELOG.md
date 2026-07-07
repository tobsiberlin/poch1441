# Changelog

## [0.5.3] - Phase-3-Layout: Das Ketten-Rennen + Rücken-Runde 3 (8.7.2026, nachts)

### Hinzugefügt
- `Phase3View` (§6c/§5b Akt 3): Ketten-Kaskade als Präsentations-Schicht über der instanten Engine - Zwangskarten enthüllen im 180-ms-Takt (Parameter-Lock), 350-ms-Beat-Drop am Kettenriss mit golden glühender Stopper-Karte, Anspielrecht-Signal wandert sichtbar, Gegner als matte Schiefer-Tokens mit Restkarten-Zähler, gespielte Ketten bleiben als lesbare Sequenz liegen (ältere gedimmt), Rundenende-Banner (Centerpot + Restkarten-Summe).
- `GameState`: Kaskaden-Präsentation (`revealedPlays`-Zeiger, `displayedHand` läuft der Engine nicht voraus), Bot-Anspiel (Platzhalter-Heuristik: niedrigste Karte), `humanLead`; DEBUG-Args `-ausspielStart`/`-autoLead` für Kaskaden-QA ohne UI-Tap.
- Kartenrücken-Runde 3 (Tobsi-Richtungen, Gestalt statt Material): `tools/gen_sichtung2_wappen.py` - W1/W2 Vertikal-Siegel (Facetten-Raute), B1/B2 Brett als flache Prägung (echte Anker-Geometrie, großer Mitte-Pott), K1 Farbe als Rahmen-Signal; alle deterministisch, ungeprimter Assoziations-Test pro Kandidat (W2 = erstes Wunschprofil „Spielkarten + Mysterium").

### Geändert
- Drei-Akte-Navigation in `ContentView` (Melden → Pochen → Ausspielen), Phase-2-Banner führt in Phase 3 weiter; `CardFace` skalierbar + Gold-Stopper-Zustand.
- X-Runde archiviert (Gestalt-Lesson: geschlossener Farbkreis = Rad; Abbruchregel dokumentiert).

### Geprüft
- Build 0 Warnings; Kaskade live im Simulator verifiziert (Mid-Chain-Shot mit Gold-Ass-Stopper + Rundenende-Shot); Cockpit mit Runde-3-Galerie + P3-Screenshot.

## [0.5.2] - Phase-2-Layout: Das Bluff-Duell (7.7.2026, nachts)

### Hinzugefügt
- `Phase2View`: Kompressions-Layout (§5b Akt 2) - Gegner als Kardinalpunkt-Tokens (Platzhalter bis Charakterstil-Urteil), violetter Poch-Pott als wachsender Held im Zentrum, entsättigter Ring als Echo, Hand mit leuchtendem Kunststück (§6b, nur eigene Hand).
- Biet-Steuerung: Slider bis zur harten Decke mit personifizierter Limit-Wand („Limit 51 · Nova kann nicht mehr mit", rückt nach Passen hoch), Passen/Mitgehen/Pochen-Erhöhen, `.rigid`-Haptik am Anschlag, `.heavy` beim Poch.
- `GameState`: Phase-2-Zustand (Pott, Poch-Mulde, Wand-Besitzer, legale Aktionen aus der Engine) + Bot-Schleife mit variablen Denkpausen (BotBrain, öffentliche State-API - Bluff-Integrität strukturell gewahrt) + Action-Bubbles („pocht 5!", „passt").
- `CardFace` extrahiert (geteilt P1/P2, Amethyst-Glow fürs qualifizierende Kunststück); DEBUG-Launch-Arg `-pochenStart` für QA-Läufe.

### Geprüft
- Build ohne Warnings, Simulator-Screenshots beider Akte verifiziert, gemini-vision-QA aufs Layout (Befund fürs Feel-Pass notiert: Slider generisch, Wand nur Text - kommt mit Game-Feel-Iteration).
- Offen: Bot-Interplay am Gerät noch nicht durchgespielt (kein UI-Tap headless) - erster Playtest deckt das.

### Entschieden (Tobsi, 7.7. nachts)
- **Charakterstil O (Öl/Gouache painterly)** mit Auflagen: Pflicht-Paintover pro Porträt, V bleibt Konsistenz-Fallback bis Konsistenz-Beweis (1 Charakter × alle Emotionen), Anker/LoRA, Garderobe-Test entkoppelt, Monogramm raus aus dem QA-Scoring.
- **Kartenrücken A verworfen** (Casino-Read: Radial-Metall + Chrom-Dom = Roulette). Stattdessen Synthese-Runde X1-X4 gebaut: Vektor-Juwelenring (Token-Farben, Brett-Reihenfolge) auf schwarz-auf-schwarz-Prägung; ungeprimter Assoziations-Test etabliert (Lesson: Vision-QA misst „premium", übersieht Assoziations-Reads). Befund: gefüllte Segment-Ringe lesen als Roulette, X4 (Signet-Größe, Linien) casino-frei. FLUX-Entgiftungsversuche A1/A3 drifteten erneut in Casino/Ornament-Slop - aussortiert.

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
