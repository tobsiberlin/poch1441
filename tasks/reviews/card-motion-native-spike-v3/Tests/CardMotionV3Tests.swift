import XCTest
import UIKit
@testable import CardMotionNativeSpikeV3

final class CardMotionV3Tests: XCTestCase {
    func testCurrentW2AndV10AssetsCompile() {
        XCTAssertNotNil(UIImage(named: "W2Damage"))
        XCTAssertNotNil(UIImage(named: "V10HeartsAce"))
    }

    func testDealRemovesActualTopCardAndLeavesExactlyTwoStaticLayers() throws {
        var engine = CardMotionEngine(layout: portrait, deckCount: 3, now: 10)
        let id = try XCTUnwrap(engine.startDeal(at: 10))
        let snapshot = engine.snapshot
        XCTAssertEqual(snapshot.deckLayerCount, 2)
        XCTAssertEqual(snapshot.flights.map(\.id), [id])
        XCTAssertEqual(snapshot.flights.first?.pose.center, portrait.deckCenter)
        XCTAssertEqual(snapshot.flights.first?.surface, .back)
    }

    func testProjectedShadowUsesRotatedActualCardContour() {
        let pose = CardPose(
            center: MotionVector(x: 180, y: 320),
            velocity: MotionVector(x: 220, y: -90),
            height: 47,
            verticalVelocity: -120,
            yawDegrees: 31,
            yawVelocity: 0,
            pitchDegrees: 10,
            pitchAxis: MotionVector(x: 0.38, y: 0.92),
            flipDegrees: 0
        )
        let projection = ProjectedShadow.project(pose: pose, cardSize: portrait.cardSize)
        XCTAssertEqual(projection.points.count, 4)
        let edge = projection.points[1] - projection.points[0]
        XCTAssertEqual(atan2(edge.y, edge.x) * 180 / .pi, 31, accuracy: 2.2)
        let bounds = projection.bounds
        XCTAssertGreaterThan(bounds.max.x - bounds.min.x, portrait.cardSize.width * 0.9)
        XCTAssertGreaterThan(bounds.max.y - bounds.min.y, portrait.cardSize.width * 0.9)
    }

    func testShadowProjectionChangesWithPitchAndHeightInsteadOfScalingBlob() {
        let base = CardPose(
            center: MotionVector(x: 200, y: 400),
            velocity: MotionVector(x: -100, y: -160),
            height: 0,
            verticalVelocity: 0,
            yawDegrees: -8,
            yawVelocity: 0,
            pitchDegrees: 0,
            pitchAxis: MotionVector(x: 0.8, y: -0.4),
            flipDegrees: 0
        )
        let lifted = CardPose(
            center: base.center,
            velocity: base.velocity,
            height: 72,
            verticalVelocity: -180,
            yawDegrees: base.yawDegrees,
            yawVelocity: 0,
            pitchDegrees: 12,
            pitchAxis: base.pitchAxis,
            flipDegrees: 0
        )
        let first = ProjectedShadow.project(pose: base, cardSize: portrait.cardSize)
        let second = ProjectedShadow.project(pose: lifted, cardSize: portrait.cardSize)
        XCTAssertNotEqual(first.points, second.points)
        XCTAssertGreaterThan(second.blurRadius, first.blurRadius)
        XCTAssertLessThan(second.opacity, first.opacity)
        XCTAssertLessThan(second.bounds.min.x, first.bounds.min.x)
        XCTAssertLessThan(second.bounds.min.y, first.bounds.min.y)
    }

    func testInterruptedReturnPreservesPositionAndVelocityAtWallclockBoundary() throws {
        var engine = CardMotionEngine(layout: portrait, deckCount: 3, now: 0)
        let playID = engine.startPlay(at: 0)
        let cancellationTime = 0.64 * 0.58
        let before = try XCTUnwrap(engine.advance(to: cancellationTime).flights.first(where: { $0.id == playID }))
        let returning = try XCTUnwrap(engine.cancelPlay(flightID: playID, at: cancellationTime))
        let after = returning.sample(at: cancellationTime)
        XCTAssertEqual(after.pose.center.x, before.pose.center.x, accuracy: 0.000_001)
        XCTAssertEqual(after.pose.center.y, before.pose.center.y, accuracy: 0.000_001)
        XCTAssertEqual(after.pose.velocity.x, before.pose.velocity.x, accuracy: 0.000_001)
        XCTAssertEqual(after.pose.velocity.y, before.pose.velocity.y, accuracy: 0.000_001)
        XCTAssertEqual(after.pose.height, before.pose.height, accuracy: 0.000_001)
        XCTAssertEqual(after.pose.verticalVelocity, before.pose.verticalVelocity, accuracy: 0.000_001)
        XCTAssertGreaterThanOrEqual(returning.duration, 0.30)
        XCTAssertLessThanOrEqual(returning.duration, 0.56)
    }

    func testInterruptedPlayReturnsToExactHandEndpointWithoutContact() throws {
        var engine = CardMotionEngine(layout: portrait, deckCount: 3, now: 0)
        let playID = engine.startPlay(at: 0)
        let cancellationTime = 0.64 * 0.58
        _ = engine.advance(to: cancellationTime)
        let returning = try XCTUnwrap(engine.cancelPlay(flightID: playID, at: cancellationTime))
        let endpoint = returning.sample(at: returning.endTime)
        XCTAssertEqual(endpoint.pose.center.x, portrait.handCenter.x, accuracy: 0.000_001)
        XCTAssertEqual(endpoint.pose.center.y, portrait.handCenter.y, accuracy: 0.000_001)
        let settled = engine.advance(to: returning.endTime + 0.001)
        XCTAssertTrue(settled.contacts.isEmpty)
        XCTAssertEqual(settled.handCardCount, 1)
        XCTAssertTrue(settled.flights.isEmpty)
    }

    func testFirstContactAndHapticShareObservedTimestampThenSettleFor86Milliseconds() throws {
        var engine = CardMotionEngine(layout: portrait, deckCount: 3, now: 4)
        let id = engine.startPlay(at: 4)
        let flight = try XCTUnwrap(engine.activeFlights.first)
        XCTAssertEqual(flight.id, id)
        XCTAssertTrue(engine.advance(to: 4 + flight.duration - 0.000_1).contacts.isEmpty)
        let atContact = engine.advance(to: 4 + flight.duration + 0.002)
        let contact = try XCTUnwrap(atContact.contacts.first)
        XCTAssertEqual(contact.scheduledTime, 4 + flight.duration, accuracy: 0.000_001)
        XCTAssertEqual(contact.hapticTime, contact.observedTime, accuracy: 0.000_001)
        XCTAssertTrue(atContact.flights.first?.hasContacted == true)
        XCTAssertFalse(engine.advance(to: 4 + flight.duration + 0.080).flights.isEmpty)
        XCTAssertTrue(engine.advance(to: 4 + flight.duration + 0.087).flights.isEmpty)
    }

    func testPitchAxisIsPerpendicularToTravelAndPitchSignTracksVerticalVelocity() throws {
        let flight = try makePlayFlight()
        let rising = flight.sample(at: flight.startTime + flight.duration * 0.25).pose
        let falling = flight.sample(at: flight.startTime + flight.duration * 0.75).pose
        XCTAssertEqual(
            rising.velocity.x * rising.pitchAxis.x + rising.velocity.y * rising.pitchAxis.y,
            0,
            accuracy: 0.01
        )
        XCTAssertGreaterThan(rising.verticalVelocity, 0)
        XCTAssertLessThan(falling.verticalVelocity, 0)
        XCTAssertGreaterThan(rising.pitchDegrees * falling.pitchDegrees, -200)
        XCTAssertNotEqual(rising.pitchDegrees.sign, falling.pitchDegrees.sign)
    }

    func testTenDealWallclockScheduleHasRealBoundedOverlap() {
        var engine = CardMotionEngine(layout: portrait, deckCount: 12, now: 0)
        engine.scheduleDealBurst(count: 10, interval: 0.135, at: 0)
        var observedMaximum = 0
        for step in 0...260 {
            let snapshot = engine.advance(to: Double(step) / 120)
            observedMaximum = max(observedMaximum, snapshot.flights.count)
        }
        XCTAssertGreaterThanOrEqual(observedMaximum, 3)
        XCTAssertLessThanOrEqual(observedMaximum, 5)
        XCTAssertEqual(engine.maximumConcurrentFlights, observedMaximum)
        XCTAssertEqual(engine.handCardCount, 10)
        XCTAssertEqual(engine.deckLayerCount, 2)
    }

    func testReducedMotionSettlesImmediatelyWithoutDelayedMovementOrContact() {
        var engine = CardMotionEngine(layout: portrait, deckCount: 3, now: 1)
        _ = engine.startPlay(at: 1)
        engine.setReducedMotion(true, at: 1.08)
        let snapshot = engine.snapshot
        XCTAssertTrue(snapshot.reducedMotion)
        XCTAssertTrue(snapshot.flights.isEmpty)
        XCTAssertEqual(snapshot.tableCardCount, 1)
        XCTAssertTrue(snapshot.contacts.isEmpty)
    }

    func testStageLayerContractPlacesEveryShadowBelowEveryRestingCard() {
        XCTAssertLessThan(CardStageLayer.projectedShadows, CardStageLayer.restingCards)
        XCTAssertLessThan(CardStageLayer.restingCards, CardStageLayer.flyingCards)
    }

    func testRendererDeclaresShadowsAndFlightSurfacesAsStageSiblings() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/CardMotionStage.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("ForEach(snapshot.flights) { flight in\n                shadow(for: flight)"))
        XCTAssertTrue(source.contains("ForEach(snapshot.flights) { flight in\n                flyingCard(flight)"))
        XCTAssertFalse(source.contains("scaleEffect("))
        XCTAssertFalse(source.contains("Ellipse("))
        XCTAssertFalse(source.contains("Circle("))
    }

    func testAllThreeEvidenceLayoutsKeepEndpointsInsideFullScene() throws {
        for dimensions in [(390.0, 844.0), (402.0, 874.0), (667.0, 375.0)] {
            let layout = CardMotionLayout(width: dimensions.0, height: dimensions.1)
            var engine = CardMotionEngine(layout: layout, deckCount: 3, now: 0)
            _ = engine.startPlay(at: 0)
            let flight = try XCTUnwrap(engine.activeFlights.first)
            let start = flight.sample(at: 0).pose.center
            let end = flight.sample(at: flight.endTime).pose.center
            XCTAssertEqual(start, layout.handCenter)
            XCTAssertEqual(end.x, layout.playCenter.x, accuracy: 0.000_001)
            XCTAssertEqual(end.y, layout.playCenter.y, accuracy: 0.000_001)
            for point in [layout.deckCenter, layout.handCenter, layout.playCenter] {
                XCTAssertGreaterThan(point.x, layout.cardSize.width / 2)
                XCTAssertLessThan(point.x, layout.viewport.width - layout.cardSize.width / 2)
                XCTAssertGreaterThan(point.y, layout.cardSize.height / 2)
                XCTAssertLessThan(point.y, layout.viewport.height - layout.cardSize.height / 2)
            }
        }
    }

    private var portrait: CardMotionLayout {
        CardMotionLayout(width: 402, height: 874)
    }

    private func makePlayFlight() throws -> ActiveCardFlight {
        var engine = CardMotionEngine(layout: portrait, deckCount: 3, now: 0)
        _ = engine.startPlay(at: 0)
        return try XCTUnwrap(engine.activeFlights.first)
    }
}
