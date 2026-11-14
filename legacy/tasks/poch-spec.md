# Poch - Spec & Projektplan (v1)

**Stand:** 7. Juli 2026
**Status:** Regelwerk EINGEFROREN (Gate A). Engine + SwiftUI-Fundament stehen; **55 Tests grün** (50 XCTest + 5 swift-testing). 10 Review-Runden dokumentiert (Abschnitt 16)

> **Design/Art-Direction:** kanonische Quelle ist `tasks/konzept.md` + `CLAUDE.md §0` (clean-modern-premium, Material>Glow, 2 Themes Premium-matt/Vivid). Wo dieses Dokument noch ältere Design-/Theme-/Wirtshaus-Formulierungen enthält, **überstimmt der Kanon** - dieses Dokument trägt das Regelwerk + den Projektplan, nicht die Art-Direction.
**Name:** Poch 1441 (entschieden 5.7.; Markenrecherche vor Store-Festlegung ausstehend) - Repo: github.com/tobsiberlin/poch1441

---

## 1. Vision & Positionierung

Poch (Pochspiel, erstmals 1441 in Straßburg erwähnt) ist der dokumentierte Urahn des Pokers - und es existiert keine polierte Mobile-Umsetzung. Wir bauen die definitive iOS-Version: ein modernes Premium-Kartenspiel (clean-digital, Material>Glow - Art-Direction in `tasks/konzept.md`), mit Balatro-artigem Game-Feel (Juice, nicht Pixel-Look) und KI-Gegnern mit Bluff-Persönlichkeiten.

**Positionierung v2 „Modern-first" (Tobsi, 6.7.2026, bindend - ersetzt die Historie-zuerst-Lesart):**
*„Ein modernes Premium-Kartenspiel, gestaltet mit zeitlosen Materialien, inspiriert von einem Spiel, das seit 1441 gespielt wird."* Die Reihenfolge ist Programm: Erst „außergewöhnliches Strategiespiel" (Hook), dann „seit 1441 gespielt" als Prestige-Stempel und Überraschung (Trojanisches Pferd im Splash/Onboarding). Die Historie ist Gütesiegel („zeitlos gut, weil jahrhundertelang bewährt"), nie staubiges Hauptverkaufsargument. Poch positioniert sich als Brettspiel-Erbe (Materialwelt von Schach/Backgammon/Go), ausdrücklich NICHT in der Poker-/Casino-Kategorie - dort wartet nur der Budget-Kampf gegen PokerStars-Polish.
- **Design-Richtung:** clean-modern-premium, dunkel (warmes Tinten-Schwarz), matte/pigmentierte Juwelen-Töne, gefräste Ringe, **Material > Glow**. Kein Holztisch, kein Mittelalter, kein Casino-Neon. Kanonische Art-Direction: `tasks/konzept.md` / `CLAUDE.md §0`.
- **Distinctive schlägt generic-premium:** die Charaktere - das *eine* warme, painterly Material im cleanen Rahmen - sind das Marken-Asset; der Kontrast warme Menschen / präzises System ist die Eigenständigkeit (2026: character-oriented + cozy zieht; Hades/Balatro/Gris gewannen über Eigenständigkeit, nie über „premium wie die Großen").

Store-sichere Alt-Formulierung bleibt gültig: „Europäisches Kartenspiel des 15. Jahrhunderts, einer der historischen Vorläufer des Pokers" - keine Fremdmarken und keine angreifbaren Superlative in Store-Metadaten; freche Zeilen wie „älter als Amerika" nur in Social-Content, nicht im Store.

**Qualitätsanspruch:** GOTY-Messlatte für jede Design-Entscheidung. Konkret heißt das: jede Interaktion hat Gewicht (Animation, Sound, Haptik), keine Ads, kein Dark-Pattern-Store, App-Store-Featuring-fähig.

**Zielplattform:** iOS 17+, Universal (iPhone + iPad). Swift, SpriteKit (Spieltisch) + SwiftUI (Menüs/Overlays).

## 2. Marktlage

- Skat/Doppelkopf/Schafkopf sind im App Store mehrfach besetzt (z.B. „Skat" von B-Interaktive, optisch 2010er-Niveau). Poch ist unbesetzt.
- Keywords „Poch", „Pochen", „Pochspiel", „Pochbrett" praktisch konkurrenzlos, aber geringes Suchvolumen → Marketing muss Nachfrage erzeugen (Story-PR), nicht nur einsammeln (ASO). Details Abschnitt 13.
- Zielgruppen: (a) DACH-Traditionskartenspieler, (b) Poker-Fans über die Herkunfts-Story, (c) Brettspiel-Community, (d) Familien (Pochbrett = klassisches Familienerbstück, Peak zwischen den Jahren).

## 3. Kanonisches Regelwerk v1 🧊 EINGEFROREN (Gate A, Tobsi, 5.7.2026)

**Freeze:** Ab hier keine Regeländerungen mehr. Beweglich bleiben ausschließlich Economy-PARAMETER (Startstack/Rundenlimit, Phase-4-Nachkalibrierung) und die spezifizierten Hausregel-Toggles. Jede echte Regeländerung bräuchte eine bewusste Gate-A-Wiedereröffnung durch Tobsi.

Quelle: Pagat.com (McLeod, „Poch"), abgeglichen mit de.wikipedia.org/wiki/Poch. Wo Quellen abweichen, gilt die hier gepinnte Regel.

**Material & Setup**
- 3-6 Spieler, in v1 frei wählbar (1 Mensch + 2-5 Bot-Charaktere); Standard-Empfehlung im UI: 4 (volle Ausbaustufe, Tobsi 5.7. - der frühere Vierertisch-Schnitt ist aufgehoben).
- 32er-Blatt (A hoch bis 7), französische Symbole mit eigenem Artwork.
- Pochbrett mit 9 Mulden: Ass, König, Dame, Bube, Zehn, Mariage, Sequenz, Poch, Mitte (Centerpot).
- Vor jedem Geben legt jeder Spieler 1 Chip in jede der 9 Mulden.
- Alle Karten werden einzeln im Uhrzeigersinn verteilt, beginnend links vom Geber, bis genau eine übrig bleibt; diese wird offen gelegt und bestimmt Trumpf. Der Geber teilt sich immer zuletzt aus - bei ungleicher Teilung haben deshalb die Spieler links vom Geber eine Karte mehr, nie der Geber. Exakte Handgrößen (Review-Runde 9, je ein Test): 3 Spieler 11/10/10 · 4 Spieler 8/8/8/7 · 5 Spieler 7/6/6/6/6 · 6 Spieler 6/5/5/5/5/5.

**Phase 1 - Melden**
- Halter von Trumpf-Ass/König/Dame/Bube/Zehn kassieren die jeweilige Mulde.
- Trumpf-König + Trumpf-Dame in einer Hand → zusätzlich Mariage-Mulde.
- Trumpf-7 + Trumpf-8 + Trumpf-9 in einer Hand → Sequenz-Mulde. (Pinned nach Pagat. v1-Toggle „Sequenz-Variante": beliebige Dreierfolge JEDER Farbe zählt; Tie-Break-Kaskade: höchste Folge > bei Gleichhöhe schlägt die Trumpf-Folge > sind beide nicht Trumpf, gewinnt der Spieler näher links vom Geber - die letzte Stufe ist ausdrücklich Poch-1441-Produktregel, kein belegter Standard [Runde 10]. Runde-9-Präzisierung - die frühere „Trumpf-Dreierfolge"-Formulierung war in sich widersprüchlich.)
- Konstruktive Folge der offenen Trumpfkarte (explizit, Review-Runde 8): Liegt Trumpf-König oder -Dame offen, ist die Mariage unmöglich; liegt Trumpf-7/8/9 offen, ist die Sequenz unmöglich - die Mulden bleiben stehen. Beides eigens getestet.
- Ist die offene Trumpfkarte selbst eine Bildkarte/Zehn/Ass, wird deren Mulde nicht gewonnen (Beispiel: Liegt der Trumpf-König offen, kann niemand die König-Mulde melden - sie bleibt stehen und wächst).
- Nicht abgeholte Mulden bleiben stehen und wachsen über Runden (eingebauter Jackpot - im HUD sichtbar machen).

**Phase 2 - Pochen**
- Kombinationen („Kunststücke"): gleiche RÄNGE zählen, Farben sind egal (vier Damen = Vierling). Vierling > Drilling > Paar; innerhalb gleicher Klasse zählt der höhere Rang; bei gleichen Paaren gewinnt das mit Trumpfkarte. Zwei Paare zählen nur als das höhere Paar; Drilling + Paar zählt nur als Drilling.
- Ohne mindestens ein Paar darf man nicht pochen (Kernregel; v1-Toggle „Pochen ohne Paar": höchste Einzelkarte gewinnt den Showdown, bei gleichem Rang schlägt die Trumpfkarte - konsistent zur Paar-Regel, Runde-9-Ergänzung).
- Bietablauf ab links vom Geber, im Uhrzeigersinn: passen, mitgehen oder erhöhen (1+ Chips), so viele Runden bis alle verbliebenen Einsätze gleich sind. Bluffen ist erlaubt und erwünscht.
- Showdown: beste Kombination gewinnt alle Einsätze + Poch-Mulde. Passen alle, bleibt die Poch-Mulde für die Folgerunden stehen und wächst mit jeder weiteren Ante (Review-Runde-7-Klarstellung).

**Phase 3 - Ausspielen**
- Der Poch-Gewinner beginnt (haben alle gepasst: der Spieler links vom Geber) und legt eine beliebige Karte.
- Wer die nächsthöhere Karte derselben Farbe hält, legt sie (Zwangszug) - die Kette reißt, wenn die benötigte Karte in keiner Hand mehr ist: Ass erreicht, die Karte ist die offen liegende Trumpfkarte, oder sie wurde früher in der Runde bereits gespielt (Präzisierung 5.7., Block 3 - der dritte Fall fehlte zuvor; erreichbar, wenn unterhalb einer bereits gelaufenen Kette neu angespielt wird). Alle drei Stopps sind für aufmerksame Spieler vorhersehbar - bewusster Skill-Anteil.
- Rundenende sofort, sobald eine Hand leer ist - auch mitten in einer laufenden Kette und auch dann, wenn die letzte Karte ein Zwangszug war. Restkarten der anderen werden bezahlt (1 Chip/Karte) und sind danach wertlos - es wird nichts nachgespielt.
- Wer die letzte Karte der Kette legte, eröffnet neu mit beliebiger Karte.
- Wer zuerst alle Handkarten los ist, gewinnt die Mitte-Mulde und erhält von jedem Gegner 1 Chip pro Restkarte.

**Einsatz- und Insolvenzregeln (gepinnt für v1, aus externem Review)**
- Erhöhungs-Cap: Niemand darf so erhöhen, dass der kleinste Stack der noch aktiven Spieler nicht mitgehen könnte. Damit gibt es in v1 kein All-in und keine Side-Pots.
- Passen in der Poch-Phase alle bis auf einen, gewinnt dieser ohne Aufdecken (der Bluff bleibt verdeckt - wichtig fürs Spielgefühl).
- Restkarten-Zahlung am Rundenende: maximal bis Stack 0, keine Schulden.
- Wer vor einem Geben die 9 Antes nicht aufbringt, scheidet aus (behält Restchips für die Endwertung). Sind weniger als 3 zahlungsfähige Spieler übrig, endet die Partie sofort - es gibt kein Zweispieler-Poch (Phase 3 degeneriert zu zweit).

**Kantenfälle (gepinnt für v1, aus Review-Runde 2)**
- Spieler mit 0 Chips nach den Antes: kann in der Poch-Phase nur passen (kein Frei-Mitgehen, kein All-in), spielt Phase 1 und 3 aber normal weiter und kann dort weiterhin gewinnen.
- „Ohne Paar kein Pochen" gilt für Eröffnen UND Mitgehen - ohne Paar bleibt nur Passen.
- Bietablauf formal: Es gibt kein „Mitgehen 0". Wer dran ist, eröffnet (1+ Chips) oder passt. Passen in der ersten vollständigen Runde alle, endet die Phase und die Poch-Mulde bleibt stehen.
- Erhöhungs-Cap formal: Eine Erhöhung auf Höchstgebot H ist nur zulässig, wenn für jeden noch aktiven Spieler gilt: H minus sein bereits gesetzter Einsatz <= sein Reststack. Der Cap wird nach jedem Passen über die verbliebenen Aktiven neu berechnet; gesetzte Chips eines Passenden bleiben im Pott.
- Geberrecht rotiert im Uhrzeigersinn über die verbliebenen Spieler; „links vom Geber" meint den nächsten aktiven Spieler.
- Bei Partie-Ende verfallen nicht gewonnene Mulden ersatzlos - das ist die klassische Regel (Pagat wörtlich: „Any unclaimed chips on the board remain there and are not won by anybody"; nur die Geldspiel-Variante teilt sie auf).
- **Hausregel-Toggle „Jackpot-Finale" (v1, Default AUS; umbenannt in Runde 9 - „Dramatisches Finale" klang zu actionlastig):** Zu Beginn der letzten Runde wandern alle Restmulden in die Mitte - unhistorisch, aber inszenierungsstark (Review-Runde-7-Idee). Nur in Modi mit Rundenlimit anwendbar (im klassischen Modus ist die letzte Runde nicht vorhersehbar). **Status (7.7.): geplant, noch NICHT gebaut/getestet** - es gibt keinen `Match.Mode`-Toggle im Code; gehört zu post-Gate-A. (Gate A = das eingefrorene Kern-Regelwerk, nicht die optionalen Toggles - Ähnliches gilt für die Hausregeln „Sequenz-Variante" und „Pochen ohne Paar": spezifiziert, aber noch nicht implementiert.)
- Wertungsgleichstand: Tie-Break über die Anzahl gewonnener Ausspiel-Phasen; danach geteilter Sieg.
- Melde-Reihenfolge (aus Review-Runde 5): nicht simultan, sondern der Reihe nach ab links vom Geber - jede Meldung wird einzeln aufgedeckt und ausgezahlt (passt zur inszenierten Melde-Dramaturgie aus Runde 4).
- Cap-Berechnung zählt nur bietberechtigte aktive Spieler (mit Paar und Stack+Gesetztes > 0): Ein 0-Chip-Spieler oder Spieler ohne Paar kann nie bieten und wird vom Cap nicht geschützt - sonst würde er jedes Bieten auf 0 deckeln. Wer zum Mitgehen exakt seinen ganzen Stack brauchte, deckelt weitere Erhöhungen auf das aktuelle Gebot. Passen ist auch vor der Eröffnung endgültig (kein „Checken"). (Implementierungs-Präzisierung 5.7., Phase-1-Block 2.)

**Partie-Ende & Wertung**
- v1-Modi: „Schnelle Partie" (festes Chip-Budget + Rundenlimit, Zieldauer 15-20 Min) und „Bis zum letzten Chip" (klassisch). Per Monte-Carlo kalibriert (5.7., `tasks/economy-kalibrierung.md`): **Schnelle Partie = Startstack 60, Rundenlimit 12** (simuliert p50 ~16 Min mit vorsichtiger Baseline); Nachkalibrierung mit echten Bot-Profilen in Phase 4 (nur Parameter, nie Regeln - erlaubte Ausnahme vom Gate-A-Freeze). Klassischer Modus terminiert in 2400 Simulationen ausnahmslos natürlich.
- Kein Echtgeld, keine Chip-Käufe, Chips nicht übertrag- oder auszahlbar (Abgrenzung zu Glücksspiel, siehe Risiko 1).

## 4. Umfang v1 / Nicht-Ziele

**v1 = volle Ausbaustufe (Tobsi, 5.7.: „außer Multiplayer alles gleich zur Veröffentlichung maximal ausbauen"):**
Bots-Einzelspieler mit **freien Tischgrößen 3-6** (dafür 5 Bot-Charaktere), Tutorial, **alle 3 Themes fest** (Wirtshaus 1441, Salon J, Theme 3 nach Fokus-Entscheidung), alle 7 Sprachen, 2 Partie-Modi, **Hausregel-Toggles** (Sequenz-Variante mit dokumentierter Tie-Break-Kaskade, „Pochen ohne Paar", weitere aus Abschnitt 3), **Pass-and-Play**, **Game Center** (Achievements; Leaderboard mit sinnvoller Metrik, nicht kumulierte Chip-Bilanz), **Detail-Statistiken**, Save/Resume.
**Explizit nicht v1 (einzige Ausnahme):** Online-Multiplayer (v2 - Tobsi-Entscheidung, zweifach bestätigt 5.7.; Nischen-Liquidität, Markttest zuerst, zweiter Marketing-Beat). Android bleibt ebenfalls außen vor (Plattform, keine Ausbaustufe).

Begründung Online-Verschiebung: Nischen-Liquiditätsproblem (leere Lobbys → 1-Sterne-Reviews), Markttest vor Server-Investition, Q4-Launchfenster, Multiplayer als zweiter Marketing-Beat für v2.

## 5. Architektur

```
PochKit (Swift Package, UI-frei, unit-getestet)
├── Rules: Regelwerk als reine Funktionen (legale Züge, Kombinationsbewertung)
├── GameState: immutable State + Reducer (Aktion → neuer State + Events)
├── Deterministik: seeded RNG (SplitMix64 o.ä.), komplette Partie aus Seed + Aktionsliste reproduzierbar
└── BotKit: Bot-Entscheider gegen dieselbe State-API wie menschliche Eingaben

PochApp (iOS)
├── TableScene (SpriteKit): Brett, Karten, Chips, Animationen, Partikel
├── HUD/Menüs (SwiftUI über SpriteKit): Mulden-Stände, Phasen-Banner, Einsatz-UI, Log
├── ThemeKit: 3 Themes als austauschbare Asset-Kataloge + Paletten + Musik-Sets
└── Services: Persistenz (Statistiken, Fortschritt), GameCenter, IAP (ein Unlock), Analytics (privacy-first, opt-in)
```

Entscheidende Eigenschaften:
- **Event-getrieben:** Engine emittiert Events (`ChipsWonFromPool`, `CardPlayed`, `PochRaised`, …), UI konsumiert sie. In v1 wird bewusst keine Netzwerk-Infrastruktur vorgebaut (YAGNI, Review-Finding) - die Online-Fähigkeit für v2 entsteht allein aus Determinismus + Event-Log, nicht aus vorgebauten Abstraktionen.
- **Deterministisch + seeded:** Tutorial nutzt präparierte Seeds/Hände; Bugs sind als Seed + Aktionsliste reproduzierbar; Server kann v2 autoritativ nachrechnen.
- **Bots laufen gegen die öffentliche API** - kein Zugriff auf verdeckte Karten (Anti-Cheat by Design, faires Spielgefühl).

## 6. Bots & Charaktere

**Archetyp-System (Tobsi, 5.7.):** 5 konstante Verhaltens-Archetypen (Engine-Profile: Solide, Geduldig-tight, Unberechenbar, Mathematisch, Aggressiv - Gate-A-neutral, es bleibt bei 5 Bot-Profilen) mit eigener Besetzung pro Welt. Die Bluff-Lesbarkeit wandert mit dem Archetyp durch die Welten.

**🍺 Wirtshaus 1441 (Tobsi, 5.7., festgelegt):**
- **Der Wirt** (Solide, Tutorial-Partner) - der Fels in der Brandung: berechenbar, blufft fast nie, kommentiert trocken.
- **Die Wirtin** (Geduldig-tight) - die Beobachterin: hält die Chips zusammen, schlägt nur mit bombensicherem Kunststück zu.
- **Der Knecht / Handwerker** (Unberechenbar) - der emotionale Gelegenheitsspieler: feuchte Hände nach harter Arbeit, zuckt bei guten Karten, extrem leicht zu lesen.
- **Der Dorfschulze / Beamte** (Mathematisch) - der Korrekte: zählt jede Karte mit, foldet diszipliniert, beschwert sich über ungleiche Handgrößen wie 8/8/8/7.
- **Die Kräuterfrau / Markt-Eusebia** (Aggressiv) - die Mutige: redet viel, psychologischer Druck, treibt Poch-Einsätze mit frechem Grinsen hoch.

**🤵 Salon-/Casino-Welt (Tobsi, 5.7., festgelegt; Store-Wording bleibt „Salon" - Casino-Vokabular im Store würde die Glücksspiel-Einstufung unnötig füttern):**
- **Der Pit Boss / Stammspieler** (Solide) - liest das Deck wie kein anderer, lässt sich nicht bluffen.
- **Die Grande Dame** (Geduldig-tight) - sehr wohlhabend, wartet auf den einen großen Stack.
- **Der Krypto-Neureiche** (Unberechenbar) - wirft mit Einsätzen um sich, wird nervös, wenn sein Bluff gecallt wird.
- **Der Student** (Mathematisch) - Card-Counter, foldet ohne Wimpernzucken.
- **Die Zockerin** (Aggressiv) - High-Roller, Dauerdruck, liebt das psychologische Showdown-Duell.

**🌙 Mitternacht-Welt (Tobsi, 5.7., festgelegt - „Late-Night-Runde"):**
- **Der Barkeeper** (Solide) - ruhig, professionell, hat alles schon gesehen, trockene Einzeiler.
- **Die Pro-Gamerin** (Geduldig-tight) - eiskalt, liest alle am Tisch, wartet auf den perfekten Moment.
- **Der Influencer** (Unberechenbar) - spielt für ein imaginäres Publikum, theatralisch, lesbar wenn man den Act durchschaut.
- **Die Quant-Analystin** (Mathematisch) - murmelt Wahrscheinlichkeiten, foldet gnadenlos, moderne Schwester des Dorfschulze-8/8/8/7-Spruchs.
- **Der Hustler** (Aggressiv) - schnelles Mundwerk, jagt die Mitte über schnelle Kettenabrisse.

Tischbesetzung: Bei 6 Spielern sitzen alle 5 Archetypen der aktiven Welt am Tisch; bei 3-5 Spielern wählt Tobsi die Gegner im Partie-Setup (Zufalls-Auswahl als Default, manuell änderbar). Produktions-Staffelung der Porträts: Wirtshaus → Salon → dritte Welt.

Technik: Heuristik + parametrisierte Zufallsprofile (Bluff-Frequenz, Risikotoleranz, Erhöhungskurve), Phase-3-Spielzug via einfacher Suche (welche Karte startet die längste eigene Kette). Kein ML nötig. Schwierigkeitsgrade über Profil-Schärfe, nicht über Karteneinsicht (Bots cheaten nie - kommunizieren wir auch so).

**Bot-Kernanforderungen (Review-Runden 8+9):** (0) Bei aktivem „Pochen ohne Paar"-Toggle ändern sich die Poch-Wahrscheinlichkeiten grundlegend - Bot-Profile lesen den Toggle-Zustand und passen Bluff-/Call-Schwellen an; (1) *Ante-Awareness* - unter ~20 Chips konservativ bieten, die 9 Antes der Folgerunde sind heilig (sonst Ausscheiden); (2) *Cap-Fenster nutzen* - steigt der Cap durch ein Passen, erhöhen starke Blätter den Druck; (3) *Mitzählen in Phase 3* (nur schwere Profile) - gespielte Karten und die offene Trumpfkarte tracken, um Ketten-Risse und das Anspielrecht vorherzusehen.

**Welten-Konsistenz (ersetzt die frühere „gleiche Figur, anderes Outfit"-Regel; Tobsi 5.7.):** Jede Welt hat ihre EIGENE Besetzung (siehe oben). Konstant bleibt der Archetyp: dieselbe Tells-STRUKTUR (z.B. „Unberechenbar zuckt bei guten Karten"), dieselbe Verhaltenslogik, dieselbe Sitz-Rolle - so bleibt gelernte Bluff-Lesbarkeit zwischen den Welten übertragbar, obwohl die Figuren wechseln.

## 7. UI & HUD

- **Mulden-Stände** direkt auf dem Brett (Chip-Stapel + Zahl), Jackpot-Wachstum über Runden prominent inszeniert.
- **Phasen-Banner** (Melden → Pochen → Ausspielen) mit kurzer Kontexthilfe, jederzeit antippbar.
- **Trumpf-Indikator** permanent sichtbar (Farbe + offene Karte).
- **Einsatz-UI** in der Poch-Phase: Chip-Slider/Stepper, Mitgehen/Erhöhen/Passen als große Buttons, aktueller Pott + wer noch drin ist. Slider-/Stepper-Grenzen kommen live aus der Engine: Der Erhöhungs-Cap kann mitten in der Setzrunde steigen (wenn der kleinste aktive Stack passt) - der Reducer bildet das exakt ab, die UI rechnet nie eigene Grenzen.
- **Hand-Assist (optional, abschaltbar):** markiert meldbare Karten in Phase 1 und die eigene beste Kombination in Phase 2 - Standard an für neue Spieler, Achievements für Spielen ohne Assist.
- **Spielverlauf-Log** (ausklappbar): wer hat was gemeldet/gepocht/gelegt, mit visuellen Markern (z.B. Pfeile/Farbcodes bei Erhöhungen) - wichtig für Lernkurve und Bluff-Nachvollzug auch für Einsteiger.
- **Aktions-Badges über den Gegnern** (Review-Runde 7): „Pocht 3" / „Geht mit" / „Passt" als kurzlebige Sprechblasen - der Bietverlauf ist ohne Log-Blick lesbar.
- **Cap nie erklären** (Review-Runde 7): Nicht mögliche Gebote sind schlicht geklemmt/ausgegraut (Kurz-Tooltip „Nicht möglich"). Steigt der Cap durch ein Passen, animieren die Stepper-Grenzen mit Mini-Toast („Limit gestiegen - Wirt hat gepasst").
- **Geber-Hinweis:** Beim Austeilen einmalig „Traditionelles Geben: Wer näher links vom Geber sitzt, bekommt bei ungleicher Teilung eine Karte mehr" (Runde-9-Korrektur - „Geber eine weniger" stimmt nur beim Vierertisch). Der Geber-Marker (D-Button) ist am Tisch immer präsent sichtbar.
- **Hand-Fächer skaliert 5-11 Karten** (3er- bis 6er-Tisch): Kartenbreite und Überlappung passen sich an, Mindest-Tap-Fläche bleibt gewahrt (Review-Runde 9).
- **Instant-Skip:** Kann niemand am Tisch bieten (kein Paar), wird die Poch-Phase automatisch übersprungen statt reihum Pass-Klicks zu erzwingen.
- **Eliminierungs-UX:** Scheidet Tobsi vor Partie-Ende aus, sofortige Wahl: „Im Zeitraffer zusehen" oder „Partie beenden" - nie minutenlanges erzwungenes Zuschauen.
- **Geschenktes Anspielrecht sichtbar machen** (Review-Runde 8): Passen alle in der Poch-Phase, bekommt der Spieler links vom Geber das Anspielrecht klar signalisiert („Alle gepasst - du spielst an") statt eines wortlosen Phasensprungs.
- **„Hand leer!"-Moment:** Das plötzliche Rundenende (auch mitten in der Kette) bekommt ein deutliches Highlight + Restkarten-Abrechnungs-Animation, damit es nie wie ein Glitch wirkt.
- **Einstellungen früh bauen (ab Phase 3):** Audio/Haptik/Assist/Sprache/Theme an einem Ort. Dazu ein **Entwicklermenü ausschließlich in DEBUG-Builds** (`#if DEBUG`, nie im Release-Binary): Review-Seed-Loader (garantiert Melde-Treffer, Drilling und perfekte Kette in drei aufeinanderfolgenden Runden), Pro/Free-Test-Toggle, Seed-Anzeige. Bewusst NICHT als versteckter Schalter im Release: Guideline 2.3.1 verbietet versteckte Features, und ein Pro-Toggle im Shipping-Build wäre zusätzlich ein Unlock-Bypass. Für das echte App-Review verweisen die Review-Notes aufs Tutorial als garantierten Alle-Phasen-Pfad (geskriptete Seeds = derselbe Effekt, regelkonform).
- Barrierefreiheit: Dynamic Type in Menüs, Farbenblind-sichere Farbsymbole (Form + Farbe), VoiceOver für Menüs (Spieltisch: Best Effort v1.x).

## 7a. Game-Feel-Dramaturgie (Review-Runde 4, komplett übernommen - Tobsi 5.7.)

Leitsatz: Die Regeln erzeugen Geschichten - die Inszenierung muss sie erzählen. Kein Element ändert Regeln oder Economy. **Identitäts-Leitplanke (Tobsi, 5.7.): eigenes Wesen, keine Balatro-Kopie** - Balatro ist nur interne Feel-Qualitäts-Messlatte; die fünf Identitäts-Säulen stehen bindend in der Projekt-CLAUDE.md §0. Juice-Prüffrage: „Wirtshaus oder Arcade-Neon?" - im Zweifel Wirtshaus. Alle Timings unterliegen dem Parameter-Lock (Projekt-CLAUDE.md §4).

1. **Ante als eine Bewegung** (Phase 3): alle 9 Einsätze in einer rhythmischen Tischgeste statt 36 Einzeltransfers; nur Mulden, die eine Schwelle erreichen, bekommen einen Mikro-Moment (anderer Klang, Stapel-Wackler, Bot-Blick zur Mulde).
2. **Melden als Aufdeck-Dramaturgie** (Phase 3): reihum (Regelwerk-Pin aus Runde 5), wertvollste offene Mulde zuerst inszeniert; bei Mariage/Sequenz kurze Pause zwischen den Karten; Bots reagieren sichtbar - die Information ist fürs Pochen relevant.
3. **Einsatz-Gesten mit lesbarer Absicht** (Phase 3/6): Mitgehen ruhig-geschlossen, kleine Erhöhung provozierend vorgeschoben, große Erhöhung = Poch-Schlag (Nr. 10), Zögern als charaktergebundener Tell, Passen = Karten körperlich zurückziehen.
4. **Kettenbruch-Spotlight + Endspiel-Verdichtung** (Phase 3/6): erzwungene Ketten-Karten schnell und rhythmisch; beim Bruch abbremsen - Lücke kurz sichtbar, Blick zur offenen Trumpfkarte, Spotlight auf den Neueröffner. Bei „nur noch eine Karte": Ambience dünner, Bots zählen sichtbar Restkarten. **Der Stopp-Grund wird immer visualisiert** (Badge: „Ass erreicht" / „Trumpfkarte!" / „Schon gespielt") - sonst wirkt die Kette unfair (Review-Runde 7). Tobsis eigene Zwangszüge leuchten ~0,8s auf, bevor sie automatisch fliegen (Parameter-Lock).
5. **„Letzte Runde"** (Phase 6): Steht fest, dass die nächste Ante-Runde nicht mehr möglich ist (bzw. vor der letzten Runde im Schnellmodus), stellt der Wirt eine Kerze in die Tischmitte; offene Mulden werden nacheinander beleuchtet; Zwischenstand als Ansage („Du führst mit 7. Der Händler braucht die Mitte."); Final-Musikvariation. Keine Regeländerung.
6. **„Abend im Rückblick"** (Phase 4/6): nach der Partie drei kuratierte Momente (Wendepunkt, Bluff, letzte Karte) als 3-5s-Rekonstruktionen mit je einem Satz - erst danach Endstand + Rematch. Basis: PochKit-Event-Log (Replay by Design). Teilbare, spoilerfreie Karten: v1.x.
7. **Gegner-Erinnerungen + Revanche** (Phase 4): genau ein Bot hinterlässt eine aus einem konkreten Match-Event erzeugte Reaktion; beim nächsten Start freiwillige „Revanche am selben Tisch". Kein Timer, keine Belohnung, kein Ablaufdatum.
8. **Wirtshausbuch** (Phase 4/5): illustrierte Einmal-Einträge für echte Erlebnisse („Großen Pott ohne Aufdecken gewonnen") mit Datum + beteiligtem Gegner. Keine Zähler, keine Prozentbalken, keine Daily-Mechanik.
9. **Kuratierte nächste Partie** (Phase 4): genau eine begründete Alternative zu „Noch einmal", abgeleitet aus der gespielten Partie; dauerhaft verfügbar, ignorierbar.
10. **Signature Moment „Der Poch"** (Phase 6, Parameter-Lock): nur bei großen Erhöhungen (Richtwert: Pott + Poch-Mulde >= 20-25% eines aktiven Stacks - sonst nutzt er sich ab). Chips vorschieben + zweimal klopfen → Sound bricht ab, Chips springen beim ersten Klopfen, Kerzen zittern beim zweiten, jeder Bot reagiert gleichzeitig aber typgerecht. Sieg ohne Aufdecken: Karten werden verdeckt eingezogen, ein Herzschlag Stille - das Geheimnis ist der Triumph.
11. **Sound-Identität pro Farbe/Aktion** (Phase 6, Gemini-Kernel aus Runde 4): geschichtete Klang-Signaturen je Farbe, Kombinationen verschmelzen zu harmonischen Phrasen.
12. **Tischgeplauder (Tobsi, 5.7.):** Charaktertypische Kommentare in besonderen Momenten (großer Poch, Bluff aufgeflogen, Jackpot geknackt, Mariage, letzte Karte, Revanche-Bezug aus den Gegner-Erinnerungen). **Eiserne Schutzregeln, damit es dem Balatro-Tempo nie widerspricht:** (a) nie blockierend - flüchtige Sprechblasen parallel zum Spielfluss, kein Modal, kein Warten, verlängern keine Animation; (b) Frequenz-Budget: selten, max. ~1 Spruch pro Phase, Cooldown pro Charakter; (c) Sprüche sind Teil des Tell-Systems - was ein Charakter sagt (oder gerade nicht sagt: der wortkarge Wirt), trägt lesbare Information; (d) Anti-Repetition: großer Pool pro Charakter/Situation, No-Repeat-Fenster; (e) in den Einstellungen abschaltbar („Tischgespräche"); (f) Lokalisierungs-Kostenbewusstsein: v1 nur Kern-Situationen (Transcreation in 7 Sprachen ist teuer), erweiterbar per Update. Content Phase 4 (mit den Profilen), Timing-Feinschliff Phase 6 (Parameter-Lock).
13. **Phasen-Identität - drei Akte** (Review-Runde 7): Jede Phase hat ihre eigene audiovisuelle Identität. Melden = Gold, Glitzern, fliegende Münzen; Pochen = dunkler, Spannung, Herzschlag; Ausspielen = Brett leuchtet, Tempo zieht an. Zahlt direkt in die Licht-Layer (Abschnitt 9) und die Musik-Sets pro Phase ein.

## 7b. Eye-Candy-Maximalprogramm (Tobsi-Mandat 5.7. abends, extern beratschlagt)

Quellen: gpt-review (Codex/ChatGPT) + gemini-review (Gemini 2.5), 5.7.2026, identisches Briefing; 12+12 Vorschläge, hier dedupliziert und auf unsere Regeln gemappt (Lesbarkeits-Licht-Regel und Wirtshaus-statt-Arcade gelten unverändert). Tobsi: „Maximalprogramm fahren." Beide Räte überlappen stark - die Schnittmenge ist die Priorität.

1. **Kartengefühl-Paket** (Phase 3 Basis, Feinschliff 6): Federphysik, minimale Biegung, unperfektes Aufliegen, Masse beim Ziehen/Geben/Ablegen; weiche Kontaktschatten unter Karten und Chips (beide Räte: das trägt Premium allein).
2. **Licht-Paket** (Phase 6): volumetrische Kerzenkegel + Staubpartikel AM RAND (nie auf der Spielfläche - Licht-Regel), Kontaktlicht auf bewegten Objekten, Funken am Docht, Holzstaub beim Poch-Schlag.
3. **Material-Paket** (Phase 2/6): streifender Messing-Glanz (Shader), speckiges Holz, Kartenfirnis, abgenutzte Kanten - Oberflächen klar unterscheidbar („berührbare Handarbeit").
4. **Spuren des Abends** (Phase 6, GPT-Unikat, passt zu Säule „Ort & Wärme"): der Tisch sammelt während einer Partie persistente Mikro-Spuren (Wachstropfen, Münzabdruck, verrutschter Stapel) - der Abend erzählt sich sichtbar.
5. **Leben im Hintergrund** (Phase 6): Idle-Mikroanimationen (Flammen-Atmen, Wandschatten, Mulden-Nachschwingen, Bot-Mikrogesten) - die Szene bleibt wach, auch wenn Tobsi nichts tut.
6. **Diegetische Übergänge** (Phase 3/6): Szenenwechsel als Wirtshaus-Choreografie (Licht blendet, Ärmel zieht vorbei, Kerze verlischt) - nie App-Screen-Schnitte.
7. **Typografie-Paket** (Phase 3): eigene Display-Schrift + sorgfältige Ziffern (lizenzfrei, historisch anmutend, perfekt lesbar), Initialen/Ligaturen für Überschriften; Zahlen im Spiel sind Craft, keine Systemschrift-Restposten.
8. **AV-Kopplung samplegenau** (Phase 6, verschärft 7a.11): Aufprall-Frame, Klang, Lichtimpuls und Haptik aus EINER Event-Timeline - Synchronität macht Gewicht.
9. **Diegetische Menüs** (Phase 3/5): Einstellungen/Statistiken als aufklappbares Kontorbuch mit Messingschließe und Registerreitern; Schalter als kleine Holz-/Messingmechanik. Lesbarkeit vor Deko.
10. **Onboarding als gespielte Szene** (Phase 5, deckt sich mit §8): erste Runde als inszenierte Wirtshausrunde mit Blickführung durch den Wirt statt Texttafeln.
11. **Splash/Intro** (Phase 3, Tobsi-Direktive): stimmungsvolles Key-Visual (LoRA, ohne generierte Schrift), Titel als Vektor-Typografie, sanfte Licht-/Parallax-Bewegung - der erste Screen ist bereits Wirtshaus.
12. **Icon- & Store-Key-Art-System** (Phase 9): App-Icon als ikonisches Einzelmotiv, konsistente Key-Art-Familie, echte UI-Captures, kurzer Impact-Trailer; saisonale Icon-Varianten v1.x.

Umsetzungsregel: Jedes Paket läuft durch den normalen QA-Loop (gemini-vision hart, dann Tobsi-Charge); Timings unter Parameter-Lock; nichts davon ändert Regeln oder Economy.

## 8. Tutorial

Geskriptete erste Partie mit präparierten Seeds, gegen den Wirt + 1 weiteren Bot:
1. **Runde 1:** nur Melden erklärt (Hand enthält garantiert Trumpf-Honors + Mariage).
2. **Runde 2:** Pochen erklärt (Hand enthält Drilling; Bot blufft sichtbar und wird entlarvt - Kernlektion: Bluffen gehört dazu).
3. **Runde 3:** Ausspielen erklärt (Ketten-Mechanik mit vorbereiteter Stopp-Situation).
4. Danach freie Partie mit aktivem Hand-Assist + kontextuellen Erst-Hinweisen (je Situation einmalig).
Skip jederzeit möglich; Tutorial aus dem Menü wiederholbar; alle Texte lokalisiert. Der „Eine Runde in 30 Sekunden"-Block aus dem Regelwerk dient als geskriptetes interaktives Intro beim allerersten Start (Runde-9-Idee: 6 Schritte durchklicken statt Textwüste).

## 9. Art Direction & Themes

**Art Direction → `tasks/konzept.md` (kanonisch).** Kurz: clean-modern-premium, dunkel (warmes Tinten-Schwarz), Farbe=Label in Juwelen-Tönen (nie Neon), Poch-Ring als Signatur, **Material > Glow**. Kein Holztisch, kein Mittelalter, kein Casino. Die warmen painterly Charaktere sind das *eine* warme Material im cleanen Rahmen (Kontrast = Eigenständigkeit). Verbote: kein Kitsch, nichts Verwaschenes, kein Zock-Marketing.

**Theme-System (kanonisch, `konzept.md`):** 2 Themes mit gleicher Geometrie - **Premium-matt** + **Vivid-Electronic** (dieselben Juwelen-Töne, matt vs. strahlend), der Held wird live gewählt. *Die drei Themes unten (Wirtshaus / Salon / Mitternacht) sind historisch und durch den Kanon ersetzt - hier nur als Archiv-Notiz.*

1. **„Wirtshaus 1441" (Default):** handgemalte, warme Storybook-Ästhetik (Aquarell-Wärme, kein glattes 3D). Holztisch, Kerzenlicht, Pergament, Straßburg-Flavor. **Stil-DNA aus 3 Kandidaten-Runden + 4 externen Reviews (5.7.): Komposition wie Kandidat X** (8 Schalen im Ring + größere 9. Mulde als Pott, Kerze außerhalb, klare Hierarchie), **auf echtes Top-down flachgezogen** (Schräg-Perspektive killt Tap-Targets - Review-4-Punkt, deckt sich mit der Code-Schablone), **Malweise Richtung Kandidat U** (gemalt statt 3D-Render). Polish-Vorgaben aus Review 3: Mittelmulde ~10-15% kleiner, Muldenverbindungen als Gravuren statt dunkler Risse, Holz dunkler/geölter für Münzkontrast. **Rustikal-Auflage (Tobsi, 5.7., bindend): nicht zu clean** - Gebrauchsspuren, raue/imperfekte Texturen, gedecktes Kerzenlicht statt Hochglanz. **Periodengerecht 1441:** Kleidung (Leinen/Wolle/Lederschürze, keine modernen Hemdkragen), Gefäße (Holz/Steinzeug, nie modernes Glas), Bier = trübes Ale mit bescheidenem Schaum (kein Sahnehaufen). Jedes LoRA-Referenz-Set wird VOR dem Training von Tobsi gesichtet (Prozess-Regel nach dem abgebrochenen Erst-Training). **Anti-Slop-Auflagen (Tobsi, 5.7.): nichts Verwaschenes; NIEMALS Schrift/Zahlen im Artwork generieren** (KI-Schrift ist fast immer Slop) - jede Beschriftung inkl. „1441"-Relief kommt als Vektor-Overlay bzw. menschliches Compositing; gemini-vision-QA prüft explizit auf Verwaschenheit und Slop-Schriften.
2. **„Salon":** modern-clean, ruhig, premium (Apple-Design-Award-Ästhetik). **Stil-Referenz gepinnt (Tobsi, 5.7.): Kandidat J** - tiefblauer Samt-/Filzbezug mit gebürstetem Gold, glasartige Chips, „schön pokerartig"; Seed 2444, Provenance `stil-kandidaten-salon-2026-07-05.json`.
3. **„Mitternacht" (Tobsi, 5.7., festgelegt):** Die lebendige dritte Welt - **Echtzeit-Fluid-Shader-Hintergrund** (tiefblau wabernd, SKShader - kein Asset, ein Effekt), flaches maximal lesbares Oktagon-Brett, die 9 Mulden als leuchtende Ringe, **Bernstein/Gold-Glow** als Marken-Akzent (Brücke zu Kerzengold/Salon-Gold). Bewusst KEINE Balatro-Kopie: kein Pixel-Look, keine Joker-Motive, kein CRT-Filter (Identitäts-Leitplanke §0 + Trade-Dress-Vorsicht). Karten flach, Chips mit Glüh-Puls. Technisch das günstigste Theme (Shader + Vektor-nahes Brett statt gemalter Assets).

**Asset-Pipeline (Replicate):**
- **Layout zuerst, Kunst danach:** Brett-Geometrie (9 Mulden, Touch-Targets, Chip-Anker) steht im Code; Artwork wird auf diese Schablone generiert/komponiert.
- **Ebenen statt Flachbild:** Tisch / Brettkörper / Mulden-Dekor / Lichtstimmung als getrennte Layer → dynamisches Kerzenflackern, echte Chip-Schatten, Theme-Tausch pro Layer. **Lesbarkeits-Licht-Regel (Tobsi, 5.7.):** In Artwork-Ebenen werden keine deckenden Schlagschatten eingebacken - Licht ist ausschließlich der kontrollierbare Overlay-Layer; die Spielfläche bleibt immer gleichmäßig lesbar.
- Kartendeck: 32 Karten + Rückseite pro Theme; Konsistenz über Stil-Referenzbilder + einheitliche Prompt-Vorlagen; Zahlen/Indizes als Vektor-Overlay im Code (Lesbarkeit garantiert, Artwork darunter).
- Charakterporträts: 4 Charaktere × Grundpose + 2-3 Emotions-Varianten (neutral/freut sich/ärgert sich) für Tells - **pro Theme** (theme-adaptives Äußeres, Abschnitt 6). Pipeline-Konsequenz: je Figur ein Character-Sheet als Identitäts-Anker (Gesicht/Silhouette müssen über Themes und Emotionen stabil bleiben); der Phase-2-Konsistenztest umfasst deshalb neben den 5 Karten auch eine Charakter-Identitätsprobe über 2 Themes hinweg.
- Mikro-Animationen (SpriteKit-Partikel, kein Asset-Zwang): Kerzenflackern, Staub im Licht, Münzglanz, Krug-Dampf.
- **QA-Loop:** pro Asset mehrere Kandidaten → gemini-vision-Review → Auswahl-HTML an Tobsi → Tobsi entscheidet. Kein Asset geht ohne diesen Loop ins Spiel.
- **Rechtliches ist Phase-2-Eingangskriterium, kein Submission-Thema** (Review-Finding): Bildmodell wird VOR dem ersten Produktions-Asset festgelegt und die Lizenz als PDF mit Datum archiviert. Pro finalem Asset in `assets/provenance.md`: Modellname + Version/Hash, Lizenz-URL/-fassung, Datum, Seed, Prompt, Referenzbilder (nur eigene/lizenzierte), Ähnlichkeitsprüfung gegen bekannte Spiele/Künstler, dokumentierte menschliche Bearbeitungsschritte + editierbare Quelldatei. Gilt getrennt für Bilder, Musik, Fonts, SFX. Hintergrund: rein KI-generierte Assets sind ggf. schwach schutzfähig - substanzielle menschliche Kompositions-/Retusche-Arbeit ist auch deshalb Teil der Pipeline, nicht nur Qualitätskosmetik.

**Audio:** Musik pro Theme (2-3 Loops), entschieden (Tobsi, 5.7.): **nur Replicate-generiert, kein Stock-Fallback.** Der vollständige Lizenznachweis (kommerzielle App-Nutzung, Trailer, Social-Clips, Bearbeitung/Loops, GEMA-frei) ist damit harter Release-Blocker: Ist er für ein Musikmodell nicht zu erbringen, wird ein anderes Modell gewählt - nicht auf Stock ausgewichen. Musikmodell-Wahl + Lizenzarchiv daher früh, zusammen mit dem Bildmodell als Phase-2-Eingangskriterium. **Loop-QA:** Audio-Modelle liefern selten mathematisch knackfreie Loops - die Pipeline enthält ein Schnitt-Tool (Python/librosa), das Nulldurchgänge und harmonisch passende Loop-Punkte findet; knackfreier Loop ist Abnahmekriterium jedes Musik-Assets. SFX-Set (Karten, Chips, Holz, Stimmen-Gemurmel als Ambience). Haptik (Core Haptics) für Chips kassieren, Poch-Erhöhung, Partie-Gewinn.

## 10. Lokalisierung

- Produktumfang: DE, EN, FR, IT, ES, NL, PL. String Catalogs ab erstem Commit, keine hartcodierten Strings. Launch-Gate entschieden (Tobsi, 5.7.): **alle 7 Sprachen zum Launch** - Übersetzungs-QA ist damit fester Bestandteil von Phase 5, kein Nice-to-have; tragbar, weil das Launch-Datum bewusst offen bleibt (Abschnitt 14).
- FR/EN erzählen die eigene Story mit (Straßburg → Poque → Poker), nicht nur Übersetzung.
- Regelwerk-/Tutorial-Texte: maschinelle Erstübersetzung + Review-Pass (LLM-Cross-Check + Stichprobe Muttersprachler, mind. für DE/EN/FR).
- Store-Metadaten pro Sprache (Abschnitt 13).

## 11. Monetarisierung

- **Free Download + Einmal-Unlock (4,99 €, Non-Consumable):** Tutorial + „Schnelle Partie" frei; Unlock öffnet alle Modi, alle Charaktere/Bot-Profile, weitere Themes (sobald verfügbar) und Statistik-Details. Restore-Purchases-Flow ist Pflicht (Guideline 3.1.1), Review-Notes erklären Chips (kein Echtgeld) und Unlock-Inhalt explizit.
- Keine Ads, kein Abo, keine kaufbaren Chips (Abgrenzung zu Glücksspiel - Chips sind reine Spielpunkte, nicht kauf- oder auszahlbar).

## 12. Risiken

1. **Alterseinstufung „Simuliertes Glücksspiel" (Top-Risiko, aus externem Review):** Chip-Setzen ist Kernmechanik jeder Partie → im Apple-Fragebogen ehrlich „häufig", was nach aktuellem Rating-System sehr wahrscheinlich in die höchste Alterskategorie fällt (je nach Region **17+/18+**; Apple generiert das Rating aus dem Fragebogen, regionale Sonderratings kommen obendrauf). Das kollidiert frontal mit einer Familien-/Weihnachtspositionierung. Guideline 5.3 (Echtgeld-Gambling) ist dagegen unkritisch, solange Chips weder kauf-, übertrag- noch auszahlbar sind. Mitigation: Rating-Fragebogen vor Produktionsfreigabe testweise real durchspielen; Positionierung im Zweifel auf Tradition/Poker-Historie statt „Familienspiel" drehen; keine Casino-Store-Kategorie; Korea/China/Vietnam vorerst nicht freischalten (eigene Zulassungsregimes für simuliertes Glücksspiel). Entschieden (Tobsi, 5.7.): 18+ wird eingeplant, Positionierung Tradition/Poker-Historie für Erwachsene; der Familien-Angle ist nur ein Bonus, falls der reale Fragebogen milder ausfällt.
2. **Asset-Konsistenz (32 Karten × 3 Themes):** größtes Pipeline-Risiko. Mitigation: Stil-Referenz-Workflow früh validieren (Phase 2 beginnt mit 5-Karten-Konsistenztest, erst bei Bestehen Vollproduktion); Fallback: Themes 2+3 nach Launch nachliefern (Launch nur mit Wirtshaus 1441).
3. **Regelvarianten-Erwartung:** Spieler kennen Poch mit Hausregeln, App „spielt falsch"-Reviews möglich. Mitigation: Regelwerk-Quelle in der App transparent, Varianten-Toggles als kommunizierte Roadmap (v1.x).
4. **Niedriges Suchvolumen:** Marketing-Risiko Nr. 1, siehe Abschnitt 2/13. Erwartungsmanagement: Nischen-App mit Featuring-Lotterielos + Long-Tail, kein Volumen-Business.
5. **Zeitplan:** Entschieden (Tobsi, 5.7.): Kalenderdaten bleiben vorerst draußen - kein festes Launch-Datum. Die Gates in Abschnitt 14 gelten als Reihenfolge-Gates (Qualitätskriterien pro Phase), nicht als Termine. Ein Q4 bleibt das Wunschfenster fürs Marketing; ob 2026 oder später, entscheidet der Fortschritt, nicht der Kalender. Damit entfällt auch der Druck, Scope (7 Sprachen, Themes 2+3) gegen ein Datum verteidigen zu müssen.
6. **Namensrechte:** „Poch"-Markenlage (DPMAregister, EUIPO/TMview, App Store; auch verwechslungsfähige Marken in Spiele-/Softwareklassen) VOR Repo-/Domain-/Store-Festlegung recherchieren.
7. **Spaß-Validierung nach Design-Komplettierung (Tobsi-Entscheidung 5.7., gegen Review-Empfehlung):** Der externe Playtest läuft als Phase 7b mit vollem Design statt früh als Ugly-Prototyp - Tobsi will maximales Design vor dem ersten Fremdkontakt. Bewusst akzeptiertes Restrisiko: Asset-Arbeit vor externem Spaß-Beweis. Abgefedert durch: erprobte Pipeline (HOT TAKE belegt das Qualitätsniveau, Grenzkosten generierter Assets sind niedrig), kontinuierliche Tobsi-Playtests ab Phase 3, Bot-vs-Bot-Simulationsmetriken aus PochKit ab Phase 1. Messgrößen des Playtests unverändert.

## 13. Marketing

**→ Single Source ist `tasks/poch-marketing.md`** (Claims-Katalog mit Store/PR-Nutzungsmatrix, ASO, Featuring-Pitch, PR-Anker, Pre-Launch). Hier nur die Kurzfassung:

- **Apple Featuring** als größter Hebel: Pitch über App-Store-Promote-Formular, Story „500 Jahre altes Kulturgut, digital wiederbelebt", gezielt auf Feiertags-Slot.
- **ASO lokalisiert:** Poch-Keywords in 7 Sprachen komplett besetzen; Screenshots pro Sprache, Design via gemini-vision-Loop.
- **Story-PR:** DACH-Brettspielmedien/-YouTuber, Poker-Communities („so sah Poker vor 500 Jahren aus"), r/boardgames; Kultur-Anker (Spielkartenmuseum/Spielearchiv) für Pressestories.
- **Short-form:** 15-Sekunden-Juice-Clips (Jackpot kassieren, Bluff auffliegen lassen) für TikTok/Shorts/Reels - Game-Feel-Investition zahlt direkt aufs Marketing ein.
- **Timing:** Launch-Datum bewusst offen (Tobsi-Entscheidung 5.7.); ein Q4 bleibt das bevorzugte Fenster (Featuring-Pitch auf „zwischen den Jahren"), festgezurrt wird erst, wenn der Fortschritt es hergibt.
- **Pre-Launch statt Launch-Tag** (aus externem Review): Landing Page + TestFlight-Warteliste spätestens ab Phase 7b (Playtest-Rekrutierung = Wartelisten-Start), Build-in-Public-Schnipsel aus der Asset-Pipeline schon ab Phase 2 (Brett-Entstehung ist selbst Content); Presskit zum Launch.
- **Store-Hygiene:** keine Fremdmarken/-spielenamen in Metadaten (Carcassonne/Balatro sind interne Referenzen), Claims store-sicher („einer der historischen Vorläufer des Pokers"); Regeltexte eigenständig formulieren - Pagat/Wikipedia sind Regelquellen, keine Textvorlagen.
- Abhängigkeit: Familien-Weihnachts-Angle steht unter Vorbehalt der Alterseinstufung (Risiko 1) - Fallback-Positionierung: Tradition + Poker-Herkunft für Erwachsene.

## 14. Roadmap

| Phase | Inhalt | Exit-Kriterium |
|---|---|---|
| 0 | Projekt-Setup, Repo, CI (Build + Tests) | Build grün auf leerer App |
| 1 | PochKit: Regelwerk + State + Tests + Economy-Simulation | Headless-Partien in Masse simulierbar; benannte Invarianten + Property-Tests grün, inkl. aller Insolvenz-/Betting-Zustände (Beispiele: „nicht abgeholte Mulden wachsen monoton", „die offene Trumpfkarte gewinnt nie eine Mulde", „Chip-Summe bleibt über alle Transfers erhalten"); Economy per Monte-Carlo kalibriert (Partiedauer, Bankrottquote) |
| 2 | Asset-Pipeline-Validierung | 5-Karten-Konsistenztest + Brett „Wirtshaus 1441" vom Tobsi abgenommen |
| 3 | TableScene + HUD (Platzhalter-Assets erlaubt), Tischgrößen-Wahl 3-6 | Spielbare Partie Mensch vs. 2-5 Bots, alle Phasen, auf echtem Gerät |
| 4 | Bots mit Persönlichkeiten (5 Charaktere) | Tobsi-Playtests: Charaktere unterscheidbar, Tells erkennbar; Bot-vs-Bot-Simulationsmetriken plausibel |
| 5 | Tutorial + Lokalisierung | Tutorial in 7 Sprachen, Erstspieler-Test bestanden |
| 6 | Juice-Pass + Audio + Haptik | „Fühlt sich saftig an"-Abnahme, gemini-vision-Pass |
| 7 | Themes 2+3, Hausregel-Toggles, Pass-and-Play | Theme-Switch live; Toggles inkl. „Dramatisches Finale" getestet; Pass-and-Play mit Hand-Verdeckung spielbar |
| 7b | Design-kompletter Playtest extern (TestFlight, 10-20 Zielgruppen-Tester) - Tobsi-Entscheidung 5.7.: nach Design-Komplettierung statt als Ugly-Prototyp | Gemessen: Tutorial-Abschlussquote, Regelverständnis (Tester erklären die 3 Phasen korrekt), „Bots wirken lesbar", „Erhöhungs-Cap wird intuitiv verstanden", „Sieg ohne Aufdecken fühlt sich fair an", Partiedauer/Abbruchquote, Kaufbereitschaft 4,99 € - Zielwerte vor Testlauf festlegen (z.B. Bluff-Erkennungsrate >60%) |
| 8 | IAP + Restore, Game Center (Achievements + Leaderboard mit sinnvoller Metrik), Detail-Statistiken, Settings, Compliance-Paket | Kaufflow + Restore im Sandbox-Test grün; Compliance-Checkliste komplett: Privacy Policy (Store + in App), App-Privacy-Angaben, PrivacyInfo.xcprivacy, Rating-Fragebogen final, DSA-Trader-Angaben, Impressum + Support-URL, Review-Notes |
| 9 | TestFlight-Beta (mind. 4 Wochen), Store-Assets, Presskit | 20+ externe Tester, Crash-frei, Beta-Feedback triagiert |
| 10 | Launch (Fenster offen, bevorzugt ein Q4) | Live im Store + Featuring-Pitch raus |

**Reihenfolge-Gates** (aus externem Review; Kalenderdaten auf Tobsi-Entscheidung vom 5.7. bewusst rausgelassen):
- **Gate 0.5 (läuft parallel zu Phase 0/1, muss VOR Phase 2 stehen):** Naming geklärt (Ähnlichkeitsrecherche, nicht nur Exact-Match), Rating-Fragebogen trocken durchgespielt + Ergebnis dokumentiert (global + regional), Bild- und Musikmodell inkl. Lizenzarchiv entschieden. Ohne Gate 0.5 startet keine Asset-Produktion.
- **Gate A:** Regelwerk + Economy eingefroren (Phase 1 abgeschlossen) - danach keine Regeländerungen mehr (heilig)
- **Gate B:** Vertical Slice auf echtem Gerät (Phase 3)
- **Gate C:** Feature Freeze nach Phase 8 - danach nur Bugfix, Polish, Store-Vorbereitung
- **Gate D:** mindestens 4 Wochen externe Beta vor der ersten Review-Einreichung

**Implementation-Readiness-Checkliste:**
- Gate 0.5: [ ] Markenrecherche als Ähnlichkeitssuche (DPMA + EUIPO/TMview + App Store + offenes Web) [ ] Rating-Dry-Run dokumentiert [ ] Bild-/Musikmodell-Lizenzen archiviert
- Gate A ✅ BESTANDEN (5.7.2026): [x] Invarianten + Property-Tests grün (55 Tests) [x] Economy kalibriert [x] Phasen-Balance-Analyse + Replays (tasks/balance-report.md) [x] Regel-Freeze durch Tobsi erteilt
- Gate 7b: [ ] Zielwerte vor Testlauf fixiert [ ] alle Playtest-Metriken erhoben [ ] Go/No-Go für Beta + Launch-Vorbereitung dokumentiert

Sobald ein Launch-Fenster festgezurrt wird, werden die Gates terminiert; bis dahin entscheidet Qualität, nicht Kalender.

Nach jeder Phase: Commit + CHANGELOG, Verifikation nach globaler Checkliste. Replicate-API-Key wird ab Phase 2 benötigt (Tobsi stellt bereit).

## 15. Offene Punkte

**Tobsi-Entscheidungen - getroffen am 5.7.2026:**
1. **Sprach-Launch-Gate:** alle 7 Sprachen zum Launch (Übersetzungs-QA damit fester Bestandteil von Phase 5).
2. **Alterseinstufung/Positionierung:** 18+ wird eingeplant; Positionierung Tradition/Poker-Historie für Erwachsene, Familien-Angle nur als Bonus.
3. **Launch-Fenster:** Kalenderdaten bleiben vorerst draußen; Reihenfolge-Gates statt Termine, bevorzugtes Fenster bleibt ein Q4.
4. **Musik-Quelle:** nur Replicate-generiert, kein Stock-Fallback → Lizenznachweis ist harter Release-Blocker, Modellwahl früh in Phase 2.
5. **Name:** Poch 1441 (Repo: github.com/tobsiberlin/poch1441).
6. **GOTY-Paket (Runde 4):** komplett übernommen → Abschnitt 7a.
7. **Playtest-Timing:** nach Design-Komplettierung (Phase 7b statt 3b), Restrisiko in Risiko 7.
8. **Implementierungsfreigabe:** erteilt für Phase 0/1 (5.7.2026); Asset-Produktion erst nach Gate 0.5.
9. **Volle Ausbaustufe in v1 (5.7., zweifach bestätigt):** „außer Multiplayer alles gleich zur Veröffentlichung maximal ausbauen" - Tischgrößen 3-6, alle 3 Themes fest, Toggles, Pass-and-Play, Game Center, Detail-Statistiken in v1; nur Online bleibt v2.
10. **Salon-Stil:** Kandidat J. **Wirtshaus-Stil-DNA:** X-Komposition × U-Malweise (GO 5.7.). **Arcade verworfen**, Fokus-Kandidaten in Prüfung.
11. **GATE A (5.7.2026): Regelwerk eingefroren.** Bewegen dürfen sich nur noch Economy-Parameter und die spezifizierten Toggles.

**To-dos:**
- Markenrecherche „Poch 1441" als **Ähnlichkeitsrecherche** (DPMAregister leistet keine Ähnlichkeitssuche, das DPMA prüft im Anmeldeverfahren keine älteren Rechte - also DPMA + EUIPO/TMview + App Store + offenes Web) VOR Store-Festlegung; Domain-Kandidaten (poch1441.de/.app) prüfen. Erste DPMA-Sichtung (Tobsi, 5.7.): 5 Treffer, augenscheinlich Chemie/Industrie (POCH S.A., Gliwice) bzw. abgelaufen („epoch Baby") - Nizza-Klassen von EM 008834087 („pocH") noch gegen die Spiele-Klassen 9/28/41 verifizieren. Zweite Sichtung (Tobsi, 5.7.): IR 1473157 (Wortmarke, Ursprung CH, Inhaber Vionar Impact SA, Genf; EU-Schutz bewilligt) in Klassen 35 + 42 - Wortlaut im Screenshot nicht eindeutig lesbar, in der Gate-0.5-Recherche identifizieren; Klasse 42 (Software-Dienstleistungen) wäre die bisher nächstliegende Berührung, aber zu einer Spiele-App (Kl. 9/28/41) nur mittelbar ähnlich, Zeichenabstand zusätzlich durch „1441"
- Replicate-Key-Übergabe bei Phase-2-Start; Bildmodell-Festlegung + Lizenzarchiv als Phase-2-Eingangskriterium
- Rating-Fragebogen testweise durchspielen (vor Phase-2-Freigabe)
- Muttersprachler-Review je nach Sprach-Gate organisieren (Fallback: LLM-Cross-Check dokumentieren)

## 16. External Review (Regel 7)

**Runde 1 - 5. Juli 2026, Quellen: gemini-review (Gemini REST) + gpt-review (Codex/ChatGPT-Abo)**

**gemini-review:** Output weitgehend generisch (Standard-Solo-Dev-Warnungen); behauptete zudem, Abschnitt 5 liege nicht vor, obwohl die komplette Spec im Prompt war - Aussagen entsprechend niedrig gewichtet. Übernommen wurde der eine substanzielle Punkt: Pre-Launch-Community-Aufbau explizit machen (→ Abschnitt 13, Landing Page + Warteliste ab Phase 3b statt erst zum Launch).

**gpt-review:** substanziell, 5 Finding-Cluster - Reaktionen im Einzelnen:
1. *Timeline ohne Gates unrealistisch* → **übernommen** - zunächst als Kalender-Gates; per Tobsi-Entscheidung vom 5.7. auf Reihenfolge-Gates ohne Kalenderdaten umgestellt (Abschnitt 14 ist maßgeblich; Inkonsistenz-Hinweis aus Runde 5 behoben).
2. *Regelwerk nicht implementierungsreif (Insolvenz/Betting-Kanten, Trumpfkarten-Widerspruch, Economy geraten, „100% Testabdeckung" als Scheinkriterium)* → **übernommen:** gepinnte Einsatz-/Insolvenzregeln (Erhöhungs-Cap statt Side-Pots, Sieg ohne Aufdecken, Zahlungs-Cap, Ausscheide-Zeitpunkt), Trumpfkarten-Regelfehler korrigiert (offene Trumpfkarte, nicht „verdecktes Blatt"), Monte-Carlo-Economy-Kalibrierung + Property-Tests als Phase-1-Exit (Abschnitte 3, 14).
3. *Spaß-/Verständnis-Validierung zu spät* → **übernommen:** Phase 3b Ugly-Prototyp-Playtest mit Messgrößen vor Asset-Vollproduktion (Abschnitte 12, 14).
4. *Scope-Streichliste* → **teilweise übernommen:** fester Vierertisch, Game Center/Achievements/Detail-Statistiken → v1.x, keine Netzwerk-Abstraktionen (YAGNI), Themes 2+3 als Stretch bestätigt. **Nicht einseitig übernommen** (expliziter Tobsi-Wunsch, → Tobsi-Entscheidung): Sprachumfang zum Launch, Theme-Switcher als Produktziel.
5. *Rating 18+ / KI-Asset-Lizenzen / Musik-Lizenzloch / Markenrecherche / Compliance-Lücken* → **übernommen:** Risiko 1 neu gefasst (18+ als Produktentscheidung), Lizenz-Nachweis als Phase-2-Eingangskriterium inkl. Provenance-Pflichten, Musik-Quelle als Tobsi-Entscheidung, Markenrecherche vor Namensfestlegung, Compliance-Paket in Phase 8, Store-Hygiene in Abschnitt 13.

**Runde 2 (Delta-Check) - 5. Juli 2026, Quelle: gpt-review:** gezielter Check nur der neu gepinnten Einsatz-/Insolvenzregeln (das neue Design-Material aus Runde 1; volle Zweitrunde bewusst nicht - die übrigen Änderungen SIND die eingearbeiteten Findings). Ergebnis: 11 konkrete Undefiniertheiten (u.a. 0-Chip-Spieler in der Poch-Phase, Mitgehen ohne Paar, Cap-Formalisierung und -Neuberechnung nach Pass, Zweispieler-Rest, Mehrfach-Insolvenz, Restchips Ausscheidender, Mulden-Verbleib bei Partie-Ende, Geber-Rotation, Tie-Break). **Alle 11 als gepinnte Kantenfälle in Abschnitt 3 aufgenommen.** Verbleibende Feinheiten (z.B. exakte Rundenlimit-Werte) löst die Monte-Carlo-Kalibrierung in Phase 1 vor Gate A (Regel-Freeze).

**Runde 3 (Tobsi-Feedback + externe Quelle) - 5. Juli 2026:** Drei Punkte, Reaktionen:
1. *Review-Seed für Apple-Reviewer via verstecktem TestFlight-Menü* → **Intent übernommen, Umsetzung geändert:** Entwicklermenü nur in DEBUG-Builds (`#if DEBUG`), nie im Release-Binary - versteckte Schalter im Shipping-Build sind ein 2.3.1-Rejection-Risiko und ein Pro-Toggle wäre ein Unlock-Bypass. Reviewer-Pfad läuft stattdessen übers geskriptete Tutorial + Review-Notes (Abschnitt 7).
2. *Cap-Neuberechnung muss im Reducer + dynamischen UI-Grenzen abgebildet sein* → **übernommen** (Abschnitt 7; Regelseite war bereits in Runde 2 gepinnt).
3. *Audio-Loop-Problem generierter Musik (Knacken am Loop-Punkt)* → **übernommen:** librosa-Schnitt-Tool + knackfreier Loop als Abnahmekriterium (Abschnitt 9). Besonders relevant wegen Tobsi-Entscheidung „nur Replicate, kein Stock-Fallback".
Tobsi-Zusatz: Einstellungen-Menü früh bauen → übernommen (Abschnitt 7, ab Phase 3).

**Runde 4 (GOTY-Kreativ-Review) - 5. Juli 2026, Quellen: gemini-review + gpt-review, diesmal mit Ideen-Prompts statt Risiko-Prompts:**
- **gpt-review: Volltreffer-Paket** (respektiert fixe Regeln, keine Dark Patterns, passt zur Wirtshaus-Identität): Phasen-Dramaturgie (Ante als eine Bewegung, Melden als inszenierte Aufdeckung statt Sofort-Auszahlung, Einsatz-Gesten mit lesbarer Absicht, Kettenbruch-Spotlight + Endspiel-Verdichtung), „Letzte Runde"-Inszenierung (Kerze) statt administrativem Partie-Ende, „Abend im Rückblick" (3 kuratierte Momente statt Statistik-Tabelle), Gegner-Erinnerungen + freiwillige Revanche, „Wirtshausbuch" (illustrierte Erlebnis-Einträge statt Fortschrittsbalken), kuratierte Nächste-Partie-Empfehlung, Signature Moment **„Der Poch"** (Tischschlag-Geste mit Stille + Charakter-Reaktionen, nur bei großen Erhöhungen). → Tobsi-Entscheidung zur Übernahme ausstehend.
- **gemini-review: weitgehend Genre-Verfehlung** - reviewte das Spiel als Run-basiertes Roguelike (Karten-Transmutation, Risiko-Slider, Deck-Mutationen); würde das traditionelle Regelwerk und die Positionierung brechen → verworfen. Verwertbarer Kernel: geschichtete Sound-Identität pro Farbe/Aktion (zahlt in die Juice-Arbeit von Phase 6 ein).

**Runde 5 (drei weitere externe Feedbacks, vom Tobsi eingereicht) - 5. Juli 2026:** Reaktionen:
1. *Pre-Gate „Naming + Rating-Dry-Run + Lizenzmodell" vor der Asset-Produktion* → **übernommen** als Gate 0.5 inkl. Implementation-Readiness-Checkliste (Abschnitt 14).
2. *DPMAregister leistet keine Ähnlichkeitssuche, DPMA prüft keine älteren Rechte - Exact-Match reicht nicht* → **übernommen**, Markenrecherche-To-do präzisiert (Abschnitt 15).
3. *Phase-3b-Metriken schärfen (Bots lesbar / Cap intuitiv / Sieg ohne Aufdecken fair) + Zielwerte vorab* → **übernommen** (Abschnitt 14).
4. *Inkonsistenz: Abschnitt 16 nannte noch Kalender-Gates, Abschnitt 14 nicht mehr* → **behoben** (Annotation in Runde 1).
5. *Rating differenzierter: höchste Alterskategorie je Region 17+/18+ statt pauschal 18+* → **übernommen** (Risiko 1).
6. *Melde-Reihenfolge unklar (simultan vs. reihum)* → **gepinnt:** reihum ab links vom Geber (Abschnitt 3).
7. *Explizite Property-Test-Invarianten benennen* → **übernommen** (Phase-1-Exit, Abschnitt 14).
8. *Log mit visuellen Tells für Einsteiger* → **übernommen** (Abschnitt 7).
9. Das dritte Feedback war überwiegend Bestätigung - Lob wird nicht als Validierungssignal gewertet (Sycophancy-Vorsicht); die im Feedback enthaltene „Implementierungsfreigabe" zählt nicht, Freigaben erteilt ausschließlich Tobsi selbst.

**Runde 9 (5 weitere Reviews, von Tobsi eingereicht) - 5. Juli 2026:** Reaktionen:
1. *Echter Text-Bug: „Geber eine Karte weniger" gilt nur beim Vierertisch* → **korrigiert** in Regelwerk, Spec und UX-Hinweis („links vom Geber = mehr, nie der Geber"); exakte Handgrößen pro Tischgröße gepinnt + eigener Test (11/10/10 · 8/8/8/7 · 7/6/6/6/6 · 6/5/5/5/5/5).
2. *Sequenz-Toggle war in sich widersprüchlich („Trumpf-Dreierfolge... dann die mit Trumpf")* → **korrigiert:** Option = Dreierfolge jeder Farbe, Kaskade höchste > Trumpf-Folge > näher links vom Geber.
3. *„Pochen ohne Paar"-Toggle braucht Tiebreak* → **ergänzt:** höchste Einzelkarte, bei gleichem Rang schlägt Trumpf.
4. *Classic-Force-End?* → bereits seit Runde 8 in der Engine (Match.safetyRoundCap = 500, getestet).
5. *Spielertext-Polish* („Das Pochen" statt „Poker-DNA" - Identität: Poker stammt von Poch, nicht umgekehrt; einfacherer Trumpf-Satz; Melden-Beispiel; Ausspielregel als verbindliche Poch-1441-Fassung markiert; Hausregeln-Default-Hinweis; „Jackpot-Finale" statt „Dramatisches Finale"; Modi-Zellen ruhiger; „am echten Tisch"-Claim entschärft) → **übernommen**.
6. *Ante erneut* → Verweis auf Balance-Report (62% Rückfluss übers Melden); Regel bleibt, Beobachtung läuft.
7. *Neue Ideen geparkt:* „Spielanleitung" (Strategie-Guide: Wann bluffen? Wann Mariage? - Phase-5/Marketing-Artefakt), 30-Sekunden-Block als interaktives Erst-Tutorial (Abschnitt 8), Papier-Playtest mit 10 Poch-Neulingen als optionaler Pre-Freeze-Check (Tobsis Wahl), Bot-Anpassung bei aktivem „ohne Paar"-Toggle (Abschnitt 6).

**Runde 8 (5 weitere Regelwerk-Reviews, von Tobsi eingereicht) - 5. Juli 2026:** Reaktionen:
1. *Spielerregelwerk-Feinschliff* (Drei-Phasen-Intro, „Kunststücke (Kombinationen)", Ketten-Stopps als Liste, „Restkarten zählen nur am Rundenende", Warum-Sätze, 30-Sekunden-Zusammenfassung, Positionierung „auf Basis klassischer Regeln, für Poch 1441 verbindlich", Modi ent-technisiert, Entwicklerzeile raus) → übernommen in `regelwerk.html`.
2. *Engine-Kantenfälle explizit* (Mariage/Sequenz bei offener Trumpfkarte + Tests; unsichtbarer Safety-Cap für Classic; Sequenz-Toggle-Kaskade für v1.x geparkt) → übernommen (Engine + Abschnitt 3; 46 Tests).
3. *Bot-Kernanforderungen* (Ante-Awareness, Cap-Fenster, Mitzählen) → übernommen (Abschnitt 6).
4. *UX* (geschenktes Anspielrecht signalisieren, „Hand leer!"-Moment) → übernommen (Abschnitt 7).
5. *Ante erneut kritisiert* → mit Daten beantwortet: ~62% der Antes fließen allein übers Melden zurück, Phasen-Balance gesund (`tasks/balance-report.md`). Regel bleibt.
6. *„Mulde der Farbe der offenen Trumpfkarte"* → Reviewer-Irrtum: Es ist die Mulde des KartenWERTS, nicht der Farbe - Wording im Regelwerk entsprechend eindeutig gemacht.

**Runde 7 (4 externe Regelwerk-Reviews, von Tobsi eingereicht) - 5. Juli 2026:** Noten 8,5-9,5/10, kein Regel-Logikfehler gefunden. Reaktionen:
1. *Doku vermischt Spieler- und Dev-Ebene* → übernommen: `artifacts/regelwerk.html` ist jetzt reines Spielerregelwerk (Cap laienverständlich, ohne Test-/Gate-Jargon); die Dev-Ebene bleibt Spec Abschnitt 3.
2. *Wording-Schärfungen* (Trumpf-Mulden-Beispiel, Poch-Mulden-Übertrag explizit, Ränge-nicht-Farben, Zwangszug-Rundenende, Restkarten wertlos, Sequenz klar als v1-Pinning) → übernommen.
3. *UX-Paket* (Aktions-Badges über Gegnern, Cap nie erklären + Limit-Toast, Geber-Hinweis, Instant-Skip ohne Bietrecht, Eliminierungs-Zeitraffer, Ketten-Stopp-Begründung als Badge, 0,8s-Zwangszug-Delay, Phasen-Identität „drei Akte") → übernommen (Abschnitte 7 und 7a).
4. *Vor Gate A Phasen-Balance + Replays prüfen* → übernommen als zusätzliche Gate-A-Bedingung (Abschnitt 14); pochsim wird um Phasen-Beitrags-Metriken erweitert.
5. *Ante zu teuer / auf 8 senken* → geprüft, verworfen: 1 Chip in jede der 9 Mulden ist die historische Kernregel; Antes fließen größtenteils über Melden/Pott zurück; Monte-Carlo zeigt gesunde Partielängen. Bleibt unter Beobachtung der Balance-Analyse.
6. *Trumpf-Bestimmung ungewöhnlich* → verworfen: „letzte Karte offen" IST die Pagat-Regel.
7. *„Centerpot selten gefüllt"* → Fehllesung: Die Mitte erhält jede Runde die Antes und wird jede Runde vom Ausspiel-Sieger gewonnen; Restkarten-Zahlungen laufen separat. Wording geschärft.
8. *Finale-Event Restmulden→Mitte* → gute Idee, als v1.x geparkt (Regeländerung, braucht Rekalibrierung).

**Runde 6 (Tobsi-Entscheidung) - 5. Juli 2026:** Externer Playtest von Phase 3b (Ugly-Prototyp, vor Asset-Produktion) auf Phase 7b (nach Design-Komplettierung) verschoben - Tobsi will maximales Design vor dem ersten Fremdkontakt. Widerspruch zur Review-Empfehlung aus Runde 1/5 ist bewusst: Die Empfehlung unterstellte teure Asset-Produktion; die HOT-TAKE-Pipeline belegt aber, dass das Qualitätsniveau mit niedrigen Grenzkosten erreichbar ist. Restrisiko + Abfederung dokumentiert in Risiko 7.
