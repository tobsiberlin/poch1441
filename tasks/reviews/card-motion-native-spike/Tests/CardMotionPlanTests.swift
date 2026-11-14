import XCTest
import UIKit
@testable import CardMotionNativeSpike

final class CardMotionPlanTests: XCTestCase {
    func testCopiedProductionAssetsAreCompiledIntoTheBundle() {
        XCTAssertNotNil(UIImage(named: "W2Damage"))
        XCTAssertNotNil(UIImage(named: "V10HeartsAce"))
    }

    func testAllowedStateTransitionsAndIllegalReturnAfterSettlement() {
        XCTAssertTrue(CardMotionStateMachine.allows(from: .idle, to: .deal(sequence: 1)))
        XCTAssertTrue(CardMotionStateMachine.allows(from: .deal(sequence: 1), to: .fan(slot: 0)))
        XCTAssertTrue(CardMotionStateMachine.allows(from: .fan(slot: 0), to: .reveal(publicEventID: 7)))
        XCTAssertTrue(CardMotionStateMachine.allows(from: .fan(slot: 0), to: .play(publicEventID: 7)))
        XCTAssertTrue(CardMotionStateMachine.allows(
            from: .play(publicEventID: 7),
            to: .return(reason: .cancelledBeforeContact)
        ))
        XCTAssertFalse(CardMotionStateMachine.allows(
            from: .settled(container: .table, slot: 0),
            to: .return(reason: .cancelledBeforeContact)
        ))
        XCTAssertFalse(CardMotionStateMachine.allows(from: .deal(sequence: 1), to: .reveal(publicEventID: 7)))
    }

    func testContactEmitsExactlyOnceAndStaleGenerationIsIgnored() {
        var machine = CardMotionStateMachine()
        let generation = machine.begin(.play(publicEventID: 9))

        XCTAssertEqual(machine.acceptContact(generation: generation), .emitFeedback)
        XCTAssertEqual(machine.acceptContact(generation: generation), .ignored)
        XCTAssertEqual(machine.emittedContactCount, 1)

        let nextGeneration = machine.begin(.play(publicEventID: 10))
        XCTAssertEqual(machine.acceptContact(generation: generation), .ignored)
        XCTAssertEqual(machine.acceptContact(generation: nextGeneration), .emitFeedback)
        XCTAssertEqual(machine.emittedContactCount, 2)
    }

    func testCancellationInvalidatesOldContactAndReturnsToFan() {
        var machine = CardMotionStateMachine()
        let playGeneration = machine.begin(.play(publicEventID: 11))
        let returnGeneration = machine.cancelBeforeContact(generation: playGeneration)

        XCTAssertNotNil(returnGeneration)
        XCTAssertEqual(machine.phase, .return(reason: .cancelledBeforeContact))
        XCTAssertEqual(machine.acceptContact(generation: playGeneration), .ignored)
        XCTAssertEqual(machine.emittedContactCount, 0)
        XCTAssertTrue(machine.transition(to: .fan(slot: 0), generation: returnGeneration ?? -1))
    }

    func testReducedMotionSettlesSilentlyAndInvalidatesOldGeneration() {
        var machine = CardMotionStateMachine()
        let generation = machine.begin(.play(publicEventID: 12))
        let settledGeneration = machine.settleForReducedMotion()

        XCTAssertGreaterThan(settledGeneration, generation)
        XCTAssertEqual(machine.phase, .settled(container: .table, slot: 0))
        XCTAssertEqual(machine.acceptContact(generation: generation), .ignored)
        XCTAssertEqual(machine.emittedContactCount, 0)
    }

    func testGroundProjectionIsLinearAndNeverRotates() {
        let plan = fixturePlan
        let start = plan.start
        let end = plan.end
        let vectorX = end.x - start.x
        let vectorY = end.y - start.y

        for index in 0...1_000 {
            let sample = plan.sample(progress: Double(index) / 1_000)
            let offsetX = sample.groundPoint.x - start.x
            let offsetY = sample.groundPoint.y - start.y
            let crossProduct = vectorX * offsetY - vectorY * offsetX
            XCTAssertEqual(crossProduct, 0, accuracy: 0.01)
            XCTAssertEqual(sample.shadowRotationDegrees, 0)
        }
    }

    func testCardArcSharesEndpointsAndSeparatesAtApex() {
        let plan = fixturePlan
        let start = plan.sample(progress: 0)
        let apex = plan.sample(progress: 0.5)
        let end = plan.sample(progress: 1)

        XCTAssertEqual(start.cardPoint.x, plan.start.x, accuracy: 0.01)
        XCTAssertEqual(start.cardPoint.y, plan.start.y, accuracy: 0.01)
        XCTAssertEqual(end.cardPoint.x, plan.end.x, accuracy: 0.01)
        XCTAssertEqual(end.cardPoint.y, plan.end.y, accuracy: 0.01)
        XCTAssertGreaterThan(apex.groundPoint.y - apex.cardPoint.y, 40)
        XCTAssertLessThan(apex.shadowOpacity, start.shadowOpacity)
    }

    func testReturnUsesTheSameEndpointsInReverse() {
        let outbound = fixturePlan
        let inbound = outbound.reversed

        XCTAssertEqual(inbound.sample(progress: 0).cardPoint, outbound.sample(progress: 1).cardPoint)
        XCTAssertEqual(inbound.sample(progress: 1).cardPoint, outbound.sample(progress: 0).cardPoint)
        XCTAssertEqual(inbound.sample(progress: 0).groundPoint, outbound.sample(progress: 1).groundPoint)
        XCTAssertEqual(inbound.sample(progress: 1).groundPoint, outbound.sample(progress: 0).groundPoint)
    }

    private var fixturePlan: CardMotionPlan {
        CardMotionPlan(
            start: MotionPoint(x: 60, y: 120),
            end: MotionPoint(x: 320, y: 620),
            arcHeight: 96,
            lateralBias: 18,
            startRotationDegrees: -7,
            endRotationDegrees: 9
        )
    }
}
