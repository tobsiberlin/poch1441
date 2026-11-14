import Darwin
import Foundation

private struct GateSummary: Encodable {
    let verdict: String
    let checks: Int
    let failures: [String]
    let commitPolicy: MotionCommitPolicy
    let selection: SelectionEvidence
    let seeds: [SeedMetrics]
}

private enum GateRunner {
    static let seeds: [UInt64] = (0..<12).map { 1_441 + UInt64($0) * 97 }

    static func run() throws -> Int32 {
        let simulator = CoinTranscriptSimulator()
        let transcripts = seeds.map(simulator.run(seed:))
        let commitPolicy = MotionCommitPolicy()
        let selection = selectionEvidence()
        var failures: [String] = []
        var checks = 0

        for transcript in transcripts {
            let metrics = transcript.metrics
            require(metrics.contactCount > 0,
                    "seed \(metrics.seed): no contact marker", checks: &checks, failures: &failures)
            require(metrics.maximumContactEnergyGainRatio <= simulator.gates.maximumContactEnergyGainRatio,
                    "seed \(metrics.seed): contact energy gain \(metrics.maximumContactEnergyGainRatio)",
                    checks: &checks, failures: &failures)
            require(metrics.maximumPenetrationPhysicalPixels <= simulator.gates.maximumPenetrationPhysicalPixels,
                    "seed \(metrics.seed): penetration \(metrics.maximumPenetrationPhysicalPixels) px",
                    checks: &checks, failures: &failures)
            require(!metrics.hardVelocityZeroingUsed,
                    "seed \(metrics.seed): hard velocity zeroing", checks: &checks, failures: &failures)
            require(metrics.restingWindowSeconds + 1e-12 >= simulator.gates.minimumRestWindowSeconds,
                    "seed \(metrics.seed): rest window \(metrics.restingWindowSeconds)s",
                    checks: &checks, failures: &failures)
            require(metrics.finalLinearSpeedMetersPerSecond < simulator.gates.maximumRestLinearSpeedMetersPerSecond,
                    "seed \(metrics.seed): final linear speed \(metrics.finalLinearSpeedMetersPerSecond)m/s",
                    checks: &checks, failures: &failures)
            require(metrics.finalAngularSpeedRadiansPerSecond < simulator.gates.maximumRestAngularSpeedRadiansPerSecond,
                    "seed \(metrics.seed): final angular speed \(metrics.finalAngularSpeedRadiansPerSecond)rad/s",
                    checks: &checks, failures: &failures)
            require(metrics.minimumContainmentMarginMeters >= 0,
                    "seed \(metrics.seed): escaped outer well by \(-metrics.minimumContainmentMarginMeters)m",
                    checks: &checks, failures: &failures)
            print(String(
                format: "seed %4llu  contacts=%d  dE=%8.5f%%  penetration=%8.5fpx  rest=%5.3fs  |v|=%8.6f  |w|=%8.6f  margin=%6.3fmm  %@",
                metrics.seed,
                metrics.contactCount,
                metrics.maximumContactEnergyGainRatio * 100,
                metrics.maximumPenetrationPhysicalPixels,
                metrics.restingWindowSeconds,
                metrics.finalLinearSpeedMetersPerSecond,
                metrics.finalAngularSpeedRadiansPerSecond,
                metrics.minimumContainmentMarginMeters * 1_000,
                metrics.passed ? "PASS" : "FAIL"
            ))
        }

        require(commitPolicy.disposition(for: .prepared) == .returnToVisibleSourcePose,
                "pre-release cancel does not return to the visible source pose",
                checks: &checks, failures: &failures)
        require(commitPolicy.disposition(for: .freeFlight) == .committedTimeScaleOnly,
                "free-flight path can be spatially retargeted or cancelled",
                checks: &checks, failures: &failures)
        require(commitPolicy.disposition(for: .postContact) == .finishTranscriptThenVisibleCountermove,
                "post-contact state can roll back before certified rest",
                checks: &checks, failures: &failures)
        require(selection.availableTranscriptCount >= selection.protectedHistoryLength + 1,
                "runtime bucket has fewer than nine transcripts",
                checks: &checks, failures: &failures)
        require(!selection.repeatWithinProtectedHistory,
                "selection audit repeats a transcript inside the last eight throws",
                checks: &checks, failures: &failures)
        let velocityAudit = hardVelocityZeroingViolations()
        require(velocityAudit.isEmpty,
                "hard velocity zeroing source patterns: \(velocityAudit.joined(separator: ", "))",
                checks: &checks, failures: &failures)

        if failures.isEmpty, let restingState = transcripts.first?.samples.last.map({ sample in
            CoinState(position: sample.position,
                      orientation: sample.orientation,
                      linearVelocity: sample.linearVelocity,
                      angularVelocity: sample.angularVelocity)
        }) {
            do {
                let receipt = try EvidenceRenderer.render(restingState: restingState)
                require(receipt.viewportWidth == 402 && receipt.viewportHeight == 874,
                        "visual evidence is not 402x874",
                        checks: &checks, failures: &failures)
                require(receipt.separateGroundShadowLayer,
                        "visual evidence has no separate ground shadow layer",
                        checks: &checks, failures: &failures)
                require(receipt.frontLipOcclusionRecomposited,
                        "visual evidence has no real front-lip occlusion pass",
                        checks: &checks, failures: &failures)
                require(receipt.materialSignature.contains("aged real copper")
                            && receipt.materialSignature.contains("aged smoke-clear polycarbonate"),
                        "visual evidence lost the Track-B material signature",
                        checks: &checks, failures: &failures)
            } catch {
                require(false, "visual evidence renderer failed: \(error)",
                        checks: &checks, failures: &failures)
            }
        }

        let verdict = failures.isEmpty ? "GREEN" : "RED"
        let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Evidence", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory,
                                                withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        let bundle = TranscriptBundle(
            generatedAt: formatter.string(from: Date()),
            sampleRateHertz: CoinTranscriptSimulator.sampleRateHertz,
            gates: simulator.gates,
            commitPolicy: commitPolicy,
            selection: selection,
            transcripts: transcripts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(bundle).write(
            to: outputDirectory.appendingPathComponent("coin-6dof-transcripts-12-seeds.json"),
            options: .atomic
        )
        let summary = GateSummary(verdict: verdict,
                                  checks: checks,
                                  failures: failures,
                                  commitPolicy: commitPolicy,
                                  selection: selection,
                                  seeds: transcripts.map(\.metrics))
        try encoder.encode(summary).write(
            to: outputDirectory.appendingPathComponent("gate-summary.json"),
            options: .atomic
        )

        print("\(verdict) - \(checks - failures.count)/\(checks) checks passed")
        failures.forEach { print("FAIL: \($0)") }
        return failures.isEmpty ? EXIT_SUCCESS : EXIT_FAILURE
    }

    private static func require(_ condition: Bool,
                                _ failure: String,
                                checks: inout Int,
                                failures: inout [String]) {
        checks += 1
        if !condition { failures.append(failure) }
    }

    private static func selectionEvidence() -> SelectionEvidence {
        let historyLength = 8
        var random = SeededRandom(seed: 0x504F_4348_3134_3431)
        var draws: [UInt64] = []
        draws.reserveCapacity(48)
        var repeated = false

        for _ in 0..<48 {
            let protected = Set(draws.suffix(historyLength))
            let candidates = seeds.filter { !protected.contains($0) }
            guard !candidates.isEmpty else {
                repeated = true
                break
            }
            let index = Int(random.next() % UInt64(candidates.count))
            let selected = candidates[index]
            if protected.contains(selected) { repeated = true }
            draws.append(selected)
        }
        return SelectionEvidence(bucket: RuntimeBucket(),
                                 availableTranscriptCount: seeds.count,
                                 protectedHistoryLength: historyLength,
                                 auditDraws: draws,
                                 repeatWithinProtectedHistory: repeated)
    }

    private static func hardVelocityZeroingViolations() -> [String] {
        let sourceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/CoinTranscriptGate", isDirectory: true)
        let forbidden = [
            "linearVelocity = .zero",
            "angularVelocity = .zero",
            "linearVelocity: .zero",
            "angularVelocity: .zero",
        ]
        var violations: [String] = []
        for name in ["CoinPhysics.swift", "Math3D.swift"] {
            let fileURL = sourceRoot.appendingPathComponent(name)
            guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else {
                violations.append("unreadable:\(fileURL.lastPathComponent)")
                continue
            }
            for pattern in forbidden where source.contains(pattern) {
                violations.append("\(fileURL.lastPathComponent):\(pattern)")
            }
        }
        return violations
    }
}

do {
    Darwin.exit(try GateRunner.run())
} catch {
    fputs("RED - gate runner failed: \(error)\n", stderr)
    Darwin.exit(EXIT_FAILURE)
}
