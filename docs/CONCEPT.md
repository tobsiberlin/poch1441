# POCH 1441 - Konzept v0.1

> **Das Spiel, das 1441 verboten wurde. Der Großvater des Pokers.**
> Spiel dich in 585 Jahren vom Straßburger Hinterzimmer bis an den Neon-Tisch von heute - und schlag den Enkel mit Opas Regeln.

Stand: 14.11.2026 · Status: Konzept vor Fun-Prototyp · Alle Zahlen sind Startwerte zum Tunen, keine Wahrheiten.

---

## 1. Vision in drei Sätzen

1. Poch ist das einzige Kartenspiel, das in **einer Runde drei Genres** spielt: Glück (Ernte), Psychoduell (Pochen), Taktik (Lauf).
2. Wir legen darüber einen **Run-Layer**, dessen Progression die echte Ahnenlinie des Pokers ist: Straßburg 1441 → Paris (Poque) → Mississippi 1834 → heute.
3. Ziel ist der "noch ein Tisch"-Sog moderner Run-Games - ohne Dark Patterns, als ehrliches Premium-Spiel.

**Was es nicht ist:** kein "Balatro mit anderen Karten", kein Casino, keine kaufbaren Chips, keine Energie, keine Werbung, kein Echtgeld.

---

## 2. Designprinzipien (verbindlich)

| Prinzip | Konsequenz |
|---|---|
| Jeder Akt hat eine echte Entscheidung | Kein Akt läuft passiv durch |
| Jeder Akt fühlt sich anders an | Andere Bühne, anderes Tempo, anderer Sound, andere Haptik |
| Regelklarheit vor Spektakel | Animation verschleiert nie den Zustand |
| Spielen vor Erklären | Kein Regelhandbuch, Lernen im ersten Tisch |
| Tempo ist ein Feature | Alles beschleunig- oder überspringbar, Schnellmodus |
| Historie als Mechanik, nicht als Deko | Epochen, Edikte und Artefakte tragen echte Geschichte |
| Fair | KI kennt keine verdeckten Karten, Mischen per Seed, nachvollziehbar |
| Offline first | Gesamter Einzelspieler ohne Netz |

---

## 3. Spielstruktur auf einen Blick

```
RUN (~40 min)  =  9 Tische  (die 9 Mulden des Pochbretts)
 ├─ Epoche I    1441 Straßburg      Tisch 1-3   (Tisch 3 = Boss)
 ├─ Epoche II   1718 Paris / Poque  Tisch 4-6   (Tisch 6 = Boss)
 ├─ Epoche III  1834 Mississippi    Tisch 7-8
 └─ Finale      2026                Tisch 9 = Mittelmulde, Boss "Der Enkel"

TISCH (~5 min)  =  3 Runden + Ziel ("Zunftzoll")
RUNDE (~90 s)   =  Akt I Ernte → Akt II Pochen → Akt III Lauf
Zwischen Tischen: Krämer (Artefakte kaufen) + nächstes Edikt wird angekündigt
```

**Tisch-Ziel (Zunftzoll):** Nach 3 Runden musst du mindestens X Chips Netto-Gewinn haben. Verfehlt = Run vorbei. Zoll steigt pro Tisch.

**Chips = Run-Währung:** Dein Chipstand ist gleichzeitig Leben, Einsatz und Geld beim Krämer. Jedes gekaufte Artefakt macht dich stärker und gleichzeitig ärmer am Tisch - das ist die zentrale Run-Spannung.

---

## 4. Regelbasis (Klassik)

Referenz: modernes deutsches Poch (Pagat). Grenzfälle sind hier festgelegt, damit die Engine nichts raten muss.

**Material:** 32 Karten (7 bis Ass), 3-6 Spieler, Standard 4 (du + 3 KI).

**Pochbrett:** 8 Außenmulden + Mittelmulde

| Mulde | Gewinnt in Akt I, wer hält ... |
|---|---|
| Ass | Ass der Zahlfarbe |
| König | König der Zahlfarbe |
| Dame | Dame der Zahlfarbe |
| Bube | Bube der Zahlfarbe |
| Zehn | Zehn der Zahlfarbe |
| Hochzeit | König + Dame der Zahlfarbe |
| Folge | 7 + 8 + 9 der Zahlfarbe |
| Poch | wird in Akt II gewonnen |
| Mitte | wird in Akt III gewonnen |

**Rundenbeginn:** Jeder legt 1 Chip in jede der 9 Mulden. Geber teilt aus, eine Karte wird aufgedeckt: deren Farbe = Zahlfarbe. Die Karte gehört niemandem.

**Akt I - Ernte:** Mulden auszahlen. Nicht gewonnene Mulden bleiben liegen und wachsen in die nächste Runde.

**Akt II - Pochen:** Beste Gruppe gleichrangiger Karten gewinnt den Poch-Topf plus Einsätze.
- Vierling > Drilling > Paar. Anzahl schlägt Rang (drei Siebener > zwei Asse).
- Gleiche Gruppe, gleicher Rang: Gruppe mit Karte der Zahlfarbe gewinnt. Sonst gewinnt, wer näher links vom Geber sitzt. *(gegen Pagat verifizieren)*
- Passen alle bis auf einen: Der gewinnt ohne Aufdecken.
- Mehrere bleiben bei ausgeglichenem Einsatz: Showdown.
- Passen alle: Niemand gewinnt, Poch-Topf bleibt für die nächste Runde.
- Klassik: Pochen nur mit mindestens einem Paar.
- Kein Side-Pot-System in v1: Einsätze sind durch den eigenen Chipstand gedeckelt.

**Akt III - Lauf (Ausspielen):**
- Gewinner des Pochens eröffnet, sonst links vom Geber. Beliebige Karte.
- Danach muss die nächsthöhere Karte derselben Farbe gelegt werden, egal von wem.
- Kann niemand fortsetzen: **Stopp.** Wer zuletzt gelegt hat, eröffnet neu.
- Wer zuerst keine Karten mehr hat, gewinnt die Mittelmulde und bekommt von jedem Gegner 1 Chip pro Restkarte.

---

## 5. Der Modern-Layer: eine echte Entscheidung pro Akt

Im **Run-Modus** aktiv, im **Klassik-Modus** aus.

### Akt I - Ernte: das Siegel
- Hand ist sichtbar, Zahlfarbe noch verdeckt.
- Du setzt dein **Siegel** auf eine der 7 Ernte-Mulden (Ass bis Folge).
- Gewinnst du genau diese Mulde: **Auszahlung x2** (Bonus kommt aus der Bank, nicht von den Gegnern).
- KI-Gegner siegeln ebenfalls und offen - das verrät etwas über ihre Hände.
- Dauer: 2-3 Sekunden. Danach Reveal mit Spannung, dann Auto-Auszahlung.
- *Tuning-Hebel:* Multiplikator, Siegel-Kosten, mehrere Siegel durch Artefakte.

### Akt II - Pochen: echtes Klopfen + Bluff
- **Signature-Interaction:** Du klopfst auf den Tisch (Doppeltipp), mit Core-Haptics-Thud. Jedes weitere Klopfen erhöht um eine Stufe. Halten = mitgehen, wegwischen = passen.
- **Tap-Alternative ist Pflicht:** Buttons Passen / Mitgehen / Erhöhen für Accessibility und Einhand.
- **Blindpochen (Bluff):** Im Run-Modus darfst du auch ohne Gruppe pochen.
  - Passen alle anderen: Du gewinnst ohne Aufdecken. Bluff gelungen.
  - Kommt es zum Showdown und du hast keine Gruppe: **Zunftstrafe.** Einsatz weg, zusätzlich zahlst du den Einsatz noch einmal in den Poch-Topf.
- **Tells:** Jeder Gegner hat 1-2 lernbare Verhaltensmuster (Zögern, Klopfrhythmus, Blickrichtung, Chip-Fummeln). Tells sind ehrlich, aber nicht immer eindeutig. Das ist das Skill-Ceiling.

### Akt III - Lauf: Kette + Multiplikator
- Jede Karte, die **du** legst, während die Reihe läuft, erhöht deine **Kette** um 1.
- Ein **Stopp, den du auslöst** (deine Karte war die letzte): Kette +1 und du eröffnest.
- Rundenende: Kettenbonus = längste eigene Kette × Faktor (Start: 1 Chip pro Glied).
- **Zähl-Spektakel:** Chips rattern hoch, Ton steigt mit jedem Glied, Haptik wird dichter. Das ist der Dopamin-Peak jeder Runde - kurz halten (≤ 1,5 s), überspringbar.

---

## 6. Run-Layer

### Epochen
| Epoche | Tische | Setting | Material / Look | Bühnen-Twist |
|---|---|---|---|---|
| I · 1441 | 1-3 | Straßburger Zunftstube, das Spiel ist verboten | Zinn, Holz, Kerzenlicht | Wache patrouilliert: lautes Klopfen hat Risiko |
| II · 1718 | 4-6 | Pariser Salon, Poque | Lack, Messing, Spiegel | Höfische Etikette-Edikte |
| III · 1834 | 7-8 | Mississippi-Dampfer, aus Poque wird Poker | Mahagoni, Gaslicht, Samt | Kartenspieler mit Tricks |
| Finale · 2026 | 9 | Neon-Tisch, "Der Enkel" spielt Poker-Logik | Graphit, Glas, Neon | Boss mit modernen Regeln vs. deine alten |

Historische Anker (für Texte, vor Release faktenchecken):
- 1441 Straßburger Verordnung erwähnt das Spiel (als "boeckels"), meist im Kontext von Verboten.
- Frankreich: Poque. Über französische Siedler nach Louisiana / New Orleans, dort zu "Poker" anglisiert.
- Bis 1834 übernimmt Poker das 52-Karten-Deck.

### Edikte (Regelmutation pro Tisch, vorher angekündigt)
Startliste:
- **Straßburger Verbot:** Max. Erhöhung 3 Chips. Wer 3× in einer Runde klopft, wird "erwischt" und zahlt 2 Chips Strafe.
- **Fastenzeit:** Hochzeit-Mulde ist versiegelt, ihr Inhalt wandert in die Mitte.
- **Salon-Etikette:** Blindpochen verboten, dafür zählt Siegel x3.
- **Bankrott des Hauses:** Zunftzoll halbiert, aber keine Krämer-Pause danach.
- **Dampferfahrt:** 52 Karten statt 32 (längerer Lauf, mehr Stopps).
- **Gezinkte Bank:** Zahlfarbe wird erst nach dem Pochen aufgedeckt.

### Artefakte (Joker-Äquivalent, Effekt + echte Mini-Story)
Startliste (Effekte sind Platzhalter fürs Balancing):
- **Ziegenbock-Figur:** Die Mittelmulde zahlt +50 %. *(Bock in der Brettmitte, Namenstheorie "boeckels")*
- **Ratsprotokoll 1441:** Edikte der Epoche I gelten für dich nicht.
- **Zinnbecher:** Erste Ernte-Mulde pro Tisch zahlt doppelt.
- **Spiegel des Salons:** Du siehst bei einem Gegner pro Runde sein Siegel, bevor du siegelst.
- **Gezinkte Karte:** 1× pro Tisch: Eine Handkarte wird zur Zahlfarbe.
- **Ärmel des Flussspielers:** Eine Karte bleibt beim Lauf geheim im Ärmel und kann eine Reihe fortsetzen, ohne gezählt zu werden.
- **Kerzenstummel:** Tells von Gegnern werden deutlicher.
- **Akademie-Regelbuch 1718:** Bei Gleichstand im Showdown gewinnst immer du.

v1-Umfang: ca. 25 Artefakte, ca. 10 Edikte.

### Krämer
Zwischen den Tischen: 3 zufällige Artefakte, Kauf mit Chips, max. 5 Artefakt-Slots. Optional "Reroll" für Chips.

### Gegner
Persönlichkeit und Stärke werden getrennt modelliert (Strategie-Vektor: Risiko, Bluffneigung, Planungstiefe, Tell-Deutlichkeit).
- Pro Epoche 3-4 Archetypen + 1 Boss. Alle fiktiv.
  - Epoche I: Der Zunftmeister (Boss), Die Wirtin, Der Stadtknecht ...
  - Epoche II: Die Salonière (Boss), Der Abbé ...
  - Epoche III: Der Flussspieler (Boss), Die Telegrafistin ...
  - Finale: **Der Enkel** - spielt aggressiv wie Pokerprofis, hat Poker-Logik als eigene Edikte.
- Die KI kennt keine verdeckten Karten. Stärke durch bessere Heuristik und Simulation, nicht durch Cheaten.

### Meta
- **Tagespoch:** Fester Daily Seed, gleicher Run für alle, teilbares Ergebnis-Grid (9 Felder = 9 Tische, Wordle-artig).
- **Chronik:** Freischaltbare Epochen-Texte und Artefakt-Geschichten. Freiwillig, kein Sammelzwang.
- **Klassik-Modus:** Pures Poch ohne Modern-Layer, freie Partie gegen 3 KI.

---

## 7. UX & Bühne

- **Hochformat, Einhand** als einziges Pflicht-Layout in v1.
- **Die Scheibe verwandelt sich pro Akt** - eine Bühne, drei Zustände:
  - Akt I: Scheibe offen und groß, 9 Mulden im Fokus.
  - Akt II: Scheibe fährt zurück und dunkelt ab, Gegner rücken heran, Duell-Arena, Musik wird leiser.
  - Akt III: Scheibe weicht, die Mitte wird zur **laufenden Kartenbahn**, Hand unten groß.
- **Objektkontinuität:** Keine Karte und kein Chip teleportiert. Zustand ändert sich erst beim **Aufprall**, nie beim Abflug.
- **Home = Poch Disc** in Graphit und Keramik, ruhig. Die Epochen bringen ihr Material mit, Neon gibt's im Finale.
- **Drei Tempi:** Gemütlich / Standard / Schnell. Erzwungene Züge (nur eine legale Karte) werden im Schnellmodus automatisch gespielt.

Motion-Startwerte:
| Aktion | Ziel |
|---|---|
| Karte anheben | 100-140 ms |
| Karte ausspielen | 180-240 ms |
| Chip setzen | 180-280 ms |
| Mulde auszahlen | 350-650 ms |
| Akt-Wechsel (Bühnen-Morph) | 350-550 ms |
| Showdown-Staffelung | 400-800 ms |
| Ketten-Zählung | ≤ 1500 ms |

**Sound & Haptik pro Akt:**
| | Ernte | Pochen | Lauf |
|---|---|---|---|
| Emotion | Vorfreude | Spannung | Flow |
| Sound | Chips, Metall | Stille, Klopfen, Puls | Kartenrascheln, steigende Tonfolge |
| Haptik | Leichte Taps pro Mulde | Schwerer Thud pro Klopfer | Rhythmisch, dichter mit der Kette |

---

## 8. Onboarding

- **Kein separates Tutorial.** Tisch 1 der Epoche I ist der Prolog: fester Seed, vorbereitete Hand.
- Runde 1 bringt pro Akt genau eine Mechanik bei: Siegel → Klopfen → Kette.
- Max. ein Satz Text pro Moment. Tutor-Figur optional (Hana aus der Vorversion prüfen).
- "Ich kenne Poch" überspringt das Tutorial sofort.
- Edikte und Artefakte kommen erst ab Tisch 2.

---

## 9. Monetarisierung

- **Gratis:** Epoche I (Tische 1-3) + Klassik-Modus gegen einfache KI. Unbegrenzt, ohne Tageslimit.
- **Vollversion (Einmalkauf):** Alle Epochen, Finale, Tagespoch, alle Gegnerstufen. Preis testen: 4,99 / 6,99 / 9,99 €.
- Kaufangebot erst nach dem ersten verlorenen oder gewonnenen Boss von Epoche I.
- StoreKit 2, Non-Consumable, Restore.

---

## 10. Technische Architektur

```
Poch/
├── App/PochiOS/              SwiftUI-Shell, Navigation, Store, Settings
└── Packages/
    ├── PochCore/             pure Swift, KEIN UI-Import
    │   ├── Model/            Card, Suit, Rank, Pot, Player, GameState
    │   ├── Rules/            Klassik-Regeln
    │   ├── Modern/           Siegel, Blindpochen, Kette
    │   ├── Run/              Tische, Zunftzoll, Edikte, Artefakte, Krämer
    │   ├── Engine/           apply(state, action) -> Transition(state, events)
    │   └── Random/           Seeded RNG
    ├── PochAI/               Persönlichkeiten, Betting, Lauf-Simulation
    ├── PochSim/              CLI: headless Partien und Runs fürs Balancing
    ├── PochStage/            Game Director, Event-Queue, Animation, Audio, Haptik
    └── PochDesign/           Tokens, Karten, Komponenten
```

**Harte Regeln:**
1. `PochCore` ist deterministisch: gleicher Seed + gleiche Actions = gleiches Ergebnis.
2. Jede Änderung läuft über `apply(state, action) throws -> Transition`. Nichts sonst mutiert den State.
3. `PochStage` konsumiert Events aus einer Queue und spielt sie ab. Es liest den State, schreibt ihn aber nie.
4. Ohne Animationen (Reduced Motion / Schnellmodus) werden dieselben Events sofort dargestellt.
5. Chips sind bilanzerhaltend - Invariante wird in jedem Test geprüft.
6. Rendering: SwiftUI zuerst. SpriteKit nur dort, wo ein Performance-Test es belegt.

---

## 11. Meilensteine

| # | Meilenstein | Abnahme |
|---|---|---|
| M0 | Regelvertrag final | Alle Grenzfälle entschieden, `docs/RULES.md` |
| M1 | PochCore Klassik + Tests | 100k Sim-Partien ohne ungültigen Zustand |
| M2 | Modern-Layer + Run im Core | Run headless spielbar, erste Balancing-Kurven aus PochSim |
| M3 | **Fun-Prototyp** | 1 Tisch, Epoche I, alle 3 Akt-Mechaniken, 5 Artefakte, Platzhaltergrafik auf dem iPhone |
| **Fun-Gate** | Go / No-Go | Siehe unten |
| M4 | Kompletter Run | 9 Tische, Krämer, Boss-Tische |
| M5 | Look & Feel | Epochen-Art, Sound, Haptik, Bühnen-Morph |
| M6 | Onboarding + Store | Prolog-Tisch, StoreKit |
| M7 | TestFlight | Externe Tester, Anfänger + Poch-Kenner |

**Fun-Gate-Kriterien (M3):**
- Du spielst freiwillig 3 Tische hintereinander, ohne dich zwingen zu müssen.
- In jedem Akt wird eine Entscheidung als echte Entscheidung erlebt (nicht nur geklickt).
- Mindestens ein "Oh nein / Yes!"-Moment pro Tisch.
- 3 Testspieler ohne Poch-Vorwissen verstehen die drei Akte nach Tisch 1.

Fällt das Gate durch: Mechaniken im Prototyp tunen, nicht in Art investieren.

---

## 12. Offene Entscheidungen

- [ ] Gleichstand im Showdown: Regel gegen Pagat verifizieren
- [ ] Zunftzoll-Kurve über 9 Tische (aus PochSim ableiten)
- [ ] Blindpochen auch im Klassik-Modus als Hausregel anbieten?
- [ ] Spielerzahl im Run fix 4 oder pro Epoche variabel?
- [ ] Endgültiger Name: "POCH 1441" vs. Alternativen
- [ ] Rolle der Tutorfigur Hana
- [ ] Preis
