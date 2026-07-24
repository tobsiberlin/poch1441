import Foundation

@MainActor
private final class TranscriptCallbackProbe {
    var names: [String] = []
    func record(_ name: String) { names.append(name) }
}
@main
@MainActor
struct TranscriptMotionPlayerTests {
    static func main() {
        certifiedPlanIsValid()
        standardPlaybackDeliversContactAndRestExactlyOnce()
        cancelBeforeReleasePublishesOnlyItsCallbackOnce()
        committedCancelDoesNotRewind()
        reducedMotionReachesTheSameEndSynchronously()
        eightCardScheduleNeverExceedsTwoMovingCards()
        print("TranscriptMotionPlayerTests: PASS")
    }

    private static func certifiedPlanIsValid() {
        let plan = CertifiedDealTranscript.plan
        expect(plan.isValid, "The admitted Stage-2 plan must remain valid")
        expect(plan.stableID == "card.deal.track-b.transcript-player.v1",
               "Stage 3 must use the admitted stable plan ID")
        expect(approximatelyEqual(plan.contact.timeSeconds, 0.54),
               "Contact must remain at 0.54 seconds")
        expect(approximatelyEqual(plan.restWindow.startTimeSeconds, 0.72),
               "Rest must remain at 0.72 seconds")
        expect(plan.cancelPolicy == .committedFlight,
               "The committed cancel policy must remain explicit")
    }

    private static func standardPlaybackDeliversContactAndRestExactlyOnce() {
        let probe = TranscriptCallbackProbe()
        let player = makePlayer(mode: .standard, probe: probe)

        expect(player.release(at: 100).phase == .inFlight,
               "Standard release must enter flight")
        expect(!player.advance(to: 100.539).contactDelivered,
               "Contact may not publish before its marker")
        let contact = player.advance(to: 100.54)
        expect(contact.phase == .settling && contact.isMoving,
               "Contact must begin a still-moving settle")
        expect(probe.names == ["onContact"], "Contact must publish exactly once")

        let preRest = player.advance(to: 100.719)
        expect(preRest.phase == .settling && preRest.isMoving,
               "Settle must count as movement until rest")
        let rest = player.advance(to: 100.72)
        expect(rest.phase == .resting && !rest.isMoving,
               "Rest must terminate movement")
        expect(probe.names == ["onContact", "onRest"],
               "Callbacks must preserve contact-before-rest ordering")
        _ = player.advance(to: 101.4)
        expect(probe.names == ["onContact", "onRest"],
               "Late samples must not duplicate callbacks")
    }

    private static func cancelBeforeReleasePublishesOnlyItsCallbackOnce() {
        let probe = TranscriptCallbackProbe()
        let player = makePlayer(mode: .standard, probe: probe)
        expect(player.cancel(at: 10).phase == .cancelledBeforeRelease,
               "A prepared player must cancel at its visible source")
        _ = player.cancel(at: 11)
        _ = player.release(at: 12)
        _ = player.advance(to: 13)
        expect(probe.names == ["onCancelBeforeRelease"],
               "Cancel-before-release must be terminal and exactly once")
    }

    private static func committedCancelDoesNotRewind() {
        let probe = TranscriptCallbackProbe()
        let player = makePlayer(mode: .standard, probe: probe)
        _ = player.release(at: 30)
        let cancelled = player.cancel(at: 30.22)
        expect(cancelled.committedCancelIgnored,
               "An in-flight cancel must retain the certified path")
        expect(approximatelyEqual(cancelled.elapsedSeconds, 0.22),
               "Cancel must first sample its current host time")
        let regressed = player.advance(to: 30.10)
        expect(regressed.sample == cancelled.sample,
               "A regressed host clock must not rewind the pose")
        _ = player.advance(to: 30.54)
        _ = player.advance(to: 30.72)
        expect(probe.names == ["onContact", "onRest"],
               "Committed motion must still complete both lifecycle edges")
    }

    private static func reducedMotionReachesTheSameEndSynchronously() {
        let standardProbe = TranscriptCallbackProbe()
        let standard = makePlayer(mode: .standard, probe: standardProbe)
        _ = standard.release(at: 80)
        let standardEnd = standard.advance(to: 80.72)

        let reducedProbe = TranscriptCallbackProbe()
        let reduced = makePlayer(mode: .reducedMotion, probe: reducedProbe)
        let reducedEnd = reduced.release(at: 90)
        expect(reducedEnd.phase == .resting && !reducedEnd.isMoving,
               "Reduced Motion must settle synchronously")
        expect(reducedProbe.names == ["onContact", "onRest"],
               "Reduced Motion must keep causal callbacks")
        expect(reducedEnd.sample == standardEnd.sample,
               "Standard and Reduced Motion must share the canonical end sample")
    }

    private static func eightCardScheduleNeverExceedsTwoMovingCards() {
        let count = 8
        let rhythmTargets = (0..<count).map { Double($0) * 0.32 }
        var starts: [Double] = []
        var rests: [Double] = []
        for index in 0..<count {
            let start = index < 2
                ? rhythmTargets[index]
                : max(rhythmTargets[index], rests[index - 2])
            starts.append(start)
            rests.append(start + CertifiedDealTranscript.plan.restWindow.startTimeSeconds)
        }
        guard let schedule = DealRhythmSchedule(
            rhythmTargetsSeconds: rhythmTargets,
            restWindowStartsSeconds: rests
        ) else {
            fail("Eight-card schedule must be constructible")
        }
        expect(schedule.entries.map(\.actualStartSeconds) == starts,
               "Every card must wait for card i-2 to enter rest")

        for tick in 0...Int((rests.last ?? 0) * 1_000) {
            let time = Double(tick) / 1_000
            let moving = starts.indices.filter {
                starts[$0] <= time && time < rests[$0]
            }.count
            expect(moving <= 2, "At most two cards may include flight or settle")
        }
    }

    private static func makePlayer(
        mode: TranscriptPlaybackMode,
        probe: TranscriptCallbackProbe
    ) -> TranscriptMotionPlayer {
        guard let player = TranscriptMotionPlayer(
            plan: CertifiedDealTranscript.plan,
            mode: mode,
            onContact: { probe.record("onContact") },
            onRest: { probe.record("onRest") },
            onCancelBeforeRelease: { probe.record("onCancelBeforeRelease") }
        ) else {
            fail("The admitted transcript must initialize its player")
        }
        return player
    }

    private static func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= 0.000_001
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("TranscriptMotionPlayerTests: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
