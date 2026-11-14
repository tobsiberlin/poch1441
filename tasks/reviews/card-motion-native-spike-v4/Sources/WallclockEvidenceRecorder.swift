import AVFoundation
import QuartzCore
import SwiftUI
import UIKit

struct WallclockFrameRecord: Codable, Sendable {
    let file: String
    let viewport: String
    let sequence: String
    let frameIndex: Int
    let captureTime: Double
    let controllerTime: Double
    let flightKind: String?
    let flightProgress: Double?
    let flightCount: Int
    let deckLayerCount: Int
    let contactCount: Int
}

struct WallclockEvidenceManifest: Codable, Sendable {
    let generatedAt: String
    let timingSource: String
    let syntheticProgressUsed: Bool
    let sourceAssets: [String]
    let frames: [WallclockFrameRecord]
    let cancellationProgressByViewport: [String: Double]
    let maximumDealOverlap: Int
    let firstContactSettleMilliseconds: Double
    let videoFile: String
}

@MainActor
enum WallclockEvidenceRecorder {
    private struct CapturedFrame {
        let image: UIImage
        let record: WallclockFrameRecord
    }

    private struct TimedSnapshot {
        let snapshot: StageSnapshot
        let record: WallclockFrameRecord
    }

    static func captureAll(controller: CardMotionController) async throws {
        let output = try outputDirectory()
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let viewports = [
            (name: "402x874", width: 402, height: 874),
        ]
        var allRecords: [WallclockFrameRecord] = []
        var cancellationProgress: [String: Double] = [:]
        var portraitVideoFrames: [UIImage] = []

        // Decode both real card assets and compile the SwiftUI/Canvas pipeline
        // before the measured wallclock run. The warm-up is deliberately
        // discarded; otherwise first-use shader work can consume the complete
        // 640 ms flight before frame two in a headless Simulator.
        controller.reset(width: 402, height: 874, deckCount: 3)
        controller.startPlay()
        _ = try render(snapshot: controller.snapshot, layout: controller.layout)
        controller.reset(width: 402, height: 874, deckCount: 3)
        _ = try render(snapshot: controller.snapshot, layout: controller.layout)

        for viewport in viewports {
            let result = try await captureInterruptedPlay(
                controller: controller,
                viewport: viewport,
                output: output
            )
            allRecords.append(contentsOf: result.frames.map(\.record))
            cancellationProgress[viewport.name] = result.cancellationProgress
            if viewport.name == "402x874" {
                portraitVideoFrames = result.frames.map(\.image)
                try writeContactSheet(
                    images: portraitVideoFrames,
                    to: output.appendingPathComponent("realtime-interrupted-play-contact-sheet-402x874.png"),
                    columns: 8,
                    cellWidth: 134
                )
            }
        }

        let contactFrames = try await captureFirstContact(
            controller: controller,
            output: output
        )
        allRecords.append(contentsOf: contactFrames.map(\.record))
        try writeContactSheet(
            images: contactFrames.map(\.image),
            to: output.appendingPathComponent("first-contact-settle-sheet-402x874.png"),
            columns: 6,
            cellWidth: 201
        )

        let dealResult = try await captureDeals(controller: controller, output: output)
        allRecords.append(contentsOf: dealResult.frames.map(\.record))
        try writeContactSheet(
            images: dealResult.frames.map(\.image),
            to: output.appendingPathComponent("realtime-8-deal-overlap-sheet-402x874.png"),
            columns: 8,
            cellWidth: 134
        )

        let videoURL = output.appendingPathComponent("wallclock-play-cancel-return-402x874.mp4")
        try await writeVideo(images: portraitVideoFrames, to: videoURL, framesPerSecond: 30)

        let manifest = WallclockEvidenceManifest(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            timingSource: "CACurrentMediaTime monotonic clock -> CardMotionEngine.advance(to:); CADisplayLink and headless evidence share this path",
            syntheticProgressUsed: false,
            sourceAssets: [
                "W2Damage from current card-motion native spike asset contract",
                "V10HeartsAce from current public V10 asset contract",
            ],
            frames: allRecords,
            cancellationProgressByViewport: cancellationProgress,
            maximumDealOverlap: dealResult.maximumOverlap,
            firstContactSettleMilliseconds: ActiveCardFlight.settleDuration * 1_000,
            videoFile: videoURL.lastPathComponent
        )
        try JSONEncoder.evidence.encode(manifest).write(
            to: output.appendingPathComponent("manifest.json"),
            options: .atomic
        )
        try Data("complete\n".utf8).write(
            to: output.appendingPathComponent("export.complete"),
            options: .atomic
        )
        controller.stop()
    }

    private static func captureInterruptedPlay(
        controller: CardMotionController,
        viewport: (name: String, width: Int, height: Int),
        output: URL
    ) async throws -> (frames: [CapturedFrame], cancellationProgress: Double) {
        controller.reset(width: Double(viewport.width), height: Double(viewport.height), deckCount: 3)
        controller.startPlay()
        _ = try render(snapshot: controller.snapshot, layout: controller.layout)
        controller.reset(width: Double(viewport.width), height: Double(viewport.height), deckCount: 3)
        _ = try render(snapshot: controller.snapshot, layout: controller.layout)
        controller.startPlayWithScheduledCancellation(atProgress: 0.58)
        let sequenceStart = CACurrentMediaTime()
        let framesPerSecond = 30.0
        var timedSnapshots: [TimedSnapshot] = []

        for index in 0..<38 {
            try await wait(until: sequenceStart + Double(index) / framesPerSecond)
            controller.synchronizeToWallclock()
            let snapshot = controller.snapshot
            let file = "\(viewport.name)-wallclock-play-cancel-return-\(String(format: "%03d", index)).png"
            let flight = snapshot.flights.first
            timedSnapshots.append(TimedSnapshot(
                snapshot: snapshot,
                record: WallclockFrameRecord(
                    file: file,
                    viewport: viewport.name,
                    sequence: "play-cancel-return",
                    frameIndex: index,
                    captureTime: CACurrentMediaTime(),
                    controllerTime: snapshot.wallclockTime,
                    flightKind: flight?.kind.rawValue,
                    flightProgress: flight?.normalizedProgress,
                    flightCount: snapshot.flights.count,
                    deckLayerCount: snapshot.deckLayerCount,
                    contactCount: snapshot.contacts.count
                )
            ))
            if controller.lastCancellationProgress != nil, controller.isIdle, index > 18 { break }
        }
        let observedCancellationProgress = controller.lastCancellationProgress ?? 0
        guard observedCancellationProgress >= 0.58, observedCancellationProgress < 0.62 else {
            throw EvidenceError.cancellationOutsideGate(viewport.name, observedCancellationProgress)
        }
        let frames = try timedSnapshots.map { item in
            CapturedFrame(
                image: try render(snapshot: item.snapshot, layout: controller.layout),
                record: item.record
            )
        }
        for frame in frames {
            try write(image: frame.image, named: frame.record.file, to: output)
        }
        return (frames, observedCancellationProgress)
    }

    private static func captureFirstContact(
        controller: CardMotionController,
        output: URL
    ) async throws -> [CapturedFrame] {
        controller.reset(width: 402, height: 874, deckCount: 3)
        controller.startPlay()
        let start = CACurrentMediaTime()
        var timedSnapshots: [TimedSnapshot] = []
        var contactObserved = false
        for index in 0..<25 {
            try await wait(until: start + Double(index) / 30)
            controller.synchronizeToWallclock()
            let snapshot = controller.snapshot
            if !snapshot.contacts.isEmpty { contactObserved = true }
            guard index >= 15 || contactObserved else { continue }
            let file = "402x874-first-contact-settle-\(String(format: "%03d", index)).png"
            let flight = snapshot.flights.first
            timedSnapshots.append(TimedSnapshot(
                snapshot: snapshot,
                record: WallclockFrameRecord(
                    file: file,
                    viewport: "402x874",
                    sequence: "first-contact-settle",
                    frameIndex: index,
                    captureTime: CACurrentMediaTime(),
                    controllerTime: snapshot.wallclockTime,
                    flightKind: flight?.kind.rawValue,
                    flightProgress: flight?.normalizedProgress,
                    flightCount: snapshot.flights.count,
                    deckLayerCount: snapshot.deckLayerCount,
                    contactCount: snapshot.contacts.count
                )
            ))
        }
        guard contactObserved else { throw EvidenceError.contactMissing }
        let frames = try timedSnapshots.map { item in
            CapturedFrame(
                image: try render(snapshot: item.snapshot, layout: controller.layout),
                record: item.record
            )
        }
        for frame in frames {
            try write(image: frame.image, named: frame.record.file, to: output)
            let cropFile = frame.record.file.replacingOccurrences(of: "settle", with: "crop")
            try write(
                image: try contactCrop(image: frame.image, layout: controller.layout),
                named: cropFile,
                to: output
            )
        }
        return frames
    }

    private static func captureDeals(
        controller: CardMotionController,
        output: URL
    ) async throws -> (frames: [CapturedFrame], maximumOverlap: Int) {
        controller.reset(width: 402, height: 874, deckCount: 3)
        controller.startSingleDeal()
        let extracted = controller.snapshot
        guard extracted.deckLayerCount == 2, extracted.flights.count == 1 else {
            throw EvidenceError.deckExtractionInvalid
        }
        let singleImage = try render(snapshot: extracted, layout: controller.layout)
        try write(image: singleImage, named: "402x874-single-deal-top-extracted-two-remain.png", to: output)

        controller.reset(width: 402, height: 874, deckCount: 12)
        controller.startDealBurst(count: 8)
        let start = CACurrentMediaTime()
        var timedSnapshots: [TimedSnapshot] = []
        var maximumOverlap = 0
        for index in 0..<90 {
            try await wait(until: start + Double(index) / 30)
            controller.synchronizeToWallclock()
            let snapshot = controller.snapshot
            maximumOverlap = max(maximumOverlap, snapshot.flights.count)
            let file = "402x874-wallclock-8-deals-\(String(format: "%03d", index)).png"
            timedSnapshots.append(TimedSnapshot(
                snapshot: snapshot,
                record: WallclockFrameRecord(
                    file: file,
                    viewport: "402x874",
                    sequence: "8-deal-overlap",
                    frameIndex: index,
                    captureTime: CACurrentMediaTime(),
                    controllerTime: snapshot.wallclockTime,
                    flightKind: snapshot.flights.first?.kind.rawValue,
                    flightProgress: snapshot.flights.first?.normalizedProgress,
                    flightCount: snapshot.flights.count,
                    deckLayerCount: snapshot.deckLayerCount,
                    contactCount: snapshot.contacts.count
                )
            ))
            if snapshot.handCardCount == 8, snapshot.flights.isEmpty { break }
        }
        guard maximumOverlap == 2 else {
            throw EvidenceError.overlapOutsideGate(maximumOverlap)
        }
        let frames = try timedSnapshots.map { item in
            CapturedFrame(
                image: try render(snapshot: item.snapshot, layout: controller.layout),
                record: item.record
            )
        }
        for frame in frames {
            try write(image: frame.image, named: frame.record.file, to: output)
        }
        return (frames, maximumOverlap)
    }

    private static func render(snapshot: StageSnapshot, layout: CardMotionLayout) throws -> UIImage {
        let content = CardMotionStage(snapshot: snapshot, layout: layout)
            .frame(width: layout.viewport.width, height: layout.viewport.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(
            width: layout.viewport.width,
            height: layout.viewport.height
        )
        guard let image = renderer.uiImage else { throw EvidenceError.renderFailed }
        return image
    }

    private static func contactCrop(image: UIImage, layout: CardMotionLayout) throws -> UIImage {
        guard let cgImage = image.cgImage else { throw EvidenceError.renderFailed }
        let width = min(220, cgImage.width)
        let height = min(260, cgImage.height)
        let originX = max(0, min(cgImage.width - width, Int(layout.playCenter.x) - width / 2))
        let originY = max(0, min(cgImage.height - height, Int(layout.playCenter.y) - height / 2))
        guard let crop = cgImage.cropping(to: CGRect(x: originX, y: originY, width: width, height: height)) else {
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
            ), let cgImage = image.cgImage else { throw EvidenceError.videoFailed }
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
        return documents.appendingPathComponent("CardMotionEvidenceV4", isDirectory: true)
    }
}

private enum EvidenceError: LocalizedError {
    case outputUnavailable
    case renderFailed
    case videoFailed
    case contactMissing
    case deckExtractionInvalid
    case cancellationOutsideGate(String, Double)
    case overlapOutsideGate(Int)

    var errorDescription: String? {
        switch self {
        case .outputUnavailable: "Evidence-Ausgabe nicht verfügbar"
        case .renderFailed: "Evidence-Frame konnte nicht gerendert werden"
        case .videoFailed: "Wallclock-Video konnte nicht geschrieben werden"
        case .contactMissing: "Kein Erstkontakt im Wallclock-Lauf"
        case .deckExtractionInvalid: "Deal hat nicht exakt die oberste Karte entnommen"
        case let .cancellationOutsideGate(viewport, progress):
            "Abbruch in \(viewport) bei \(progress), nicht im Gate 0.58..<0.62"
        case let .overlapOutsideGate(overlap):
            "Maximaler Deal-Overlap \(overlap), erwartet 3...5"
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
