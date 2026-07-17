import Foundation

/// Stable identity for an opponent. Unlike a table index, this value survives orientation,
/// phase and dealer changes.
struct OpponentID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Semantic seats used by every First-Run composition. Layout code may move the visual
/// coordinates, but it must never reinterpret these identities between orientations.
enum StableOpponentSeatID: String, Codable, CaseIterable, Sendable {
    case left
    case across
    case right

    var uiSeatIndex: Int {
        switch self {
        case .left: 1
        case .across: 2
        case .right: 3
        }
    }
}

/// The only evidence classes a player-facing tendency may describe. Both are observable
/// over several public decisions and structurally exclude cards, hand strength and tells.
enum PublicTendencyBasis: String, Codable, Sendable {
    case observedDecisionTempo
    case observedUnopenedRoundInitiative
}

/// A tendency is deliberately an aggregate observation, never a promise about the next
/// action. Copy lives in the localization catalog and must preserve that probabilistic tone.
struct PublicOpponentTendency: Codable, Equatable, Sendable {
    enum Disclosure: String, Codable, Sendable {
        case afterFirstUnderstoodPochDecision
    }

    enum Semantics: String, Codable, Sendable {
        case aggregateObservation
    }

    let id: String
    let basis: PublicTendencyBasis
    let disclosure: Disclosure
    let semantics: Semantics

    var titleLocalizationKey: String {
        "opponent.tendency.\(id).title"
    }

    var summaryLocalizationKey: String {
        "opponent.tendency.\(id).summary"
    }
}

/// Presentation-safe opponent metadata. It intentionally does not expose BotProfile or any
/// round state, so the selection and tutorial layers cannot derive information from a hand.
struct OpponentDescriptor: Equatable, Sendable {
    let id: OpponentID
    let displayName: String
    let portraitAssetPrefix: String
    let publicTendency: PublicOpponentTendency
}

struct OpponentSeat: Equatable, Sendable {
    let id: StableOpponentSeatID
    let opponent: OpponentDescriptor

    var uiSeatIndex: Int { id.uiSeatIndex }
}

struct OpponentLineup: Equatable, Sendable {
    let seats: [OpponentSeat]

    func opponent(at seatID: StableOpponentSeatID) -> OpponentDescriptor? {
        seats.first(where: { $0.id == seatID })?.opponent
    }
}

enum OpponentSelection: Equatable, Sendable {
    /// Standard for free play. The seed comes from presentation/session state, never from
    /// cards or another hidden gameplay value.
    case automatic(seed: UInt64, excludingPrevious: Set<OpponentID> = [])
    /// Optional advanced path. UI should present this only when the player explicitly asks.
    case manual([OpponentID])
}

enum OpponentRosterError: Error, Equatable {
    case unsupportedVersion(Int)
    case duplicateOpponent(OpponentID)
    case duplicateTutorialSeat(StableOpponentSeatID)
    case duplicateTutorialOpponent(OpponentID)
    case incompleteTutorialSeats
    case unknownOpponent(OpponentID)
    case invalidManualCount(expected: Int, actual: Int)
    case insufficientAutomaticCandidates
}

/// Data-driven roster resolver for the Lead track. It has three narrow integration hooks:
/// `curatedTutorialLineup()`, `lineup(for:)` and `manualSelectionOptions`.
struct OpponentRosterCatalog: Sendable {
    private struct Payload: Decodable {
        struct Profile: Decodable {
            let id: OpponentID
            let name: String
            let portraitAssetPrefix: String
            let automaticEligible: Bool
            let publicTendency: PublicOpponentTendency
        }

        struct TutorialSeat: Decodable {
            let seatID: StableOpponentSeatID
            let opponentID: OpponentID
        }

        let version: Int
        let profiles: [Profile]
        let tutorialLineup: [TutorialSeat]
    }

    private let descriptorsByID: [OpponentID: OpponentDescriptor]
    private let orderedDescriptors: [OpponentDescriptor]
    private let automaticCandidateIDs: [OpponentID]
    private let tutorialSeats: [(StableOpponentSeatID, OpponentID)]

    init(data: Data, decoder: JSONDecoder = JSONDecoder()) throws {
        let payload = try decoder.decode(Payload.self, from: data)
        guard payload.version == 1 else {
            throw OpponentRosterError.unsupportedVersion(payload.version)
        }

        var descriptorsByID: [OpponentID: OpponentDescriptor] = [:]
        var orderedDescriptors: [OpponentDescriptor] = []
        var automaticCandidateIDs: [OpponentID] = []
        for profile in payload.profiles {
            guard descriptorsByID[profile.id] == nil else {
                throw OpponentRosterError.duplicateOpponent(profile.id)
            }
            let descriptor = OpponentDescriptor(
                id: profile.id,
                displayName: profile.name,
                portraitAssetPrefix: profile.portraitAssetPrefix,
                publicTendency: profile.publicTendency
            )
            descriptorsByID[profile.id] = descriptor
            orderedDescriptors.append(descriptor)
            if profile.automaticEligible {
                automaticCandidateIDs.append(profile.id)
            }
        }

        var seenSeats: Set<StableOpponentSeatID> = []
        var seenOpponents: Set<OpponentID> = []
        var tutorialSeats: [(StableOpponentSeatID, OpponentID)] = []
        for seat in payload.tutorialLineup {
            guard seenSeats.insert(seat.seatID).inserted else {
                throw OpponentRosterError.duplicateTutorialSeat(seat.seatID)
            }
            guard seenOpponents.insert(seat.opponentID).inserted else {
                throw OpponentRosterError.duplicateTutorialOpponent(seat.opponentID)
            }
            guard descriptorsByID[seat.opponentID] != nil else {
                throw OpponentRosterError.unknownOpponent(seat.opponentID)
            }
            tutorialSeats.append((seat.seatID, seat.opponentID))
        }
        guard seenSeats == Set(StableOpponentSeatID.allCases) else {
            throw OpponentRosterError.incompleteTutorialSeats
        }

        self.descriptorsByID = descriptorsByID
        self.orderedDescriptors = orderedDescriptors
        self.automaticCandidateIDs = automaticCandidateIDs
        self.tutorialSeats = tutorialSeats
    }

    var manualSelectionOptions: [OpponentDescriptor] {
        orderedDescriptors
    }

    func curatedTutorialLineup() throws -> OpponentLineup {
        try makeLineup(tutorialSeats)
    }

    func lineup(for selection: OpponentSelection) throws -> OpponentLineup {
        switch selection {
        case let .automatic(seed, excludingPrevious):
            return try automaticLineup(seed: seed, excludingPrevious: excludingPrevious)
        case let .manual(opponentIDs):
            guard opponentIDs.count == StableOpponentSeatID.allCases.count else {
                throw OpponentRosterError.invalidManualCount(
                    expected: StableOpponentSeatID.allCases.count,
                    actual: opponentIDs.count
                )
            }
            guard Set(opponentIDs).count == opponentIDs.count else {
                let duplicate = opponentIDs.first(where: { id in
                    opponentIDs.filter { $0 == id }.count > 1
                }) ?? opponentIDs[0]
                throw OpponentRosterError.duplicateOpponent(duplicate)
            }
            return try makeLineup(Array(zip(StableOpponentSeatID.allCases, opponentIDs)))
        }
    }

    private func automaticLineup(seed: UInt64,
                                 excludingPrevious: Set<OpponentID>) throws -> OpponentLineup {
        let seatCount = StableOpponentSeatID.allCases.count
        guard automaticCandidateIDs.count >= seatCount else {
            throw OpponentRosterError.insufficientAutomaticCandidates
        }

        var picker = DeterministicOpponentPicker(seed: seed)
        var candidates = automaticCandidateIDs
        picker.shuffle(&candidates)

        var selected = Array(candidates.filter { !excludingPrevious.contains($0) }.prefix(seatCount))
        if selected.count < seatCount {
            selected.append(contentsOf: candidates.filter(excludingPrevious.contains).prefix(seatCount - selected.count))
        }
        return try makeLineup(Array(zip(StableOpponentSeatID.allCases, selected)))
    }

    private func makeLineup(_ assignments: [(StableOpponentSeatID, OpponentID)]) throws -> OpponentLineup {
        let seats = try assignments.map { seatID, opponentID in
            guard let descriptor = descriptorsByID[opponentID] else {
                throw OpponentRosterError.unknownOpponent(opponentID)
            }
            return OpponentSeat(id: seatID, opponent: descriptor)
        }
        return OpponentLineup(seats: seats.sorted { $0.uiSeatIndex < $1.uiSeatIndex })
    }
}

private struct DeterministicOpponentPicker {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func shuffle<Element>(_ values: inout [Element]) {
        guard values.count > 1 else { return }
        for index in stride(from: values.count - 1, through: 1, by: -1) {
            let swapIndex = Int(next() % UInt64(index + 1))
            values.swapAt(index, swapIndex)
        }
    }

    private mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
