import XCTest
@testable import PochKit

final class RoundTests: XCTestCase {
    /// Spec Abschnitt 3: Antes (9 Chips pro Spieler) fließen vor dem Geben aufs Brett;
    /// Melde-Auszahlungen entsprechen exakt der unabhängig berechneten Melde-Logik.
    func testAntesAndMeldingMatchIndependentComputation() {
        let round = Round(stacks: [40, 40, 40, 40], board: Board(), seed: 1441)

        let expectedDeal = Deal.deal(playerCount: 4, seed: 1441)
        XCTAssertEqual(round.deal, expectedDeal)

        var expectedStacks = [31, 31, 31, 31] // 40 - 9 Antes
        for (player, pools) in Melding.meldOrder(deal: expectedDeal) {
            expectedStacks[player] += pools.count * 4 // jede Mulde enthält genau die 4 Antes dieser Runde
        }
        XCTAssertEqual(round.betting.seats.map(\.stack), expectedStacks)
        XCTAssertEqual(round.totalChips, 160)
    }

    /// Spec Abschnitt 3: Passen alle, bleibt die Poch-Mulde stehen und der Spieler links
    /// vom Geber führt das Ausspielen an.
    func testAllPassKeepsPochPoolAndLeaderIsLeftOfDealer() throws {
        var round = Round(stacks: [40, 40, 40], board: Board(), seed: 7)
        for player in 0..<3 {
            try round.applyBet(.pass, by: player)
        }
        XCTAssertEqual(round.stage, .playout)
        XCTAssertNil(round.pochWinner)
        XCTAssertEqual(round.board[.poch], 3, "Poch-Mulde bleibt bei allgemeinem Passen stehen")
        XCTAssertEqual(round.playout?.leader, 0)
    }

    /// Spec Abschnitt 3: Sieg ohne Aufdecken kassiert Pott + Poch-Mulde; der Gewinner führt an.
    func testUncontestedPochWinnerTakesPotAndLeads() throws {
        // Seed dynamisch wählen: Der Spieler am Zug muss direkt bietberechtigt sein,
        // damit alle übrigen nach der Eröffnung passen (kein Vorab-Passen nötig).
        guard let (seed, opener) = (UInt64(0)..<200).lazy.compactMap({ seed -> (UInt64, Int)? in
            let candidate = Round(stacks: [40, 40, 40], board: Board(), seed: seed)
            return candidate.betting.seats[candidate.betting.turn].mayBid ? (seed, candidate.betting.turn) : nil
        }).first else {
            return XCTFail("Kein Seed mit direkt bietberechtigtem Startspieler gefunden")
        }

        var round = Round(stacks: [40, 40, 40], board: Board(), seed: seed)
        let stackBefore = round.betting.seats[opener].stack
        try round.applyBet(.open(2), by: opener)
        while round.stage == .betting {
            try round.applyBet(.pass, by: round.betting.turn)
        }
        XCTAssertEqual(round.stage, .playout)
        XCTAssertEqual(round.pochWinner, opener)
        XCTAssertEqual(round.board[.poch], 0)
        XCTAssertEqual(round.stacks[opener], stackBefore - 2 + 2 + 3, "Eigener Einsatz zurück + Poch-Mulde (3 Antes)")
        XCTAssertEqual(round.playout?.leader, opener)
        XCTAssertTrue(round.events.contains(.pochWon(player: opener, pot: 2, pochPool: 3, byShowdown: false)))
    }

    /// Spec Abschnitt 3: Restkarten-Zahlung ist bei Stack 0 gedeckelt - keine Schulden.
    func testCardPaymentsCappedAtZeroStack(){
        // Wird über den Fuzzer unten strukturell mitgeprüft (Stacks nie negativ);
        // hier der gezielte Kantenfall: ein Spieler startet mit exakt 9 Chips (nach Antes 0).
        var round = Round(stacks: [9, 40, 40], board: Board(), seed: 3)
        XCTAssertNoThrow(try round.applyBet(.pass, by: round.betting.turn))
        XCTAssertNoThrow(try round.applyBet(.pass, by: round.betting.turn))
        XCTAssertNoThrow(try round.applyBet(.pass, by: round.betting.turn))
        while round.stage == .playout, let phase = round.playout, round.stacks.indices.contains(phase.leader) {
            guard let card = phase.hands[phase.leader].first else { return XCTFail("Führender ohne Karten") }
            XCTAssertNoThrow(try round.applyLead(card))
            if round.stage == .finished { break }
        }
        XCTAssertEqual(round.stage, .finished)
        XCTAssertTrue(round.stacks.allSatisfy { $0 >= 0 }, "Keine Schulden - Zahlungen sind gedeckelt")
        guard case .roundEnded(_, _, let payments)? = round.events.last else {
            return XCTFail("Runde endete ohne roundEnded-Event")
        }
        XCTAssertTrue(payments.allSatisfy { $0 >= 0 })
    }

    /// Invarianten-Fuzzer (Spec Abschnitt 14): Komplette Runden über viele Seeds mit
    /// zufälligen legalen Aktionen - die Chip-Summe (Stacks + Brett + offene Einsätze)
    /// bleibt nach jeder einzelnen Aktion konstant, jede Runde terminiert.
    func testFullRoundChipConservationAcrossSeeds() throws {
        for seed in UInt64(0)..<120 {
            var rng = SeededRNG(seed: seed)
            let playerCount = Int.random(in: 3...6, using: &rng)
            let stacks = (0..<playerCount).map { _ in Int.random(in: 9...60, using: &rng) }
            var carryBoard = Board()
            if Bool.random(using: &rng) {
                carryBoard.add(Int.random(in: 1...10, using: &rng), to: .mariage) // stehengebliebener Jackpot
                carryBoard.add(Int.random(in: 1...10, using: &rng), to: .poch)
            }
            let expectedTotal = stacks.reduce(0, +) + carryBoard.total

            var round = Round(stacks: stacks, board: carryBoard, seed: seed)
            XCTAssertEqual(round.totalChips, expectedTotal, "Seed \(seed): Erhaltung nach Setup verletzt")

            var steps = 0
            while round.stage != .finished {
                steps += 1
                XCTAssertLessThan(steps, 600, "Seed \(seed): Runde terminiert nicht")

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
                XCTAssertEqual(round.totalChips, expectedTotal, "Seed \(seed): Chip-Erhaltung nach Schritt \(steps) verletzt")
            }
            XCTAssertTrue(round.stacks.allSatisfy { $0 >= 0 }, "Seed \(seed): negativer Stack")
        }
    }
}
