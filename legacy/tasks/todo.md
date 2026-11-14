# Poch 1441 - Arbeitsloop / Todo

**Stand:** 17. Juli 2026, laufender Produkt- und Lernmodus-Pass
**Ziel:** App nach `tasks/design-canon-2026.md` und
`tasks/board-art-direction.md` entwickeln. Ältere Mockups, PM-Nummern und
Materialstudien sind nur Provenienz und keine bindende Designvorgabe.

## Aktueller belastbarer Zwischenstand

Die folgenden älteren Implementierungs- und QA-Angaben dokumentieren erreichte
Zwischenstände. Vor einer Übernahme in den neuen Vertical Slice müssen sichtbare
Claims gegen den Stand vom 17. Juli erneut geprüft werden; sie überschreiben weder
Designkanon noch Board-Brief.

- [x] Phase 2 besitzt feste Bühnenzonen. Entscheidung, Aktionen, Gegner und Hand
  überlagern sich im normalen und geführten Zustand nicht mehr.
- [x] Mira, Kian und Juno nutzen erste echte Portrait-Assets mit neutralem,
  nachdenklichem und angespanntem Zustand sowie kompakten Reaktionsblasen.
- [x] Während des Gebens zieht sich das PM49-Brett zurück. Größere Kartenrücken
  fliegen sichtbar zu den drei Gegnerplätzen und zur Spielerhand.
- [x] Phase 3 zeigt die Gegner als Herkunft der Karten und inszeniert jede neu
  aufgedeckte Karte mit einem eigenen Flug zum zentralen Fächer.
- [x] Die erste Tutorial-Fläche wurde von einer Regelwand auf einen kurzen
  Proof-of-Fun-Einstieg mit Entscheidungsrail reduziert.
- [x] Der erste Timing-Pass verlangsamt Geben, Münzflug, Gegnerreaktion,
  Phasenwechsel und Kartenketten auf lesbare Beats.
- [x] Neue sichtbare Texte dieses Passes liegen in DE, EN, FR, IT, ES, NL und PL vor.
- [x] `TableTokenPile` übernimmt die natürlich überlappte PM68-Anordnung. Material,
  Randprofil, Fluggröße, Einrastbewegung und Zielpunkt wurden per Video und
  Einzelbildern gegen reale Bietaktionen geprüft.
- [~] Die Gegnerbilder sind als hochwertige Replicate-Triptychs integriert. Für den
  Freeze fehlen noch konsistente Gesten, Sieg/Niederlage und eine weniger fotografische
  finale Art Direction.
- [x] Der letzte Akt besitzt eine eigene letzte-Karte-Zäsur. Die letzten acht
  gespielten Karten bilden ein breites Abschluss-Tableau um das Medaillon; erst
  danach folgen Mitte, Restkarten und Ergebnis. Video-QA:
  `artifacts/qa/final-act-orchestrated-v2/`.
- [x] Der First-Run startet direkt in eine deterministische, spielbare Lernpartie.
  Sechs kurze Beats führen durch Geben, Trumpf, Melden, Pochen, Ausspielen und
  Abschluss, ohne die Aktionsflächen oder die Kartenhand zu verdecken.
- [x] Drei datengetriebene, regelkonforme Lernstarts sind für 3 und 4 Spieler
  vorhanden: Meldegewinn, bewusste Paar-/Poch-Entscheidung und Ausspielen mit
  menschlichem Anspielrecht. Die Seeds liegen in `App/TutorialScenarios.json`.
- [x] Jede Tutorial-Lektion besitzt einen Erfolgsabschluss. Der Fortschritt wird
  dauerhaft gespeichert, ist in Lektionen und Fortschrittsleiste sichtbar und endet
  nach dem letzten Akt in einem ruhigen Transfer zur freien Partie. QA:
  `artifacts/app-screens/tutorial-completion-v1-20260710/tutorial-complete.png`.
- [ ] Bestehende ältere Hardcode-Texte müssen in einem separaten Lokalisierungs-Audit
  in den neuen String-Katalog überführt werden.

**QA dieses Passes:** `artifacts/qa/poch-motion-real-action-v2/`,
`artifacts/qa/deal-motion-cinematic-v1/`,
`artifacts/qa/playout-motion-orchestrated-v1/`,
`artifacts/qa/guided-six-beats-v1/`,
`artifacts/qa/broad-screen-audit-v1/`,
`artifacts/qa/overlay-audit-v2/`,
`artifacts/qa/opponent-reaction-current/`.

---

## Verbindliche Layout-Leitplanke

Das alte Mockup liefert nur noch einzelne Kompositionserkenntnisse. Bindend sind
`tasks/design-canon-2026.md` und `tasks/board-art-direction.md`:

- Phase 1: große echte Poch Disc, breite lesbare Hand am unteren Rand, wenig UI-Lärm.
- Phase 2: klare getrennte Zonen für Einsatzsteuerung, Entscheidung, Gegner, Disc und
  Hand. Der alte vertikale Range-Regler ist keine bindende Lösung.
- Phase 3: große Kartenkomposition als Hauptbild, Disc beziehungsweise Mitte als
  räumliches Ziel, Hand am unteren Rand.
- Portrait und Landscape erhalten eigenständige adaptive Kompositionen desselben
  Zustands. Kein Text, Panel oder Gegner darf Karte, Zielfeld oder Primäraktion
  überlagern.
- Abweichungen von alten Bildern sind erwünscht, wenn sie Regelklarheit,
  Materialglaubwürdigkeit, Accessibility oder den Anti-Casino-Kanon verbessern.

## Harte Qualitaets-Gates Aus Tobsi-Kritik 9.7.

- [ ] **Gesamter Loop darf nicht mehr roh/basic wirken.** Jeder Screen braucht klare
  Hauptspannung, sichtbare Hierarchie, hochwertige Bewegung und keine Debug-Text-Anmutung.
- [x] **Münzen/Chips neu bewerten.** Sie müssen wie echte, schwere Spielchips in
  den Mulden liegen: materialig, gestapelt, perspektivisch ruhig, nie gelbe UI-Punkte.
  Verbindliche neue Referenz: `PM68 Glass Tokens In Pot` - Tokens liegen als schwere,
  natuerlich geschichtete Glas-/Metall-Chips in der Mulde, mit hartem Kontakt-Schatten,
  weichem Hoehenschatten und leichter Glasbrechung. Diese Anordnung ist Pflicht fuer
  alle Mulden-/Pott-Zustaende; keine flachen Punkte, keine Bonbon-Chips.
- [x] **Kartenrücken prominent nutzen.** Der gelockte Rücken trägt jetzt das
  Austeilritual mit großen Flugkarten und klaren Zielplätzen. Er bleibt außerdem in
  Gegnerhänden und Seitendeck sichtbar.
  Gegnerhaende, Deck-/Trumpf-Moment, Phase-2-Panels, Phase-3-Seitendeck/Medaillon.
- [~] **Texte und Labels auditieren.** Keine durcheinanderliegenden Texte, keine
  schlecht eingefuegten Debug-Hinweise, kein Overlap mit Karten/Mulden/Portraits.
  Stand 10.7.: Hauptscreens, Guided-Zustände, Hilfe, Tutorial, Einstellungen und
  Pause wurden im Simulator ohne sichtbare Überlagerungen geprüft. Ältere Rand- und
  Fehlerzustände sowie alle Übersetzungen brauchen noch einen automatisierten Sweep.
- [~] **Kartenlage gegen Mockup auditieren.** Besonders letzter Spielzug/Phase 3:
  Karten muessen dramatisch und mockup-nah liegen, mit schwarzer Kante/Schatten.
  Stand 10.7.: Geben, Spielerhand und laufender Ausspiel-Fächer sind mockup-nah
  gesetzt. Der echte letzte Kartenwurf und das Ergebnis-Handoff bleiben offen.
  Stand 10.7. später: Der leere Start von Akt 3 ist jetzt ein eigener, kompakter
  `Erster Zug`-Moment statt eines falschen `Riss`-Zustands. Mitte, Aufgabe, Gegner und
  Spielerhand bilden bereits vor der ersten Karte eine geschlossene Komposition. QA:
  `artifacts/app-screens/phase3-opening-v2-20260710/phase3-opening.png`.
- [~] **Gegner neu denken.** Namen duerfen nicht unfreiwillig altbacken wirken;
  Figuren brauchen Mimik/Spielzug-Reaktionen und klare Rollen ohne Hand-Leak.
  Stand 10.7. später: Der kuratierte Pool umfasst elf Personen mit jeweils sechs
  normalisierten Stimmungen. Identität, Blickrichtung und Außenkreis bleiben beim
  Mimikwechsel stabil; der Wechsel nutzt Crossfade und leichten Blur statt Bildsprung.
- [~] **Spieleranzahl anbieten.** Engine und `GameState` tragen 3-6 Spieler. Die
  produktionsreif geprüften Layouts und der sichtbare Settings-Picker sind derzeit auf
  3 oder 4 begrenzt; 5/6 benötigen einen eigenen kompakten Gegnerkranz.
- [~] **Geführter Modus nach Tutorial.** Nach dem Tutorial soll ein Begleitmodus jeden
  Spielzug erklaeren: Optionen, Idee dahinter, Auswirkungen, empfohlene Entscheidung,
  ohne verdeckte Karten zu verraten. Muss jederzeit abschaltbar sein.
  Stand 10.7.: sechs kontextuelle Beats und abschaltbare Assist-Hinweise sind
  spielbar. Tiefergehende Erklärungen pro legaler Alternative fehlen noch.
- [ ] **UX-Elemente ent-basic-en.** Buttons, Slider, Toggles und Panels muessen wie
  Poch-1441-Objekte wirken, nicht wie generische iOS-Demo-Komponenten.

## Dramaturgie-/Spieldynamik-Gates

- [x] **Echte Partie statt isolierter Runden.** `BotMatchSource` nutzt jetzt
  `PochKit.Match`: Konten, Mulden, Geberrotation und Gegneridentitäten bleiben stabil,
  Rundensitze werden an der GameState-Grenze auf feste UI-Sitze gemappt und Quick
  endet nach 12 Runden in einer Partieabrechnung. Engine-Tests und Simulator-Build
  sind grün. Details: `tasks/match-session-integration.md`.
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
- [~] **Orchestrierung auditieren.** Die bestehenden Millisekunden-Dokumente fuer
  Muenzen/Karten/Effekte muessen mit dem echten UI abgeglichen werden: Timing, Layering,
  Fokuswechsel, Haptik, Sound und Abbruchfaelle.
  Stand 10.7.: Geben, Poch-Transfer und Ausspielkette wurden per Video-Frames
  ausgerichtet. Sound, Haptik, Reduce Motion und Unterbrechungsfälle bleiben offen.
- [ ] **Eye-candy mit Spielklarheit koppeln.** Jede Animation muss Regelverstaendnis
  verbessern oder emotionale Spannung erhoehen; keine Deko-Effekte, die Poch als
  Casino/Arcade missverstaendlich machen.
- [x] **FTUE als Proof-of-Fun bauen.** Erste Minute: erst Kartenflug, Ring, Mulde,
  Gegnerreaktion und eine klare Entscheidung erleben; Regeln danach kontextuell erklaeren.
  Kein Start mit Regelwand oder Prozent-Tutorial. Stand 10.7.: frische Installation
  startet direkt mit Kartenflug und geführter, deterministischer Runde.
- [ ] **Value before explanation.** Jede Erklaerung muss an einen sichtbaren Spielwert
  gekoppelt sein: stehender Poch, Limit/Wand, Strafstrom, Kettenriss, gewonnene Mulde.
- [ ] **Ethical retention only.** Keine Pricing-Anchors, Signup-Walls, Fake-Progress,
  kuenstliche Knappheit oder FOMO. Langzeitbindung entsteht aus Meisterschaft,
  Gegnerkenntnis, Tisch/Deck-Identitaet und Chronik.
- [ ] **UX-Ideen-Prueffrage.** Jede neue UX-Idee muss mindestens eines verbessern:
  Regelverstaendnis, emotionale Spannung oder langfristige Bindung an Tisch/Gegner/Chronik.
  Reine Effekt-Deko fliegt raus.

**Stand 9.7. Arbeitsloop:** Gates aufgenommen. Erste globale Politur umgesetzt:
materialigere `TableChip`-Komponente, sichtbarere Gegner-Kartenruecken, DealOverlay
rendert nach Skip keine Rest-Flugkarten mehr, Zug-Begleiter hat Settings-Schalter und
zustandsbezogene Texte, Phase 3 zeigt ein Rueckseiten-Seitendeck neben dem Medaillon.
Aktuelle QA-Screens: `artifacts/app-screens/global-polish-v2b-20260709/` und
`artifacts/app-screens/global-polish-v3b-20260709/phase3-side-deck.png`.
Spaeterer Stand: Phase-2-Gegnerrollen auf moderne Verhaltenslabels reduziert,
Statuswerte ausgeschrieben, Phase-3-Medaillon als Centerpot-Objekt umgebaut,
Zug-Begleiter in Phase 2 so verschoben, dass er Hand und Gegner nicht verdeckt.
QA-Screens: `artifacts/app-screens/phase23-polish-v1-20260709/`.
Naechster Stand: Phase-2-Buttons materialiger mit Icon-Ankern, Gegner-Reaktionspills
sichtbarer, Settings haben einen Spieler-Picker fuer 3/4 Spieler; `GameState` kann die
Tischgroesse neu konfigurieren. 5/6 bleiben Engine-faehig, aber wegen eigenem Layout-Gate
noch nicht als UI-Option freigegeben. QA-Screens:
`artifacts/app-screens/player-count-v1-20260709/`,
`artifacts/app-screens/opponent-reactions-v1-20260709/`.
Aktueller Layout-Pass: Phase 2 komprimiert (Slider/Ring/Actions/Gegner/Hand),
`-coachOff` als QA-Schalter ergaenzt, Phase-2-Zug-Begleiter als kompakter Lehr-Pill
umgebaut, Phase 3 auf radialeren Kartenfaecher hinter Medaillon gestellt. QA:
`artifacts/app-screens/mockup-pass-v2-20260709/`,
`artifacts/app-screens/mockup-pass-v3-20260709/`,
`artifacts/app-screens/mockup-pass-v6-20260709/`,
`artifacts/app-screens/mockup-pass-v7-20260709/`. Build:
`/tmp/poch1441-build-mockup-pass-v8.log`.
Chip-/Muenzen-Pass: `TableChip` materialiger und stapelbarer gemacht, PM49-Mulden
und Centerpot zeigen ruhigere Mini-Stapel statt UI-Punkte, Phase-2-Kompaktring nutzt
kleine Chip-Stacks. QA: `artifacts/app-screens/chip-material-v1-20260709/`. Build:
`/tmp/poch1441-build-chip-material-v1.log`. Offen: Timing/Layering der Chipfluege
gegen die Millisekunden-Orchestrierung auditieren und im echten Ablauf weiter polieren.
Aktueller Screen-Fix: Phase-2-Coach nicht mehr als externes Overlay ueber Ring/Range,
sondern als kleiner Inline-Hinweis im Pochen-Flow; Phase-3-Spacer korrigiert, damit
Status nicht in Karten/Medaillon liegt und der Kartenstrom eine zusammenhaengendere
Buehne bekommt. QA: `artifacts/app-screens/phase2-coach-inline-v1-20260709/`,
`artifacts/app-screens/phase3-cardfan-reserve-v1-20260709/`. Builds:
`/tmp/poch1441-build-phase2-coach-inline.log`,
`/tmp/poch1441-build-phase3-cardfan-reserve-v1.log`.
Harter UX-Stabilisierungspass nach Kritik "Screens wirken wie Vollkatastrophe":
eigener Simulator `Poch1441-iPhone16Pro` angelegt (`.poch-simulator-udid`), Phase-2-
Gegnerpanels von kindlichen Portrait-/Kartenstapel-Kacheln auf ruhigere Sitzplaketten
mit Rollen-Sigil umgebaut, Chip-Rendering entbuntet und materialiger/ruhiger gemacht,
Pochen-Status/Hinweis/Metriken in eine einzige Entscheidungs-Karte zusammengefuehrt,
Copy von interner "Wand" auf konkrete Poch-Mulde/Einsatz/Gegnerantwort geaendert.
QA: `artifacts/app-screens/ux-stabilize-v1-20260709/`,
`artifacts/app-screens/ux-stabilize-v2-20260709/`,
`artifacts/app-screens/ux-stabilize-v3-20260709/`,
`artifacts/app-screens/ux-stabilize-v4-20260709/`. Builds:
`/tmp/poch1441-build-ux-stabilize-v1.log`,
`/tmp/poch1441-build-ux-stabilize-v2.log`,
`/tmp/poch1441-build-ux-stabilize-v3.log`,
`/tmp/poch1441-build-ux-stabilize-v4.log`.
Wichtig: Dieser Pass ist bewusst nur Schadensbegrenzung, kein Design-Freeze. Alle
Phasen brauchen weiterhin einen breiten Kompositions-/Dramaturgie-Rework gegen Mockup.
Folgepass `ux-character-stage`: Phase 2 nutzt wieder kompakte Charakter-Panels mit
Portrait, Kartenruecken-Anmutung und Reaktionszeile statt abstrakter Sigil-Kacheln;
Panels danach verkleinert, damit Hand und Gegner nicht mehr so stark kollidieren.
`TableChip` weiter entbonbonisiert: flacherer metallischer Chip mit gedämpfterem
Highlight und Materialringen. Phase 3-Hand deutlich zur Kartenstrom-Buehne hochgezogen,
damit Status und Spielerhand nicht mehr durch ein grosses schwarzes Loch getrennt sind.
QA: `artifacts/app-screens/ux-character-stage-v1-20260709/`,
`artifacts/app-screens/ux-character-stage-v2-20260709/`. Build:
`/tmp/poch1441-build-ux-character-stage-v2.log`.
Folgepass `phase2-actions`: Phase-2-Eröffnungszustand entstapelt: Nur die realen
Aktionen `Passen` und `Pochen` werden gezeigt, solange `Mitgehen`/`Erhoehen` nicht
legal sind. Entscheidungstext nennt jetzt konkret Paar, Einsatz und Ziel
(`Pott + Mulde`) statt interner Kurzbegriffe. Gegnerplaketten sind kompakter, ohne
gequetschte Rollenkuerzel; Stats lesen als `8 Karten · 51 Chips`. Premium und Vivid
wurden im dedizierten Simulator gesichtet. QA:
`artifacts/app-screens/phase2-actions-v1-20260709/`. Build:
`/tmp/poch1441-build-phase2-actions-v1.log`.
Deal-/Kartenruecken-Pass: Deal-Ziele aus dem Header heraus in die Ring-/Tischbuehne
verschoben, damit Logo, Phase und Trumpf nicht mehr von Kartenruecken/Portraits
ueberlagert werden. Gegner-Zielkarten sind groesser und sitzen als Tischplaetze um
den Ring; Zielrahmen danach stark entschaerft, damit nicht Debug-Boxen, sondern die
Ruecken und Flugbahnen wirken. QA: `artifacts/app-screens/deal-stage-v2-20260709/`,
`artifacts/app-screens/deal-stage-v3-20260709/`. Build:
`/tmp/poch1441-build-deal-stage-v4.log`.
Poch-Muenzen-Pass: `PochBetFlight` zielt nicht mehr auf fixe Prozent-Koordinaten,
sondern rechnerisch auf das Zentrum des kompakten PM49-Rings in Phase 2. Flugchips
wurden groesser/materialiger gemacht, Impact-Ring in der Poch-Mitte klarer. QA:
`artifacts/app-screens/pochflight-target-v1-20260709/`,
`artifacts/app-screens/pochflight-chips-v2-20260709/`. Build:
`/tmp/poch1441-build-pochflight-chips-v2.log`.
Offen: Fuer die finale Muenzdramaturgie reicht Screenshot-QA nicht; hier braucht es
Video-/Frame-Audit gegen die Millisekunden-Orchestrierung, damit Flug, Impact,
Zählerwechsel und Gegnerreaktion wirklich als ein Beat wirken.
Weiterhin offen und kritisch: echte Gegner-Assets/Mimik fehlen, Phase 2 wirkt noch
zu gestapelt, Phase 3 braucht finalen letzten-Spielzug-Zustand statt nur Preview,
und die Chip-/Muenzen-Fluege muessen gegen die vorhandene Millisekunden-Orchestrierung
pixelgenau geprüft werden.
Layout-Pass `layout-stage-v1..v5`: Phase 2 von Spacer-Stapel auf feste Bühnenzonen
umgestellt (Range/Ring, Entscheidung, Aktionen, Gegner, Hand). Buttons schneiden nicht
mehr in die Statuskarte, illegale Aktionen bleiben ausgeblendet. Gegnernamen von
altertümlichen Platzhaltern auf neutrale Namen (`Mira`, `Kian`, `Juno`) umgestellt und
Gegnerpanels kleiner/ruhiger gemacht. Kleine Ringchips und Muldenchips wurden vergrößert,
damit sie eher als Spielchips statt als farbige Punkte lesen. Phase 3 nutzt eine
absolutere Mockup-Bühne: großer zentraler Kartenfächer, Medaillon, Seitendeck,
Status darunter, Hand unten größer/angehoben. QA:
`artifacts/app-screens/layout-stage-v1-20260709/`,
`artifacts/app-screens/layout-stage-v2-20260709/`,
`artifacts/app-screens/layout-stage-v3-20260709/`,
`artifacts/app-screens/layout-stage-v4b-20260709/`,
`artifacts/app-screens/layout-stage-v5-20260709/`. Build:
`/tmp/poch1441-build-layout-stage-v5.log`.
Offen nach Sichtung: Gegner sind noch Code-Platzhalter und nicht design-award-würdig,
Phase 2 braucht weniger Panel-Optik und mehr Tischdramaturgie, Phase 3 braucht einen
eigenen finalen Ketten-/letzter-Zug-Zustand, und die große Leere zwischen Beats muss
über sinnvolle Karten-/Chip-/Gegnerbewegung statt statischen Text gefüllt werden.
Folgepass `layout-stage-v6..v7`: Gegnerzeile von hohen Kartenpanels auf flachere
Tischplaketten umgebaut; keine abgeschnittenen Gegnerdetails mehr (`8 Karten` plus
Chipzahl statt `... c...`). Phase-3-Status von langem Satz auf starken Beat umgestellt
(`WÄHLE ANSPIEL`, `KARTENSTROM LÄUFT`) mit kurzer Regelzeile darunter. QA:
`artifacts/app-screens/layout-stage-v6-20260709/`,
`artifacts/app-screens/layout-stage-v7-20260709/`. Build:
`/tmp/poch1441-build-layout-stage-v7.log`.
Offen nach Sichtung: Phase 2 ist strukturell stabiler, aber noch zu statisch; finale
Gegner brauchen echte Assets/Mimik/Animationsstates, und die Entscheidungszone muss
perspektivisch noch mehr wie ein Tischmoment statt wie eine Formular-Karte wirken.
Folgepass `phase2-seat-cleanup`: Phase-2-Gegner von Debug-Kartenpanels weiter zu
ruhigeren Tischplaetzen reduziert; Rollen/Stats/Reaktionszeile sind lesbarer, Handfächer
unten kleiner und stärker als Bottom-Bleed, Pochen-Coach-Overlay in Phase 2 entfernt,
damit keine Lernkarte mehr Ring, Slider oder Buttons verdeckt. `TableChip` erneut
flacher/metallischer gemacht, damit Muldenchips weniger wie gelbe UI-Punkte wirken.
QA: `artifacts/app-screens/phase2-seat-cleanup-v3-20260709/`. Build:
`/tmp/poch1441-build-phase2-seat-cleanup-v3.log`.
Offen nach Sichtung: Gegner sind weiterhin Code-Platzhalter statt echter Art-Direction;
Entscheidungskarte/Buttons brauchen noch mehr Luft und Phase 2 braucht echte
Gegner-Mimik/Chipflug-Video-QA, bevor sie design-award-faehig ist.
Folgepass `opponent-medallions`: Phase-2-Gegner erneut entpanelt: lange
Sitz-Kapseln und Debug-Rails entfernt, stattdessen runde Medaillons mit
angedeutetem Kartenruecken-Faecher, Name/Rolle/Ministatus und Reaktionszeile.
Guided-Sichtung bleibt frei von Ueberlagerungen. QA:
`artifacts/app-screens/opponent-medallions-v2-20260709/`. Build:
`/tmp/poch1441-build-opponent-medallions-v2.log`.
Offen: Das ist nur ein besserer Code-Zwischenstand. Fuer den Zielzustand muessen
Mira/Kian/Juno als echte painterly Character-Assets mit Mimikstates kommen
(`neutral`, `denkt`, `passt`, `geht mit`, `pocht/erhoeht`, `gewinnt/verliert`).
Phase-1-Handlift: Kartenhand im Melden-Endzustand deutlich naeher an den PM49-Ring
gezogen, damit der Screen wie eine zusammenhaengende Mockup-Buehne wirkt und nicht
wie Ring oben plus isolierte Hand unten. QA:
`artifacts/app-screens/phase1-handlift-v2-20260709/`. Build:
`/tmp/poch1441-build-phase1-handlift-v2.log`.
Phase-2-Decision-Dial: Entscheidungskarte von langem Info-/Formularpanel zu einem
kompakteren Tischmoment umgebaut. Rechts zeigt ein runder Einsatz-Fokus `SETZE 1`
plus Poch-Mulde, links bleiben nur Zugstatus, kurze Konsequenz und vier knappe
Druckwerte. Premium/Guided/Vivid gesichtet; Guided bleibt ohne Overlay-Kollision,
Vivid kippt nicht in Neon/Casino. QA:
`artifacts/app-screens/phase2-decision-dial-v1-20260709/`. Build:
`/tmp/poch1441-build-phase2-decision-dial-v1.log`.
Offen: Buttons und Gegnerreaktionen brauchen spaeter noch echte Moment-Animationen
(Druckaufbau, Antwort, Chipflug, Mimik), damit Phase 2 nicht nur statisch schoen,
sondern spielerisch spannend wird.
Guided-/Overlay-Pass `guided-overlays-v1`: Tutorial-Overlay auf "erste geführte
Partie" umgebaut: erst Wert erleben, dann Regeln; Begleiter erklärt sehen/wägen/spielen
statt mit Regelwand zu starten. Hilfe erweitert um konkrete Tisch-Lesbarkeit
(`Farbiger Muldenrand`, `Violette Mitte`, `Großer Kartenfächer`), damit neue Spieler
direkt verstehen, was UI-Elemente bedeuten. Coach-Copy in Phase 2/3 konkretisiert:
Einsatz, Poch-Mulde, Gegnerantwort, Kettenriss und Anspielwechsel werden als
Konsequenzen erklärt. Settings-Sichtung bestätigt Theme-/Spielerwahl weiter lesbar.
QA: `artifacts/app-screens/guided-overlays-v1-20260709/`. Build:
`/tmp/poch1441-build-guided-overlays-v1.log`.
Offen nach Sichtung: Tutorial ist inhaltlich besser, aber erster Overlay-Screen ist
noch dicht; spätere Feinarbeit sollte entweder mehr gestaffelte Tutorial-Seiten oder
einen echten interaktiven Walkthrough mit Spotlight/Next-Step statt langer Scrollfläche
bauen.
Folgepass `guided-spotlight/opponents/chip/endstage`: Externer Zug-Begleiter in
Phase 2 kollidiert nicht mehr mit Gegnern; Phase-2-Copy gekuerzt. Gegnerplaketten
haben groessere Portraits, sichtbarere Kartenruecken und klarere Reaktionspills.
`TableChip` nutzt jetzt goldene Metallfassung plus gedämpftes farbiges Zentrum
statt Bonbon-Kreis. Partie-Ende/Punishing bekam ein gefasstes Ergebnis-Panel mit
Gewinner, Rueckblick und Chips, damit der Zustand nicht mehr als drei Zahlen im
leeren Raum wirkt. QA:
`artifacts/app-screens/guided-spotlight-v2-20260709/`,
`artifacts/app-screens/opponents-v1-20260709/`,
`artifacts/app-screens/chip-v1-20260709/`,
`artifacts/app-screens/endstage-v1-20260709/`. Builds:
`/tmp/poch1441-build-guided-spotlight-v2.log`,
`/tmp/poch1441-build-opponents-v1.log`,
`/tmp/poch1441-build-chip-v1.log`,
`/tmp/poch1441-build-endstage-v1.log`.
Offen nach Sichtung: echte Gegner-Art/Mimik ist weiterhin groesster sichtbarer
Platzhalter; Endscreen braucht spaeter eine richtige visuelle Bühne/Chronik statt
nur Premium-Panel; Phase 3 braucht noch einen finalen letzter-Spielzug-Zustand
mit mockup-naher Kartenlage.
Folgepass `deal-no-fronts/phase3-deal`: Phase-1-Hand zeigt Vorderseiten erst nach
abgeschlossenem Deal, damit die Rueckseiten-Inszenierung nicht mehr als Ghosting ueber
sichtbaren Karten liegt. Deal-Zielrahmen wurden entfernt; die Ruecken selbst tragen
die Inszenierung. Phase 3 wurde tiefer und kompakter gegen das Mockup gesetzt:
zentraler Kartenfaecher mit Medaillon naeher am Zielbild, untere Hand staerker
ueberlappt und sauberer als separater Spielerfächer. QA:
`artifacts/app-screens/phase3-deal-v1-20260709/`,
`artifacts/app-screens/deal-no-fronts-v1-20260709/`. Builds:
`/tmp/poch1441-build-phase3-deal-v1.log`,
`/tmp/poch1441-build-deal-no-fronts-v1.log`.
Offen nach Sichtung: Gegner-Zielruecken beim Deal sind noch etwas transparent/technisch;
Phase 3 braucht weiterhin einen echten finalen Ketten-/letzter-Zug-Zustand mit
dramatischer Kartenfolge statt nur Preview-Anspiel.

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

Der verbindliche Qualitäts- und Umsetzungsplan für den nächsten großen Sprung liegt in
`tasks/goty-2026-masterplan.md`. Bei Widersprüchen zwischen früheren erledigt-Markierungen
und realer Nutzersichtung gilt der Masterplan: Verständnis, physische Glaubwürdigkeit und
gemessene Abnahme gewinnen vor Implementierungsstatus.

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
  Stand 9.7. spaeter: Screen-Dichte reduziert, Gegnerpanels/Hand/Slider kompakter,
  Coach von der unteren Kollisionszone weggezogen. Clean-Screen ist deutlich stabiler;
  Guided-Variante bleibt offen fuer weitere Feinarbeit bei Breite/Position.
  QA: `artifacts/app-screens/mockup-pass-v3-20260709/phase2-guided.png`.
  Stand 9.7. spaeter: externer Phase-2-Coach entfernt; Assist-Erklaerung sitzt als
  kleiner Inline-Lehrchip unter der Statuszeile und verdeckt weder Ring noch Slider.
  QA: `artifacts/app-screens/phase2-coach-inline-v1-20260709/phase2-guided-inline.png`.
  Stand 9.7. abends: Phase-2-Entscheidungsfeld, Action-Dock, Gegnerreihe und
  untere Hand wieder in klarere vertikale Zonen getrennt; Handkarten vergroessert
  und als Bottom-Bleed Richtung Mockup gesetzt. QA:
  `artifacts/app-screens/phase2-hand-bleed-v2-20260709/phase2-premium.png`,
  `artifacts/app-screens/phase2-hand-bleed-v2-20260709/phase2-demo.png`.
  Offen bleibt: Action-Dock und Gegner muessen gestalterisch neu auf Mockup-Niveau,
  nicht nur kollisionsfrei.
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
  Stand 9.7. spaeter: Faecher ist nun radialer und hinter dem Center-Medaillon
  gelayert statt als flache Reihe; separater Centerpot-Pill wurde entfernt,
  Kettenstatus sitzt in der Statuszone unter dem Faecher. Noch offen: letzter
  Spielzug und Seitendeck brauchen weitere Bewegungs-/Layer-Politur. QA:
  `artifacts/app-screens/mockup-pass-v3-20260709/phase3-preview.png`,
  `artifacts/app-screens/mockup-pass-v6-20260709/phase3-preview.png`,
  `artifacts/app-screens/mockup-pass-v7-20260709/phase3-preview.png`.
  Stand 9.7. spaeter: expandierender Spacer vor der Statuszeile entfernt,
  Gegnerrahmen kompakter, Kartenfaecher reserviert echte Layout-Hoehe; Status liegt
  nicht mehr im Medaillon/Kartenbild. QA:
  `artifacts/app-screens/phase3-cardfan-reserve-v1-20260709/phase3-preview.png`.
  Offen: Abstand zwischen Status und unterer Hand sowie letzter Spielzug weiter
  gegen Mockup feintunen.
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
  letzter Karte und Finisher sichtbar. Stand 10.7.: letzter Kartenwurf, Stille,
  Abrechnung und Ergebnis sind als getrennte Beats orchestriert; echter
  Replay-Rückblick fehlt.
- [~] Button-Hierarchie: neue Partie, Rueckblick, Einstellungen/Hilfe. Stand:
  klare Primäraktion `Nächste Runde` als dunkles Materialobjekt mit Goldkante;
  Rückblick fehlt.

---

## Track B - Tutorial / Onboarding

- [ ] Kein separates Tutorialbrett verwenden. Die echte Track-A-Poch-Disc durchläuft
  die vier Lernzustände `Orientieren`, `Verbinden`, `Beweisen`, `Loslassen`; Form,
  Material und 8+1-Geometrie bleiben identisch zum freien Spiel.
- [ ] Tutorial-Komposition in Portrait und Landscape adaptiv umsetzen. Landscape:
  stabile Gegnerachse links, Lernhandlung mittig, Disc rechts, Hand unten. Rotation
  übernimmt den bestätigten Beat ohne Neustart oder Überspringen.
- [ ] Technische Platzhalter, Messlinien und Konstruktionsbeschriftung aus jeder
  produktiven Lernansicht ausschließen. Labels sind lokalisiert und verschwinden
  nach dem Lernmoment vollständig.
- [ ] Geführte Erstpartie mit fester Gegnerbesetzung. In den ersten 45 Sekunden nur
  Name, Portrait und Sitz; danach optionaler Lernbeat `Gegner lesen` mit genau einer
  öffentlichen Tendenz. Keine Handstärke-Tells.
- [ ] Freie Partie: `Tisch automatisch besetzen` als empfohlener Standard und
  `Mitspieler wählen` als freiwillige Vertiefung mit maximal drei Tendenzbegriffen.

- [x] Erster Start: kurze, spielbare Einführung statt Text. Der erste App-Start
  springt direkt in eine deterministische geführte Runde; DEBUG kann den Zustand
  mit `-firstRun` reproduzieren.
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
  Overlay-Reiter. Stand 10.7.: als direkte Lektion mit eigener Paar-Hand und
  echter Eröffnungsentscheidung spielbar.
- [~] Tutorial Kapitel 3: Ausspielen, Kette, Stopps, Mitte. Stand: hochwertigere
  scrollbare Overlay-Seite mit Kartenfächer-Miniatur und klarer Footer-Aktion.
  Stand 10.7.: direkte Lektion überspringt Pochen ausschließlich durch legale
  Pass-Aktionen und startet mit menschlichem Anspielrecht.
- [x] Überspringen über den abschaltbaren Begleiter und Wiederholen über das Menü.
- [~] Kontext-Hinweise als elegante Coach-Bubbles; nie blockierend, nie zu viel Text.
  Stand 9.7.: Phase 1 kompakter Coach-Chip, Phase 2/3 dynamische Coach-Bubbles
  eingebaut. Stand 9.7. spaeter: Guided-Mode-Schiene pro Phase ergaenzt; sie
  erklaert nur den naechsten Schritt und laesst die Aktionsflaechen frei.
  Screens: `artifacts/app-screens/guided-phase2.png`,
  `artifacts/app-screens/guided-phase3-v2.png`. Stand 10.7.: echte Progression
  über sechs Beats umgesetzt und mit `artifacts/qa/guided-six-beats-v1/`
  geprüft. Offen bleiben gezielte Alternativentscheidungen und drei getrennte
  Tutorial-Szenarien.
- [~] Tutorial-Seeds/States vorbereiten oder Mock-State fuer UI bauen, bis Engine-Seeds stehen.
  Stand: `TutorialScenarios.json` enthält validierte Seeds für 3/4 Spieler;
  `tools/find_tutorial_seeds.swift` kann sie gegen PochKit neu ermitteln.
  QA: `artifacts/qa/tutorial-lessons-v1/`.

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

- [ ] Tischwahl implementieren: große Vorschauen für `Poch Disc` und `Unterwegs`,
  Segment `Nur diese Partie` / `Als Standard` und eine Primäraktion. Session-Override
  und gespeicherten Standard getrennt halten; Standard unter `Tisch & Material`
  jederzeit änderbar. Default der Gültigkeit: `Nur diese Partie`.
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
- [x] Phase-3-Ausspielen: Start-/Preview-Fächer auf 8 Karten verbreitert,
  Coach-Box aus dem Hauptscreen entfernt; Status bleibt kompakt, Kartenfächer +
  Medaillon tragen wie im Mockup die Szene. QA:
  `artifacts/app-screens/audit-20260709-0521/phase3-premium-cleanstream.png`.
  Stand 9.7. spaeter: sichtbare Phase-3-Bezeichnung auf `DATEN-STROM`
  umgestellt, Top-Faecher kompakter/vertikaler Richtung Mockup gezogen,
  Medaillon vergroessert, Seitendeck sichtbarer, Spielerhand groesser als
  unterer Bleed; Guided-Spotlight-Rahmen in Phase 3 entfernt, damit die
  Kartenbuehne nicht von Debug-Overlays verdeckt wird. QA:
  `artifacts/app-screens/phase3-mockup-v4-20260709/phase3-premium.png`,
  `artifacts/app-screens/phase3-mockup-v4-20260709/phase3-guided.png`.
  Stand 9.7. abends: Cyber-Restbezeichnung `DATEN-STROM` wieder entfernt;
  Header/Phasentoken/Curtain verwenden `AUSSPIELEN`. QA:
  `artifacts/app-screens/phase2-hand-bleed-v1-20260709/phase3-ausspielen.png`.
- [x] Phase-2-Mockup-Komposition: grosse Coach-Box aus dem Hauptscreen entfernt
  und durch kompakte Statuszeile ersetzt (`DEIN ZUG`, Gegneraktion, Ergebnis);
  Range-Slider von losgeloesten Chip-/Wand-Balken bereinigt. QA:
  `artifacts/app-screens/audit-20260709-0521/phase2-premium-clean-slider.png`,
  `artifacts/app-screens/audit-20260709-0521/phase2-vivid-clean-slider.png`.
- [x] Trumpf-/Skip-Puls entschaerft: kurzer Material-Akzent aus dem Brettzentrum,
  kein grosser grauer Overlay-Kreis ueber Ring/Karten.
- [~] Action-Badges über Gegnern: passt, geht mit, erhöht, pocht. Stand:
  Phase-2-Panels zeigen Reaktions-Bubbles; Animation/Timing und Audio-Haptik fehlen.
  Stand 9.7. spaeter: Phase-2-Kompositionspass v4 reduziert Gegnerkarten auf
  kompakte Persona-Plaketten, hebt die eigene Hand wieder an, beruhigt die
  Muenzen und entschärft den Guided-Overlay-Rahmen. QA:
  `artifacts/app-screens/phase2-table-v4-20260709/phase2-clean.png`,
  `artifacts/app-screens/phase2-table-v4-20260709/phase2-guided.png`.
  Stand 9.7. spaeter: Gegnerzeile als breitere Sitz-Plaketten neu gesetzt,
  lesbare Werte (`Karten`, `Chips`) statt Kryptokuerzel/Abkuerzungen,
  gemeinsame Tischleiste unter den Buttons, groessere Persona-Siegel und
  sichtbarer Reaktionsfuss. QA:
  `artifacts/app-screens/phase2-opponents-v4-20260709/phase2-premium.png`,
  `artifacts/app-screens/phase2-opponents-v4-20260709/phase2-guided.png`,
  `artifacts/app-screens/phase2-opponents-v4-20260709/phase2-vivid.png`.
  Stand 10.7.: echte Charakterportraits mit drei Stimmungen, handlungsbezogenen
  Sprechblasen und klarem Aktivzustand integriert. Offen: Gesten, Sieg/Niederlage,
  Audio und finale einheitlichere Illustrationssprache.
- [~] Gewinn-Overlay fuer Mulden: kurzer, matter Juwelen-Akzent, kein Dauer-Glow.
  Stand: Phase-1-Meldegewinn pulst jetzt direkt in der aktiven PM49-Mulde mit
  Materialkante und kleinen Splittern, synchron zum Chipflug. Stand 9.7. spaeter:
  Phase-3-Mitte/Endabrechnung hat nun Centerpot-Release und Chip-Impact beim
  Gewinner, ebenfalls als Materialeffekt statt Glow.
- [x] Poch-Chipflug: Chips fliegen beim Bieten aus Spieler-/Gegnerposition in den
  Poch-Pott, mit kurzem Material-Impact. Stand 9.7.: Zielpunkt auf die zentrale
  Poch-Mulde kalibriert, Impact ist kleiner/goldener und weniger UI-glow-artig.
  DEBUG-QA triggert die Sequenz mehrfach fuer stabile Simulator-Screenshots.
  Stand 9.7. später: Frame-Serie `poch-flight-material-v3-frames` zeigt
  deckendere, koerperlichere Chips und einen kompakten materialartigen Einschlag
  exakt im Poch-Zentrum. Stand 10.7.: echte Human- und Bot-Transfers zeigen
  Ursache, Flug, Materialkontakt und erst danach die gegnerische Antwort. Video-QA:
  `artifacts/qa/poch-motion-real-action-v2/`.
- [x] Phase-1-Deal-Ritual: Kartenrücken sollen als großzügige, schöne
  Austeilbewegung wirken, nicht als Debug-Zielmarker. Stand 9.7. spaeter:
  Gegner-Zielstapel aus dem PM49-Ring nach oben in eine leise Tischrand-Zone
  verlegt, statische Zielkarten stark abgedimmt, Deal-Portraet-Platzhalter
  entfernt, Flugkarten minimal groesser. QA:
  `artifacts/app-screens/phase1-deal-v3-20260709/deal-mid.png`,
  `artifacts/app-screens/phase1-deal-v3-20260709/phase1-done.png`.
  Stand 10.7.: großes cinematic Deal-Staging mit sichtbarem Deckanker,
  Portrait-Zielplätzen und deutlich größeren Kartenrücken umgesetzt. Video-QA:
  `artifacts/qa/deal-motion-cinematic-v1/`.
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
- [~] Eye-candy-/Orchestrierungs-Gate pro Phase: Vor jedem Freeze prüfen,
  ob der Screen innerhalb von 2 Sekunden intuitiv erklaert, was passiert,
  welche Entscheidung ansteht, welche Spannung daraus entsteht und wo die
  Belohnung landet. Stand 10.7.: die drei Hauptscreens bestehen den statischen
  Zwei-Sekunden-Test; Deal, Einsatztransfer und Ausspielkette wurden zusätzlich
  als Video geprüft. Ergebnisübergang, Audio/Haptik und seltene Fehlerzustände
  bleiben vor dem Freeze offen.

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
  `/tmp/poch1441-build-help-compact.log`. Stand 9.7. spaeter: erfolgreich nach
  Phase-2-Kompositionspass und Phase-3-Faecherpass; Logs:
  `/tmp/poch1441-build-mockup-pass-v1.log`,
  `/tmp/poch1441-build-mockup-pass-v2.log`,
  `/tmp/poch1441-build-mockup-pass-v3.log`,
  `/tmp/poch1441-build-mockup-pass-v5.log`,
  `/tmp/poch1441-build-mockup-pass-v7.log`,
  `/tmp/poch1441-build-mockup-pass-v8.log`. Stand 9.7. spaeter: erfolgreich
  nach Phase-2-Tischverdichtung, Guided-Overlay-Fix und Muenzen-Beruhigung;
  Logs: `/tmp/poch1441-build-phase2-table-v2.log`,
  `/tmp/poch1441-build-phase2-table-v3.log`,
  `/tmp/poch1441-build-phase2-table-v4.log`. Stand 9.7. spaeter: erfolgreich
  nach Phase-3-Mockup-Faecher, temporaerer `DATEN-STROM`-Benennung und Guided-Spotlight-Fix;
  Logs: `/tmp/poch1441-build-phase3-mockup-v3.log`,
  `/tmp/poch1441-build-phase3-mockup-v4.log`. Stand 9.7. spaeter: erfolgreich
  nach Phase-1-Deal-Zielstapel-Fix; Logs:
  `/tmp/poch1441-build-phase1-deal-v2.log`,
  `/tmp/poch1441-build-phase1-deal-v3.log`. Stand 9.7. spaeter: erfolgreich
  nach Phase-2-Gegnerplaketten/Stats-Fix; Logs:
  `/tmp/poch1441-build-phase2-opponents-v3.log`,
  `/tmp/poch1441-build-phase2-opponents-v4.log`. Stand 10.7.: erfolgreich nach
  finalem Timing-, First-Run-, Opponent- und Overlay-Pass; Log:
  `/tmp/poch1441-final-pass-build.log`. `swift test` besteht mit 50 PochKit- und
  5 Bot-Tests. Der Build enthält DE, EN, FR, IT, ES, NL und PL.
- [x] Simulator sauber installieren, falls Bundle-State wieder falsche App zeigt.
  Dedizierter Simulator: `Poch1441-iPhone16Pro`, UDID lokal in
  `.poch-simulator-udid`.

---

## Nächste GOTY-Schleife

1. Den letzten Ausspielzug, Gewinner-Moment und Ergebnis-Handoff als eigenen finalen
   Spannungsbogen bauen und gegen das Mockup frameweise prüfen.
2. Drei gescriptete Tutorial-Szenarien mit sicheren Lernentscheidungen ergänzen:
   Meldegewinn, Poch-Druck und Kettenstopp.
3. Sound- und Haptiksystem an die bestehenden Timing-Tokens anbinden; Reduce Motion
   und Unterbrechungsfälle gleich mitprüfen.
4. Zusätzliche Gegnerzustände Sieg/Niederlage/Geste produzieren und Reaktionen ohne
   Hand-Leak datengetrieben orchestrieren.
5. Vivid-Theme vollständig auf Tokens umstellen und Premium/Vivid über alle
   Haupt-, Overlay-, Ergebnis- und Fehlerzustände screenshotten.
6. Ältere sichtbare Hardcode-Texte vollständig in den String-Katalog überführen.
7. Danach Langzeitmotivation: Chronik, Statistiken, Meisterschaft und ehrliche
   Tisch-/Deck-Identität ohne künstliche Knappheit.

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
