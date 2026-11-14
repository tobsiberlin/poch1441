import CoreGraphics
import Foundation

struct V3: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double

    static let zero = Self(x: 0, y: 0, z: 0)
    static let up = Self(x: 0, y: 0, z: 1)

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static func * (lhs: Self, rhs: Double) -> Self {
        Self(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    static func / (lhs: Self, rhs: Double) -> Self {
        Self(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }

    var length: Double { sqrt(x * x + y * y + z * z) }
    var horizontalLength: Double { sqrt(x * x + y * y) }

    var normalized: Self {
        let divisor = max(length, 1e-12)
        return self / divisor
    }

    func dot(_ other: Self) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: Self) -> Self {
        Self(x: y * other.z - z * other.y,
             y: z * other.x - x * other.z,
             z: x * other.y - y * other.x)
    }
}

struct Quaternion: Codable, Equatable, Sendable {
    var w: Double
    var x: Double
    var y: Double
    var z: Double

    static let identity = Self(w: 1, x: 0, y: 0, z: 0)

    init(w: Double, x: Double, y: Double, z: Double) {
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }

    init(angle: Double, axis: V3) {
        let unit = axis.normalized
        let half = angle * 0.5
        w = cos(half)
        x = unit.x * sin(half)
        y = unit.y * sin(half)
        z = unit.z * sin(half)
    }

    static func * (lhs: Self, rhs: Self) -> Self {
        Self(
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
            z: lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w
        ).normalized
    }

    var normalized: Self {
        let divisor = max(sqrt(w * w + x * x + y * y + z * z), 1e-12)
        return Self(w: w / divisor, x: x / divisor, y: y / divisor, z: z / divisor)
    }

    func rotated(_ vector: V3) -> V3 {
        let qv = V3(x: x, y: y, z: z)
        let t = qv.cross(vector) * 2
        return vector + t * w + qv.cross(t)
    }

    static func integrated(from start: Self, angularVelocity: V3, time: Double) -> Self {
        let speed = angularVelocity.length
        guard speed > 1e-9 else { return start }
        return Self(angle: speed * time, axis: angularVelocity) * start
    }
}

enum CoinSegment: String, Codable, Sendable {
    case ballisticFlight
    case firstContact
    case afterrun
    case rest
}

struct CoinState: Codable, Equatable, Sendable {
    let time: Double
    let segment: CoinSegment
    let position: V3
    let linearVelocity: V3
    let orientation: Quaternion
    let angularVelocity: V3
    let bottomGap: Double
    let collisionCount: Int
}

struct CoinMotionMetrics: Codable, Sendable {
    let seed: UInt64
    let contactTime: Double
    let secondContactTime: Double
    let restTime: Double
    let preContactSpeed: Double
    let postContactSpeed: Double
    let preContactEnergy: Double
    let postContactEnergy: Double
    let restPoint: V3
    let safeZoneDistance: Double
    let collisionCount: Int
    let didSnap: Bool
    let didZeroVelocity: Bool
}

struct CoinMotionPlan: Sendable {
    static let gravity = 9.81
    static let mass = 0.00230
    static let radius = 0.008125
    static let thickness = 0.00167
    static let safeZoneRadius = 0.0125

    let seed: UInt64
    let target: V3
    let start: V3
    let initialVelocity: V3
    let initialAngularVelocity: V3
    let initialOrientation: Quaternion
    let preContactVelocity: V3
    let postContactVelocity: V3
    let postContactAngularVelocity: V3
    let firstContactTime: Double
    let secondContactTime: Double
    let slideStartTime: Double
    let restTime: Double
    let firstContactPosition: V3
    let secondContactPosition: V3
    let slideStartPosition: V3
    let slideAcceleration: V3
    let firstContactOrientation: Quaternion
    let secondContactOrientation: Quaternion
    let slideStartOrientation: Quaternion
    let slideStartAngularVelocity: V3

    init(seed: UInt64) {
        self.seed = seed
        var random = StableRandom(seed: seed)

        let targetAngle = random.unit(in: 0...(2 * .pi))
        let targetRadius = sqrt(random.unit(in: 0...1)) * Self.safeZoneRadius * 0.62
        target = V3(x: cos(targetAngle) * targetRadius,
                    y: sin(targetAngle) * targetRadius,
                    z: 0)

        let travelAngle = random.unit(in: (-0.20)...0.20)
        let horizontalSpeed = random.unit(in: 0.225...0.252)
        let direction = V3(x: cos(travelAngle), y: sin(travelAngle), z: 0)
        let contactTime = random.unit(in: 0.326...0.354)
        firstContactTime = contactTime

        let verticalVelocity = random.unit(in: 0.39...0.48)
        let initialHeight = 0.5 * Self.gravity * contactTime * contactTime
            - verticalVelocity * contactTime
        initialVelocity = direction * horizontalSpeed + V3(x: 0, y: 0, z: verticalVelocity)
        preContactVelocity = initialVelocity + V3(x: 0, y: 0, z: -Self.gravity * contactTime)

        let initialTilt = random.unit(in: 0.34...0.72)
        let tiltAxis = V3(x: random.unit(in: -1...1),
                          y: random.unit(in: -1...1),
                          z: 0).normalized
        initialOrientation = Quaternion(angle: initialTilt, axis: tiltAxis)
        initialAngularVelocity = V3(x: random.unit(in: 9.5...14.0),
                                    y: random.unit(in: -5.2...5.2),
                                    z: random.unit(in: 11.0...17.0))
        firstContactOrientation = Quaternion.integrated(
            from: initialOrientation,
            angularVelocity: initialAngularVelocity,
            time: contactTime
        )

        let restitution = random.unit(in: 0.205...0.235)
        let support = Self.supportVector(orientation: firstContactOrientation)
        let radialInertia = Self.mass * (3 * Self.radius * Self.radius
            + Self.thickness * Self.thickness) / 12
        let normal = V3.up
        let preContactPointVelocity = preContactVelocity
            + initialAngularVelocity.cross(support)
        let normalEffectiveMass = 1 / Self.mass
            + normal.dot((support.cross(normal) / radialInertia).cross(support))
        let contactNormalImpulse = max(
            0,
            -(1 + restitution) * preContactPointVelocity.dot(normal)
                / max(normalEffectiveMass, 1e-9)
        )
        // A finite coin contacts through a small manifold, not a mathematical
        // point. The second support point supplies enough normal impulse that
        // the centre of mass cannot continue through the tray plane.
        let minimumCenterRebound = restitution * abs(preContactVelocity.z)
        let manifoldSupportImpulse = Self.mass
            * (minimumCenterRebound - preContactVelocity.z)
        let normalImpulseMagnitude = max(contactNormalImpulse,
                                         manifoldSupportImpulse)
        let normalImpulse = normal * normalImpulseMagnitude
        let velocityAfterNormal = preContactVelocity + normalImpulse / Self.mass
        let angularAfterNormal = initialAngularVelocity
            + support.cross(normalImpulse) / radialInertia
        let pointVelocityAfterNormal = velocityAfterNormal
            + angularAfterNormal.cross(support)
        let tangentVelocity = V3(x: pointVelocityAfterNormal.x,
                                 y: pointVelocityAfterNormal.y,
                                 z: 0)
        // Worn copper against the smooth snack-box polymer is deliberately a
        // low-friction impact pair. Higher values cancel all lateral motion in
        // the single normal impulse and recreate the fake "slot" stop.
        let friction = random.unit(in: 0.052...0.068)
        let tangent = tangentVelocity.horizontalLength > 1e-9
            ? tangentVelocity.normalized
            : .zero
        let tangentEffectiveMass = 1 / Self.mass
            + tangent.dot((support.cross(tangent) / radialInertia).cross(support))
        let freeTangentImpulse = tangentVelocity.horizontalLength > 1e-9
            ? -tangentVelocity.horizontalLength / max(tangentEffectiveMass, 1e-9)
            : 0
        let tangentLimit = friction * normalImpulseMagnitude
        let tangentImpulseMagnitude = min(tangentLimit,
                                          max(-tangentLimit, freeTangentImpulse))
        let tangentImpulse = tangent * tangentImpulseMagnitude
        let impulse = normalImpulse + tangentImpulse
        postContactVelocity = preContactVelocity + impulse / Self.mass
        let angularImpulse = support.cross(impulse)
        postContactAngularVelocity = initialAngularVelocity
            + angularImpulse / radialInertia

        let hopTime = max(0.070, 2 * postContactVelocity.z / Self.gravity)
        secondContactTime = contactTime + hopTime
        firstContactPosition = .zero
        let firstToSecond = postContactVelocity * hopTime
            + V3(x: 0, y: 0, z: -0.5 * Self.gravity * hopTime * hopTime)
        secondContactPosition = firstToSecond
        secondContactOrientation = Quaternion.integrated(
            from: firstContactOrientation,
            angularVelocity: postContactAngularVelocity,
            time: hopTime
        )

        let secondRestitution = 0.08
        let secondPreVertical = postContactVelocity.z - Self.gravity * hopTime
        let secondPostVertical = -secondPreVertical * secondRestitution
        let microHopTime = 2 * secondPostVertical / Self.gravity
        slideStartTime = secondContactTime + microHopTime
        let secondHorizontalVelocity = V3(x: postContactVelocity.x * 0.72,
                                          y: postContactVelocity.y * 0.72,
                                          z: secondPostVertical)
        slideStartPosition = secondContactPosition
            + secondHorizontalVelocity * microHopTime
            + V3(x: 0, y: 0, z: -0.5 * Self.gravity * microHopTime * microHopTime)
        slideStartOrientation = Quaternion.integrated(
            from: secondContactOrientation,
            angularVelocity: postContactAngularVelocity * 0.68,
            time: microHopTime
        )
        slideStartAngularVelocity = postContactAngularVelocity * 0.48

        let slideHorizontalVelocity = V3(x: secondHorizontalVelocity.x * 0.66,
                                         y: secondHorizontalVelocity.y * 0.66,
                                         z: 0)
        let slideDeceleration = random.unit(in: 0.72...0.88)
        let slideDuration = slideHorizontalVelocity.horizontalLength / slideDeceleration
        restTime = slideStartTime + slideDuration
        slideAcceleration = slideHorizontalVelocity.horizontalLength > 1e-9
            ? slideHorizontalVelocity.normalized * (-slideDeceleration)
            : .zero
        let slideDisplacement = slideHorizontalVelocity * slideDuration
            + slideAcceleration * (0.5 * slideDuration * slideDuration)
        let fullHorizontalDisplacement = direction * horizontalSpeed * contactTime
            + V3(x: firstToSecond.x, y: firstToSecond.y, z: 0)
            + V3(x: slideStartPosition.x - secondContactPosition.x,
                 y: slideStartPosition.y - secondContactPosition.y,
                 z: 0)
            + slideDisplacement
        start = target - fullHorizontalDisplacement + V3(x: 0, y: 0, z: initialHeight)
    }

    func state(at rawTime: Double, reducedMotion: Bool = false) -> CoinState {
        if reducedMotion {
            return CoinState(time: max(0, rawTime),
                             segment: .rest,
                             position: target,
                             linearVelocity: .zero,
                             orientation: restingOrientation,
                             angularVelocity: .zero,
                             bottomGap: 0,
                             collisionCount: 0)
        }
        let time = max(0, rawTime)
        if time < firstContactTime {
            let position = start + initialVelocity * time
                + V3(x: 0, y: 0, z: -0.5 * Self.gravity * time * time)
            let velocity = initialVelocity + V3(x: 0, y: 0, z: -Self.gravity * time)
            let orientation = Quaternion.integrated(from: initialOrientation,
                                                    angularVelocity: initialAngularVelocity,
                                                    time: time)
            return resolvedState(time: time,
                                 segment: .ballisticFlight,
                                 position: position,
                                 velocity: velocity,
                                 orientation: orientation,
                                 angularVelocity: initialAngularVelocity,
                                 collisions: 0)
        }
        if time < firstContactTime + (1.0 / 60.0) {
            let position = V3(x: start.x + initialVelocity.x * firstContactTime,
                              y: start.y + initialVelocity.y * firstContactTime,
                              z: 0)
            return resolvedState(time: time,
                                 segment: .firstContact,
                                 position: position,
                                 velocity: postContactVelocity,
                                 orientation: firstContactOrientation,
                                 angularVelocity: postContactAngularVelocity,
                                 collisions: 1)
        }
        if time < secondContactTime {
            let local = time - firstContactTime
            let position = V3(x: start.x + initialVelocity.x * firstContactTime,
                              y: start.y + initialVelocity.y * firstContactTime,
                              z: 0)
                + postContactVelocity * local
                + V3(x: 0, y: 0, z: -0.5 * Self.gravity * local * local)
            let velocity = postContactVelocity + V3(x: 0, y: 0, z: -Self.gravity * local)
            let orientation = Quaternion.integrated(from: firstContactOrientation,
                                                    angularVelocity: postContactAngularVelocity,
                                                    time: local)
            return resolvedState(time: time,
                                 segment: .afterrun,
                                 position: position,
                                 velocity: velocity,
                                 orientation: orientation,
                                 angularVelocity: postContactAngularVelocity,
                                 collisions: 1)
        }
        if time < slideStartTime {
            let local = time - secondContactTime
            let secondVelocity = V3(x: postContactVelocity.x * 0.72,
                                    y: postContactVelocity.y * 0.72,
                                    z: max(0, -(postContactVelocity.z
                                        - Self.gravity * (secondContactTime - firstContactTime))) * 0.08)
            let position = V3(x: start.x + initialVelocity.x * firstContactTime + secondContactPosition.x,
                              y: start.y + initialVelocity.y * firstContactTime + secondContactPosition.y,
                              z: 0)
                + secondVelocity * local
                + V3(x: 0, y: 0, z: -0.5 * Self.gravity * local * local)
            let orientation = Quaternion.integrated(from: secondContactOrientation,
                                                    angularVelocity: postContactAngularVelocity * 0.68,
                                                    time: local)
            return resolvedState(time: time,
                                 segment: .afterrun,
                                 position: position,
                                 velocity: secondVelocity + V3(x: 0, y: 0, z: -Self.gravity * local),
                                 orientation: orientation,
                                 angularVelocity: postContactAngularVelocity * 0.68,
                                 collisions: 2)
        }
        if time < restTime {
            let local = time - slideStartTime
            let slideVelocity = V3(x: postContactVelocity.x * 0.72 * 0.66,
                                   y: postContactVelocity.y * 0.72 * 0.66,
                                   z: 0)
            let position = V3(x: start.x + initialVelocity.x * firstContactTime + slideStartPosition.x,
                              y: start.y + initialVelocity.y * firstContactTime + slideStartPosition.y,
                              z: 0)
                + slideVelocity * local + slideAcceleration * (0.5 * local * local)
            let velocity = slideVelocity + slideAcceleration * local
            let fraction = min(1, local / max(restTime - slideStartTime, 1e-9))
            let angularVelocity = slideStartAngularVelocity * (1 - fraction)
            let averageAngularVelocity = slideStartAngularVelocity * (1 - 0.5 * fraction)
            let orientation = Quaternion.integrated(from: slideStartOrientation,
                                                    angularVelocity: averageAngularVelocity,
                                                    time: local)
            return resolvedState(time: time,
                                 segment: .afterrun,
                                 position: position,
                                 velocity: velocity,
                                 orientation: orientation,
                                 angularVelocity: angularVelocity,
                                 collisions: 2)
        }
        return CoinState(time: time,
                         segment: .rest,
                         position: target,
                         linearVelocity: .zero,
                         orientation: restingOrientation,
                         angularVelocity: .zero,
                         bottomGap: 0,
                         collisionCount: 2)
    }

    var duration: Double { restTime + 0.18 }

    var restingOrientation: Quaternion {
        let slideDuration = max(0, restTime - slideStartTime)
        return Quaternion.integrated(from: slideStartOrientation,
                                     angularVelocity: slideStartAngularVelocity * 0.5,
                                     time: slideDuration)
    }

    var metrics: CoinMotionMetrics {
        CoinMotionMetrics(
            seed: seed,
            contactTime: firstContactTime,
            secondContactTime: secondContactTime,
            restTime: restTime,
            preContactSpeed: preContactVelocity.length,
            postContactSpeed: postContactVelocity.length,
            preContactEnergy: mechanicalEnergy(velocity: preContactVelocity,
                                               angularVelocity: initialAngularVelocity),
            postContactEnergy: mechanicalEnergy(velocity: postContactVelocity,
                                                angularVelocity: postContactAngularVelocity),
            restPoint: target,
            safeZoneDistance: target.horizontalLength,
            collisionCount: 2,
            didSnap: false,
            didZeroVelocity: false
        )
    }

    private func resolvedState(time: Double,
                               segment: CoinSegment,
                               position: V3,
                               velocity: V3,
                               orientation: Quaternion,
                               angularVelocity: V3,
                               collisions: Int) -> CoinState {
        let gap = max(0, position.z)
        let support = Self.verticalSupport(orientation: orientation)
        return CoinState(time: time,
                         segment: segment,
                         position: V3(x: position.x, y: position.y, z: gap + support),
                         linearVelocity: velocity,
                         orientation: orientation,
                         angularVelocity: angularVelocity,
                         bottomGap: gap,
                         collisionCount: collisions)
    }

    private func mechanicalEnergy(velocity: V3, angularVelocity: V3) -> Double {
        let translational = 0.5 * Self.mass * velocity.dot(velocity)
        let radial = Self.mass * (3 * Self.radius * Self.radius
            + Self.thickness * Self.thickness) / 12
        let axial = 0.5 * Self.mass * Self.radius * Self.radius
        let rotational = 0.5 * radial * (angularVelocity.x * angularVelocity.x
            + angularVelocity.y * angularVelocity.y)
            + 0.5 * axial * angularVelocity.z * angularVelocity.z
        return translational + rotational
    }

    private static func supportVector(orientation: Quaternion) -> V3 {
        let normal = orientation.rotated(.up)
        let horizontalNormal = V3(x: normal.x, y: normal.y, z: 0)
        let radialDirection = horizontalNormal.length > 1e-9
            ? horizontalNormal.normalized * (-radius)
            : .zero
        let cap = normal * (-thickness * 0.5 * (normal.z >= 0 ? 1 : -1))
        return radialDirection + cap
    }

    static func verticalSupport(orientation: Quaternion) -> Double {
        let normal = orientation.rotated(.up)
        let radial = radius * sqrt(max(0, 1 - normal.z * normal.z))
        return radial + thickness * 0.5 * abs(normal.z)
    }
}

private struct StableRandom: Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func unit(in range: ClosedRange<Double>) -> Double {
        let fraction = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    }
}
