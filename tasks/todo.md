# Poch 1441 - Todo / Status

**Stand:** 7. Juli 2026. Kanon: `tasks/konzept.md` · Kurzfassung: `CLAUDE.md §0` · lebendes Cockpit: `artifacts/poch-1441-cockpit.html` (auch in iCloud-TEMP).

## Fertig

- [x] **Engine (PochKit) - Gate A eingefroren.** Alle 3 Phasen (Melden/Pochen/Ausspielen), Combos, Dealing (8/8/8/7), Match-Modi, Bot-Profile. Deterministisch, headless simulierbar. **55 Tests, 0 Failures.**
- [x] **Design-Kanon** (`konzept.md`): Produkt-Linie X, Balatro-Feel-nicht-Struktur, Farbe=Label (Juwelen), Poch-Ring, Kern-Trias-Feel-Specs, Meta-Architektur, Phasen-Morph.
- [x] **SwiftUI-Fundament:** Ring-Geometrie (8 Mulden + Mitte), GameState←PochKit-Bridge (echte Werte), 2-Theme-System (Premium-matt + Vivid), MatchSource-Seam.
- [x] **Material-Fundament (Iter. 1-3):** warmes Tinten-Schwarz + Vignette, Metallkanten statt Dauer-Glow, gefräste Ring-Linie + Mitte-Pott. Beide Themes grün + screenshot-verifiziert.

## Zum Entscheiden (Tobsi-Gate)

- [ ] **AKTIV - Kartenrücken Runde 3 (W/B/K):** Rad-Gestalt aufgebrochen (Tobsi-Richtungen 7.7. nachts): W1/W2 Vertikal-Siegel, B1/B2 Brett-Prägung, K1 Kanten-Farbe - alle deterministisch, ungeprimt getestet. **Empfehlung W2** (einziges „Spielkarten + Mysterium"-Profil). Abbruchregel dokumentiert: sitzt nichts → Signet auf Monogramm/1441-Relief, Ring bleibt Brett. X-Runde archiviert (Gestalt-Lesson).
- [ ] **Theme-Held A/B** - geparkt, live am Ende, wenn zwischen Premium-matt und Vivid flippbar.
- [ ] **Geparkt - Garderobe-Frage:** Reviewer forderte periodenechte 1441-Kleidung; widerspricht Modern-first-Kanon. Default: zeitlos-modern. Nur bei Tobsi-Votum ändern.

### Entschieden 7.7. nachts
- [x] **Charakter-Render-Stil: O (Öl/Gouache painterly)** - mit Auflagen: (1) Pflicht-Paintover pro finalem Porträt (Midjourney-Öl-Tell), (2) V bleibt Konsistenz-/Slop-Fallback bis painterly über 1 kompletten Charakter × alle Emotionen bewiesen (Konsistenztest VOR Vollproduktion, CLAUDE.md §5), (3) Anker/LoRA, (4) Stil-Test künftig mit kanon-konformer Garderobe (Confound raus), (5) Monogramm fliegt aus dem QA-Scoring.

## Als Nächstes (Loop, kein Gate)

- [ ] **JETZT: Phasen-Morph-Transitionen** (`.matchedGeometryEffect`, §5b) - P2/P3-Layouts stehen, Ziel-Positionen jetzt ableitbar. Ring → Kompression (P2) → Backdrop (P3), Tokens Top-Bar → Kardinalpunkte.
- [ ] Clean-moderne Karten aufs Blatt (Default-Deck, code-gerendert) statt Platzhalter; Rücken nach Tobsi-Urteil.
- [ ] Game-Feel-Pass: Deal/Meld-Juice (40 ms), „Der Poch"-Tischschlag, Ketten-Kaskade, Tells - unter Parameter-Lock (§4). Dazu P2-QA-Befund: Slider generisch, Limit-Wand nur Text → Wand als physisches Objekt gestalten.
- [ ] Lokalisierungs-Katalog (`Localizable.xcstrings`) anlegen, bevor weitere UI-Strings wachsen (§8-Schuld aus dem Fundament).
- [ ] Bot-Interplay am Gerät durchspielen (P2-Flow läuft headless ungetestet).

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
