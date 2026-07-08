# Poch 1441 - Todo / Status

**Stand:** 8. Juli 2026, Abend (nach Mockup-Delta-Session). Kanon: `tasks/konzept.md` · Kurzfassung: `CLAUDE.md §0`
**Nordstern-Mockup:** `artifacts/style-ref/mockup-anchor.png` + iCloud TEMP `935b2c31-45a6-44d1-b74d-0dfd39cc8817.JPG`
**Letzter Commit:** `0.7.1` - Phase-1-Ring-Skalierung, alles gepusht

---

## GERADE ERLEDIGT (diese Session, 0.6.5 → 0.6.7)

Die komplette Karten-Ästhetik ist neu und von Tobsi iterativ abgenommen („besser") - NICHT wieder anfassen ohne Auftrag:

- **0.6.5 - Final-Template:** Alle 32 Vorderseiten aus EINER deterministischen Vorlage
  (`tools/gen_cards_final.py`, kein KI-Bild): weiße Karte, große Bold-Sans-Indizes
  (Helvetica Neue Bold) mit Pip darunter (oben-links + unten-rechts, identisches Tile 180°
  gedreht), htdebeer-Hoffiguren per SVG-Chirurgie OHNE Alt-Indizes, Asse mit großem
  Zentral-Pip, klassische Pip-Raster. @2x 312×444 + @3x 468×666. Eckradius = CardFace-Clip.
- **0.6.6 - Mockup-Tiefe:** SVG-Recolor auf tiefe Juwelen-Töne (Gewänder-Weinrot #7E2333,
  Pip-Karmesin #B51D27, Antikgold #B8933A, staubiges Royal #465685 - Gewänder-/Pip-Rot
  in der Quelle disjunkt, getrennt gemappt), Papier-Textur (seeded rng(1441), identisch
  auf allen 32), Pip-Tiefengradient (Licht immer von oben).
- **0.6.7 - Karton-Wölbung:** `App/CardWarp.metal` als SwiftUI-layerEffect in
  `CardFace.swift` - obere Ecken rollen subtil hoch (2.4pt × scale), Einroll-Zug an den
  Seiten, Licht erzählt die Krümmung, deterministischer Seed pro Karte. Layout unverändert
  (padding/-padding-Paar). Kontaktschatten kräftiger (0.5/4/2.5). taste-gate: PASS.
- **Index-Report geprüft:** „Falsche Indizes in verdeckten Ecken" = Overlap-Illusion,
  KEIN Bug (obere rechte Ecke ist designbedingt leer; „fremder" Index gehört der
  Nachbarkarte; Gewandfarbe verrät seit Recolor nicht mehr die Kartenfarbe - Index zählt).
- Einmalig installiert: Xcode MetalToolchain (~700 MB, Build-Voraussetzung für .metal).
- Provenance: `assets/provenance/cardfronts-final.md`. QA-Loop: gemini-vision 3 Runden
  + taste-gate, Befunde pixelweise verifiziert (nie blind übernommen).

**Offener Feinschliff-Kandidat (nur falls Tobsi es live stört):** taste-gate-Restpunkt
„Kantenbeleuchtung stellenweise zu uniform scharf" (CardWarp-Shading-Konstanten).

**Geparkte Tobsi-Entscheidung (aus 0.6.6, unbeantwortet):** Custom-Hoffiguren-Sichtung
via FLUX neben dem jetzigen Stand? (Letzte echte Mockup-Abweichung: einzigartige
Charakter-Gesichter. Konsistenz-Risiko dokumentiert.)

**Cleanup-Kandidaten (erwähnt, nicht beauftragt):** untrackter Duplikat-Ordner
`Poch1441/Assets.xcassets/` (Build nutzt nur `App/`); toter Zahlkarten-Rendering-Code
in `CardFace.swift` (numberCard/pipGrid/indexBlock, seit 0.6.4 ungenutzt).

---

## JETZT: Mockup-Delta (verbleibend, Reihenfolge nach Priorität)

### PHASE 3 - AUSSPIELEN
- **IST:** Kleine Karten-Reihen (face-down + face-up), winzige Kartenstapel, viel leerer Raum
- **SOLL (Mockup):**
  - GROSSER DRAMATISCHER FÄCHER der 60-70% des Screens einnimmt
  - Gespielte Karten (K♠, A♠, J♠, 10♠) als breiter angewinkelter Fan
  - Poch-Medallion (Herz-Symbol) prominent im Zentrum
  - Spielerhand-Fächer unten (ebenfalls angewinkelt)
- **Dateien:** `Phase3View.swift` - PlayedCardsFan (war mal implementiert, wurde reverted)
- **Technisch:** Korrekte SwiftUI Fan-Implementierung ohne GeometryReader+position-Konflikt
  (alter Bug). Richtig: `.offset(x:).rotationEffect(.degrees(), anchor: .bottom)` in ZStack
  (so macht es der Phase-1-Fächer in `ContentView.swift::handView`)

### PHASE 2 - POCHEN
- **IST:** Poch-Pott dominiert Mitte, Gegner-Tokens (B/N/G) drumherum, Slider kaum sichtbar
  links, Karten in horizontaler Reihe, Buttons „Passen" + „Pochen 1!"
- **SOLL (Mockup):**
  - Slider: LINKS, vertikal, groß + Label „RANGE"
  - Poch-Ring: RECHTS, kompakt, zeigt A/K/Q/J/10 an den Positionen
  - Action-Buttons: 2×2-Grid mittig (PASS | MITGEHEN / ERHÖHEN | ALL-IN → ohne ALL-IN)
  - Charakter-Portraits: UNTEN links/rechts mit Status-Bubble („PASSED")
  - Karten: kleiner Fächer ganz unten
- **Dateien:** `Phase2View.swift` - komplettes Layout-Refactoring nötig

### PHASE 1 - MELDEN
- **IST:** Ring relativ klein (ca. 40% Screen), Tokens oben numerisch, Buttons ↺ + „Pochen ›"
  über Karten (Fächer selbst ist seit dieser Session mockup-nah)
- **SOLL (Mockup):**
  - Ring ist GROSS, dominiert 55-60% des Screens
  - Mulden-Values als große Chip-Anzeige (+130, +20 etc.), nicht kleine Zahlen
  - Keine sichtbaren Buttons im normalen Spielfluss (oder minimal)
  - Gegner-Tokens: klein, diskret (nur Buchstabe + Stack)
- **Dateien:** `ContentView.swift` (handView, ringView, opponentTopBar, phase1Footer)

---

## Fertig / Eingefroren

- [x] **Engine (PochKit) - Gate A.** 55 Tests, 0 Failures. Alle 3 Phasen, Combos, Dealing, Bots.
- [x] **Kartenrücken W2** - FINAL, Exekutions-Befehl ausgeführt. `CardBack.swift` + Provenance.
- [x] **Kartenvorderseiten Final-Template 0.6.5-0.6.7** - siehe oben. Generator:
  `tools/gen_cards_final.py` (deterministisch, reproduzierbar - bei Änderungswunsch
  Konstanten im Skript anpassen und neu laufen lassen, NIE einzelne PNGs von Hand).
- [x] **Kern-Trias-Feel-Spec v1 komplett** (8.7.): Trumpf-Beat §6a, Melde-Strom §6a-b,
  Poch-Tischschlag §6b, Balatro-Kollaps §6a-e (T=12, 11.557-Runden-Sim), Eiszeit-Vakuum §6c.
- [x] **Phase-1-Fächer** - angewinkelt, Bleed-Ästhetik, jetzt mit Karton-Wölbung.
- [x] **Phasen-Morph** - matchedGeometryEffect über alle 3 Akte.
- [x] **Design-Kanon** (`konzept.md`): alle §-Specs dokumentiert.
- [x] **Naming/Recht:** „POCH 1441" schützbar als Komposit-Marke.

---

## GERADE ERLEDIGT (Mockup-Delta-Session 0.6.9 → 0.7.1)

- [x] **0.6.9 - Phase-3-Fan:** PlayedCardsFan (scale 2.0, bis 66°), Poch-Medaillon (♥), handFan (angewinkelt)
- [x] **0.7.0 - Phase-2-Layout:** Slider links (vertikal), Ring rechts (kompakt, Tiles mit Chip-Werten),
  Portraits UNTEN, handFan (kleiner Fächer)
- [x] **0.7.1 - Phase-1-Ring:** ringRadius 130→145, Chip-Werte mit „+"-Präfix, Token diskret

## GERADE ERLEDIGT (Morph-QA-Session, 8. Juli 2026 Abend)

- [x] **Morph-QA** - Alle drei Phasenwechsel am Simulator durchgespielt:
  - Phase 1 (Melden): Ring, Fan, „Pochen ›"-Button - alles erreichbar, kein Crash
  - Phase 1→2 Morph: matchedGeometryEffect läuft sauber (kein stuck-State)
  - Phase 2 (Pochen): Slider links, Ring rechts, Portraits unten, Passen/Pochen-Buttons OK
  - Phase 2→3 Morph: Übergang nach Poch-Pott-Zuteilung klappt
  - Phase 3 (Ausspielen): Gespielte Karten im Fan sichtbar, Portraits oben
  - Phase 3→1 (neue Runde): Sauberer Reset zurück zu Phase 1
  - **Keine Crashes, keine stuck-Animationen, vollständiger Loop funktioniert.**

## Nächste Session - Empfohlene Reihenfolge

1. **Phase-1 Footer** - Pochen›-Button minimaler / noch diskreter (todo §SOLL)
2. **Phase-2 Tierschlag-Tuning** - Poch-Pott-Wachstum sichtbarer, kompakter Ring polieren
3. **Phase-3 Fan-Dramatik** - Mit mehr gespielten Karten prüfen ob 60-70% Screen erreicht wird

Wiedereinstieg: „Lies tasks/todo.md, weiter mit Phase-1 Footer."

---

## Offene Tobsi-Gates

- Custom-Hoffiguren-Sichtung ja/nein (geparkt, siehe oben)
- Charaktere (Stil O = painterly, Konsistenztest VOR Vollproduktion)
- Theme-Held A/B
- Juice-Feel, Sound, Haptik
- ASC-Login (Rating), Anwalts-Kurzprüfung
- Lokalisierungs-Katalog (`Localizable.xcstrings`)
- Bot-Interplay am Gerät

## Roadmap bis Release

- [ ] Meta-Progression: Charakter-Roster, Deck-Unlocks, Economy-Sim
- [ ] Sound + Haptik
- [ ] IAP (StoreKit-2, 4,99 €)
- [ ] Tutorial / Onboarding
- [ ] Lokalisierung 7 Sprachen
- [ ] TestFlight-Beta, Store-Assets, Launch
