import Foundation

struct GateFailure: Error, CustomStringConvertible {
    let gate: Int
    let message: String
    var description: String { "Gate \(gate): \(message)" }
}

struct ViewportProjection: Equatable, Sendable {
    let width: Int
    let height: Int

    func project(_ point: Vector3) -> (x: Double, y: Double) {
        let scale = Double(min(width, height)) / 0.22
        return (
            Double(width) * 0.5 + point.x * scale,
            Double(height) * 0.58 - point.y * scale * 0.72 - point.z * scale * 0.68
        )
    }
}

@main
enum MotionCoinsV2GateRunner {
    static func main() {
        do {
            let experiment = CoinExperiment()
            let baseline = experiment.run()
            try gate1Apex(baseline)
            try gate2FirstContact(baseline)
            try gate3NoTunneling(baseline)
            try gate4ThreeDimensionalOrientation(baseline)
            try gate5ContactBeginnings(baseline)
            try gate6NoAuthoredSettleMechanism()
            try gate7SettleWindow(baseline)
            try gate8Support(baseline)
            try gate9ContactTolerance(baseline)
            try gate10Determinism(experiment: experiment, baseline: baseline)
            try gate11ViewportInvariance(baseline)
            emitSuccess(baseline)
        } catch {
            FileHandle.standardError.write(Data("MOTION_COINS_V2_BLOCKED: \(error)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }

    private static func gate1Apex(_ outcome: ExperimentOutcome) throws {
        guard (0.055...0.070).contains(outcome.apex) else {
            throw GateFailure(gate: 1, message: "Apex \(millimetres(outcome.apex)) mm")
        }
    }

    private static func gate2FirstContact(_ outcome: ExperimentOutcome) throws {
        guard let firstImpact = outcome.firstImpactTime,
              (0.18...0.26).contains(firstImpact) else {
            throw GateFailure(gate: 2, message: "first contact \(outcome.firstImpactTime ?? -1) s")
        }
    }

    private static func gate3NoTunneling(_ outcome: ExperimentOutcome) throws {
        guard outcome.maximumUnresolvedCrossing <= 0.00015 else {
            throw GateFailure(
                gate: 3,
                message: "unresolved crossing \(millimetres(outcome.maximumUnresolvedCrossing)) mm"
            )
        }
    }

    private static func gate4ThreeDimensionalOrientation(_ outcome: ExperimentOutcome) throws {
        guard outcome.minimumEdgeRatio < 0.35 else {
            throw GateFailure(gate: 4, message: "minimum edge ratio \(outcome.minimumEdgeRatio)")
        }
        let orientations = Set(outcome.trajectory.map { quantized($0.orientation) })
        guard orientations.count > 12 else {
            throw GateFailure(gate: 4, message: "orientation did not evolve in 3D")
        }
    }

    private static func gate5ContactBeginnings(_ outcome: ExperimentOutcome) throws {
        guard (1...4).contains(outcome.contactBeginnings) else {
            throw GateFailure(gate: 5, message: "\(outcome.contactBeginnings) contact beginnings")
        }
    }

    private static func gate6NoAuthoredSettleMechanism() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("RigidCoinExperiment.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8).lowercased()
        let forbidden = [
            "spring", "slot", "snap", "magnet", "timeout",
            "targetposition", "settleposition", "forcedsettle",
        ]
        for token in forbidden where source.contains(token) {
            throw GateFailure(gate: 6, message: "forbidden authored settle token: \(token)")
        }
    }

    private static func gate7SettleWindow(_ outcome: ExperimentOutcome) throws {
        guard let firstImpact = outcome.firstImpactTime,
              let settle = outcome.settleTime,
              settle - firstImpact <= 1.25 else {
            throw GateFailure(
                gate: 7,
                message: "settle delta \((outcome.settleTime ?? -1) - (outcome.firstImpactTime ?? 0)) s"
            )
        }
    }

    private static func gate8Support(_ outcome: ExperimentOutcome) throws {
        guard outcome.hasSupport && outcome.finalBody.sleeping else {
            throw GateFailure(gate: 8, message: "final body has no stable support")
        }
    }

    private static func gate9ContactTolerance(_ outcome: ExperimentOutcome) throws {
        guard outcome.maximumUnresolvedCrossing <= 0.00015,
              outcome.finalSupportGap <= 0.00020 else {
            throw GateFailure(
                gate: 9,
                message: "penetration \(millimetres(outcome.maximumUnresolvedCrossing)) mm, "
                    + "support gap \(millimetres(outcome.finalSupportGap)) mm"
            )
        }
    }

    private static func gate10Determinism(
        experiment: CoinExperiment,
        baseline: ExperimentOutcome
    ) throws {
        let baselineDigest = trajectoryDigest(baseline.trajectory)
        for replay in 1...10 {
            let outcome = experiment.run()
            let stepTolerance = CoinExperiment.fixedStep + 1e-12
            guard abs((outcome.firstImpactTime ?? -1) - (baseline.firstImpactTime ?? -1)) <= stepTolerance,
                  abs((outcome.settleTime ?? -1) - (baseline.settleTime ?? -1)) <= stepTolerance,
                  (outcome.finalBody.position - baseline.finalBody.position).length <= 0.00020,
                  orientationDifferenceDegrees(
                    outcome.finalBody.orientation,
                    baseline.finalBody.orientation
                  ) <= 0.5,
                  trajectoryDigest(outcome.trajectory) == baselineDigest else {
                throw GateFailure(gate: 10, message: "replay \(replay) diverged")
            }
        }
    }

    private static func gate11ViewportInvariance(_ outcome: ExperimentOutcome) throws {
        let portrait = ViewportProjection(width: 390, height: 844)
        let landscape = ViewportProjection(width: 667, height: 375)
        let portraitPoints = outcome.trajectory.map { portrait.project($0.position) }
        let landscapePoints = outcome.trajectory.map { landscape.project($0.position) }
        guard portraitPoints.count == landscapePoints.count,
              portraitPoints.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              landscapePoints.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            throw GateFailure(gate: 11, message: "projection changed physics samples")
        }
        let digestBeforeProjection = trajectoryDigest(outcome.trajectory)
        guard digestBeforeProjection == trajectoryDigest(outcome.trajectory) else {
            throw GateFailure(gate: 11, message: "projection mutated world trajectory")
        }
    }

    private static func emitSuccess(_ outcome: ExperimentOutcome) {
        let report: [String: Any] = [
            "status": "PASS",
            "gates": 11,
            "fixed_step_hz": 120,
            "apex_mm": millimetres(outcome.apex),
            "first_contact_s": outcome.firstImpactTime ?? NSNull(),
            "settle_s": outcome.settleTime ?? NSNull(),
            "contact_beginnings": outcome.contactBeginnings,
            "minimum_edge_ratio": rounded(outcome.minimumEdgeRatio, digits: 4),
            "maximum_penetration_mm": millimetres(outcome.maximumUnresolvedCrossing),
            "support_gap_mm": millimetres(outcome.finalSupportGap),
            "physics_steps": outcome.physicsSteps,
        ]
        let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        if let data {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }

    private static func trajectoryDigest(_ trajectory: [TrajectorySample]) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for sample in trajectory {
            let values = [
                Double(sample.step),
                sample.position.x, sample.position.y, sample.position.z,
                sample.orientation.real,
                sample.orientation.imaginary.x,
                sample.orientation.imaginary.y,
                sample.orientation.imaginary.z,
            ]
            for value in values {
                let quantized = Int64((value * 1_000_000_000).rounded())
                hash ^= UInt64(bitPattern: quantized)
                hash &*= 1_099_511_628_211
            }
        }
        return hash
    }

    private static func orientationDifferenceDegrees(
        _ left: Quaternion,
        _ right: Quaternion
    ) -> Double {
        let relative = (left * right.conjugate).normalized
        let cosine = min(1, max(-1, abs(relative.real)))
        return (2 * acos(cosine)).degrees
    }

    private static func quantized(_ quaternion: Quaternion) -> String {
        [quaternion.real, quaternion.imaginary.x, quaternion.imaginary.y, quaternion.imaginary.z]
            .map { String(Int(($0 * 10_000).rounded())) }
            .joined(separator: ":")
    }

    private static func millimetres(_ metres: Double) -> Double {
        rounded(metres * 1_000, digits: 4)
    }

    private static func rounded(_ value: Double, digits: Int) -> Double {
        let factor = pow(10, Double(digits))
        return (value * factor).rounded() / factor
    }
}
