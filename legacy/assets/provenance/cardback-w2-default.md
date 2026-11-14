# Provenance - Default-Kartenrücken „W2-Final" (Facetten-Siegel)

**Status:** FINAL / Asset-Freeze (Tobsi-Entscheid + Exekutions-Befehl, 7.7.2026 nachts)
**Dateien:** `artifacts/sichtung1/card-W2.png` (Print/Marketing-Master 1000x1400),
`App/CardBack.swift` (Engine-Rendering, Source of Truth der Farben = `DesignTokens.swift`)

## Konstruktion (deterministisch, kein generiertes Motiv)
- Signet: facettierte Siegel-Raute, 8 Facetten PUNKTSYMMETRISCH (Facette i = i+4),
  Farben exakt aus DesignTokens (Gold C5A059, Rosé 8E2A43, Smaragd 1A5E4E,
  Amethyst 4A2E65, Platin-Hairlines), gezeichnet in PIL (4x supersampled):
  `tools/gen_sichtung2_wappen.py::lozenge_final()`.
- Monogramm P·1441: Vektor-Overlay (Didot, 4x supersampled), rotationssymmetrisches
  Paar - NIE generiert (Anti-Slop §5).
- Symmetrie-Garantie: Grund + Artwork + Karte mathematisch symmetrisiert
  (Blend mit 180-Grad-Rotation). **Beweis 7.7.2026: Pixel-Diff Karte vs. gedrehte
  Karte = [0, 0, 0] je Kanal.** Kein Orientierungs-Leak.

## KI-Anteil (nur Textur-Grund)
- Grund-Textur: Replicate `black-forest-labs/flux-1.1-pro`, Seed 93442, 7.7.2026,
  Prompt siehe `Assets_Raw/sichtung1/log.json` (Label GR2) - matte schwarz-auf-schwarz
  Lack-Textur ohne Motiv/Farbe/Schrift. Lizenz: Replicate-Terms (kommerzielle Nutzung
  der Outputs), Nachweis-PDF im Release-Paket nachziehen (Musik-/Asset-Lizenzordner).

## Menschliche Entscheidungsschritte
- Runde 1 (A-H, FLUX/Recraft) → Tobsi: A = Casino-Read, verworfen.
- Runde 2 (X1-X4 Vektor-Synthese) → Tobsi-Reviewer: Rad-GESTALT ist der Trigger.
- Runde 3 (W/B/K, Gestalt aufgebrochen) → W2 gewinnt (ungeprimt: „Spielkarten,
  Luxus-Accessoire, Mysterium").
- Finalisierung: Punktsymmetrie-Auflage, Monogramm-Crisp-Auflage, Engine-Branding.
- Offenes Rest-Risiko (dokumentiert): Karo-As-/Luxusartikel-Assoziation, Wirkung bei
  Spielgröße - harter Test am echten Tisch-Layout vor Release.

## Nachschärfung vor Print-Master (8.7.2026, Tobsi-Review des Freeze)
- **Fächer-Test** (5 überlappende Rücken als Gegnerhand, 3 Fassungen): Urteil
  gemini-vision Ranking FC > FB > FA - Innenfacetten-Vergrößerung (0.64 statt 0.5)
  = ruhigster Fächer bei voller Signet-Präsenz. In Print-Master UND CardBack.swift
  übernommen (Code-Parität); Symmetrie-Beweis erneut [0, 0, 0].
- **Karo-As-Assoziation entschärft** (Tobsi): Facettentiefe + 4 Juwelentöne + Monogramm
  lesen als Signet, nicht als Kartenwert. Bindende Farbregel: kein Ton dominant,
  Granatrot nie flächig.

## Signet-Entscheid (8.7.2026, Tobsi + Vergleichstest M1/M2/M3)
- Monogramm = **nur „1441"**, dezent (Didot-Mediävalziffern) - die Zahl trägt die
  Marke, das P entfällt (mehrdeutig). Gemini-Ranking M2 > M3 (leer) > M1 (geschwätzig).
- Immer als gespiegeltes Eck-Paar: ein Einzel-Monogramm bräche die Punktsymmetrie
  („1441" ist gedreht nicht „1441") - das Paar ist der Preis des Orientierungs-Beweises.
- Voller Name „Poch 1441" lebt überall, wo die Marke neu gelernt wird (App-Icon,
  Splash, Store, Onboarding) - nie auf dem Rücken.

## Fächer-Wette entschieden (8.7.2026 spät, Tobsi-Hypothese bestätigt)
- Vergleich der Trennungs-Mechanismen im Fächer: rahmenlos / Juwelen-Farbrand (WK2) /
  Kontaktschatten + Graphit-Hairline. **Ranking 4 > 3 > 1 > 2**: Schatten + Graphit
  gewinnt klar (Tobsis Mechanik), der Farbrand landet auf dem letzten Platz und ist
  VERWORFEN. Bonus-Befund: die W2-FACETTEN-Raute trägt die Mechanik besser als die
  W1-Quadranten - der Freeze bleibt bestehen.
- Konsequenz: **Graphit-Hairline (98,98,104) auf der Kartenkante** in Print-Master
  UND CardBack.swift (uniform = punktsymmetrisch unkritisch, Beweis erneut [0,0,0]);
  der **Kontaktschatten ist Render-Eigenschaft** der Fächer-Darstellung im Spiel
  (Game-Feel-Pass), nie ins Asset eingebacken (Lesbarkeits-Licht-Regel §5).
