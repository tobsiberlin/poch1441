# Stand POCH 1441 - Neubau

Letzte Aktualisierung: 14.11.2026, Staffelwechsel nach dem M0-Entwurf

## Ziel

Kompletter Neubau nach `docs/CONCEPT.md` (Konzept v0.1). Arbeitsregeln in `CLAUDE.md`. Das alte Projekt liegt unter `legacy/` und ist nur Referenz.

## Erledigt

- **Schritt 1 - Umbau (14.11.2026):** Alter Stand als Commit gesichert und mit `legacy-snapshot` getaggt. Auf dem Branch `neustart` ist das alte Projekt nach `legacy/` verschoben, `CLAUDE.md` und `docs/CONCEPT.md` sind neu angelegt. `fastlane/` bleibt im Root (Entscheidung Tobsi: Pipeline zu App Store Connect behalten).
- **Schritt 2 - M0 Entwurf (14.11.2026):** `docs/RULES.md` geschrieben: Klassik-Regeln (`K-…`), Modern-Layer (`M-…`), Abweichungen zum alten Code mit Belegen, Fragenliste. Kein Swift-Code.

## Jetzt dran

### A. Entschieden - in `docs/RULES.md` einarbeiten

Tobsi am 14.11.2026: "alles wie vorgeschlagen". Das deckt nur die Fragen, zu denen `docs/RULES.md` eine klare Empfehlung enthielt. Die Vorgänger-Session hatte fälschlich behauptet, jede Frage habe eine Empfehlung.

Einarbeiten heißt: Regeltext festschreiben, das Kennzeichen `[OFFEN F-nn]` durch `[E]` ersetzen (neu in Abschnitt 0.2: "Von Tobsi entschieden, mit Datum") und die Frage aus Abschnitt 10 in ein Entscheidungsprotokoll verschieben.

| Frage | Entscheidung | Regel |
|---|---|---|
| F-01 | Die zweite Gleichstandsstufe ("näher links vom Geber") entfällt im Klassik-Vertrag. | K-306 |
| F-05 | Passen ist immer endgültig, auch vor der ersten Eröffnung. | K-312 |
| F-06 | Restkarten werden höchstens bis Stand 0 bezahlt, keine Schulden. | K-409 |
| F-07 | Die Engine führt Zwangszüge selbst aus und meldet sie als Events. | K-410 |
| F-08 | Ernte-Events in Brettreihenfolge: Ass, König, Dame, Bube, Zehn, Hochzeit, Folge. | K-211 |
| F-12 | Alle siegeln verdeckt, die Siegel werden zugleich aufgedeckt. Mehrere Spieler dürfen dieselbe Mulde siegeln. | M-104 |
| F-17 | Die Bank ist ein eigenes Konto und darf ins Minus gehen. Invariante: Spieler plus Mulden plus Einsätze plus Bank ist konstant. | M-401, K-502 |
| F-04, Punkt 4 | Gemeinsamer Deckel: Niemand darf höher bieten, als der ärmste noch bietberechtigte Spieler insgesamt zahlen kann. Neu berechnet nach jedem Passen. | K-310 |
| 10.5 | Die sechs von Pagat übernommenen Regeln sind bestätigt, einschließlich "die Vorhand erhält die erste Karte". | K-004, K-103, K-106, K-304, K-308, K-311 |

### B. Noch offen - Tobsi vorlegen

Elf Fragen hatten keine oder nur eine halbe Empfehlung. Die folgenden Vorschläge stammen aus der Vorgänger-Session, die alten Code und Pagat vollständig im Kontext hatte. Sie sind Vorschläge, keine Entscheidungen.

- **F-02 Einsatz in die Mulden nicht zahlbar.** Wer vor einer Runde keine 9 Chips hat, nimmt an ihr nicht teil. Im Klassik-Modus endet damit die Partie (wie Pagat). Was im Run daraus folgt, wird in M2 entschieden (neu als R-05).
- **F-03 Erster Geber.** Der erste Geber wird aus dem Seed bestimmt (Pagat: "chosen at random"). Danach wechselt das Geberrecht nach links.
- **F-04 Einsatzregeln, Rest.** Mindesteinsatz 1 Chip. Eine Stufe ist 1 Chip, erhöht wird in ganzen Stufen, mehrere Stufen auf einmal sind erlaubt. Ohne Edikt gibt es keine weitere Obergrenze und keine Begrenzung der Zahl der Erhöhungen, es gilt nur der gemeinsame Deckel. Für den Deckel zählen alle Spieler, die noch dabei sind, pochen dürfen und Chips haben. Wer nach dem Einsatz in die Mulden 0 Chips hat, kann nur passen. Alle Werte in die Config.
- **F-09 Ende einer Klassik-Partie.** Wie Pagat: Die Partie endet, sobald vor einer Runde ein Spieler keine 9 Chips mehr hat. Die meisten Chips gewinnen, bei Gleichstand geteilter Sieg. Chips in den Mulden verfallen.
- **F-10 Modern-Layer für KI-Sitze.** Siegel, Blindpochen und Kette gelten für alle Sitze gleich. Die Engine braucht dann keinen Sonderfall "Mensch", und Tells ergeben nur Sinn, wenn Gegner wirklich bluffen können.
- **F-11 Siegel: Pflicht und Kosten.** Siegeln ist Pflicht. Kosten zum Start 0, als Config-Wert. Sollten später Kosten kommen, fließen sie in die Bank.
- **F-13 Zunftstrafe.** Bezugsgröße ist der gesamte eigene Einsatz in diesem Akt II. Die Strafe bleibt in der Poch-Mulde liegen und wächst in die nächste Runde. Reichen die Chips nicht, wird bis Stand 0 gezahlt. Die Strafe trifft jeden Showdown-Teilnehmer ohne Gruppe, egal ob er eröffnet hat oder nur mitgegangen ist.
- **F-14 Showdown ohne jede Gruppe.** Niemand gewinnt. Alle Teilnehmer zahlen Zunftstrafe. Einsätze, Strafen und der bisherige Inhalt bleiben in der Poch-Mulde für die nächste Runde. Den Lauf eröffnet die Vorhand. Die Sitzregel aus F-01 wird damit nirgends gebraucht.
- **F-15 Kette: Zählweise.** Die Kette zählt die Karten, die ein Spieler in Folge legt, ohne dass ein anderer dazwischen legt. Die Eröffnungskarte zählt mit. Ein eigener Stopp gibt ein zusätzliches Glied, und die Kette läuft in der neuen Reihe weiter. Legt ein anderer Spieler eine Karte, beginnt die Kette neu. Beendet eine Karte die Runde, zählt sie als Karte, aber nicht als Stopp. Im Beispiel aus `docs/RULES.md`: ♥7 und ♥8 ergeben 2, dann unterbricht S2. Danach ♥10 mit Stopp und ♠A mit Stopp ergeben 4. Die längste Kette ist 4.
- **F-16 Kettenbonus.** Der Bonus kommt aus der Bank. Jeder Spieler erhält ihn für seine längste Kette, unabhängig davon, wer den Lauf gewinnt. Keine Mindestlänge zum Start, aber ein Config-Wert dafür.
- **F-18 Blindpochen im Klassik-Modus.** Nicht in v1. Klassik bleibt pures Poch.

Antwortzeile für Tobsi: `alles wie vorgeschlagen` oder einzelne Abweichungen, zum Beispiel `F-15: Lesart B`.

### C. Danach

- Tobsis Antwort zu B einarbeiten, Status von `docs/RULES.md` auf "final" setzen. Damit ist M0 abgenommen.
- M1 (PochCore Klassik, test-first) beginnt erst nach einem eigenen Plan im Plan Mode. Jeder Test nennt seine Regel-ID.

## Entscheidungen

- Branch `neustart` trägt den Neubau. `main` und der alte Branch `agent/publish-poch-tutorial-hardware-qa` bleiben unberührt. Ob `neustart` zu `main` wird, ist offen.
- Das Chrome-Profil aus einem Review-Lauf wird nicht versioniert.
- Herkunft jeder Regel ist in `docs/RULES.md` gekennzeichnet: `[K]` Konzept, `[P]` Pagat, `[A]` abgeleitet, `[OFFEN]`, künftig `[E]` entschieden.
- Kontextschnitte führt Claude selbständig per cmux durch (Tobsi 14.11.2026): Stand sichern, Nachfolge-Session in neuer Fläche starten, prüfen, alte Fläche schließen.

## Geparkt

- `fastlane/Fastfile` verweist auf `Poch1441.xcodeproj` und die alten Schemes. Anpassen, sobald das neue App-Target existiert.
- Im Root gibt es keine `AGENTS.md` mehr (liegt in `legacy/`).
- Die Root-`.gitignore` ignoriert `*.xcodeproj`. Neu bewerten, wenn das neue Xcode-Projekt entsteht.
- Das neue `CLAUDE.md` verlangt XcodeBuildMCP. Der Server muss vor M3 eingerichtet sein.
- Arbeitsbaum `poch-material` (Branch `codex/poch-material-20260718`) ist unberührt und nicht Teil des Tags.
- Vorgemerkt für den Run-Layer (M2): R-01 bis R-04 in `docs/RULES.md`, Abschnitt 10.4.
- Die globale `~/.claude/CLAUDE.md` sagt im Abschnitt zu Schnittpunkten noch, Claude liefere einen Copy-Paste-Block für `/clear`. Tobsis neue Vorgabe (cmux-Staffelwechsel) ist bisher nur als Projekt-Memory gespeichert. Tobsi einmal fragen, ob die globale Regel angepasst werden soll.
