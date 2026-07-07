# Poch 1441 - Todo / Status

**Stand:** 7. Juli 2026. Kanon: `tasks/konzept.md` · Kurzfassung: `CLAUDE.md §0` · lebendes Cockpit: `artifacts/poch-1441-cockpit.html` (auch in iCloud-TEMP).

## Fertig

- [x] **Engine (PochKit) - Gate A eingefroren.** Alle 3 Phasen (Melden/Pochen/Ausspielen), Combos, Dealing (8/8/8/7), Match-Modi, Bot-Profile. Deterministisch, headless simulierbar. **55 Tests, 0 Failures.**
- [x] **Design-Kanon** (`konzept.md`): Produkt-Linie X, Balatro-Feel-nicht-Struktur, Farbe=Label (Juwelen), Poch-Ring, Kern-Trias-Feel-Specs, Meta-Architektur, Phasen-Morph.
- [x] **SwiftUI-Fundament:** Ring-Geometrie (8 Mulden + Mitte), GameState←PochKit-Bridge (echte Werte), 2-Theme-System (Premium-matt + Vivid), MatchSource-Seam.
- [x] **Material-Fundament (Iter. 1-3):** warmes Tinten-Schwarz + Vignette, Metallkanten statt Dauer-Glow, gefräste Ring-Linie + Mitte-Pott. Beide Themes grün + screenshot-verifiziert.

## Zum Entscheiden (Tobsi-Gate)

- [ ] **Theme-Held A/B** - geparkt, live am Ende, wenn zwischen Premium-matt und Vivid flippbar.
- [ ] **Geparkt - Garderobe-Frage:** Reviewer forderte periodenechte 1441-Kleidung; widerspricht Modern-first-Kanon. Default: zeitlos-modern. Nur bei Tobsi-Votum ändern.

### Entschieden 7.7. nachts
- [x] **Kartenrücken: W2 FINAL (Asset-Freeze, Exekutions-Befehl).** Auflagen erfüllt: Punktsymmetrie mit Pixel-Beweis [0,0,0] (E-Fehler strukturell unmöglich), crisp Vektor-Monogramm (4x supersampled), Engine-Branding (`CardBack.swift` rendert aus DesignTokens), Provenance-Sidecar `assets/provenance/cardback-w2-default.md`. Restrisiken dokumentiert (Karo-As-Assoziation, Spielgröße → harter Tisch-Test vor Release). Runden 1-3 archiviert.
- [x] **Charakter-Render-Stil: O (Öl/Gouache painterly)** - mit Auflagen: (1) Pflicht-Paintover pro finalem Porträt (Midjourney-Öl-Tell), (2) V bleibt Konsistenz-/Slop-Fallback bis painterly über 1 kompletten Charakter × alle Emotionen bewiesen (Konsistenztest VOR Vollproduktion, CLAUDE.md §5), (3) Anker/LoRA, (4) Stil-Test künftig mit kanon-konformer Garderobe (Confound raus), (5) Monogramm fliegt aus dem QA-Scoring.

## Als Nächstes (Loop, kein Gate)

- [ ] **JETZT: Clean Karten-Vorderseiten** (code-gerendert, Premium-Material statt weißer Platzhalter - größter taste-gate-Befund) + `CardBack` im Deal einsetzen.
- [ ] **Umsetzungs-To-dos Rücken (Tobsi 8.7., kein Geschmack):** (a) Print-Master-Monogramm bei Druckdaten-Abnahme auf Vektor-Schärfe prüfen (App = SwiftUI-Text, immer crisp; Garbling nur in Raster-Mockups), (b) Fächer-Kontaktschatten am echten SpriteKit-Tisch mit Kerzenlicht-Layer verifizieren (Schatten muss mit Lichtstimmung spielen, nicht dagegen).
- [ ] Game-Feel-Pass: Deal/Meld-Juice (40 ms), „Der Poch"-Tischschlag, Ketten-Kaskade, Tells - unter Parameter-Lock (§4). Morph-2-Label-Crossfade = Hand-Gate (Geräte-Tuning). ERLEDIGT 8.7.: Pott-Material, Slider-Rille, Wand-Pfeiler (Räte 5->8); Trumpf-Beat §6a + Melde-Strom §6a-b komplett (Kaskade, Freeze, Puls, Münzflüge, rollende Zähler, Prä-Melde-Anzeige, Skip, reduceMotion). Poch-Tischschlag ERLEDIGT 8.7. (Zittern 300ms/4pt, Chip-Stapel, Diff-Beweis). OFFEN: Münz-Bogenbahn (Hand-Gate), Balatro-Kollaps-Stufe-2 + Threshold-Sim, Sound.
- [ ] Lokalisierungs-Katalog (`Localizable.xcstrings`) anlegen, bevor weitere UI-Strings wachsen (§8-Schuld aus dem Fundament).
- [ ] Bot-Interplay am Gerät durchspielen (P2-Flow läuft headless ungetestet).

### Phasen-Morph - erledigt (8.7. nachts)
- [x] `matchedGeometryEffect` + Namespace über alle drei Akte (Tokens, Poch-Tile→Pott, Mulden→Echo-Dots), `.position`-Frames, Spring 0.55 (Parameter-Lock). Bewegungs-QA: 9/9 und 8/7.
- [x] Feel-Pass-Befunde notiert: Token-Label-Crossfade undeutlich (Morph 2), Poch-Pott Glow→Material, Slider-Materialität.

### Phase-3-Layout - erledigt (8.7. nachts)
- [x] `Phase3View`: Kaskaden-Präsentation 180 ms/Karte + 350-ms-Beat-Drop (Parameter-Lock-Tokens), Gold-Stopper, Anspielrecht-Signal, Schiefer-Tokens (§5c P3), lesbare Ketten-Sequenz, Rundenende-Banner.
- [x] `GameState`: revealedPlays-Zeiger, displayedHand, Bot-Anspiel (niedrigste Karte, Platzhalter), humanLead; DEBUG `-ausspielStart`/`-autoLead`.
- [x] Live-Verifikation: Kaskade + Ass-Stopper-Gold + Rundenende im Simulator geschossen; Build 0 Warnings.

### Phase-2-Layout - erledigt (7.7. nachts)
- [x] `Phase2View` (Kardinalpunkte §5c, Poch-Pott-Held §5b, Ring-Echo), Biet-Slider mit beschrifteter Limit-Wand + `.rigid`-Bump, Passen/Mitgehen/Pochen-Erhöhen, `.heavy`-Poch-Haptik, Ergebnis-Banner (auch „ohne Aufdecken - Bluff bleibt geheim").
- [x] `GameState`: Phase-2-API (Pott, Wand-Besitzer, legale Aktionen), Bot-Loop mit BotBrain-Denkpausen, Action-Bubbles; `CardFace` extrahiert (Kunststück-Glow §6b); DEBUG-Arg `-pochenStart`.
- [x] Build 0 Warnings, Screenshots beider Akte verifiziert, gemini-vision-QA.

### Sichtung 1 - erledigt (7.7. abends)
- [x] Kartenrücken-Frage beantwortet (JA: Trumpf-Beat, Gegner-Hände, Cosmetic-Anker, Marke) + 8 Richtungen generiert (FLUX/Recraft/PIL), QA via gemini-vision + GPT-Räte, 8 Retakes.
- [x] Charakter-Stil-Proben (3 Richtungen × Nova/Blade), gleiche QA.
- [x] Cockpit-Umbau: Jetzt/Wartet/Registriert-Struktur, Galerien eingebettet (KEINE ZIPs mehr - neue Dauer-Regel), Lightbox + Spielgrößen-Mini + Copy-Antworten.

## Roadmap bis Release

- [ ] Meta-Progression: Charakter-Roster (BotProfile-Mapping), Deck-Unlocks, Gilden-Chronik, Rangliste. Economy per Headless-Sim kalibrieren.
- [ ] Sound + Haptik.
- [ ] IAP (StoreKit-2-Unlock 4,99 €, Restore, Compliance-Paket).
- [ ] Tutorial / Onboarding.
- [ ] Lokalisierung 7 Sprachen (ab erstem String, Transcreation).
- [ ] TestFlight-Beta, Store-Assets, Launch.

## Gate 0.5 - Naming/Recht (offen)

- [ ] EUIPO/TMview-Ähnlichkeitsrecherche (Klassen 9/28/41).
- [ ] Nizza-Klassen EM 008834087 („pocH") verifizieren; Wortlaut IR 1473157 identifizieren.
- [ ] ASC-Rating-Fragebogen in App Store Connect trocken durchspielen (Tobsi-Login).
- [x] Kernbefund: „Poch" gemeinfrei/generisch (Straßburg 1441) → schützbar ist die Komposit-Marke „POCH 1441". Details: `tasks/naming-diligence-2026-07-06.md`.

## Tobsi-Gates (brauchen dich)

- Geschmacks-Abnahmen: Charaktere, Theme-Held, Juice-Feel, Sound.
- ASC-Login (Rating), Anwalts-Kurzprüfung Name vor ASC-App-Record.
- Playtest-Rekrutierung (Beta).
