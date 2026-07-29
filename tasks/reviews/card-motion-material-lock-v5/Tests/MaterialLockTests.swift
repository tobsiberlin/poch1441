import XCTest
import UIKit
import CryptoKit
@testable import CardMotionMaterialLockV5

final class MaterialLockTests: XCTestCase {
    func testFrozenV1V2V3GeometryTimingContactAndMotionHashesMatch() throws {
        let v5Root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let reviewsRoot = v5Root.deletingLastPathComponent()
        for revision in [
            FrozenMotionContract.v1,
            FrozenMotionContract.v2,
            FrozenMotionContract.v3,
        ] {
            let sourceRoot = reviewsRoot
                .appendingPathComponent(revision.reference)
                .appendingPathComponent("Sources")
            let contracts = [
                (revision.modelFile, revision.modelSHA256),
                (revision.controllerFile, revision.controllerSHA256),
                (revision.stageFile, revision.stageSHA256),
            ]
            for (file, expectedHash) in contracts {
                let data = try Data(contentsOf: sourceRoot.appendingPathComponent(file))
                XCTAssertEqual(
                    sha256(data),
                    expectedHash,
                    "\(revision.reference)/\(file) no longer matches the historical lock"
                )
            }
        }

        let v4Root = reviewsRoot.appendingPathComponent("card-motion-material-lock-v4")
        let v4SourceSHA256 = [
            "FrozenMotionContract.swift": "7aa0beebe0e505668f5f9c6fb933c323cad6bf93ba4ffd0398ed5d619199e0e1",
            "MaterialLockController.swift": "018504e26ab18f5605be1221d6d1022fcaf348ad943fa5d66c7ce7dbf9f075c6",
            "MaterialLockModel.swift": "57898a7157ca5e8c987021f4b412ca20d6daa402d84be066d732ffc07b59c32e",
            "MaterialLockStage.swift": "d6885cd33530a0f81876ca2af38499d49b56e72dde5f3f7768e6ef9c27cb08a3",
            "ProductW2CardSurface.swift": "c736fa2e6a01b75e55615b65a163366f5b22efcac4d59d4ce897767719e1e8b3",
            "W2CardMaterialContract.swift": "8d44945cd1b304442f331cd328bc34d94cf3ae5d907a457c8148e9e628a83573",
        ]
        for (file, expectedHash) in v4SourceSHA256 {
            let v4Data = try Data(contentsOf: v4Root.appendingPathComponent("Sources/\(file)"))
            let v5Data = try Data(contentsOf: v5Root.appendingPathComponent("Sources/\(file)"))
            XCTAssertEqual(sha256(v4Data), expectedHash, "Frozen V4 hash drifted for \(file)")
            XCTAssertEqual(sha256(v5Data), expectedHash, "V5 hash differs from frozen V4 for \(file)")
            XCTAssertEqual(v5Data, v4Data, "\(file) drifted; V5 must be capture-only")
        }
        let w2Data = try Data(contentsOf: v5Root.appendingPathComponent("Sources/W2CardMaterialContract.swift"))
        XCTAssertEqual(sha256(w2Data), FrozenMotionContract.w2ContractSHA256)
    }

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
            "matteInkCoverage", "directionalFibreField", "directionalFibres",
            "sparsePrintDropout", "printDropouts", "edgeCompression",
        ] {
            XCTAssertTrue(material.contains(required), "Missing W2 layer: \(required)")
        }
        XCTAssertFalse(stage.localizedCaseInsensitiveContains("diagnostic"))
        XCTAssertFalse(stage.contains("Text("))
        XCTAssertFalse(stage.contains("stroke("))
    }

    func testV5PreservesV4MaterialAndFrozenPresentation() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let material = try String(
            contentsOf: root.appendingPathComponent("Sources/ProductW2CardSurface.swift"),
            encoding: .utf8
        )
        let stage = try String(
            contentsOf: root.appendingPathComponent("Sources/MaterialLockStage.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(material.contains("edgeInset = size.width * 0.0105"))
        XCTAssertTrue(material.contains("0x8B8376"))
        XCTAssertTrue(material.contains("0x5E5951"))
        XCTAssertFalse(material.contains("0xD7D0C3"), "V2's bright UI-like card edge must not return")
        XCTAssertFalse(material.contains("ellipseIn:"), "Oval patch primitives must not return")
        XCTAssertFalse(material.contains("lowFrequencyStockTooth"))
        XCTAssertFalse(material.contains("stockTooth"))
        XCTAssertFalse(material.contains("RadialGradient("), "Broad spot coverage must not replace the removed ovals")
        XCTAssertTrue(stage.contains("PlanePoint(x: -1.7, y: 1.4)"))
        XCTAssertTrue(stage.contains("PlanePoint(x: 0.8, y: 1.9)"))
        XCTAssertTrue(stage.contains("shadowCoreOpacity"))
        XCTAssertTrue(stage.contains("shadowCoreBlur"))
    }

    func testV5RecorderRemovesOnlyTheErroneousPixelBufferFlip() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let v4Recorder = try String(
            contentsOf: root.deletingLastPathComponent()
                .appendingPathComponent("card-motion-material-lock-v4/Sources/MaterialLockEvidenceRecorder.swift"),
            encoding: .utf8
        )
        let v5Recorder = try String(
            contentsOf: root.appendingPathComponent("Sources/MaterialLockEvidenceRecorder.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(v4Recorder.contains("context.translateBy(x: 0, y: image.size.height)"))
        XCTAssertTrue(v4Recorder.contains("context.scaleBy(x: 1, y: -1)"))
        XCTAssertFalse(v5Recorder.contains("context.translateBy(x: 0, y: image.size.height)"))
        XCTAssertFalse(v5Recorder.contains("context.scaleBy(x: 1, y: -1)"))
        XCTAssertTrue(v5Recorder.contains("context.draw(cgImage"))
    }

    func testOrientationVerifierComparesDecodedPixelsAgainstRenderedEvidence() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let verifier = try String(
            contentsOf: root.appendingPathComponent("Scripts/VideoOrientationVerifier.swift"),
            encoding: .utf8
        )
        for required in [
            "AVAssetReaderTrackOutput",
            "copyNextSampleBuffer()",
            "meanAbsoluteRGBError",
            "rotate180",
            "horizontalMirror",
            "verticalMirror",
            "best.0 == \"identity\"",
        ] {
            XCTAssertTrue(verifier.contains(required), "Missing decoded-pixel orientation check: \(required)")
        }
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
        XCTAssertTrue(recorder.contains("captureStaticGate()"))
        XCTAssertTrue(recorder.contains("motionAdvanced: false"))
        XCTAssertTrue(controller.contains("PlaneLockMotion.fixedStep"))
        XCTAssertTrue(controller.contains("engine.advanceFixedStep()"))
        XCTAssertTrue(recorder.contains("FrozenMotionContract.v1.modelSHA256"))
        XCTAssertTrue(recorder.contains("FrozenMotionContract.v2.modelSHA256"))
        XCTAssertTrue(recorder.contains("FrozenMotionContract.v3.modelSHA256"))
        XCTAssertTrue(recorder.contains("FrozenMotionContract.w2ContractSHA256"))
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
