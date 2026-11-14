import Darwin
import Foundation

struct Fixture: Sendable {
    let name: String
    let family: String
    let body: CoinBody
    let plane: Plane
    let duration: Double
}

struct GateReport {
    private(set) var checks = 0
    private(set) var failures: [String] = []

    mutating func require(_ condition: Bool, _ message: String) {
        checks += 1
        if !condition { failures.append(message) }
    }
}

@main
enum GateRunner {
    static let rates = [60, 120, 240]

    static func main() {
        let solver = AnalyticCoinSolver()
        var report = GateReport()

        print("Coin Motion V3 - analytic architecture gates")
        print("collision: \(solver.architecture.collisionMethod)")
        runArchitectureGate(solver: solver, report: &report)
        runFreeFlightGate(solver: solver, report: &report)

        let fixtures = makeFixtures(solver: solver)
        let familyCounts = Dictionary(grouping: fixtures, by: \.family).mapValues { $0.count }
        report.require((familyCounts["central-face"] ?? 0) >= 7, "central face perturbation matrix is incomplete")
        report.require((familyCounts["edge-lip"] ?? 0) >= 7, "edge/lip perturbation matrix is incomplete")

        for fixture in fixtures {
            runFixtureGates(fixture: fixture, solver: solver, report: &report)
        }
        runRestGate(solver: solver, report: &report)

        if report.failures.isEmpty {
            print("GREEN - \(report.checks) mandatory checks passed")
            Darwin.exit(EXIT_SUCCESS)
        }

        print("RED - \(report.failures.count) of \(report.checks) mandatory checks failed")
        for failure in report.failures {
            print("FAIL: \(failure)")
        }
        Darwin.exit(EXIT_FAILURE)
    }

    private static func runArchitectureGate(
        solver: AnalyticCoinSolver,
        report: inout GateReport
    ) {
        let architecture = solver.architecture
        report.require(architecture.fixedSubstepCount == nil, "fixed physics substeps are configured")
        report.require(!architecture.sleepEnabled, "sleep is configured")
        report.require(!architecture.velocityZeroingEnabled, "velocity zeroing is configured")
        report.require(architecture.globalContactDamping == 0, "global contact damping is configured")
        print("architecture: no substeps, no sleep, no velocity zeroing, no global damping")
    }

    private static func runFreeFlightGate(
        solver: AnalyticCoinSolver,
        report: inout GateReport
    ) {
        for rate in rates {
            var body = CoinBody(
                position: Vector3(x: -0.03, y: 0.02, z: 0.75),
                linearVelocity: Vector3(x: 0.41, y: -0.17, z: 1.25),
                orientation: Quaternion(axis: Vector3(x: 1, y: 2, z: -0.5), angle: 0.63),
                angularVelocity: Vector3(x: 13, y: -7, z: 29)
            )
            let initialEnergy = solver.mechanicalEnergy(body)
            let initialMomentum = solver.angularMomentum(body)
            var maximumEnergyError = 0.0
            var maximumMomentumError = 0.0
            var maximumQuaternionError = 0.0
            let dt = 1 / Double(rate)

            for _ in 0..<rate {
                body = solver.propagated(body, duration: dt)
                maximumEnergyError = max(
                    maximumEnergyError,
                    abs(solver.mechanicalEnergy(body) - initialEnergy) / max(abs(initialEnergy), 1e-12)
                )
                maximumMomentumError = max(
                    maximumMomentumError,
                    (solver.angularMomentum(body) - initialMomentum).length
                        / max(initialMomentum.length, 1e-12)
                )
                maximumQuaternionError = max(maximumQuaternionError, abs(body.orientation.norm - 1))
            }

            print(String(
                format: "free-flight %3d Hz  dE=%9.2e  dL=%9.2e  dq=%9.2e",
                rate,
                maximumEnergyError,
                maximumMomentumError,
                maximumQuaternionError
            ))
            report.require(maximumEnergyError <= 1e-10, "free-flight energy drift at \(rate) Hz: \(maximumEnergyError)")
            report.require(maximumMomentumError <= 1e-10, "free-flight momentum drift at \(rate) Hz: \(maximumMomentumError)")
            report.require(maximumQuaternionError <= 1e-12, "free-flight quaternion drift at \(rate) Hz: \(maximumQuaternionError)")
        }
    }

    private static func runFixtureGates(
        fixture: Fixture,
        solver: AnalyticCoinSolver,
        report: inout GateReport
    ) {
        var outcomes: [Int: SimulationOutcome] = [:]
        for rate in rates {
            let outcome = solver.run(
                initialBody: fixture.body,
                plane: fixture.plane,
                duration: fixture.duration,
                hertz: rate
            )
            outcomes[rate] = outcome
            let energyGrowth = outcome.maximumEnergy - outcome.initialEnergy
            print(String(
                format: "%-24@ %3d Hz  hit=%7.5f  raw=%8.2e  residual=%8.2e  dE=%8.2e  splits=%d",
                fixture.name as NSString,
                rate,
                outcome.firstImpactTime ?? -1,
                outcome.maximumRawPenetration,
                outcome.maximumResidualPenetration,
                energyGrowth,
                outcome.eventSplits
            ))
            report.require(outcome.allFinite, "\(fixture.name) is non-finite at \(rate) Hz")
            report.require(outcome.impactCount > 0, "\(fixture.name) did not collide at \(rate) Hz")
            report.require(
                outcome.maximumRawPenetration <= 0.00015,
                "\(fixture.name) raw penetration at \(rate) Hz: \(outcome.maximumRawPenetration)"
            )
            report.require(
                outcome.maximumResidualPenetration <= 1e-9,
                "\(fixture.name) residual penetration at \(rate) Hz: \(outcome.maximumResidualPenetration)"
            )
            report.require(
                energyGrowth <= 0.01 * outcome.energyScale,
                "\(fixture.name) contact energy growth at \(rate) Hz: \(energyGrowth)"
            )
        }

        guard let reference = outcomes[240] else {
            report.require(false, "\(fixture.name) has no 240 Hz reference")
            return
        }
        for rate in [60, 120] {
            guard let candidate = outcomes[rate] else {
                report.require(false, "\(fixture.name) has no \(rate) Hz result")
                continue
            }
            let impactDifference = abs(
                (candidate.firstImpactTime ?? .infinity)
                    - (reference.firstImpactTime ?? -.infinity)
            )
            let positionDifference = (candidate.finalBody.position - reference.finalBody.position).length
            let orientationDifference = candidate.finalBody.orientation.angularDistance(
                to: reference.finalBody.orientation
            )
            let energyDifference = abs(
                solver.mechanicalEnergy(candidate.finalBody)
                    - solver.mechanicalEnergy(reference.finalBody)
            ) / reference.energyScale

            report.require(impactDifference <= 0.0001, "\(fixture.name) \(rate)/240 impact delta: \(impactDifference)")
            report.require(positionDifference <= 0.00075, "\(fixture.name) \(rate)/240 position delta: \(positionDifference)")
            report.require(orientationDifference <= 1 * .pi / 180, "\(fixture.name) \(rate)/240 orientation delta: \(orientationDifference.degrees)°")
            report.require(energyDifference <= 0.02, "\(fixture.name) \(rate)/240 energy delta: \(energyDifference)")
        }
    }

    private static func runRestGate(
        solver: AnalyticCoinSolver,
        report: inout GateReport
    ) {
        let plane = centralPlane
        let orientation = Quaternion.identity
        let body = placedBody(
            solver: solver,
            plane: plane,
            orientation: orientation,
            gap: 0.0004,
            tangentialOffset: .zero,
            velocity: Vector3(x: 0, y: 0, z: -0.03),
            angularVelocity: .zero
        )

        for rate in rates {
            let outcome = solver.run(
                initialBody: body,
                plane: plane,
                duration: 0.8,
                hertz: rate,
                auditRest: true
            )
            print(String(
                format: "rest central-baseline     %3d Hz  quiet=%5.3f  |v|=%8.2e  |w|=%8.2e  raw=%8.2e",
                rate,
                outcome.sustainedRestDuration,
                outcome.finalBody.linearVelocity.length,
                outcome.finalBody.angularVelocity.length,
                outcome.maximumRawPenetration
            ))
            report.require(outcome.impactCount > 0, "central rest baseline did not collide at \(rate) Hz")
            report.require(outcome.sustainedRestDuration >= 0.5, "central rest audit too short at \(rate) Hz: \(outcome.sustainedRestDuration)")
            report.require(outcome.finalBody.linearVelocity.length < 0.015, "central rest linear speed at \(rate) Hz")
            report.require(outcome.finalBody.angularVelocity.length < 0.8, "central rest angular speed at \(rate) Hz")
            report.require(outcome.maximumRawPenetration <= 0.00015, "central rest raw penetration at \(rate) Hz")
        }
    }

    private static var centralPlane: Plane {
        Plane(
            name: "central-floor",
            normal: .up,
            restitution: 0.24,
            restitutionCutoff: 0.25,
            friction: 0.28
        )
    }

    private static var lipPlane: Plane {
        let angle = 30 * Double.pi / 180
        return Plane(
            name: "inclined-lip-tangent",
            normal: Vector3(x: -sin(angle), y: 0, z: cos(angle)),
            restitution: 0.24,
            restitutionCutoff: 0.25,
            friction: 0.28
        )
    }

    private static func makeFixtures(solver: AnalyticCoinSolver) -> [Fixture] {
        let centralSpecs: [(String, Double, Double, Double)] = [
            ("central-baseline", 0, 0.82, 0),
            ("central-speed-minus", 0, 0.76, 0),
            ("central-speed-plus", 0, 0.88, 0),
            ("central-tilt-minus", -3, 0.82, 0),
            ("central-tilt-plus", 3, 0.82, 0),
            ("central-offset-minus", 0, 0.82, -0.004),
            ("central-offset-plus", 0, 0.82, 0.004),
        ]
        let central = centralSpecs.map { name, tilt, speed, offset -> Fixture in
            let orientation = Quaternion(axis: Vector3(x: 0, y: 1, z: 0), angle: tilt * .pi / 180)
            let body = placedBody(
                solver: solver,
                plane: centralPlane,
                orientation: orientation,
                gap: 0.008,
                tangentialOffset: Vector3(x: offset, y: 0, z: 0),
                velocity: Vector3(x: 0, y: 0, z: -speed),
                angularVelocity: .zero
            )
            return Fixture(name: name, family: "central-face", body: body, plane: centralPlane, duration: 0.035)
        }

        let lipSpecs: [(String, Double, Double, Double)] = [
            ("lip-baseline", 78, 0.90, 0),
            ("lip-speed-minus", 78, 0.83, 0),
            ("lip-speed-plus", 78, 0.97, 0),
            ("lip-angle-minus", 74, 0.90, 0),
            ("lip-angle-plus", 82, 0.90, 0),
            ("lip-offset-minus", 78, 0.90, -0.005),
            ("lip-offset-plus", 78, 0.90, 0.005),
        ]
        let lipNormal = lipPlane.normal
        let tangent = Vector3(x: lipNormal.z, y: 0, z: -lipNormal.x).normalized()
        let lip = lipSpecs.map { name, tilt, speed, offset -> Fixture in
            let orientation = Quaternion(axis: Vector3(x: 0, y: 1, z: 0), angle: tilt * .pi / 180)
            let body = placedBody(
                solver: solver,
                plane: lipPlane,
                orientation: orientation,
                gap: 0.008,
                tangentialOffset: tangent * offset,
                velocity: lipNormal * -speed + tangent * 0.22,
                angularVelocity: .zero
            )
            return Fixture(name: name, family: "edge-lip", body: body, plane: lipPlane, duration: 0.035)
        }
        return central + lip
    }

    private static func placedBody(
        solver: AnalyticCoinSolver,
        plane: Plane,
        orientation: Quaternion,
        gap: Double,
        tangentialOffset: Vector3,
        velocity: Vector3,
        angularVelocity: Vector3
    ) -> CoinBody {
        let probe = CoinBody(
            position: .zero,
            linearVelocity: velocity,
            orientation: orientation,
            angularVelocity: angularVelocity
        )
        let supportRadius = -solver.contactGeometry(body: probe, plane: plane).separation - plane.offset
        return CoinBody(
            position: plane.normal * (plane.offset + supportRadius + gap) + tangentialOffset,
            linearVelocity: velocity,
            orientation: orientation,
            angularVelocity: angularVelocity
        )
    }
}
