# Poch 1441 - Tutorial-Wording in Build 10

Stand: 22.07.2026. Grundlage sind die aktuell ausgelieferten deutschen Texte aus `ContentView.swift`, `Phase2View.swift`, `Phase3View.swift` und `Localizable.xcstrings`.

## Platzhalter

- `<Rang>` ist der Rang des Paares, im separaten Biet-Tutorial zum Beispiel `10`.
- `<Name>` ist der Name des gerade handelnden Mitspielers.
- `<n>` ist ein dynamischer Chip-, Karten- oder Gesamtwert.
- Großschreibung ist Teil der sichtbaren Inszenierung.

## Hauptpfad der geführten ersten Runde

### 0. Einstieg

- Titel: **Deine erste Runde**
- Intro: „Eine Runde, drei Chancen auf den Topf. Hana zeigt dir jeden Zug direkt am Tisch.“
- Drei Akte: **1 Melden - 2 Pochen - 3 Ausspielen**
- Ziel: „Melde mit Trumpf. Poche mit einem Paar. Spiele deine Hand leer - dann gehört dir die Mitte.“
- Hauptaktion: **Erste Runde spielen**
- Alternative: **Ohne Einführung spielen**
- Kompakte Accessibility-Fassung des Ziels: „Karten los. Mitte gewinnen.“

### 1. Melden - Stein in die Mitte

- Titel: **Ziehe den Stein in die Mitte**
- Erklärung: „Dort wartet der Gewinn der letzten Phase.“
- Handlung: Den eigenen Stein in die Mitte ziehen oder antippen.
- Accessibility-Aktion: **Stein in die Mitte legen**

### 2. Melden - Tisch wird gefüllt

- Titel: **Jetzt füllt sich der Tisch**
- Erklärung: „Alle legen einen Stein in jeden kleinen Topf. Passende Trumpfkarten können diese Münzen gleich gewinnen.“
- Handlung: Läuft automatisch.
- Option während der Montage: **Direkt zum Trumpf**

### 3. Melden - erste Kartenrunde

- Titel: **Eine Karte für jeden**
- Erklärung: „Tippe auf Karten austeilen. Jede Karte bleibt sichtbar bei dem Spieler liegen, der sie bekommt.“
- Handlung im normalen Hauptpfad: Läuft als Teil der kurzen Austeil-Montage automatisch.
- Separater Schritt-Button: **Karten austeilen**

### 4. Melden - Hände vervollständigen

- Titel: **Deine Hand füllt sich**
- Erklärung: „Schließe das Austeilen ab. Danach suchen wir gemeinsam deine erste Gewinnkarte.“
- Handlung im normalen Hauptpfad: Läuft automatisch.
- Separater Schritt-Button: **Austeilen abschließen**

### 5. Melden - Trumpf aufdecken

- Titel: **Welche Farbe gewinnt?**
- Erklärung: „Decke die Tischkarte auf. Sie bestimmt nur die Trumpffarbe und gehört zu keiner Hand.“
- Aktion: **Trumpf aufdecken**

### 6. Melden - Gewinnkarte spielen

- Titel: **Da ist deine Gewinnkarte**
- Erklärung: „Tippe auf deinen markierten Trumpf-König. Er räumt den König-Topf ab.“
- Handlung: Die tatsächlich markierte Karte antippen.
- Accessibility-Aktion: **Markierte Karte spielen**

### 7. Melden - Gewinn verstehen

- Titel: **Treffer! Der Topf gehört dir**
- Erklärung: „Dein Trumpf-König räumt den König-Topf ab. Dame und König zusammen gewinnen zusätzlich den Paar-Topf.“
- Handlung: Der Gewinn wird sichtbar eingesammelt.

### 8. Melden - Übergang zum Bieten

- Titel: **Dein erster Gewinn ist sicher**
- Erklärung: „Jetzt bietet ihr um den Poch-Topf. Hana zeigt dir gleich eine sichere erste Entscheidung.“
- Aktion: **Weiter: Chips setzen**
- Kurzer Meilenstein: **Bonus-Töpfe geschafft**

### 9. Phasenwechsel zu Pochen

- Phase: **PHASE 2**
- Titel: **POCHEN**
- Unterzeile: „Du hast den Tisch gelesen. Jetzt kommt die Mutprobe.“

### 10. Pochen - das Paar erkennen

- Titel: **Du hast ein Paar**
- Erklärung: „Deine beiden <Rang> öffnen den Extra-Topf. Setz Chips und schnapp ihn dir.“
- Aktion: **Chips setzen**
- Statuszeile: **DEIN ZUG - <Rang>-PAAR**

### 11. Pochen - Einsatz wählen

- Titel: **Starte mit einem Chip**
- Erklärung: „Der Einsatz bestimmt, wie viel auf dem Spiel steht. Ein Chip hält dein Risiko klein.“
- Aktion: **1 Chip auswählen**
- Messwerte: **DU BIETEST - IM TOPF - SCHON GESETZT**

### 12. Pochen - den Tisch herausfordern

- Titel: **Pochen**
- Erklärung: „Tippe auf „Um <n> Chip spielen“. Genau das heißt Pochen: Jetzt entscheiden die anderen.“
- Hauptaktion bei einem Chip: **Um 1 Chip spielen**
- Alternative Aktionen: **Passen**, **<n> Chip mitsetzen**, **Auf <n> Chips erhöhen**

### 13. Pochen - der Chip bewegt sich

- Titel: **Dein Einsatz fliegt**
- Erklärung: „Dein Chip ist unterwegs zum Topf. Sobald er landet, sind die anderen dran.“
- Handlung: Läuft automatisch.

### 14. Pochen - die anderen entscheiden

- Titel: **Die anderen sind dran**
- Erklärung: „Dein Chip ist im Topf. Jetzt entscheidet <Name>, ob er mitspielt.“
- Sichtbare Reaktionen: **überlegt …**, **passt**, **pocht <n>!**, **geht mit**, **erhöht <n>**, **bereit**

### 15. Pochen - mögliche Antwort

- Titel: **Deine Wahl**
- Erklärung: „Mitspielen kostet <n> Chip. Mit Passen steigst du ohne weiteren Einsatz aus.“
- Aktionen: **<n> Chip mitsetzen**, **Auf <n> Chips erhöhen** oder **Passen**
- Dieser Schritt erscheint nur, wenn ein Mitspieler das Gebot hält oder erhöht.

### 16. Pochen - Ergebnis

- Gewinnerstatus: **<NAME> - NIMMT DEN POCH**
- Alternative ohne Gebot: **KEIN POCH - MULDE BLEIBT**
- Aktion: **Karten ausspielen**
- Kurzer Meilenstein: **Bieten geschafft**

### 17. Phasenwechsel zum Ausspielen

- Phase: **PHASE 3**
- Titel: **AUSSPIELEN**
- Unterzeile: „Der Poch ist entschieden. Jetzt zählt Tempo.“

### 18. Ausspielen - erste Startkarte

- Augenbraue: **ERSTER ZUG**
- Titel bei eigenem Zug: **TIPPE DEINE STARTKARTE**
- Titel bei einem Mitspieler: **<NAME> LEGT DIE STARTKARTE**
- Erklärung: „Tippe eine Karte. Danach folgen die Karten derselben Farbe automatisch der Reihe nach.“
- Handlung bei eigenem Zug: Eine Karte aus der Hand antippen.

### 19. Ausspielen - Karten folgen automatisch

- Titel: **DIE NÄCHSTE KARTE FOLGT**
- Erklärung: „Jetzt kommt automatisch die nächsthöhere Karte derselben Farbe. Du musst nichts tippen.“
- Handlung: Läuft automatisch.

### 20. Ausspielen - eine neue Reihe beginnt

- Augenbraue: **REIHE ENDET BEI <KARTE>**
- Titel bei eigenem Zug: **DU STARTET DIE NÄCHSTE REIHE**
- Erklärung bei eigenem Zug: „Du hast die letzte Karte gelegt. Tippe jetzt eine neue Startkarte.“
- Titel bei einem Mitspieler: **<NAME> STARTET DIE NÄCHSTE REIHE**
- Erklärung bei einem Mitspieler: „Die Reihe ist zu Ende. Wer zuletzt gelegt hat, beginnt die nächste.“

### 21. Ausspielen - letzte Karte

- Augenbraue: **LETZTE KARTE**
- Titel: „Du schließt die Runde.“ oder „<Name> schließt die Runde.“
- Erklärung: „Die Mitte hält inne. Gleich folgt die Abrechnung.“

### 22. Rundenabrechnung

- Augenbraue: **RUNDENENDE**
- Hauptzeile: „Du nimmst die Mitte“ oder „<Name> nimmt die Mitte“
- Gewinnerzeile: „Dein letzter Zug entscheidet.“ oder „<Name> schließt die Runde ab.“
- Erklärung: „Mitte und Restkarten ergeben <n> Chips.“
- Werte: **MITTE - RESTKARTEN - TOTAL**

### 23. Tutorial-Abschluss

- Augenbraue: **LEKTION ABGESCHLOSSEN**
- Titel nach allen drei Teilen: **Bereit für den freien Tisch**
- Erklärung: „Du kannst Bonus-Töpfe holen, um den Poch bieten und deine Hand leer spielen. Am freien Tisch hilft Hana nur, wenn du sie brauchst.“
- Fortschritt: **3 von 3 Lektionen**
- Hauptaktion: **Freie Partie starten**
- Alternative: **Lektionen ansehen**

## Zustandsabhängige Tutorial-Texte

Diese Texte gehören ebenfalls zum Tutorial, erscheinen aber nicht zwingend im geraden Hauptpfad.

### Pochen ohne Paar

- Titel: **Kein Paar**
- Erklärung: „Diesmal hast du kein Paar. Tippe Passen - du setzt nichts und behältst deine Chips.“
- Status: **PASSEN - KEIN PAAR**
- Aktion: **Passen**

### Mitgehen oder erhöhen

- Titel: **Mitgehen oder erhöhen**
- Erklärung: „Mitgehen kostet <n>. Erhöhe nur, wenn dein Paar stark genug für mehr Risiko ist - höchstens bis <n>.“

### Im Gebot bleiben

- Titel: **Bleibst du dabei?**
- Erklärung: „Mitgehen kostet <n>. Mit Passen behältst du deine übrigen Steine, gibst diesen Topf aber auf.“

### Gegner-Tendenz nach einer sichtbaren Entscheidung

- Titelmuster: **<Name>: Frühe Initiative**, **<Name>: Bedachtes Tempo** oder **<Name>: Wechselndes Tempo**
- Erklärungen:
  - „Steigt in offenen Bietrunden vergleichsweise oft zuerst ein.“
  - „Nimmt sich bei Entscheidungen meist etwas mehr Zeit.“
  - „Entscheidet mal zügig, mal mit etwas mehr Zeit.“
- Fester Zusatz: „Eine Tendenz, kein Versprechen.“

### Einzelne Lektion statt kompletter Runde

- Menü: **Poch lernen**
- Unterzeile: **DEINE ERSTE RUNDE**
- Hero-Titel: **Deine erste Runde**
- Hero-Text: „Du spielst sofort mit. Jeder Schritt zeigt dir genau die Karte oder Taste, die jetzt zählt.“
- Auswahl: **Einzelnen Spielteil üben**
- Einstieg: **Einstieg wählen**
- Lektionen:
  - **Bonus-Töpfe** - „Trumpf erkennen“
  - **Bieten** - „Paar ausspielen“
  - **Karten loswerden** - „passend ablegen“
- Aktion: **Spielteil starten**
- Abschluss einer einzelnen Lektion: **<Lektionsname> geschafft**
- Erklärung: „Stark gespielt. Du kannst direkt weitermachen oder diesen Teil noch einmal üben.“

## Kurze Review-Fragen

1. Versteht ein Mensch ohne Poch-Vorkenntnisse nach jedem Text, warum die Handlung sinnvoll ist?
2. Ist klar, welche Töpfe sofort durch Karten und welcher Topf erst am Rundenende gewonnen wird?
3. Wird „Pochen“ als Entscheidung mit einem Paar verständlich, ohne Regelbuchsprache zu verwenden?
4. Klingt die Sprache nach einem spannenden Kartenspiel und nicht nach einem technischen Ablaufstatus?
5. Sind Handlung, Konsequenz und nächstes Ziel pro Schritt eindeutig?
