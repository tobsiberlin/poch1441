import Foundation

enum CoinTransferLifecycle: Int, CaseIterable, Equatable, Hashable, Sendable {
    case prepared
    case departed
    case airborne
    case impacted
    case settling
    case completed
    case cancelled
}

struct CoinTransferIdentity: Equatable, Hashable, Sendable {
    let eventID: String
    let generation: Int
}

enum CoinTransferMotionPreference: Equatable, Hashable, Sendable {
    case standard
    case reduceMotion
}

enum CoinTransferPresentationBeat: Equatable, Hashable, Sendable {
    case sourceEmphasis
    case spatialFlight
    case targetEmphasis
    case crossfade
    case materialContact
    case settle
}

enum CoinTransferGateResult: Equatable, Hashable, Sendable {
    case accepted
    case stale
    case duplicate
    case cancelled
    case invalidTransition
}

/// Named concurrency policy for renderer-owned flights. It contains no economy or
/// game-rule values and can therefore be shared by every coin transfer source.
struct CoinTransferPolicy: Equatable, Hashable, Sendable {
    static let standard = CoinTransferPolicy(
        maxConcurrentFlights: Defaults.maxConcurrentFlights
    )

    let maxConcurrentFlights: Int

    var isValid: Bool {
        maxConcurrentFlights > 0
    }

    private enum Defaults {
        static let maxConcurrentFlights = 2
    }
}

struct CoinTransferScheduleEntry: Equatable, Hashable, Sendable {
    let identity: CoinTransferIdentity
    let sequence: Int
    let waveIndex: Int
    let laneIndex: Int
}

/// Deterministically partitions caller-owned event IDs into bounded flight waves.
/// Input order is the only ordering source; clocks, randomness and game state are absent.
struct CoinTransferPlan: Equatable, Sendable {
    let policy: CoinTransferPolicy
    let motionPreference: CoinTransferMotionPreference
    let entries: [CoinTransferScheduleEntry]

    var presentationBeats: [CoinTransferPresentationBeat] {
        switch motionPreference {
        case .standard:
            return [.sourceEmphasis, .spatialFlight, .materialContact, .settle]
        case .reduceMotion:
            return [.sourceEmphasis, .targetEmphasis, .crossfade, .materialContact, .settle]
        }
    }

    /// Reduce Motion has no flight timer to await. Its complete transaction runs
    /// synchronously through the same logical lifecycle and contact gate.
    var requiresFlightWait: Bool {
        motionPreference == .standard && !entries.isEmpty
    }

    init(
        eventIDs: [String],
        generation: Int,
        motionPreference: CoinTransferMotionPreference,
        policy: CoinTransferPolicy = .standard
    ) {
        self.policy = policy
        self.motionPreference = motionPreference

        guard policy.isValid,
              eventIDs.allSatisfy({ !$0.isEmpty }),
              Set(eventIDs).count == eventIDs.count else {
            entries = []
            return
        }

        entries = eventIDs.enumerated().map { sequence, eventID in
            CoinTransferScheduleEntry(
                identity: CoinTransferIdentity(eventID: eventID, generation: generation),
                sequence: sequence,
                waveIndex: sequence / policy.maxConcurrentFlights,
                laneIndex: sequence % policy.maxConcurrentFlights
            )
        }
    }

    func entries(inWave waveIndex: Int) -> [CoinTransferScheduleEntry] {
        entries.filter { $0.waveIndex == waveIndex }
    }
}

/// Generation-bound, rule-neutral lifecycle for one physical coin transfer.
/// The caller's atomic state mutation belongs exclusively in `registerImpact`.
struct CoinTransferTransaction: Equatable, Sendable {
    let identity: CoinTransferIdentity
    let motionPreference: CoinTransferMotionPreference
    private(set) var lifecycle: CoinTransferLifecycle = .prepared

    init(
        eventID: String,
        generation: Int,
        motionPreference: CoinTransferMotionPreference
    ) {
        identity = CoinTransferIdentity(eventID: eventID, generation: generation)
        self.motionPreference = motionPreference
    }

    @discardableResult
    mutating func depart(eventID: String, generation: Int) -> CoinTransferGateResult {
        transition(
            identity: CoinTransferIdentity(eventID: eventID, generation: generation),
            from: .prepared,
            to: .departed
        )
    }

    @discardableResult
    mutating func enterAirborne(eventID: String, generation: Int) -> CoinTransferGateResult {
        transition(
            identity: CoinTransferIdentity(eventID: eventID, generation: generation),
            from: .departed,
            to: .airborne
        )
    }

    /// Runs `applyAtomically` exactly once, and only for the matching airborne event.
    /// The non-throwing closure and lifecycle mutation share one synchronous call, so
    /// no await or animation callback can interleave between impact and its gate.
    @discardableResult
    mutating func registerImpact(
        eventID: String,
        generation: Int,
        applyAtomically: () -> Void
    ) -> CoinTransferGateResult {
        let candidate = CoinTransferIdentity(eventID: eventID, generation: generation)
        guard candidate == identity else { return .stale }

        switch lifecycle {
        case .airborne:
            applyAtomically()
            lifecycle = .impacted
            return .accepted
        case .impacted, .settling, .completed:
            return .duplicate
        case .cancelled:
            return .cancelled
        case .prepared, .departed:
            return .invalidTransition
        }
    }

    @discardableResult
    mutating func beginSettling(eventID: String, generation: Int) -> CoinTransferGateResult {
        transition(
            identity: CoinTransferIdentity(eventID: eventID, generation: generation),
            from: .impacted,
            to: .settling
        )
    }

    @discardableResult
    mutating func complete(eventID: String, generation: Int) -> CoinTransferGateResult {
        transition(
            identity: CoinTransferIdentity(eventID: eventID, generation: generation),
            from: .settling,
            to: .completed
        )
    }

    /// Performs the logical departure, flight, impact, settling and completion in one
    /// synchronous pass. No invisible flight or settling delay survives Reduce Motion.
    @discardableResult
    mutating func performReducedMotionTransfer(
        eventID: String,
        generation: Int,
        applyAtomically: () -> Void
    ) -> CoinTransferGateResult {
        let candidate = CoinTransferIdentity(eventID: eventID, generation: generation)
        guard candidate == identity else { return .stale }
        guard motionPreference == .reduceMotion else { return .invalidTransition }

        switch lifecycle {
        case .prepared:
            lifecycle = .departed
            lifecycle = .airborne
            applyAtomically()
            lifecycle = .impacted
            lifecycle = .settling
            lifecycle = .completed
            return .accepted
        case .departed, .airborne:
            return .invalidTransition
        case .impacted, .settling, .completed:
            return .duplicate
        case .cancelled:
            return .cancelled
        }
    }

    @discardableResult
    mutating func cancel(eventID: String, generation: Int) -> CoinTransferGateResult {
        let candidate = CoinTransferIdentity(eventID: eventID, generation: generation)
        guard candidate == identity else { return .stale }

        switch lifecycle {
        case .completed:
            return .duplicate
        case .cancelled:
            return .cancelled
        case .prepared, .departed, .airborne, .impacted, .settling:
            lifecycle = .cancelled
            return .accepted
        }
    }

    private mutating func transition(
        identity candidate: CoinTransferIdentity,
        from expected: CoinTransferLifecycle,
        to target: CoinTransferLifecycle
    ) -> CoinTransferGateResult {
        guard candidate == identity else { return .stale }

        if lifecycle == .cancelled {
            return .cancelled
        }
        if lifecycle == target || lifecycle.rawValue > target.rawValue {
            return .duplicate
        }
        guard lifecycle == expected else {
            return .invalidTransition
        }
        lifecycle = target
        return .accepted
    }
}
