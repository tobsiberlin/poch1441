import Foundation
import PochKit

/// Kalibrierung des `jackpotKollapsThreshold` (konzept §6 Auflage 3): die Stufe-2-
/// Explosion soll in ~15-20% der Tisch-Runden zünden (statistisch 0-1x pro Runde).
/// Reine Tooling-Erweiterung - Gate A (Regeln) unberührt.
func runKollapsCalibration(matches: Int) {
    var rng = SeededRNG(seed: 4242)
    var roundsTotal = 0
    var maxMeldPerRound: [Int] = []
    var allMeldChips: [Int] = []

    for _ in 0..<matches {
        var match = Match(playerCount: 4, startingStack: 60, mode: .quick(roundLimit: 12))
        while match.result == nil, match.roundsPlayed < 60 {
            guard let (started, tableSeats) = match.startRound(seed: rng.next()) else { break }
            var round = started

            var roundMax = 0
            for event in round.events {
                if case .melded(_, _, let chips) = event {
                    roundMax = max(roundMax, chips)
                    allMeldChips.append(chips)
                }
            }
            maxMeldPerRound.append(roundMax)
            roundsTotal += 1

            // Runde zufällig zu Ende spielen (Baseline wie MatchSimulator .random)
            while round.stage != .finished {
                switch round.stage {
                case .betting:
                    let player = round.betting.turn
                    guard round.betting.legalActions(for: player) != nil else { break }
                    try? round.applyBet(.pass, by: player)
                case .playout:
                    guard let phase = round.playout,
                          let observation = phase.botObservation(for: phase.leader),
                          !observation.legalLeads.isEmpty else { break }
                    let card = observation.legalLeads[
                        rng.nextInt(in: 0..<observation.legalLeads.count)
                    ]
                    try? round.applyLead(card)
                case .finished:
                    break
                }
            }
            match.finishRound(round, tableSeats: tableSeats)
        }
    }

    print("Kollaps-Kalibrierung: \(matches) Partien, \(roundsTotal) Tisch-Runden")
    print("Meld-Auszahlungen gesamt: \(allMeldChips.count)")
    print(String(repeating: "-", count: 64))
    print("Threshold | Runden mit Zuendung (max Meld >= T) | Zuend-Rate")
    for threshold in 6...20 {
        let fired = maxMeldPerRound.filter { $0 >= threshold }.count
        let rate = 100.0 * Double(fired) / Double(max(roundsTotal, 1))
        let marker = (rate >= 15 && rate <= 20) ? "  <-- Zielband 15-20%" : ""
        print(String(format: "   T = %2d | %6d / %6d | %5.1f%%%@",
                     threshold, fired, roundsTotal, rate, marker))
    }
}
