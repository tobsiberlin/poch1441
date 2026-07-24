import CryptoKit
import Foundation
import ImageIO

@MainActor
private final class CoinCallbackProbe {
    var names: [String] = []
    func record(_ name: String) { names.append(name) }
}

@main
@MainActor
struct CoinMotionTranscriptTests {
    static func main() throws {
        let plan = try loadPlan()
        validateHashBoundData(plan)
        validateBuildTimeAtlas()
        validateExactLifecycle(plan)
        validateCommittedCancel(plan)
        validateReducedMotion(plan)
        validateQuaternionInterpolation()
        print("CoinMotionTranscriptTests: PASS")
    }

    private static func validateBuildTimeAtlas() {
        let url = repositoryRoot
            .appendingPathComponent("App/Assets.xcassets/CoinTranscriptSpriteAtlas.imageset")
            .appendingPathComponent("coin-transcript-sprite-atlas@3x.png")
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any] else {
            fail("The build-time sprite atlas must exist and decode")
        }
        expect(properties[kCGImagePropertyPixelWidth] as? Int == 1_344,
               "The seven-column @3x atlas width must remain exact")
        expect(properties[kCGImagePropertyPixelHeight] as? Int == 2_688,
               "The fourteen-row @3x atlas height must remain exact")
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        expect(digest == "74af07a0cdca4b4276e2b69eb0a2c5f40a586581bcbc0b393439798ecc52f0f9",
               "The runtime atlas must remain byte-bound to the admitted renderer")
    }

    private static func validateHashBoundData(_ plan: CertifiedCoinTranscript) {
        expect(plan.isValid, "The extracted seed must pass every admission rule")
        expect(plan.contactSampleIndex == 18 && plan.contactTimeSeconds == 0.075,
               "The first impact edge must remain sample 18 at 75 ms")
        expect(plan.restSampleIndex == 387 && plan.restTimeSeconds == 1.6125,
               "Playback must end at the first restCertified marker")
        expect(plan.transcript.metrics.maximumContactEnergyGainRatio == 0,
               "The admitted seed may not gain contact energy")
        expect(plan.transcript.metrics.maximumPenetrationPhysicalPixels < 0.5,
               "The admitted seed must remain below the penetration gate")

        let source = repositoryRoot
            .appendingPathComponent("tasks/reviews/coin-motion-transcript-gate-v1/Evidence")
            .appendingPathComponent("coin-6dof-transcripts-12-seeds.json")
        guard let data = try? Data(contentsOf: source) else { fail("The source bundle must exist") }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        expect(digest == plan.sourceBundleSHA256,
               "The app resource must stay bound to the admitted source bundle")
    }

    private static func validateExactLifecycle(_ plan: CertifiedCoinTranscript) {
        let probe = CoinCallbackProbe()
        let player = makePlayer(plan: plan, mode: .standard, probe: probe)
        expect(player.release(at: 10).phase == .inFlight, "Release must enter free flight")
        expect(!player.advance(to: 10.074).contactDelivered, "Contact may not fire early")
        let contact = player.advance(to: 10.075)
        expect(contact.phase == .settling && contact.isMoving, "Contact must retain settle motion")
        expect(probe.names == ["contact"], "Contact must publish exactly once")
        let rest = player.advance(to: 11.6125)
        expect(rest.phase == .resting && !rest.isMoving, "Rest must end motion")
        expect(probe.names == ["contact", "rest"], "Rest must follow contact exactly once")
        _ = player.advance(to: 20)
        expect(probe.names == ["contact", "rest"], "Late time may not duplicate callbacks")
    }

    private static func validateCommittedCancel(_ plan: CertifiedCoinTranscript) {
        let probe = CoinCallbackProbe()
        let player = makePlayer(plan: plan, mode: .standard, probe: probe)
        _ = player.release(at: 30)
        let cancelled = player.cancel(at: 30.05)
        expect(cancelled.committedCancelIgnored, "Released coin motion cannot be cancelled")
        let regressed = player.advance(to: 30.01)
        expect(regressed.sample == cancelled.sample, "A host-clock regression cannot rewind pose")
        _ = player.advance(to: 31.6125)
        expect(probe.names == ["contact", "rest"], "Committed motion must finish causally")
    }

    private static func validateReducedMotion(_ plan: CertifiedCoinTranscript) {
        let probe = CoinCallbackProbe()
        let player = makePlayer(plan: plan, mode: .reducedMotion, probe: probe)
        let snapshot = player.release(at: 40)
        expect(snapshot.phase == .resting && !snapshot.isMoving,
               "Reduced Motion must reach rest synchronously")
        expect(snapshot.sample == plan.transcript.samples.last,
               "Reduced Motion must share the certified end state")
        expect(probe.names == ["contact", "rest"],
               "Reduced Motion must preserve causal marker order")
    }

    private static func validateQuaternionInterpolation() {
        let start = CoinQuaternion(w: 0.0087265355, x: 0, y: 0, z: 0.9999619231)
        let end = CoinQuaternion(w: 0.0087265355, x: 0, y: 0, z: -0.9999619231)
        let midpoint = start.slerped(to: end, amount: 0.5)
        expect(abs(midpoint.norm - 1) < 0.000_001, "Slerp must retain unit length")
        expect(abs(abs(midpoint.yawRadians) - .pi) < 0.02,
               "Slerp must take the shortest arc across the ±π wrap")
    }

    private static func makePlayer(
        plan: CertifiedCoinTranscript,
        mode: TranscriptPlaybackMode,
        probe: CoinCallbackProbe
    ) -> CoinTranscriptMotionPlayer {
        guard let player = CoinTranscriptMotionPlayer(
            plan: plan,
            mode: mode,
            onContact: { probe.record("contact") },
            onRest: { probe.record("rest") },
            onCancelBeforeRelease: { probe.record("cancel") }
        ) else { fail("The admitted plan must construct a player") }
        return player
    }

    private static func loadPlan() throws -> CertifiedCoinTranscript {
        let url = repositoryRoot.appendingPathComponent("App/CertifiedCoinTranscriptSeed1441.json")
        return try CertifiedCoinTranscript.decode(Data(contentsOf: url))
    }

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("CoinMotionTranscriptTests: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
