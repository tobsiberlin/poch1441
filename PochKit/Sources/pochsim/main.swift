import Foundation
import PochKit

// Subkommando "balance": Phasen-Balance-Analyse für den Gate-A-Report (Review-Runde 7/8).
if CommandLine.arguments.contains("balance") {
    runBalanceAnalysis(seeds: 300)
    exit(0)
}

// Monte-Carlo-Sweep für die Economy-Kalibrierung (Spec Abschnitt 14, Phase-1-Exit).
// Zufalls-Baseline: alle Entscheidungen gleichverteilt legal - Bot-Profile ersetzen das in
// Phase 4, dann wird nachkalibriert (nur Parameter, nie Regeln).

let seedsPerConfig: UInt64 = 300
let playerCount = 4 // v1: fester Vierertisch

// Zeitmodell (Annahme, auf dem Gerät in Phase 3 zu validieren):
// menschliche Entscheidung ~4s, Runden-Overhead (Antes/Geben/Melden/Abrechnung inszeniert) ~35s.
let decisionSeconds = 4.0
let roundOverheadSeconds = 35.0

struct Aggregate {
    var rounds: [Int] = []
    var decisions: [Int] = []
    var bankruptcies: [Int] = []
    var cappedOut = 0

    mutating func add(_ stats: MatchSimulator.Stats) {
        rounds.append(stats.roundsPlayed)
        decisions.append(stats.decisions)
        bankruptcies.append(stats.bankruptcies)
        if stats.endedByRoundCap { cappedOut += 1 }
    }

    func percentile(_ values: [Int], _ p: Double) -> Int {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let index = Int(Double(sorted.count - 1) * p)
        return sorted[index]
    }

    func minutes(rounds: Int, decisions: Int) -> Double {
        (Double(decisions) * decisionSeconds + Double(rounds) * roundOverheadSeconds) / 60.0
    }

    func line(label: String) -> String {
        let r50 = percentile(rounds, 0.5), r90 = percentile(rounds, 0.9)
        let d50 = percentile(decisions, 0.5), d90 = percentile(decisions, 0.9)
        let b50 = percentile(bankruptcies, 0.5)
        let m50 = minutes(rounds: r50, decisions: d50)
        let m90 = minutes(rounds: r90, decisions: d90)
        let capNote = cappedOut > 0 ? " capHits=\(cappedOut)" : ""
        return String(
            format: "%@  Runden p50/p90: %2d/%2d  Entscheidungen p50/p90: %3d/%3d  Pleiten p50: %d  ~Minuten p50/p90: %.1f/%.1f%@",
            label, r50, r90, d50, d90, b50, m50, m90, capNote
        )
    }
}

print("pochsim - \(seedsPerConfig) Partien pro Konfiguration, \(playerCount) Spieler, Zufalls-Baseline")
print(String(repeating: "-", count: 100))

for policy in [MatchSimulator.Policy.random, .cautious] {
    print("\n=== Policy: \(policy.rawValue) ===")
    print("Modus: Schnelle Partie (quick)")
    for startingStack in [20, 30, 40, 60] {
        for roundLimit in [6, 8, 10, 12, 16] {
            var agg = Aggregate()
            for seed in 0..<seedsPerConfig {
                agg.add(MatchSimulator.simulate(
                    playerCount: playerCount,
                    startingStack: startingStack,
                    mode: .quick(roundLimit: roundLimit),
                    seed: seed,
                    policy: policy
                ))
            }
            print(agg.line(label: String(format: "Stack %2d, Limit %2d |", startingStack, roundLimit)))
        }
        print("")
    }

    print("Modus: Bis zum letzten Chip (classic, Sicherheitsdeckel 400 Runden)")
    for startingStack in [20, 30, 40, 60] {
        var agg = Aggregate()
        for seed in 0..<seedsPerConfig {
            agg.add(MatchSimulator.simulate(
                playerCount: playerCount,
                startingStack: startingStack,
                mode: .classic,
                seed: seed,
                policy: policy
            ))
        }
        print(agg.line(label: String(format: "Stack %2d           |", startingStack)))
    }
}
