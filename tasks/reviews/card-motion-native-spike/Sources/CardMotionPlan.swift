import Foundation

struct MotionPoint: Equatable, Sendable {
    let x: Double
    let y: Double

    static func mix(_ start: MotionPoint, _ end: MotionPoint, progress: Double) -> MotionPoint {
        MotionPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }
}

enum CardContainer: Equatable, Sendable {
    case deck
    case hand
    case table
}

enum CardReturnReason: Equatable, Sendable {
    case cancelledBeforeContact
    case invalidatedPresentation
}

enum CardMotionPhase: Equatable, Sendable {
    case idle
    case deal(sequence: Int)
    case fan(slot: Int)
    case reveal(publicEventID: Int)
    case play(publicEventID: Int)
    case `return`(reason: CardReturnReason)
    case settled(container: CardContainer, slot: Int)
}

enum CardContactOutcome: Equatable, Sendable {
    case emitFeedback
    case ignored
}

struct CardMotionStateMachine: Equatable, Sendable {
    private(set) var phase: CardMotionPhase = .idle
    private(set) var generation = 0
    private(set) var emittedContactCount = 0
    private var acceptedContactGeneration: Int?

    mutating func begin(_ newPhase: CardMotionPhase) -> Int {
        generation += 1
        phase = newPhase
        acceptedContactGeneration = nil
        return generation
    }

    @discardableResult
    mutating func transition(to next: CardMotionPhase, generation candidate: Int) -> Bool {
        guard candidate == generation, Self.allows(from: phase, to: next) else {
            return false
        }
        phase = next
        return true
    }

    mutating func acceptContact(generation candidate: Int) -> CardContactOutcome {
        guard candidate == generation,
              acceptedContactGeneration != generation else {
            return .ignored
        }

        switch phase {
        case .deal:
            acceptedContactGeneration = generation
            emittedContactCount += 1
            phase = .fan(slot: 0)
            return .emitFeedback
        case .play:
            acceptedContactGeneration = generation
            emittedContactCount += 1
            phase = .settled(container: .table, slot: 0)
            return .emitFeedback
        default:
            return .ignored
        }
    }

    @discardableResult
    mutating func cancelBeforeContact(generation candidate: Int) -> Int? {
        guard candidate == generation,
              acceptedContactGeneration != generation else {
            return nil
        }
        guard case .play = phase else { return nil }
        generation += 1
        phase = .return(reason: .cancelledBeforeContact)
        acceptedContactGeneration = nil
        return generation
    }

    @discardableResult
    mutating func settleForReducedMotion() -> Int {
        generation += 1
        switch phase {
        case .deal:
            phase = .fan(slot: 0)
        case .return:
            phase = .fan(slot: 0)
        case .reveal, .play:
            phase = .settled(container: .table, slot: 0)
        case .idle, .fan, .settled:
            break
        }
        acceptedContactGeneration = nil
        return generation
    }

    static func allows(from: CardMotionPhase, to: CardMotionPhase) -> Bool {
        switch (from, to) {
        case (.idle, .deal),
             (.deal, .fan),
             (.fan, .reveal),
             (.fan, .play),
             (.reveal, .fan),
             (.reveal, .play),
             (.play, .settled),
             (.play, .return),
             (.return, .fan):
            return true
        default:
            return false
        }
    }
}

struct CardMotionSample: Equatable, Sendable {
    let progress: Double
    let groundPoint: MotionPoint
    let cardPoint: MotionPoint
    let cardRotationDegrees: Double
    let cardTiltDegrees: Double
    let shadowRotationDegrees: Double
    let shadowOpacity: Double
    let shadowScale: Double
}

struct CardMotionPlan: Equatable, Sendable {
    let start: MotionPoint
    let end: MotionPoint
    let arcHeight: Double
    let lateralBias: Double
    let startRotationDegrees: Double
    let endRotationDegrees: Double

    func sample(progress rawProgress: Double) -> CardMotionSample {
        let progress = min(max(rawProgress, 0), 1)
        let ground = MotionPoint.mix(start, end, progress: progress)
        let lift = 4 * progress * (1 - progress)
        let lateral = sin(.pi * progress) * lateralBias
        let distanceX = end.x - start.x
        let distanceY = end.y - start.y
        let length = max(hypot(distanceX, distanceY), 0.000_001)
        let normalX = -distanceY / length
        let normalY = distanceX / length
        let card = MotionPoint(
            x: ground.x + normalX * lateral,
            y: ground.y + normalY * lateral - arcHeight * lift
        )
        let rotation = startRotationDegrees
            + (endRotationDegrees - startRotationDegrees) * progress

        return CardMotionSample(
            progress: progress,
            groundPoint: ground,
            cardPoint: card,
            cardRotationDegrees: rotation,
            cardTiltDegrees: -8 * lift,
            shadowRotationDegrees: 0,
            shadowOpacity: 0.34 - 0.16 * lift,
            shadowScale: 1 + 0.14 * lift
        )
    }

    var reversed: CardMotionPlan {
        CardMotionPlan(
            start: end,
            end: start,
            arcHeight: arcHeight,
            lateralBias: -lateralBias,
            startRotationDegrees: endRotationDegrees,
            endRotationDegrees: startRotationDegrees
        )
    }
}

