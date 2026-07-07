import XCTest
@testable import PochKit

final class BettingTests: XCTestCase {
    private let trump = Suit.hearts

    /// Hand mit Paar (bietberechtigt), ohne Trumpfkarten.
    private var pairHand: [Card] {
        [Card(suit: .spades, rank: .nine), Card(suit: .clubs, rank: .nine)]
    }

    /// Hand ohne Paar (nie bietberechtigt).
    private var noPairHand: [Card] {
        [Card(suit: .spades, rank: .ace), Card(suit: .clubs, rank: .king)]
    }

    private func phase(stacks: [Int], hands: [[Card]]? = nil) -> BettingPhase {
        BettingPhase(
            stacks: stacks,
            hands: hands ?? Array(repeating: pairHand, count: stacks.count),
            trump: trump
        )
    }

    /// Spec Abschnitt 3: Passen alle in der ersten vollständigen Runde, endet die Phase (Poch-Mulde bleibt stehen).
    func testAllPassEndsPhase() throws {
        var p = phase(stacks: [10, 10, 10, 10])
        for player in 0..<4 {
            try p.apply(.pass, by: player)
        }
        XCTAssertEqual(p.outcome, .allPassed)
    }

    /// Spec Abschnitt 3: Kein "Mitgehen 0" - vor der Eröffnung gibt es nur Eröffnen oder Passen.
    func testNoCallBeforeOpening() {
        var p = phase(stacks: [10, 10, 10])
        XCTAssertEqual(p.legalActions(for: 0)?.canCall, false)
        XCTAssertThrowsError(try p.apply(.call, by: 0)) { error in
            XCTAssertEqual(error as? BettingPhase.ActionError, .noOpeningYet)
        }
    }

    /// Spec Abschnitt 3: Ohne Paar weder Eröffnen noch Mitgehen - nur Passen.
    func testNoPairMayOnlyPass() throws {
        var p = phase(stacks: [10, 10, 10], hands: [noPairHand, pairHand, pairHand])
        let legal = try XCTUnwrap(p.legalActions(for: 0))
        XCTAssertTrue(legal.canPass)
        XCTAssertNil(legal.openRange)
        XCTAssertThrowsError(try p.apply(.open(2), by: 0)) { error in
            XCTAssertEqual(error as? BettingPhase.ActionError, .mayNotBid)
        }
    }

    /// Spec Abschnitt 3 (Kantenfall): 0-Chip-Spieler kann nur passen - und drückt den Cap nicht auf 0.
    func testZeroChipPlayerOnlyPassesAndDoesNotLowerCap() throws {
        var p = phase(stacks: [10, 0, 6])
        XCTAssertEqual(p.bidCap, 6, "Cap zählt nur bietberechtigte Spieler - der 0-Chip-Sitz nicht")
        let legalZero = try XCTUnwrap({ () -> BettingPhase.LegalActions? in
            var copy = p
            try? copy.apply(.open(3), by: 0)
            return copy.legalActions(for: 1)
        }())
        XCTAssertTrue(legalZero.canPass)
        XCTAssertFalse(legalZero.canCall)
        XCTAssertNil(legalZero.raiseRange)
        _ = p
    }

    /// Spec Abschnitt 3: Erhöhungs-Cap = kleinster Gesamtbestand (Stack + Gesetztes) der
    /// bietberechtigten Aktiven; niemand darf höher bieten, als der Knappste zahlen kann.
    func testRaiseAboveCapIsIllegal() throws {
        var p = phase(stacks: [20, 5, 20])
        try p.apply(.open(3), by: 0)
        XCTAssertEqual(p.bidCap, 5)
        XCTAssertThrowsError(try p.apply(.raise(to: 6), by: 1)) { error in
            XCTAssertEqual(error as? BettingPhase.ActionError, .bidOutOfBounds)
        }
    }

    /// Spec Abschnitt 3 (Kantenfall): Der Cap wird nach jedem Passen neu berechnet - passt der
    /// kleinste Stack, steigt der Cap; die gesetzten Chips des Passenden bleiben im Pott.
    func testCapRisesAfterSmallestStackPasses() throws {
        var p = phase(stacks: [20, 5, 20])
        try p.apply(.open(2), by: 0)
        XCTAssertEqual(p.bidCap, 5)
        try p.apply(.pass, by: 1)
        XCTAssertEqual(p.bidCap, 20, "Nach dem Passen des knappsten Sitzes steigt der Cap")
        let legal = try XCTUnwrap(p.legalActions(for: 2))
        XCTAssertEqual(legal.raiseRange, 3...20)
    }

    /// Spec Abschnitt 3: Passen alle bis auf einen, gewinnt dieser ohne Aufdecken.
    func testWonUncontestedWhenAllOthersFold() throws {
        var p = phase(stacks: [10, 10, 10])
        try p.apply(.open(4), by: 0)
        try p.apply(.pass, by: 1)
        try p.apply(.pass, by: 2)
        XCTAssertEqual(p.outcome, .wonUncontested(player: 0))
    }

    /// Spec Abschnitt 3: Sind alle verbliebenen Einsätze gleich, kommt der Showdown mit genau
    /// den noch aktiven Spielern.
    func testShowdownWhenBetsAreEqual() throws {
        var p = phase(stacks: [10, 10, 10, 10])
        try p.apply(.open(2), by: 0)
        try p.apply(.call, by: 1)
        try p.apply(.raise(to: 4), by: 2)
        try p.apply(.pass, by: 3)
        try p.apply(.call, by: 0)
        try p.apply(.call, by: 1)
        XCTAssertEqual(p.outcome, .showdown(players: [0, 1, 2]))
        XCTAssertEqual(p.seats.map(\.committed), [4, 4, 4, 0])
    }

    /// Spec Abschnitt 3: Showdown-Sieger ist die beste Kombination; bei gleichen Paaren gewinnt Trumpf.
    func testShowdownWinnerByComboAndTrumpTiebreak() {
        let hands: [[Card]] = [
            [Card(suit: .spades, rank: .king), Card(suit: .clubs, rank: .king)],     // Paar Könige ohne Trumpf
            [Card(suit: .hearts, rank: .king), Card(suit: .diamonds, rank: .king)],  // Paar Könige MIT Trumpf
            [Card(suit: .spades, rank: .seven), Card(suit: .clubs, rank: .seven), Card(suit: .diamonds, rank: .seven)], // Drilling
        ]
        XCTAssertEqual(Showdown.winner(among: [0, 1], hands: hands, trump: trump), 1)
        XCTAssertEqual(Showdown.winner(among: [0, 1, 2], hands: hands, trump: trump), 2)
    }

    /// Invarianten-Fuzzer (Spec Abschnitt 14): Über viele Seeds zufällige legale Aktionsfolgen -
    /// Chips bleiben erhalten, Mitgehen ist für Aktive immer bezahlbar, die Phase terminiert.
    func testRandomLegalSequencesHoldInvariants() throws {
        for seed in UInt64(0)..<150 {
            var rng = SeededRNG(seed: seed)
            let playerCount = Int.random(in: 3...6, using: &rng)
            let deal = Deal.deal(playerCount: playerCount, seed: seed &+ 99)
            let stacks = (0..<playerCount).map { _ in Int.random(in: 0...25, using: &rng) }
            let initialTotal = stacks.reduce(0, +)

            var p = BettingPhase(stacks: stacks, hands: deal.hands, trump: deal.trump)
            var steps = 0
            while p.outcome == nil {
                steps += 1
                XCTAssertLessThan(steps, 500, "Seed \(seed): Bietphase terminiert nicht")

                let player = p.turn
                let legal = try XCTUnwrap(p.legalActions(for: player))

                var actions: [BettingPhase.Action] = [.pass]
                if let open = legal.openRange { actions.append(.open(Int.random(in: open, using: &rng))) }
                if legal.canCall { actions.append(.call) }
                if let raise = legal.raiseRange { actions.append(.raise(to: Int.random(in: raise, using: &rng))) }

                let index = Int.random(in: 0..<actions.count, using: &rng)
                try p.apply(actions[index], by: player)

                let total = p.seats.map { $0.stack + $0.committed }.reduce(0, +)
                XCTAssertEqual(total, initialTotal, "Seed \(seed): Chip-Erhaltung verletzt")

                if p.currentBet > 0 {
                    for seat in p.seats where seat.isActive && seat.isBidEligible {
                        XCTAssertGreaterThanOrEqual(
                            seat.stack + seat.committed, p.currentBet,
                            "Seed \(seed): Aktiver bietberechtigter Spieler kann nicht mehr mitgehen - Cap verletzt"
                        )
                    }
                }
            }
        }
    }
}
