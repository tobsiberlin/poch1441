import Foundation

@main
struct TranscriptCoinIntegrationContractTests {
    static func main() throws {
        let phase2 = try source("App/Phase2View.swift")
        let drop = try source("App/TranscriptCoinDrop.swift")
        let effects = try source("App/Effects.swift")
        let gameState = try source("App/GameState.swift")
        let coinPlan = try source("App/CoinTransferPlan.swift")
        let cue = try source("App/MotionContactCue.swift")
        let feedback = try source("App/CoinContactFeedback.swift")

        expect(drop.hasPrefix("#if DEBUG"), "The first coin hook must compile only in DEBUG")
        expect(phase2.contains("-transcriptCoinQA"), "Standard QA needs an explicit switch")
        expect(phase2.contains("-transcriptCoinReducedMotionQA"),
               "Reduced Motion QA needs an explicit switch")
        expect(phase2.contains("theme == .unterwegs"),
               "The transcript hook must be confined to Track B")
        expect(drop.contains("queen.drop.seed-1441") || drop.contains("Queen-Well-Drop-Proof"),
               "The hook must remain labelled as a Queen drop, not a full throw")
        expect(drop.contains("CoinTransferTransaction"),
               "The existing transaction remains the only lifecycle gate")
        expect(drop.contains("MotionContactCue") && drop.contains("contactHostTime"),
               "The isolated hook must schedule feedback from the certified contact host tick")
        expect(drop.contains("feedback.markContact(identity: identity)"),
               "The same generation-bound cue must cross the visible contact gate")
        expect(drop.contains("cancelFeedbackBeforeContact"),
               "Pre-contact teardown must cancel pending physical output")
        expect(drop.contains("registerImpact") && drop.contains("beginSettling")
                && drop.contains("complete"),
               "Contact, settle, and completion must remain distinct")
        expect(drop.contains("CoinTranscriptSpriteAtlas"),
               "Runtime rendering must use the admitted build-time atlas")
        expect(drop.contains("QueenFrontLipMask"),
               "The actual tray front edge must occlude the coin")
        expect(!drop.contains("R1ContactFeedback") && !drop.contains("pochShock"),
               "The proof cannot reuse ceramic or action-time feedback")
        expect(effects.contains("R1ContactFeedback"),
               "The untouched ceramic fallback must remain available")
        expect(!gameState.contains("CoinTranscriptMotionPlayer"),
               "GameState must remain independent from the coin transcript")
        expect(!coinPlan.contains("import SwiftUI") && !coinPlan.contains("GameState"),
               "The transaction gate must remain renderer- and rule-neutral")
        expect(cue.contains("soundEnabled") && cue.contains("hapticsEnabled"),
               "Sound and haptic settings must stay independent on one cue")
        expect(feedback.contains("AVAudioTime(hostTime: cue.contactHostTime)"),
               "Audio must consume the cue host tick directly")
        expect(feedback.contains("hapticEngine.currentTime + delay"),
               "Haptics must map the same host edge into the independent engine clock")
        print("TranscriptCoinIntegrationContractTests: PASS")
    }

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("TranscriptCoinIntegrationContractTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
