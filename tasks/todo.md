# Poch 1441 - Arbeitsloop / Todo

**Stand:** 9. Juli 2026, frueher Morgen
**Ziel:** App maximal Richtung Mockup bringen, aber mit unserem Kanon: Poch 1441,
PM49-Ring, finale Karten, Premium-matt plus Vivid-Theme, Material > Glow, kein Casino.
**Mockup-Referenz:** `/Users/tobsi/Library/Mobile Documents/com~apple~CloudDocs/TEMP/935b2c31-45a6-44d1-b74d-0dfd39cc8817.JPG`

---

## Harte Layout-Leitplanke

Das Mockup ist fuer die **Komposition** sehr nah zu treffen:

- Kartenlage, Kartenfaecher, Anschnitt am unteren Bildschirmrand und zentrale
  Karten-/Medaillon-Komposition moeglichst nahe am Mockup.
- Element-Proportionen zuerst nach Mockup setzen, danach erst an unsere Farben,
  Namen und PM49-/Premium-Ästhetik anpassen.
- Phase 1: grosser zentraler Ring, Karten unten breit angeschnitten, wenig UI-Lärm.
- Phase 2: linker Vertikalregler, kompakter Ring rechts/oben, Actions mittig,
  Portrait-/Statusbereich unten.
- Phase 3: grosser dramatischer Kartenfaecher als Hauptbild, Medaillon/Ring im Zentrum,
  Handkarten unten wie Mockup.
- Abweichungen sind nur erlaubt, wenn sie durch echte Poch-Regeln, Lesbarkeit oder
  unseren Anti-Casino-Kanon begruendet sind.

## Harte Qualitaets-Gates Aus Tobsi-Kritik 9.7.

- [ ] **Gesamter Loop darf nicht mehr roh/basic wirken.** Jeder Screen braucht klare
  Hauptspannung, sichtbare Hierarchie, hochwertige Bewegung und keine Debug-Text-Anmutung.
- [ ] **Muenzen/Chips neu bewerten.** Sie muessen wie echte, schwere Spielchips in
  den Mulden liegen: materialig, gestapelt, perspektivisch ruhig, nie gelbe UI-Punkte.
- [ ] **Kartenruecken prominent nutzen.** Der gelockte Ruecken muss sichtbar tragen:
  Gegnerhaende, Deck-/Trumpf-Moment, Phase-2-Panels, Phase-3-Seitendeck/Medaillon.
- [ ] **Texte und Labels auditieren.** Keine durcheinanderliegenden Texte, keine
  schlecht eingefuegten Debug-Hinweise, kein Overlap mit Karten/Mulden/Portraits.
- [ ] **Kartenlage gegen Mockup auditieren.** Besonders letzter Spielzug/Phase 3:
  Karten muessen dramatisch und mockup-nah liegen, mit schwarzer Kante/Schatten.
- [ ] **Gegner neu denken.** Namen duerfen nicht unfreiwillig altbacken wirken;
  Figuren brauchen Mimik/Spielzug-Reaktionen und klare Rollen ohne Hand-Leak.
- [ ] **Spieleranzahl anbieten.** Settings/Neue Partie muss perspektivisch 2/3/4
  Spieler erlauben, sofern Engine/Regeln das sauber tragen.
- [ ] **Gefuehrter Modus nach Tutorial.** Nach dem Tutorial soll ein Begleitmodus jeden
  Spielzug erklaeren: Optionen, Idee dahinter, Auswirkungen, empfohlene Entscheidung,
  ohne verdeckte Karten zu verraten. Muss jederzeit abschaltbar sein.
- [ ] **UX-Elemente ent-basic-en.** Buttons, Slider, Toggles und Panels muessen wie
  Poch-1441-Objekte wirken, nicht wie generische iOS-Demo-Komponenten.

## Dramaturgie-/Spieldynamik-Gates

- [ ] **Jede Phase braucht eine eigene Spannungskurve.** Melden = Entdecken/Claimen,
  Pochen = Druck/Entscheidung, Ausspielen = Kettenreaktion/Finale. Kein Screen darf
  nur ein anderer Button-Zustand derselben App sein.
- [ ] **Jeder Spielzug braucht Vorfreude, Entscheidung und Rueckmeldung.** Vor dem Zug
  muss klar sein, worum es geht; waehrenddessen muessen Optionen intuitiv wirken; danach
  muessen Chips, Karten, Gegnerreaktion und Sound/Haptik den Ausgang spuerbar machen.
- [ ] **Komposition pro Schritt gegen Mockup pruefen.** Karten, Ring, Gegner, Text und
  Chips muessen pro Phase eine klare Hauptbuehne haben; nichts darf zufaellig verteilt,
  ueberlappt oder wie Debug-Layout wirken.
- [ ] **Langzeitmotivation sichtbar machen.** Rundenende, Serie, Fortschritt, Varianten,
  Charakterreaktionen und Statistik/Belohnung muessen sich nach hochwertigem Spielsystem
  anfuehlen, nicht nach einmaligem Durchklicken.
- [ ] **Orchestrierung auditieren.** Die bestehenden Millisekunden-Dokumente fuer
  Muenzen/Karten/Effekte muessen mit dem echten UI abgeglichen werden: Timing, Layering,
  Fokuswechsel, Haptik, Sound und Abbruchfaelle.
- [ ] **Eye-candy mit Spielklarheit koppeln.** Jede Animation muss Regelverstaendnis
  verbessern oder emotionale Spannung erhoehen; keine Deko-Effekte, die Poch als
  Casino/Arcade missverstaendlich machen.

**Stand 9.7. Arbeitsloop:** Gates aufgenommen. Erste globale Politur umgesetzt:
materialigere `TableChip`-Komponente, sichtbarere Gegner-Kartenruecken, DealOverlay
rendert nach Skip keine Rest-Flugkarten mehr, Zug-Begleiter hat Settings-Schalter und
zustandsbezogene Texte, Phase 3 zeigt ein Rueckseiten-Seitendeck neben dem Medaillon.
Aktuelle QA-Screens: `artifacts/app-screens/global-polish-v2b-20260709/` und
`artifacts/app-screens/global-polish-v3b-20260709/phase3-side-deck.png`.

---

## Eingeloggt / Nicht Wieder Aufmachen

- [x] **Kartenvorderseiten final aktiv.**
  - Generator: `tools/gen_cards_vector_public_domain.py`
  - QA: `artifacts/sichtung-karten-franzoesisch.html`
  - Provenance: `assets/provenance/cardfronts-final.md`
  - Quelle: 32 einzelne Public-Domain-SVGs, kein KI-Sheet.
  - Gelockt: mehr Padding, Rubinrot, rote Asse geboostet, Ecktypografie groesser/fetter,
    Premium-Stock-Finish. Keine zweite Overpaint-Typo.
- [x] **Kartenwoelbung:** sichtbare Woelbung/Schatten bleiben in `CardFace`/Shader,
  nicht hart in PNGs.
- [x] **Ring-Richtung:** PM49 / Cockpit 8-Color ist die bevorzugte Richtung.
  Alte Ringvarianten bleiben im Archiv, nicht mehr als Default explorieren.
- [x] **Design-Kanon:** `tasks/konzept.md` gilt. Mockup ist Layout-/Proportionsreferenz,
  nicht Casino-/Neon-Vorgabe.
- [x] **Theme-Strategie:** zwei Themes bauen: `Premium` als Default und `Vivid` als
  sattere Variante mit gleicher Geometrie. Vivid darf klarer/greller sein, aber nicht
  nach Casino, Slot, Roulette oder Neon-Arcade kippen.
- [x] **Gegner-Stilrichtung:** warme, painterly Charaktere im cleanen Premium-Rahmen.
  Keine generischen Buchstaben-Tokens als Zielzustand; Tokens nur als Platzhalter.
  Gegner sind Marken-Asset und brauchen sichtbare Gesten/Reaktionen.
- [x] **Regeln:** `tasks/poch-spec.md` Gate A gilt. Keine Regelarbeit ohne Auftrag.

---

## Arbeitsannahmen Fuer Den Naechsten Loop

Diese Punkte blockieren die Umsetzung nicht. Falls Tobsi nichts anderes sagt, so bauen:

- **Gegnerplatzierung:** Phase 1 oben diskret; Phase 2 als Charakter-/Portrait-Fokus
  links/rechts/unten-nahe Buttons; Phase 3 entsaettigt im Hintergrund, damit Karten-Fan
  dominiert.
- **Gegnerreaktionen:** zunaechst datengetriebene UI-Zustaende, noch keine finalen
  Charakterportraets: `passt`, `geht mit`, `erhoeht`, `pocht`, `gewinnt`, `verliert`,
  `denkt`. Keine Handstaerke-Leaks.
- **Tutorial-Stil:** interaktiv, szenisch, kurz. Keine Textwand. Wirt/Coach fuehrt durch
  Melden -> Pochen -> Ausspielen mit gescripteten Seeds.
- **Hilfen:** schoene Hilfe als Regelbuch/Kontor-Overlay, aber modern und scanbar.
- **Einstellungen:** produktionsnah bauen: Audio, Haptik, Assist, Motion, Theme,
  Sprache-Platzhalter, Tutorial zuruecksetzen. DEBUG-Bereich nur `#if DEBUG`.
- **Overlays:** alle Overlays als echte App-Flaechen, keine Landingpage. Close/Back immer
  eindeutig, keine verschachtelten Karten-in-Karten.

---

## Track A - Mockup-Proportionen / Core Screens

### A1 Phase 1 - Melden / grosser Ring
- [x] Ring als Hero-Objekt: deutlich groesser, hoeher, ruhiger. Stand 9.7.:
  PM49 ist als echtes Asset im Hauptscreen eingebunden, mit PM1/PM49-Materialwirkung
  statt procedural UI-Ring.
- [x] PM49-Ring/Asset als Platzhalter bzw. generiertes Bild sauber einbinden.
- [x] Untere Kartenhand wie Mockup: breit, angeschnitten, klare Woelbung/Schatten.
- [x] Gegnerstatus sehr diskret oben, keine UI-Ueberladung.
- [x] Hauptaktionen minimalisieren; normale Phase soll nicht nach Button-Wand aussehen.
- [x] Phasentitel im Mockup-Rhythmus: Poch-Logo, kleine Phasennummer, grosse
  Akt-Ueberschrift (`MELDEN`, `POCHEN`, `AUSSPIELEN`). Sichtungen:
  `artifacts/app-screens/phase1-title-premium-v3.png`,
  `artifacts/app-screens/phase2-title-premium.png`,
  `artifacts/app-screens/phase3-title-premium.png`.
- [~] Chip-/Muldenwerte als starke, klare Labels, nicht kleine Zahlen.
  Stand 9.7.: Werte/Chip-Cluster sind lesbar; naechster Feinschliff ist
  Gewinnauszahlung/Highlight pro Mulde statt statischer `+4`-Anmutung. QA-Arg
  `-dealDone`/`-skipDeal` zeigt Phase 1 direkt nach dem Deal fuer stabile
  Screenshots. Aktuelle Sichtung: `artifacts/app-screens/phase1-dealdone-premium-v3.png`.
  Stand 9.7. spaeter: aktiver Meldegewinn hat jetzt einen kurzen materiellen
  Muldenakzent (`PoolWinAccent`) mit Innenfase, Messing-Splittern und kompaktem
  `+N` direkt in der Schatulle. QA-Sichtung:
  `artifacts/app-screens/phase1-pool-win-accent-2.png`.
- [x] Mulden/Schatullen wie im Mockup andeuten: jede Kategorie wirkt wie eine wertige
  Fassung/Schale/Schatulle fuer Chips, nicht nur ein flaches Segment. PM49-Form und
  Material bleiben, aber Behälterlogik muss sichtbar werden. Stand: PM49-Asset +
  `TableChip`-Cluster und sichtbare Farbmulden.

### A2 Phase 2 - Pochen / Batero-Modus
- [~] Layout nach Mockup-Proportion: Slider links, kompakter Ring rechts/oben, Actions mittig.
  Stand 9.7.: linker Range-Regler ist jetzt ein eigener gefraester Vertikalregler
  mit Messinggriff statt iOS-Default-Slider (`artifacts/app-screens/phase2-custom-rail.png`).
  Aktionszone ist als stabiles 2x2-Command-Grid umgesetzt: legale Aktionen aktiv,
  nicht verfuegbare Slots gedimmt, damit Phase 2 nicht springt und mockup-naeher
  liest. Aktuelle Sichtung: `artifacts/app-screens/phase2-command-grid-premium.png`.
- [x] Actions: `Passen`, `Mitgehen`, `Erhoehen`; kein `All-in`.
- [~] Poch-Pott/Limit-Wand als psychologischer Held, nicht generischer Slider.
  Stand: Wette-Zentrale mit Pott, stehender Mulde, Limit-Halter und eigenem Einsatz
  eingebaut; Poch-Chipflug in den Pott ist als Motion-Layer verdrahtet und per
  DEBUG-Launch-Arg `-pochFlightQA` als wiederholbarer QA-Zustand sichtbar.
  Aktuelle Sichtung: `artifacts/app-screens/phase2-poch-flight-qa-v3.png`.
- [x] Gegnerreaktionen mit Status-Bubbles und Denkzustand.
- [~] Gegner als schoene Character-Panels/Portraits nach painterly Stilrichtung,
  nicht nur Initialen. Bis finale Assets da sind: hochwertige Silhouetten/Portrait-
  Platzhalter statt bloßer Buchstaben. Stand: code-gerenderte warme Portrait-
  Panels mit Rolle, Konto, Kartenanzahl und Reaktion eingebaut; Stand 9.7. spaeter:
  Rollen-Silhouetten vorsichtig unterscheidbarer gemacht (Wirt/Baronesse/Ratsherr),
  Sichtung `artifacts/app-screens/phase2-opponent-polish.png`. Finale raster/painterly
  Assets fehlen weiterhin.
- [x] Eigene Hand unten als kleiner Faecher.

### A3 Phase 3 - Ausspielen / Kartenstrom
- [~] Grosser dramatischer Karten-Fan im Zentrum, 60-70% Screen. Stand: Karten
  sind stark und mockup-nah; Feinschliff bei vertikalem Rhythmus/Endzustand offen.
- [~] Poch-/Center-Medaillon als ruhiger Anker, nicht Casino-Emblem. Stand:
  sichtbares dunkles Front-Medaillon eingebaut; `-holdPlayout` erzeugt stabilen
  QA-Zustand fuer Mockup-Vergleich.
- [~] Gespielte Karten klar lesbar; Stopper/Anspielrecht visuell markieren.
  Stand 9.7.: Stopper-/Kettenzustand als kompakter Badge ueber dem zentralen
  Kartenfaecher; aktives Anspielrecht hebt die Spielerhand mit feinem Goldrahmen,
  Schatten und Lift hervor. Aktuelle Sichtung:
  `artifacts/app-screens/phase3-chain-badge-short-v2.png`.
- [x] Untere Hand-Faecher analog Mockup, aber mit finalen Karten.
- [x] Phase-3-Leerzustand vermeiden: auch Demo/Preview soll dramatisch aussehen.

### A4 Partie-Ende
- [~] Ergebnis-Screen ohne Spielhallen-/Casino-Sprache. Stand: Phase-3-Endscreen
  mit Gewinner, Mitte, Strafzahlungen und Premium-Panel eingebaut.
- [~] Premium-Endstand, Rundenverlauf, bester Moment, naechste Partie. Stand:
  Endstand/Zahlungen plus kompakter Rueckblick mit Ketten, laengster Kette,
  letzter Karte und Finisher sichtbar; echter Replay-Rueckblick fehlt.
- [~] Button-Hierarchie: neue Partie, Rueckblick, Einstellungen/Hilfe. Stand:
  klare Primaeraktion `Naechste Runde`; Rueckblick fehlt.

---

## Track B - Tutorial / Onboarding

- [ ] Erster Start: kurze, spielbare Einfuehrung statt Text.
- [~] Tutorial Kapitel 1: Melden und Mulden. Stand: hochwertigere scrollbare
  Overlay-Seite mit Coach-Bubble, Phasen-Reitern, Fortschrittsstreifen und
  visueller Miniatur fuer Melden. Aktuelle Sichtung:
  `artifacts/app-screens/tutorial-tabs-v2.png`. Stand 9.7.: Der Footer
  `Geführte Runde starten` startet nun eine deterministische Lernrunde über
  `GameState.startTutorialRound()`, deren Seed regelkonform eine eigene
  Poch-Kombination enthält. Phase-1-QA:
  `artifacts/app-screens/tutorial-seed-phase1-v2.png`.
- [~] Tutorial Kapitel 2: Pochen, Paarpflicht, Mitgehen/Erhoehen/Passen. Stand:
  visuelle Miniatur mit Range-Rille und Pott, eingebettet in den gemeinsamen
  Overlay-Reiter. Noch nicht als gescripteter Spielzustand spielbar.
- [~] Tutorial Kapitel 3: Ausspielen, Kette, Stopps, Mitte. Stand: hochwertigere
  scrollbare Overlay-Seite mit Kartenfaecher-Miniatur und klarer Footer-Aktion.
- [ ] Skip und Wiederholen im Menue.
- [~] Kontext-Hinweise als elegante Coach-Bubbles; nie blockierend, nie zu viel Text.
  Stand 9.7.: Phase 1 kompakter Coach-Chip, Phase 2/3 dynamische Coach-Bubbles
  eingebaut. Stand 9.7. spaeter: Guided-Mode-Schiene pro Phase ergaenzt; sie
  erklaert nur den naechsten Schritt und laesst die Aktionsflaechen frei.
  Screens: `artifacts/app-screens/guided-phase2.png`,
  `artifacts/app-screens/guided-phase3-v2.png`. Noch offen: echte Schritt-
  Progression statt nur phasenbasierter Coach-Schiene.
- [~] Tutorial-Seeds/States vorbereiten oder Mock-State fuer UI bauen, bis Engine-Seeds stehen.
  Stand: regelkonformer Seed-Selektor in `GameState.startTutorialRound()` sucht
  eine Lernrunde mit eigener Poch-Kombination und mehreren Meldungen.

---

## Track C - Hilfe / Regelbuch

- [~] Hilfe-Overlay als schoenes Regelbuch/Kontor-Panel. Stand: strukturierter,
  scrollbarer Premium-Modal mit kompakter Regelkachel-Matrix und internem
  Lernen/Regeln/Tisch-Reiter. Aktuelle Sichtung:
  `artifacts/app-screens/help-tabs-v2.png`.
- [~] Schnellhilfe pro Phase.
- [~] Regelreferenz: 9 Mulden, 3 Phasen, Poch-Kunststuecke, Kettenstopps.
- [~] Glossar: Mariage, Sequenz, Poch, Mitte, Trumpf, Kette. Stand: wichtigste
  Begriffe in der Schnellhilfe; Stand 9.7. spaeter: kompakter Begriffsblock mit
  Trumpf/Mitte/Wand/Kette in der Hilfe ergaenzt. Sichtung:
  `artifacts/app-screens/help-glossary.png`. Noch offen: finaler Copy-Pass.
- [~] Visuale Beispiele mit Karten/Mulden, keine langen Fliesstextbloecke.
  Stand 9.7.: Tutorial zeigt visuelle Phasen-Miniaturen; Hilfe zeigt Regelkacheln.
  Stand 9.7. spaeter: Hilfe-Regeln haben drei kompakte Visualbeispiele mit
  echten Karten, Mulden und Chips bekommen. Sichtung:
  `artifacts/app-screens/help-visual-examples.png`. Noch offen: eigener
  Glossar-Screen und Feinschliff nach finaler Copy.
- [ ] Barrierearme Struktur: klare Headings, groessere Tap-Zonen, scroll stabil.

---

## Track D - Vivid Theme / Theme-System

- [x] Theme-State zentralisieren: `Premium` und `Vivid`.
- [ ] DesignTokens um zwei Token-Sets erweitern: matte Premium-Werte und sattere
  Vivid-Werte.
- [ ] Alle Phasen benutzen Theme-Tokens statt verstreuter Einzelwerte.
- [ ] PM49/Ring im Vivid-Theme: gleiche Form, sattere Pigmentringe/Mulden, kein
  Dauer-Glow.
- [ ] Karten bleiben in beiden Themes gleich; nur Schatten/Aura/Highlight duerfen
  theme-spezifisch reagieren.
- [x] Vivid in Settings sichtbar umschaltbar.
- [x] Theme-Vorschau in Settings: Premium/Vivid als kleine Materialprobe statt nur
  abstraktem Toggle. Sichtung: `artifacts/app-screens/settings-theme-preview.png`.
- [~] Vivid-Sichtung/Screenshots fuer Phase 1/2/3 erzeugen. Stand: Phase-2-
  Vivid-Sichtung mit neuer Phasenatmosphaere erzeugt
  (`artifacts/app-screens/phase2-vivid-atmosphere.png`). Stand 9.7.: frische
  Vivid-Screens fuer Phase 1/2/3 vorhanden:
  `artifacts/app-screens/phase1-dealdone-vivid-v2.png`,
  `artifacts/app-screens/phase2-command-grid-vivid.png`,
  `artifacts/app-screens/phase3-core-vivid-v2.png`.

## Track E - Einstellungen / Menues

- [~] Settings-Screen: Audio/Haptik/Effekte. Stand: Sound, Haptik, Assist-Hinweise,
  Tischeffekte, Theme, Sprache-/Tutorial-/Rechtliches-Platzhalter und DEBUG-
  Startzustände sichtbar. Stand 9.7.: Settings sind im gemeinsamen Overlay-System
  mit Reitern, Footer-Aktion und korrigiertem Amethyst-Kontrast eingebunden.
  Aktuelle Sichtung: `artifacts/app-screens/settings-tabs-v3.png`.
- [~] Spielhilfen: Hand-Assist, Stopper-Hinweise, reduzierte Bewegung.
- [x] Darstellung: Premium/Vivid Theme als UI-Switch.
- [x] DEBUG-Launch-Args fuer Darstellung: `-vivid`/`-neon` und `-premium`.
- [x] DEBUG-Launch-Arg fuer Phase-1-QA: `-dealDone`/`-skipDeal` springt in den
  fertig ausgeteilten Melden-Zustand.
- [x] Sprache vorbereitet, auch wenn Localizations spaeter kommen.
- [x] Rechtliches/Impressum/Datenschutz-Platzhalter.
- [~] DEBUG-Sektion: Seed/Phase-Skip, Tutorial reset, Screenshot states. Nur DEBUG.
  Stand: `-pochenStart`, `-ausspielStart`, `-holdPlayout`, `-settings`, `-help`,
  `-tutorial`, `-roundEnd`, `-vivid`/`-premium`, `-guided`, `-tutorialSeed`,
  `-menu`/`-pause`, `-roundPunishing`.

---

## Track F - Overlays / Game Feel

- [x] Phasenwechsel-Overlay: Melden -> Pochen -> Ausspielen als kurzer Akt-Wechsel.
  Stand 9.7.: `PhaseCurtain` verdrahtet fuer Tap Phase 1->2, Continue Phase 2->3,
  neue Runde und DEBUG-Morph. QA-Screenshot:
  `artifacts/app-screens/phase-curtain-ausspielen.png`.
- [x] Phasenatmosphaere: jede Phase bekommt eigene, subtile Buehnenfarbe
  (Melden Gold/Graphit, Pochen Amethyst-Druck, Ausspielen Smaragd/Platin), damit
  die drei Akte ohne Casino-Glow unterschiedlich lesbar sind.
- [x] Phase-1-Mockup-Komposition: Gegnerleiste und runder Weiter-Button aus dem
  Hero-Screen entfernt; PM49-Brett ist wieder alleiniger Hauptdarsteller, Handfächer
  bleibt als unterer Bleed. QA:
  `artifacts/app-screens/audit-20260709-0521/phase1-premium-cleanhero.png`.
  Flow-Fix: Tap aufs Brett skippt waehrend des Deals, nach abgeschlossenem Deal
  wechselt derselbe Tap in Phase 2.
- [x] Phase-3-Datenstrom: Start-/Preview-Fächer auf 8 Karten verbreitert,
  Coach-Box aus dem Hauptscreen entfernt; Status bleibt kompakt, Kartenfächer +
  Medaillon tragen wie im Mockup die Szene. QA:
  `artifacts/app-screens/audit-20260709-0521/phase3-premium-cleanstream.png`.
- [x] Phase-2-Mockup-Komposition: grosse Coach-Box aus dem Hauptscreen entfernt
  und durch kompakte Statuszeile ersetzt (`DEIN ZUG`, Gegneraktion, Ergebnis);
  Range-Slider von losgeloesten Chip-/Wand-Balken bereinigt. QA:
  `artifacts/app-screens/audit-20260709-0521/phase2-premium-clean-slider.png`,
  `artifacts/app-screens/audit-20260709-0521/phase2-vivid-clean-slider.png`.
- [x] Trumpf-/Skip-Puls entschaerft: kurzer Material-Akzent aus dem Brettzentrum,
  kein grosser grauer Overlay-Kreis ueber Ring/Karten.
- [~] Action-Badges ueber Gegnern: passt, geht mit, erhoeht, pocht. Stand:
  Phase-2-Panels zeigen Reaktions-Bubbles; Animation/Timing und Audio-Haptik fehlen.
- [~] Gewinn-Overlay fuer Mulden: kurzer, matter Juwelen-Akzent, kein Dauer-Glow.
  Stand: Phase-1-Meldegewinn pulst jetzt direkt in der aktiven PM49-Mulde mit
  Materialkante und kleinen Splittern, synchron zum Chipflug. Stand 9.7. spaeter:
  Phase-3-Mitte/Endabrechnung hat nun Centerpot-Release und Chip-Impact beim
  Gewinner, ebenfalls als Materialeffekt statt Glow.
- [~] Poch-Chipflug: Chips fliegen beim Bieten aus Spieler-/Gegnerposition in den
  Poch-Pott, mit kurzem Material-Impact. Stand 9.7.: Zielpunkt auf die zentrale
  Poch-Mulde kalibriert, Impact ist kleiner/goldener und weniger UI-glow-artig.
  DEBUG-QA triggert die Sequenz mehrfach fuer stabile Simulator-Screenshots.
  Stand 9.7. spaeter: Frame-Serie `poch-flight-material-v3-frames` zeigt
  deckendere, koerperlichere Chips und einen kompakten materialartigen Einschlag
  exakt im Poch-Zentrum. Naechster Schritt: Video-QA fuer Timing gegen die
  Millisekunden-Orchestrierung.
- [~] Rundenende-Overlay: Centerpot, Restkartenzahlung, Gewinner. Stand:
  Phase-3-Endscreen umgesetzt; Centerpot fliegt im Strafstrom mit. Stand 9.7.
  spaeter: Strafstrom hat eigenen QA-State `-roundPunishing`, materiellen
  Centerpot-Release, Gewinner-Impact und klare Abrechnungszeile statt falschem
  Anspiel-/Handstatus. QA-Sichtung:
  `artifacts/app-screens/phase3-punish-material-v2.png`. Stand 9.7. spaeter:
  Haptik-/Motion-Kadenz zaehlt jetzt Centerpot plus Restkarten, gedeckelt nach
  `Tokens.p3PunishTickCap`; Strafchips haben getrennte Lanes und kleineren
  Konto-Impact statt Portrait-Treffer. QA-Sichtungen:
  `artifacts/app-screens/phase3-punish-target-v6.png`,
  `artifacts/app-screens/punish-orchestration-frames/`.
- [~] Pausen-/Menue-Overlay mit Hilfe, Einstellungen, Neustart. Stand:
  gemeinsames Overlay mit Reitern (`Lernen`, `Regeln`, `Tisch`), Close-Button
  und Kontext-Footer ist eingebaut; Tutorial-Footer startet eine echte gefuehrte
  Runde. Stand 9.7. spaeter: echtes Pause-Overlay als eigener Menue-Zustand
  ergaenzt, mit Resume, Phasenstrip, Trumpf/Mitte-Metriken, direktem Sprung zu
  Regeln/Tisch/Tutorial und Neue Runde. QA-Screens:
  `artifacts/app-screens/pause-menu-phase1.png`,
  `artifacts/app-screens/pause-menu-phase2.png`,
  `artifacts/app-screens/pause-menu-phase3-v2.png`. Stand 9.7. spaeter:
  Tutorial-/Hilfe-Overlays poliert: Primary-Button ist dunkles Material mit
  farbiger Kante statt flachem Goldblock; Hilfe zeigt alle drei Akte im ersten
  Blick ohne abgeschnittenen Beispielblock. QA:
  `artifacts/app-screens/overlay-audit-20260709-0555/tutorial-polished.png`,
  `artifacts/app-screens/overlay-audit-20260709-0555/help-compact.png`,
  `artifacts/app-screens/overlay-audit-20260709-0555/settings-polished.png`.
- [ ] Error/Empty states fuer unklare Engine-Zustaende.

---

## Track G - Asset- und Repo-Hygiene

- [ ] Alte Karten-/Ring-Sichtungen speicherarm archivieren oder klar als `archive` markieren.
- [ ] `artifacts/` aufraeumen: nur aktuelle Sichtungen prominent, alte nicht loeschen ohne Auftrag.
- [ ] Tote Generatoren markieren/archivieren, damit sie nicht versehentlich wieder genutzt werden.
- [ ] Build pruefen nach UI-Schritten.
- [x] Build pruefen nach UI-Schritten. Stand 9.7.: `xcodebuild -project
  Poch1441.xcodeproj -scheme Poch1441 -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
  erfolgreich nach Phase-2/Phase-3-Feinschliff. Stand 9.7. spaeter: erneut
  erfolgreich nach Guided-Tutorial-Seed und Coach-Schiene; Log:
  `/tmp/poch1441-build-guided-3.log`. Stand 9.7. spaeter: erneut erfolgreich
  nach Pause-Menue und Phase-1-PoolWinAccent; Logs:
  `/tmp/poch1441-build-menu-2.log`, `/tmp/poch1441-build-poolwin.log`.
  Stand 9.7. spaeter: erneut erfolgreich nach Phase-3-Strafstrom-Polish;
  Log: `/tmp/poch1441-build-phase3-punish-2.log`. Stand 9.7. spaeter:
  erfolgreich nach Hilfe-Visuals, Theme-Vorschau und grossen Phasentiteln; Logs:
  `/tmp/poch1441-build-help-visuals.log`,
  `/tmp/poch1441-build-theme-preview.log`,
  `/tmp/poch1441-build-phase1-clean-title.log`. Stand 9.7. spaeter: erfolgreich
  nach Hilfe-Glossar und Gegner-Polish; Logs:
  `/tmp/poch1441-build-help-glossary.log`,
  `/tmp/poch1441-build-opponent-polish.log`. Stand 9.7. spaeter: erfolgreich
  nach Phase-3-Abrechnungs-Orchestrierung; Logs:
  `/tmp/poch1441-build-punish-orchestration.log`,
  `/tmp/poch1441-build-punish-target-3.log`. Stand 9.7. spaeter: erfolgreich
  nach Phase-2-Mockup-Statusline und Overlay-Polish; Logs:
  `/tmp/poch1441-build-phase2-clean-slider.log`,
  `/tmp/poch1441-build-help-compact.log`.
- [ ] Simulator sauber installieren, falls Bundle-State wieder falsche App zeigt.

---

## Sofort-Startreihenfolge Fuer Den Langen Loop

1. Phase 1/2/3 Screens visuell an Mockup-Proportionen angleichen.
2. Finales Kartendeck in echten Screens pruefen und nur bei Screen-Problemen anfassen.
3. Premium/Vivid Theme-State und Settings-Toggle einbauen.
4. Tutorial-Shell + Hilfe-Shell + Settings-Shell bauen.
5. Overlays und Gegnerreaktionen einziehen.
6. Simulator-Screenshots fuer Phase 1/2/3/Ende in Premium und Vivid erzeugen und iterieren.
7. Danach Feinschliff: Motion, Haptik, Reduce Motion.

---

## Offene Entscheidungen, Die Spaeter Schoen Waeren

Diese sind nicht noetig, um jetzt weiterzuarbeiten:

- Finale Charakterportraet-Assets. Stilrichtung ist entschieden: warme painterly
  Figuren, clean gerahmt, keine generischen Tokens.
- Exakte PM49-Ring-Produktion als echtes 3D/Render-Asset vs. aktueller Platzhalter.
- Umfang der ersten Tutorial-Texte in allen Sprachen.
- Sound/Haptik final am Geraet.

**Naechster Wiedereinstieg nach Kontextloeschung:**
`Lies tasks/todo.md und starte mit Track A1/A2/A3 Richtung Mockup. Karten, PM49 und Premium/Vivid-Theme-Strategie sind gelockt.`
