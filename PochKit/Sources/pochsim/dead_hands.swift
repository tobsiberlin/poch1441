import Foundation
import PochKit

struct DeadHandReport {
    let playerCount: Int
    var hands = 0
    var withoutMeld = 0
    var withoutPair = 0
    var withoutMeldOrPair = 0

    mutating func record(hand: [Card], melded: Bool, trump: Suit) {
        let mayBid = ComboEvaluator.best(in: hand, trump: trump) != nil
        hands += 1
        if !melded { withoutMeld += 1 }
        if !mayBid { withoutPair += 1 }
        if !melded && !mayBid { withoutMeldOrPair += 1 }
    }

    func printSummary() {
        func percent(_ value: Int) -> String {
            guard hands > 0 else { return "0.00" }
            return String(format: "%.2f", Double(value) / Double(hands) * 100)
        }
        print("\(playerCount) Spieler | Hände \(hands) | ohne Meldung \(percent(withoutMeld))% | ohne Paar \(percent(withoutPair))% | beides \(percent(withoutMeldOrPair))%")
    }
}

func runDeadHandAnalysis(dealsPerPlayerCount: Int) {
    precondition(dealsPerPlayerCount > 0)
    print("Dead-Hand-Analyse - \(dealsPerPlayerCount) Deals je Tischgröße")
    print(String(repeating: "-", count: 104))

    for playerCount in 3...6 {
        var report = DeadHandReport(playerCount: playerCount)
        for seed in 0..<dealsPerPlayerCount {
            let deal = Deal.deal(playerCount: playerCount, seed: UInt64(seed))
            for player in deal.hands.indices {
                report.record(hand: deal.hands[player],
                              melded: !Melding.pools(for: deal.hands[player],
                                                    upcard: deal.upcard).isEmpty,
                              trump: deal.trump)
            }
        }
        report.printSummary()
    }
}
