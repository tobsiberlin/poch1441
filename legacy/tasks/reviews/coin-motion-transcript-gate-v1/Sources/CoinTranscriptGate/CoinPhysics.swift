import Foundation

struct TrackBOuterWell: Encodable, Sendable {
    let name = "queen outer well"
    let sourceCenterPixels = Vector3(x: 648, y: 704, z: 0)
    let floorWidth = 0.049
    let floorHeight = 0.039
    let frontLipDepth = 0.0067
    let screenWellWidthPixels = 51.0

    var halfPhysicalPixelMeters: Double {
        0.5 * floorWidth / screenWellWidthPixels
    }
}

struct CoinGeometry: Encodable, Sendable {
    let radius = 0.0095
    let halfThickness = 0.0008
    let mass = 0.00311

    var radialInertia: Double {
        mass * (3 * radius * radius + 4 * halfThickness * halfThickness) / 12
    }

    var axialInertia: Double { 0.5 * mass * radius * radius }
    var inverseMass: Double { 1 / mass }

    func inverseInertia(_ vector: Vector3, orientation: Quaternion) -> Vector3 {
        let axis = orientation.rotate(.up).normalized()
        let axial = axis * vector.dot(axis)
        let radial = vector - axial
        return radial / radialInertia + axial / axialInertia
    }
}

struct CoinState: Codable, Equatable, Sendable {
    var position: Vector3
    var orientation: Quaternion
    var linearVelocity: Vector3
    var angularVelocity: Vector3
}

enum ContactMarker: String, Codable, Sendable {
    case impactBegin
    case contactImpulse
    case supportBegin
    case restWindowBegin
    case restCertified
}

struct TranscriptSample: Encodable, Sendable {
    let time: Double
    let position: Vector3
    let orientation: Quaternion
    let linearVelocity: Vector3
    let angularVelocity: Vector3
    let contacts: [ContactMarker]
}

struct SeedMetrics: Encodable, Sendable {
    let seed: UInt64
    let contactCount: Int
    let maximumContactEnergyGainRatio: Double
    let maximumPenetrationMeters: Double
    let maximumPenetrationPhysicalPixels: Double
    let restingWindowSeconds: Double
    let finalLinearSpeedMetersPerSecond: Double
    let finalAngularSpeedRadiansPerSecond: Double
    let minimumContainmentMarginMeters: Double
    let hardVelocityZeroingUsed: Bool
    let passed: Bool
}

struct SeedTranscript: Encodable, Sendable {
    let seed: UInt64
    let well: TrackBOuterWell
    let coin: CoinGeometry
    let metrics: SeedMetrics
    let samples: [TranscriptSample]
}

struct TranscriptBundle: Encodable, Sendable {
    let schema = "poch.coin-6dof-transcript.v1"
    let generatedAt: String
    let sampleRateHertz: Int
    let gates: GateThresholds
    let commitPolicy: MotionCommitPolicy
    let selection: SelectionEvidence
    let transcripts: [SeedTranscript]
}

struct GateThresholds: Encodable, Sendable {
    let maximumContactEnergyGainRatio = 0.0025
    let maximumPenetrationPhysicalPixels = 0.5
    let maximumRestLinearSpeedMetersPerSecond = 0.001
    let maximumRestAngularSpeedRadiansPerSecond = 0.002
    let minimumRestWindowSeconds = 0.120
}

enum MotionPhase: String, Encodable, Sendable {
    case prepared
    case freeFlight
    case postContact
}

enum CancelDisposition: String, Encodable, Sendable {
    case returnToVisibleSourcePose
    case committedTimeScaleOnly
    case finishTranscriptThenVisibleCountermove
}

struct MotionCommitPolicy: Encodable, Sendable {
    let commitPoint = "release"
    let preRelease = CancelDisposition.returnToVisibleSourcePose
    let freeFlight = CancelDisposition.committedTimeScaleOnly
    let postContact = CancelDisposition.finishTranscriptThenVisibleCountermove

    func disposition(for phase: MotionPhase) -> CancelDisposition {
        switch phase {
        case .prepared: preRelease
        case .freeFlight: freeFlight
        case .postContact: postContact
        }
    }
}

struct RuntimeBucket: Encodable, Sendable {
    let id = "402x874|queen|single-cent|standard|aged-copper-smoke-polycarbonate"
    let viewport = "402x874"
    let targetWell = "queen"
    let payload = "single-cent"
    let intensity = "standard"
    let materialSignature = "aged copper on aged smoke-clear polycarbonate"
}

struct SelectionEvidence: Encodable, Sendable {
    let bucket: RuntimeBucket
    let availableTranscriptCount: Int
    let protectedHistoryLength: Int
    let auditDraws: [UInt64]
    let repeatWithinProtectedHistory: Bool
}

private enum MotionMode: Sendable {
    case flight
    case support
}

private struct ContactGeometry: Sendable {
    let separation: Double
    let centerOffset: Vector3
}

struct CoinTranscriptSimulator: Sendable {
    static let sampleRateHertz = 240
    static let duration = 3.2
    private static let gravity = Vector3(x: 0, y: 0, z: -9.81)
    private static let timeOfImpactTolerance = 1e-10
    private static let restitution = 0.075
    private static let friction = 0.24
    private static let captureNormalSpeed = 0.018
    private static let translationResistance = 15.0
    private static let tiltResistance = 10.0
    private static let spinResistance = 5.7

    let well = TrackBOuterWell()
    let coin = CoinGeometry()
    let gates = GateThresholds()

    func run(seed: UInt64) -> SeedTranscript {
        var random = SeededRandom(seed: seed)
        let initialTiltAxis = Vector3(
            x: random.unit(in: -1...1),
            y: random.unit(in: -1...1),
            z: 0
        ).normalized(or: Vector3(x: 1, y: 0, z: 0))
        let initialTilt = random.unit(in: -1.2...1.2) * .pi / 180
        let initialYaw = random.unit(in: -.pi ... .pi)
        var state = CoinState(
            position: Vector3(
                x: random.unit(in: -0.0032...0.0032),
                y: random.unit(in: -0.0022...0.0022),
                z: random.unit(in: 0.047...0.054)
            ),
            orientation: Quaternion(axis: .up, angle: initialYaw)
                * Quaternion(axis: initialTiltAxis, angle: initialTilt),
            linearVelocity: Vector3(
                x: random.unit(in: -0.022...0.022),
                y: random.unit(in: -0.016...0.016),
                z: random.unit(in: -0.27 ... -0.20)
            ),
            angularVelocity: Vector3(
                x: random.unit(in: -0.40...0.40),
                y: random.unit(in: -0.40...0.40),
                z: random.unit(in: 5.4...8.2)
            )
        )

        let dt = 1 / Double(Self.sampleRateHertz)
        let stepCount = Int(Self.duration / dt)
        var mode = MotionMode.flight
        var samples: [TranscriptSample] = []
        samples.reserveCapacity(stepCount + 1)
        var contactCount = 0
        var maximumEnergyGain = 0.0
        var maximumPenetration = 0.0
        var minimumContainmentMargin = containmentMargin(state.position)
        var restWindow = 0.0
        var restWindowStarted = false
        var restCertified = false

        samples.append(sample(time: 0, state: state, contacts: []))
        for step in 1...stepCount {
            var markers: [ContactMarker] = []
            switch mode {
            case .flight:
                let result = advanceFlight(state: state, duration: dt)
                state = result.state
                maximumPenetration = max(maximumPenetration, result.maximumPenetration)
                if result.impacted {
                    markers.append(contentsOf: [.impactBegin, .contactImpulse])
                    contactCount += 1
                    maximumEnergyGain = max(maximumEnergyGain, result.energyGainRatio)
                }
                if result.captured {
                    mode = .support
                    markers.append(.supportBegin)
                }
            case .support:
                state = advanceSupport(state: state, duration: dt)
            }

            minimumContainmentMargin = min(minimumContainmentMargin,
                                           containmentMargin(state.position))
            let quiet = mode == .support
                && state.linearVelocity.length < gates.maximumRestLinearSpeedMetersPerSecond
                && state.angularVelocity.length < gates.maximumRestAngularSpeedRadiansPerSecond
            restWindow = quiet ? restWindow + dt : 0
            if quiet && !restWindowStarted {
                restWindowStarted = true
                markers.append(.restWindowBegin)
            } else if !quiet {
                restWindowStarted = false
            }
            if !restCertified, restWindow + 1e-12 >= gates.minimumRestWindowSeconds {
                restCertified = true
                markers.append(.restCertified)
            }

            samples.append(sample(time: Double(step) * dt,
                                  state: state,
                                  contacts: markers))
        }

        let penetrationPixels = maximumPenetration / well.halfPhysicalPixelMeters * 0.5
        let metrics = SeedMetrics(
            seed: seed,
            contactCount: contactCount,
            maximumContactEnergyGainRatio: maximumEnergyGain,
            maximumPenetrationMeters: maximumPenetration,
            maximumPenetrationPhysicalPixels: penetrationPixels,
            restingWindowSeconds: restWindow,
            finalLinearSpeedMetersPerSecond: state.linearVelocity.length,
            finalAngularSpeedRadiansPerSecond: state.angularVelocity.length,
            minimumContainmentMarginMeters: minimumContainmentMargin,
            hardVelocityZeroingUsed: false,
            passed: contactCount > 0
                && maximumEnergyGain <= gates.maximumContactEnergyGainRatio
                && penetrationPixels <= gates.maximumPenetrationPhysicalPixels
                && restWindow + 1e-12 >= gates.minimumRestWindowSeconds
                && state.linearVelocity.length < gates.maximumRestLinearSpeedMetersPerSecond
                && state.angularVelocity.length < gates.maximumRestAngularSpeedRadiansPerSecond
                && minimumContainmentMargin >= 0
        )
        return SeedTranscript(seed: seed,
                              well: well,
                              coin: coin,
                              metrics: metrics,
                              samples: samples)
    }

    private func advanceFlight(state: CoinState, duration: Double) -> (
        state: CoinState,
        impacted: Bool,
        captured: Bool,
        maximumPenetration: Double,
        energyGainRatio: Double
    ) {
        var current = state
        var remaining = duration
        var impacted = false
        var maximumPenetration = 0.0
        var maximumEnergyGain = 0.0
        var eventBudget = 4

        while remaining > 1e-12 {
            var startSeparation = contactGeometry(current).separation
            let startContactVelocity = contactVelocity(current).z
            if startSeparation <= Self.timeOfImpactTolerance,
               startContactVelocity < 0,
               eventBudget > 0 {
                let penetration = max(0, -startSeparation)
                maximumPenetration = max(maximumPenetration, penetration)
                current.position.z += penetration
                startSeparation = contactGeometry(current).separation
                let beforeEnergy = mechanicalEnergy(current)
                let normalSpeed = impactNormalSpeed(current)
                let capture = normalSpeed * Self.restitution <= Self.captureNormalSpeed
                applyImpulse(state: &current, restitution: capture ? 0 : Self.restitution)
                let afterEnergy = mechanicalEnergy(current)
                maximumEnergyGain = max(
                    maximumEnergyGain,
                    max(0, afterEnergy - beforeEnergy) / max(abs(beforeEnergy), 1e-12)
                )
                impacted = true
                eventBudget -= 1
                if capture {
                    return (advanceSupport(state: current, duration: remaining),
                            true, true, maximumPenetration, maximumEnergyGain)
                }
                continue
            }

            let candidate = propagated(current, duration: remaining)
            let candidateSeparation = contactGeometry(candidate).separation
            if startSeparation > 0, candidateSeparation <= 0, eventBudget > 0 {
                var lower = 0.0
                var upper = remaining
                for _ in 0..<42 {
                    let middle = 0.5 * (lower + upper)
                    let probe = propagated(current, duration: middle)
                    if contactGeometry(probe).separation > 0 {
                        lower = middle
                    } else {
                        upper = middle
                    }
                }
                current = propagated(current, duration: upper)
                remaining -= upper
                continue
            }

            maximumPenetration = max(maximumPenetration, max(0, -candidateSeparation))
            return (candidate, impacted, false,
                    maximumPenetration, maximumEnergyGain)
        }

        return (current, impacted, false, maximumPenetration, maximumEnergyGain)
    }

    private func propagated(_ state: CoinState, duration: Double) -> CoinState {
        CoinState(
            position: state.position + state.linearVelocity * duration
                + Self.gravity * (0.5 * duration * duration),
            orientation: state.orientation.integrated(
                worldAngularVelocity: state.angularVelocity,
                duration: duration
            ),
            linearVelocity: state.linearVelocity + Self.gravity * duration,
            angularVelocity: state.angularVelocity
        )
    }

    private func advanceSupport(state: CoinState, duration: Double) -> CoinState {
        guard duration > 0 else { return state }
        let translationDecay = exp(-Self.translationResistance * duration)
        let tiltDecay = exp(-Self.tiltResistance * duration)
        let spinDecay = exp(-Self.spinResistance * duration)
        var velocity = Vector3(
            x: state.linearVelocity.x * translationDecay,
            y: state.linearVelocity.y * translationDecay,
            z: state.linearVelocity.z
        )
        let angularVelocity = Vector3(
            x: state.angularVelocity.x * tiltDecay,
            y: state.angularVelocity.y * tiltDecay,
            z: state.angularVelocity.z * spinDecay
        )
        let integrated = state.orientation.integrated(
            worldAngularVelocity: angularVelocity,
            duration: duration
        )
        let level = Quaternion(axis: .up, angle: integrated.yaw)
        let orientation = integrated.slerped(to: level, fraction: 1 - tiltDecay)
        var position = state.position
        position.x += 0.5 * (state.linearVelocity.x + velocity.x) * duration
        position.y += 0.5 * (state.linearVelocity.y + velocity.y) * duration
        let oldHeight = supportHeight(state.orientation)
        let newHeight = supportHeight(orientation)
        position.z = newHeight
        velocity.z = (newHeight - oldHeight) / duration
        return CoinState(position: position,
                         orientation: orientation,
                         linearVelocity: velocity,
                         angularVelocity: angularVelocity)
    }

    private func applyImpulse(state: inout CoinState, restitution: Double) {
        let axis = state.orientation.rotate(.up).normalized()
        if abs(axis.z) >= cos(15 * .pi / 180) {
            applyFaceManifoldImpulse(state: &state, restitution: restitution)
            return
        }

        let contact = contactGeometry(state)
        let normal = Vector3.up
        let relativeVelocity = state.linearVelocity
            + state.angularVelocity.cross(contact.centerOffset)
        let normalVelocity = relativeVelocity.dot(normal)
        guard normalVelocity < 0 else { return }

        let normalLever = contact.centerOffset.cross(normal)
        let effectiveNormalMass = coin.inverseMass
            + normal.dot(coin.inverseInertia(normalLever,
                                             orientation: state.orientation)
                .cross(contact.centerOffset))
        let normalImpulseMagnitude = -(1 + restitution) * normalVelocity
            / max(effectiveNormalMass, 1e-12)
        let normalImpulse = normal * normalImpulseMagnitude
        state.linearVelocity = state.linearVelocity + normalImpulse * coin.inverseMass
        state.angularVelocity = state.angularVelocity
            + coin.inverseInertia(contact.centerOffset.cross(normalImpulse),
                                  orientation: state.orientation)

        let afterNormal = state.linearVelocity
            + state.angularVelocity.cross(contact.centerOffset)
        let tangentVelocity = afterNormal - normal * afterNormal.dot(normal)
        guard tangentVelocity.length > 1e-12 else { return }
        let tangent = tangentVelocity.normalized()
        let tangentLever = contact.centerOffset.cross(tangent)
        let effectiveTangentMass = coin.inverseMass
            + tangent.dot(coin.inverseInertia(tangentLever,
                                              orientation: state.orientation)
                .cross(contact.centerOffset))
        let unconstrained = -tangentVelocity.length / max(effectiveTangentMass, 1e-12)
        let frictionMagnitude = max(unconstrained,
                                    -Self.friction * normalImpulseMagnitude)
        let frictionImpulse = tangent * frictionMagnitude
        state.linearVelocity = state.linearVelocity + frictionImpulse * coin.inverseMass
        state.angularVelocity = state.angularVelocity
            + coin.inverseInertia(contact.centerOffset.cross(frictionImpulse),
                                  orientation: state.orientation)
    }

    private func applyFaceManifoldImpulse(state: inout CoinState,
                                          restitution: Double) {
        let incomingNormalSpeed = max(0, -state.linearVelocity.z)
        guard incomingNormalSpeed > 0 else { return }
        let normalDelta = (1 + restitution) * incomingNormalSpeed
        state.linearVelocity.z += normalDelta

        let tangent = Vector3(x: state.linearVelocity.x,
                              y: state.linearVelocity.y,
                              z: 0)
        let maximumFrictionDelta = Self.friction * normalDelta
        let retainedTangentSpeed = max(tangent.length * 0.08,
                                       tangent.length - maximumFrictionDelta)
        if tangent.length > 1e-12 {
            let retained = retainedTangentSpeed / tangent.length
            state.linearVelocity.x *= retained
            state.linearVelocity.y *= retained
        }

        // A nearly parallel face lands through a distributed contact patch.
        // Its opposing edge impulses cancel most tip torque without deleting
        // either velocity vector. Axial spin survives and decays under rolling
        // resistance during persistent support.
        state.angularVelocity.x *= 0.22
        state.angularVelocity.y *= 0.22
        state.angularVelocity.z *= 0.94
    }

    private func impactNormalSpeed(_ state: CoinState) -> Double {
        let axis = state.orientation.rotate(.up).normalized()
        if abs(axis.z) >= cos(15 * .pi / 180) {
            return max(0, -state.linearVelocity.z)
        }
        return max(0, -contactVelocity(state).z)
    }

    private func contactGeometry(_ state: CoinState) -> ContactGeometry {
        let axis = state.orientation.rotate(.up).normalized()
        let axialProjection = axis.z
        let radialLength = sqrt(max(0, 1 - axialProjection * axialProjection))
        let axialOffset: Vector3
        if abs(axialProjection) < 1e-12 {
            axialOffset = Vector3(x: 0, y: 0, z: -coin.halfThickness)
        } else {
            axialOffset = axis * (-coin.halfThickness * (axialProjection > 0 ? 1 : -1))
        }
        let radialDirection = Vector3(x: axis.x, y: axis.y, z: -radialLength)
            .normalized(or: Vector3(x: 1, y: 0, z: 0))
        let radialOffset = radialLength > 1e-12 ? radialDirection * coin.radius : Vector3(x: 0, y: 0, z: 0)
        let support = axialOffset + radialOffset
        return ContactGeometry(separation: state.position.z + support.z,
                               centerOffset: support)
    }

    private func contactVelocity(_ state: CoinState) -> Vector3 {
        let contact = contactGeometry(state)
        return state.linearVelocity + state.angularVelocity.cross(contact.centerOffset)
    }

    private func supportHeight(_ orientation: Quaternion) -> Double {
        let axis = orientation.rotate(.up).normalized()
        let axial = abs(axis.z)
        return coin.halfThickness * axial
            + coin.radius * sqrt(max(0, 1 - axial * axial))
    }

    private func mechanicalEnergy(_ state: CoinState) -> Double {
        let axis = state.orientation.rotate(.up).normalized()
        let axialSpeed = state.angularVelocity.dot(axis)
        let radialSpeed = state.angularVelocity - axis * axialSpeed
        return 0.5 * coin.mass * state.linearVelocity.lengthSquared
            + 0.5 * coin.axialInertia * axialSpeed * axialSpeed
            + 0.5 * coin.radialInertia * radialSpeed.lengthSquared
            + coin.mass * 9.81 * state.position.z
    }

    private func containmentMargin(_ position: Vector3) -> Double {
        min(well.floorWidth * 0.5 - coin.radius - abs(position.x),
            well.floorHeight * 0.5 - coin.radius - abs(position.y))
    }

    private func sample(time: Double,
                        state: CoinState,
                        contacts: [ContactMarker]) -> TranscriptSample {
        TranscriptSample(time: time,
                         position: state.position,
                         orientation: state.orientation,
                         linearVelocity: state.linearVelocity,
                         angularVelocity: state.angularVelocity,
                         contacts: contacts)
    }
}
