import Darwin
import Foundation

private struct TechnicalSummary: Encodable {
    let verdict: String
    let inherited: InheritedCertificate
    let material: MaterialReceipt
    let failures: [String]
}

private enum Runner {
    static func run() throws -> Int32 {
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let repository = current.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let inherited = try InheritedEvidence.load(from: repository)
        var failures: [String] = []
        require(inherited.summary.verdict == "GREEN", "V1 verdict is not GREEN", into: &failures)
        require(inherited.summary.checks == 106, "V1 does not expose 106 checks", into: &failures)
        require(inherited.summary.failures.isEmpty, "V1 contains failures", into: &failures)
        require(inherited.bundle.transcripts.count == 12, "V1 transcript count is not 12", into: &failures)
        require(inherited.summary.commitPolicy.commitPoint == "release",
                "release is not the inherited commit point", into: &failures)
        require(inherited.summary.commitPolicy.freeFlight == "committedTimeScaleOnly",
                "free-flight commit policy changed", into: &failures)
        require(inherited.summary.commitPolicy.postContact == "finishTranscriptThenVisibleCountermove",
                "post-contact policy changed", into: &failures)
        require(inherited.summary.selection.availableTranscriptCount >= 9,
                "selection pool has fewer than nine transcripts", into: &failures)
        require(!inherited.summary.selection.repeatWithinProtectedHistory,
                "inherited selection repeats inside protected history", into: &failures)
        guard failures.isEmpty,
              let state = inherited.bundle.transcripts.first?.samples.last else {
            failures.forEach { print("FAIL: \($0)") }
            return EXIT_FAILURE
        }

        let argument = CommandLine.arguments.dropFirst().first ?? "--crop-gate"
        let mode: RenderMode = argument == "--uncut" ? .uncut : .cropGate
        let evidence = current.appendingPathComponent("Evidence", isDirectory: true)
        let material = try MaterialRenderer.render(repository: repository,
                                                   state: state,
                                                   mode: mode,
                                                   outputDirectory: evidence)
        require(material.projectedCoinDiameterPixels >= 19
                    && material.projectedCoinDiameterPixels <= 21,
                "projected coin diameter is no longer physical", into: &failures)
        require(material.alphaCropPixels[2] >= 290,
                "source alpha crop did not recover the real coin face", into: &failures)
        require(material.supersampleScale >= 4,
                "material is not supersampled before target projection", into: &failures)

        let summary = TechnicalSummary(
            verdict: failures.isEmpty ? "TECHNICAL_GREEN_HUMAN_PENDING" : "RED",
            inherited: inherited.certificate,
            material: material,
            failures: failures
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(summary).write(
            to: evidence.appendingPathComponent("technical-summary.json"),
            options: .atomic
        )
        print("\(summary.verdict) - inherited V1 untouched; mode=\(mode.rawValue)")
        failures.forEach { print("FAIL: \($0)") }
        return failures.isEmpty ? EXIT_SUCCESS : EXIT_FAILURE
    }

    private static func require(_ condition: Bool,
                                _ failure: String,
                                into failures: inout [String]) {
        if !condition { failures.append(failure) }
    }
}

do {
    Darwin.exit(try Runner.run())
} catch {
    fputs("RED - material lock failed: \(error)\n", stderr)
    Darwin.exit(EXIT_FAILURE)
}
