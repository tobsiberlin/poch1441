import Darwin
import Foundation

do {
    let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let repository = current.deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let evidence = current.appendingPathComponent("Evidence", isDirectory: true)
    if CommandLine.arguments.contains("--app-sprite-atlas") {
        let output = repository.appendingPathComponent(
            "App/Assets.xcassets/CoinTranscriptSpriteAtlas.imageset/coin-transcript-sprite-atlas@3x.png"
        )
        let frameCount = try MaterialTimeGate.writeAppSpriteAtlas(
            repository: repository,
            outputURL: output
        )
        print("GREEN - wrote \(frameCount) admitted @3x sprite frames")
        Darwin.exit(EXIT_SUCCESS)
    }
    let uncutRequested = CommandLine.arguments.contains("--uncut-proof")
    let receipt = try MaterialTimeGate.run(
        repository: repository,
        outputDirectory: evidence,
        uncutProofURL: uncutRequested
            ? evidence.appendingPathComponent("uncut-material-proof-402x874.mp4")
            : nil
    )
    print("\(receipt.verdict) - \(receipt.selectedSampleIndices.count) temporal material frames; uncut=\(receipt.uncutProofGenerated)")
    Darwin.exit(EXIT_SUCCESS)
} catch {
    fputs("RED - material time gate failed: \(error)\n", stderr)
    Darwin.exit(EXIT_FAILURE)
}
