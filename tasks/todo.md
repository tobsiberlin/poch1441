# Poch 1441 - Todo / Status

**Stand:** 8. Juli 2026. Kanon: `tasks/konzept.md` · Kurzfassung: `CLAUDE.md §0`
**Nordstern-Mockup:** `artifacts/style-ref/mockup-anchor.png` + iCloud TEMP `935b2c31-45a6-44d1-b74d-0dfd39cc8817.JPG`
**Letzter Commit:** `68225e2` - Kartenfächer Phase 1 (Bleed-Ästhetik)

---

## JETZT: Mockup-Delta (8.7. Abend - Pixel-für-Pixel-Vergleich)

Der aktuelle Stand hat massive Abweichungen vom Nordstern-Mockup. Reihenfolge nach Priorität:

### KARTEN-ÄSTHETIK (kritisch, alle Phasen)
- **IST:** SVG-Assets (htdebeer, LGPL) - Bildkarten zweiköpfig korrekt, aber zu DUNKEL und pixelig in der App-Darstellung
- **SOLL (Mockup):** Karten sind WEISS/sehr hell, crisp, groß, dominieren das Bild
- **Fix:** SVG-Assets bei @3x rendern (aktuell @2x = 156×225px), Helligkeit prüfen, ggf. neu rendern mit höherer Auflösung
- **Assets:** `Assets_Raw/svg-cards/png/` → `App/Assets.xcassets/Cards/`
- **Code:** `CardFace.swift` - `svgCard(named:)` Funktion

### PHASE 1 - MELDEN
- **IST:** Ring relativ klein (ca. 40% Screen), Tokens oben numerisch (1/2/3), Fächer angewinkelt aber Karten zu klein/dunkel, Buttons ↺ + "Pochen ›" über Karten
- **SOLL (Mockup):**
  - Ring ist GROSS, dominiert 55-60% des Screens
  - Mulden-Values als große Chip-Anzeige (+130, +20 etc.), nicht kleine Zahlen
  - Karten-Fächer: GRÖSSER, weißere Karten, Fan-Bogen mit Bleed
  - Keine sichtbaren Buttons im normalen Spielfluss (oder minimal)
  - Gegner-Tokens: klein, diskret (nur Buchstabe + Stack)
- **Dateien:** `ContentView.swift` (handView, ringView, opponentTopBar, phase1Footer)

### PHASE 2 - POCHEN
- **IST:** Poch-Pott dominiert Mitte, Gegner-Tokens (B/N/G) drumherum, Slider kaum sichtbar links, Karten in horizontaler Reihe, Buttons "Passen" + "Pochen 1!"
- **SOLL (Mockup):**
  - Slider: LINKS, vertikal, groß + Label "RANGE"
  - Poch-Ring: RECHTS, kompakt, zeigt A/K/Q/J/10 an den Positionen
  - Action-Buttons: 2×2-Grid mittig (PASS | MITGEHEN / ERHÖHEN | ALL-IN → ohne ALL-IN)
  - Charakter-Portraits: UNTEN links/rechts mit Status-Bubble ("PASSED")
  - Karten: kleiner Fächer ganz unten
- **Dateien:** `Phase2View.swift` - komplettes Layout-Refactoring nötig

### PHASE 3 - AUSSPIELEN
- **IST:** Kleine Karten-Reihen (face-down + face-up), winzige Kartenstapel, viel leerer Raum
- **SOLL (Mockup):**
  - GROSSER DRAMATISCHER FÄCHER der 60-70% des Screens einnimmt
  - Gespielte Karten (K♠, A♠, J♠, 10♠) als breiter angewinkelter Fan
  - Poch-Medallion (Herz-Symbol) prominent im Zentrum
  - Spielerhand-Fächer unten (ebenfalls angewinkelt)
- **Dateien:** `Phase3View.swift` - PlayedCardsFan (war mal implementiert, wurde reverted)
- **Technisch:** Korrekte SwiftUI Fan-Implementierung ohne GeometryReader+position-Konflikt (alter Bug). Richtig: `.offset(x:).rotationEffect(.degrees(), anchor: .bottom)` in ZStack

---

## Fertig / Eingefroren

- [x] **Engine (PochKit) - Gate A.** 55 Tests, 0 Failures. Alle 3 Phasen, Combos, Dealing, Bots.
- [x] **Kartenrücken W2** - FINAL, Exekutions-Befehl ausgeführt. `CardBack.swift` + Provenance.
- [x] **Kartenvorderseiten - SVG-Assets (htdebeer/SVG-cards, LGPL)** - 32 klassische Spielkarten eingebunden. Bildkarten (K/D/B) zweiköpfig korrekt, Zahlkarten (7-10) mit Pip-Anordnung. Aktuell @2x - Auflösungs-Fix noch offen.
- [x] **Kern-Trias-Feel-Spec v1 komplett** (8.7.): Trumpf-Beat §6a, Melde-Strom §6a-b, Poch-Tischschlag §6b, Balatro-Kollaps §6a-e (T=12, 11.557-Runden-Sim), Eiszeit-Vakuum + Straf-Strom §6c.
- [x] **Phase-1-Fächer** - angewinkelt, Bleed-Ästhetik, Buttons kompakt oben.
- [x] **Phasen-Morph** - matchedGeometryEffect über alle 3 Akte.
- [x] **Design-Kanon** (`konzept.md`): alle §-Specs dokumentiert.
- [x] **Naming/Recht:** „POCH 1441" schützbar als Komposit-Marke.

---

## Nächste Session - Empfohlene Reihenfolge

1. **Karten-Ästhetik fixen** (SVG @3x re-rendern, Helligkeit) - schneller Win, alle Phasen profitieren
2. **Phase 3 Fan** - PlayedCardsFan korrekt implementieren (war gebaut, dann reverted wegen Bugs)
3. **Phase 2 Layout** - Slider links / Ring rechts / Portraits unten
4. **Phase 1 Ring-Skalierung** - Ring größer, Mulden-Values prominenter

---

## Offene Tobsi-Gates

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
