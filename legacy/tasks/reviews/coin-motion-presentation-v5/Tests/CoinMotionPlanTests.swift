import XCTest
@testable import CoinMotionPresentationV5

final class CoinMotionPlanTests: XCTestCase {
    func testTenSeedsEndInsideSafeZoneWithoutSnap() {
        for index in 0..<10 {
            let plan = CoinMotionPlan(seed: 1_441 + UInt64(index) * 97)
            XCTAssertLessThanOrEqual(plan.metrics.safeZoneDistance,
                                     CoinMotionPlan.safeZoneRadius)
            XCTAssertFalse(plan.metrics.didSnap)
            XCTAssertFalse(plan.metrics.didZeroVelocity)
            XCTAssertEqual(plan.metrics.collisionCount, 2)
        }
    }

    func testFirstContactHasPositionContinuityAndImpulseVelocityChange() {
        let plan = CoinMotionPlan(seed: 1_441)
        let epsilon = 1e-7
        let before = plan.state(at: plan.firstContactTime - epsilon)
        let contact = plan.state(at: plan.firstContactTime)
        XCTAssertEqual(before.position.x, contact.position.x, accuracy: 1e-6)
        XCTAssertEqual(before.position.y, contact.position.y, accuracy: 1e-6)
        XCTAssertLessThan(abs(before.bottomGap - contact.bottomGap), 1e-5)
        XCTAssertLessThan(before.linearVelocity.z, 0)
        XCTAssertGreaterThan(contact.linearVelocity.z, 0)
        XCTAssertLessThan(contact.linearVelocity.length, before.linearVelocity.length)
    }

    func testEnergyFallsAtFirstContactForEverySeed() {
        for index in 0..<100 {
            let plan = CoinMotionPlan(seed: UInt64(index) * 3_911 + 7)
            XCTAssertLessThan(plan.metrics.postContactEnergy,
                              plan.metrics.preContactEnergy,
                              "seed \(plan.seed)")
        }
    }

    func testNoFrameClipsFloorAcrossAllRequiredSequences() {
        for index in 0..<10 {
            let plan = CoinMotionPlan(seed: 1_441 + UInt64(index) * 97)
            for frame in 0...Int(ceil(plan.duration * 60)) {
                let state = plan.state(at: Double(frame) / 60)
                XCTAssertGreaterThanOrEqual(state.bottomGap, 0)
            }
        }
    }

    func testRestIsReachedContinuouslyByFriction() {
        let plan = CoinMotionPlan(seed: 1_441)
        let nearRest = plan.state(at: plan.restTime - 1e-6)
        let rest = plan.state(at: plan.restTime)
        XCTAssertLessThan(nearRest.linearVelocity.length, 1e-5)
        XCTAssertLessThan(nearRest.angularVelocity.length, 2e-3)
        XCTAssertEqual(nearRest.position.x, rest.position.x, accuracy: 1e-6)
        XCTAssertEqual(nearRest.position.y, rest.position.y, accuracy: 1e-6)
        XCTAssertEqual(rest.linearVelocity, .zero)
    }

    func testReducedMotionHasImmediateSemanticRestState() {
        let plan = CoinMotionPlan(seed: 1_441)
        let state = plan.state(at: 0, reducedMotion: true)
        XCTAssertEqual(state.segment, .rest)
        XCTAssertEqual(state.position, plan.target)
        XCTAssertEqual(state.linearVelocity, .zero)
        XCTAssertEqual(state.angularVelocity, .zero)
    }

    func testQuaternionIntegrationPreservesUnitLength() {
        let plan = CoinMotionPlan(seed: 1_441)
        for frame in 0...Int(ceil(plan.duration * 60)) {
            let orientation = plan.state(at: Double(frame) / 60).orientation
            let length = sqrt(orientation.w * orientation.w
                + orientation.x * orientation.x
                + orientation.y * orientation.y
                + orientation.z * orientation.z)
            XCTAssertEqual(length, 1, accuracy: 1e-9)
        }
    }
}
