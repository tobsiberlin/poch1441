# Poch 1441 - Todo / Status

**Stand:** 7. Juli 2026. Kanon: `tasks/konzept.md` · Kurzfassung: `CLAUDE.md §0` · lebendes Cockpit: `artifacts/poch-1441-cockpit.html` (auch in iCloud-TEMP).

## Fertig

- [x] **Engine (PochKit) - Gate A eingefroren.** Alle 3 Phasen (Melden/Pochen/Ausspielen), Combos, Dealing (8/8/8/7), Match-Modi, Bot-Profile. Deterministisch, headless simulierbar. **55 Tests, 0 Failures.**
- [x] **Design-Kanon** (`konzept.md`): Produkt-Linie X, Balatro-Feel-nicht-Struktur, Farbe=Label (Juwelen), Poch-Ring, Kern-Trias-Feel-Specs, Meta-Architektur, Phasen-Morph.
- [x] **SwiftUI-Fundament:** Ring-Geometrie (8 Mulden + Mitte), GameState←PochKit-Bridge (echte Werte), 2-Theme-System (Premium-matt + Vivid), MatchSource-Seam.
- [x] **Material-Fundament (Iter. 1-3):** warmes Tinten-Schwarz + Vignette, Metallkanten statt Dauer-Glow, gefräste Ring-Linie + Mitte-Pott. Beide Themes grün + screenshot-verifiziert.

## Zum Entscheiden (Tobsi-Gate) - Sichtung 1 liegt im Cockpit (7.7. abends)

- [ ] **AKTIV - Kartenrücken-Signet:** 8 Richtungen (A-H) QA-gefiltert im Cockpit. Empfehlung A (Mulden-Ring, Markenlogik GPT-Top-1 + Kanon §4); stärkste Alternativen E (Art-Deco), C (Schockwelle). Antwort-Buttons im Cockpit.
- [ ] **DANACH - Charakter-Render-Stil:** 6 Proben (O/V/S je Nova+Blade) im Cockpit. Empfehlung O (Öl/Gouache painterly - Kanon + GPT + Wärme-Scores 9/7). Nach Urteil: Stil ankern (Referenz-Familie, ggf. LoRA), dann Roster.
- [ ] **Theme-Held A/B** - geparkt, live am Ende, wenn zwischen Premium-matt und Vivid flippbar.

## Als Nächstes (Loop, kein Gate)

- [ ] **JETZT: Phase-2-Layout (Pochen):** Biet-Slider + Limit-Wand (personifiziert, „rückt hoch nach Passen"), PASS/MITGEHEN/ERHÖHEN, violetter Poch-Pott als Held, Kardinalpunkte-Präsenz (§5c). Platzhalter-Tokens bis Charakterstil entschieden.
- [ ] Phase-3-Layout (Ausspielen): Karten-Fächer + Ketten-Kaskade (180 ms konstant, Beat-Drop 350 ms).
- [ ] Phasen-Morph-Transitionen (`.matchedGeometryEffect`) - Ziel-Positionen erst nach P2/P3-Layouts (§5b).
- [ ] Clean-moderne Karten aufs Blatt (Default-Deck, code-gerendert) statt Platzhalter; Rücken nach Tobsi-Urteil.
- [ ] Game-Feel-Pass: Deal/Meld-Juice (40 ms), „Der Poch", Ketten-Kaskade, Tells - unter Parameter-Lock (§4).

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
