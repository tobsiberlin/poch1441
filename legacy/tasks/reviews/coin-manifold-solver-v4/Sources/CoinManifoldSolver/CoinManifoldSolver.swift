import Foundation
import simd

public typealias Vector3 = SIMD3<Double>

@inline(__always)
func clamped(_ value: Double, _ range: ClosedRange<Double>) -> Double {
    min(max(value, range.lowerBound), range.upperBound)
}

public struct SolverBudget: Sendable, Equatable {
    public let step: Double
    public let stepsPerRenderFrame: Int
    public let velocityIterations: Int
    public let contactBand: Double
    public let penetrationSlop: Double
    public let baumgarte: Double
    public let rollingResistance: Double
    public let sleepDelay: Double
    public let linearSleepThreshold: Double
    public let angularSleepThreshold: Double

    /// Frozen before the first v4 run. Changing this creates a new spike version.
    public static let v4 = SolverBudget(
        step: 1.0 / 240.0,
        stepsPerRenderFrame: 4,
        velocityIterations: 18,
        contactBand: 0.00015,
        penetrationSlop: 0.000015,
        baumgarte: 0.16,
        rollingResistance: 0.012,
        sleepDelay: 0.50,
        linearSleepThreshold: 0.015,
        angularSleepThreshold: 0.8
    )
}

public enum CoinShape: Sendable, Equatable {
    case cylinder(segments: Int)
    case boxControl

    public static let radius = 0.011
    public static let halfThickness = 0.0011
    public static let mass = 0.0045

    public var contactSegments: Int {
        switch self {
        case .cylinder(let segments): max(segments, 12)
        case .boxControl: 4
        }
    }

    public func localVertices() -> [(feature: Int, point: Vector3)] {
        switch self {
        case .boxControl:
            var values: [(Int, Vector3)] = []
            var feature = 0
            for y in [-Self.halfThickness, Self.halfThickness] {
                for x in [-Self.radius, Self.radius] {
                    for z in [-Self.radius, Self.radius] {
                        values.append((feature, Vector3(x, y, z)))
                        feature += 1
                    }
                }
            }
            return values
        case .cylinder(let requestedSegments):
            let segments = max(requestedSegments, 12)
            var values: [(Int, Vector3)] = []
            values.reserveCapacity(segments * 2)
            for cap in 0..<2 {
                let y = cap == 0 ? -Self.halfThickness : Self.halfThickness
                for index in 0..<segments {
                    let angle = 2 * Double.pi * Double(index) / Double(segments)
                    values.append((cap * segments + index,
                                   Vector3(Self.radius * cos(angle), y, Self.radius * sin(angle))))
                }
            }
            return values
        }
    }

    public func support(direction: Vector3) -> (feature: Int, point: Vector3) {
        switch self {
        case .boxControl:
            let point = Vector3(
                direction.x < 0 ? -Self.radius : Self.radius,
                direction.y < 0 ? -Self.halfThickness : Self.halfThickness,
                direction.z < 0 ? -Self.radius : Self.radius
            )
            let feature = (direction.y < 0 ? 0 : 4)
                + (direction.x < 0 ? 0 : 2)
                + (direction.z < 0 ? 0 : 1)
            return (feature, point)
        case .cylinder(let requestedSegments):
            let segments = max(requestedSegments, 12)
            let cap = direction.y < 0 ? 0 : 1
            let radialLength = hypot(direction.x, direction.z)
            guard radialLength > 1e-15 else {
                return (cap * segments,
                        Vector3(Self.radius, cap == 0 ? -Self.halfThickness : Self.halfThickness, 0))
            }
            let rawAngle = atan2(direction.z, direction.x)
            let normalized = rawAngle < 0 ? rawAngle + 2 * .pi : rawAngle
            let index = Int((normalized / (2 * .pi) * Double(segments)).rounded()) % segments
            let angle = 2 * Double.pi * Double(index) / Double(segments)
            return (cap * segments + index,
                    Vector3(Self.radius * cos(angle),
                            cap == 0 ? -Self.halfThickness : Self.halfThickness,
                            Self.radius * sin(angle)))
        }
    }

    public func supportExtent(direction: Vector3) -> Double {
        let local = simd_normalize(direction)
        switch self {
        case .boxControl:
            return Self.radius * abs(local.x)
                + Self.halfThickness * abs(local.y)
                + Self.radius * abs(local.z)
        case .cylinder:
            let radial = support(direction: Vector3(local.x, 0, local.z)).point
            return Self.halfThickness * abs(local.y) + abs(radial.x * local.x + radial.z * local.z)
        }
    }

    public var inertia: Vector3 {
        let mass = Self.mass
        switch self {
        case .boxControl:
            let width = 2 * Self.radius
            let height = 2 * Self.halfThickness
            return Vector3(
                mass * (height * height + width * width) / 12,
                mass * (width * width + width * width) / 12,
                mass * (width * width + height * height) / 12
            )
        case .cylinder:
            let thickness = 2 * Self.halfThickness
            let radial = mass * (3 * Self.radius * Self.radius + thickness * thickness) / 12
            return Vector3(radial, 0.5 * mass * Self.radius * Self.radius, radial)
        }
    }
}

public struct RigidCoin: Sendable, Equatable {
    public let id: Int
    public let shape: CoinShape
    public var position: Vector3
    public var orientation: simd_quatd
    public var linearVelocity: Vector3
    public var angularVelocity: Vector3
    public var friction: Double
    public var restitution: Double
    public var asleep: Bool
    public var quietDuration: Double

    public init(id: Int,
                shape: CoinShape,
                position: Vector3,
                orientation: simd_quatd,
                linearVelocity: Vector3,
                angularVelocity: Vector3,
                friction: Double,
                restitution: Double) {
        self.id = id
        self.shape = shape
        self.position = position
        self.orientation = simd_normalize(orientation)
        self.linearVelocity = linearVelocity
        self.angularVelocity = angularVelocity
        self.friction = friction
        self.restitution = restitution
        self.asleep = false
        self.quietDuration = 0
    }

    public var inverseMass: Double { 1 / CoinShape.mass }

    public func inverseInertiaApplied(to worldVector: Vector3) -> Vector3 {
        let local = orientation.inverse.act(worldVector)
        let inertia = shape.inertia
        let localResult = Vector3(local.x / inertia.x, local.y / inertia.y, local.z / inertia.z)
        return orientation.act(localResult)
    }

    public func worldPoint(local: Vector3) -> Vector3 {
        position + orientation.act(local)
    }

    public mutating func applyImpulse(_ impulse: Vector3, at worldPoint: Vector3) {
        linearVelocity += impulse * inverseMass
        let lever = worldPoint - position
        angularVelocity += inverseInertiaApplied(to: simd_cross(lever, impulse))
    }

    public mutating func applyAngularImpulse(_ impulse: Vector3) {
        angularVelocity += inverseInertiaApplied(to: impulse)
    }

    public mutating func integrate(duration: Double) {
        position += linearVelocity * duration
        let speed = simd_length(angularVelocity)
        if speed > 1e-14 {
            let delta = simd_quatd(angle: speed * duration, axis: angularVelocity / speed)
            orientation = simd_normalize(delta * orientation)
        }
    }
}

public struct PlanePatch: Sendable, Equatable {
    public let id: Int
    public let name: String
    public let point: Vector3
    public let normal: Vector3
    public let tangentU: Vector3
    public let tangentV: Vector3
    public let halfU: Double
    public let halfV: Double
    public let friction: Double
    public let restitution: Double

    public init(id: Int,
                name: String,
                point: Vector3,
                normal: Vector3,
                tangentU: Vector3,
                halfU: Double,
                halfV: Double,
                friction: Double,
                restitution: Double) {
        let n = simd_normalize(normal)
        let u = simd_normalize(tangentU - n * simd_dot(tangentU, n))
        self.id = id
        self.name = name
        self.point = point
        self.normal = n
        self.tangentU = u
        self.tangentV = simd_normalize(simd_cross(n, u))
        self.halfU = halfU
        self.halfV = halfV
        self.friction = friction
        self.restitution = restitution
    }

    public func coordinates(of worldPoint: Vector3) -> SIMD2<Double> {
        let relative = worldPoint - point
        return SIMD2(simd_dot(relative, tangentU), simd_dot(relative, tangentV))
    }

    public func contains(_ worldPoint: Vector3, expansion: Double = 0) -> Bool {
        let uv = coordinates(of: worldPoint)
        return abs(uv.x) <= halfU + expansion && abs(uv.y) <= halfV + expansion
    }

    public func signedDistance(to worldPoint: Vector3) -> Double {
        simd_dot(worldPoint - point, normal)
    }
}

public struct ContactID: Hashable, Comparable, Sendable {
    public let body: Int
    public let surface: Int
    public let feature: Int

    public static func < (lhs: ContactID, rhs: ContactID) -> Bool {
        if lhs.body != rhs.body { return lhs.body < rhs.body }
        if lhs.surface != rhs.surface { return lhs.surface < rhs.surface }
        return lhs.feature < rhs.feature
    }
}

public struct ContactPoint: Sendable, Equatable {
    public let id: ContactID
    public let surfaceID: Int
    public let worldPoint: Vector3
    public let normal: Vector3
    public let tangentU: Vector3
    public let tangentV: Vector3
    public let penetration: Double
    public let friction: Double
    public let restitution: Double
}

struct CachedImpulse: Sendable {
    var normal: Double = 0
    var tangentU: Double = 0
    var tangentV: Double = 0
    var lastSeenStep: Int = 0
}

public struct SolverStepMetrics: Sendable, Equatable {
    public var contactIDs: [ContactID] = []
    public var maximumPenetration: Double = 0
    public var floorContact = false
    public var lipContact = false
    public var warmStartedContacts = 0
    public var generatedContactCount = 0
    public var ccdImpacts = 0
}

public final class PersistentManifoldSolver: @unchecked Sendable {
    public static let floorID = 1
    public static let lipID = 2
    public static let gravity = Vector3(0, -9.81, 0)

    public let budget: SolverBudget
    public let surfaces: [PlanePatch]
    private var cache: [ContactID: CachedImpulse] = [:]
    private var stepIndex = 0

    public init(budget: SolverBudget = .v4,
                floorFriction: Double = 0.65,
                floorRestitution: Double = 0) {
        self.budget = budget
        let floor = PlanePatch(
            id: Self.floorID,
            name: "floor",
            point: .zero,
            normal: Vector3(0, 1, 0),
            tangentU: Vector3(1, 0, 0),
            halfU: 0.09,
            halfV: 0.07,
            friction: floorFriction,
            restitution: floorRestitution
        )
        let lipAngle = -25.0 * Double.pi / 180
        let lipRotation = simd_quatd(angle: lipAngle, axis: Vector3(1, 0, 0))
        let lipNormal = lipRotation.act(Vector3(0, 1, 0))
        let lipCenter = Vector3(0, 0.010, 0.064)
        let lipTop = lipCenter + lipNormal * 0.003
        let lip = PlanePatch(
            id: Self.lipID,
            name: "front-lip",
            point: lipTop,
            normal: lipNormal,
            tangentU: Vector3(1, 0, 0),
            halfU: 0.095,
            halfV: 0.015,
            friction: 0.62,
            restitution: 0.12
        )
        self.surfaces = [floor, lip]
    }

    public func reset() {
        cache.removeAll(keepingCapacity: true)
        stepIndex = 0
    }

    public func persistentImpulseCount() -> Int { cache.count }

    public func analyticSeparation(body: RigidCoin, surface: PlanePatch) -> Double {
        let localNormal = body.orientation.inverse.act(surface.normal)
        let extent = body.shape.supportExtent(direction: -localNormal)
        let projectedCenter = body.position - surface.normal * extent
        guard surface.contains(projectedCenter, expansion: CoinShape.radius) else {
            return .infinity
        }
        return surface.signedDistance(to: body.position) - extent
    }

    public func maximumAnalyticPenetration(body: RigidCoin) -> Double {
        surfaces.reduce(0) { maximum, surface in
            max(maximum, max(0, -analyticSeparation(body: body, surface: surface)))
        }
    }

    public func manifold(body: RigidCoin) -> [ContactPoint] {
        var allContacts: [ContactPoint] = []
        for surface in surfaces {
            let vertices = body.shape.localVertices()
            var candidates: [ContactPoint] = []
            candidates.reserveCapacity(vertices.count)
            for vertex in vertices {
                let world = body.worldPoint(local: vertex.point)
                let distance = surface.signedDistance(to: world)
                guard distance <= budget.contactBand,
                      surface.contains(world, expansion: budget.contactBand) else { continue }
                candidates.append(ContactPoint(
                    id: ContactID(body: body.id, surface: surface.id, feature: vertex.feature),
                    surfaceID: surface.id,
                    worldPoint: world,
                    normal: surface.normal,
                    tangentU: surface.tangentU,
                    tangentV: surface.tangentV,
                    penetration: max(0, -distance),
                    friction: sqrt(body.friction * surface.friction),
                    restitution: max(body.restitution, surface.restitution)
                ))
            }

            if candidates.isEmpty {
                let localDirection = body.orientation.inverse.act(-surface.normal)
                let support = body.shape.support(direction: localDirection)
                let world = body.worldPoint(local: support.point)
                let distance = surface.signedDistance(to: world)
                if distance <= budget.contactBand,
                   surface.contains(world, expansion: budget.contactBand) {
                    candidates.append(ContactPoint(
                        id: ContactID(body: body.id, surface: surface.id, feature: support.feature),
                        surfaceID: surface.id,
                        worldPoint: world,
                        normal: surface.normal,
                        tangentU: surface.tangentU,
                        tangentV: surface.tangentV,
                        penetration: max(0, -distance),
                        friction: sqrt(body.friction * surface.friction),
                        restitution: max(body.restitution, surface.restitution)
                    ))
                }
            }
            allContacts.append(contentsOf: selectDistributed(candidates, limit: 4))
        }
        return allContacts.sorted { $0.id < $1.id }
    }

    private func selectDistributed(_ candidates: [ContactPoint], limit: Int) -> [ContactPoint] {
        guard candidates.count > limit else { return candidates.sorted { $0.id < $1.id } }
        var remaining = candidates.sorted {
            if $0.penetration != $1.penetration { return $0.penetration > $1.penetration }
            return $0.id < $1.id
        }
        var selected = [remaining.removeFirst()]
        while selected.count < limit, !remaining.isEmpty {
            let nextIndex = remaining.indices.max { lhs, rhs in
                let leftDistance = selected.map {
                    simd_length_squared(remaining[lhs].worldPoint - $0.worldPoint)
                }.min() ?? 0
                let rightDistance = selected.map {
                    simd_length_squared(remaining[rhs].worldPoint - $0.worldPoint)
                }.min() ?? 0
                if leftDistance != rightDistance { return leftDistance < rightDistance }
                return remaining[lhs].id > remaining[rhs].id
            } ?? remaining.startIndex
            selected.append(remaining.remove(at: nextIndex))
        }
        return selected.sorted { $0.id < $1.id }
    }

    public func step(body: inout RigidCoin) -> SolverStepMetrics {
        stepIndex += 1
        guard !body.asleep else {
            return SolverStepMetrics()
        }

        let dt = budget.step
        body.linearVelocity += Self.gravity * dt
        var metrics = SolverStepMetrics()

        var contacts = manifold(body: body)
        if !contacts.isEmpty {
            solve(body: &body, contacts: contacts, duration: dt, metrics: &metrics)
        }

        var remaining = dt
        var ccdPasses = 0
        while remaining > 1e-10, ccdPasses < 2 {
            if let toi = earliestTOI(body: body, duration: remaining), toi < remaining {
                body.integrate(duration: toi)
                remaining -= toi
                contacts = manifold(body: body)
                if !contacts.isEmpty {
                    solve(body: &body, contacts: contacts, duration: dt, metrics: &metrics)
                    metrics.ccdImpacts += 1
                } else {
                    let nudge = min(remaining, 1e-8)
                    body.integrate(duration: nudge)
                    remaining -= nudge
                }
                ccdPasses += 1
            } else {
                body.integrate(duration: remaining)
                remaining = 0
            }
        }
        if remaining > 0 {
            body.integrate(duration: remaining)
        }

        contacts = manifold(body: body)
        if !contacts.isEmpty {
            solve(body: &body, contacts: contacts, duration: dt, metrics: &metrics)
        }
        metrics.maximumPenetration = max(metrics.maximumPenetration,
                                         maximumAnalyticPenetration(body: body))

        let linearQuiet = simd_length(body.linearVelocity) < budget.linearSleepThreshold
        let angularQuiet = simd_length(body.angularVelocity) < budget.angularSleepThreshold
        if linearQuiet && angularQuiet && !contacts.isEmpty {
            body.quietDuration += dt
            if body.quietDuration >= budget.sleepDelay {
                // Natural sleep: retain the measured residual velocities; do not zero them.
                body.asleep = true
            }
        } else {
            body.quietDuration = 0
        }

        cache = cache.filter { _, value in stepIndex - value.lastSeenStep <= 2 }
        return metrics
    }

    private func earliestTOI(body: RigidCoin, duration: Double) -> Double? {
        var earliest: Double?
        for surface in surfaces {
            let start = analyticSeparation(body: body, surface: surface)
            guard start.isFinite, start > 0 else { continue }
            var predicted = body
            predicted.integrate(duration: duration)
            let end = analyticSeparation(body: predicted, surface: surface)
            guard end.isFinite, end <= 0 else { continue }

            var low = 0.0
            var high = duration
            for _ in 0..<18 {
                let middle = (low + high) * 0.5
                var sample = body
                sample.integrate(duration: middle)
                let separation = analyticSeparation(body: sample, surface: surface)
                if separation > 0 { low = middle } else { high = middle }
            }
            if earliest == nil || high < earliest! { earliest = high }
        }
        return earliest
    }

    private func solve(body: inout RigidCoin,
                       contacts: [ContactPoint],
                       duration: Double,
                       metrics: inout SolverStepMetrics) {
        guard !contacts.isEmpty else { return }
        metrics.generatedContactCount = max(metrics.generatedContactCount, contacts.count)
        metrics.contactIDs.append(contentsOf: contacts.map(\.id))
        metrics.maximumPenetration = max(metrics.maximumPenetration,
                                         contacts.map(\.penetration).max() ?? 0)

        for contact in contacts {
            guard let cached = cache[contact.id] else { continue }
            let impulse = contact.normal * cached.normal
                + contact.tangentU * cached.tangentU
                + contact.tangentV * cached.tangentV
            body.applyImpulse(impulse, at: contact.worldPoint)
            metrics.warmStartedContacts += 1
        }

        for _ in 0..<budget.velocityIterations {
            for contact in contacts {
                var cached = cache[contact.id] ?? CachedImpulse()
                let lever = contact.worldPoint - body.position
                var pointVelocity = body.linearVelocity + simd_cross(body.angularVelocity, lever)
                let normalVelocity = simd_dot(pointVelocity, contact.normal)
                let normalMass = effectiveMass(body: body, lever: lever, direction: contact.normal)
                let penetrationError = max(0, contact.penetration - budget.penetrationSlop)
                let positionTarget = budget.baumgarte * penetrationError / duration
                let bounceTarget = normalVelocity < -0.20 ? -contact.restitution * normalVelocity : 0
                let targetVelocity = max(positionTarget, bounceTarget)
                let normalDelta = (targetVelocity - normalVelocity) * normalMass
                let oldNormal = cached.normal
                cached.normal = max(0, oldNormal + normalDelta)
                body.applyImpulse(contact.normal * (cached.normal - oldNormal), at: contact.worldPoint)

                pointVelocity = body.linearVelocity + simd_cross(body.angularVelocity, lever)
                let oldU = cached.tangentU
                let oldV = cached.tangentV
                cached.tangentU -= simd_dot(pointVelocity, contact.tangentU)
                    * effectiveMass(body: body, lever: lever, direction: contact.tangentU)
                cached.tangentV -= simd_dot(pointVelocity, contact.tangentV)
                    * effectiveMass(body: body, lever: lever, direction: contact.tangentV)
                let frictionLimit = contact.friction * cached.normal
                let tangentMagnitude = hypot(cached.tangentU, cached.tangentV)
                if tangentMagnitude > frictionLimit, tangentMagnitude > 0 {
                    let scale = frictionLimit / tangentMagnitude
                    cached.tangentU *= scale
                    cached.tangentV *= scale
                }
                let frictionImpulse = contact.tangentU * (cached.tangentU - oldU)
                    + contact.tangentV * (cached.tangentV - oldV)
                body.applyImpulse(frictionImpulse, at: contact.worldPoint)
                cached.lastSeenStep = stepIndex
                cache[contact.id] = cached
            }
        }

        for contact in contacts {
            guard let cached = cache[contact.id], cached.normal > 0 else { continue }
            let tangentOmega = body.angularVelocity
                - contact.normal * simd_dot(body.angularVelocity, contact.normal)
            let speed = simd_length(tangentOmega)
            guard speed > 1e-12 else { continue }
            let maximumTorqueImpulse = budget.rollingResistance * cached.normal * CoinShape.radius
            let direction = -tangentOmega / speed
            let unitResponse = simd_length(body.inverseInertiaApplied(to: direction))
            let stoppingImpulse = unitResponse > 1e-15 ? speed / unitResponse : 0
            body.applyAngularImpulse(direction * min(maximumTorqueImpulse, stoppingImpulse))
        }

        for contact in contacts where (cache[contact.id]?.normal ?? 0) > 0 {
            if contact.surfaceID == Self.floorID { metrics.floorContact = true }
            if contact.surfaceID == Self.lipID { metrics.lipContact = true }
        }
    }

    private func effectiveMass(body: RigidCoin, lever: Vector3, direction: Vector3) -> Double {
        let angular = simd_cross(lever, direction)
        let angularResponse = body.inverseInertiaApplied(to: angular)
        let denominator = body.inverseMass + simd_dot(simd_cross(angularResponse, lever), direction)
        return denominator > 1e-15 ? 1 / denominator : 0
    }
}

public struct StateHasher: Sendable {
    private(set) public var value: UInt64 = 1_469_598_103_934_665_603

    public init() {}

    public mutating func add(_ value: Double) {
        var bits = value.bitPattern.littleEndian
        withUnsafeBytes(of: &bits) { bytes in
            for byte in bytes {
                self.value ^= UInt64(byte)
                self.value &*= 1_099_511_628_211
            }
        }
    }

    public mutating func add(_ value: Bool) {
        self.value ^= value ? 1 : 0
        self.value &*= 1_099_511_628_211
    }

    public mutating func add(body: RigidCoin) {
        add(body.position.x); add(body.position.y); add(body.position.z)
        add(body.orientation.vector.x); add(body.orientation.vector.y)
        add(body.orientation.vector.z); add(body.orientation.vector.w)
        add(body.linearVelocity.x); add(body.linearVelocity.y); add(body.linearVelocity.z)
        add(body.angularVelocity.x); add(body.angularVelocity.y); add(body.angularVelocity.z)
        add(body.asleep)
    }
}

public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    public mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    public mutating func value(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }
}

public func mechanicalEnergy(body: RigidCoin) -> Double {
    let mass = CoinShape.mass
    let translational = 0.5 * mass * simd_length_squared(body.linearVelocity)
    let localOmega = body.orientation.inverse.act(body.angularVelocity)
    let inertia = body.shape.inertia
    let rotational = 0.5 * (inertia.x * localOmega.x * localOmega.x
        + inertia.y * localOmega.y * localOmega.y
        + inertia.z * localOmega.z * localOmega.z)
    return mass * 9.81 * body.position.y + translational + rotational
}
