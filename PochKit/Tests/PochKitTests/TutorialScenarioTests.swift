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

    private struct AppBotCatalog: Decodable {
        struct Entry: Decodable {
            let id: String
            let profile: BotProfile
        }

        struct TutorialSeat: Decodable {
            let opponentID: String
        }

        let profiles: [Entry]
        let tutorialLineup: [TutorialSeat]
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

    private func loadAppBotCatalog() throws -> AppBotCatalog {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot.appendingPathComponent("App/BotProfiles.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppBotCatalog.self, from: data)
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
        XCTAssertEqual(fourPlayer.round.deal.upcard, Card(suit: .diamonds, rank: .jack))
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
        XCTAssertEqual(melds.map(\.0), [0, 0, 0, 2, 3])
        XCTAssertEqual(melds.map(\.1), [.king, .queen, .mariage, .ten, .ace])
        XCTAssertEqual(melds.map(\.2), [4, 4, 4, 4, 4])
    }

    /// Die erste Lernreise bleibt eine einzige echte Runde. Ihr Meld-Seed muss daher
    /// auch den tatsächlichen Poch mit der kuratierten Besetzung und ein eigenes
    /// Anspiel tragen, statt beim Aktwechsel unbemerkt Hand oder Trumpf auszutauschen.
    func testFourPlayerMeldSeedCarriesTheCompleteFirstJourney() throws {
        let catalog = try loadCatalog()
        let botCatalog = try loadAppBotCatalog()
        let started = try startRound(
            playerCount: 4,
            seed: seed(for: .meld, playerCount: 4, catalog: catalog)
        )
        XCTAssertEqual(started.humanSeat, 0)

        let profilesByID = Dictionary(uniqueKeysWithValues:
            botCatalog.profiles.map { ($0.id, $0.profile) })
        let tutorialProfiles = try botCatalog.tutorialLineup.map { seat in
            try XCTUnwrap(profilesByID[seat.opponentID])
        }
        XCTAssertEqual(tutorialProfiles.count, 3)

        var round = started.round
        let opening = try XCTUnwrap(round.betting.legalActions(for: started.humanSeat)?.openRange)
        XCTAssertTrue(opening.contains(1))
        try round.applyBet(.open(1), by: started.humanSeat)

        var botRNG = SeededRNG(seed: 0xC0FFEE)
        var decisionCount = 0
        while round.stage == .betting, decisionCount < 32 {
            decisionCount += 1
            let player = round.betting.turn
            let legal = try XCTUnwrap(round.betting.legalActions(for: player))
            if player == started.humanSeat {
                try round.applyBet(legal.canCall ? .call : .pass, by: player)
                continue
            }

            let profile = tutorialProfiles[player - 1]
            _ = BotBrain.thinkSeconds(profile: profile, rng: &botRNG)
            let observation = try XCTUnwrap(round.botObservation(for: player))
            let action = BotBrain.action(profile: profile,
                                         observation: observation,
                                         legal: legal,
                                         rng: &botRNG)
            try round.applyBet(action, by: player)
        }

        XCTAssertLessThan(decisionCount, 32)
        XCTAssertEqual(round.stage, .playout)
        XCTAssertEqual(round.pochWinner, started.humanSeat)
        let bettingOutcome = try XCTUnwrap(round.events.compactMap { event -> BettingPhase.Outcome? in
            guard case .bettingEnded(let outcome) = event else { return nil }
            return outcome
        }.last)
        guard case .showdown(let players) = bettingOutcome else {
            return XCTFail("Die erste Lernreise muss den vollständigen Showdown lehren")
        }
        XCTAssertEqual(Set(players), Set(0..<4))
        let pochWin = try XCTUnwrap(round.events.compactMap { event -> Bool? in
            guard case .pochWon(_, _, _, let byShowdown) = event else { return nil }
            return byShowdown
        }.last)
        XCTAssertTrue(pochWin)
        let phase = try XCTUnwrap(round.playout)
        XCTAssertEqual(phase.leader, started.humanSeat)

        XCTAssertEqual(
            ComboEvaluator.best(
                in: round.deal.hands[started.humanSeat],
                trump: round.deal.trump
            ),
            Combo(kind: .triple, rank: .queen, containsTrump: true)
        )
        XCTAssertEqual(
            ComboEvaluator.best(in: round.deal.hands[1], trump: round.deal.trump),
            Combo(kind: .triple, rank: .eight, containsTrump: false)
        )

        var guidedChain = phase
        try guidedChain.lead(Card(suit: .hearts, rank: .jack))
        XCTAssertEqual(
            guidedChain.plays.map(\.card),
            [
                Card(suit: .hearts, rank: .jack),
                Card(suit: .hearts, rank: .queen),
                Card(suit: .hearts, rank: .king),
                Card(suit: .hearts, rank: .ace)
            ]
        )
        XCTAssertEqual(
            guidedChain.plays.map(\.player),
            [started.humanSeat, started.humanSeat, 3, started.humanSeat]
        )
        XCTAssertEqual(guidedChain.leader, started.humanSeat)
        XCTAssertGreaterThanOrEqual(
            guidedChain.hands[started.humanSeat].count,
            2,
            "Nach der erklärten Reihe braucht der Mensch eine echte neue Startwahl"
        )
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
