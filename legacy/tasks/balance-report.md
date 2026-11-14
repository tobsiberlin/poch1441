# Gate-A-Balance-Report (Phasen-Analyse) - 5. Juli 2026

Werkzeug: `swift run -c release pochsim balance` (300 Partien / 3499 Runden, Cautious-Baseline, 4 Spieler, Schnelle Partie 60/12). Angefordert von Review-Runde 7 als Gate-A-Bedingung; beantwortet auch das Ante-Thema aus Runde 8.

## Ergebnisse

| Metrik | Wert | Bewertung |
|---|---|---|
| Runden mit Poch-Sieger | 99% | Poch-Phase wird fast immer gespielt (kein toter Ast) |
| Poch-Sieger gewinnt auch das Ausspielen | 37% | keine Runaway-Kopplung der Phasen |
| Poch-Sieger = größter Rundengewinner | 54% | Pochen ist wichtig, dominiert aber nicht |
| Runde entschieden durch Melden / Pochen / Ausspielen | 30% / 16% / 53% | **alle drei Phasen tragen substanziell** - genau die gewünschte Varianz („jede Runde endet anders") |
| Rundensieger ohne Melde-Chips | 11% | Phase 1 ist fast nie bedeutungslos |
| Melde-Chips pro Runde (Ø) | 22,3 von 36 Antes | **~62% der Antes fließen allein übers Melden zurück** |
| Jackpot-Übertrag zu Rundenbeginn p50/p90/max | 32 / 60 / 100 Chips | Jackpots werden spürbar groß (Drama), laufen aber nicht davon |

## Interpretation

1. **Ante-Kritik (Runden 7+8) entkräftet:** Die 9er-Ante ist kein Grind-Loch - fast zwei Drittel fließen sofort übers Melden zurück, der Rest speist Poch-Pott, Mitte und die Jackpot-Mulden, die alle wieder gewonnen werden. Partielängen bleiben gesund (p50 ~9-12 Runden im Quick-Modus).
2. **Keine Poch-Dominanz:** Der befürchtete „Poch-Sieg entscheidet alles"-Effekt tritt nicht ein (54%/37%).
3. **Ausspielen führt mit 53%** - erwartbar, da Mitte + Restkartenzahlung jede Runde am Ausspiel-Sieger hängen. Das ist Design-Absicht (das Rennen als Finale), keine Schieflage; Melden (30%) bleibt stark.
4. Vorbehalt: Cautious-Baseline, nicht echte Bots - Re-Check mit Charakter-Profilen in Phase 4 (erlaubte Parameter-Ausnahme vom Freeze).

## Replay-Stichproben

Der Event-Strom jeder Runde ist vollständig (Seed + Aktionsliste reproduzierbar). Stichproben-Sichtung: Verläufe plausibel, keine Anomalien (keine Endlos-Bietrunden, keine negativen Stacks, Ketten-Stopps korrekt). Safety-Cap für den Classic-Modus ist seit Runde 8 im Engine-Netz (500 Runden, real nie erreicht).

**Fazit: Aus Balance-Sicht steht Gate A nichts mehr im Weg.**
