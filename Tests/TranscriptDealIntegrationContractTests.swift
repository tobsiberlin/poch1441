import Foundation

@main
struct TranscriptDealIntegrationContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static func main() throws {
        let content = try source("App/ContentView.swift")
        let overlay = try source("App/DealOverlay.swift")
        let certified = try source("App/CertifiedDealTranscript.swift")
        let gameState = try source("App/GameState.swift")

        expect(certified.contains("#if DEBUG"),
               "Transcript selection must be compiled behind DEBUG")
        expect(certified.contains("-transcriptDealQA"),
               "Standard QA needs an explicit launch gate")
        expect(certified.contains("-transcriptDealReducedMotionQA"),
               "Reduced Motion QA needs an explicit launch gate")
        expect(certified.contains("return nil"),
               "The default and every release build must retain the fallback")
        expect(certified.components(separatedBy: "MotionPlaybackPlan(").count - 1 == 1,
               "Stage 3 must instantiate exactly the admitted single-card plan")

        expect(overlay.contains("if let transcriptMode"),
               "FlyingBack must select the transcript only when the gate is active")
        expect(overlay.contains("private var impactFlight: some View"),
               "The old ImpactFlight path must remain an immediate fallback")
        expect(overlay.contains("onContact: registerTranscriptContact"),
               "Transcript contact must enter the existing transaction gate")
        expect(overlay.contains("onRest: registerTranscriptRest"),
               "Transcript rest must remain distinct from contact")
        expect(overlay.contains("onImpact()\n    }\n\n    private func registerTranscriptRest"),
               "Only contact may invoke the GameState callback")
        expect(overlay.contains("try await Task.sleep(for: .milliseconds(4))"),
               "The debug consumer must sample a real monotone wallclock")
        expect(overlay.contains("not emit a callback after SwiftUI has cancelled this task"),
               "Task cancellation must explicitly forbid late callbacks")

        expect(gameState.contains("guard presentation.impact(id: eventID) else { return }"),
               "GameState must keep its duplicate and cancelled-event gate")
        expect(gameState.contains("landedDealIndices.insert(sequence)"),
               "Out-of-order contacts must still use the existing ordered buffer")
        expect(gameState.contains("presentation.cancelAll()"),
               "Skip must invalidate pending presentation events")
        expect(!gameState.contains("TranscriptMotionPlayer"),
               "GameState must remain independent of the motion player")
        expect(!certified.contains("import PochKit"),
               "The admitted transcript must remain rule-neutral")
        expect(content.contains("if ProcessInfo.processInfo.arguments.contains(\"-transcriptDealReducedMotionQA\")"),
               "Reduced Motion QA must create real events without changing the product default")

        print("TranscriptDealIntegrationContractTests: PASS")
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(
                Data("TranscriptDealIntegrationContractTests: \(message)\n".utf8)
            )
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
