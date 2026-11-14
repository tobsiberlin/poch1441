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
    let fullSequenceVideo: String
    let frames: [PlaneLockFrameRecord]
}

@MainActor
enum PlaneLockEvidenceRecorder {
    private struct TimedSnapshot {
        let snapshot: PlaneLockSnapshot
        let record: PlaneLockFrameRecord
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
            let file = "402x874-plane-lock-\(String(format: "%03d", index)).png"
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
            to: output.appendingPathComponent("uncut-plane-lock-sequence-402x874.png"),
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
            to: output.appendingPathComponent("tight-first-edge-contact-strip-402x874.png"),
            columns: contactCrops.count,
            cellWidth: 190
        )

        let videoURL = output.appendingPathComponent("wallclock-plane-lock-402x874.mp4")
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
        let content = PlaneLockStage(snapshot: snapshot, showDiagnostics: true)
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
            context.translateBy(x: 0, y: image.size.height)
            context.scaleBy(x: 1, y: -1)
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
        return documents.appendingPathComponent("CardPlaneLockEvidenceV1", isDirectory: true)
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
