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

struct CardDimensions: Equatable, Sendable {
    let width: Double
    let height: Double
}

struct CardPose: Equatable, Sendable {
    let center: MotionPoint
    let scale: Double
    let rotationDegrees: Double

    static func mix(_ start: CardPose, _ end: CardPose, progress: Double) -> CardPose {
        CardPose(
            center: MotionPoint.mix(start.center, end.center, progress: progress),
            scale: start.scale + (end.scale - start.scale) * progress,
            rotationDegrees: start.rotationDegrees
                + (end.rotationDegrees - start.rotationDegrees) * progress
        )
    }
}

enum CardMotionSegment: String, CaseIterable, Codable, Sendable {
    case deal
    case reveal
    case play
    case `return`
}

enum CardSurfaceState: Equatable, Sendable {
    case back
    case reveal(progress: Double)
    case face
}

struct CardTrajectory: Equatable, Sendable {
    let startPose: CardPose
    let endPose: CardPose
    let arcHeight: Double
    let lateralBias: Double

    func sample(progress rawProgress: Double) -> CardTrajectorySample {
        let progress = min(max(rawProgress, 0), 1)
        let groundPose = CardPose.mix(startPose, endPose, progress: progress)
        let height = 4 * progress * (1 - progress)
        let distanceX = endPose.center.x - startPose.center.x
        let distanceY = endPose.center.y - startPose.center.y
        let distance = hypot(distanceX, distanceY)
        let normalX = distance > 0.000_001 ? -distanceY / distance : 0
        let normalY = distance > 0.000_001 ? distanceX / distance : 0
        let lateral = sin(.pi * progress) * lateralBias
        let cardCenter = MotionPoint(
            x: groundPose.center.x + normalX * lateral,
            y: groundPose.center.y + normalY * lateral - arcHeight * height
        )

        return CardTrajectorySample(
            trajectoryProgress: progress,
            groundPose: groundPose,
            cardPose: CardPose(
                center: cardCenter,
                scale: groundPose.scale,
                rotationDegrees: groundPose.rotationDegrees
            ),
            normalizedHeight: height
        )
    }
}

struct CardTrajectorySample: Equatable, Sendable {
    let trajectoryProgress: Double
    let groundPose: CardPose
    let cardPose: CardPose
    let normalizedHeight: Double
}

struct CardMotionSample: Equatable, Sendable {
    let segment: CardMotionSegment
    let segmentProgress: Double
    let cardPose: CardPose
    let groundPose: CardPose
    let surface: CardSurfaceState
    let cardTiltDegrees: Double
    let shadowRotationDegrees: Double
    let shadowOpacity: Double
    let shadowWidthScale: Double
    let shadowLengthScale: Double
    let shadowBlur: Double
    let normalizedHeight: Double
}

struct CardMotionPlan: Equatable, Sendable {
    let segment: CardMotionSegment
    let trajectory: CardTrajectory
    let trajectoryStartProgress: Double
    let trajectoryEndProgress: Double

    func sample(progress rawSegmentProgress: Double) -> CardMotionSample {
        let segmentProgress = min(max(rawSegmentProgress, 0), 1)
        let trajectoryProgress = trajectoryStartProgress
            + (trajectoryEndProgress - trajectoryStartProgress) * segmentProgress
        let trajectorySample = trajectory.sample(progress: trajectoryProgress)
        let height = trajectorySample.normalizedHeight
        let surface: CardSurfaceState
        switch segment {
        case .deal:
            surface = .back
        case .reveal:
            surface = .reveal(progress: segmentProgress)
        case .play, .return:
            surface = .face
        }

        return CardMotionSample(
            segment: segment,
            segmentProgress: segmentProgress,
            cardPose: trajectorySample.cardPose,
            groundPose: trajectorySample.groundPose,
            surface: surface,
            cardTiltDegrees: -7.5 * height,
            shadowRotationDegrees: 0,
            shadowOpacity: 0.29 - 0.14 * height,
            shadowWidthScale: trajectorySample.groundPose.scale * (0.92 + 0.10 * height),
            shadowLengthScale: trajectorySample.groundPose.scale * (0.70 + 0.16 * height),
            shadowBlur: 2.2 + 4.8 * height,
            normalizedHeight: height
        )
    }
}

struct CardMotionLayout: Equatable, Sendable {
    let viewport: CardDimensions
    let cardSize: CardDimensions
    let deckTop: CardPose
    let handSlot: CardPose
    let playTarget: CardPose

    init(width: Double, height: Double) {
        viewport = CardDimensions(width: width, height: height)
        let shortEdge = min(width, height)
        let cardWidth = min(max(shortEdge * 0.19, 58), 82)
        cardSize = CardDimensions(width: cardWidth, height: cardWidth * 74 / 52)
        deckTop = CardPose(
            center: MotionPoint(x: width * 0.20, y: height * 0.25),
            scale: 1,
            rotationDegrees: -7
        )
        handSlot = CardPose(
            center: MotionPoint(x: width * 0.72, y: height * 0.72),
            scale: 0.88,
            rotationDegrees: 9
        )
        playTarget = CardPose(
            center: MotionPoint(x: width * 0.52, y: height * 0.46),
            scale: 1,
            rotationDegrees: -2
        )
    }

    func plan(for segment: CardMotionSegment, interruptionProgress: Double = 0.58) -> CardMotionPlan? {
        switch segment {
        case .deal:
            return CardMotionPlan(
                segment: .deal,
                trajectory: CardTrajectory(
                    startPose: deckTop,
                    endPose: handSlot,
                    arcHeight: min(max(viewport.height * 0.16, 48), 112),
                    lateralBias: min(18, viewport.width * 0.028)
                ),
                trajectoryStartProgress: 0,
                trajectoryEndProgress: 1
            )
        case .reveal:
            return CardMotionPlan(
                segment: .reveal,
                trajectory: CardTrajectory(
                    startPose: handSlot,
                    endPose: handSlot,
                    arcHeight: 10,
                    lateralBias: 0
                ),
                trajectoryStartProgress: 0,
                trajectoryEndProgress: 1
            )
        case .play:
            return CardMotionPlan(
                segment: .play,
                trajectory: playTrajectory,
                trajectoryStartProgress: 0,
                trajectoryEndProgress: 1
            )
        case .return:
            guard interruptionProgress >= 0, interruptionProgress < 1 else { return nil }
            return CardMotionPlan(
                segment: .return,
                trajectory: playTrajectory,
                trajectoryStartProgress: interruptionProgress,
                trajectoryEndProgress: 0
            )
        }
    }

    private var playTrajectory: CardTrajectory {
        CardTrajectory(
            startPose: handSlot,
            endPose: playTarget,
            arcHeight: min(max(viewport.height * 0.13, 42), 84),
            lateralBias: -min(14, viewport.width * 0.022)
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
        guard candidate == generation, Self.allows(from: phase, to: next) else { return false }
        phase = next
        return true
    }

    mutating func acceptContact(generation candidate: Int) -> CardContactOutcome {
        guard candidate == generation, acceptedContactGeneration != generation else {
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

    mutating func cancelBeforeContact(generation candidate: Int) -> Int? {
        guard candidate == generation,
              acceptedContactGeneration != generation,
              case .play = phase else {
            return nil
        }
        generation += 1
        phase = .return(reason: .cancelledBeforeContact)
        acceptedContactGeneration = nil
        return generation
    }

    mutating func settleForReducedMotion() -> Int {
        generation += 1
        switch phase {
        case .deal, .return:
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

