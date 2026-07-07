import XCTest
@testable import PochKit

final class MatchTests: XCTestCase {
    /// Spec Abschnitt 3: „Schnelle Partie" endet am Rundenlimit mit Wertung nach Chipstand.
    func testQuickModeEndsAtRoundLimit() {
        let stats = MatchSimulator.simulate(playerCount: 4, startingStack: 60, mode: .quick(roundLimit: 5), seed: 11)
        XCTAssertLessThanOrEqual(stats.roundsPlayed, 5)
        XCTAssertFalse(stats.winners.isEmpty, "Partie muss mit mindestens einem Sieger enden")
        XCTAssertFalse(stats.endedByRoundCap)
    }

    /// Spec Abschnitt 3: Klassischer Modus endet, sobald weniger als 3 Spieler die Antes zahlen
    /// können; Ausgeschiedene behalten ihre Restchips für die Endwertung.
    func testClassicModeEndsWhenFewerThanThreeSolvent() {
        let stats = MatchSimulator.simulate(playerCount: 3, startingStack: 12, mode: .classic, seed: 3)
        XCTAssertFalse(stats.endedByRoundCap)
        XCTAssertFalse(stats.winners.isEmpty)
        XCTAssertTrue(stats.finalStacks.allSatisfy { $0 >= 0 }, "Keine Schulden, auch nicht bei Ausgeschiedenen")
    }

    /// Engine-Safety-Net (Review-Runde 8): Der unsichtbare Runden-Deckel erzwingt auch im
    /// klassischen Modus deterministisch eine Wertung - real wird er nie erreicht.
    func testClassicSafetyCapForcesResult() {
        var match = Match(playerCount: 4, startingStack: 200, mode: .classic, safetyRoundCap: 2)
        var rng = SeededRNG(seed: 1)
        var guardCounter = 0
        while match.result == nil, guardCounter < 10 {
            guardCounter += 1
            guard let (started, seats) = match.startRound(seed: rng.next()) else { break }
            var round = started
            while round.stage == .betting { try? round.applyBet(.pass, by: round.betting.turn) }
            while round.stage == .playout, let phase = round.playout, let card = phase.hands[phase.leader].first {
                try? round.applyLead(card)
            }
            match.finishRound(round, tableSeats: seats)
        }
        XCTAssertNotNil(match.result, "Safety-Cap muss eine Wertung erzwingen")
        XCTAssertEqual(match.roundsPlayed, 2)
    }

    /// Spec Abschnitt 5: Gleicher Seed → identischer Partie-Verlauf (Reproduzierbarkeit).
    func testSimulationIsDeterministicPerSeed() {
        let a = MatchSimulator.simulate(playerCount: 4, startingStack: 40, mode: .quick(roundLimit: 10), seed: 99)
        let b = MatchSimulator.simulate(playerCount: 4, startingStack: 40, mode: .quick(roundLimit: 10), seed: 99)
        XCTAssertEqual(a, b)
    }

    /// Invariante (Spec Abschnitt 14): Chip-Erhaltung über eine KOMPLETTE Partie -
    /// Stacks + Brett bleiben nach jeder Runde exakt die Summe der Startstacks.
    func testFullMatchChipConservation() throws {
        for seed in UInt64(0)..<40 {
            var rng = SeededRNG(seed: seed)
            let playerCount = Int.random(in: 3...6, using: &rng)
            let startingStack = Int.random(in: 20...60, using: &rng)
            let expectedTotal = playerCount * startingStack

            var match = Match(playerCount: playerCount, startingStack: startingStack, mode: .quick(roundLimit: 12))
            while match.result == nil, match.roundsPlayed < 40 {
                guard let (started, tableSeats) = match.startRound(seed: rng.next()) else { break }
                var round = started
                while round.stage != .finished {
                    switch round.stage {
                    case .betting:
                        let player = round.betting.turn
                        let legal = try XCTUnwrap(round.betting.legalActions(for: player))
                        var actions: [BettingPhase.Action] = [.pass]
                        if let open = legal.openRange { actions.append(.open(Int.random(in: open, using: &rng))) }
                        if legal.canCall { actions.append(.call) }
                        if let raise = legal.raiseRange { actions.append(.raise(to: Int.random(in: raise, using: &rng))) }
                        try round.applyBet(actions[Int.random(in: 0..<actions.count, using: &rng)], by: player)
                    case .playout:
                        let phase = try XCTUnwrap(round.playout)
                        let hand = phase.hands[phase.leader]
                        try round.applyLead(hand[Int.random(in: 0..<hand.count, using: &rng)])
                    case .finished:
                        break
                    }
                }
                match.finishRound(round, tableSeats: tableSeats)
                let total = match.stacks.reduce(0, +) + match.board.total
                XCTAssertEqual(total, expectedTotal, "Seed \(seed), Runde \(match.roundsPlayed): Chip-Erhaltung verletzt")
            }
        }
    }

    /// Spec Kantenfälle: Das Geberrecht rotiert im Uhrzeigersinn ausschließlich über die
    /// verbliebenen Spieler; die Runden-Sitzordnung beginnt links vom Geber, der Geber
    /// bekommt als Letzter Karten.
    func testSeatOrderStartsLeftOfDealerAndSkipsEliminated() throws {
        var match = Match(playerCount: 4, startingStack: 40, mode: .classic)
        let (round1, seats1) = try XCTUnwrap(match.startRound(seed: 1))
        XCTAssertEqual(seats1, [1, 2, 3, 0], "Geber 0: Reihenfolge beginnt links von ihm, er selbst zuletzt")

        // Verlustarme, deterministische Runde (alle passen, erste Karte anspielen), damit
        // niemand unter die Ante-Grenze fällt - getestet wird hier nur die Rotation.
        var r1 = round1
        while r1.stage == .betting {
            try r1.applyBet(.pass, by: r1.betting.turn)
        }
        while r1.stage == .playout {
            let phase = try XCTUnwrap(r1.playout)
            let card = try XCTUnwrap(phase.hands[phase.leader].first)
            try r1.applyLead(card)
        }
        match.finishRound(r1, tableSeats: seats1)
        XCTAssertEqual(match.dealer, 1, "Geberrecht wandert im Uhrzeigersinn")

        let (_, seats2) = try XCTUnwrap(match.startRound(seed: 2))
        XCTAssertEqual(seats2, [2, 3, 0, 1])
    }
}
