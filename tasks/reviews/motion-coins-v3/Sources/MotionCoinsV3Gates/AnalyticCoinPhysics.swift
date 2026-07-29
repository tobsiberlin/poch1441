import Foundation

struct CoinGeometry: Sendable {
    let radius = 0.011
    let halfThickness = 0.0011
    let mass = 0.0045

    var inverseMass: Double { 1 / mass }
    var radialInertia: Double {
        let thickness = halfThickness * 2
        return mass * (3 * radius * radius + thickness * thickness) / 12
    }
    var axialInertia: Double { 0.5 * mass * radius * radius }

    func inverseInertia(_ vector: Vector3, orientation: Quaternion) -> Vector3 {
        let axis = orientation.rotate(.up).normalized(or: .up)
        let axialPart = axis * vector.dot(axis)
        let radialPart = vector - axialPart
        return radialPart / radialInertia + axialPart / axialInertia
    }
}

struct CoinBody: Equatable, Sendable {
    var position: Vector3
    var linearVelocity: Vector3
    var orientation: Quaternion
    var angularVelocity: Vector3
}

struct Plane: Sendable {
    let name: String
    let normal: Vector3
    let offset: Double
    let restitution: Double
    let restitutionCutoff: Double
    let friction: Double

    init(
        name: String,
        normal: Vector3,
        offset: Double = 0,
        restitution: Double,
        restitutionCutoff: Double,
        friction: Double
    ) {
        self.name = name
        self.normal = normal.normalized(or: .up)
        self.offset = offset
        self.restitution = restitution
        self.restitutionCutoff = restitutionCutoff
        self.friction = friction
    }
}

struct ContactGeometry: Sendable {
    let separation: Double
    let centerOffset: Vector3
}

struct ArchitectureDeclaration: Sendable {
    let fixedSubstepCount: Int? = nil
    let sleepEnabled = false
    let velocityZeroingEnabled = false
    let globalContactDamping = 0.0
    let collisionMethod = "analytic cylinder support + event-time bisection"
}

struct StepEvidence: Sendable {
    var rawPenetration = 0.0
    var residualPenetration = 0.0
    var impactCount = 0
    var eventSplits = 0
    var dissipatedEnergy = 0.0
}

struct SimulationOutcome: Sendable {
    let finalBody: CoinBody
    let firstImpactTime: Double?
    let maximumRawPenetration: Double
    let maximumResidualPenetration: Double
    let maximumEnergy: Double
    let initialEnergy: Double
    let energyScale: Double
    let impactCount: Int
    let eventSplits: Int
    let sustainedRestDuration: Double
    let allFinite: Bool
}

struct AnalyticCoinSolver: Sendable {
    static let gravity = Vector3(x: 0, y: 0, z: -9.81)
    static let contactTolerance = 2e-9

    let geometry = CoinGeometry()
    let architecture = ArchitectureDeclaration()

    func contactGeometry(body: CoinBody, plane: Plane) -> ContactGeometry {
        let axis = body.orientation.rotate(.up).normalized(or: .up)
        let axialProjection = plane.normal.dot(axis)
        let radialNormal = plane.normal - axis * axialProjection
        let radialLength = sqrt(max(0, 1 - axialProjection * axialProjection))
        let supportRadius = geometry.halfThickness * abs(axialProjection)
            + geometry.radius * radialLength

        let axialOffset: Vector3
        if abs(axialProjection) < 1e-12 {
            axialOffset = .zero
        } else {
            axialOffset = axis * (-geometry.halfThickness * (axialProjection > 0 ? 1 : -1))
        }
        let radialOffset = radialLength > 1e-12
            ? radialNormal * (-geometry.radius / radialLength)
            : .zero
        return ContactGeometry(
            separation: plane.normal.dot(body.position) - plane.offset - supportRadius,
            centerOffset: axialOffset + radialOffset
        )
    }

    func propagated(_ body: CoinBody, duration: Double, acceleration: Vector3 = gravity) -> CoinBody {
        let initialAxis = body.orientation.rotate(.up).normalized(or: .up)
        let momentum = angularMomentum(body)
        let precessionRate = momentum.length / geometry.radialInertia
        let spinCorrectionRate = (1 / geometry.axialInertia - 1 / geometry.radialInertia)
            * momentum.dot(initialAxis)
        let precession = Quaternion(axis: momentum, angle: precessionRate * duration)
        let spinCorrection = Quaternion(axis: .up, angle: spinCorrectionRate * duration)
        let orientation = (precession * body.orientation * spinCorrection).normalized
        let finalAxis = orientation.rotate(.up).normalized(or: .up)
        let angularVelocity = momentum / geometry.radialInertia
            + finalAxis * (
                (1 / geometry.axialInertia - 1 / geometry.radialInertia)
                    * momentum.dot(finalAxis)
            )
        return CoinBody(
            position: body.position + body.linearVelocity * duration
                + acceleration * (0.5 * duration * duration),
            linearVelocity: body.linearVelocity + acceleration * duration,
            orientation: orientation,
            angularVelocity: angularVelocity
        )
    }

    func mechanicalEnergy(_ body: CoinBody) -> Double {
        let translational = 0.5 * geometry.mass * body.linearVelocity.lengthSquared
        let axis = body.orientation.rotate(.up).normalized(or: .up)
        let axialSpeed = body.angularVelocity.dot(axis)
        let radialSpeed = body.angularVelocity - axis * axialSpeed
        let rotational = 0.5 * geometry.axialInertia * axialSpeed * axialSpeed
            + 0.5 * geometry.radialInertia * radialSpeed.lengthSquared
        let potential = -geometry.mass * Self.gravity.dot(body.position)
        return translational + rotational + potential
    }

    func angularMomentum(_ body: CoinBody) -> Vector3 {
        let axis = body.orientation.rotate(.up).normalized(or: .up)
        let axialSpeed = body.angularVelocity.dot(axis)
        let radialSpeed = body.angularVelocity - axis * axialSpeed
        return radialSpeed * geometry.radialInertia + axis * (axialSpeed * geometry.axialInertia)
    }

    func run(
        initialBody: CoinBody,
        plane: Plane,
        duration: Double,
        hertz: Int,
        auditRest: Bool = false
    ) -> SimulationOutcome {
        let stepDuration = 1 / Double(hertz)
        let steps = Int(ceil(duration / stepDuration))
        var body = initialBody
        var firstImpactTime: Double?
        var maximumRawPenetration = 0.0
        var maximumResidualPenetration = 0.0
        let initialEnergy = mechanicalEnergy(body)
        let energyScale = max(
            abs(initialEnergy),
            0.5 * geometry.mass * body.linearVelocity.lengthSquared
                + geometry.mass * 9.81 * max(abs(body.position.z), 0.05),
            1e-9
        )
        var maximumEnergy = initialEnergy
        var impactCount = 0
        var eventSplits = 0
        var elapsed = 0.0
        var sustainedRestDuration = 0.0

        for _ in 0..<steps {
            let dt = min(stepDuration, duration - elapsed)
            guard dt > 0 else { break }
            var evidence = StepEvidence()
            advance(body: &body, plane: plane, duration: dt, evidence: &evidence)
            elapsed += dt
            if firstImpactTime == nil, evidence.impactCount > 0 {
                firstImpactTime = firstImpactOffset(
                    from: initialBody,
                    plane: plane,
                    notAfter: elapsed
                )
            }
            maximumRawPenetration = max(maximumRawPenetration, evidence.rawPenetration)
            maximumResidualPenetration = max(maximumResidualPenetration, evidence.residualPenetration)
            maximumEnergy = max(maximumEnergy, mechanicalEnergy(body))
            impactCount += evidence.impactCount
            eventSplits += evidence.eventSplits

            if auditRest {
                let geometryAtRest = contactGeometry(body: body, plane: plane)
                let quiet = geometryAtRest.separation <= 2e-7
                    && body.linearVelocity.length < 0.015
                    && body.angularVelocity.length < 0.8
                sustainedRestDuration = quiet ? sustainedRestDuration + dt : 0
            }
        }

        return SimulationOutcome(
            finalBody: body,
            firstImpactTime: firstImpactTime,
            maximumRawPenetration: maximumRawPenetration,
            maximumResidualPenetration: maximumResidualPenetration,
            maximumEnergy: maximumEnergy,
            initialEnergy: initialEnergy,
            energyScale: energyScale,
            impactCount: impactCount,
            eventSplits: eventSplits,
            sustainedRestDuration: sustainedRestDuration,
            allFinite: isFinite(body)
        )
    }

    private func advance(
        body: inout CoinBody,
        plane: Plane,
        duration: Double,
        evidence: inout StepEvidence
    ) {
        var remaining = duration
        var elapsedInStep = 0.0
        var eventBudget = 4

        while remaining > 1e-12 {
            let contact = contactGeometry(body: body, plane: plane)
            let contactVelocity = body.linearVelocity
                + body.angularVelocity.cross(contact.centerOffset)
            let normalVelocity = contactVelocity.dot(plane.normal)

            if isStableFaceSupport(body: body, plane: plane, contact: contact, normalVelocity: normalVelocity) {
                let normalGravity = Self.gravity.dot(plane.normal)
                let constrainedAcceleration = Self.gravity
                    - plane.normal * min(0, normalGravity)
                body = propagated(body, duration: remaining, acceleration: constrainedAcceleration)
                let raw = max(0, -contactGeometry(body: body, plane: plane).separation)
                evidence.rawPenetration = max(evidence.rawPenetration, raw)
                if raw > 0 { correct(body: &body, plane: plane, penetration: raw) }
                evidence.residualPenetration = max(
                    evidence.residualPenetration,
                    max(0, -contactGeometry(body: body, plane: plane).separation)
                )
                return
            }

            if contact.separation <= Self.contactTolerance, normalVelocity < -1e-8, eventBudget > 0 {
                let before = mechanicalEnergy(body)
                applyImpact(body: &body, plane: plane, contact: contact)
                evidence.dissipatedEnergy += max(0, before - mechanicalEnergy(body))
                evidence.impactCount += 1
                eventBudget -= 1
                continue
            }

            let candidate = propagated(body, duration: remaining)
            let candidateSeparation = contactGeometry(body: candidate, plane: plane).separation

            if contact.separation > Self.contactTolerance,
               candidateSeparation < 0,
               eventBudget > 0 {
                let impactDuration = impactTime(
                    from: body,
                    plane: plane,
                    duration: remaining
                )
                body = propagated(body, duration: impactDuration)
                var impactContact = contactGeometry(body: body, plane: plane)
                let raw = max(0, -impactContact.separation)
                evidence.rawPenetration = max(evidence.rawPenetration, raw)
                if raw > 0 {
                    correct(body: &body, plane: plane, penetration: raw)
                    impactContact = contactGeometry(body: body, plane: plane)
                }
                let before = mechanicalEnergy(body)
                applyImpact(body: &body, plane: plane, contact: impactContact)
                evidence.dissipatedEnergy += max(0, before - mechanicalEnergy(body))
                evidence.impactCount += 1
                evidence.eventSplits += 1
                eventBudget -= 1
                elapsedInStep += impactDuration
                remaining -= impactDuration
                continue
            }

            body = candidate
            let raw = max(0, -candidateSeparation)
            evidence.rawPenetration = max(evidence.rawPenetration, raw)
            if raw > 0 { correct(body: &body, plane: plane, penetration: raw) }
            evidence.residualPenetration = max(
                evidence.residualPenetration,
                max(0, -contactGeometry(body: body, plane: plane).separation)
            )
            elapsedInStep += remaining
            remaining = 0
        }

        _ = elapsedInStep
    }

    private func isStableFaceSupport(
        body: CoinBody,
        plane: Plane,
        contact: ContactGeometry,
        normalVelocity: Double
    ) -> Bool {
        let axis = body.orientation.rotate(.up).normalized(or: .up)
        return contact.separation <= 2e-7
            && abs(axis.dot(plane.normal)) > 1 - 1e-10
            && abs(normalVelocity) < 1e-7
            && body.angularVelocity.length < 1e-7
    }

    private func impactTime(from body: CoinBody, plane: Plane, duration: Double) -> Double {
        var lower = 0.0
        var upper = duration
        for _ in 0..<52 {
            let middle = (lower + upper) * 0.5
            let probe = propagated(body, duration: middle)
            if contactGeometry(body: probe, plane: plane).separation > 0 {
                lower = middle
            } else {
                upper = middle
            }
        }
        return upper
    }

    private func firstImpactOffset(from initial: CoinBody, plane: Plane, notAfter time: Double) -> Double {
        guard contactGeometry(body: initial, plane: plane).separation > 0 else { return 0 }
        return impactTime(from: initial, plane: plane, duration: time)
    }

    private func applyImpact(body: inout CoinBody, plane: Plane, contact: ContactGeometry) {
        let pointVelocity = body.linearVelocity
            + body.angularVelocity.cross(contact.centerOffset)
        let normalVelocity = pointVelocity.dot(plane.normal)
        guard normalVelocity < 0 else { return }

        let restitution = abs(normalVelocity) >= plane.restitutionCutoff
            ? plane.restitution
            : 0
        let normalDenominator = impulseDenominator(
            direction: plane.normal,
            offset: contact.centerOffset,
            body: body
        )
        let normalImpulseMagnitude = -(1 + restitution) * normalVelocity / normalDenominator
        apply(
            impulse: plane.normal * normalImpulseMagnitude,
            offset: contact.centerOffset,
            body: &body
        )

        let velocityAfterNormal = body.linearVelocity
            + body.angularVelocity.cross(contact.centerOffset)
        let tangentVelocity = velocityAfterNormal
            - plane.normal * velocityAfterNormal.dot(plane.normal)
        let tangentSpeed = tangentVelocity.length
        guard tangentSpeed > 1e-12 else { return }
        let tangent = tangentVelocity / tangentSpeed
        let tangentDenominator = impulseDenominator(
            direction: tangent,
            offset: contact.centerOffset,
            body: body
        )
        let unconstrainedMagnitude = tangentSpeed / tangentDenominator
        let frictionMagnitude = min(unconstrainedMagnitude, plane.friction * normalImpulseMagnitude)
        apply(impulse: tangent * -frictionMagnitude, offset: contact.centerOffset, body: &body)
    }

    private func impulseDenominator(
        direction: Vector3,
        offset: Vector3,
        body: CoinBody
    ) -> Double {
        let angular = geometry.inverseInertia(
            offset.cross(direction),
            orientation: body.orientation
        ).cross(offset)
        return geometry.inverseMass + direction.dot(angular)
    }

    private func apply(impulse: Vector3, offset: Vector3, body: inout CoinBody) {
        body.linearVelocity = body.linearVelocity + impulse * geometry.inverseMass
        body.angularVelocity = body.angularVelocity + geometry.inverseInertia(
            offset.cross(impulse),
            orientation: body.orientation
        )
    }

    private func correct(body: inout CoinBody, plane: Plane, penetration: Double) {
        body.position = body.position + plane.normal * penetration
    }

    private func isFinite(_ body: CoinBody) -> Bool {
        [
            body.position.x, body.position.y, body.position.z,
            body.linearVelocity.x, body.linearVelocity.y, body.linearVelocity.z,
            body.orientation.real,
            body.orientation.imaginary.x, body.orientation.imaginary.y,
            body.orientation.imaginary.z,
            body.angularVelocity.x, body.angularVelocity.y, body.angularVelocity.z,
        ].allSatisfy(\.isFinite)
    }
}
