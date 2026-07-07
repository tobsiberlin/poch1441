# Economy-Kalibrierung (Monte-Carlo) - Stand 5. Juli 2026

Werkzeug: `PochKit/Sources/pochsim` (`swift run -c release pochsim`), 300 Partien pro Konfiguration, 4 Spieler (v1-Vierertisch), deterministisch pro Seed. Zwei Baselines: `random` (chaotisch = Obergrenze der Chip-Geschwindigkeit) und `cautious` (foldet ohne gutes Blatt = näher an echtem Spiel). Echte Bot-Profile ersetzen beide in Phase 4.

**Zeitmodell (Annahme, in Phase 3 auf dem Gerät zu validieren):** Entscheidung ~4s, Runden-Overhead (Antes/Geben/Melden/Abrechnung inszeniert) ~35s.

## Kernbefunde

1. **Zufalls-Baseline verzerrt massiv:** Bei Zufallsspiel enden Partien nach 2-5 Runden durch Pleiten (p50: 2 von 4 Spielern insolvent) - Rundenlimits greifen nie. Aus dieser Baseline allein darf nicht kalibriert werden (LFD: kein verzerrtes Instrument).
2. **Vorsichtige Baseline:** Rundenlimits greifen ab Stack 40 tatsächlich; Pleiten sinken auf p50 0-2; Partiedauern werden planbar (enge p50/p90-Spannen bei Stack 60).
3. **Klassischer Modus terminiert zuverlässig:** 0 Cap-Hits über alle 2400 Classic-Simulationen (Deckel 400 Runden) - kein Endlos-Partie-Risiko. Stack 60 classic: p50 ~24 Min, p90 ~45 Min = guter „langer Abend".

## Gepinnte Parameter (vorläufig)

| Modus | Parameter | Simulierte Dauer (cautious) |
|---|---|---|
| **Schnelle Partie** | **Startstack 60, Rundenlimit 12** | p50 15.8 Min / p90 16.5 Min - trifft das 15-20-Min-Ziel mit enger Streuung; p50 nur 1 Pleite (freundlich) |
| Bis zum letzten Chip | Startstack 60 | p50 ~24 Min / p90 ~45 Min |

Vergleichswerte: Stack 40/Limit 12 → 11.8/16.2 Min (etwas zu kurz); Stack 60/Limit 16 → ~21 Min (drüber).

## Vorbehalte / Re-Check-Punkte

- Zufalls-Baseline liefert für dieselbe Config ~7 Min - der echte Wert liegt zwischen den Baselines. **Nachkalibrierung mit echten Bot-Profilen in Phase 4** (nur Parameter-Tuning, nie Regeländerungen - explizit erlaubte Ausnahme vom Gate-A-Freeze).
- Zeitmodell-Konstanten (4s/35s) in Phase 3 auf dem Gerät messen und die Tabelle neu rechnen.
- Parameter leben als Daten (Konfiguration), nicht im Code verstreut - Anpassung ohne Engine-Änderung.
