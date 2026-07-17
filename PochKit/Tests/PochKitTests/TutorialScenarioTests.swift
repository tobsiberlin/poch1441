import Foundation
import XCTest
@testable import PochKit

final class TutorialScenarioTests: XCTestCase {
    private enum LessonID: String, CaseIterable, Decodable, Hashable {
        case meld
        case bidding
        case playout
    }

    private struct Catalog: Decodable {
        struct Lesson: Decodable {
            let id: LessonID
            let seeds: [String: UInt64]
        }

        let version: Int
        let lessons: [Lesson]
    }

    /// Der Test liest bewusst dieselbe Build-Time-Quelle wie die App. `#filePath` hält
    /// die Auflösung unabhängig vom Arbeitsverzeichnis von Xcode und `swift test`.
    private func loadCatalog() throws -> Catalog {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PochKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // PochKit
            .deletingLastPathComponent() // Repository
        let url = repositoryRoot.appendingPathComponent("App/TutorialScenarios.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Catalog.self, from: data)
    }

    private func seed(
        for lessonID: LessonID,
        playerCount: Int,
        catalog: Catalog,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> UInt64 {
        let lesson = try XCTUnwrap(
            catalog.lessons.first(where: { $0.id == lessonID }),
            "Tutorial-Lektion \(lessonID.rawValue) fehlt",
            file: file,
            line: line
        )
        return try XCTUnwrap(
            lesson.seeds[String(playerCount)],
            "Tutorial-Lektion \(lessonID.rawValue) hat keinen Seed für \(playerCount) Spieler",
            file: file,
            line: line
        )
    }

    private func startRound(playerCount: Int, seed: UInt64) throws -> (round: Round, humanSeat: Int) {
        var match = Match(
            playerCount: playerCount,
            startingStack: 60,
            mode: .quick(roundLimit: 12),
            firstDealer: playerCount - 1
        )
        let started = try XCTUnwrap(match.startRound(seed: seed))
        let humanSeat = try XCTUnwrap(started.tableSeats.firstIndex(of: 0))
        return (started.round, humanSeat)
    }

    func testCatalogIsVersionedUniqueAndComplete() throws {
        let catalog = try loadCatalog()

        XCTAssertEqual(catalog.version, 1)
        XCTAssertEqual(catalog.lessons.count, LessonID.allCases.count)
        XCTAssertEqual(Set(catalog.lessons.map(\.id)), Set(LessonID.allCases))
        for lesson in catalog.lessons {
            XCTAssertEqual(
                Set(lesson.seeds.keys),
                Set(["3", "4"]),
                "\(lesson.id.rawValue) muss die kanonischen Drei- und Vierer-Seeds enthalten"
            )
        }
    }

    /// Die Meldungs-Seeds garantieren eine frühe Auszahlung an den Menschen. Karten,
    /// Reihenfolge und Auszahlung stammen ausschließlich aus `Round` und `Melding`.
    func testMeldSeedsStartWithCanonicalHumanRewards() throws {
        let catalog = try loadCatalog()

        let threePlayer = try startRound(
            playerCount: 3,
            seed: seed(for: .meld, playerCount: 3, catalog: catalog)
        )
        XCTAssertEqual(threePlayer.humanSeat, 0, "Der Mensch sitzt links vom Geber")
        XCTAssertEqual(
            Melding.pools(
                for: threePlayer.round.deal.hands[threePlayer.humanSeat],
                upcard: threePlayer.round.deal.upcard
            ),
            [.jack, .ten]
        )
        XCTAssertEqual(firstMeldPlayer(in: threePlayer.round), threePlayer.humanSeat)

        let fourPlayer = try startRound(
            playerCount: 4,
            seed: seed(for: .meld, playerCount: 4, catalog: catalog)
        )
        XCTAssertEqual(fourPlayer.humanSeat, 0, "Der Mensch sitzt links vom Geber")
        XCTAssertEqual(fourPlayer.round.deal.upcard, Card(suit: .hearts, rank: .jack))
        XCTAssertEqual(
            Melding.pools(
                for: fourPlayer.round.deal.hands[fourPlayer.humanSeat],
                upcard: fourPlayer.round.deal.upcard
            ),
            [.king, .queen, .mariage]
        )
        XCTAssertEqual(firstMeldPlayer(in: fourPlayer.round), fourPlayer.humanSeat)

        let melds = fourPlayer.round.events.compactMap { event -> (Int, Pool, Int)? in
            guard case .melded(let player, let pool, let chips) = event else { return nil }
            return (player, pool, chips)
        }
        XCTAssertEqual(melds.map(\.0), [0, 0, 0, 3, 3])
        XCTAssertEqual(melds.map(\.1), [.king, .queen, .mariage, .ace, .ten])
        XCTAssertEqual(melds.map(\.2), [4, 4, 4, 4, 4])
    }

    /// Der Poch-Seed muss den Menschen am ersten Zug regelkonform eröffnen lassen. Der Test
    /// fragt dafür ausschließlich `BettingPhase.legalActions` und bewertet keine UI-Grenzen.
    func testBiddingSeedsGiveHumanTheFirstLegalOpening() throws {
        let catalog = try loadCatalog()

        for playerCount in [3, 4] {
            let started = try startRound(
                playerCount: playerCount,
                seed: seed(for: .bidding, playerCount: playerCount, catalog: catalog)
            )
            let round = started.round
            let legal = try XCTUnwrap(round.betting.legalActions(for: started.humanSeat))

            XCTAssertEqual(round.betting.turn, started.humanSeat)
            XCTAssertTrue(round.betting.seats[started.humanSeat].mayBid)
            XCTAssertTrue(legal.canPass)
            XCTAssertTrue(try XCTUnwrap(legal.openRange).contains(1))
            XCTAssertFalse(legal.canCall)
            XCTAssertNil(legal.raiseRange)
        }
    }

    /// Das Ausspiel-Tutorial überspringt Pochen durch legale Pässe. Danach führt der Mensch
    /// und der Seed bietet mindestens ein Anspiel, das eine echte Zwangskette samt Riss erzeugt.
    func testPlayoutSeedsReachAHumanLedChainAndBreak() throws {
        let catalog = try loadCatalog()

        for playerCount in [3, 4] {
            var started = try startRound(
                playerCount: playerCount,
                seed: seed(for: .playout, playerCount: playerCount, catalog: catalog)
            )
            while started.round.stage == .betting {
                try started.round.applyBet(.pass, by: started.round.betting.turn)
            }

            XCTAssertEqual(started.round.stage, .playout)
            XCTAssertEqual(started.round.pochWinner, nil)
            let phase = try XCTUnwrap(started.round.playout)
            XCTAssertEqual(phase.leader, started.humanSeat)

            let chainAfterBreak = phase.hands[started.humanSeat].lazy.compactMap { card -> PlayoutPhase? in
                var candidate = phase
                try? candidate.lead(card)
                guard candidate.winner == nil,
                      candidate.plays.count > 1,
                      candidate.leader == candidate.plays.last?.player
                else { return nil }
                return candidate
            }.first
            let verifiedChain = try XCTUnwrap(
                chainAfterBreak,
                "Seed muss eine sichtbare Zwangskette mit anschließendem neuen Anspiel liefern"
            )
            XCTAssertTrue(verifiedChain.plays[0].isLead)
            XCTAssertTrue(verifiedChain.plays.dropFirst().allSatisfy { !$0.isLead })
        }
    }

    private func firstMeldPlayer(in round: Round) -> Int? {
        round.events.compactMap { event -> Int? in
            guard case .melded(let player, _, _) = event else { return nil }
            return player
        }.first
    }
}
