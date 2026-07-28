import XCTest
import UIKit
@testable import CardMotionNativeSpike

final class CardMotionPlanTests: XCTestCase {
    func testCopiedProductionAssetsAreCompiledIntoTheBundle() {
        XCTAssertNotNil(UIImage(named: "W2Damage"))
        XCTAssertNotNil(UIImage(named: "V10HeartsAce"))
    }

    func testEverySegmentHasItsOwnPlan() {
        let layout = fixtureLayout
        for segment in CardMotionSegment.allCases {
            XCTAssertEqual(layout.plan(for: segment)?.segment, segment)
        }
    }

    func testDealExtractsExactlyFromDeckTopAndLandsExactlyInHandSlot() throws {
        let layout = fixtureLayout
        let plan = try XCTUnwrap(layout.plan(for: .deal))
        XCTAssertEqual(plan.sample(progress: 0).cardPose, layout.deckTop)
        XCTAssertEqual(plan.sample(progress: 1).cardPose, layout.handSlot)
    }

    func testDealAndPlayEndpointsMatchAcrossEveryEvidenceViewport() throws {
        let viewports = [(390.0, 844.0), (667.0, 375.0), (402.0, 874.0)]
        for viewport in viewports {
            let layout = CardMotionLayout(width: viewport.0, height: viewport.1)
            let deal = try XCTUnwrap(layout.plan(for: .deal))
            let play = try XCTUnwrap(layout.plan(for: .play))
            XCTAssertEqual(deal.sample(progress: 0).cardPose, layout.deckTop)
            XCTAssertEqual(deal.sample(progress: 1).cardPose, layout.handSlot)
            XCTAssertEqual(play.sample(progress: 0).cardPose, layout.handSlot)
            XCTAssertEqual(play.sample(progress: 1).cardPose, layout.playTarget)
        }
    }

    func testRevealRemainsInHandSlotAndOnlyChangesSurface() throws {
        let layout = fixtureLayout
        let plan = try XCTUnwrap(layout.plan(for: .reveal))
        let start = plan.sample(progress: 0)
        let end = plan.sample(progress: 1)
        XCTAssertEqual(start.cardPose, layout.handSlot)
        XCTAssertEqual(end.cardPose, layout.handSlot)
        XCTAssertEqual(start.surface, .reveal(progress: 0))
        XCTAssertEqual(end.surface, .reveal(progress: 1))
    }

    func testPlayStartsExactlyInHandSlotAndLandsExactlyInTargetPose() throws {
        let layout = fixtureLayout
        let plan = try XCTUnwrap(layout.plan(for: .play))
        XCTAssertEqual(plan.sample(progress: 0).cardPose, layout.handSlot)
        XCTAssertEqual(plan.sample(progress: 1).cardPose, layout.playTarget)
    }

    func testReturnStartsAtExactInterruptedPlayPoseAndEndsInHand() throws {
        let layout = fixtureLayout
        let interruption = 0.58
        let play = try XCTUnwrap(layout.plan(for: .play))
        let returnPlan = try XCTUnwrap(layout.plan(for: .return, interruptionProgress: interruption))
        XCTAssertEqual(returnPlan.sample(progress: 0).cardPose, play.sample(progress: interruption).cardPose)
        XCTAssertEqual(returnPlan.sample(progress: 0).groundPose, play.sample(progress: interruption).groundPose)
        XCTAssertEqual(returnPlan.sample(progress: 1).cardPose, layout.handSlot)
    }

    func testReturnCannotBeCreatedAtOrAfterContact() {
        let layout = fixtureLayout
        XCTAssertNil(layout.plan(for: .return, interruptionProgress: 1))
        XCTAssertNil(layout.plan(for: .return, interruptionProgress: 1.1))
    }

    func testGroundProjectionIsLinearCardShapedAndNeverRotates() throws {
        let layout = fixtureLayout
        for segment in [CardMotionSegment.deal, .play, .return] {
            let plan = try XCTUnwrap(layout.plan(for: segment))
            let first = plan.sample(progress: 0).groundPose.center
            let last = plan.sample(progress: 1).groundPose.center
            let vectorX = last.x - first.x
            let vectorY = last.y - first.y
            for index in 0...1_000 {
                let sample = plan.sample(progress: Double(index) / 1_000)
                let offsetX = sample.groundPose.center.x - first.x
                let offsetY = sample.groundPose.center.y - first.y
                XCTAssertEqual(vectorX * offsetY - vectorY * offsetX, 0, accuracy: 0.01)
                XCTAssertEqual(sample.shadowRotationDegrees, 0)
                XCTAssertGreaterThan(sample.shadowWidthScale, sample.shadowLengthScale)
            }
        }
    }

    func testShadowSoftensAndLightensWithHeight() throws {
        let plan = try XCTUnwrap(fixtureLayout.plan(for: .play))
        let contact = plan.sample(progress: 0)
        let apex = plan.sample(progress: 0.5)
        XCTAssertGreaterThan(apex.shadowBlur, contact.shadowBlur)
        XCTAssertLessThan(apex.shadowOpacity, contact.shadowOpacity)
        XCTAssertGreaterThan(apex.shadowWidthScale, contact.shadowWidthScale)
        XCTAssertGreaterThan(apex.shadowLengthScale, contact.shadowLengthScale)
    }

    func testShadowRendererUsesNoCircularPrimitive() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/CardMotionFlight.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("PerspectiveCardFootprint"))
        XCTAssertFalse(source.contains("Ellipse("))
        XCTAssertFalse(source.contains("Circle("))
    }

    func testContactGenerationAndCancellationContract() {
        var machine = CardMotionStateMachine()
        let playGeneration = machine.begin(.play(publicEventID: 7))
        let returnGeneration = machine.cancelBeforeContact(generation: playGeneration)
        XCTAssertNotNil(returnGeneration)
        XCTAssertEqual(machine.acceptContact(generation: playGeneration), .ignored)
        XCTAssertEqual(machine.emittedContactCount, 0)

        let nextPlay = machine.begin(.play(publicEventID: 8))
        XCTAssertEqual(machine.acceptContact(generation: nextPlay), .emitFeedback)
        XCTAssertEqual(machine.acceptContact(generation: nextPlay), .ignored)
        XCTAssertNil(machine.cancelBeforeContact(generation: nextPlay))
        XCTAssertEqual(machine.emittedContactCount, 1)
    }

    func testReducedMotionSettlesSilently() {
        var machine = CardMotionStateMachine()
        let generation = machine.begin(.play(publicEventID: 9))
        _ = machine.settleForReducedMotion()
        XCTAssertEqual(machine.acceptContact(generation: generation), .ignored)
        XCTAssertEqual(machine.emittedContactCount, 0)
    }

    private var fixtureLayout: CardMotionLayout {
        CardMotionLayout(width: 390, height: 844)
    }
}
