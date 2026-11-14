import Foundation

struct MotionVector: Equatable, Codable, Sendable {
    var x: Double
    var y: Double

    static let zero = MotionVector(x: 0, y: 0)

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: Self, rhs: Double) -> Self {
        Self(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    var length: Double { hypot(x, y) }

    var normalized: Self {
        let magnitude = length
        guard magnitude > 0.000_001 else { return .zero }
        return self * (1 / magnitude)
    }
}

struct MotionSize: Equatable, Codable, Sendable {
    let width: Double
    let height: Double
}

struct CardMotionLayout: Equatable, Codable, Sendable {
    let viewport: MotionSize
    let cardSize: MotionSize
    let deckCenter: MotionVector
    let handCenter: MotionVector
    let playCenter: MotionVector
    let deckYaw: Double
    let handYaw: Double
    let playYaw: Double

    init(width: Double, height: Double) {
        viewport = MotionSize(width: width, height: height)
        let cardWidth = 54.0
        cardSize = MotionSize(width: cardWidth, height: cardWidth * 74 / 52)
        deckCenter = MotionVector(x: width * 0.84, y: height * 0.36)
        handCenter = MotionVector(x: width * 0.73, y: height * 0.88)
        playCenter = MotionVector(x: width * 0.53, y: height * 0.575)
        deckYaw = -6
        handYaw = 7
        playYaw = -1.5
    }
}

enum CardSurface: String, Codable, Sendable {
    case back
    case face
}

enum CardFlightKind: String, Codable, Sendable {
    case deal
    case play
    case `return`
}

enum CardDestination: String, Codable, Sendable {
    case hand
    case table
}

struct CardPose: Equatable, Codable, Sendable {
    let center: MotionVector
    let velocity: MotionVector
    let height: Double
    let verticalVelocity: Double
    let yawDegrees: Double
    let yawVelocity: Double
    let pitchDegrees: Double
    let pitchAxis: MotionVector
    let flipDegrees: Double
}

struct CardFlightSnapshot: Equatable, Codable, Identifiable, Sendable {
    let id: Int
    let kind: CardFlightKind
    let surface: CardSurface
    let pose: CardPose
    let normalizedProgress: Double
    let firstContactProgress: Double
    let hasContacted: Bool
}

struct ContactRecord: Equatable, Codable, Sendable {
    let flightID: Int
    let kind: CardFlightKind
    let scheduledTime: Double
    let observedTime: Double
    let hapticTime: Double
}

struct RestingCard: Equatable, Codable, Identifiable, Sendable {
    let id: Int
    let surface: CardSurface
    let center: MotionVector
    let yawDegrees: Double
}

struct StageSnapshot: Equatable, Codable, Sendable {
    let wallclockTime: Double
    let deckLayerCount: Int
    let handCards: [RestingCard]
    let tableCards: [RestingCard]
    let flights: [CardFlightSnapshot]
    let contacts: [ContactRecord]
    let maximumConcurrentFlights: Int
    let reducedMotion: Bool

    static let empty = StageSnapshot(
        wallclockTime: 0,
        deckLayerCount: 3,
        handCards: [],
        tableCards: [],
        flights: [],
        contacts: [],
        maximumConcurrentFlights: 0,
        reducedMotion: false
    )

    var handCardCount: Int { handCards.count }
    var tableCardCount: Int { tableCards.count }
}

struct ProjectedShadow: Equatable, Codable, Sendable {
    let points: [MotionVector]
    let blurRadius: Double
    let opacity: Double

    var bounds: (min: MotionVector, max: MotionVector) {
        guard let first = points.first else { return (.zero, .zero) }
        return points.dropFirst().reduce((first, first)) { partial, point in
            (
                MotionVector(x: min(partial.0.x, point.x), y: min(partial.0.y, point.y)),
                MotionVector(x: max(partial.1.x, point.x), y: max(partial.1.y, point.y))
            )
        }
    }

    static func project(
        pose: CardPose,
        cardSize: MotionSize,
        lightDirection: (x: Double, y: Double, z: Double) = (-0.34, -0.48, -1)
    ) -> Self {
        let halfWidth = cardSize.width / 2
        let halfHeight = cardSize.height / 2
        let localCorners = [
            Vector3(x: -halfWidth, y: -halfHeight, z: 0),
            Vector3(x: halfWidth, y: -halfHeight, z: 0),
            Vector3(x: halfWidth, y: halfHeight, z: 0),
            Vector3(x: -halfWidth, y: halfHeight, z: 0),
        ]
        let yaw = pose.yawDegrees * .pi / 180
        let pitch = pose.pitchDegrees * .pi / 180
        let axis = Vector3(x: pose.pitchAxis.x, y: pose.pitchAxis.y, z: 0).normalized
        let groundZ = max(0, pose.height) + 0.42
        let points = localCorners.map { corner -> MotionVector in
            let yawed = corner.rotated(around: Vector3(x: 0, y: 0, z: 1), radians: yaw)
            let tilted = yawed.rotated(around: axis, radians: pitch)
            let worldZ = groundZ + tilted.z
            let ray = max(0, worldZ) / max(0.001, -lightDirection.z)
            return MotionVector(
                x: pose.center.x + tilted.x + lightDirection.x * ray,
                y: pose.center.y + tilted.y + lightDirection.y * ray
            )
        }
        let heightFactor = min(max(pose.height / 96, 0), 1)
        return ProjectedShadow(
            points: points,
            blurRadius: 1.15 + 4.45 * heightFactor,
            opacity: 0.47 - 0.22 * heightFactor
        )
    }
}

private struct Vector3 {
    let x: Double
    let y: Double
    let z: Double

    var normalized: Self {
        let magnitude = sqrt(x * x + y * y + z * z)
        guard magnitude > 0.000_001 else { return Self(x: 1, y: 0, z: 0) }
        return Self(x: x / magnitude, y: y / magnitude, z: z / magnitude)
    }

    func rotated(around rawAxis: Self, radians: Double) -> Self {
        let axis = rawAxis.normalized
        let cosine = cos(radians)
        let sine = sin(radians)
        let dot = x * axis.x + y * axis.y + z * axis.z
        let cross = Self(
            x: axis.y * z - axis.z * y,
            y: axis.z * x - axis.x * z,
            z: axis.x * y - axis.y * x
        )
        return Self(
            x: x * cosine + cross.x * sine + axis.x * dot * (1 - cosine),
            y: y * cosine + cross.y * sine + axis.y * dot * (1 - cosine),
            z: z * cosine + cross.z * sine + axis.z * dot * (1 - cosine)
        )
    }
}

struct Hermite2D: Equatable, Sendable {
    let start: MotionVector
    let end: MotionVector
    let startVelocity: MotionVector
    let endVelocity: MotionVector
    let duration: Double

    func position(at rawProgress: Double) -> MotionVector {
        let t = min(max(rawProgress, 0), 1)
        let h00 = 2 * t * t * t - 3 * t * t + 1
        let h10 = t * t * t - 2 * t * t + t
        let h01 = -2 * t * t * t + 3 * t * t
        let h11 = t * t * t - t * t
        return start * h00
            + startVelocity * (h10 * duration)
            + end * h01
            + endVelocity * (h11 * duration)
    }

    func velocity(at rawProgress: Double) -> MotionVector {
        let t = min(max(rawProgress, 0), 1)
        let dh00 = 6 * t * t - 6 * t
        let dh10 = 3 * t * t - 4 * t + 1
        let dh01 = -6 * t * t + 6 * t
        let dh11 = 3 * t * t - 2 * t
        return start * (dh00 / duration)
            + startVelocity * dh10
            + end * (dh01 / duration)
            + endVelocity * dh11
    }
}

struct Hermite1D: Equatable, Sendable {
    let start: Double
    let end: Double
    let startVelocity: Double
    let endVelocity: Double
    let duration: Double

    func value(at rawProgress: Double) -> Double {
        let t = min(max(rawProgress, 0), 1)
        let h00 = 2 * t * t * t - 3 * t * t + 1
        let h10 = t * t * t - 2 * t * t + t
        let h01 = -2 * t * t * t + 3 * t * t
        let h11 = t * t * t - t * t
        return start * h00 + startVelocity * h10 * duration + end * h01 + endVelocity * h11 * duration
    }

    func velocity(at rawProgress: Double) -> Double {
        let t = min(max(rawProgress, 0), 1)
        let dh00 = 6 * t * t - 6 * t
        let dh10 = 3 * t * t - 4 * t + 1
        let dh01 = -6 * t * t + 6 * t
        let dh11 = 3 * t * t - 2 * t
        return start * dh00 / duration
            + startVelocity * dh10
            + end * dh01 / duration
            + endVelocity * dh11
    }
}

struct ActiveCardFlight: Equatable, Sendable {
    static let settleDuration = 0.086

    let id: Int
    let kind: CardFlightKind
    let surface: CardSurface
    let destination: CardDestination
    let startTime: Double
    let duration: Double
    let path: Hermite2D
    let heightPath: Hermite1D?
    let arcHeight: Double
    let startYaw: Double
    let endYaw: Double
    let firstContactEnabled: Bool
    let settleLift: Double
    let settleTravel: Double
    let settleYawDegrees: Double

    var endTime: Double { startTime + duration + (firstContactEnabled ? Self.settleDuration : 0) }

    func sample(at time: Double) -> CardFlightSnapshot {
        let elapsed = max(0, time - startTime)
        let progress = min(elapsed / duration, 1)
        let contacted = firstContactEnabled && elapsed >= duration
        let baseCenter = path.position(at: progress)
        let baseVelocity = path.velocity(at: progress)
        let baseHeight: Double
        let baseVerticalVelocity: Double
        if let heightPath {
            baseHeight = max(0, heightPath.value(at: progress))
            baseVerticalVelocity = heightPath.velocity(at: progress)
        } else {
            baseHeight = max(0, 4 * arcHeight * progress * (1 - progress))
            baseVerticalVelocity = 4 * arcHeight * (1 - 2 * progress) / duration
        }

        let settleProgress = contacted
            ? min(max((elapsed - duration) / Self.settleDuration, 0), 1)
            : 0
        let approach = path.endVelocity.normalized
        let restitution = contacted
            ? sin(.pi * settleProgress) * (1 - settleProgress)
            : 0
        let center = baseCenter - approach * (settleTravel * restitution)
        let height = baseHeight + settleLift * restitution
        let horizontalVelocity = contacted ? approach * (-34 * cos(.pi * settleProgress)) : baseVelocity
        let verticalVelocity = contacted ? settleLift * (.pi * cos(.pi * settleProgress) * (1 - settleProgress) - sin(.pi * settleProgress)) / Self.settleDuration : baseVerticalVelocity
        let velocityDirection = horizontalVelocity.length > 0.01
            ? horizontalVelocity.normalized
            : (path.end - path.start).normalized
        let pitchAxis = MotionVector(x: -velocityDirection.y, y: velocityDirection.x)
        let pitch = max(-12.5, min(12.5, -atan2(verticalVelocity, max(horizontalVelocity.length, 40)) * 180 / .pi * 0.72))
        let contactRock = sin(2 * .pi * settleProgress) * (1 - settleProgress)
        let yaw = startYaw + (endYaw - startYaw) * smooth(progress) + (contacted ? settleYawDegrees * contactRock : 0)
        let yawVelocity = (endYaw - startYaw) * smoothDerivative(progress) / duration

        return CardFlightSnapshot(
            id: id,
            kind: kind,
            surface: surface,
            pose: CardPose(
                center: center,
                velocity: horizontalVelocity,
                height: height,
                verticalVelocity: verticalVelocity,
                yawDegrees: yaw,
                yawVelocity: yawVelocity,
                pitchDegrees: pitch,
                pitchAxis: pitchAxis,
                flipDegrees: 0
            ),
            normalizedProgress: progress,
            firstContactProgress: duration / max(duration + Self.settleDuration, duration),
            hasContacted: contacted
        )
    }

    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
    private func smoothDerivative(_ t: Double) -> Double { 6 * t * (1 - t) }
}

struct ScheduledDeal: Equatable, Sendable {
    let startTime: Double
    let handSlotOffset: MotionVector
    let seed: Int
}

struct CardMotionEngine: Equatable, Sendable {
    private(set) var layout: CardMotionLayout
    private(set) var deckLayerCount: Int
    private(set) var handCards: [RestingCard] = []
    private(set) var tableCards: [RestingCard] = []
    private(set) var activeFlights: [ActiveCardFlight] = []
    private(set) var contacts: [ContactRecord] = []
    private(set) var maximumConcurrentFlights = 0
    private(set) var reducedMotion = false
    private(set) var now: Double
    private var contactedFlightIDs: Set<Int> = []
    private var scheduledDeals: [ScheduledDeal] = []
    private var nextFlightID = 1

    init(layout: CardMotionLayout, deckCount: Int = 3, now: Double = 0) {
        self.layout = layout
        deckLayerCount = deckCount
        self.now = now
    }

    mutating func reset(layout: CardMotionLayout, deckCount: Int, at time: Double) {
        self = CardMotionEngine(layout: layout, deckCount: deckCount, now: time)
    }

    @discardableResult
    mutating func startDeal(at time: Double, handOffset: MotionVector = .zero, seed: Int = 0) -> Int? {
        guard deckLayerCount > 0 else { return nil }
        if reducedMotion {
            deckLayerCount -= 1
            handCards.append(RestingCard(id: nextFlightID, surface: .back, center: layout.handCenter + handOffset, yawDegrees: layout.handYaw))
            nextFlightID += 1
            now = time
            return nil
        }
        deckLayerCount -= 1
        let destination = layout.handCenter + handOffset
        let delta = destination - layout.deckCenter
        let releaseVariation = seededUnit(seed: seed, salt: 11)
        let yawVariation = seededUnit(seed: seed, salt: 29)
        let flightVariation = seededUnit(seed: seed, salt: 47)
        let settleVariation = seededUnit(seed: seed, salt: 71)
        let releaseAngle = (-3.2 + releaseVariation * 6.4) * .pi / 180
        let baseDirection = delta.normalized
        let releaseDirection = MotionVector(
            x: baseDirection.x * cos(releaseAngle) - baseDirection.y * sin(releaseAngle),
            y: baseDirection.x * sin(releaseAngle) + baseDirection.y * cos(releaseAngle)
        )
        let duration = min(max(0.34 + delta.length / 8_000 + (flightVariation - 0.5) * 0.028, 0.36), 0.41)
        let flight = ActiveCardFlight(
            id: nextFlightID,
            kind: .deal,
            surface: .back,
            destination: .hand,
            startTime: time,
            duration: duration,
            path: Hermite2D(
                start: layout.deckCenter,
                end: destination,
                startVelocity: releaseDirection * min(430, delta.length / duration * 0.74),
                endVelocity: delta.normalized * min(170, delta.length / duration * 0.28),
                duration: duration
            ),
            heightPath: nil,
            arcHeight: 38 + seededUnit(seed: seed, salt: 83) * 13,
            startYaw: layout.deckYaw + (yawVariation - 0.5) * 4.5,
            endYaw: layout.handYaw + handOffset.x * 0.08 + (yawVariation - 0.5) * 5.5,
            firstContactEnabled: true,
            settleLift: 5.4 + settleVariation * 2.2,
            settleTravel: 4.2 + settleVariation * 1.8,
            settleYawDegrees: 2.7 + settleVariation * 1.8
        )
        nextFlightID += 1
        activeFlights.append(flight)
        maximumConcurrentFlights = max(maximumConcurrentFlights, activeFlights.count)
        now = time
        return flight.id
    }

    @discardableResult
    mutating func startPlay(at time: Double) -> Int {
        let delta = layout.playCenter - layout.handCenter
        let duration = 0.64
        let flight = ActiveCardFlight(
            id: nextFlightID,
            kind: .play,
            surface: .face,
            destination: .table,
            startTime: time,
            duration: duration,
            path: Hermite2D(
                start: layout.handCenter,
                end: layout.playCenter,
                startVelocity: delta.normalized * 300,
                endVelocity: delta.normalized * 96,
                duration: duration
            ),
            heightPath: nil,
            arcHeight: min(max(layout.viewport.height * 0.095, 34), 72),
            startYaw: layout.handYaw,
            endYaw: layout.playYaw,
            firstContactEnabled: true,
            settleLift: 7.2,
            settleTravel: 5.2,
            settleYawDegrees: 4.2
        )
        nextFlightID += 1
        activeFlights.append(flight)
        maximumConcurrentFlights = max(maximumConcurrentFlights, activeFlights.count)
        now = time
        return flight.id
    }

    @discardableResult
    mutating func cancelPlay(flightID: Int, at time: Double) -> ActiveCardFlight? {
        guard let index = activeFlights.firstIndex(where: {
            $0.id == flightID && $0.kind == .play && time < $0.startTime + $0.duration
        }) else { return nil }
        let interrupted = activeFlights.remove(at: index)
        let pose = interrupted.sample(at: time).pose
        let distance = (layout.handCenter - pose.center).length
        let speed = pose.velocity.length
        let duration = min(max(0.28 + distance / 780 + min(speed / 2_400, 0.12), 0.30), 0.56)
        let returning = ActiveCardFlight(
            id: nextFlightID,
            kind: .return,
            surface: .face,
            destination: .hand,
            startTime: time,
            duration: duration,
            path: Hermite2D(
                start: pose.center,
                end: layout.handCenter,
                startVelocity: pose.velocity,
                endVelocity: .zero,
                duration: duration
            ),
            heightPath: Hermite1D(
                start: pose.height,
                end: 0,
                startVelocity: pose.verticalVelocity,
                endVelocity: 0,
                duration: duration
            ),
            arcHeight: 0,
            startYaw: pose.yawDegrees,
            endYaw: layout.handYaw,
            firstContactEnabled: false,
            settleLift: 0,
            settleTravel: 0,
            settleYawDegrees: 0
        )
        nextFlightID += 1
        activeFlights.append(returning)
        maximumConcurrentFlights = max(maximumConcurrentFlights, activeFlights.count)
        now = time
        return returning
    }

    mutating func scheduleDealBurst(count: Int, at time: Double) {
        var releaseTime = time
        scheduledDeals = (0..<min(max(count, 0), deckLayerCount)).map { index in
            let fanIndex = Double(index) - Double(max(0, count - 1)) / 2
            let offset = MotionVector(x: fanIndex * layout.cardSize.width * 0.11, y: abs(fanIndex) * 1.2)
            let scheduled = ScheduledDeal(
                startTime: releaseTime,
                handSlotOffset: offset,
                seed: index
            )
            let distance = (layout.handCenter + offset - layout.deckCenter).length
            let seededOffset = (seededUnit(seed: index, salt: 101) - 0.5) * 0.018
            releaseTime += min(max(0.24 + distance / 9_000 + seededOffset, 0.24), 0.32)
            return scheduled
        }
    }

    mutating func setReducedMotion(_ enabled: Bool, at time: Double) {
        reducedMotion = enabled
        guard enabled else { return }
        for flight in activeFlights {
            switch flight.destination {
            case .hand:
                handCards.append(RestingCard(id: flight.id, surface: flight.surface, center: flight.path.end, yawDegrees: flight.endYaw))
            case .table:
                tableCards.append(RestingCard(id: flight.id, surface: flight.surface, center: flight.path.end, yawDegrees: flight.endYaw))
            }
        }
        activeFlights.removeAll()
        scheduledDeals.removeAll()
        now = time
    }

    mutating func advance(to time: Double) -> StageSnapshot {
        now = max(now, time)
        while let first = scheduledDeals.first, first.startTime <= now {
            scheduledDeals.removeFirst()
            _ = startDeal(at: first.startTime, handOffset: first.handSlotOffset, seed: first.seed)
        }

        for flight in activeFlights where flight.firstContactEnabled {
            let contactTime = flight.startTime + flight.duration
            if now >= contactTime, !contactedFlightIDs.contains(flight.id) {
                contactedFlightIDs.insert(flight.id)
                contacts.append(ContactRecord(
                    flightID: flight.id,
                    kind: flight.kind,
                    scheduledTime: contactTime,
                    observedTime: now,
                    hapticTime: now
                ))
            }
        }

        let completed = activeFlights.filter { now >= $0.endTime }
        for flight in completed {
            switch flight.destination {
            case .hand:
                handCards.append(RestingCard(id: flight.id, surface: flight.surface, center: flight.path.end, yawDegrees: flight.endYaw))
            case .table:
                tableCards.append(RestingCard(id: flight.id, surface: flight.surface, center: flight.path.end, yawDegrees: flight.endYaw))
            }
        }
        let completedIDs = Set(completed.map(\.id))
        activeFlights.removeAll { completedIDs.contains($0.id) }
        maximumConcurrentFlights = max(maximumConcurrentFlights, activeFlights.count)
        return snapshot
    }

    var snapshot: StageSnapshot {
        StageSnapshot(
            wallclockTime: now,
            deckLayerCount: deckLayerCount,
            handCards: handCards,
            tableCards: tableCards,
            flights: activeFlights.map { $0.sample(at: now) },
            contacts: contacts,
            maximumConcurrentFlights: maximumConcurrentFlights,
            reducedMotion: reducedMotion
        )
    }

    private func seededUnit(seed: Int, salt: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed &* 1_103_515_245 &+ salt &* 12_345))
        value ^= value >> 17
        value &*= 0xED5AD4BB
        value ^= value >> 11
        return Double(value & 0xFFFF) / Double(0xFFFF)
    }
}
