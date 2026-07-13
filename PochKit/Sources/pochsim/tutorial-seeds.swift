import Foundation
import PochKit

func runTutorialSeedSearch(playerCount: Int, upperBound: UInt64) {
    var matches = 0
    for seed in 1...upperBound {
        var match = Match(playerCount: playerCount,
                          startingStack: 60,
                          mode: .quick(roundLimit: 12),
                          firstDealer: playerCount - 1)
        guard let started = match.startRound(seed: seed),
              let humanRoundSeat = started.tableSeats.firstIndex(of: 0),
              started.round.deal.hands.indices.contains(humanRoundSeat),
              let combo = ComboEvaluator.best(
                in: started.round.deal.hands[humanRoundSeat],
                trump: started.round.deal.trump)
        else { continue }

        print("seed=\(seed) rank=\(combo.rank.rawValue) kind=\(combo.kind.rawValue) trump=\(started.round.deal.trump.rawValue)")
        matches += 1
        if matches == 12 { return }
    }
}
