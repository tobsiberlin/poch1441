import Foundation

@main
struct Phase1MeldPresentationContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static func main() throws {
        let content = try source("App/ContentView.swift")
        let overlay = try source("App/DealOverlay.swift")
        let gameState = try source("App/GameState.swift")
        let tokens = try source("App/DesignTokens.swift")

        expect(content.contains(".onChange(of: guidedReduceMotion)"),
               "A live Reduce Motion change must settle the active Phase-1 transfer")
        expect(content.contains("game.settlePhase1Presentation()"),
               "Leaving Phase 1 must settle its material presentation")
        expect(content.contains("-meldPayoutLiveReduceMotionQA"),
               "The live preference change needs a deterministic runtime route")
        expect(content.contains("-meldPayoutFastTransitionQA"),
               "A stale completion needs a deterministic transition route")
        expect(content.contains("game.debugBeginNextMeldPayout()"),
               "Fast handoff QA must begin a real visible transfer before leaving Phase 1")
        expect(content.contains("guidedMeldTask: Task<Void, Never>?"),
               "The guided meld flow must own its asynchronous work")
        expect(content.contains("generation == guidedMeldGeneration"),
               "Reset or phase changes must invalidate guided meld work")
        expect(content.contains("guidedMeldTask?.cancel()"),
               "The guided meld flow needs an explicit cancellation path")
        expect(content.contains("guidedMeldInterruptionTask: Task<Void, Never>?"),
               "Deterministic interruption QA must retain its asynchronous trigger")
        expect(content.contains("cancelGuidedMeldFlow()\n                game.settlePhase1Presentation()"),
               "Closing the guided rail must not leave Phase 1 partially presented")

        expect(overlay.contains("let generation = game.meldPresentationGeneration"),
               "Every payout flight must capture its presentation generation")
        expect(overlay.contains("generation: generation"),
               "The material contact must return its captured generation")
        expect(overlay.contains("TableWorldPiece(world: world"),
               "Meld payouts must use the shared physical table material")
        expect(overlay.contains("delay: Double(index) * Tokens.p1MeldTokenStagger"),
               "The heavy pieces must remain individually visible in flight")
        expect(!overlay.contains("Double(progress) * 3.6"),
               "A flying token must not rotate its baked material lighting")
        expect(overlay.contains("guard index == count - 1"),
               "Only the last physical contact may settle the payout")
        expect(overlay.contains("phase1.meld.flight"),
               "Runtime QA needs a semantic handle for the visible transfer")

        expect(gameState.contains("private(set) var meldPresentationGeneration = 0"),
               "Meld callbacks need a monotone presentation identity")
        expect(gameState.contains("generation == meldPresentationGeneration"),
               "Stale contacts must be rejected before mutating counters")
        expect(gameState.contains("presentation.cancelAll()"),
               "Immediate settlement must cancel active presentation events")
        expect(gameState.contains("func debugStartMeldPayout()"),
               "The UI test must use a deterministic PochKit-backed payout")

        expect(tokens.contains("static let p1MeldTokenDiameter"),
               "Physical payout scale belongs in DesignTokens")
        expect(tokens.contains("static let p1MeldPhysicalLimit"),
               "The visible material limit must be explicit")

        FileHandle.standardOutput.write(
            Data("Phase1MeldPresentationContractTests: PASS\n".utf8)
        )
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(
            Data("Phase1MeldPresentationContractTests: \(message)\n".utf8)
        )
        Foundation.exit(EXIT_FAILURE)
    }
}
