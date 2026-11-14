import Foundation

@main
struct MotionPlaybackPlanTests {
    static func main() throws {
        try canonicalSerializationReplaysByteForByte()
        atLeastNineVariantsAvoidRepeatsAcrossEightTransfers()
        invalidPlansAndBucketsFailClosed()
        dealRhythmWaitsForTheCardTwoPlacesBefore()
        sourceRemainsRuleNeutral()
        FileHandle.standardOutput.write(Data("MotionPlaybackPlanTests: PASS\n".utf8))
    }

    private static func canonicalSerializationReplaysByteForByte() throws {
        let bucket = makeBucket()
        let first = MotionVariantSelector.selections(from: bucket, seed: 1_441, count: 32)
        let replay = MotionVariantSelector.selections(from: bucket, seed: 1_441, count: 32)
        expect(first == replay, "The same seed must select the same plans")
        try expect(
            try MotionTranscriptCodec.encode(first) == MotionTranscriptCodec.encode(replay),
            "The same selection must serialize byte-for-byte"
        )
        let decoded = try MotionTranscriptCodec.decode(
            [MotionVariantSelection].self,
            from: MotionTranscriptCodec.encode(first)
        )
        expect(decoded == first, "Canonical transcript data must round-trip")
    }

    private static func atLeastNineVariantsAvoidRepeatsAcrossEightTransfers() {
        let bucket = makeBucket()
        expect(bucket.isValid, "A nine-variant bucket must pass validation")
        let selections = MotionVariantSelector.selections(from: bucket, seed: .max, count: 90)
        expect(selections.count == 90, "A valid bucket must satisfy the requested count")

        for start in 0...(selections.count - 8) {
            let window = selections[start..<(start + 8)].map(\.plan.stableID)
            expect(Set(window).count == 8,
                   "No exact plan may repeat inside eight consecutive transfers")
        }
    }

    private static func invalidPlansAndBucketsFailClosed() {
        let valid = makePlan(index: 0)
        expect(valid.isValid, "The fixture plan must be valid")

        let invalid = MotionPlaybackPlan(
            stableID: "invalid",
            materialFamily: .cardStock,
            worldLightID: "track-b",
            durationSeconds: 1,
            samples: valid.samples,
            contact: MotionContactMarker(sampleIndex: 8, timeSeconds: 0.5, surfaceID: "well"),
            restWindow: valid.restWindow,
            cancelPolicy: .committedFlight
        )
        expect(!invalid.isValid, "An out-of-range contact sample must fail closed")

        let undersized = MotionVariantBucket(
            stableID: "card.deal",
            plans: (0..<8).map(makePlan)
        )
        expect(!undersized.isValid, "Every selection bucket needs at least nine variants")
        expect(
            MotionVariantSelector.selections(from: undersized, seed: 1, count: 8).isEmpty,
            "An invalid bucket must not emit a partial schedule"
        )
    }

    private static func dealRhythmWaitsForTheCardTwoPlacesBefore() {
        let schedule = DealRhythmSchedule(
            rhythmTargetsSeconds: [0, 0.18, 0.34, 0.50, 0.66],
            restWindowStartsSeconds: [0.42, 0.57, 0.81, 0.95, 1.12]
        )
        expect(schedule?.entries.map(\.actualStartSeconds) == [0, 0.18, 0.42, 0.57, 0.81],
               "actualStart(i) must wait for restWindowStart(i-2)")
        expect(
            DealRhythmSchedule(
                rhythmTargetsSeconds: [0, .infinity],
                restWindowStartsSeconds: [0.2, 0.4]
            ) == nil,
            "Non-finite schedule data must fail closed"
        )
    }

    private static func sourceRemainsRuleNeutral() {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/MotionPlaybackPlan.swift")
        guard let source = try? String(contentsOf: sourceURL, encoding: .utf8) else {
            fail("MotionPlaybackPlan.swift must be readable")
        }
        expect(!source.contains("import PochKit"), "Transcript data must not import PochKit")
        expect(!source.contains("GameState"), "Transcript data must not depend on GameState")
        expect(!source.contains("SwiftUI"), "Transcript data must not depend on a renderer")
    }

    private static func makeBucket() -> MotionVariantBucket {
        MotionVariantBucket(
            stableID: "card.deal.track-b",
            plans: (0..<9).map(makePlan)
        )
    }

    private static func makePlan(index: Int) -> MotionPlaybackPlan {
        let rotation = Double(index) * 0.25
        return MotionPlaybackPlan(
            stableID: "card.deal.track-b.\(index)",
            materialFamily: .cardStock,
            worldLightID: "track-b.world-light.v1",
            durationSeconds: 1,
            samples: [
                MotionSample(
                    normalizedTime: 0,
                    position: MotionPoint(x: 0, y: 0),
                    depth: 0,
                    rotationDegrees: rotation,
                    curlMillimeters: 1.1,
                    shadow: MotionShadowSample(
                        offset: MotionPoint(x: 0, y: 1),
                        blurRadius: 2,
                        opacity: 0.2
                    )
                ),
                MotionSample(
                    normalizedTime: 0.5,
                    position: MotionPoint(x: 0.6, y: 0.7),
                    depth: 1,
                    rotationDegrees: rotation + 2,
                    curlMillimeters: 0,
                    shadow: MotionShadowSample(
                        offset: MotionPoint(x: 2, y: 4),
                        blurRadius: 6,
                        opacity: 0.12
                    )
                ),
                MotionSample(
                    normalizedTime: 1,
                    position: MotionPoint(x: 1, y: 1),
                    depth: 0,
                    rotationDegrees: rotation,
                    curlMillimeters: 0,
                    shadow: MotionShadowSample(
                        offset: MotionPoint(x: 0, y: 1),
                        blurRadius: 2,
                        opacity: 0.24
                    )
                )
            ],
            contact: MotionContactMarker(sampleIndex: 1, timeSeconds: 0.5, surfaceID: "track-b.center-well"),
            restWindow: MotionRestWindow(startTimeSeconds: 0.82, minimumDurationSeconds: 0.18),
            cancelPolicy: .committedFlight
        )
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) rethrows {
        guard try condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("MotionPlaybackPlanTests: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
