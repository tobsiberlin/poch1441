import Foundation

@main
enum MotionSyncContractTests {
    static func main() throws {
        try roundTripPreservesEventIdentityAndClockDomain()
        hapticClockBridgeUsesHostNanoseconds()
        refreshRateTrackerUsesObservedIntervalsAndConfirmsSwitches()
        frameGateUsesRateSpecificStrictP99Budgets()
        frameGateEvaluatesRateChangesAsSeparateSegments()
        frameGateRejectsMixedRatesInsideOneSegment()
        frameGateRejectsMixedOrHotOperatingConditions()
        physicalGatePassesAtInclusiveThresholds()
        physicalGateRejectsNinetyFifthPercentileRegression()
        schedulingMarkersCannotPassPhysicalGate()
        mislabeledPhysicalSourceCannotPassPhysicalGate()
        duplicatePhysicalMarkerRejectsTheEvent()
        reducedMotionUsesTheSamePhysicalThresholds()
        FileHandle.standardOutput.write(Data("MotionSyncContractTests: PASS\n".utf8))
    }

    private static func hapticClockBridgeUsesHostNanoseconds() {
        let anchor = MotionSyncHapticClockAnchor(
            hostNanosecondsAtMidpoint: 5_000_000_000,
            hapticEngineSeconds: 12.5
        )
        expect(
            anchor.hostNanoseconds(forHapticEngineSeconds: 12.516) == 5_016_000_000,
            "Haptic engine time must bridge onto the device host clock"
        )
        expect(
            anchor.hostNanoseconds(forHapticEngineSeconds: 12.48) == 4_980_000_000,
            "The clock bridge must also support events before its anchor"
        )
    }

    private static func refreshRateTrackerUsesObservedIntervalsAndConfirmsSwitches() {
        var tracker = MotionSyncRefreshRateTracker(confirmationCount: 3)
        expect(tracker.observe(displayIntervalNanoseconds: 8_333_333) == nil,
               "One interval must not establish an active refresh rate")
        expect(tracker.observe(displayIntervalNanoseconds: 8_333_333) == nil,
               "Two intervals must not establish an active refresh rate")
        expect(
            tracker.observe(displayIntervalNanoseconds: 8_333_333)
                == MotionSyncRefreshDecision(activeRefreshHertz: 120, startsNewSegment: true),
            "Three observed 120 Hz intervals must open the first segment"
        )
        expect(
            tracker.observe(displayIntervalNanoseconds: 8_400_000)
                == MotionSyncRefreshDecision(activeRefreshHertz: 120, startsNewSegment: false),
            "Small measured jitter must remain in the active segment"
        )
        expect(tracker.observe(displayIntervalNanoseconds: 12_500_000) == nil,
               "A single slower frame must not masquerade as a rate switch")
        expect(tracker.observe(displayIntervalNanoseconds: 12_500_000) == nil,
               "A rate switch requires confirmation")
        expect(
            tracker.observe(displayIntervalNanoseconds: 12_500_000)
                == MotionSyncRefreshDecision(activeRefreshHertz: 80, startsNewSegment: true),
            "Confirmed observed 80 Hz intervals must start a new segment"
        )
        expect(tracker.observe(displayIntervalNanoseconds: 20_000_000) == nil,
               "Unsupported measured rates must remain unclassified")
    }

    private static func frameGateUsesRateSpecificStrictP99Budgets() {
        let passing = [
            frameSamples(segment: 0, rate: 120, durationMilliseconds: 8.2),
            frameSamples(segment: 1, rate: 80, durationMilliseconds: 12.4),
            frameSamples(segment: 2, rate: 60, durationMilliseconds: 16.6)
        ].flatMap { $0 }
        let passResults = MotionSyncFrameEvaluator.evaluate(passing)
        expect(passResults.count == 3 && passResults.allSatisfy(\.passes),
               "Every supported refresh tier must pass below its strict p99 budget")

        let exactThreshold = frameSamples(
            segment: 0,
            rate: 120,
            durationMilliseconds: 8.33
        )
        let blocked = MotionSyncFrameEvaluator.evaluate(exactThreshold)
        expect(blocked.count == 1 && !blocked[0].passesFrameTime,
               "The 120 Hz gate is strict: 8.33 ms is not less than 8.33 ms")
    }

    private static func frameGateEvaluatesRateChangesAsSeparateSegments() {
        let first = frameSamples(
            segment: 4,
            rate: 120,
            durationMilliseconds: 8,
            lowPowerMode: false,
            thermal: .nominal
        )
        let second = frameSamples(
            segment: 5,
            rate: 80,
            durationMilliseconds: 12,
            lowPowerMode: true,
            thermal: .fair
        )
        let results = MotionSyncFrameEvaluator.evaluate(first + second)
        expect(results.map(\.measuredRefreshHertz) == [120, 80],
               "A measured rate change must produce separately evaluated segments")
        expect(results[0].lowPowerModeStates == [false],
               "The first segment must preserve its Low Power metadata")
        expect(results[1].lowPowerModeStates == [true] && results[1].thermalStates == [.fair],
               "The second segment must preserve changed operating conditions")
    }

    private static func frameGateRejectsMixedRatesInsideOneSegment() {
        let mixed = frameSamples(segment: 0, rate: 120, durationMilliseconds: 7)
            + frameSamples(segment: 0, rate: 80, durationMilliseconds: 7)
        let result = MotionSyncFrameEvaluator.evaluate(mixed)
        expect(result.count == 1 && !result[0].hasConsistentRate && !result[0].passes,
               "The recorder must not hide a refresh-rate switch inside one segment")
    }

    private static func frameGateRejectsMixedOrHotOperatingConditions() {
        let mixed = frameSamples(
            segment: 0,
            rate: 60,
            durationMilliseconds: 10,
            lowPowerMode: false,
            count: 60
        ) + frameSamples(
            segment: 0,
            rate: 60,
            durationMilliseconds: 10,
            lowPowerMode: true,
            count: 60
        )
        let mixedResult = MotionSyncFrameEvaluator.evaluate(mixed)
        expect(!mixedResult[0].hasConsistentOperatingConditions && !mixedResult[0].passes,
               "Low Power or thermal changes must not be hidden inside one segment")

        let hot = frameSamples(
            segment: 1,
            rate: 60,
            durationMilliseconds: 10,
            thermal: .serious
        )
        let hotResult = MotionSyncFrameEvaluator.evaluate(hot)
        expect(!hotResult[0].hasMeasurableThermalState && !hotResult[0].passes,
               "Serious or critical thermal state must not produce a release pass")
    }

    private static func roundTripPreservesEventIdentityAndClockDomain() throws {
        let observation = makeObservation(
            event: "coin-17",
            variant: .reducedMotion,
            marker: .simulationContact,
            domain: .deviceHost,
            timestamp: 123_456_789,
            source: .hostClock
        )
        let data = try JSONEncoder().encode(observation)
        let replay = try JSONDecoder().decode(MotionSyncObservation.self, from: data)
        expect(replay == observation, "JSON round-trip changed the event contract")
        expect(replay.clockDomain == .deviceHost, "Clock domains must survive evidence export")
    }

    private static func physicalGatePassesAtInclusiveThresholds() {
        var observations: [MotionSyncObservation] = []
        for index in 0..<30 {
            observations += physicalTriplet(
                event: "coin-\(index)",
                variant: .standard,
                visual: 1_000_000_000,
                audioDeltaMilliseconds: index >= 28 ? 16.7 : 8,
                hapticDeltaMilliseconds: index >= 28 ? 20 : 10
            )
        }

        let result = MotionSyncEvaluator.evaluatePhysicalCapture(observations)
        expect(result.completeEventCount == 30, "All complete events must be measured")
        expect(result.audioToImageP95Milliseconds == 16.7, "Audio p95 must use nearest rank")
        expect(result.hapticToImageP95Milliseconds == 20, "Haptic p95 must use nearest rank")
        expect(result.passes, "Inclusive production thresholds should pass")
    }

    private static func physicalGateRejectsNinetyFifthPercentileRegression() {
        var observations: [MotionSyncObservation] = []
        for index in 0..<30 {
            observations += physicalTriplet(
                event: "card-\(index)",
                variant: .standard,
                visual: 2_000_000_000,
                audioDeltaMilliseconds: index >= 28 ? 18 : 7,
                hapticDeltaMilliseconds: index >= 28 ? 24 : 9
            )
        }

        let result = MotionSyncEvaluator.evaluatePhysicalCapture(observations)
        expect(!result.passesAudio, "A p95 audio regression must block")
        expect(!result.passesHaptic, "A p95 haptic regression must block")
        expect(!result.passes, "Either physical regression must block the combined gate")
    }

    private static func schedulingMarkersCannotPassPhysicalGate() {
        let diagnostics = [
            makeObservation(marker: .simulationContact, domain: .deviceHost, timestamp: 10, source: .hostClock),
            makeObservation(marker: .visualSubmitted, domain: .deviceHost, timestamp: 10, source: .displayLink),
            makeObservation(marker: .audioScheduled, domain: .deviceHost, timestamp: 10, source: .hostClock),
            makeObservation(marker: .hapticScheduled, domain: .deviceHost, timestamp: 10, source: .hapticEngine)
        ]
        let result = MotionSyncEvaluator.evaluatePhysicalCapture(diagnostics, minimumSampleCount: 1)
        expect(!result.passes, "Perfect scheduling telemetry is not proof of physical synchrony")
    }

    private static func mislabeledPhysicalSourceCannotPassPhysicalGate() {
        var observations = physicalTriplet(
            event: "wrong-source",
            variant: .standard,
            visual: 1_000_000_000,
            audioDeltaMilliseconds: 5,
            hapticDeltaMilliseconds: 5
        )
        let mislabeled = observations[2]
        observations[2] = MotionSyncObservation(
            runID: mislabeled.runID,
            eventID: mislabeled.eventID,
            generation: mislabeled.generation,
            object: mislabeled.object,
            variant: mislabeled.variant,
            marker: mislabeled.marker,
            clockDomain: mislabeled.clockDomain,
            timestampNanoseconds: mislabeled.timestampNanoseconds,
            source: .hostClock
        )
        let result = MotionSyncEvaluator.evaluatePhysicalCapture(observations, minimumSampleCount: 1)
        expect(!result.passes, "A software source must not masquerade as physical evidence")
        expect(result.rejectedEventCount == 1, "Mislabeled evidence must remain visible")
    }

    private static func duplicatePhysicalMarkerRejectsTheEvent() {
        var observations = physicalTriplet(
            event: "duplicate",
            variant: .standard,
            visual: 1_000_000_000,
            audioDeltaMilliseconds: 5,
            hapticDeltaMilliseconds: 5
        )
        observations.append(observations[0])
        let result = MotionSyncEvaluator.evaluatePhysicalCapture(observations, minimumSampleCount: 1)
        expect(result.completeEventCount == 0, "Ambiguous physical evidence must not be averaged")
        expect(result.rejectedEventCount == 1, "The ambiguous event must be reported")
    }

    private static func reducedMotionUsesTheSamePhysicalThresholds() {
        let observations = physicalTriplet(
            event: "reduced",
            variant: .reducedMotion,
            visual: 1_000_000_000,
            audioDeltaMilliseconds: 16,
            hapticDeltaMilliseconds: 19
        )
        let result = MotionSyncEvaluator.evaluatePhysicalCapture(observations, minimumSampleCount: 1)
        expect(result.passes, "Reduced motion changes choreography, not causal synchrony")
    }

    private static func physicalTriplet(
        event: String,
        variant: MotionSyncMotionVariant,
        visual: UInt64,
        audioDeltaMilliseconds: Double,
        hapticDeltaMilliseconds: Double
    ) -> [MotionSyncObservation] {
        [
            makeObservation(
                event: event,
                variant: variant,
                marker: .physicalVisualContact,
                domain: .externalCapture,
                timestamp: visual,
                source: .highSpeedVideo
            ),
            makeObservation(
                event: event,
                variant: variant,
                marker: .physicalAudioOnset,
                domain: .externalCapture,
                timestamp: visual + nanoseconds(audioDeltaMilliseconds),
                source: .acousticMicrophone
            ),
            makeObservation(
                event: event,
                variant: variant,
                marker: .physicalHapticOnset,
                domain: .externalCapture,
                timestamp: visual + nanoseconds(hapticDeltaMilliseconds),
                source: .contactMicrophone
            )
        ]
    }

    private static func nanoseconds(_ milliseconds: Double) -> UInt64 {
        UInt64((milliseconds * 1_000_000).rounded())
    }

    private static func frameSamples(
        segment: Int,
        rate: Int,
        durationMilliseconds: Double,
        lowPowerMode: Bool = false,
        thermal: MotionSyncThermalState = .nominal,
        count: Int = 120
    ) -> [MotionSyncFrameSample] {
        let interval: UInt64
        switch rate {
        case 120: interval = 8_333_333
        case 80: interval = 12_500_000
        default: interval = 16_666_667
        }
        return (0..<count).map { frame in
            MotionSyncFrameSample(
                runID: "frame-run",
                segmentIndex: segment,
                frameIndex: frame,
                displayTimestampNanoseconds: UInt64(frame) * interval,
                observedDisplayIntervalNanoseconds: interval,
                renderDurationNanoseconds: nanoseconds(durationMilliseconds),
                measuredRefreshHertz: rate,
                lowPowerModeEnabled: lowPowerMode,
                thermalState: thermal
            )
        }
    }

    private static func makeObservation(
        event: String = "event-1",
        variant: MotionSyncMotionVariant = .standard,
        marker: MotionSyncMarkerKind,
        domain: MotionSyncClockDomain,
        timestamp: UInt64,
        source: MotionSyncEvidenceSource
    ) -> MotionSyncObservation {
        MotionSyncObservation(
            runID: "run-1",
            eventID: event,
            generation: 1,
            object: event.hasPrefix("card") ? .card : .coin,
            variant: variant,
            marker: marker,
            clockDomain: domain,
            timestampNanoseconds: timestamp,
            source: source
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("MotionSyncContractTests: FAIL - \(message)\n".utf8))
            exit(1)
        }
    }
}
