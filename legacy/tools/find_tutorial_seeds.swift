struct TutorialSeedReport {
    var meld: UInt64?
    var bidding: UInt64?
    var playout: UInt64?
}

func humanMeldCount(in round: Round) -> Int {
    round.events.reduce(into: 0) { count, event in
        if case .melded(let player, _, _) = event, player == 0 {
            count += 1
        }
    }
}

func allPass(_ round: Round) -> Round? {
    var candidate = round
    while candidate.stage == .betting {
        do {
            try candidate.applyBet(.pass, by: candidate.betting.turn)
        } catch {
            return nil
        }
    }
    return candidate
}

@main
enum FindTutorialSeeds {
    static func main() {
        for playerCount in [3, 4] {
            let report = find(playerCount: playerCount)
            print("players=\(playerCount)")
            print("meld=\(report.meld.map(String.init) ?? "missing")")
            print("bidding=\(report.bidding.map(String.init) ?? "missing")")
            print("playout=\(report.playout.map(String.init) ?? "missing")")
        }
    }

    private static func find(playerCount: Int) -> TutorialSeedReport {
        var report = TutorialSeedReport()
        for seed in UInt64(1_441)..<UInt64(100_000) {
            let round = Round(stacks: Array(repeating: 60, count: playerCount),
                              board: Board(),
                              seed: seed)
            let combo = ComboEvaluator.best(in: round.deal.hands[0], trump: round.deal.trump)

            if report.meld == nil, humanMeldCount(in: round) >= 2 {
                report.meld = seed
            }

            if report.bidding == nil,
               combo?.kind == .pair,
               round.betting.turn == 0,
               round.betting.legalActions(for: 0)?.openRange != nil {
                report.bidding = seed
            }

            if report.playout == nil,
               let passed = allPass(round),
               passed.stage == .playout,
               passed.playout?.leader == 0,
               (passed.playout?.hands[0].count ?? 0) >= 7 {
                report.playout = seed
            }

            if report.meld != nil, report.bidding != nil, report.playout != nil {
                break
            }
        }
        return report
    }
}
