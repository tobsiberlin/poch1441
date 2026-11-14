import Foundation

@main
enum DealRhythmContractTests {
    static func main() throws {
        rhythmContainsTensionAccelerationRecoveryAndRelease()
        deterministicReplayDoesNotBecomePerceptuallyUniform()
        noThreeConsecutiveRouteOrContactClassesMatch()
        try actualStartRespectsRhythmAndTwoCardsBackRestGate()
        try settleCountsAsActiveMovement()
        try adversarialDurationsNeverExceedTwoActiveCardsAtAnyRefreshRate()
        try reducedMotionHasNoInvisibleWait()
        malformedDurationsAreRejected()
        FileHandle.standardOutput.write(Data("DealRhythmContractTests: PASS\n".utf8))
    }

    private static func rhythmContainsTensionAccelerationRecoveryAndRelease() {
        for mode in [DealRhythmMode.standard, .reducedMotion] {
            let profile = DealRhythmProfile.make(dealCount: 8, seed: 1441, mode: mode)
            expect(profile.pulses.first?.phase == .tension, "The sequence must establish tension")
            expect(profile.pulses.contains { $0.phase == .acceleration },
                   "The sequence must accelerate")
            guard let recoveryIndex = profile.pulses.firstIndex(where: { $0.phase == .recovery }) else {
                fail("The sequence must contain a short recovery")
            }
            expect(profile.pulses.last?.phase == .release, "The sequence must end with release")

            let accelerated = profile.pulses.filter { $0.phase == .acceleration }
            for pair in zip(accelerated, accelerated.dropFirst()) {
                expect(pair.1.intervalFromPreviousSeconds <= pair.0.intervalFromPreviousSeconds,
                       "Acceleration intervals must contract or hold their minimum pulse")
            }
            expect(
                profile.pulses[recoveryIndex].intervalFromPreviousSeconds
                    > profile.pulses[recoveryIndex - 1].intervalFromPreviousSeconds,
                "Recovery must open a short breath after acceleration"
            )
            expect(
                profile.pulses[recoveryIndex + 1].intervalFromPreviousSeconds
                    < profile.pulses[recoveryIndex].intervalFromPreviousSeconds,
                "Release must close the recovery without dragging"
            )
        }
    }

    private static func deterministicReplayDoesNotBecomePerceptuallyUniform() {
        let first = DealRhythmProfile.make(dealCount: 8, seed: 21, mode: .standard)
        let replay = DealRhythmProfile.make(dealCount: 8, seed: 21, mode: .standard)
        let next = DealRhythmProfile.make(dealCount: 8, seed: 22, mode: .standard)
        expect(first == replay, "The same public seed must replay exactly")
        expect(first != next, "Adjacent seeds must not produce an exact perceptual replay")

        let adjacentRepeats = zip(first.pulses, first.pulses.dropFirst()).filter { lhs, rhs in
            lhs.route == rhs.route &&
                lhs.contact == rhs.contact &&
                lhs.gestureVariation == rhs.gestureVariation
        }
        expect(adjacentRepeats.isEmpty, "Adjacent deals must not repeat the complete gesture signature")

        let signatures = Set((0..<256).map { seed in
            DealRhythmProfile.make(dealCount: 8, seed: UInt64(seed), mode: .standard)
                .pulses
                .map { "\($0.route.rawValue):\($0.contact.rawValue):\($0.gestureVariation)" }
                .joined(separator: "|")
        })
        expect(signatures.count == 256, "Many seeds must not collapse into repeated choreography")
    }

    private static func noThreeConsecutiveRouteOrContactClassesMatch() {
        for seed in 0..<1_024 {
            for mode in [DealRhythmMode.standard, .reducedMotion] {
                let pulses = DealRhythmProfile.make(
                    dealCount: 12,
                    seed: UInt64(seed),
                    mode: mode
                ).pulses
                for index in 2..<pulses.count {
                    expect(
                        !(pulses[index].route == pulses[index - 1].route &&
                          pulses[index].route == pulses[index - 2].route),
                        "Three identical route classes are forbidden"
                    )
                    expect(
                        !(pulses[index].contact == pulses[index - 1].contact &&
                          pulses[index].contact == pulses[index - 2].contact),
                        "Three identical contact classes are forbidden"
                    )
                }
            }
        }
    }

    private static func actualStartRespectsRhythmAndTwoCardsBackRestGate() throws {
        let profile = DealRhythmProfile.make(dealCount: 10, seed: 91, mode: .standard)
        let durations = alternatingDurations(count: 10, mode: .standard, offset: 0)
        let schedule = try DealRhythmScheduler.schedule(profile: profile, durations: durations)

        for index in schedule.indices {
            let requiredRest = index >= 2 ? schedule[index - 2].restWindowStartSeconds : 0
            let expected = max(profile.pulses[index].targetStartSeconds, requiredRest)
            expect(equal(schedule[index].actualStartSeconds, expected),
                   "Actual start must equal max(rhythmTarget, restWindowStart two cards back)")
        }
    }

    private static func settleCountsAsActiveMovement() throws {
        let profile = DealRhythmProfile.make(dealCount: 1, seed: 7, mode: .standard)
        let duration = DealMotionDurations(
            travelSeconds: 0.30,
            contactSeconds: 0.08,
            settleSeconds: 0.14
        )
        let card = try DealRhythmScheduler.schedule(profile: profile, durations: [duration])[0]
        expect(equal(card.restWindowStartSeconds, 0.52),
               "Rest may begin only after travel, contact and settle")
        expect(card.isActive(at: 0.519_999), "Settle must still count as active movement")
        expect(!card.isActive(at: 0.52), "The half-open movement interval ends at rest")
    }

    private static func adversarialDurationsNeverExceedTwoActiveCardsAtAnyRefreshRate() throws {
        for seed in 0..<512 {
            for mode in [DealRhythmMode.standard, .reducedMotion] {
                let profile = DealRhythmProfile.make(
                    dealCount: 12,
                    seed: UInt64(seed),
                    mode: mode
                )
                for offset in 0..<4 {
                    let durations = alternatingDurations(count: 12, mode: mode, offset: offset)
                    let schedule = try DealRhythmScheduler.schedule(
                        profile: profile,
                        durations: durations
                    )
                    for refreshRate in [60, 80, 120] {
                        let step = 1 / Double(refreshRate)
                        let end = schedule.last?.restWindowStartSeconds ?? 0
                        var time = 0.0
                        while time <= end + step {
                            expect(
                                DealRhythmScheduler.activeCount(in: schedule, at: time) <= 2,
                                "At most two cards may move at \(refreshRate) Hz"
                            )
                            time += step
                        }
                    }
                }
            }
        }
    }

    private static func reducedMotionHasNoInvisibleWait() throws {
        for seed in 0..<512 {
            let profile = DealRhythmProfile.make(
                dealCount: 12,
                seed: UInt64(seed),
                mode: .reducedMotion
            )
            for offset in 0..<4 {
                let durations = alternatingDurations(
                    count: 12,
                    mode: .reducedMotion,
                    offset: offset
                )
                let schedule = try DealRhythmScheduler.schedule(
                    profile: profile,
                    durations: durations
                )
                for index in 1..<schedule.count {
                    let latestPriorRest = schedule[..<index]
                        .map(\.restWindowStartSeconds)
                        .max() ?? 0
                    expect(
                        schedule[index].actualStartSeconds <= latestPriorRest + 0.000_000_1,
                        "Reduced Motion must not retain an invisible standard-travel pause"
                    )
                }
            }
        }
    }

    private static func malformedDurationsAreRejected() {
        let profile = DealRhythmProfile.make(dealCount: 2, seed: 0, mode: .standard)
        do {
            _ = try DealRhythmScheduler.schedule(
                profile: profile,
                durations: [DealMotionDurations(
                    travelSeconds: 0.2,
                    contactSeconds: 0.08,
                    settleSeconds: 0.1
                )]
            )
            fail("Duration count mismatch must throw")
        } catch DealRhythmScheduleError.durationCountMismatch {
            // Expected.
        } catch {
            fail("Unexpected error for duration count mismatch")
        }
    }

    private static func alternatingDurations(
        count: Int,
        mode: DealRhythmMode,
        offset: Int
    ) -> [DealMotionDurations] {
        let variants: [DealMotionDurations] = switch mode {
        case .standard:
            [
                DealMotionDurations(travelSeconds: 0.28, contactSeconds: 0.06, settleSeconds: 0.10),
                DealMotionDurations(travelSeconds: 0.50, contactSeconds: 0.12, settleSeconds: 0.18),
                DealMotionDurations(travelSeconds: 0.30, contactSeconds: 0.12, settleSeconds: 0.18),
                DealMotionDurations(travelSeconds: 0.50, contactSeconds: 0.06, settleSeconds: 0.10)
            ]
        case .reducedMotion:
            [
                DealMotionDurations(travelSeconds: 0.085, contactSeconds: 0.04, settleSeconds: 0.055),
                DealMotionDurations(travelSeconds: 0.14, contactSeconds: 0.08, settleSeconds: 0.10),
                DealMotionDurations(travelSeconds: 0.085, contactSeconds: 0.08, settleSeconds: 0.10),
                DealMotionDurations(travelSeconds: 0.14, contactSeconds: 0.04, settleSeconds: 0.055)
            ]
        }
        return (0..<count).map { variants[($0 + offset) % variants.count] }
    }

    private static func equal(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= 0.000_000_001
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("DealRhythmContractTests: FAIL - \(message)\n".utf8))
        exit(1)
    }
}
