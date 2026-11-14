import Foundation
import PochKit

func runTutorialSeedSearch(playerCount: Int, upperBound: UInt64) {
    var meldMatches = 0
    var comboMatches = 0
    for seed in 1...upperBound {
        var match = Match(playerCount: playerCount,
                          startingStack: 60,
                          mode: .quick(roundLimit: 12),
                          firstDealer: playerCount - 1)
        guard let started = match.startRound(seed: seed),
              let humanRoundSeat = started.tableSeats.firstIndex(of: 0),
              started.round.deal.hands.indices.contains(humanRoundSeat)
        else { continue }

        let hand = started.round.deal.hands[humanRoundSeat]
        let pools = Melding.pools(for: hand, upcard: started.round.deal.upcard)
        let melds = started.round.events.compactMap { event -> (Int, Pool, Int)? in
            guard case .melded(let player, let pool, let chips) = event else { return nil }
            return (player, pool, chips)
        }
        let firstMeld = melds.first

        if meldMatches < 12,
           pools.contains(.mariage),
           firstMeld?.0 == humanRoundSeat {
            let cards = hand
                .sorted { lhs, rhs in
                    lhs.suit.rawValue == rhs.suit.rawValue
                        ? lhs.rank.rawValue > rhs.rank.rawValue
                        : lhs.suit.rawValue < rhs.suit.rawValue
                }
                .map { "\($0.suit.rawValue)-\($0.rank.rawValue)" }
                .joined(separator: ",")
            let won = Pool.allCases.filter(pools.contains).map(\.rawValue).joined(separator: ",")
            let firstPool = firstMeld?.1.rawValue ?? "none"
            let firstChips = firstMeld?.2 ?? 0
            let events = melds
                .map { "seat\($0.0)-\($0.1.rawValue)-\($0.2)" }
                .joined(separator: ",")
            print("meld seed=\(seed) humanRoundSeat=\(humanRoundSeat) upcard=\(started.round.deal.upcard.suit.rawValue)-\(started.round.deal.upcard.rank.rawValue) pools=\(won) first=\(firstPool) chips=\(firstChips) hand=\(cards) events=\(events)")
            meldMatches += 1
        }

        if comboMatches < 12,
           let combo = ComboEvaluator.best(in: hand, trump: started.round.deal.trump) {
            print("combo seed=\(seed) rank=\(combo.rank.rawValue) kind=\(combo.kind.rawValue) trump=\(started.round.deal.trump.rawValue)")
            comboMatches += 1
        }

        if meldMatches == 12, comboMatches == 12 { return }
    }
}
