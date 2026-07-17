# Changelog

## Unreleased

### Geändert
- Neuer verbindlicher `tasks/design-canon-2026.md`: Poch 1441 wird als erstmals
  2026 erfundenes Strategieprodukt gestaltet - Präzision statt Effekte,
  Produktdesign statt Luxusinszenierung und Funktion statt Dekoration.
- Board- und Materialgrundlage konsolidiert: Track A `Poch Disc`, optionaler Track B
  `Unterwegs`, gemeinsame 8+1-Regelgeometrie, R1-Keramiksteine und individuell
  gealterte gleichwertige 1-Cent-Münzen. Ältere PM-/Glas-Token-/Mockup-Anker sind
  nicht mehr bindend.
- Tischwahl festgelegt: `Nur diese Partie` verwendet einen Session-Override,
  `Als Standard` speichert die Wahl bis zur nächsten Änderung. Eine spontane Wahl
  überschreibt die dauerhafte Präferenz nicht.
- `CardFace.swift` / `CardWarp.metal`: Kartenwölbung feiner abgestimmt
  (Eckenhub 2.4 → 1.6 × scale, ruhigeres Licht); Kartonrand bleibt unabhängig
  vom Wölbungswert konstant.
- `DesignTokens.swift` / `ContentView.swift`: Phase-1-Proportionen stärker am
  Mockup-Anker ausgerichtet: Ring nahezu full-width, grössere Handkarten mit
  Bottom-Bleed, Weiter-Aktion ohne eigenen Layout-Block.
- `tools/gen_pochring_replicate.py`: Replicate-HTML-Sichtung für Poch-Ring-
  Materialrichtungen (A-H) ergänzt und nach iCloud-TEMP spiegelbar gemacht.
- `tools/gen_precision_monolith.py`: fokussierte Precision-Monolith-Sichtung
  (PM1-PM8) plus Vektor-Spec für Premium/Vivid-Mulden erzeugt.
- `precision-monolith-sichtung.html`: falsche M9-SVG-Ergänzung wieder entfernt;
  M9 war nicht PM9 und optisch nicht auf Niveau der PM-Serie.
- PM9-Retakes verworfen: Text-only-Prompt driftet zu Neon/LED bzw. 3x3-Objekt;
  PM9 aus sichtbarer Sichtung entfernt. Nächster Schritt nur mit PM7/PM5 als
  Referenzbild oder kontrollierter Code-/Vektor-Geometrie.
- PM10-PM12 ergänzt: PM1-basierte Varianten mit dezenten Ringen um alle
  Mulden. PM10 ist stärkster Kandidat; PM11 zu steril/flach, PM12 falscher
  Count/zu voll.
- PM13 korrigiert und PM17-PM22 ergänzt: kontrollierte Poch-Geometrie mit
  exakt 8 Außenmulden + echter Mittelmulde; PM17-PM19 bleiben PM1-materialnah
  mit dezenten Pigmentringen, PM20-PM22 testen symmetrische PM7-Metallmulden.

## [0.7.1] - Phase-1-Ring-Skalierung: grösserer Ring, prominente Chip-Werte, diskrete Tokens - 8.7.2026

### Geändert
- `DesignTokens.swift`: `ringRadius` 130 → 145 (Ring ~10% grösser, Frame 314 → 344pt)
- `ContentView.swift::muldeTile`: Chip-Werte mit „+"-Präfix (`+4` statt `4`), font 13 → 15pt bold;
  Null-Mulden zeigen „·" statt „0"; label-font leicht angepasst (14/8pt statt 16/9pt)
- `ContentView.swift::opponentTopBar`: Token-Kreis 34 → 28pt, Name-Initial statt Sitz-Nummer,
  Farbe auf `Tokens.slate` reduziert (diskret), padding-top 16 → 10pt

## [0.7.0] - Phase-2-Layout: Slider links / Ring rechts / Portraits unten - 8.7.2026

### Geändert
- `Phase2View.swift`: Komplettes Layout-Refactoring (Mockup-Delta Phase 2):
  - `duelArea` (GeometryReader 372pt) → `topArea` (HStack: sliderPanel | compactRing)
  - Vertikaler Biet-Slider LINKS: rotierter SwiftUI-Slider in gefräster Rille, RANGE-Label,
    Chip-Stapel, Wand-Indikator (glüht gold am Anschlag), Wall-Label
  - Kompakter Poch-Ring RECHTS (scale 0.40): miniaturisierte Pool-Kacheln mit Chip-Werten,
    Morph-Anker via matchedGeometryEffect (IDs aus Phase 1 erhalten), POCH-Pott im Zentrum
  - Action-Buttons als 2-Spalten-Layout (PASSEN + MITGEHEN / ERHÖHEN-Zeile)
  - Gegner-Portraits UNTEN als horizontale Reihe (token() wiederverwendet)
  - `handView` (flat HStack) → `handFan` (angewinkelter Fächer, scale 1.0, am Bildschirmrand)

## [0.6.9] - Phase-3-Fächer: grosser dramatischer Fan + Poch-Medaillon + Handfächer - 8.7.2026

### Geändert
- `Phase3View.swift`: `chainsArea`/`chainRow` durch `playedCardsFan` ersetzt - aktueller Stich als
  grosser angewinkelter Fächer (scale 2.0, bis 66° Spreizung), Muster von ContentView::handView
- Poch-Medaillon (♥, Amethyst-Kreis) im Zentrum des Fächers als subtiler Hintergrund-Anker
- `handView` → `handFan`: Spielerhand ebenfalls angewinkelt (scale 1.55, bis 40° Spreizung),
  identisches `.offset + .rotationEffect(anchor:.bottom)`-Muster
- `centerpotChip` → `centerpotRow`: Centerpot-Chip + „N Stiche"-Badge in einer Zeile
- Ältere Ketten nicht mehr als ScrollView - stattdessen Stich-Zähler im Header

## [0.6.8] - Kantenphysik: Kartonstärke, Ebenen-Schatten, Kanten-Licht - 8.7.2026

### Geändert
- `CardWarp.metal`: Kantenphysik im Quell-Raum (SDF der Kartenform, wandert mit
  der Wölbung mit): dunkler Kartonstärke-Saum an der Schnittkante (Rückseite
  schimmert minimal durch), hauchfeines 1px-Licht auf lichtzugewandten Oberkanten
- `CardFace.swift`: zweite, weiche Schattenlage (0.20/8×scale/3.5×scale) unter dem
  Kontaktschatten - Penumbra folgt der gewölbten Silhouette, an gehobenen Ecken
  breiter (spürbarer Luftspalt zwischen Kartenebenen)
- Assets, Indizes und Fächer-Geometrie unverändert (reines Rendering)
- QA: gemini-vision PASS („physischer Premium-Karton, keine Artefakte")

## [0.6.7] - Karton-Wölbung im Kartenfächer (CardWarp-Shader) - 8.7.2026

### Hinzugefügt
- `App/CardWarp.metal` - physische Karton-Wölbung als SwiftUI-layerEffect:
  obere Kartenecken rollen subtil nach oben (max. 2.4pt × Kartenskala),
  Einroll-Zug krümmt die Seitenkanten, Licht folgt der gebogenen Fläche
  (Highlight auf gehobenen Ecken, Mulde liegt tiefer). Deterministischer
  Seed pro Karte (leichte Asymmetrie - Fächer wirkt nicht geklont).
  Render-Eigenschaft, nie ins Asset gebacken (Lesbarkeits-Licht-Regel §5).

### Geändert
- `CardFace.swift`: Wölbungs-Shader via padding/-padding-Paar (Layout
  unverändert, kein Clipping der gehobenen Ecken); Kontaktschatten kräftiger
  (0.5/4/2.5 statt 0.4/3/2) - Fächer-Wette 8.7.: Schatten ist Render-Eigenschaft
- Index-Prüfung nach Tobsi-Report „falsche Indizes in verdeckten Ecken":
  Befund = Overlap-Illusion, kein Bug (jede Karte trägt nur eigene Indizes
  oben-links/unten-rechts; der „fremde" Index gehört der Nachbarkarte).
  Q-Karte im Screenshot war eine schwarze Dame - Gewänder sind seit 0.6.6
  bei allen Damen weinrot, Farb-Wahrheit liegt allein beim Index
- Einmalig: Xcode MetalToolchain-Komponente installiert (Build-Voraussetzung)

### QA
- taste-gate (gemini-vision): Runde 1 FAIL (Krümmung las sich nicht) →
  Licht-Erzählung verstärkt, Einroll-Zug, Kontaktschatten → Runde 2 PASS
  („sehr physisch und premium, Wölbung natürlich, Schatten sauber")

## [0.6.6] - Kartenvorderseiten Runde 2: Mockup-Tiefe (Juwelen-Palette + Papier-Feel) - 8.7.2026

### Geändert
- Tiefe Juwelen-Palette statt greller htdebeer-Quellfarben (Tobsi-Feedback: „im
  Vergleich zum Mockup leicht anders" - zu flach/grell):
  - Gewänder-Rot `#E61408` → tiefes Weinrot `#7E2333`
  - Pip-/Index-Rot `#e6180a` → tiefes Karmesin `#B51D27`
  - Neon-Gelb `#F8C20F` → gedämpftes Antikgold `#B8933A`
  - Violett-Blau `#1C1585` → staubiges Royal `#465685`
  (Remap auf SVG-Ebene - saubere Kanten, getrennt mappbar, da Gewänder- und
  Pip-Rot in der Quelle nachweislich disjunkt sind)
- Papier-Feel statt steriler Vektor-Fläche: warmes Weiß, feines Korn, Leinen-
  Anmutung, sanfter Licht-Sheen von oben-links (seeded, identisch auf allen 32
  Karten, Amplituden ~1-2% - Lesbarkeit unberührt)
- Pips mit dezentem Tiefengradient (Licht von oben, nach Rotation angewandt -
  Lichtrichtung auf allen Pips identisch)
- QA: 2 gemini-vision-Iterationen gegen das Mockup („gedeckt, physisch, edel"
  bestätigt), 32er-Montage ohne Inkonsistenzen/Artefakte

## [0.6.5] - Kartenvorderseiten Final-Template (100% Konsistenz) - 8.7.2026

### Geändert
- Alle 32 Kartenvorderseiten aus EINER deterministischen Vorlage neu generiert
  (`tools/gen_cards_final.py`) - behebt die Inkonsistenzen des 0.6.4-Satzes
  (Rahmen mal ja/mal nein, Indizes zu randnah, abweichende Designs):
  - Weiße Karte, Eckradius deckungsgleich mit CardFace-Clip (8/52 der Breite)
  - Große fette Eck-Indizes (Helvetica Neue Bold) mit Pip darunter, oben-links +
    unten-rechts als identisches, 180° gedrehtes Tile (Mockup-Look)
  - Hoffiguren J/Q/K: htdebeer-Figuren per SVG-Chirurgie OHNE Alt-Indizes/Basis
    extrahiert, einheitlich platziert, weißes Knockout hinter den Indizes
  - Asse: großes zentrales Pip; Zahlkarten: klassisches Raster, untere Hälfte gedreht
  - Auflösung erhöht: @2x 312x444 + @3x 468x666 (vorher nur @2x 156x225)
- `CardFace.swift`: Header-Kommentar auf neuen Asset-Stand korrigiert

### Hinzugefügt
- `assets/provenance/cardfronts-final.md` - Provenance inkl. QA-Nachweis
- `Assets_Raw/cards/final/` - 32 Master-PNGs 624x888 (lokal, gitignored - via Generator reproduzierbar)

## [0.6.4] - Klassische Spielkarten (SVG Open-Source Assets) - 8.7.2026

### Hinzugefügt
- 32 klassische Spielkarten-Assets (htdebeer/SVG-cards, LGPL) - zweiköpfige Bildkarten (König, Dame, Bube) + Asse in traditionellem Casino-Design (Rot/Blau/Gelb/Schwarz), gerendert als @2x PNGs via rsvg-convert
- `App/Assets.xcassets/Cards/` - 32 imagesets für alle Poch-Karten
- `CardFace.swift` nutzt echte SVG-Assets für Bildkarten/Asse; Zahlkarten 7-10 bleiben code-gerendert (Pip-Anordnung)
- Generator-Skripte: `tools/gen_cards_faces.py`, `tools/gen_cards_casino.py`, `tools/gen_cards_altenburg.py` (experimentell, abgelöst durch SVG)

### Geändert
- `CardFace.swift`: Bildkarten/Asse nutzen `Image("card_{suit}_{rank}")` statt Unicode-Buchstaben


## [0.6.3] - Premium-Kartenvorderseiten (Rang-differenziertes Zentrum) - 8.7.2026

### Geändert
- `CardFace`: rang-differenziertes Zentrum statt einheitlichem Einzel-Pip:
  - **Zahlkarten 7-10**: klassische 2-spaltige Pip-Anordnung (7/8/9/10 Pips)
  - **Bildkarten J/Q/K**: großer Serif-Rang-Buchstabe allein (kein redundantes Pip darunter)
  - **Ass**: ikonische einzelne große Pip mit Tiefenschatten
- gemini-vision-QA nach je einer Iteration: Lesbarkeit 9/10, Rang-Differenzierung 8/10, Premium-Anmutung 7/10 (von 6/10 vorher). Verbleibende Schwäche = keine Bildkarten-Illustrationen (Phase-2-Asset-Task, kein Code-Fix möglich).

### Hinweis
- `CardBack` (W2-Final) war bereits in `DealOverlay` eingebaut - bleibt unverändert.


## [0.6.2] - Kostenbremse: Kontext- & Token-Disziplin (Doku) - 8.7.2026

### Geändert
- Neue globale CLAUDE.md-Sektion „💸 Kontext- & Token-Disziplin" (earned: ~20 $ in kurzer Zeit verbrannt): große generierte Dateien nie komplett einlesen, Loops mit quiet-stdout, /clear-Schnittpunkte aktiv anbieten, Subagents als Kontext-Schutz.
- Projekt-CLAUDE.md §10: Cockpit wird bei Commit/Zwischenstand gesammelt regeneriert (nicht pro Teilschritt) und nie per Read in den Kontext geholt; §7: Screenshots vor dem Read auf ~800px verkleinern.
- Lesson in `tasks/lessons.md` dokumentiert.


## [0.6.1] - Das Eiszeit-Vakuum (§6c c) - 8.7.2026

### Hinzugefügt
- Rundenende-Inszenierung als State-Machine (frozen -> punishing -> done): in der ms der letzten Karte entsättigen alle Ketten zu Schiefer (Freeze), der Centerpot (Platin) leuchtet auf, dann die bewusste **400-ms-Zäsur** (Parameter-Lock p3Vakuum), dann der **Straf-Strom PARALLEL pro Verlierer** (Chip-Ströme zum Sieger, visuell auf 5 Chips gedeckelt) mit gedeckelter 90-ms-Tick-Kadenz (max. 12 Ticks - nie zäh), Konten rollen numerisch, erst danach das Banner.
- Rundenende-Juice skaliert mit dem Pott (§6c Auflage 1): Platin-Vignette nur beim genuin fetten Centerpot (>= Kollaps-Threshold), Baseline bleibt ruhig.
- reduceMotion: keine Chip-Flüge, sanfte Fades (§6c Auflage 2); Stack-Labels an den Schiefer-Tokens.

### Geprüft
- Frame-Serie einer echten Runde (-ausspielStart -autoLead): Farbe -> Schiefer-Freeze -> glühender Centerpot -> Zäsur -> Banner klar sichtbar; Timing Freeze->Banner ~1,7 s wie ausgelegt.


## [0.6.0] - Der Balatro-Kollaps (§6a e) - 8.7.2026

### Hinzugefügt
- **Threshold-Kalibrierung per Headless-Sim** (§6 Auflage 3): neues pochsim-Subkommando `kollaps` - 1.000 Partien / 11.557 Tisch-Runden, Zünd-Raten-Tabelle T=6..20. Ergebnis: Zielband 15-20% bei T=9..12; gewählt **T=12 (16,2%)**, das rare Ende (konzeptkonform Richtung 15+ bei Ante-Eskalation). Als dokumentierter Token `jackpotKollapsThreshold`.
- **Stufe-2-Inszenierung:** beim fetten Meld birst das Tile in ~30 Partikeln in Kategorie-Farbe (goldener Winkel statt RNG - deterministisch), Screen-Shake 150 ms / 3 pt (nur Ring), farbgetönter Vignetten-Flash für einen Wimpernschlag (Ränder glühen, Spielfläche bleibt lesbar - Lesbarkeits-Licht-Regel), schwebendes „+N" beim Gewinner, .heavy-Haptik.
- reduceMotion (§6 Auflage 2): Shake genullt, Flash wird 50-ms-Dissolve, Partikel werden Farb-Blink - Wucht wandert in die Haptik. DEBUG `-kollapsDemo` (Threshold 1) für QA.

### Geprüft
- Frame-Serie: Vignetten-Wimpernschlag, Partikel-Streuung und +N sichtbar; Rarity-Lock bleibt gewahrt (Demo zündet nur per Override).


## [0.5.9] - "Der Poch": Der Tischschlag (§6b) - 8.7.2026

### Hinzugefügt
- Signaturgeste: bei jedem Eröffnen/Erhöhen (Mensch UND Bot) zittert die Tisch-Welt (Duell-Bühne) für 300 ms mit 4-pt-Amplitude - das HUD bleibt ruhig (GeometryEffect, nur Offset, kein Layout-Thrashing §9). Trigger `pochShock` in GameState, gekoppelte .heavy-Haptik; reduceMotion nullt die Amplitude.
- Gebots-Gewicht: Chip-Stapel wächst sichtbar mit dem Slider in der Bietzone (max. 9 Chips, Feder-Animation).
- DEBUG `-pochDemo` für Tischschlag-QA ohne UI-Tap.

### Geprüft
- Deterministischer Bewegungs-Beweis statt Judge: Frame-Diff-Kurve der Duell-Bühne zeigt den Schlag-Burst (0,57/1,17/0,66/0,70 über ~300 ms = pochShake-Token) gegen ~0,1 Grundrauschen; Kontaktbogen bestätigt Chip-Stapel, Pott-Roll 0->3 und ruhiges HUD.


## [0.5.8] - Der Melde-Strom (§6a b) - 8.7.2026

### Hinzugefügt
- Melde-Strom nach dem Trumpf-Beat: Mulden zahlen rhythmisch reihum aus (Takt 550 ms, Parameter-Lock p1MeldStep) - Mulde pulst in Kategorie-Farbe, Münz-Chips in Juwel-Tint fliegen gestaffelt zur Gewinner-Position, Konten + Mulden-Zähler rollen numerisch (contentTransition).
- Dramaturgie-Fix: der Ring zeigt jetzt PRÄ-Melde-Werte (displayedChips/displayedStack laufen der Engine hinterher) - vorher standen die Mulden schon beim Einstieg auf 0, der Strom hatte nichts zu erzählen.
- Tap-Skip deckt jetzt Deal UND Melde-Strom ab; reduceMotion überspringt den Strom komplett (Safe-Mode §6 Auflage 2). Bogen-Flugbahn der Münzen = dokumentiertes Hand-Gate (v1 gerade + gestaffelt).

### Geprüft
- Bewegungs-QA (Frame-Serie): Auszahlungs-Sequenz klar lesbar (wandernder Fokus, Münzflüge, Konten-Updates), Räte 7/10 Lesbarkeit. Farb-Kritik (Münzen immer gelb) als Fehllesung geprüft: Tint ist kategoriegebunden, die sichtbaren Melds waren Gold-Mulden.


## [0.5.7] - Der Trumpf-Beat (§6a) - 8.7.2026

### Hinzugefügt
- Deal-Präsentation Phase 1: 31 Kartenrücken (CardBack) fliegen im 40-ms-Kaskaden-Takt vom Ring-Zentrum in die Hände, die Hand baut sich mit Ankunfts-Verzögerung auf, der Trumpf bleibt verdeckt bis zum Beat: 150-ms-Freeze, dann Flip + radialer Lichtpuls in Trumpffarbe (Rot-Suits = Rosé, Schwarz = Platin). Alle Werte als Parameter-Lock-Tokens (p1DealStep/p1Flight/p1TrumpFreeze/p1Pulse).
- Haptik-Kadenz exakt 90 ms, von der Karten-Anzahl ENTKOPPELT (§6 Auflage 4); Tap auf den Ring überspringt die Kaskade (skipDeal); reduceMotion-Pfad: keine Flüge, sanfter Dissolve, Beat wandert in einen Haptik-Tick (§6 Auflage 2).
- DealOverlay als hitTest-freie Präsentations-Schicht (schluckt keine Taps - bekannte Falle §7).

### Geprüft
- Bewegungs-QA (Frame-Serie 12fps): Kaskade spec-genau (31 Karten ≈ 1,3 s), Puls + Trumpf-Flip sichtbar. Räte-Timing-Kritik als Fehlmessung widerlegt (Judge zählte nur die 8 Menschen-Karten = 160-ms-Sichtabstand); gelockte Parameter unangetastet, nur Puls-Sichtbarkeit angehoben (0.7->0.9, Breite 14->22).


## [0.5.6] - Feel-Polish P2 + Kessel-Runde + Cockpit-Diät (8.7.2026)

### Geändert
- Material > Glow umgesetzt (Feel-Befunde): Poch-Pott mit gefräster Innenstufe + reduziertem Schein (Premium: Radius 12->6, Opacity 0.25->0.14), Biet-Slider in dunkler Rille, Limit-Wand als gefräster Platin-Pfeiler mit Gold-Anschlag. Räte-Vergleich Vorher/Nachher: 5 -> 8 (Material-Premium). Rest-Befund (flache Token-Kreise) erledigt sich mit der O-Porträt-Produktion.
- Cockpit entschlackt: 10 MB -> 6.5 MB (Archiv-Galerien raus, aktive Entscheidungen + Sieger-Referenzen bleiben).

### Hinzugefügt
- Kessel-Runde KA/KB/KC (tools/gen_kessel_varianten.py): stilisierte Poch-Kessel-Motive, punktsymmetrisch; ungeprimte QA: KB bestes Profil, KC Casino-Rückfall (raus), keiner schlägt W2 - Empfehlung: KA/KB in den Unlock-Deck-Pool (§7.2).
- Phase 2: CardBack-Mini-Fächer hinter den Gegner-Tokens (verdeckte Hand §6b, Kontaktschatten als Render-Eigenschaft).
- Morph-2-Label-Crossfade als Hand-Gate dokumentiert (braucht Geräte-Tuning, kein Blind-Fix).


## [0.5.5] - Phasen-Morph: Drei Akte, eine Bühne (8.7.2026, nachts)

### Hinzugefügt
- Phasen-Morph (§5b) via `matchedGeometryEffect` + geteiltem Namespace über alle drei Akte: Gegner-Tokens fliegen Top-Bar → Kardinalpunkte → Schiefer-Reihe, die Poch-Mulde löst sich aus dem Ring und wird zum Poch-Pott (Signatur-Flug), die 7 übrigen Mulden konvergieren zu Echo-Dots. `.position` statt `.offset` für echte Layout-Frames, `withAnimation(.spring(0.55))` unter Parameter-Lock (`Tokens.aktMorph`).
- DEBUG `-morphDemo`: automatischer Akt-Durchlauf für Bewegungs-QA (Video ohne UI-Tap); Frame-Extraktion nativ via AVFoundation (ffmpeg-Havarie umgangen).

### Geprüft (Feel-Regel: Räte VOR Commit)
- Bewegungs-QA auf Frame-Serien (15fps-Kontaktbögen): Morph 1 (P1→P2) Kontinuität 9/10, Premium 9/10; Morph 2 (P2→P3) 8/10, 7/10. Befund für den Game-Feel-Pass: Text-Crossfade macht fliegende Tokens leicht undeutlich; Poch-Pott eher Glow als Material.
- taste-gate (Erstlauf, unkalibriert): FAIL auf bekannter Platzhalter-Ebene (generische Karten/Tokens = eingeplante Tasks); drei Overflow-Claims per eigenem Blick als Judge-Rauschen widerlegt.


## [0.5.4] - Kartenrücken W2 FINAL: Asset-Freeze (8.7.2026, nachts)

### Entschieden (Tobsi-Exekutions-Befehl)
- **W2 (Facetten-Siegel) ist der verbindliche Default-Kartenrücken.** Finalisierungs-Auflagen umgesetzt:
  - **Punktsymmetrie:** 8 Facetten konstruktiv gepaart (i = i+4), Grund + Karte mathematisch symmetrisiert (Blend mit 180°-Rotation). Harter Beweis: Pixel-Diff Karte vs. gedrehte Karte = [0, 0, 0] - kein Orientierungs-Leak (E-Fehler strukturell unmöglich).
  - **Monogramm crisp:** P·1441 als Vektor-Overlay (Didot), 4x supersampled - nie generiert.
  - **Engine-Branding:** `App/CardBack.swift` rendert die Facetten-Raute direkt aus `DesignTokens` (Code = Source of Truth der Label-Farben), punktsymmetrisch, skalierbar, Monogramm ab Faktor 1.2.
  - Provenance-Sidecar `assets/provenance/cardback-w2-default.md` (Konstruktion, KI-Anteil nur Grund-Textur mit Seed, menschliche Entscheidungskette, dokumentierte Restrisiken: Karo-As-Assoziation + Spielgrößen-Test am Tisch).
- Cockpit verschlankt (Archiv-Galerien raus, Final + Beweis rein).

### Nachschärfung vor Print-Master (Tobsi-Review des Freeze)
- **Fächer-Test** (5 überlappende Rücken als Gegnerhand, 3 Fassungen): FC gewinnt (Innenfacetten 0.64 statt 0.5 = ruhigster Fächer bei voller Signet-Präsenz) - in Print-Master UND `CardBack.swift` übernommen, Symmetrie-Beweis erneut [0,0,0].
- **Signet-Entscheid:** Monogramm = nur „1441" dezent (M2 im Vergleichstest; das P ist mehrdeutig, die Zahl trägt). Immer als gespiegeltes Paar - Einzel-Monogramm bräche die Punktsymmetrie. Voller Name „Poch 1441" lebt bei Icon/Splash/Store/Onboarding.
- Karo-As-Entschärfung dokumentiert (Farbregel: kein Ton dominant, Granat nie flächig).

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
