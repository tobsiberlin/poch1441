# Kartenrücken-Dossier - Wiederaufnahme-Kit

**Stand:** 8. Juli 2026 · **Status: ENTSCHIEDEN (Tobsi):** W2-Facetten-Siegel + Kontaktschatten + Graphit-Kante + „1441"-Signet-Paar ist der Default-Rücken („nimm erst mal das"). **Später änderbar** - dieses Dossier ist der Wiedereinstieg ohne Nullstart.

---

## 1. Der Final-Stand (was gilt)

- **Motiv:** W2 = facettierte Siegel-Raute, 8 Facetten punktsymmetrisch gepaart (i = i+4), Innenring 0.64 (Fächer-Test FC), Token-Farben Gold/Granat/Smaragd/Amethyst + Platin-Hairlines, dunkler Kern.
- **Signet:** nur „1441" (Didot, Mediävalziffern), dezent, IMMER als gespiegeltes Eck-Paar (Einzel-Monogramm bräche die Punktsymmetrie). „P" verworfen (mehrdeutig); „Poch 1441" ausgeschrieben lebt bei Icon/Splash/Store.
- **Kante:** neutrale Graphit-Hairline (98,98,104) auf der Kartenkante - Fächer-Trennung ohne Farbrauschen (Wette 8.7.: schlägt Farbrand UND rahmenlos, Ranking 4>3>1>2).
- **Kontaktschatten:** RENDER-Eigenschaft der Fächer-Darstellung (nie ins Asset!) - in SwiftUI `.shadow(...)` pro überlappender Karte; am SpriteKit-Tisch gegen den Kerzenlicht-Layer verifizieren (offenes Umsetzungs-To-do).
- **Beweis:** Pixel-Diff Karte vs. 180°-gedreht = [0, 0, 0] (Orientierungs-Leak unmöglich). Nach JEDER Änderung neu führen.

## 2. Dateien & Code (Quelle der Wahrheit)

| Was | Wo |
|---|---|
| Print-Master (1000×1400) | `artifacts/sichtung1/card-W2.png` |
| Engine-Rendering (Farben aus DesignTokens) | `App/CardBack.swift` |
| Motiv-Konstruktion (W2-final) | `tools/gen_sichtung2_wappen.py::lozenge_final()` |
| Compositing (Rahmen, Signet, Symmetrisierung, Kante) | `tools/gen_sichtung1_composite.py::card_back(...)` mit `sym=True, edge=(98,98,104)` |
| Fächer-/Schatten-Tests | `tools/gen_faecher_schatten.py`, `gen_faecher_mono.py`, `gen_faecher_test.py` |
| Kessel-Motive (Unlock-Pool-Kandidaten) | `tools/gen_kessel_varianten.py` (KA-KF) |
| Provenance + Entscheidungskette | `assets/provenance/cardback-w2-default.md` |
| Externe Prompts | iCloud-TEMP `poch1441-kartenruecken-prompts.md` (Kopie: §4 unten) |

**Regenerieren des Finals (ein Befehl):**
```bash
cd /Users/tobsi/poch1441 && python3 - <<'EOF'
import importlib.util
from PIL import Image, ImageChops
spec = importlib.util.spec_from_file_location("w", "tools/gen_sichtung2_wappen.py")
w = importlib.util.module_from_spec(spec); spec.loader.exec_module(w)
w.comp.card_back("W2", art=w.lozenge_final(), save_card=True, sym=True, edge=(98, 98, 104))
card = Image.open("artifacts/sichtung1/card-W2.png")
print("Symmetrie:", [e[1] for e in ImageChops.difference(card, card.rotate(180)).getextrema()])
EOF
```

## 3. Die Entscheidungskette (warum es so aussieht)

1. **Runde 1 (A-H, generiert):** A (Mulden-Ring als Lünette) = Casino-Read → verworfen. FLUX drifteten wiederholt in Gold-Lünette/Ornament-Slop → Vektor-Weg.
2. **Runde 2 (X1-X4, Vektor-Synthese):** Gestalt-Lesson - **geschlossener Farbkreis = Rad, egal welches Material**; X4 = „casino-frei durch Marken-Verzicht" (Gegenfalle).
3. **Runde 3 (W/B/K, Gestalt aufgebrochen):** W2 gewinnt ungeprimt („Spielkarten, Luxus-Accessoire, Mysterium").
4. **Finalisierung:** Punktsymmetrie-Paarung (8 Facetten), Fächer-Test → Innenring 0.64, Monogramm-Matrix → „1441" Paar, Wette → Schatten + Graphit statt Farbrand.
5. **Kessel-Runden (KA-KF):** keiner schlägt W2s Profil; KB/KE stärkste → **Unlock-Deck-Pool** (§7.2).

## 4. Externe Generierungs-Prompts (Kopie)

Grund (FLUX 1.1 Pro, Seed 93442): `matte black lacquer surface with an extremely subtle debossed geometric texture, tone-on-tone black-on-black, almost invisible, soft directional light from top, premium playing card back ground texture, no color, no gold, no metal, no chrome, unsigned, no watermark, no text, no letters, no numbers, no typography, no logo`

Komplett-Rücken (Motiv-Ideen): siehe iCloud-TEMP-Datei; Kern-Guards: keine KI-Schrift, kein geschlossener Farbkreis, matte Juwelen (C5A059 / 8E2A43 / 1A5E4E / 4A2E65 / E2E8F0), ungeprimter Assoziations-Check.

## 5. Wiedereinstiegs-Checkliste (falls wir den Rücken nochmal anfassen)

1. Dieses Dossier + `assets/provenance/cardback-w2-default.md` lesen (nicht die Runden wiederholen!).
2. Neues Motiv als Vektor in `gen_kessel_varianten.py`-Stil konstruieren ODER extern generieren (Prompts §4) - immer punktsymmetrisch denken.
3. Durch die Pipeline: ungeprimter Assoziations-Test → Compositing (sym=True, edge=Graphit) → **Fächer-Test mit Schatten** (der ehrliche Test) → Pixel-Beweis [0,0,0].
4. `CardBack.swift` paritätisch nachziehen (Code = Source of Truth der Farben).
5. Cockpit-Sichtung mit Copy-Antworten; Tobsi entscheidet.
