import XCTest
import UIKit
@testable import CardMotionNativeSpikeV4

final class CardMotionV4Tests: XCTestCase {
    func testCurrentTrackBWorldAndCardAssetsCompile() {
        XCTAssertNotNil(UIImage(named: "TrackBWorld"))
        XCTAssertNotNil(UIImage(named: "W2Damage"))
        XCTAssertNotNil(UIImage(named: "V10HeartsAce"))
    }

    func testReturnedFaceRemainsSameFaceInRestingHandDataset() throws {
        var engine = CardMotionEngine(layout: layout, deckCount: 3, now: 0)
        let playID = engine.startPlay(at: 0)
        let cancelTime = 0.64 * 0.58
        let before = try XCTUnwrap(engine.advance(to: cancelTime).flights.first)
        let returning = try XCTUnwrap(engine.cancelPlay(flightID: playID, at: cancelTime))
        let returnStart = returning.sample(at: cancelTime)
        XCTAssertEqual(returnStart.surface, .face)
        XCTAssertEqual(returnStart.pose.center, before.pose.center)
        XCTAssertEqual(returnStart.pose.velocity.x, before.pose.velocity.x, accuracy: 0.000_001)
        XCTAssertEqual(returnStart.pose.velocity.y, before.pose.velocity.y, accuracy: 0.000_001)

        let settled = engine.advance(to: returning.endTime + 0.001)
        let handCard = try XCTUnwrap(settled.handCards.first)
        XCTAssertEqual(handCard.id, returning.id)
        XCTAssertEqual(handCard.surface, .face)
        XCTAssertEqual(handCard.center, layout.handCenter)
        XCTAssertEqual(handCard.yawDegrees, layout.handYaw)
    }

    func testShadowIsActualFourCornerProjectionAndCalibratedForTrackBTable() throws {
        let flight = try playFlight()
        let airborne = flight.sample(at: flight.startTime + flight.duration * 0.46)
        let shadow = ProjectedShadow.project(pose: airborne.pose, cardSize: layout.cardSize)
        XCTAssertEqual(shadow.points.count, 4)
        XCTAssertGreaterThan(shadow.opacity, 0.24)
        XCTAssertLessThan(shadow.opacity, 0.48)
        XCTAssertGreaterThan(shadow.blurRadius, 1.15)
        let edge = shadow.points[1] - shadow.points[0]
        XCTAssertEqual(
            atan2(edge.y, edge.x) * 180 / .pi,
            airborne.pose.yawDegrees,
            accuracy: 2.2
        )
    }

    func testAllProjectedShadowsAreBelowEveryRestingAndFlyingCard() {
        XCTAssertLessThan(CardStageLayer.projectedShadows, CardStageLayer.restingCards)
        XCTAssertLessThan(CardStageLayer.restingCards, CardStageLayer.flyingCards)
    }

    func testFirstContactProducesVisiblePoseBeatWithoutScale() throws {
        let flight = try playFlight()
        let before = flight.sample(at: flight.startTime + flight.duration - 0.001)
        let contact = flight.sample(at: flight.startTime + flight.duration)
        let rebound = flight.sample(at: flight.startTime + flight.duration + 0.020)
        XCTAssertFalse(before.hasContacted)
        XCTAssertTrue(contact.hasContacted)
        XCTAssertGreaterThan(rebound.pose.height, 3)
        XCTAssertGreaterThan((rebound.pose.center - contact.pose.center).length, 1.3)
        XCTAssertGreaterThan(abs(rebound.pose.yawDegrees - contact.pose.yawDegrees), 1.8)
        XCTAssertNotEqual(before.pose.pitchDegrees.sign, contact.pose.pitchDegrees.sign)
        XCTAssertEqual(ActiveCardFlight.settleDuration, 0.086, accuracy: 0.000_001)

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let renderer = try String(
            contentsOf: root.appendingPathComponent("Sources/CardMotionStage.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(renderer.contains("scaleEffect("))
    }

    func testEightDealsUseDistanceBased240To320MillisecondCadenceAndMaxTwoFlights() {
        var engine = CardMotionEngine(layout: layout, deckCount: 10, now: 0)
        engine.scheduleDealBurst(count: 8, at: 0)
        var releaseTimesByID: [Int: Double] = [:]
        var observedMaximum = 0
        for step in 0...320 {
            let snapshot = engine.advance(to: Double(step) / 120)
            observedMaximum = max(observedMaximum, snapshot.flights.count)
            for flight in engine.activeFlights where flight.kind == .deal {
                releaseTimesByID[flight.id] = flight.startTime
            }
        }
        let releaseTimes = releaseTimesByID.values.sorted()
        XCTAssertEqual(releaseTimes.count, 8)
        for pair in zip(releaseTimes, releaseTimes.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1 - pair.0, 0.24)
            XCTAssertLessThanOrEqual(pair.1 - pair.0, 0.32)
        }
        XCTAssertEqual(observedMaximum, 2)
        XCTAssertEqual(engine.maximumConcurrentFlights, 2)
        XCTAssertEqual(engine.handCards.count, 8)
    }

    func testDealSeedVariationIsDeterministicButNotCloned() throws {
        var first = CardMotionEngine(layout: layout, deckCount: 3, now: 0)
        var second = CardMotionEngine(layout: layout, deckCount: 3, now: 0)
        _ = first.startDeal(at: 0, seed: 2)
        _ = second.startDeal(at: 0, seed: 2)
        XCTAssertEqual(first.activeFlights, second.activeFlights)

        var third = CardMotionEngine(layout: layout, deckCount: 3, now: 0)
        _ = third.startDeal(at: 0, seed: 3)
        let seededTwo = try XCTUnwrap(first.activeFlights.first)
        let seededThree = try XCTUnwrap(third.activeFlights.first)
        XCTAssertNotEqual(seededTwo.duration, seededThree.duration)
        XCTAssertNotEqual(seededTwo.startYaw, seededThree.startYaw)
        XCTAssertNotEqual(seededTwo.path.startVelocity, seededThree.path.startVelocity)
        XCTAssertNotEqual(seededTwo.settleLift, seededThree.settleLift)
    }

    func testContactAndHapticUseSameFirstObservedWallclock() throws {
        var engine = CardMotionEngine(layout: layout, deckCount: 3, now: 9)
        _ = engine.startPlay(at: 9)
        let flight = try XCTUnwrap(engine.activeFlights.first)
        XCTAssertTrue(engine.advance(to: 9 + flight.duration - 0.000_1).contacts.isEmpty)
        let snapshot = engine.advance(to: 9 + flight.duration + 0.001)
        let contact = try XCTUnwrap(snapshot.contacts.first)
        XCTAssertEqual(contact.scheduledTime, 9 + flight.duration, accuracy: 0.000_001)
        XCTAssertEqual(contact.observedTime, contact.hapticTime, accuracy: 0.000_001)
    }

    func testEvidenceUsesMonotonicControllerWallclockAndNoSyntheticProgress() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let recorder = try String(
            contentsOf: root.appendingPathComponent("Sources/WallclockEvidenceRecorder.swift"),
            encoding: .utf8
        )
        let controller = try String(
            contentsOf: root.appendingPathComponent("Sources/CardMotionController.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(recorder.contains("syntheticProgressUsed: false"))
        XCTAssertTrue(recorder.contains("controller.synchronizeToWallclock()"))
        XCTAssertTrue(controller.contains("advance(to: CACurrentMediaTime())"))
    }

    private var layout: CardMotionLayout {
        CardMotionLayout(width: 402, height: 874)
    }

    private func playFlight() throws -> ActiveCardFlight {
        var engine = CardMotionEngine(layout: layout, deckCount: 3, now: 0)
        _ = engine.startPlay(at: 0)
        return try XCTUnwrap(engine.activeFlights.first)
    }
}
