import Foundation

struct CoinGeometry: Sendable {
    let radius = 0.011
    let halfThickness = 0.0011
    let mass = 0.0045

    var inverseMass: Double { 1 / mass }
    var inverseRadialInertia: Double {
        let fullThickness = halfThickness * 2
        let inertia = mass * (3 * radius * radius + fullThickness * fullThickness) / 12
        return 1 / inertia
    }
    var inverseAxialInertia: Double {
        1 / (0.5 * mass * radius * radius)
    }

    func localSupportPoints() -> [Vector3] {
        let segmentCount = 64
        var points = [
            Vector3(x: 0, y: 0, z: -halfThickness),
            Vector3(x: 0, y: 0, z: halfThickness),
        ]
        points.reserveCapacity(segmentCount * 2 + 2)
        for index in 0..<segmentCount {
            let angle = Double(index) / Double(segmentCount) * 2 * Double.pi
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            points.append(Vector3(x: x, y: y, z: -halfThickness))
            points.append(Vector3(x: x, y: y, z: halfThickness))
        }
        return points
    }
}

struct BowlSurface: Sendable {
    let floorDepth = 0.004
    let innerRadius = 0.034
    let outerRadius = 0.050

    func sample(at point: Vector3) -> (height: Double, normal: Vector3) {
        let radial = hypot(point.x, point.y)
        guard radial > innerRadius else {
            return (-floorDepth, .up)
        }
        guard radial < outerRadius else {
            return (0, .up)
        }

        let span = outerRadius - innerRadius
        let parameter = (radial - innerRadius) / span
        let smooth = parameter * parameter * (3 - 2 * parameter)
        let height = -floorDepth + floorDepth * smooth
        let derivative = floorDepth * 6 * parameter * (1 - parameter) / span
        let radialDirection = Vector3(x: point.x / radial, y: point.y / radial, z: 0)
        let normal = Vector3(
            x: -derivative * radialDirection.x,
            y: -derivative * radialDirection.y,
            z: 1
        ).normalized(or: .up)
        return (height, normal)
    }
}

struct CoinBody: Equatable, Sendable {
    var position: Vector3
    var linearVelocity: Vector3
    var orientation: Quaternion
    var angularVelocity: Vector3
    var sleeping = false
    var quietDuration = 0.0
}

struct Contact: Sendable {
    let localPoint: Vector3
    let worldPoint: Vector3
    let normal: Vector3
    let penetration: Double
    let gap: Double
}

struct TrajectorySample: Equatable, Sendable {
    let step: Int
    let position: Vector3
    let orientation: Quaternion
}

struct ExperimentOutcome: Sendable {
    let firstImpactTime: Double?
    let settleTime: Double?
    let apex: Double
    let minimumEdgeRatio: Double
    let contactBeginnings: Int
    let maximumPenetration: Double
    let maximumUnresolvedCrossing: Double
    let finalSupportGap: Double
    let hasSupport: Bool
    let finalBody: CoinBody
    let trajectory: [TrajectorySample]
    let physicsSteps: Int
}

struct CoinExperiment: Sendable {
    static let fixedStep = 1.0 / 120.0
    private static let solverSubsteps = 4
    private static let gravity = Vector3(x: 0, y: 0, z: -9.81)
    private static let restitution = 0.22
    private static let slidingFriction = 0.26
    private static let rollingDamping = 4.8
    private static let linearAirDamping = 0.035
    private static let angularAirDamping = 0.045

    let geometry = CoinGeometry()
    let surface = BowlSurface()
    private let supportPoints: [Vector3]

    init() {
        supportPoints = geometry.localSupportPoints()
    }

    func run(maximumPhysicsSteps: Int = 600) -> ExperimentOutcome {
        var body = CoinBody(
            position: Vector3(x: -0.140, y: 0, z: 0.020),
            linearVelocity: Vector3(x: 0.680, y: 0, z: 0.900),
            orientation: Quaternion(axis: Vector3(x: 0, y: 1, z: 0), angle: 8 * .pi / 180),
            angularVelocity: Vector3(x: 0, y: 16, z: 3)
        )
        var apex = body.position.z
        var minimumEdgeRatio = projectedEdgeRatio(body.orientation)
        var firstImpactTime: Double?
        var settleTime: Double?
        var contactBeginnings = 0
        var wasContacting = false
        var maximumPenetration = 0.0
        var maximumUnresolvedCrossing = 0.0
        var trajectory: [TrajectorySample] = []
        trajectory.reserveCapacity(maximumPhysicsSteps + 1)
        trajectory.append(sample(body, step: 0))
        var completedSteps = 0

        for step in 1...maximumPhysicsSteps {
            let substepDuration = Self.fixedStep / Double(Self.solverSubsteps)
            var contactedThisStep = false
            for _ in 0..<Self.solverSubsteps {
                let result = advance(body: &body, duration: substepDuration)
                contactedThisStep = contactedThisStep || result.contacted
                maximumPenetration = max(maximumPenetration, result.correctedPenetration)
                maximumUnresolvedCrossing = max(
                    maximumUnresolvedCrossing,
                    result.unresolvedCrossing
                )
            }

            let time = Double(step) * Self.fixedStep
            if contactedThisStep && !wasContacting {
                contactBeginnings += 1
                if firstImpactTime == nil { firstImpactTime = time }
            }
            wasContacting = contactedThisStep

            let support = nearestSupport(body)
            let isQuiet = support.hasSupport
                && body.linearVelocity.length < 0.015
                && body.angularVelocity.length < 0.8
            body.quietDuration = isQuiet ? body.quietDuration + Self.fixedStep : 0
            if body.quietDuration >= 0.20 {
                body.sleeping = true
                body.linearVelocity = .zero
                body.angularVelocity = .zero
                settleTime = time
            }

            apex = max(apex, body.position.z)
            minimumEdgeRatio = min(minimumEdgeRatio, projectedEdgeRatio(body.orientation))
            trajectory.append(sample(body, step: step))
            completedSteps = step
            if body.sleeping { break }
        }

        let finalSupport = nearestSupport(body)
        return ExperimentOutcome(
            firstImpactTime: firstImpactTime,
            settleTime: settleTime,
            apex: apex,
            minimumEdgeRatio: minimumEdgeRatio,
            contactBeginnings: contactBeginnings,
            maximumPenetration: maximumPenetration,
            maximumUnresolvedCrossing: maximumUnresolvedCrossing,
            finalSupportGap: finalSupport.gap,
            hasSupport: finalSupport.hasSupport,
            finalBody: body,
            trajectory: trajectory,
            physicsSteps: completedSteps
        )
    }

    private func advance(body: inout CoinBody, duration: Double) -> (
        contacted: Bool,
        correctedPenetration: Double,
        unresolvedCrossing: Double
    ) {
        guard !body.sleeping else { return (true, 0, 0) }
        let previous = body
        let candidate = predictedState(from: previous, duration: duration)
        let previousDepth = deepestContact(previous)?.penetration ?? 0
        let candidateDepth = deepestContact(candidate)?.penetration ?? 0
        var unresolvedCrossing = 0.0

        if previousDepth <= 0, candidateDepth > 0 {
            var lower = 0.0
            var upper = 1.0
            for _ in 0..<18 {
                let middle = (lower + upper) * 0.5
                let probe = predictedState(from: previous, duration: duration * middle)
                if deepestContact(probe) == nil {
                    lower = middle
                } else {
                    upper = middle
                }
            }
            body = predictedState(from: previous, duration: duration * upper)
            let remaining = duration * (1 - upper)
            let impactResult = solveContacts(body: &body, duration: duration * upper)
            if remaining > 1e-9 {
                body = predictedState(from: body, duration: remaining)
                let finalResult = solveContacts(body: &body, duration: remaining)
                unresolvedCrossing = max(
                    impactResult.unresolvedCrossing,
                    finalResult.unresolvedCrossing
                )
                return (
                    impactResult.contacted || finalResult.contacted,
                    max(impactResult.correctedPenetration, finalResult.correctedPenetration),
                    unresolvedCrossing
                )
            }
            return (
                impactResult.contacted,
                impactResult.correctedPenetration,
                impactResult.unresolvedCrossing
            )
        }

        body = candidate
        return solveContacts(body: &body, duration: duration)
    }

    private func predictedState(from body: CoinBody, duration: Double) -> CoinBody {
        var result = body
        let linearDecay = exp(-Self.linearAirDamping * duration)
        let angularDecay = exp(-Self.angularAirDamping * duration)
        result.position += body.linearVelocity * duration
            + Self.gravity * (0.5 * duration * duration)
        result.linearVelocity = (body.linearVelocity + Self.gravity * duration) * linearDecay
        result.orientation = body.orientation.integrated(
            worldAngularVelocity: body.angularVelocity,
            duration: duration
        )
        result.angularVelocity = body.angularVelocity * angularDecay
        return result
    }

    private func solveContacts(body: inout CoinBody, duration: Double) -> (
        contacted: Bool,
        correctedPenetration: Double,
        unresolvedCrossing: Double
    ) {
        var contacted = false
        var correctedPenetration = 0.0

        for _ in 0..<8 {
            let contacts = contacts(for: body)
                .sorted { $0.penetration > $1.penetration }
                .prefix(6)
            guard !contacts.isEmpty else { break }
            contacted = true

            for contact in contacts {
                let currentWorldPoint = body.position + body.orientation.rotate(contact.localPoint)
                let surfaceSample = surface.sample(at: currentWorldPoint)
                let penetration = max(0, surfaceSample.height - currentWorldPoint.z)
                correctedPenetration = max(correctedPenetration, penetration)
                if penetration > 0 {
                    body.position += surfaceSample.normal * min(penetration * 0.84, 0.00012)
                }

                let lever = currentWorldPoint - body.position
                let pointVelocity = body.linearVelocity + body.angularVelocity.cross(lever)
                let normalSpeed = pointVelocity.dot(surfaceSample.normal)
                guard normalSpeed < 0 else { continue }

                let leverCrossNormal = lever.cross(surfaceSample.normal)
                let angularNormal = inverseInertiaApplied(
                    leverCrossNormal,
                    orientation: body.orientation
                ).cross(lever)
                let denominator = geometry.inverseMass + surfaceSample.normal.dot(angularNormal)
                guard denominator > 1e-12 else { continue }

                let bounce = normalSpeed < -0.12 ? Self.restitution : 0
                let normalImpulseMagnitude = -(1 + bounce) * normalSpeed / denominator
                applyImpulse(
                    surfaceSample.normal * normalImpulseMagnitude,
                    at: lever,
                    body: &body
                )

                let postNormalVelocity = body.linearVelocity + body.angularVelocity.cross(lever)
                let tangentVelocity = postNormalVelocity
                    - surfaceSample.normal * postNormalVelocity.dot(surfaceSample.normal)
                let tangentSpeed = tangentVelocity.length
                if tangentSpeed > 1e-9 {
                    let tangent = tangentVelocity / tangentSpeed
                    let leverCrossTangent = lever.cross(tangent)
                    let angularTangent = inverseInertiaApplied(
                        leverCrossTangent,
                        orientation: body.orientation
                    ).cross(lever)
                    let tangentDenominator = geometry.inverseMass + tangent.dot(angularTangent)
                    let unconstrained = tangentSpeed / max(tangentDenominator, 1e-12)
                    let frictionMagnitude = min(
                        unconstrained,
                        Self.slidingFriction * normalImpulseMagnitude
                    )
                    applyImpulse(-tangent * frictionMagnitude, at: lever, body: &body)
                }
            }
        }

        if contacted {
            body.angularVelocity *= exp(-Self.rollingDamping * duration)
        }
        let unresolved = max(0, deepestContact(body)?.penetration ?? 0)
        return (contacted, correctedPenetration, unresolved)
    }

    private func applyImpulse(_ impulse: Vector3, at lever: Vector3, body: inout CoinBody) {
        body.linearVelocity += impulse * geometry.inverseMass
        body.angularVelocity += inverseInertiaApplied(
            lever.cross(impulse),
            orientation: body.orientation
        )
    }

    private func inverseInertiaApplied(
        _ worldVector: Vector3,
        orientation: Quaternion
    ) -> Vector3 {
        let bodyVector = orientation.conjugate.rotate(worldVector)
        let bodyResult = Vector3(
            x: bodyVector.x * geometry.inverseRadialInertia,
            y: bodyVector.y * geometry.inverseRadialInertia,
            z: bodyVector.z * geometry.inverseAxialInertia
        )
        return orientation.rotate(bodyResult)
    }

    private func contacts(for body: CoinBody) -> [Contact] {
        supportPoints.compactMap { localPoint in
            let worldPoint = body.position + body.orientation.rotate(localPoint)
            let surfaceSample = surface.sample(at: worldPoint)
            let gap = worldPoint.z - surfaceSample.height
            guard gap <= 0.00002 else { return nil }
            return Contact(
                localPoint: localPoint,
                worldPoint: worldPoint,
                normal: surfaceSample.normal,
                penetration: max(0, -gap),
                gap: gap
            )
        }
    }

    private func deepestContact(_ body: CoinBody) -> Contact? {
        contacts(for: body).max { $0.penetration < $1.penetration }
    }

    private func nearestSupport(_ body: CoinBody) -> (hasSupport: Bool, gap: Double) {
        let minimumGap = supportPoints.map { localPoint -> Double in
            let worldPoint = body.position + body.orientation.rotate(localPoint)
            return worldPoint.z - surface.sample(at: worldPoint).height
        }.min() ?? .infinity
        let hasSupport = minimumGap >= -0.00015 && minimumGap <= 0.00020
            && body.position.z < 0.020
        return (hasSupport, abs(minimumGap))
    }

    private func projectedEdgeRatio(_ orientation: Quaternion) -> Double {
        let coinNormal = orientation.rotate(.up).normalized(or: .up)
        let cameraDirection = Vector3(x: 0.08, y: -0.70, z: 0.71).normalized(or: .up)
        return abs(coinNormal.dot(cameraDirection))
    }

    private func sample(_ body: CoinBody, step: Int) -> TrajectorySample {
        TrajectorySample(step: step, position: body.position, orientation: body.orientation)
    }
}

private extension Vector3 {
    static func += (left: inout Vector3, right: Vector3) {
        left = left + right
    }

    static func *= (left: inout Vector3, right: Double) {
        left = left * right
    }
}
