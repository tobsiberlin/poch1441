import Foundation

@main
struct OpponentRosterContractTests {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "App/BotProfiles.json"))
        let catalog = try OpponentRosterCatalog(data: data)

        try curatedTutorialLineupIsStable(catalog)
        try automaticSelectionIsDeterministicAndPublic(catalog)
        try manualSelectionPreservesStableSeats(catalog)
        try legacyBotProfileShapeStillDecodes(data)
        presentationDescriptorsExcludeHiddenState(catalog)

        FileHandle.standardOutput.write(Data("OpponentRosterContractTests: PASS\n".utf8))
    }

    private static func curatedTutorialLineupIsStable(_ catalog: OpponentRosterCatalog) throws {
        let lineup = try catalog.curatedTutorialLineup()
        expect(lineup.seats.map(\.id) == [.left, .across, .right],
               "Tutorial seats must keep their semantic order")
        expect(lineup.seats.map(\.opponent.displayName) == ["Hana", "Noah", "Jonas"],
               "Tutorial lineup must remain curated")
        expect(lineup.seats.allSatisfy {
            $0.opponent.publicTendency.disclosure == .afterFirstUnderstoodPochDecision
        }, "Tendencies must stay hidden until the first understood Poch decision")
        expect(lineup.seats.allSatisfy {
            $0.opponent.publicTendency.semantics == .aggregateObservation
        }, "A tendency must describe an aggregate observation")
    }

    private static func automaticSelectionIsDeterministicAndPublic(
        _ catalog: OpponentRosterCatalog
    ) throws {
        let first = try catalog.lineup(for: .automatic(seed: 1_441))
        let replay = try catalog.lineup(for: .automatic(seed: 1_441))
        expect(first == replay, "Automatic selection must replay from its presentation seed")
        expect(Set(first.seats.map(\.opponent.id)).count == 3,
               "Automatic selection must not duplicate an opponent")

        let next = try catalog.lineup(for: .automatic(
            seed: 1_441,
            excludingPrevious: Set(first.seats.map(\.opponent.id))
        ))
        expect(Set(first.seats.map(\.opponent.id)).isDisjoint(with: next.seats.map(\.opponent.id)),
               "Automatic selection should prefer opponents outside the previous lineup")
    }

    private static func manualSelectionPreservesStableSeats(_ catalog: OpponentRosterCatalog) throws {
        let ids = catalog.manualSelectionOptions.prefix(3).map(\.id)
        let lineup = try catalog.lineup(for: .manual(ids))
        expect(lineup.seats.map(\.id) == [.left, .across, .right],
               "Manual selection must use the same stable seats as automatic selection")
        expect(lineup.seats.map(\.opponent.id) == ids,
               "Manual selection order must map directly onto semantic seats")

        do {
            _ = try catalog.lineup(for: .manual([ids[0], ids[0], ids[1]]))
            fail("Duplicate manual opponents must be rejected")
        } catch let error as OpponentRosterError {
            guard case .duplicateOpponent(ids[0]) = error else {
                fail("Unexpected duplicate selection error: \(error)")
            }
        }
    }

    private static func legacyBotProfileShapeStillDecodes(_ data: Data) throws {
        struct LegacyCatalog: Decodable {
            struct Entry: Decodable {
                struct Profile: Decodable {
                    let openAggression: Double
                    let bluffFrequency: Double
                    let riskTolerance: Double
                    let raiseAggression: Double
                    let thinkSecondsMin: Double
                    let thinkSecondsMax: Double
                }

                let name: String
                let profile: Profile
            }

            let version: Int
            let profiles: [Entry]
        }

        let legacy = try JSONDecoder().decode(LegacyCatalog.self, from: data)
        expect(legacy.version == 1, "GameState currently requires BotProfiles version 1")
        expect(legacy.profiles.count == 11, "All existing behavior profiles must remain available")
        expect(legacy.profiles.allSatisfy { !$0.name.isEmpty }, "Legacy names must remain readable")
    }

    private static func presentationDescriptorsExcludeHiddenState(_ catalog: OpponentRosterCatalog) {
        let forbiddenFragments = ["hand", "strength", "card", "action", "trump"]
        for descriptor in catalog.manualSelectionOptions {
            let labels = Mirror(reflecting: descriptor).children.compactMap(\.label)
            expect(labels.allSatisfy { label in
                forbiddenFragments.allSatisfy { !label.lowercased().contains($0) }
            }, "Presentation descriptor must not expose hidden or per-action state")
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("OpponentRosterContractTests: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
