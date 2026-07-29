import XCTest
@testable import TranscriptMotionPlayerV1

@MainActor
private final class TestCallbackProbe {
    var names: [String] = []
    func record(_ name: String) { names.append(name) }
}

@MainActor
final class TranscriptMotionPlayerV1Tests: XCTestCase {
    func testHarnessUsesOneValidCertifiedPlan() throws {
        let plan = try CertifiedTranscript.validatedPlan()
        XCTAssertTrue(plan.isValid)
        XCTAssertEqual(plan.stableID, "card.deal.track-b.transcript-player.v1")
        XCTAssertEqual(plan.contact.timeSeconds, 0.54, accuracy: 0.000_001)
        XCTAssertEqual(plan.restWindow.startTimeSeconds, 0.72, accuracy: 0.000_001)
        XCTAssertEqual(plan.cancelPolicy, .committedFlight)
    }

    func testStandardPlaybackDeliversContactAndRestExactlyOnce() throws {
        let probe = TestCallbackProbe()
        let player = try makePlayer(mode: .standard, probe: probe)

        XCTAssertEqual(player.release(at: 100).phase, .inFlight)
        let preContact = player.advance(to: 100.539)
        XCTAssertTrue(preContact.isMoving)
        XCTAssertFalse(preContact.contactDelivered)

        let contact = player.advance(to: 100.54)
        XCTAssertEqual(contact.phase, .settling)
        XCTAssertTrue(contact.isMoving)
        XCTAssertEqual(probe.names, ["onContact"])

        let preRest = player.advance(to: 100.719)
        XCTAssertEqual(preRest.phase, .settling)
        XCTAssertTrue(preRest.isMoving, "Settle must count as motion until onRest")

        let rest = player.advance(to: 100.72)
        XCTAssertEqual(rest.phase, .resting)
        XCTAssertFalse(rest.isMoving)
        XCTAssertEqual(probe.names, ["onContact", "onRest"])

        _ = player.advance(to: 101.4)
        XCTAssertEqual(probe.names, ["onContact", "onRest"])
    }

    func testCancelBeforeReleasePublishesOnlyItsCallbackOnce() throws {
        let probe = TestCallbackProbe()
        let player = try makePlayer(mode: .standard, probe: probe)

        XCTAssertEqual(player.cancel(at: 10).phase, .cancelledBeforeRelease)
        _ = player.cancel(at: 11)
        _ = player.release(at: 12)
        _ = player.advance(to: 13)

        XCTAssertEqual(probe.names, ["onCancelBeforeRelease"])
        XCTAssertFalse(player.currentSnapshot.contactDelivered)
        XCTAssertFalse(player.currentSnapshot.restDelivered)
    }

    func testCommittedInFlightCancelCompletesCertifiedPath() throws {
        let probe = TestCallbackProbe()
        let player = try makePlayer(mode: .standard, probe: probe)
        _ = player.release(at: 50)
        let beforeCancel = player.advance(to: 50.22)
        let cancelled = player.cancel(at: 50.22)

        XCTAssertTrue(cancelled.committedCancelIgnored)
        XCTAssertEqual(cancelled.phase, .inFlight)
        XCTAssertTrue(cancelled.isMoving)
        XCTAssertEqual(cancelled.elapsedSeconds, beforeCancel.elapsedSeconds, accuracy: 0.000_001)
        XCTAssertEqual(cancelled.sample, beforeCancel.sample, "Cancel at the same host time must preserve pose")
        XCTAssertEqual(probe.names, [])

        _ = player.advance(to: 50.54)
        let rest = player.advance(to: 50.72)
        XCTAssertEqual(rest.phase, .resting)
        XCTAssertFalse(rest.isMoving)
        XCTAssertEqual(probe.names, ["onContact", "onRest"])
    }

    func testCommittedCancelAdvancesMonotonicallyWithoutPriorSampling() throws {
        let probe = TestCallbackProbe()
        let player = try makePlayer(mode: .standard, probe: probe)
        _ = player.release(at: 30)

        let cancelled = player.cancel(at: 30.22)
        XCTAssertEqual(cancelled.elapsedSeconds, 0.22, accuracy: 0.000_001)
        XCTAssertGreaterThan(cancelled.sample.normalizedTime, 0)
        XCTAssertTrue(cancelled.committedCancelIgnored)

        let regressedHostTime = player.advance(to: 30.10)
        XCTAssertEqual(regressedHostTime.elapsedSeconds, cancelled.elapsedSeconds, accuracy: 0.000_001)
        XCTAssertEqual(regressedHostTime.sample, cancelled.sample, "Host-time regressions must not rewind pose")
    }

    func testReducedMotionReachesSameEndStateSynchronously() throws {
        let standardProbe = TestCallbackProbe()
        let standard = try makePlayer(mode: .standard, probe: standardProbe)
        _ = standard.release(at: 80)
        let standardEnd = standard.advance(to: 80.72)

        let reducedProbe = TestCallbackProbe()
        let reduced = try makePlayer(mode: .reducedMotion, probe: reducedProbe)
        let reducedEnd = reduced.release(at: 90)

        XCTAssertEqual(reducedEnd.phase, .resting)
        XCTAssertFalse(reducedEnd.isMoving)
        XCTAssertEqual(reducedProbe.names, ["onContact", "onRest"])
        XCTAssertEqual(reducedEnd.sample, standardEnd.sample)
    }

    func testInterpolationIsRendererNeutralAndFinite() throws {
        let probe = TestCallbackProbe()
        let player = try makePlayer(mode: .standard, probe: probe)
        _ = player.release(at: 0)
        let snapshot = player.advance(to: 0.36)

        XCTAssertEqual(snapshot.sample.normalizedTime, 0.5, accuracy: 0.000_001)
        XCTAssertTrue(snapshot.sample.isValid)
        XCTAssertGreaterThan(snapshot.sample.position.x, 0.34)
        XCTAssertLessThan(snapshot.sample.position.x, 0.66)
    }

    private func makePlayer(
        mode: TranscriptPlaybackMode,
        probe: TestCallbackProbe
    ) throws -> TranscriptMotionPlayer {
        let plan = try CertifiedTranscript.validatedPlan()
        return try XCTUnwrap(TranscriptMotionPlayer(
            plan: plan,
            mode: mode,
            onContact: { probe.record("onContact") },
            onRest: { probe.record("onRest") },
            onCancelBeforeRelease: { probe.record("onCancelBeforeRelease") }
        ))
    }
}
