import Foundation

@main
struct OpponentRosterContractTests {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "App/BotProfiles.json"))
        let catalog = try OpponentRosterCatalog(data: data)

        try curatedTutorialLineupIsStable(catalog)
        try automaticSelectionIsDeterministicAndPublic(catalog)
        try manualSelectionPreservesStableSeats(catalog)
        try malformedTutorialDataFailsClosed(data)
        try invalidPresentationMetadataFailsClosed(data)
        try legacyBotProfileShapeStillDecodes(data)
        try publicTendencyIDsRemainFiniteAndConsistent(data)
        try firstUnderstoodDecisionDisclosesExactlyOneTendency(catalog)
        try unknownDecisionActorFailsClosed(catalog)
        presentationDescriptorsExcludeHiddenState(catalog)
        automaticSelectionInputExcludesGameState()

        FileHandle.standardOutput.write(Data("OpponentRosterContractTests: PASS\n".utf8))
    }

    private static func curatedTutorialLineupIsStable(_ catalog: OpponentRosterCatalog) throws {
        let lineup = try catalog.curatedTutorialLineup()
        expect(lineup.seats.map(\.id) == [.left, .across, .right],
               "Tutorial seats must keep their semantic order")
        expect(lineup.seats.map(\.opponent.id.rawValue) == ["hana", "noah", "jonas"],
               "Tutorial identities must remain Hana, Noah and Jonas from BotProfiles.json")
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

    private static func malformedTutorialDataFailsClosed(_ data: Data) throws {
        let payload = try jsonObject(data)

        var missingSeat = payload
        missingSeat["tutorialLineup"] = [
            ["seatID": "left", "opponentID": "hana"],
            ["seatID": "across", "opponentID": "noah"],
        ]
        expectRosterError(.incompleteTutorialSeats, payload: missingSeat)

        var unknownOpponent = payload
        unknownOpponent["tutorialLineup"] = [
            ["seatID": "left", "opponentID": "hana"],
            ["seatID": "across", "opponentID": "noah"],
            ["seatID": "right", "opponentID": "unknown"],
        ]
        expectRosterError(.unknownOpponent(OpponentID(rawValue: "unknown")),
                          payload: unknownOpponent)

        var duplicateOpponent = payload
        duplicateOpponent["tutorialLineup"] = [
            ["seatID": "left", "opponentID": "hana"],
            ["seatID": "across", "opponentID": "noah"],
            ["seatID": "right", "opponentID": "hana"],
        ]
        expectRosterError(.duplicateTutorialOpponent(OpponentID(rawValue: "hana")),
                          payload: duplicateOpponent)
    }

    private static func invalidPresentationMetadataFailsClosed(_ data: Data) throws {
        let payload = try jsonObject(data)

        var duplicateName = payload
        var profiles = duplicateName["profiles"] as? [[String: Any]] ?? []
        guard profiles.count >= 2 else { fail("Fixture must contain at least two profiles") }
        profiles[1]["name"] = profiles[0]["name"]
        duplicateName["profiles"] = profiles
        expectRosterError(.duplicateDisplayName("Liv"), payload: duplicateName)

        var insufficientCandidates = payload
        profiles = insufficientCandidates["profiles"] as? [[String: Any]] ?? []
        for index in profiles.indices {
            profiles[index]["automaticEligible"] = index < 2
        }
        insufficientCandidates["profiles"] = profiles
        expectRosterError(.insufficientAutomaticCandidates, payload: insufficientCandidates)
    }

    private static func publicTendencyIDsRemainFiniteAndConsistent(_ data: Data) throws {
        let payload = try jsonObject(data)
        var profiles = payload["profiles"] as? [[String: Any]] ?? []
        guard !profiles.isEmpty else { fail("Fixture must contain public tendencies") }

        var unsupported = payload
        var unsupportedProfiles = profiles
        var tendency = unsupportedProfiles[0]["publicTendency"] as? [String: Any] ?? [:]
        tendency["id"] = "hiddenConfidence"
        unsupportedProfiles[0]["publicTendency"] = tendency
        unsupported["profiles"] = unsupportedProfiles
        expectRosterError(
            .unsupportedPublicTendencyID(OpponentID(rawValue: "liv"), "hiddenConfidence"),
            payload: unsupported
        )

        var inconsistent = payload
        tendency = profiles[0]["publicTendency"] as? [String: Any] ?? [:]
        tendency["basis"] = PublicTendencyBasis.observedUnopenedRoundInitiative.rawValue
        profiles[0]["publicTendency"] = tendency
        inconsistent["profiles"] = profiles
        expectRosterError(
            .inconsistentPublicTendencyBasis(
                OpponentID(rawValue: "liv"),
                expected: .observedDecisionTempo,
                actual: .observedUnopenedRoundInitiative
            ),
            payload: inconsistent
        )
    }

    private static func firstUnderstoodDecisionDisclosesExactlyOneTendency(
        _ catalog: OpponentRosterCatalog
    ) throws {
        let lineup = try catalog.curatedTutorialLineup()
        let noahID = OpponentID(rawValue: "noah")
        let jonasID = OpponentID(rawValue: "jonas")
        var session = OpponentTendencyDisclosureSession()

        expect(session.currentDisclosure(in: lineup) == nil,
               "A tendency must be absent before the understood-decision milestone")

        let first = session.discloseAfterUnderstandingFirstPochDecision(
            madeBy: noahID,
            in: lineup
        )
        expect(first?.opponentID == noahID,
               "The learning beat must explain the publicly observed actor")
        expect(first?.titleLocalizationKey == "opponent.tendency.variablePace.title",
               "Disclosure must use the approved tendency title key")
        expect(first?.summaryLocalizationKey == "opponent.tendency.variablePace.summary",
               "Disclosure must use the approved tendency summary key")
        expect(first?.caveatLocalizationKey == "opponent.tendency.caveat",
               "Every disclosure must carry the non-promise caveat")

        let repeated = session.discloseAfterUnderstandingFirstPochDecision(
            madeBy: jonasID,
            in: lineup
        )
        expect(repeated == nil,
               "A later decision must not replace the one optional learning beat")
        expect(session.currentDisclosure(in: lineup) == first,
               "The disclosed tendency must remain stable across rerenders")

        guard let first else { fail("The first understood decision must disclose a tendency") }
        let disclosureLabels = Set(Mirror(reflecting: first).children.compactMap(\.label))
        expect(disclosureLabels == ["opponentID", "opponentDisplayName", "tendency"],
               "Disclosure payload must contain only approved public presentation data")
    }

    private static func unknownDecisionActorFailsClosed(
        _ catalog: OpponentRosterCatalog
    ) throws {
        let lineup = try catalog.curatedTutorialLineup()
        var session = OpponentTendencyDisclosureSession()
        let disclosure = session.discloseAfterUnderstandingFirstPochDecision(
            madeBy: OpponentID(rawValue: "unknown"),
            in: lineup
        )

        expect(disclosure == nil, "An unknown public actor must not disclose metadata")
        expect(session.disclosedOpponentID == nil,
               "A rejected actor must not consume the one-shot disclosure")
    }

    private static func presentationDescriptorsExcludeHiddenState(_ catalog: OpponentRosterCatalog) {
        for descriptor in catalog.manualSelectionOptions {
            let descriptorLabels = Set(Mirror(reflecting: descriptor).children.compactMap(\.label))
            expect(descriptorLabels == ["id", "displayName", "portraitAssetPrefix", "publicTendency"],
                   "Presentation descriptor must contain only approved public metadata")

            let tendencyLabels = Set(
                Mirror(reflecting: descriptor.publicTendency).children.compactMap(\.label)
            )
            expect(tendencyLabels == ["id", "basis", "disclosure", "semantics"],
                   "A public tendency must not gain hidden or per-action state")
        }
    }

    private static func automaticSelectionInputExcludesGameState() {
        let selection = OpponentSelection.automatic(
            seed: 1_441,
            excludingPrevious: [OpponentID(rawValue: "hana")]
        )
        guard let payload = Mirror(reflecting: selection).children.first?.value else {
            fail("Automatic selection must expose a typed payload")
        }
        let fields = Dictionary(uniqueKeysWithValues: Mirror(reflecting: payload).children.compactMap {
            child -> (String, Any)? in
            guard let label = child.label else { return nil }
            return (label, child.value)
        })
        expect(Set(fields.keys) == ["seed", "excludingPrevious"],
               "Automatic selection may depend only on a presentation seed and prior opponent IDs")
        expect(fields["seed"] is UInt64,
               "Automatic selection seed must remain independent of game-state types")
        expect(fields["excludingPrevious"] is Set<OpponentID>,
               "Automatic exclusions must contain only stable opponent IDs")
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            fail("BotProfiles fixture must be a JSON object")
        }
        return payload
    }

    private static func expectRosterError(_ expected: OpponentRosterError,
                                          payload: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            _ = try OpponentRosterCatalog(data: data)
            fail("Malformed roster must fail closed with \(expected)")
        } catch let error as OpponentRosterError {
            expect(error == expected, "Expected \(expected), received \(error)")
        } catch {
            fail("Expected OpponentRosterError, received \(error)")
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
