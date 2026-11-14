import Foundation

enum DealRhythmMode: String, Codable, Sendable {
    case standard
    case reducedMotion
}

enum DealRhythmPhase: String, Codable, Sendable {
    case tension
    case acceleration
    case recovery
    case release
}

enum DealRouteClass: String, Codable, CaseIterable, Sendable {
    case innerArc
    case outerArc
    case shallowDirect
    case localOffset
    case localSettle
    case targetCrossfade
}

enum DealContactClass: String, Codable, CaseIterable, Sendable {
    case leadingCorner
    case trailingCorner
    case longEdge
    case softFlat
}

struct DealRhythmPulse: Codable, Equatable, Sendable {
    let index: Int
    let phase: DealRhythmPhase
    let targetStartSeconds: Double
    let intervalFromPreviousSeconds: Double
    let route: DealRouteClass
    let contact: DealContactClass
    /// A small non-temporal variation parameter for the rendering adapter. It
    /// must not be interpreted as an additional delay.
    let gestureVariation: Double
}

struct DealRhythmProfile: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let seed: UInt64
    let mode: DealRhythmMode
    let pulses: [DealRhythmPulse]

    init(
        schemaVersion: Int = 1,
        seed: UInt64,
        mode: DealRhythmMode,
        pulses: [DealRhythmPulse]
    ) {
        self.schemaVersion = schemaVersion
        self.seed = seed
        self.mode = mode
        self.pulses = pulses
    }

    static func make(
        dealCount: Int,
        seed: UInt64,
        mode: DealRhythmMode
    ) -> DealRhythmProfile {
        guard dealCount > 0 else {
            return DealRhythmProfile(seed: seed, mode: mode, pulses: [])
        }

        var random = SplitMix64(seed: seed)
        let recoveryIndex = dealCount >= 4 ? dealCount - 2 : nil
        let routeChoices: [DealRouteClass] = switch mode {
        case .standard: [.innerArc, .outerArc, .shallowDirect]
        case .reducedMotion: [.localOffset, .localSettle, .targetCrossfade]
        }

        var pulses: [DealRhythmPulse] = []
        var target = 0.0
        var previousAccelerationInterval: Double?

        for index in 0..<dealCount {
            let phase = phase(
                at: index,
                dealCount: dealCount,
                recoveryIndex: recoveryIndex
            )
            let interval = interval(
                for: phase,
                index: index,
                mode: mode,
                previousAccelerationInterval: previousAccelerationInterval,
                random: &random
            )
            if index > 0 { target += interval }

            if phase == .tension || phase == .acceleration {
                previousAccelerationInterval = interval
            }

            let route = constrainedChoice(
                from: routeChoices,
                previous: pulses.map(\.route),
                random: &random
            )
            var contact = constrainedChoice(
                from: DealContactClass.allCases,
                previous: pulses.map(\.contact),
                random: &random
            )
            if let previous = pulses.last,
               previous.route == route,
               previous.contact == contact {
                contact = nextChoice(after: contact, in: DealContactClass.allCases)
            }

            pulses.append(DealRhythmPulse(
                index: index,
                phase: phase,
                targetStartSeconds: target,
                intervalFromPreviousSeconds: index == 0 ? 0 : interval,
                route: route,
                contact: contact,
                gestureVariation: random.nextUnit()
            ))
        }

        return DealRhythmProfile(seed: seed, mode: mode, pulses: pulses)
    }

    private static func phase(
        at index: Int,
        dealCount: Int,
        recoveryIndex: Int?
    ) -> DealRhythmPhase {
        if index == dealCount - 1, dealCount > 1 { return .release }
        if index == recoveryIndex { return .recovery }
        if index <= 1 { return .tension }
        return .acceleration
    }

    private static func interval(
        for phase: DealRhythmPhase,
        index: Int,
        mode: DealRhythmMode,
        previousAccelerationInterval: Double?,
        random: inout SplitMix64
    ) -> Double {
        guard index > 0 else { return 0 }

        let jitter = random.nextSignedUnit()
        switch (mode, phase) {
        case (.standard, .tension):
            return 0.316 + jitter * 0.004
        case (.standard, .acceleration):
            let candidate = max(0.242, 0.310 - Double(index - 1) * 0.021 + jitter * 0.003)
            return max(0.242, min(candidate, (previousAccelerationInterval ?? 0.316) - 0.006))
        case (.standard, .recovery):
            return 0.304 + jitter * 0.004
        case (.standard, .release):
            return 0.226 + jitter * 0.003
        case (.reducedMotion, .tension):
            return 0.082 + jitter * 0.0015
        case (.reducedMotion, .acceleration):
            let candidate = max(0.070, 0.082 - Double(index - 1) * 0.004 + jitter * 0.001)
            return max(0.070, min(candidate, (previousAccelerationInterval ?? 0.082) - 0.002))
        case (.reducedMotion, .recovery):
            return 0.088 + jitter * 0.0015
        case (.reducedMotion, .release):
            return 0.068 + jitter * 0.001
        }
    }

    private static func constrainedChoice<T: Equatable>(
        from choices: [T],
        previous: [T],
        random: inout SplitMix64
    ) -> T {
        var choice = choices[random.nextIndex(upperBound: choices.count)]
        if previous.count >= 2,
           choice == previous[previous.count - 1],
           choice == previous[previous.count - 2] {
            choice = nextChoice(after: choice, in: choices)
        }
        return choice
    }

    private static func nextChoice<T: Equatable>(after value: T, in choices: [T]) -> T {
        guard let index = choices.firstIndex(of: value) else { return choices[0] }
        return choices[(index + 1) % choices.count]
    }
}

struct DealMotionDurations: Codable, Equatable, Sendable {
    let travelSeconds: Double
    let contactSeconds: Double
    let settleSeconds: Double

    var movementSeconds: Double {
        travelSeconds + contactSeconds + settleSeconds
    }
}

struct ScheduledDealCard: Codable, Equatable, Sendable {
    let index: Int
    let rhythmTargetSeconds: Double
    let actualStartSeconds: Double
    let contactStartSeconds: Double
    let settleStartSeconds: Double
    /// The first instant at which this card is no longer moving. Settle is part
    /// of the active interval `[actualStartSeconds, restWindowStartSeconds)`.
    let restWindowStartSeconds: Double
    let route: DealRouteClass
    let contact: DealContactClass

    func isActive(at time: Double) -> Bool {
        actualStartSeconds <= time && time < restWindowStartSeconds
    }
}

enum DealRhythmScheduleError: Error, Equatable {
    case durationCountMismatch
    case nonPositiveMovementDuration(index: Int)
}

enum DealRhythmScheduler {
    static func schedule(
        profile: DealRhythmProfile,
        durations: [DealMotionDurations]
    ) throws -> [ScheduledDealCard] {
        guard profile.pulses.count == durations.count else {
            throw DealRhythmScheduleError.durationCountMismatch
        }

        var scheduled: [ScheduledDealCard] = []
        for (pulse, duration) in zip(profile.pulses, durations) {
            guard duration.travelSeconds >= 0,
                  duration.contactSeconds >= 0,
                  duration.settleSeconds >= 0,
                  duration.movementSeconds > 0 else {
                throw DealRhythmScheduleError.nonPositiveMovementDuration(index: pulse.index)
            }

            let twoCardsBackRest = pulse.index >= 2
                ? scheduled[pulse.index - 2].restWindowStartSeconds
                : 0
            let actualStart = max(pulse.targetStartSeconds, twoCardsBackRest)
            let contactStart = actualStart + duration.travelSeconds
            let settleStart = contactStart + duration.contactSeconds
            let restWindowStart = settleStart + duration.settleSeconds

            scheduled.append(ScheduledDealCard(
                index: pulse.index,
                rhythmTargetSeconds: pulse.targetStartSeconds,
                actualStartSeconds: actualStart,
                contactStartSeconds: contactStart,
                settleStartSeconds: settleStart,
                restWindowStartSeconds: restWindowStart,
                route: pulse.route,
                contact: pulse.contact
            ))
        }
        return scheduled
    }

    static func activeCount(in schedule: [ScheduledDealCard], at time: Double) -> Int {
        schedule.reduce(into: 0) { count, card in
            if card.isActive(at: time) { count += 1 }
        }
    }
}

private struct SplitMix64: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func nextSignedUnit() -> Double {
        nextUnit() * 2 - 1
    }

    mutating func nextIndex(upperBound: Int) -> Int {
        Int(next() % UInt64(upperBound))
    }
}
