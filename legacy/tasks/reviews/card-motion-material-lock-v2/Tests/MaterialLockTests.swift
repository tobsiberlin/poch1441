import XCTest
import UIKit
@testable import CardMotionMaterialLockV2

final class MaterialLockTests: XCTestCase {
    func testActualTrackBWorldAndExistingDeckSurfaceCompile() {
        XCTAssertNotNil(UIImage(named: "TrackBWorld"))
        XCTAssertNotNil(UIImage(named: "card_back_damage_00"))
        XCTAssertNotNil(UIImage(named: "card_back_damage_01"))
        XCTAssertNotNil(UIImage(named: "card_back_damage_02"))
    }

    func testExplicitTableHomographyCalibrationRMSIsAtMostOnePixel() {
        let calibration = PlaneLockCalibration()
        XCTAssertLessThanOrEqual(
            calibration.homography.calibrationRMS(expected: calibration.tablePlane),
            1.0
        )
    }

    func testStableRestCornersAreWithinTwoPixelsOfTarget() {
        let calibration = PlaneLockCalibration()
        let pose = PlaneLockMotion().pose(at: PlaneLockMotion.sequenceDuration)
        XCTAssertEqual(pose.phase, .stableRest)
        XCTAssertLessThanOrEqual(maximumCornerDeviation(pose.cardQuad, calibration.targetQuad), 2.0)
    }

    func testTargetQuadIsInsideSemanticLargeMiddleRegion() {
        let calibration = PlaneLockCalibration()
        for corner in calibration.targetQuad.points {
            XCTAssertTrue(
                convexQuadContains(calibration.semanticMiddleRegion, point: corner, tolerance: 0.001),
                "Every projected card corner must lie in the large central compartment"
            )
        }
        XCTAssertTrue(
            convexQuadContains(
                calibration.semanticMiddleRegion,
                point: calibration.targetQuad.center,
                tolerance: 0.001
            )
        )
    }

    func testFirstEdgeContactAndFixedStepContinuityHaveNoTeleport() {
        let motion = PlaneLockMotion()
        let before = motion.pose(at: PlaneLockMotion.firstContactTime - PlaneLockMotion.fixedStep)
        let contact = motion.pose(at: PlaneLockMotion.firstContactTime)
        let after = motion.pose(at: PlaneLockMotion.firstContactTime + PlaneLockMotion.fixedStep)

        XCTAssertFalse(before.hasContacted)
        XCTAssertTrue(contact.hasContacted)
        XCTAssertEqual(contact.phase, .firstEdgeContact)
        XCTAssertLessThanOrEqual(maximumCornerDeviation(before.cardQuad, contact.cardQuad), 2.0)
        XCTAssertLessThanOrEqual(maximumCornerDeviation(contact.cardQuad, after.cardQuad), 2.0)

        let target = motion.calibration.targetQuad
        XCTAssertEqual(contact.cardQuad.bottomLeft.x, target.bottomLeft.x, accuracy: 0.001)
        XCTAssertEqual(contact.cardQuad.bottomLeft.y, target.bottomLeft.y, accuracy: 0.001)
        XCTAssertEqual(contact.cardQuad.bottomRight.x, target.bottomRight.x, accuracy: 0.001)
        XCTAssertEqual(contact.cardQuad.bottomRight.y, target.bottomRight.y, accuracy: 0.001)
        XCTAssertGreaterThan(
            maximumCornerDeviation(contact.cardQuad, target),
            2.0,
            "The trailing edge must still be visibly raised at first contact"
        )
    }

    func testSurfaceRemainsCardBackAcrossContactAndRest() {
        let motion = PlaneLockMotion()
        let samples = stride(from: 0.0, through: PlaneLockMotion.sequenceDuration, by: PlaneLockMotion.fixedStep)
        XCTAssertTrue(samples.allSatisfy { motion.pose(at: $0).surface == .cardBack })
    }

    func testDirectedShadowIsSeparateAndMovesAwayFromUpperLeftLight() {
        let pose = PlaneLockMotion().pose(at: 0.39)
        XCTAssertGreaterThan(pose.height, 30)
        XCTAssertGreaterThan(pose.shadowQuad.center.x, pose.groundQuad.center.x + 6)
        XCTAssertGreaterThan(pose.shadowQuad.center.y, pose.groundQuad.center.y + 9)
        XCTAssertNotEqual(pose.shadowQuad, pose.cardQuad)
    }

    func testOneWorldLightProfileIsStableAcrossTheWholeSequence() {
        let motion = PlaneLockMotion()
        XCTAssertEqual(motion.lightProfile, .trackB)
        XCTAssertEqual(WorldLightProfile.trackB.id, "track-b-lamp-upper-left-v1")
        XCTAssertLessThan(WorldLightProfile.trackB.keyDirection.x, 0)
        XCTAssertLessThan(WorldLightProfile.trackB.keyDirection.y, 0)
    }

    @MainActor
    func testProductionW2MaterialRemainsReadableAtProjectedPhoneScale() {
        let calibration = PlaneLockCalibration()
        let topEdge = (calibration.targetQuad.topRight - calibration.targetQuad.topLeft).length
        let leftEdge = (calibration.targetQuad.bottomLeft - calibration.targetQuad.topLeft).length
        let shortEdge = min(topEdge, leftEdge)
        XCTAssertGreaterThanOrEqual(shortEdge, 54)
        XCTAssertLessThanOrEqual(shortEdge, 70)
        XCTAssertEqual(ProductW2SurfaceRaster.size, CGSize(width: 312, height: 444))
        XCTAssertEqual(W2BackPatina.marks().count, 24)
        XCTAssertEqual(W2BackPatina.marks(), W2BackPatina.marks())
    }

    func testProductProofUsesCardStockPatinaDamageAndNoDiagnosticChrome() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let material = try String(
            contentsOf: root.appendingPathComponent("Sources/ProductW2CardSurface.swift"),
            encoding: .utf8
        )
        let stage = try String(
            contentsOf: root.appendingPathComponent("Sources/MaterialLockStage.swift"),
            encoding: .utf8
        )
        for required in [
            "cardStock", "materialPatina", "materialDamage", "facetLozenge",
            "monograms", "fixedWorldLightResponse", "W2BackPatina.marks()",
        ] {
            XCTAssertTrue(material.contains(required), "Missing W2 layer: \(required)")
        }
        XCTAssertFalse(stage.localizedCaseInsensitiveContains("diagnostic"))
        XCTAssertFalse(stage.contains("Text("))
        XCTAssertFalse(stage.contains("stroke("))
    }

    func testSourceDeckIsGroundedBySameWorldLightProfile() {
        let calibration = PlaneLockCalibration()
        let profile = WorldLightProfile.trackB
        let shadowCenter = calibration.sourceQuad.translated(
            by: profile.keyDirection * -profile.restingShadowOffset
        ).center
        XCTAssertGreaterThanOrEqual(
            (shadowCenter - calibration.sourceQuad.center).length,
            profile.restingShadowOffset - 0.001
        )
        XCTAssertLessThanOrEqual(
            (shadowCenter - calibration.sourceQuad.center).length,
            profile.restingShadowOffset
        )
        XCTAssertLessThanOrEqual(profile.restingShadowOffset, 0.75)
    }

    func testStoredMaterialCurlDischargesExactlyOnceAfterFirstContact() throws {
        let motion = PlaneLockMotion()
        let before = motion.pose(at: PlaneLockMotion.firstContactTime - PlaneLockMotion.fixedStep)
        XCTAssertEqual(before.storedMaterialCurlMillimeters, 1.1, accuracy: 0.000_001)

        let postContact = stride(
            from: PlaneLockMotion.firstContactTime,
            through: PlaneLockMotion.sequenceDuration,
            by: PlaneLockMotion.fixedStep
        ).map { motion.pose(at: $0).storedMaterialCurlMillimeters }
        XCTAssertEqual(try XCTUnwrap(postContact.first), 1.1, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(postContact.last), 0, accuracy: 0.000_001)
        for pair in zip(postContact, postContact.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.1, pair.0 + 0.000_001)
        }
        XCTAssertEqual(postContact.filter { $0 > 0.000_001 }.count > 0, true)
        XCTAssertTrue(postContact.suffix(20).allSatisfy { $0 == 0 })
    }

    func testContactShadowGapStaysWithinBlueprintGate() {
        let pose = PlaneLockMotion().pose(at: PlaneLockMotion.sequenceDuration)
        XCTAssertLessThanOrEqual(
            (pose.shadowQuad.center - pose.groundQuad.center).length,
            0.75
        )
    }

    func testEvidenceUsesMonotonicWallclockWithFixedStepAndNoSyntheticProgress() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let recorder = try String(
            contentsOf: root.appendingPathComponent("Sources/MaterialLockEvidenceRecorder.swift"),
            encoding: .utf8
        )
        let controller = try String(
            contentsOf: root.appendingPathComponent("Sources/MaterialLockController.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(recorder.contains("syntheticProgressUsed: false"))
        XCTAssertTrue(recorder.contains("CACurrentMediaTime()"))
        XCTAssertTrue(controller.contains("PlaneLockMotion.fixedStep"))
        XCTAssertTrue(controller.contains("engine.advanceFixedStep()"))
    }
}
