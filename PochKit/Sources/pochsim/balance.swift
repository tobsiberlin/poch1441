import Foundation
import PochKit

// Phasen-Balance-Analyse für den Gate-A-Report (Spec Abschnitt 14, Review-Runde 7):
// Wie oft entscheidet welche Phase die Runde? Dominieren Poch-Gewinne? Wie groß werden
// die Jackpots? Deterministisch pro Seed, Cautious-Baseline (näher an echtem Spiel).

struct BalanceReport {
    var rounds = 0
    var pochRounds = 0                 // Runden mit Poch-Sieger (nicht alle gepasst)
    var pochWinnerWinsPlayout = 0      // Poch-Sieger gewinnt auch das Ausspielen
    var pochWinnerBestNet = 0          // Poch-Sieger hat den größten Netto-Gewinn der Runde
    var decidedByMeld = 0              // größter Brutto-Beitrag zum Top-Netto-Spieler
    var decidedByPoch = 0
    var decidedByPlayout = 0
    var winnerWithoutMeld = 0          // Top-Netto-Spieler hatte 0 Melde-Chips
    var meldChipsTotal = 0
    var carryovers: [Int] = []         // stehengebliebene Mulden-Chips zu Rundenbeginn

    mutating func record(round: Round, netGains: [Int]) {
        rounds += 1

        var meldGross = Array(repeating: 0, count: netGains.count)
        var pochGross = Array(repeating: 0, count: netGains.count)
        var playoutGross = Array(repeating: 0, count: netGains.count)
        var pochWinner: Int?
        var playoutWinner: Int?

        for event in round.events {
            switch event {
            case .melded(let player, _, let chips):
                meldGross[player] += chips
                meldChipsTotal += chips
            case .pochWon(let player, let pot, let pochPool, _):
                pochGross[player] += pot + pochPool
                pochWinner = player
            case .roundEnded(let winner, let center, let payments):
                playoutGross[winner] += center + payments.reduce(0, +)
                playoutWinner = winner
            default:
                break
            }
        }

        guard let top = netGains.indices.max(by: { netGains[$0] < netGains[$1] }) else { return }

        if let pochWinner {
            pochRounds += 1
            if pochWinner == playoutWinner { pochWinnerWinsPlayout += 1 }
            if pochWinner == top { pochWinnerBestNet += 1 }
        }

        let contributions = [
            (meldGross[top], 0), (pochGross[top], 1), (playoutGross[top], 2),
        ]
        switch contributions.max(by: { $0.0 < $1.0 })?.1 {
        case 0: decidedByMeld += 1
        case 1: decidedByPoch += 1
        default: decidedByPlayout += 1
        }
        if meldGross[top] == 0 { winnerWithoutMeld += 1 }
    }

    func percentile(_ values: [Int], _ p: Double) -> Int {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted[Int(Double(sorted.count - 1) * p)]
    }

    func print() {
        let r = Double(rounds)
        let pr = Double(max(pochRounds, 1))
        Swift.print("""
        Phasen-Balance (\(rounds) Runden, Cautious-Baseline, 4 Spieler, Stack 60, Limit 12)
        ------------------------------------------------------------------------------
        Runden mit Poch-Sieger:                \(pochRounds) (\(Int(Double(pochRounds) / r * 100))%)
        Poch-Sieger gewinnt auch Ausspielen:   \(Int(Double(pochWinnerWinsPlayout) / pr * 100))% der Poch-Runden
        Poch-Sieger = größter Rundengewinner:  \(Int(Double(pochWinnerBestNet) / pr * 100))% der Poch-Runden
        Runde entschieden durch  Melden:       \(Int(Double(decidedByMeld) / r * 100))%
                                 Pochen:       \(Int(Double(decidedByPoch) / r * 100))%
                                 Ausspielen:   \(Int(Double(decidedByPlayout) / r * 100))%
        Rundensieger ohne Melde-Chips:         \(Int(Double(winnerWithoutMeld) / r * 100))%
        Melde-Chips pro Runde (Durchschnitt):  \(String(format: "%.1f", Double(meldChipsTotal) / r))
        Jackpot-Übertrag zu Rundenbeginn p50/p90/max: \(percentile(carryovers, 0.5)) / \(percentile(carryovers, 0.9)) / \(carryovers.max() ?? 0) Chips
        """)
    }
}

func runBalanceAnalysis(seeds: UInt64) {
    var report = BalanceReport()

    for seed in 0..<seeds {
        var rng = SeededRNG(seed: seed)
        var match = Match(playerCount: 4, startingStack: 60, mode: .quick(roundLimit: 12))

        while match.result == nil {
            report.carryovers.append(match.board.total)
            guard let (started, tableSeats) = match.startRound(seed: rng.next()) else { break }
            var round = started
            let stacksBefore = tableSeats.map { match.stacks[$0] }

            while round.stage != .finished {
                switch round.stage {
                case .betting:
                    let player = round.betting.turn
                    guard let legal = round.betting.legalActions(for: player) else { break }
                    guard let observation = round.botObservation(for: player) else { break }
                    let action = MatchSimulator.baselineAction(
                        policy: .cautious,
                        observation: observation,
                        legal: legal,
                        rng: &rng
                    )
                    try? round.applyBet(action, by: player)
                case .playout:
                    guard let phase = round.playout,
                          let observation = phase.botObservation(for: phase.leader),
                          let card = BotBrain.lead(observation: observation) else { break }
                    try? round.applyLead(card)
                case .finished:
                    break
                }
            }

            let netGains = round.stacks.indices.map { round.stacks[$0] - stacksBefore[$0] }
            report.record(round: round, netGains: netGains)
            match.finishRound(round, tableSeats: tableSeats)
        }
    }
    report.print()
}
