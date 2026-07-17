import XCTest
@testable import PochKit

final class TutorialScenarioTests: XCTestCase {
    /// Datenvertrag aus `App/TutorialScenarios.json`: Auch der Drei-Personen-Fallback
    /// muss aus unveränderten Poch-Regeln eine frühe, vom Menschen begonnene Meldung
    /// liefern. Der Test pinnt keine UI-Erzählung, sondern nur die Engine-Wahrheit des Seeds.
    func testThreePlayerMeldSeedStartsWithHumanRewardFromRoundRules() throws {
        let seed: UInt64 = 1_444
        var match = Match(
            playerCount: 3,
            startingStack: 60,
            mode: .quick(roundLimit: 12),
            firstDealer: 2
        )
        let started = try XCTUnwrap(match.startRound(seed: seed))
        let humanRoundSeat = try XCTUnwrap(started.tableSeats.firstIndex(of: 0))

        XCTAssertEqual(started.tableSeats, [0, 1, 2])
        XCTAssertEqual(humanRoundSeat, 0, "Der Mensch meldet zuerst, links vom Geber")

        let humanPools = Melding.pools(
            for: started.round.deal.hands[humanRoundSeat],
            upcard: started.round.deal.upcard
        )
        XCTAssertEqual(humanPools, [.jack, .ten], "Seed 1444 muss eine frühe Meldung garantieren")

        let firstMeldPlayer = started.round.events.compactMap { event -> Int? in
            guard case .melded(let player, _, _) = event else { return nil }
            return player
        }.first
        XCTAssertEqual(firstMeldPlayer, humanRoundSeat)
    }

    /// Tutorialvertrag aus Spec Abschnitt 8: Am Vierertisch hält der Mensch in Runde 1
    /// echte Trumpf-Honors plus Mariage. Die Auszahlungen entstehen ausschließlich aus
    /// dem normalen Round-Setup und beginnen beim Menschen links vom Geber.
    func testFourPlayerMeldSeedStartsWithHumanMariageFromRoundRules() throws {
        let seed: UInt64 = 19
        var match = Match(
            playerCount: 4,
            startingStack: 60,
            mode: .quick(roundLimit: 12),
            firstDealer: 3
        )
        let started = try XCTUnwrap(match.startRound(seed: seed))
        let humanRoundSeat = try XCTUnwrap(started.tableSeats.firstIndex(of: 0))

        XCTAssertEqual(started.tableSeats, [0, 1, 2, 3])
        XCTAssertEqual(humanRoundSeat, 0, "Der Mensch meldet zuerst, links vom Geber")
        XCTAssertEqual(started.round.deal.upcard, Card(suit: .hearts, rank: .jack))

        let humanHand = started.round.deal.hands[humanRoundSeat]
        XCTAssertTrue(humanHand.contains(Card(suit: .hearts, rank: .king)))
        XCTAssertTrue(humanHand.contains(Card(suit: .hearts, rank: .queen)))
        XCTAssertEqual(
            Melding.pools(for: humanHand, upcard: started.round.deal.upcard),
            [.king, .queen, .mariage]
        )

        let melds = started.round.events.compactMap { event -> (player: Int, pool: Pool, chips: Int)? in
            guard case .melded(let player, let pool, let chips) = event else { return nil }
            return (player, pool, chips)
        }
        XCTAssertEqual(melds.count, 5)
        XCTAssertEqual(melds[0].player, humanRoundSeat)
        XCTAssertEqual(melds[0].pool, .king)
        XCTAssertEqual(melds[0].chips, 4)
        XCTAssertEqual(melds[1].player, humanRoundSeat)
        XCTAssertEqual(melds[1].pool, .queen)
        XCTAssertEqual(melds[1].chips, 4)
        XCTAssertEqual(melds[2].player, humanRoundSeat)
        XCTAssertEqual(melds[2].pool, .mariage)
        XCTAssertEqual(melds[2].chips, 4)
        XCTAssertEqual(melds[3].player, 3)
        XCTAssertEqual(melds[3].pool, .ace)
        XCTAssertEqual(melds[3].chips, 4)
        XCTAssertEqual(melds[4].player, 3)
        XCTAssertEqual(melds[4].pool, .ten)
        XCTAssertEqual(melds[4].chips, 4)
    }
}
