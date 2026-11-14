# RULES.md - Regelvertrag für PochCore

Stand: 14.11.2026 · Status: **Entwurf M0, noch nicht final.** Final ist der Vertrag erst, wenn alle Fragen aus Abschnitt 10 entschieden sind.

Dieses Dokument legt fest, wie sich eine Runde Poch in `PochCore` verhält. Grundlage ist `docs/CONCEPT.md` (Kapitel 4 und 5). Solange hier etwas als offen markiert ist, wird es nicht implementiert.

---

## 0. Lesehilfe

### 0.1 Geltungsbereich

- **Enthalten:** der Ablauf einer einzelnen Runde im Klassik-Modus (Abschnitte 2 bis 7) und die vier Bausteine des Modern-Layers: Siegel, Blindpochen, Zunftstrafe, Kette (Abschnitt 8).
- **Nicht enthalten:** der Run-Layer (Tische, Zunftzoll, Edikte, Artefakte, Krämer), die KI, Tells, Bühne und Animation. Berührungspunkte zum Run-Layer stehen als Fragen in Abschnitt 10.4.

### 0.2 Herkunft jeder Regel

Jede Regel trägt eine Kennzeichnung, woher sie stammt:

| Kennzeichen | Bedeutung |
|---|---|
| **[K]** | Steht so im Konzept. |
| **[P]** | Das Konzept schweigt, nennt aber Pagat als Referenz. Die Regel ist von pagat.com übernommen und in Abschnitt 10.5 zur Bestätigung gelistet. |
| **[A]** | Abgeleitet: zwingende Folge anderer Regeln, ohne Spielraum. |
| **[OFFEN F-nn]** | Nicht entschieden. Verweis auf die Frage in Abschnitt 10. |

### 0.3 Regel-IDs

`K-…` sind Klassik-Regeln, `M-…` Regeln des Modern-Layers. Die IDs sind stabil. Jeder Engine-Test nennt die Regel-ID, die er absichert.

### 0.4 Notation

- Farben: Herz ♥, Karo ♦, Pik ♠, Kreuz ♣.
- Ränge aufsteigend: 7, 8, 9, 10, B (Bube), D (Dame), K (König), A (Ass).
- Eine Karte: `♥D` ist die Herz-Dame.
- Sitze im Uhrzeigersinn: **S1** ist die Vorhand (links vom Geber), dann S2, S3 und so weiter. Der letzte Sitz ist der Geber. In den Beispielen sitzen vier Spieler, S4 ist der Geber.

---

## 1. Begriffe

| Begriff | Bedeutung |
|---|---|
| Runde | Ein vollständiger Durchlauf: Einsatz, Geben, Akt I, Akt II, Akt III, Abrechnung. |
| Akt I / II / III | Ernte / Pochen / Lauf. |
| Geber | Der Spieler, der in dieser Runde austeilt. |
| Vorhand | Der Spieler links vom Geber, also der nächste Sitz im Uhrzeigersinn. |
| Zahlkarte | Die eine Karte, die nach dem Geben übrig bleibt und aufgedeckt wird. |
| Zahlfarbe | Die Farbe der Zahlkarte. |
| Mulde | Eines der neun Fächer des Pochbretts, in dem Chips liegen. |
| Ernte-Mulden | Die sieben Mulden Ass, König, Dame, Bube, Zehn, Hochzeit, Folge. |
| Poch-Mulde | Die Mulde, die in Akt II gewonnen wird. Im Konzept auch "Poch-Topf". |
| Mittelmulde | Die Mulde, die in Akt III gewonnen wird. |
| Einsatz | Chips, die ein Spieler in Akt II setzt. |
| Gruppe | Zwei, drei oder vier Karten gleichen Rangs in einer Hand: Paar, Drilling, Vierling. |
| Reihe | Eine Folge aufsteigender Karten derselben Farbe in Akt III. |
| Stopp | Das Ende einer Reihe, weil niemand die nächsthöhere Karte legen kann. |
| Bank | Eine Chipquelle außerhalb von Spielern und Mulden (nur Modern-Layer). |

---

## 2. Material und Aufbau

**K-001 Blatt.** Gespielt wird mit 32 Karten: vier Farben mit je acht Rängen von 7 bis Ass. Die Rangfolge ist 7 < 8 < 9 < 10 < B < D < K < A. **[K]**

**K-002 Spielerzahl.** Drei bis sechs Spieler. Standard sind vier: ein Mensch und drei KI. **[K]**

**K-003 Brett.** Das Brett hat neun Mulden: Ass, König, Dame, Bube, Zehn, Hochzeit, Folge, Poch und Mitte. **[K]**

**K-004 Sitzordnung.** Geben, Bieten und alle Reihenfolgen laufen im Uhrzeigersinn. "Links vom Geber" meint den nächsten Sitz im Uhrzeigersinn. **[P]**

**K-005 Chips.** Chips sind unteilbar. Alle Beträge sind ganze Zahlen. **[A]**

**K-006 Mischen.** Die Kartenreihenfolge ergibt sich allein aus dem Seed. Gleicher Seed und gleiche Aktionen ergeben dieselbe Runde. **[K]**

---

## 3. Rundenbeginn

**K-101 Einsatz in die Mulden.** Vor dem Geben legt jeder Spieler 1 Chip in jede der neun Mulden, also 9 Chips. **[K]**

> Beispiel: Vier Spieler. Jede Mulde wächst um 4 Chips, das Brett insgesamt um 36.

**K-102 Einsatz nicht zahlbar.** Was geschieht, wenn ein Spieler weniger als 9 Chips hat, ist offen. **[OFFEN F-02]**

**K-103 Geben.** Der Geber verteilt die Karten einzeln im Uhrzeigersinn, beginnend bei der Vorhand, bis genau eine Karte übrig ist. **[P]**

**K-104 Handgrößen.** Aus K-103 folgen ungleiche Hände. Die Sitze ab der Vorhand erhalten die Zusatzkarten, der Geber nie. **[A]**

| Spieler | Handgrößen ab Vorhand |
|---|---|
| 3 | 11 / 10 / 10 |
| 4 | 8 / 8 / 8 / 7 |
| 5 | 7 / 6 / 6 / 6 / 6 |
| 6 | 6 / 5 / 5 / 5 / 5 / 5 |

> Beispiel: Vier Spieler. S1, S2 und S3 halten je 8 Karten, der Geber S4 hält 7. Das sind 31 Karten, die 32. ist die Zahlkarte.

**K-105 Zahlkarte.** Die übrig gebliebene Karte wird offen aufgedeckt. Ihre Farbe ist die Zahlfarbe. Die Karte gehört niemandem und wird in keinem Akt gespielt, gezählt oder gewertet. **[K]**

**K-106 Geberwechsel.** Nach jeder Runde wechselt das Geberrecht zum nächsten Sitz im Uhrzeigersinn. **[P]** Wer in der ersten Runde gibt, ist offen. **[OFFEN F-03]**

---

## 4. Akt I - Ernte

**K-201 Einzelkarten-Mulden.** Wer Ass, König, Dame, Bube oder Zehn der Zahlfarbe in der Hand hält, erhält den gesamten Inhalt der gleichnamigen Mulde. **[K]**

> Beispiel: Zahlkarte ♥9, Zahlfarbe Herz. S2 hält ♥A und bekommt die Ass-Mulde.

**K-202 Hochzeit.** Wer König und Dame der Zahlfarbe in derselben Hand hält, erhält die Hochzeit-Mulde, zusätzlich zur König- und zur Dame-Mulde. **[K]**

> Beispiel: Zahlfarbe Herz, erste Runde, in jeder Mulde liegen 4 Chips. S1 hält ♥K und ♥D und bekommt König, Dame und Hochzeit, zusammen 12 Chips.

**K-203 Folge.** Wer 7, 8 und 9 der Zahlfarbe in derselben Hand hält, erhält die Folge-Mulde. **[K]**

**K-204 Geteilter Besitz zählt nicht.** Hält ein Spieler ♥K und ein anderer ♥D, gewinnt niemand die Hochzeit. Dasselbe gilt für eine auf mehrere Hände verteilte 7-8-9. **[A]**

**K-205 Die Zahlkarte sperrt ihre Mulde.** Ist die Zahlkarte selbst Ass, König, Dame, Bube oder Zehn, kann die gleichnamige Mulde in dieser Runde niemand gewinnen. **[A]** aus K-105.

> Beispiel: Zahlkarte ♥B. Den Herz-Buben hält niemand, die Bube-Mulde bleibt liegen.

**K-206 Die Zahlkarte sperrt die Hochzeit.** Ist die Zahlkarte König oder Dame, ist die Hochzeit in dieser Runde nicht gewinnbar. **[A]**

**K-207 Die Zahlkarte sperrt die Folge.** Ist die Zahlkarte eine 7, 8 oder 9, ist die Folge in dieser Runde nicht gewinnbar. **[A]**

> Beispiel zu K-205 bis K-207: Zahlkarte ♥K. König-Mulde und Hochzeit bleiben liegen. Die Dame-Mulde ist weiterhin gewinnbar.

**K-208 Liegen gebliebene Mulden.** Eine nicht gewonnene Mulde behält ihren Inhalt. Mit dem Einsatz der nächsten Runde wächst sie weiter. **[K]**

> Beispiel: Die Folge-Mulde wird drei Runden lang nicht gewonnen. Bei vier Spielern liegen nach dem Einsatz der vierten Runde 16 Chips darin.

**K-209 Keine Entscheidung.** Im Klassik-Modus trifft in Akt I niemand eine Entscheidung. Die Auszahlung folgt allein aus Händen und Zahlkarte. **[K]**

**K-210 Poch und Mitte.** Poch-Mulde und Mittelmulde werden in Akt I nicht ausgezahlt. **[K]**

**K-211 Reihenfolge der Auszahlungen.** Jede Ernte-Mulde hat höchstens einen Gewinner, die Reihenfolge ändert also keine Chipstände. In welcher Reihenfolge die Engine die Auszahlungs-Events ausgibt, ist offen. **[OFFEN F-08]**

---

## 5. Akt II - Pochen

### 5.1 Gruppen und ihr Vergleich

**K-301 Gruppe.** Gewertet werden nur Paar, Drilling und Vierling: zwei, drei oder vier Karten gleichen Rangs. Die Farben spielen für das Vorliegen einer Gruppe keine Rolle. **[K]**

**K-302 Größe schlägt Rang.** Vierling schlägt Drilling, Drilling schlägt Paar, unabhängig vom Rang. **[K]**

> Beispiel: S1 hält ♣7 ♦7 ♠7, S2 hält ♥A ♠A. Der Siebener-Drilling von S1 gewinnt.

**K-303 Bei gleicher Größe zählt der Rang.** Die Gruppe aus den höheren Karten gewinnt. **[K]**

> Beispiel: Paar Dame schlägt Paar Zehn.

**K-304 Nur die beste Gruppe.** Von jeder Hand zählt allein die beste Gruppe. Zwei Paare zählen als das höhere Paar. Drilling plus Paar zählt als Drilling. **[K]**, Einzelfälle **[P]**.

> Beispiel: ♠K ♣K ♦9 ♥9 zählt als Paar König. ♠8 ♣8 ♦8 ♥B ♠B zählt als Drilling Acht.

**K-305 Gleiche Größe, gleicher Rang.** Es gewinnt die Gruppe, die die Karte der Zahlfarbe enthält. **[K]**, deckungsgleich mit Pagat.

> Beispiel: Zahlfarbe Herz. S1 hält ♥D ♠D, S3 hält ♦D ♣D. S1 gewinnt.

**K-306 Zweite Gleichstandsstufe.** Das Konzept nennt als zweite Stufe "wer näher links vom Geber sitzt" und markiert sie selbst als zu prüfen. Im Klassik-Modus ist diese Stufe nie erreichbar (Begründung bei F-01). Ob sie im Vertrag bleibt, ist offen. **[OFFEN F-01]**

### 5.2 Teilnahme und Ablauf

**K-307 Teilnahme nur mit Gruppe.** Im Klassik-Modus darf nur pochen, wer mindestens ein Paar hält. Das gilt für Eröffnen, Mitgehen und Erhöhen. Ohne Gruppe bleibt nur Passen. **[K]**

**K-308 Reihenfolge.** Die Vorhand ist zuerst am Zug, danach geht es im Uhrzeigersinn weiter. **[P]**

**K-309 Aktionen.** Wer am Zug ist, kann passen, eröffnen (als Erster einen Einsatz bringen), mitgehen (den höchsten Einsatz ausgleichen) oder erhöhen (den höchsten Einsatz überbieten). **[K]**

**K-310 Einsatzgrenzen.** Das Konzept legt fest: kein Side-Pot, Einsätze sind durch den eigenen Chipstand gedeckelt. Mindesteinsatz, Erhöhungsschritt, Obergrenze und der Fall, dass ein Spieler nicht ausgleichen kann, sind offen. **[OFFEN F-04]**

**K-311 Gesetzte Chips bleiben.** Wer nach einem eigenen Einsatz passt, bekommt seine gesetzten Chips nicht zurück. Sie gehen an den Gewinner von Akt II. **[P]**, im Konzept als "plus Einsätze" angelegt.

**K-312 Passen.** Ob Passen endgültig ist oder ein Spieler nach einem frühen Passen wieder einsteigen darf, ist offen. **[OFFEN F-05]**

### 5.3 Ende von Akt II

**K-313 Alle passen.** Bringt niemand einen Einsatz, gewinnt niemand. Die Poch-Mulde bleibt liegen und wächst mit dem Einsatz der nächsten Runde. **[K]**

> Beispiel: In der Poch-Mulde liegen 4 Chips, alle vier passen. In der nächsten Runde liegen nach dem Einsatz 8 Chips darin.

**K-314 Alle bis auf einen passen.** Bleibt nach mindestens einem Einsatz nur ein Spieler übrig, gewinnt er die Poch-Mulde und alle Einsätze, ohne seine Karten zu zeigen. **[K]**

> Beispiel: Poch-Mulde 4. S1 eröffnet mit 2, S2, S3 und S4 passen. S1 erhält 4 aus der Mulde und seine 2 zurück. Niemand sieht seine Hand.

Hinweis: Pagat verlangt hier das Vorzeigen eines Paars. Das Konzept weicht bewusst ab. Im Klassik-Modus garantiert K-307 ohnehin, dass der Gewinner eine Gruppe hält.

**K-315 Showdown.** Bleiben mehrere Spieler und sind ihre Einsätze ausgeglichen, decken sie ihre beste Gruppe auf. Die beste Gruppe nach K-302 bis K-305 gewinnt die Poch-Mulde und alle Einsätze, auch die der ausgestiegenen Spieler. **[K]**

> Beispiel: Poch-Mulde 4. S1 eröffnet mit 2, S2 geht mit, S3 erhöht auf 5, S4 passt, S1 passt und verliert seine 2, S2 zahlt 3 nach. Showdown zwischen S2 und S3. Der Gewinner erhält 2 + 5 + 5 = 12 Chips Einsätze und 4 aus der Mulde.

**K-316 Folge für Akt III.** Der Gewinner von Akt II eröffnet Akt III. **[K]**

---

## 6. Akt III - Lauf

**K-401 Eröffnung.** Den Lauf eröffnet der Gewinner von Akt II. Haben dort alle gepasst, eröffnet die Vorhand. **[K]**

**K-402 Erste Karte.** Der Eröffner legt eine beliebige Karte aus seiner Hand. **[K]**

**K-403 Fortsetzung.** Danach muss die nächsthöhere Karte derselben Farbe gelegt werden, von wem auch immer sie gehalten wird. Das kann derselbe Spieler sein, der die vorige Karte gelegt hat. **[K]**

> Beispiel: S1 legt ♠9. S3 hält ♠10 und muss sie legen. S1 hält ♠B und muss sie legen.

**K-404 Stopp.** Eine Reihe endet, wenn niemand die nächsthöhere Karte legen kann. Dafür gibt es genau drei Gründe **[A]**:

- **(a) Ass erreicht.** Über dem Ass gibt es keine Karte.
  > Beispiel: S1 legt ♠K, S3 legt ♠A. Stopp.
- **(b) Die nächste Karte ist die Zahlkarte.**
  > Beispiel: Zahlkarte ♥10. S2 legt ♥8, S4 legt ♥9. Die ♥10 liegt offen auf dem Tisch. Stopp.
- **(c) Die nächste Karte wurde in dieser Runde schon gespielt.**
  > Beispiel: Zuvor lief die Reihe ♦9, ♦10, ♦B. Später eröffnet S1 mit ♦7, S2 legt ♦8. Die ♦9 ist bereits gespielt. Stopp.

Weitere Gründe gibt es nicht: Jede Karte ist entweder in einer Hand, die Zahlkarte oder gespielt.

**K-405 Nach dem Stopp.** Wer die letzte Karte der Reihe gelegt hat, eröffnet eine neue Reihe mit einer beliebigen Karte. **[K]**

**K-406 Rundenende.** Sobald ein Spieler seine letzte Karte gelegt hat, endet der Lauf sofort, auch mitten in einer Reihe. Es wird nichts nachgespielt. **[K]**, Sofortigkeit **[A]**.

> Beispiel: S3 hält nur noch ♣D. S1 eröffnet mit ♣B, S3 muss ♣D legen und ist damit fertig. S2 hält ♣K und legt ihn nicht mehr.

**K-407 Letzte Karte als Eröffnung.** Eröffnet ein Spieler mit seiner letzten Karte, gewinnt er damit sofort. **[A]**

**K-408 Gewinn.** Wer zuerst keine Karten mehr hat, erhält die Mittelmulde und von jedem Gegner 1 Chip pro Karte, die dieser noch hält. **[K]**

> Beispiel: S3 gewinnt. Mittelmulde 4 Chips. S1 hält noch 3 Karten, S2 eine, S4 vier. S3 erhält 4 + 3 + 1 + 4 = 12 Chips.

**K-409 Restkarten nicht zahlbar.** Was geschieht, wenn ein Gegner weniger Chips als Restkarten hat, ist offen. **[OFFEN F-06]**

**K-410 Zwangszug in der Engine.** Ob die Fortsetzung nach K-403 von der Engine selbst ausgeführt wird oder eine eigene Aktion des Karteninhabers ist, ist offen. **[OFFEN F-07]**

**K-411 Der Lauf endet immer.** Jeder Zug entfernt eine Karte aus einer Hand, und der Eröffner hat stets mindestens eine Karte. Nach höchstens 31 Zügen ist eine Hand leer. **[A]**

**K-412 Die Mittelmulde wird jede Runde gewonnen.** Aus K-411 folgt: Im Klassik-Modus bleibt in der Mittelmulde nie etwas liegen. **[A]**

---

## 7. Abrechnung und Chip-Bilanz

**K-501 Rundenablauf.** Die Schritte einer Runde in fester Reihenfolge **[K]**:

1. Einsatz in die Mulden (K-101)
2. Geben (K-103)
3. Zahlkarte aufdecken (K-105)
4. Akt I Ernte
5. Akt II Pochen
6. Akt III Lauf
7. Auszahlung von Mittelmulde und Restkarten (K-408)

Im Modern-Layer verschiebt sich Schritt 3 hinter das Siegeln (M-101).

**K-502 Chip-Erhaltung.** Im Klassik-Modus ist die Summe aus allen Spielerständen, allen Mulden und allen laufenden Einsätzen nach jeder Aktion gleich. Jeder Engine-Test prüft das. **[K]**

**K-503 Übertrag.** Was nach Schritt 7 in den Mulden liegt, bleibt für die nächste Runde liegen. Betroffen sein können die sieben Ernte-Mulden und die Poch-Mulde. **[K]**

**K-504 Ende einer Klassik-Partie.** Wann eine freie Partie im Klassik-Modus endet und wer sie gewinnt, ist offen. **[OFFEN F-09]**

---

## 8. Modern-Layer

**M-001 Aktivierung.** Der Modern-Layer ist im Run-Modus aktiv und im Klassik-Modus aus. **[K]**

**M-002 Klassik bleibt die Basis.** Alle Regeln aus den Abschnitten 2 bis 7 gelten weiter, soweit eine M-Regel sie nicht ausdrücklich ändert. **[A]**

**M-003 Geltung für KI-Sitze.** Für das Siegel legt das Konzept fest, dass auch die KI siegelt. Ob Blindpochen und Kette ebenfalls für alle Sitze gelten, ist offen. **[OFFEN F-10]**

### 8.1 Siegel (Akt I)

**M-101 Zeitpunkt.** Gesiegelt wird nach dem Geben und vor dem Aufdecken der Zahlkarte. Jeder Spieler kennt seine Hand, die Zahlfarbe ist noch unbekannt. **[K]**

**M-102 Ziel.** Ein Spieler setzt sein Siegel auf genau eine der sieben Ernte-Mulden. Poch und Mitte sind nicht siegelbar. **[K]**

**M-103 Pflicht und Kosten.** Ob das Siegeln Pflicht ist und was es zum Start kostet, ist offen. **[OFFEN F-11]**

**M-104 Reihenfolge und Sichtbarkeit.** Die Siegel der KI sind offen sichtbar. Ob man sie vor der eigenen Wahl sieht und ob mehrere Spieler dieselbe Mulde siegeln dürfen, ist offen. **[OFFEN F-12]**

**M-105 Aufdecken und Ernte.** Nach dem Siegeln wird die Zahlkarte aufgedeckt. Danach läuft die Ernte automatisch nach Abschnitt 4. **[K]**

**M-106 Treffer.** Gewinnt ein Spieler genau die Mulde, auf der sein Siegel liegt, wird die Auszahlung verdoppelt. Der Muldeninhalt kommt aus der Mulde, derselbe Betrag zusätzlich aus der Bank. Die Gegner zahlen nichts. **[K]**

> Beispiel: In der Dame-Mulde liegen 8 Chips. Du hast Dame gesiegelt, die Zahlfarbe wird Herz, du hältst ♥D. Du erhältst 8 Chips aus der Mulde und 8 aus der Bank.

**M-107 Genau diese Mulde.** Der Bonus gilt nur für die gesiegelte Mulde, nicht für weitere Mulden, die derselbe Spieler in dieser Runde gewinnt. **[A]**

> Beispiel: Du siegelst Hochzeit und hältst ♥K und ♥D, Zahlfarbe Herz, in jeder Mulde liegen 4 Chips. König 4, Dame 4, Hochzeit 4 plus 4 Bonus. Zusammen 16 Chips.

**M-108 Fehlgriff.** Liegt das Siegel auf einer Mulde, die der Spieler nicht gewinnt, hat es keine Wirkung. **[A]**

**M-109 Lebensdauer.** Ein Siegel gilt für eine Runde und verfällt danach. **[A]**

### 8.2 Blindpochen und Zunftstrafe (Akt II)

**M-201 Pochen ohne Gruppe.** Im Run-Modus darf ein Spieler auch ohne Gruppe pochen. M-201 hebt K-307 auf. **[K]**

**M-202 Bluff gelungen.** Passen alle anderen, gewinnt der Spieler nach K-314, ohne aufzudecken. Ob er eine Gruppe hatte, erfährt niemand. **[K]**

**M-203 Gruppe schlägt keine Gruppe.** Im Showdown verliert eine Hand ohne Gruppe gegen jede Hand mit Gruppe. **[A]**

**M-204 Zunftstrafe.** Kommt es zum Showdown und ein Teilnehmer hat keine Gruppe, verliert er seinen Einsatz und zahlt denselben Betrag zusätzlich in den Poch-Topf. **[K]**

> Beispiel: Poch-Mulde 4. Du hältst keine Gruppe und eröffnest mit 3. S2 geht mit einem Paar Neun mit, S3 und S4 passen. Showdown: S2 gewinnt die Einsätze (6) und die Mulde (4). Du hast deine 3 verloren und zahlst 3 weitere Chips Strafe.

**M-205 Einzelheiten der Zunftstrafe.** Wohin die Strafe fließt, was bei fehlenden Chips gilt und wie "Einsatz" genau bemessen wird, ist offen. **[OFFEN F-13]**

**M-206 Showdown ohne jede Gruppe.** Was gilt, wenn kein Teilnehmer des Showdowns eine Gruppe hat, ist offen. **[OFFEN F-14]**

### 8.3 Kette (Akt III)

**M-301 Zählung.** Jede Karte, die ein Spieler legt, während die Reihe läuft, erhöht seine Kette um 1. **[K]**

**M-302 Eigener Stopp.** Löst ein Spieler einen Stopp aus, weil seine Karte die letzte der Reihe war, erhöht sich seine Kette um 1, und er eröffnet nach K-405. **[K]**

**M-303 Kettenbonus.** Am Rundenende erhält der Spieler einen Bonus in Höhe seiner längsten Kette mal Faktor. Der Startwert des Faktors ist 1 Chip pro Glied und gehört in die zentrale Config. **[K]**

**M-304 Zählweise im Einzelnen.** Wann eine Kette abbricht, ob die Eröffnungskarte zählt und ob eine Kette über mehrere Reihen weiterläuft, ist offen. **[OFFEN F-15]**

**M-305 Quelle und Empfänger des Bonus.** Wer den Kettenbonus zahlt und wer ihn bekommt, ist offen. **[OFFEN F-16]**

### 8.4 Bank und Bilanz

**M-401 Bank.** Der Siegel-Bonus kommt aus der Bank (M-106). Damit ist das System aus Spielern und Mulden im Run-Modus nicht mehr geschlossen. Wie die Chip-Erhaltung aus K-502 mit Bank formuliert wird, ist offen. **[OFFEN F-17]**

---

## 9. Abweichungen zwischen altem Code und Konzept

Geprüft am 14.11.2026 gegen `legacy/PochKit/Sources/PochKit` (13 Dateien, vollständig gelesen). Pfade in der Spalte "Beleg" sind relativ zu diesem Ordner.

### 9.1 Abweichungen

| Nr | Thema | Konzept | Alter Code | Beleg |
|---|---|---|---|---|
| A-01 | Engine-Vertrag | Einziger Weg ist `apply(state:action:) throws -> Transition`. | Einsatz, Geben und Ernte laufen im Initializer von `Round`. Danach zwei mutierende Methoden. | `Round.swift:41-79`, `:99`, `:129` |
| A-02 | Entscheidung in Akt I | Run-Modus: Siegel vor dem Aufdecken der Zahlkarte. | Keine Entscheidung. Die Zahlkarte ist mit dem Geben bekannt, die Ernte folgt sofort. | `Round.swift:3`, `:59-69` |
| A-03 | Siegel | Vorhanden (Kapitel 5). | Nicht vorhanden. | Suche in 9.3 |
| A-04 | Obergrenze der Einsätze | "Durch den eigenen Chipstand gedeckelt." | Deckel ist der kleinste Gesamtstand aller bietberechtigten aktiven Spieler. Er wird nach jedem Passen neu berechnet. | `Betting.swift:75-80` |
| A-05 | Höhe der Einsätze | "Jedes weitere Klopfen erhöht um eine Stufe." | Frei wählbar: Eröffnung von 1 bis Deckel, Erhöhung von aktuellem Gebot plus 1 bis Deckel. | `Betting.swift:91-104` |
| A-06 | Pochen ohne Gruppe | Run-Modus: erlaubt (Blindpochen). | Immer verboten. Ohne Paar ist nur Passen legal. | `Betting.swift:37-45`, `:87-89` |
| A-07 | Showdown ohne Gruppe | Zunftstrafe. | Nicht vorgesehen. Die Engine bricht mit `preconditionFailure` ab. | `Betting.swift:183-185` |
| A-08 | Zweite Gleichstandsstufe | "Wer näher links vom Geber sitzt." | Keine solche Regel. Der Fall gilt als unmöglich. Schlägt niemand den ersten Teilnehmer, bleibt dieser vorn. | `Combos.swift:16-24`, `Betting.swift:186-194` |
| A-09 | Zwangszug | "Muss gelegt werden", im Schnellmodus automatisch. | Die Engine spielt die ganze Reihe selbst. Nur die Eröffnung ist eine Aktion. | `Playout.swift:55-66`, `:68-88` |
| A-10 | Kette und Kettenbonus | Vorhanden (Kapitel 5). | Nicht vorhanden. Ein Zug kennt nur Spieler, Karte und ob er Eröffnung war. | `Playout.swift:13-17` |
| A-11 | Bank | Siegel-Bonus kommt aus der Bank. | Geschlossenes System: Spielerstände plus Brett. | `Round.swift:167-174` |
| A-12 | Aufbau einer Partie | Tisch mit 3 Runden und Zunftzoll, Run mit 9 Tischen. | Partie mit den Modi `classic` und `quick(roundLimit:)`. | `Match.swift:7-10` |
| A-13 | Tells | "Ehrlich", also aus dem Verhalten lernbar. | Bewusst unabhängig von der Hand. Die Funktion bekommt die Karten nicht. | `Tell.swift:1-5`, `:40-41` |
| A-14 | Begriffe | Zahlfarbe, Hochzeit, Folge, Akt. | `trump`, `mariage`, `sequence`, Phase. | `Dealing.swift:9`, `Board.swift:2-6` |

### 9.2 Wo der alte Code etwas regelt, das im Konzept fehlt

Diese Punkte sind im Konzept nicht entschieden. Der alte Code zeigt eine mögliche Lösung. Sie stehen alle als Frage in Abschnitt 10.

| Nr | Thema | Alter Code | Beleg | Frage |
|---|---|---|---|---|
| B-01 | Einsatz nicht zahlbar | Spieler scheidet vor dem Geben aus und behält seine Restchips. Unter drei Spielern endet die Partie. | `Match.swift:64-72` | F-02 |
| B-02 | Geberwechsel | Rotation im Uhrzeigersinn über die verbliebenen Spieler. | `Match.swift:100-104` | F-03 |
| B-03 | Passen | Endgültig, auch vor der ersten Eröffnung. Es gibt kein Abwarten. | `Betting.swift:9`, `:113-114` | F-05 |
| B-04 | Spieler ohne Chips nach dem Einsatz | Kann in Akt II nur passen und senkt den Deckel nicht. | `Betting.swift:40-45` | F-04 |
| B-05 | Restkarten nicht zahlbar | Zahlung höchstens bis Stand 0, keine Schulden. | `Round.swift:142-151` | F-06 |
| B-06 | Reihenfolge der Ernte | Ab Vorhand reihum, je Spieler in Brettreihenfolge. | `Melding.swift:31-33`, `Round.swift:62-69` | F-08 |
| B-07 | Ende und Wertung der Partie | Meiste Chips gewinnen. Bei Gleichstand zählen gewonnene Läufe, danach geteilter Sieg. | `Match.swift:107-115` | F-09 |

### 9.3 Übereinstimmungen und Suche

- **Deckungsgleich** mit dem Konzept sind: 32 Karten und 3 bis 6 Spieler (`Cards.swift:24-28`, `Dealing.swift:12`), 1 Chip pro Mulde (`Board.swift:35-39`), die sieben Ernte-Bedingungen (`Melding.swift:10-22`), die Rangfolge der Gruppen mit Zahlfarbe als Entscheider (`Combos.swift:20-24`), Sieg ohne Aufdecken (`Betting.swift:18`), die Eröffnung des Laufs (`Round.swift:119-123`) und das sofortige Rundenende (`Playout.swift:61-64`, `:80-83`).
- **Suche nach Modern-Layer-Begriffen** (Siegel, Blindpochen, Zunftstrafe, Kettenbonus, Multiplikator, deutsch und englisch) über alle Quelldateien: 5 Treffer, alle für das Wort "Kette" im Sinn der Zwangszug-Reihe (`Playout.swift:3`, `:5`, `:53`, `:74`, `Round.swift:127`). Kein Baustein des Modern-Layers ist im alten Code angelegt.
- Die alte Spec (`legacy/tasks/poch-spec.md`, Abschnitt 3) beschreibt drei Hausregel-Schalter (Sequenz-Variante, Pochen ohne Paar, Jackpot-Finale). Laut derselben Spec wurden sie nie gebaut. Das Konzept kennt sie nicht.

---

## 10. Offene Fragen

Nichts in diesem Abschnitt ist entschieden. Jede Frage nennt, was Konzept, Pagat und alter Code dazu sagen. Die Zeile "Empfehlung" ist ein unverbindlicher Vorschlag.

Pagat-Zitate stammen von `pagat.com/stops/poch.html`, abgerufen am 14.11.2026.

### 10.1 Klassik

**F-01 Zweite Gleichstandsstufe im Showdown**
- Konzept: "Gleiche Gruppe, gleicher Rang: Gruppe mit Karte der Zahlfarbe gewinnt. Sonst gewinnt, wer näher links vom Geber sitzt. *(gegen Pagat verifizieren)*"
- Pagat: kennt nur die erste Stufe. "If two players have pairs of the same rank, the pair containing the card of the pay suit is better." Eine Sitzregel gibt es dort nicht.
- Befund: Im Klassik-Modus ist die zweite Stufe nie erreichbar. Zwei Paare gleichen Rangs in zwei Händen brauchen alle vier Karten dieses Rangs. Eine davon hat die Zahlfarbe und liegt in genau einem der Paare. Ist die Zahlkarte selbst von diesem Rang, sind nur drei Karten im Spiel und zwei Paare unmöglich. Zwei Drillinge oder Vierlinge gleichen Rangs gibt es bei vier Karten je Rang nicht.
- Erreichbar wird ein Gleichstand erst im Modern-Layer (siehe F-14) oder durch Artefakte.
- Optionen: (a) Stufe im Klassik-Vertrag streichen. (b) Als formale Rückfallregel behalten.
- Empfehlung: (a). Die Regel für den Modern-Layer wird in F-14 entschieden.

**F-02 Einsatz in die Mulden nicht zahlbar**
- Konzept: schweigt. Im Run ist der Chipstand "Leben".
- Pagat: Das Spiel endet meist, wenn jemand die 9 Chips nicht mehr aufbringt.
- Alter Code: Der Spieler scheidet vor dem Geben aus (B-01).
- Optionen: (a) Der Spieler scheidet aus, die Runde läuft ohne ihn. (b) Die Partie oder der Tisch endet sofort. (c) Er zahlt, was er hat, und spielt mit.
- Empfehlung: getrennt nach Modus entscheiden. Im Run liegt (b) nahe, weil dort der Mensch der einzige zählende Spieler ist.

**F-03 Erster Geber**
- Konzept: schweigt.
- Pagat: "The first dealer is chosen at random and the turn to deal passes to the left after each hand."
- Alter Code: Erster Geber ist ein Parameter, Standard Sitz 0.
- Optionen: (a) Aus dem Seed bestimmt. (b) Fest, zum Beispiel sitzt der Mensch in Runde 1 als Vorhand. (c) Im Run je Tisch neu bestimmt.
- Hinweis: Der Sitz zum Geber entscheidet über Handgröße (K-104) und Zugreihenfolge. Bei 3 Runden pro Tisch und 4 Spielern gibt nicht jeder einmal.

**F-04 Einsatzregeln im Pochen**
- Konzept: "Kein Side-Pot-System in v1: Einsätze sind durch den eigenen Chipstand gedeckelt." Dazu: "Jedes weitere Klopfen erhöht um eine Stufe." Das Edikt "Straßburger Verbot" nennt "Max. Erhöhung 3 Chips".
- Pagat: "I have not seen explicit rules about betting limits or what happens when players do not have enough chips to equal another player's bet."
- Alter Code: Freie Beträge ab 1, Deckel ist der kleinste Stand der bietberechtigten Spieler (A-04, A-05).
- Zu entscheiden:
  1. Mindesteinsatz bei der Eröffnung.
  2. Größe einer "Stufe" beim Erhöhen und ob nur stufenweise erhöht wird.
  3. Obergrenze pro Erhöhung und Zahl der Erhöhungen ohne Edikt.
  4. Was gilt, wenn ein Spieler den höchsten Einsatz nicht ausgleichen kann. Nach dem Wortlaut des Konzepts könnte ein reicher Spieler einen armen aus dem Topf bieten. Der alte Code verhindert das über den gemeinsamen Deckel.
  5. Ob ein Spieler ohne Chips nach dem Einsatz in die Mulden nur passen kann.
- Empfehlung: Punkt 4 zuerst klären, er bestimmt die übrigen. Der gemeinsame Deckel des alten Codes ist die einfachste Lösung ohne Side-Pot und ist dort getestet.

**F-05 Ist Passen endgültig**
- Konzept: schweigt.
- Pagat: uneindeutig. Vor dem ersten Einsatz "pass", danach "drop out (fold)".
- Alter Code: endgültig, auch vor der ersten Eröffnung (B-03).
- Optionen: (a) Passen ist immer endgültig. (b) Wer vor der ersten Eröffnung passt, darf nach einer Eröffnung noch mitgehen.
- Empfehlung: (a). Kürzere Runden und klarere Zustände.

**F-06 Restkarten nicht zahlbar**
- Konzept: schweigt.
- Pagat: schweigt.
- Alter Code: Zahlung bis Stand 0, keine Schulden (B-05).
- Optionen: (a) Zahlung höchstens bis Stand 0. (b) Schulden sind möglich. (c) Der Fehlbetrag kommt aus der Bank.
- Empfehlung: (a). Passt zu "kein Side-Pot" und hält die Bilanz geschlossen.

**F-07 Zwangszug: automatisch oder Aktion**
- Konzept: "Danach muss die nächsthöhere Karte derselben Farbe gelegt werden." Und: "Erzwungene Züge (nur eine legale Karte) werden im Schnellmodus automatisch gespielt."
- Alter Code: Die Engine spielt die Reihe selbst (A-09).
- Optionen: (a) Die Engine führt Zwangszüge selbst aus und meldet sie als Events. Die Bühne entscheidet, ob der Mensch die Karte antippt. (b) Jeder Zwangszug ist eine eigene Aktion des Halters.
- Hinweis: Das Artefakt "Ärmel des Flussspielers" hält eine Karte zurück und braucht bei (a) eine Sonderbehandlung.
- Empfehlung: (a). Ohne Wahlmöglichkeit ist eine Aktion nur Zeremonie, und Architektur-Regel 7 in `CLAUDE.md` verlangt dieselben Events mit und ohne Animation.

**F-08 Reihenfolge der Ernte-Events**
- Konzept: schweigt. Chipstände hängen nicht davon ab.
- Alter Code: ab Vorhand reihum, je Spieler in Brettreihenfolge (B-06).
- Optionen: (a) Wie alter Code. (b) In Brettreihenfolge der Mulden, unabhängig vom Sitz.
- Empfehlung: (b). Die Bühne zeigt in Akt I das Brett, eine Runde über die Mulden ist leichter zu lesen.

**F-09 Ende einer Klassik-Partie**
- Konzept: "Pures Poch ohne Modern-Layer, freie Partie gegen 3 KI." Kein Endkriterium.
- Pagat: Ende, wenn jemand die 9 Chips nicht mehr hat. Die meisten Chips gewinnen. "Any unclaimed chips on the board remain there and are not won by anybody."
- Alter Code: zwei Modi, Wertung nach Chips, dann nach gewonnenen Läufen (B-07).
- Zu entscheiden: Endkriterium, Wertung bei Gleichstand, Verbleib der Chips in den Mulden.

**F-18 Blindpochen als Hausregel im Klassik-Modus**
- Konzept, Kapitel 12: als offene Entscheidung geführt.
- Pagat nennt die Variante: "Some play that it is possible to take part in the Pochen without even a pair of matching cards. If none of the players in the showdown has even a pair, the highest single card wins."
- Hängt an F-13 und F-14.

### 10.2 Modern-Layer

**F-10 Gelten Blindpochen und Kette für alle Sitze**
- Konzept: Siegel ausdrücklich auch für die KI. Für Kette steht "jede Karte, die **du** legst". Der Strategie-Vektor der Gegner enthält "Bluffneigung".
- Optionen: (a) Alle drei Bausteine gelten für alle Sitze gleich. (b) Kettenbonus nur für den Menschen. (c) Blindpochen und Kettenbonus nur für den Menschen.
- Hinweis: Bei (b) und (c) fließen Bank-Chips nur zum Menschen. Das verschiebt das Balancing des Zunftzolls.

**F-11 Siegel: Pflicht und Kosten**
- Konzept: "Du setzt dein Siegel auf eine der 7 Ernte-Mulden." Als Tuning-Hebel genannt: "Multiplikator, Siegel-Kosten, mehrere Siegel durch Artefakte."
- Zu entscheiden: Muss jeder siegeln oder darf man verzichten. Startwert der Kosten (naheliegend 0). Wohin Kosten fließen, falls es welche gibt.

**F-12 Siegel: Reihenfolge und Sichtbarkeit**
- Konzept: "KI-Gegner siegeln ebenfalls und offen - das verrät etwas über ihre Hände." Das Artefakt "Spiegel des Salons" lässt dich ein gegnerisches Siegel sehen, "bevor du siegelst".
- Befund: Das Artefakt hat nur einen Wert, wenn man die Siegel der Gegner normalerweise erst nach der eigenen Wahl sieht.
- Optionen: (a) Alle wählen verdeckt, dann werden alle Siegel zugleich aufgedeckt. (b) Reihum offen ab Vorhand.
- Zusatzfrage: Dürfen mehrere Spieler dieselbe Mulde siegeln. Gewinnen kann sie ohnehin nur einer.
- Empfehlung: (a), mehrfaches Siegeln derselben Mulde erlaubt.

**F-13 Zunftstrafe im Einzelnen**
- Konzept: "Einsatz weg, zusätzlich zahlst du den Einsatz noch einmal in den Poch-Topf."
- Zu entscheiden:
  1. Bezugsgröße: der gesamte Einsatz des Spielers in diesem Akt II.
  2. Ziel der Strafe: Sie geht mit an den Gewinner dieses Showdowns, oder sie bleibt in der Poch-Mulde für die nächste Runde liegen.
  3. Der Spieler hat nicht genug Chips für die Strafe.
  4. Gilt die Strafe auch, wenn der Spieler ohne Gruppe nur mitgegangen ist, statt selbst zu eröffnen.
- Hinweis zu 2: Bleibt die Strafe in der Mulde, entsteht ein wachsender Topf für die Folgerunde, ähnlich den liegen gebliebenen Ernte-Mulden.

**F-14 Showdown, in dem niemand eine Gruppe hat**
- Konzept: nicht geregelt. Möglich, sobald zwei Spieler blind pochen.
- Pagat (Variante): höchste Einzelkarte gewinnt, Gleichstand nach fester Farbrangfolge.
- Optionen: (a) Alle zahlen Zunftstrafe, niemand gewinnt, alles bleibt in der Poch-Mulde. (b) Höchste Einzelkarte gewinnt, bei gleichem Rang die Zahlfarbe, sonst der Sitz näher an der Vorhand. Die Verlierer zahlen Strafe. (c) Wie (b), aber ohne Strafe.
- Hinweis: Hier wäre die Sitzregel aus F-01 erstmals erreichbar.

**F-15 Kette: Zählweise**
- Konzept: "Jede Karte, die du legst, während die Reihe läuft, erhöht deine Kette um 1. Ein Stopp, den du auslöst (deine Karte war die letzte): Kette +1 und du eröffnest. Rundenende: Kettenbonus = längste eigene Kette × Faktor."
- Unklar: "Längste" setzt voraus, dass eine Kette abbricht. Wann, steht nicht da.
- Beispiel zur Unterscheidung: Du hältst unter anderem ♥7, ♥8, ♥10 und ♠A, S2 hält ♥9, die ♥B ist die Zahlkarte. Du eröffnest ♥7, legst ♥8, S2 legt ♥9, du legst ♥10 und löst den Stopp aus. Dann eröffnest du ♠A und löst wieder einen Stopp aus.
  - Lesart A, eine fremde Karte bricht die Kette: nach ♥8 steht sie bei 2, S2 unterbricht. Neue Kette mit ♥10.
  - Lesart B, die Kette zählt alle eigenen Karten einer Reihe und endet mit der Reihe: ♥7, ♥8, ♥10 ergeben 3.
  - Lesart C, die Kette läuft weiter, solange du jede Reihe selbst beendest: ♥7, ♥8, ♥10 und ♠A hängen zusammen.
- Zu entscheiden: Lesart A, B oder C. Zählt die Eröffnungskarte mit. Zählt der eigene Stopp als zusätzliches Glied neben der Karte, die ihn auslöst.

**F-16 Kettenbonus: Quelle, Empfänger, Schwelle**
- Konzept: nennt nur die Höhe.
- Zu entscheiden: Kommt der Bonus aus der Bank wie beim Siegel. Bekommt ihn jeder Spieler oder nur der Sieger des Laufs (hängt an F-10). Gibt es eine Mindestlänge. Ohne Schwelle erhält jeder, der eine Karte legt, mindestens 1 Chip.

**F-17 Bank und Chip-Erhaltung**
- Konzept: Kapitel 10, harte Regel 5 verlangt, dass Chips bilanzerhaltend sind. Zugleich kommt der Siegel-Bonus "aus der Bank".
- Zu entscheiden: Die Bank wird als eigenes Konto geführt, das ins Minus gehen darf, und die Invariante lautet "Spieler plus Mulden plus Einsätze plus Bank ist konstant". Oder die Bank ist eine unbegrenzte Quelle, und die Invariante wird als Buchungsregel formuliert: Jeder Chip hat eine Herkunft und ein Ziel.
- Empfehlung: Bank als Konto. Dann bleibt ein einziger Summen-Test für beide Modi gültig, und PochSim kann den Bank-Abfluss pro Run direkt ausweisen.

### 10.3 Bereits im Konzept als offen geführt

Kapitel 12 des Konzepts listet sieben offene Entscheidungen. Für den Regelvertrag relevant sind zwei: der Gleichstand im Showdown (hier F-01 und F-14) und Blindpochen im Klassik-Modus (hier F-18).

### 10.4 Vorgemerkt für den Run-Layer (M2)

Diese Punkte gehören nicht zu M0, berühren aber die Runde:

- **R-01** Was geschieht mit liegen gebliebenen Mulden am Ende eines Tisches und zwischen zwei Tischen.
- **R-02** Zählen Bank-Zuflüsse aus Siegel und Kette zum "Netto-Gewinn" für den Zunftzoll.
- **R-03** Spielerzahl im Run fest 4 oder je Epoche verschieden (Konzept, Kapitel 12). Davon hängen die Handgrößen aus K-104 ab.
- **R-04** Das Edikt "Dampferfahrt" spielt mit 52 Karten. Das verändert K-001 und K-104 und die Folge-Mulde (K-203).

### 10.5 Aus Pagat übernommen - bitte bestätigen

Diese Regeln stehen nicht im Konzept. Sie sind von Pagat übernommen, weil das Konzept Pagat als Referenz nennt. Der alte Code verhält sich in allen Punkten gleich.

| Regel | Inhalt | Pagat im Wortlaut |
|---|---|---|
| K-004 | Alles läuft im Uhrzeigersinn. | "The dealer deals out the cards clockwise" |
| K-103 | Alle Karten bis auf eine werden einzeln verteilt. | "one at a time as far as they will go until only one card is left" |
| K-106 | Das Geberrecht wechselt nach jeder Runde nach links. | "the turn to deal passes to the left after each hand" |
| K-304 | Zwei Paare zählen als das höhere, Drilling plus Paar als Drilling. | "If you have two pairs you only count the higher one. If you have a triple and a pair your hand just counts as a triple" |
| K-308 | Die Vorhand beginnt das Pochen. | "Starting with the player to the left of the dealer and going round clockwise" |
| K-311 | Wer aussteigt, verliert seine gesetzten Chips. | "When you drop out of the betting you sacrifice any chips you may already have bet" |

Einschränkung zu K-103: Dass die Vorhand die erste Karte erhält, steht bei Pagat nicht wörtlich. Dieser Teil folgt dem alten Code (`Dealing.swift:5`) und bestimmt, wer bei ungleicher Teilung eine Karte mehr hält.

Eine bewusste Abweichung des Konzepts von Pagat ist K-314: Sieg ohne Aufdecken. Pagat schreibt: "having shown a pair or better to prove entitlement to win them".
