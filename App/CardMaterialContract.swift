import Foundation

/// A unit-space point used by build-time and runtime card material renderers.
/// Both axes use the closed range `0...1`.
struct CardMaterialPoint: Equatable, Hashable, Sendable {
    let x: Double
    let y: Double

    var rotatedByHalfTurn: CardMaterialPoint {
        CardMaterialPoint(x: 1 - x, y: 1 - y)
    }
}

/// A unit-space rectangle. Card artwork remains responsible for mapping it to pixels.
struct CardMaterialRect: Equatable, Hashable, Sendable {
    let minimumX: Double
    let minimumY: Double
    let maximumX: Double
    let maximumY: Double

    func intersectsCircle(center: CardMaterialPoint, radius: Double) -> Bool {
        let closestX = min(max(center.x, minimumX), maximumX)
        let closestY = min(max(center.y, minimumY), maximumY)
        let deltaX = center.x - closestX
        let deltaY = center.y - closestY
        return deltaX * deltaX + deltaY * deltaY <= radius * radius
    }
}

/// Renderer-neutral parameters for one subtle abrasion or fibre variation.
struct CardPatinaMark: Equatable, Hashable, Sendable {
    let center: CardMaterialPoint
    let radius: Double
    let opacity: Double
    let rotationDegrees: Double

    var rotatedByHalfTurn: CardPatinaMark {
        CardPatinaMark(
            center: center.rotatedByHalfTurn,
            radius: radius,
            opacity: opacity,
            rotationDegrees: Self.normalizedAngle(rotationDegrees + 180)
        )
    }

    private static func normalizedAngle(_ angle: Double) -> Double {
        let remainder = angle.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }
}

/// Named material bounds for the frozen W2 back. There is intentionally no card or
/// asset identifier here: every physical copy receives the same orientation-neutral
/// parameter field, so patina cannot reveal a hidden card's identity.
struct W2BackPatinaConfiguration: Equatable, Sendable {
    static let standard = W2BackPatinaConfiguration(
        pairCount: Defaults.pairCount,
        safeEdgeInset: Defaults.safeEdgeInset,
        minimumRadius: Defaults.minimumRadius,
        maximumRadius: Defaults.maximumRadius,
        minimumOpacity: Defaults.minimumOpacity,
        maximumOpacity: Defaults.maximumOpacity
    )

    let pairCount: Int
    let safeEdgeInset: Double
    let minimumRadius: Double
    let maximumRadius: Double
    let minimumOpacity: Double
    let maximumOpacity: Double

    private enum Defaults {
        static let pairCount = 12
        static let safeEdgeInset = 0.055
        static let minimumRadius = 0.0035
        static let maximumRadius = 0.012
        static let minimumOpacity = 0.025
        static let maximumOpacity = 0.075
    }
}

enum W2BackPatina {
    /// A fixed material seed, independent of the face-down card and its position.
    private static let materialSeed: UInt64 = 0x57_32_50_41_54_49_4E_41
    private static let halfTurnDegrees = 180.0
    private static let fullTurnDegrees = 360.0

    static func marks(
        configuration: W2BackPatinaConfiguration = .standard
    ) -> [CardPatinaMark] {
        guard configuration.pairCount > 0,
              configuration.safeEdgeInset >= 0,
              configuration.safeEdgeInset < 0.5,
              configuration.minimumRadius >= 0,
              configuration.maximumRadius >= configuration.minimumRadius,
              configuration.minimumOpacity >= 0,
              configuration.maximumOpacity >= configuration.minimumOpacity else {
            return []
        }

        var generator = CardMaterialGenerator(seed: materialSeed)
        var result: [CardPatinaMark] = []
        result.reserveCapacity(configuration.pairCount * 2)

        for _ in 0..<configuration.pairCount {
            let x = generator.value(in: configuration.safeEdgeInset...(1 - configuration.safeEdgeInset))
            let y = generator.value(in: configuration.safeEdgeInset...(1 - configuration.safeEdgeInset))
            let mark = CardPatinaMark(
                center: CardMaterialPoint(x: x, y: y),
                radius: generator.value(
                    in: configuration.minimumRadius...configuration.maximumRadius
                ),
                opacity: generator.value(
                    in: configuration.minimumOpacity...configuration.maximumOpacity
                ),
                rotationDegrees: generator.value(in: 0..<fullTurnDegrees)
            )
            result.append(mark)
            result.append(CardPatinaMark(
                center: mark.center.rotatedByHalfTurn,
                radius: mark.radius,
                opacity: mark.opacity,
                rotationDegrees: (mark.rotationDegrees + halfTurnDegrees)
                    .truncatingRemainder(dividingBy: fullTurnDegrees)
            ))
        }
        return result
    }
}

struct CardFrontPatinaConfiguration: Equatable, Sendable {
    static let standard = CardFrontPatinaConfiguration(
        markCount: Defaults.markCount,
        maximumPlacementAttemptsPerMark: Defaults.maximumPlacementAttemptsPerMark,
        safeEdgeInset: Defaults.safeEdgeInset,
        minimumRadius: Defaults.minimumRadius,
        maximumRadius: Defaults.maximumRadius,
        minimumOpacity: Defaults.minimumOpacity,
        maximumOpacity: Defaults.maximumOpacity,
        protectedIndexZones: Defaults.protectedIndexZones
    )

    let markCount: Int
    let maximumPlacementAttemptsPerMark: Int
    let safeEdgeInset: Double
    let minimumRadius: Double
    let maximumRadius: Double
    let minimumOpacity: Double
    let maximumOpacity: Double
    let protectedIndexZones: [CardMaterialRect]

    private enum Defaults {
        static let markCount = 18
        static let maximumPlacementAttemptsPerMark = 32
        static let safeEdgeInset = 0.045
        static let minimumRadius = 0.0025
        static let maximumRadius = 0.009
        static let minimumOpacity = 0.018
        static let maximumOpacity = 0.052

        static let topLeadingIndexZone = CardMaterialRect(
            minimumX: 0,
            minimumY: 0,
            maximumX: 0.24,
            maximumY: 0.25
        )
        static let bottomTrailingIndexZone = CardMaterialRect(
            minimumX: 1 - topLeadingIndexZone.maximumX,
            minimumY: 1 - topLeadingIndexZone.maximumY,
            maximumX: 1,
            maximumY: 1
        )
        static let protectedIndexZones = [topLeadingIndexZone, bottomTrailingIndexZone]
    }
}

enum CardFrontPatina {
    private static let fullTurnDegrees = 360.0

    /// Stable across processes and OS releases; unlike `Hasher`, this is suitable for assets.
    static func seed(assetID: String) -> UInt64 {
        CardMaterialStableSeed.value(for: assetID)
    }

    static func marks(
        assetID: String,
        configuration: CardFrontPatinaConfiguration = .standard
    ) -> [CardPatinaMark] {
        guard !assetID.isEmpty,
              configuration.markCount > 0,
              configuration.maximumPlacementAttemptsPerMark > 0,
              configuration.safeEdgeInset >= 0,
              configuration.safeEdgeInset < 0.5,
              configuration.minimumRadius >= 0,
              configuration.maximumRadius >= configuration.minimumRadius,
              configuration.minimumOpacity >= 0,
              configuration.maximumOpacity >= configuration.minimumOpacity else {
            return []
        }

        var generator = CardMaterialGenerator(seed: seed(assetID: assetID))
        var result: [CardPatinaMark] = []
        result.reserveCapacity(configuration.markCount)

        for _ in 0..<configuration.markCount {
            for _ in 0..<configuration.maximumPlacementAttemptsPerMark {
                let radius = generator.value(
                    in: configuration.minimumRadius...configuration.maximumRadius
                )
                let placementInset = configuration.safeEdgeInset + radius
                guard placementInset < 0.5 else { continue }
                let center = CardMaterialPoint(
                    x: generator.value(in: placementInset...(1 - placementInset)),
                    y: generator.value(in: placementInset...(1 - placementInset))
                )
                let isProtected = configuration.protectedIndexZones.contains {
                    $0.intersectsCircle(center: center, radius: radius)
                }
                guard !isProtected else { continue }

                result.append(CardPatinaMark(
                    center: center,
                    radius: radius,
                    opacity: generator.value(
                        in: configuration.minimumOpacity...configuration.maximumOpacity
                    ),
                    rotationDegrees: generator.value(in: 0..<fullTurnDegrees)
                ))
                break
            }
        }
        return result
    }
}

/// Renderer-neutral card transform. Coordinates deliberately remain unconstrained so
/// the same type can represent SpriteKit, SwiftUI and normalized test spaces.
struct CardPose: Equatable, Hashable, Sendable {
    static let identity = CardPose(
        x: Defaults.origin,
        y: Defaults.origin,
        depth: Defaults.origin,
        rotationDegrees: Defaults.rotationDegrees,
        scale: Defaults.scale
    )

    let x: Double
    let y: Double
    let depth: Double
    let rotationDegrees: Double
    let scale: Double

    init(x: Double, y: Double, depth: Double = 0, rotationDegrees: Double = 0, scale: Double = 1) {
        self.x = x
        self.y = y
        self.depth = depth
        self.rotationDegrees = rotationDegrees
        self.scale = scale
    }

    func interpolated(to target: CardPose, progress: Double) -> CardPose {
        let boundedProgress = min(max(progress, Defaults.minimumProgress), Defaults.maximumProgress)
        return CardPose(
            x: Self.interpolate(x, target.x, boundedProgress),
            y: Self.interpolate(y, target.y, boundedProgress),
            depth: Self.interpolate(depth, target.depth, boundedProgress),
            rotationDegrees: Self.interpolate(rotationDegrees, target.rotationDegrees, boundedProgress),
            scale: Self.interpolate(scale, target.scale, boundedProgress)
        )
    }

    private static func interpolate(_ start: Double, _ end: Double, _ progress: Double) -> Double {
        start + (end - start) * progress
    }

    private enum Defaults {
        static let origin = 0.0
        static let rotationDegrees = 0.0
        static let scale = 1.0
        static let minimumProgress = 0.0
        static let maximumProgress = 1.0
    }
}

struct CardFlightIdentity: Equatable, Hashable, Sendable {
    let eventID: String
    let generation: Int
}

enum CardFlightMotionPreference: Equatable, Sendable {
    case standard
    case reduceMotion
}

enum CardFlightPresentationBeat: Equatable, Sendable {
    case sourceEmphasis
    case spatialFlight
    case targetEmphasis
    case crossfade
    case materialContact
}

enum CardFlightContactResult: Equatable, Sendable {
    case accepted
    case duplicate
    case stale
    case cancelled
}

/// A rule-neutral, generation-bound delivery transaction. Consumers mutate game or
/// presentation state only after `.accepted`; stale and duplicate callbacks are inert.
struct CardFlightTransaction: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case awaitingContact
        case contacted
        case completed
        case cancelled
    }

    let identity: CardFlightIdentity
    let source: CardPose
    let target: CardPose
    let motionPreference: CardFlightMotionPreference
    private(set) var state: State = .awaitingContact

    var presentationBeats: [CardFlightPresentationBeat] {
        switch motionPreference {
        case .standard:
            return [.spatialFlight, .materialContact]
        case .reduceMotion:
            return [.sourceEmphasis, .targetEmphasis, .crossfade, .materialContact]
        }
    }

    init(
        eventID: String,
        generation: Int,
        source: CardPose,
        target: CardPose,
        motionPreference: CardFlightMotionPreference
    ) {
        identity = CardFlightIdentity(eventID: eventID, generation: generation)
        self.source = source
        self.target = target
        self.motionPreference = motionPreference
    }

    @discardableResult
    mutating func registerContact(eventID: String, generation: Int) -> CardFlightContactResult {
        guard identity == CardFlightIdentity(eventID: eventID, generation: generation) else {
            return .stale
        }
        switch state {
        case .awaitingContact:
            state = .contacted
            return .accepted
        case .contacted, .completed:
            return .duplicate
        case .cancelled:
            return .cancelled
        }
    }

    @discardableResult
    mutating func complete(eventID: String, generation: Int) -> Bool {
        guard identity == CardFlightIdentity(eventID: eventID, generation: generation),
              state == .contacted else {
            return false
        }
        state = .completed
        return true
    }

    mutating func cancel() {
        guard state != .completed else { return }
        state = .cancelled
    }
}

private enum CardMaterialStableSeed {
    private static let offsetBasis: UInt64 = 14_695_981_039_346_656_037
    private static let prime: UInt64 = 1_099_511_628_211

    static func value(for text: String) -> UInt64 {
        text.utf8.reduce(offsetBasis) { partial, byte in
            (partial ^ UInt64(byte)) &* prime
        }
    }
}

private struct CardMaterialGenerator {
    private static let multiplier: UInt64 = 6_364_136_223_846_793_005
    private static let increment: UInt64 = 1_442_695_040_888_963_407
    private static let mantissaBits = 53
    private static let mantissaDivisor = Double(UInt64(1) << mantissaBits)

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func value(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + unitValue() * (range.upperBound - range.lowerBound)
    }

    mutating func value(in range: Range<Double>) -> Double {
        range.lowerBound + unitValue() * (range.upperBound - range.lowerBound)
    }

    private mutating func unitValue() -> Double {
        state = state &* Self.multiplier &+ Self.increment
        return Double(state >> (UInt64.bitWidth - Self.mantissaBits)) / Self.mantissaDivisor
    }
}
