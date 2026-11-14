# Poch 1441 - Echte Partien über mehrere Runden

## Ziel

Die App soll nicht nur einzelne Runden zeigen. Eine Partie muss die vorhandene
`PochKit.Match`-Logik vollständig nutzen:

- Konten und stehende Mulden bleiben zwischen Runden erhalten.
- Das Geberrecht rotiert regelkonform.
- Zahlungsunfähige Sitze scheiden vor dem Geben aus.
- Quick-Partie und klassische Partie enden nach den Regeln des Kerns.
- Ergebnis, Chronik und Langzeitmotivation beruhen auf echten Matchdaten.

## Aktuelles Risiko

`BotMatchSource.newRound(seed:)` erzeugt derzeit wieder eine neue `Round` mit 60 Chips
pro Sitz und einem leeren `Board`. Das ist für Screen- und Rundenprototypen brauchbar,
aber keine vollständige Partie.

Die direkte Umstellung auf `Match` ist nicht lokal: `Match.startRound` liefert ein
Mapping von Rundensitzen zu festen Tischsitzen. Durch die Geberrotation ist der Mensch
nicht dauerhaft Rundensitz 0. In der App setzen derzeit unter anderem Bieten,
Ausspielen, Gegnernamen, Kartenflug, Ergebnis und Tutorial voraus, dass UI-Sitz 0 der
Mensch ist.

## Red-Team-Prüfung

1. **Falsche Annahme:** Rundensitz und UI-Sitz seien identisch.
   Folge: Bots könnten die menschliche Hand spielen oder verdeckte Karten offenlegen.
2. **Fehlendes Mapping:** Gewinner und Restkartenzahlungen könnten beim falschen Portrait
   landen.
3. **Instabile Gegneridentität:** Namen und Portraits könnten bei jeder Geberrotation
   den Sitz wechseln.
4. **Tutorialbruch:** Deterministische Seeds und erwartetes menschliches Anspielrecht
   hängen aktuell an Sitz 0.
5. **Abbruchfall:** Eine neue Runde darf erst nach vollständig abgeschlossener
   Ergebnisinszenierung in `Match.finishRound` übernommen werden.

## Zielarchitektur

`MatchSource` liefert zusätzlich zur laufenden `Round` ein stabiles Sitz-Mapping:

- `tableSeat(forRoundSeat:)`
- `roundSeat(forTableSeat:)`
- `humanRoundSeat`
- `roundsPlayed`, `matchResult`, `matchStacks`, `board`

Die UI arbeitet weiterhin mit stabilen UI-Sitzen:

- UI-Sitz 0 bleibt der Mensch am unteren Bildschirmrand.
- UI-Sitze 1... behalten Name, Portrait und Chronik während der gesamten Partie.
- `GameState` übersetzt ausschließlich an der Source-Grenze zwischen UI- und
  Rundensitzen.
- PochKit bleibt alleinige Wahrheit für Regeln, Zahlungen, Rotation und Partieende.

## Umsetzung in überprüfbaren Stufen

1. **Mapping-Adapter und Tests**
   - bijektives Mapping für 3-6 Spieler
   - Mensch bleibt UI-Sitz 0 bei jeder Geberposition
   - keine Hand oder Zahlung wechselt die Identität
2. **Lesepfade umstellen**
   - Hände, Stacks, Zug, Limit, Gewinner, Zahlungen, Kartenherkunft
3. **Aktionspfade umstellen**
   - menschliches Bieten und Anspielen auf `humanRoundSeat`
   - Bot-Schleife auf alle anderen Rundensitze
4. **Rundenübergang anschließen**
   - `finishRound` exakt einmal nach abgeschlossener Ergebnisinszenierung
   - `startRound` erst nach CTA oder automatischem Tutorial-Transfer
5. **Match-Ende und Chronik**
   - Quick-Modus, Classic-Modus, Geber, Runde, Ausscheiden und Endergebnis sichtbar
6. **QA-Gates**
   - PochKit-Matchtests unverändert grün
   - deterministischer 12-Runden-Simulatorlauf
   - UI-Screenshot je Geberposition und für 3/4/5/6 Spieler
   - keine verdeckte Gegnerkarte in Logs, UI oder Assist-Hinweisen

## Done

Eine neu gestartete Partie behält nach `Nächste Runde` alle Konten und Mulden, rotiert
den Geber, zeigt weiterhin dieselben Gegneridentitäten, endet regelkonform und lässt
sich mit gleichem Seed vollständig reproduzieren.
