import Foundation

@MainActor
private final class ContactCueOutputSpy: MotionContactCueOutput {
    var prepared = 0
    var scheduled: [MotionContactCue] = []
    var cancelled: [CoinTransferIdentity] = []

    func prepare() { prepared += 1 }
    func schedule(_ cue: MotionContactCue) { scheduled.append(cue) }
    func cancel(identity: CoinTransferIdentity) { cancelled.append(identity) }
}

@main
@MainActor
struct MotionContactCueTests {
    static func main() throws {
        exactOnceScheduleAndContact()
        staleAndDuplicateCuesAreInert()
        cancelBeforeContactCancelsBothOutputsOnce()
        contactMakesLaterCancelInert()
        settingsStayOnTheSingleCue()
        print("MotionContactCueTests: PASS")
    }

    private static func exactOnceScheduleAndContact() {
        let spy = ContactCueOutputSpy()
        let coordinator = MotionContactCueCoordinator(output: spy)
        try? coordinator.prepare()
        let cue = makeCue()
        expect((try? coordinator.schedule(cue)) == .accepted, "First cue must schedule")
        expect(spy.prepared == 1 && spy.scheduled == [cue], "One prepared output receives one cue")
        expect(coordinator.markContact(identity: cue.identity) == .accepted,
               "The matching contact must be accepted")
        expect(coordinator.markContact(identity: cue.identity) == .alreadyContacted,
               "Duplicate contact must be inert")
    }

    private static func staleAndDuplicateCuesAreInert() {
        let spy = ContactCueOutputSpy()
        let coordinator = MotionContactCueCoordinator(output: spy)
        let cue = makeCue()
        expect((try? coordinator.schedule(cue)) == .accepted, "First cue must schedule")
        expect((try? coordinator.schedule(cue)) == .duplicate, "Duplicate schedule must be rejected")
        let stale = makeCue(generation: cue.identity.generation + 1)
        expect((try? coordinator.schedule(stale)) == .stale, "A different generation must be stale")
        expect(spy.scheduled.count == 1, "Rejected cues cannot reach physical outputs")
    }

    private static func cancelBeforeContactCancelsBothOutputsOnce() {
        let spy = ContactCueOutputSpy()
        let coordinator = MotionContactCueCoordinator(output: spy)
        let cue = makeCue()
        _ = try? coordinator.schedule(cue)
        expect(coordinator.cancelBeforeContact(identity: cue.identity) == .accepted,
               "A pre-contact teardown must cancel")
        expect(spy.cancelled == [cue.identity], "Physical outputs must cancel exactly once")
        expect(coordinator.cancelBeforeContact(identity: cue.identity) == .cancelled,
               "Repeated cancellation must be inert")
        expect(spy.cancelled.count == 1, "No duplicate physical cancellation")
    }

    private static func contactMakesLaterCancelInert() {
        let spy = ContactCueOutputSpy()
        let coordinator = MotionContactCueCoordinator(output: spy)
        let cue = makeCue()
        _ = try? coordinator.schedule(cue)
        _ = coordinator.markContact(identity: cue.identity)
        expect(coordinator.cancelBeforeContact(identity: cue.identity) == .alreadyContacted,
               "Post-contact teardown cannot invent a rollback")
        expect(spy.cancelled.isEmpty, "A delivered contact cannot be physically cancelled")
    }

    private static func settingsStayOnTheSingleCue() {
        let spy = ContactCueOutputSpy()
        let coordinator = MotionContactCueCoordinator(output: spy)
        let cue = makeCue(soundEnabled: false, hapticsEnabled: true)
        _ = try? coordinator.schedule(cue)
        expect(spy.scheduled.first?.soundEnabled == false,
               "Disabled sound must remain disabled at the scheduled edge")
        expect(spy.scheduled.first?.hapticsEnabled == true,
               "Haptics must remain independently enabled")
        expect(spy.scheduled.first?.contactHostTime == cue.contactHostTime,
               "Audio and haptics must consume the same certified host tick")
    }

    private static func makeCue(generation: Int = 1_441,
                                soundEnabled: Bool = true,
                                hapticsEnabled: Bool = true) -> MotionContactCue {
        MotionContactCue(
            identity: CoinTransferIdentity(eventID: "coin-queen-drop", generation: generation),
            contactHostTime: 9_876_543,
            surfaceID: "queen-outer-well",
            audioFingerprintID: "cent-copper-polycarbonate-01",
            soundEnabled: soundEnabled,
            hapticsEnabled: hapticsEnabled
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("MotionContactCueTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
