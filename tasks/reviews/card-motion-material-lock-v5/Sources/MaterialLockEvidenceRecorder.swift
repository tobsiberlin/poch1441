import AVFoundation
import QuartzCore
import SwiftUI
import UIKit

struct PlaneLockFrameRecord: Codable, Sendable {
    let file: String
    let frameIndex: Int
    let captureWallclock: Double
    let fixedStepIndex: Int
    let simulationTime: Double
    let phase: String
    let height: Double
    let hasContacted: Bool
}

struct PlaneLockEvidenceManifest: Codable, Sendable {
    let generatedAt: String
    let viewport: String
    let timingSource: String
    let syntheticProgressUsed: Bool
    let captureFramesPerSecond: Int
    let fixedStepSeconds: Double
    let homographyCalibrationRMSPixels: Double
    let stableRestCornerDeviationPixels: Double
    let targetRegion: String
    let worldLightProfileID: String
    let worldLightKeyDirection: PlanePoint
    let contactShadowOffsetPixels: Double
    let surfaceBeforeContact: String
    let surfaceAfterContact: String
    let storedMaterialCurlBeforeContactMillimeters: Double
    let storedMaterialCurlAtStableRestMillimeters: Double
    let firstContactFrameIndex: Int
    let stableRestFrameCount: Int
    let frozenContractReferences: [String]
    let frozenContractSHA256: [String: String]
    let frozenW2ContractSHA256: String
    let productMaterial: String
    let productMaterialVariant: Int
    let targetCardShortEdgePixels: Double
    let diagnosticGraphicsVisible: Bool
    let fullSequenceVideo: String
    let frames: [PlaneLockFrameRecord]
}

struct StaticMaterialGateManifest: Codable, Sendable {
    let generatedAt: String
    let viewport: String
    let sourceFrame: String
    let stableRestFrame: String
    let targetCardShortEdgePixels: Double
    let materialHypothesis: String
    let motionAdvanced: Bool
}

@MainActor
enum PlaneLockEvidenceRecorder {
    private struct TimedSnapshot {
        let snapshot: PlaneLockSnapshot
        let record: PlaneLockFrameRecord
    }

    static func captureStaticGate() throws {
        let output = try staticOutputDirectory()
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let motion = PlaneLockMotion()
        let source = PlaneLockSnapshot(
            fixedStepIndex: 0,
            simulationTime: 0,
            pose: motion.pose(at: 0)
        )
        let restStep = Int((PlaneLockMotion.sequenceDuration / PlaneLockMotion.fixedStep).rounded())
        let stableRest = PlaneLockSnapshot(
            fixedStepIndex: restStep,
            simulationTime: PlaneLockMotion.sequenceDuration,
            pose: motion.pose(at: PlaneLockMotion.sequenceDuration)
        )
        let sourceImage = try render(snapshot: source)
        let stableRestImage = try render(snapshot: stableRest)
        try write(image: sourceImage, named: "402x874-static-source-v5.png", to: output)
        try write(image: stableRestImage, named: "402x874-static-rest-v5.png", to: output)
        try writeContactSheet(
            images: [sourceImage, stableRestImage],
            to: output.appendingPathComponent("static-source-rest-pair-v5-402x874.png"),
            columns: 2,
            cellWidth: PlaneLockCalibration.viewportWidth
        )

        let calibration = PlaneLockCalibration()
        let sourceCrop = try crop(image: sourceImage, around: calibration.sourceQuad, padding: 10)
        let restCrop = try crop(image: stableRestImage, around: calibration.targetQuad, padding: 10)
        try write(image: sourceCrop, named: "static-source-card-crop-v5.png", to: output)
        try write(image: restCrop, named: "static-rest-card-crop-v5.png", to: output)
        try writeContactSheet(
            images: [sourceCrop, restCrop],
            to: output.appendingPathComponent("static-material-crops-v5.png"),
            columns: 2,
            cellWidth: 190
        )

        let targetShortEdge = min(
            (calibration.targetQuad.topRight - calibration.targetQuad.topLeft).length,
            (calibration.targetQuad.bottomLeft - calibration.targetQuad.topLeft).length
        )
        let manifest = StaticMaterialGateManifest(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            viewport: "402x874",
            sourceFrame: "402x874-static-source-v5.png",
            stableRestFrame: "402x874-static-rest-v5.png",
            targetCardShortEdgePixels: targetShortEdge,
            materialHypothesis: "Irregular directional fibres, sparse bent print dropout and narrow edge compression will read as matte printed card stock at 54.85 px without discrete oval patches.",
            motionAdvanced: false
        )
        try JSONEncoder.evidence.encode(manifest).write(
            to: output.appendingPathComponent("static-manifest.json"),
            options: .atomic
        )
        try Data("complete\n".utf8).write(
            to: output.appendingPathComponent("export.complete"),
            options: .atomic
        )
    }

    static func capture(controller: PlaneLockController) async throws {
        let output = try outputDirectory()
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        controller.reset()
        _ = try render(snapshot: controller.snapshot)
        controller.start()
        let sequenceStart = CACurrentMediaTime()
        var timed: [TimedSnapshot] = []

        let captureFramesPerSecond = 60
        for index in 0..<82 {
            try await wait(
                until: sequenceStart + Double(index) / Double(captureFramesPerSecond)
            )
            controller.synchronizeToWallclock()
            let snapshot = controller.snapshot
            let file = "402x874-material-lock-v5-\(String(format: "%03d", index)).png"
            timed.append(TimedSnapshot(
                snapshot: snapshot,
                record: PlaneLockFrameRecord(
                    file: file,
                    frameIndex: index,
                    captureWallclock: CACurrentMediaTime(),
                    fixedStepIndex: snapshot.fixedStepIndex,
                    simulationTime: snapshot.simulationTime,
                    phase: snapshot.pose.phase.rawValue,
                    height: snapshot.pose.height,
                    hasContacted: snapshot.pose.hasContacted
                )
            ))
        }
        controller.stop()

        guard let firstContact = timed.firstIndex(where: { $0.snapshot.pose.hasContacted }) else {
            throw EvidenceError.contactMissing
        }
        let stableRestCount = timed.filter { $0.snapshot.pose.phase == .stableRest }.count
        guard stableRestCount >= 8 else { throw EvidenceError.stableRestMissing(stableRestCount) }

        var frames: [UIImage] = []
        frames.reserveCapacity(timed.count)
        for item in timed {
            let image = try render(snapshot: item.snapshot)
            try write(image: image, named: item.record.file, to: output)
            frames.append(image)
        }

        try writeContactSheet(
            images: frames,
            to: output.appendingPathComponent("uncut-material-lock-v5-sequence-402x874.png"),
            columns: 8,
            cellWidth: 100
        )

        let contactRange = max(0, firstContact - 4)...min(frames.count - 1, firstContact + 8)
        let contactCrops = try contactRange.map { index -> UIImage in
            let crop = try contactCrop(image: frames[index])
            try write(
                image: crop,
                named: "402x874-contact-crop-\(String(format: "%03d", index)).png",
                to: output
            )
            return crop
        }
        try writeContactSheet(
            images: contactCrops,
            to: output.appendingPathComponent("tight-first-edge-contact-v5-strip-402x874.png"),
            columns: contactCrops.count,
            cellWidth: 190
        )

        let videoURL = output.appendingPathComponent("wallclock-material-lock-v5-402x874.mp4")
        try await writeVideo(
            images: frames,
            to: videoURL,
            framesPerSecond: captureFramesPerSecond
        )

        let calibration = PlaneLockCalibration()
        let restPose = PlaneLockMotion().pose(at: PlaneLockMotion.sequenceDuration)
        let manifest = PlaneLockEvidenceManifest(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            viewport: "402x874",
            timingSource: "CACurrentMediaTime monotonic wallclock -> 240 Hz fixed-step accumulator shared by CADisplayLink and evidence recorder",
            syntheticProgressUsed: false,
            captureFramesPerSecond: captureFramesPerSecond,
            fixedStepSeconds: PlaneLockMotion.fixedStep,
            homographyCalibrationRMSPixels: calibration.homography.calibrationRMS(expected: calibration.tablePlane),
            stableRestCornerDeviationPixels: maximumCornerDeviation(restPose.cardQuad, calibration.targetQuad),
            targetRegion: "Track-B large central compartment",
            worldLightProfileID: WorldLightProfile.trackB.id,
            worldLightKeyDirection: WorldLightProfile.trackB.keyDirection,
            contactShadowOffsetPixels: WorldLightProfile.trackB.restingShadowOffset,
            surfaceBeforeContact: PlaneLockSurface.cardBack.rawValue,
            surfaceAfterContact: restPose.surface.rawValue,
            storedMaterialCurlBeforeContactMillimeters: PlaneLockMotion().pose(
                at: PlaneLockMotion.firstContactTime - PlaneLockMotion.fixedStep
            ).storedMaterialCurlMillimeters,
            storedMaterialCurlAtStableRestMillimeters: restPose.storedMaterialCurlMillimeters,
            firstContactFrameIndex: firstContact,
            stableRestFrameCount: stableRestCount,
            frozenContractReferences: [
                FrozenMotionContract.v1.reference,
                FrozenMotionContract.v2.reference,
                FrozenMotionContract.v3.reference,
            ],
            frozenContractSHA256: [
                "v1Model": FrozenMotionContract.v1.modelSHA256,
                "v1Controller": FrozenMotionContract.v1.controllerSHA256,
                "v1Stage": FrozenMotionContract.v1.stageSHA256,
                "v2Model": FrozenMotionContract.v2.modelSHA256,
                "v2Controller": FrozenMotionContract.v2.controllerSHA256,
                "v2Stage": FrozenMotionContract.v2.stageSHA256,
                "v3Model": FrozenMotionContract.v3.modelSHA256,
                "v3Controller": FrozenMotionContract.v3.controllerSHA256,
                "v3Stage": FrozenMotionContract.v3.stageSHA256,
            ],
            frozenW2ContractSHA256: FrozenMotionContract.w2ContractSHA256,
            productMaterial: "Production W2 CardBack unchanged; irregular directional fibres, sparse bent print dropout, narrow edge compression, subtle camping patina, thin dark exposed stock edge",
            productMaterialVariant: 0,
            targetCardShortEdgePixels: min(
                (calibration.targetQuad.topRight - calibration.targetQuad.topLeft).length,
                (calibration.targetQuad.bottomLeft - calibration.targetQuad.topLeft).length
            ),
            diagnosticGraphicsVisible: false,
            fullSequenceVideo: videoURL.lastPathComponent,
            frames: timed.map(\.record)
        )
        try JSONEncoder.evidence.encode(manifest).write(
            to: output.appendingPathComponent("manifest.json"),
            options: .atomic
        )
        try Data("complete\n".utf8).write(
            to: output.appendingPathComponent("export.complete"),
            options: .atomic
        )
    }

    private static func render(snapshot: PlaneLockSnapshot) throws -> UIImage {
        let content = MaterialLockStage(snapshot: snapshot)
            .frame(
                width: PlaneLockCalibration.viewportWidth,
                height: PlaneLockCalibration.viewportHeight
            )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(
            width: PlaneLockCalibration.viewportWidth,
            height: PlaneLockCalibration.viewportHeight
        )
        guard let image = renderer.uiImage else { throw EvidenceError.renderFailed }
        return image
    }

    private static func contactCrop(image: UIImage) throws -> UIImage {
        guard let cgImage = image.cgImage,
              let crop = cgImage.cropping(to: CGRect(x: 105, y: 340, width: 210, height: 205)) else {
            throw EvidenceError.renderFailed
        }
        return UIImage(cgImage: crop)
    }

    private static func crop(image: UIImage, around quad: PlaneQuad, padding: Double) throws -> UIImage {
        guard let cgImage = image.cgImage else { throw EvidenceError.renderFailed }
        let points = quad.points
        guard let minimumX = points.map(\.x).min(),
              let maximumX = points.map(\.x).max(),
              let minimumY = points.map(\.y).min(),
              let maximumY = points.map(\.y).max() else {
            throw EvidenceError.renderFailed
        }
        let bounds = CGRect(origin: .zero, size: image.size)
        let proposed = CGRect(
            x: minimumX - padding,
            y: minimumY - padding,
            width: maximumX - minimumX + 2 * padding,
            height: maximumY - minimumY + 2 * padding
        ).intersection(bounds).integral
        guard let cropped = cgImage.cropping(to: proposed) else { throw EvidenceError.renderFailed }
        return UIImage(cgImage: cropped)
    }

    private static func write(image: UIImage, named name: String, to output: URL) throws {
        guard let data = image.pngData() else { throw EvidenceError.renderFailed }
        try data.write(to: output.appendingPathComponent(name), options: .atomic)
    }

    private static func writeContactSheet(
        images: [UIImage],
        to output: URL,
        columns: Int,
        cellWidth: Double
    ) throws {
        guard let first = images.first else { throw EvidenceError.renderFailed }
        let aspect = first.size.height / max(first.size.width, 1)
        let cell = CGSize(width: cellWidth, height: cellWidth * aspect)
        let rows = Int(ceil(Double(images.count) / Double(columns)))
        let size = CGSize(width: cell.width * Double(columns), height: cell.height * Double(rows))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let sheet = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            for (index, image) in images.enumerated() {
                image.draw(in: CGRect(
                    x: Double(index % columns) * cell.width,
                    y: Double(index / columns) * cell.height,
                    width: cell.width,
                    height: cell.height
                ))
            }
        }
        guard let data = sheet.pngData() else { throw EvidenceError.renderFailed }
        try data.write(to: output, options: .atomic)
    }

    private static func writeVideo(images: [UIImage], to output: URL, framesPerSecond: Int) async throws {
        guard let first = images.first else { throw EvidenceError.renderFailed }
        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(first.size.width),
            AVVideoHeightKey: Int(first.size.height),
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(first.size.width),
                kCVPixelBufferHeightKey as String: Int(first.size.height),
            ]
        )
        guard writer.canAdd(input) else { throw EvidenceError.videoFailed }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? EvidenceError.videoFailed }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else { throw EvidenceError.videoFailed }
        for (index, image) in images.enumerated() {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(2))
            }
            var optionalBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
            guard let buffer = optionalBuffer else { throw EvidenceError.videoFailed }
            CVPixelBufferLockBaseAddress(buffer, [])
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            guard let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: CVPixelBufferGetWidth(buffer),
                height: CVPixelBufferGetHeight(buffer),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            ), let cgImage = image.cgImage else {
                throw EvidenceError.videoFailed
            }
            // The ImageRenderer CGImage already has the row order expected by the
            // AVAssetWriter pixel buffer. V4 applied an extra UIKit-style vertical
            // flip here, so the encoded frames no longer matched the upright PNGs.
            context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
            let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(framesPerSecond))
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw writer.error ?? EvidenceError.videoFailed
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? EvidenceError.videoFailed }
    }

    private static func wait(until target: Double) async throws {
        let remaining = target - CACurrentMediaTime()
        if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
    }

    private static func outputDirectory() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw EvidenceError.outputUnavailable
        }
        return documents.appendingPathComponent("CardMaterialLockEvidenceV5", isDirectory: true)
    }

    private static func staticOutputDirectory() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw EvidenceError.outputUnavailable
        }
        return documents.appendingPathComponent("CardMaterialLockStaticEvidenceV5", isDirectory: true)
    }
}

private enum EvidenceError: LocalizedError {
    case outputUnavailable
    case renderFailed
    case videoFailed
    case contactMissing
    case stableRestMissing(Int)

    var errorDescription: String? {
        switch self {
        case .outputUnavailable: "Evidence-Ausgabe nicht verfügbar"
        case .renderFailed: "Evidence-Frame konnte nicht gerendert werden"
        case .videoFailed: "Wallclock-Video konnte nicht geschrieben werden"
        case .contactMissing: "Kein Erstkantenkontakt im Wallclock-Lauf"
        case let .stableRestMissing(count): "Nur \(count) stabile Ruheframes statt mindestens 8"
        }
    }
}

private extension JSONEncoder {
    static var evidence: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
