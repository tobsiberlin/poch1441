import Foundation

/// Exact Stage-2 plan admitted by the technical and human evidence receipts.
enum CertifiedDealTranscript {
    static let sourceContractSHA256 = "8f50b68ff3141ad45f7d9eb751913c9c40af99678c15570a52821413561f6f16"

    static let plan = MotionPlaybackPlan(
        stableID: "card.deal.track-b.transcript-player.v1",
        materialFamily: .cardStock,
        worldLightID: "track-b.world-light.v1",
        durationSeconds: 0.72,
        samples: [
            MotionSample(
                normalizedTime: 0,
                position: MotionPoint(x: 0.18, y: 0.15),
                depth: 0,
                rotationDegrees: -5.2,
                curlMillimeters: 0.5,
                shadow: MotionShadowSample(
                    offset: MotionPoint(x: 0, y: 1), blurRadius: 2, opacity: 0.22
                )
            ),
            MotionSample(
                normalizedTime: 0.24,
                position: MotionPoint(x: 0.34, y: 0.30),
                depth: 0.72,
                rotationDegrees: -2.1,
                curlMillimeters: 1.2,
                shadow: MotionShadowSample(
                    offset: MotionPoint(x: 5, y: 9), blurRadius: 11, opacity: 0.15
                )
            ),
            MotionSample(
                normalizedTime: 0.55,
                position: MotionPoint(x: 0.66, y: 0.66),
                depth: 1,
                rotationDegrees: 2.4,
                curlMillimeters: 0.9,
                shadow: MotionShadowSample(
                    offset: MotionPoint(x: 8, y: 12), blurRadius: 14, opacity: 0.11
                )
            ),
            MotionSample(
                normalizedTime: 0.75,
                position: MotionPoint(x: 0.84, y: 0.82),
                depth: 0.18,
                rotationDegrees: 0.6,
                curlMillimeters: 0.2,
                shadow: MotionShadowSample(
                    offset: MotionPoint(x: 2, y: 3), blurRadius: 5, opacity: 0.24
                )
            ),
            MotionSample(
                normalizedTime: 0.90,
                position: MotionPoint(x: 0.89, y: 0.855),
                depth: 0.07,
                rotationDegrees: -0.35,
                curlMillimeters: 0.08,
                shadow: MotionShadowSample(
                    offset: MotionPoint(x: 1, y: 2), blurRadius: 3, opacity: 0.26
                )
            ),
            MotionSample(
                normalizedTime: 1,
                position: MotionPoint(x: 0.90, y: 0.86),
                depth: 0,
                rotationDegrees: 0,
                curlMillimeters: 0,
                shadow: MotionShadowSample(
                    offset: MotionPoint(x: 0, y: 1), blurRadius: 2, opacity: 0.28
                )
            ),
        ],
        contact: MotionContactMarker(
            sampleIndex: 3,
            timeSeconds: 0.54,
            surfaceID: "track-b.center-well"
        ),
        restWindow: MotionRestWindow(
            startTimeSeconds: 0.72,
            minimumDurationSeconds: 0.18
        ),
        cancelPolicy: .committedFlight
    )

    /// No release build can select this route. Stage 3 is a launch-argument gate
    /// for one deterministic debug seed while ImpactFlight remains the default.
    static var requestedDebugMode: TranscriptPlaybackMode? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-transcriptDealReducedMotionQA") {
            return .reducedMotion
        }
        if arguments.contains("-transcriptDealQA") {
            return .standard
        }
        #endif
        return nil
    }
}
