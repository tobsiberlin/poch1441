import AVFoundation
import QuartzCore
import SwiftUI
import UIKit

struct HarnessFrameRecord: Codable, Sendable {
    let sequence: String
    let frameIndex: Int
    let targetElapsedSeconds: Double
    let captureElapsedSeconds: Double
    let captureHostTime: Double
    let activeCardIndices: [Int]
    let activeCount: Int
    let visibleCardIndices: [Int]
    let phasesByCard: [String: String]
    let peeledCardIndices: [Int]
    let deckCount: Int
}

struct HarnessLifecycleRecord: Codable, Sendable {
    let cardIndex: Int
    let rhythmPhase: String
    let rhythmTargetSeconds: Double
    let actualStartSeconds: Double
    let contactSeconds: Double
    let settleSeconds: Double
    let restWindowStartSeconds: Double
    let capturedStartSeconds: Double?
    let capturedContactSeconds: Double?
    let capturedSettleSeconds: Double?
    let capturedRestSeconds: Double?
    let routeClass: String
    let contactClass: String
}

struct HarnessSequenceRecord: Codable, Sendable {
    let sequence: String
    let captureFramesPerSecond: Int
    let uncut: Bool
    let videoFile: String
    let timelineFile: String
    let contactSheetFile: String
    let cancellationSeconds: Double?
    let cancellationClearSeconds: Double?
    let maximumActiveCards: Int
    let maximumActiveCardsAtPeel: Int
    let invisibleWaitSeconds: Double
    let lifecycle: [HarnessLifecycleRecord]
    let frames: [HarnessFrameRecord]
}

struct HarnessEvidenceManifest: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let viewport: String
    let timingSource: String
    let sourceContract: String
    let sourceContractSHA256: String
    let syntheticProgressUsed: Bool
    let productAudioIncluded: Bool
    let materialApprovalClaimed: Bool
    let sourceAssets: [String]
    let sequences: [HarnessSequenceRecord]
}

@MainActor
enum WallclockEvidenceRecorder {
    static let framesPerSecond = 60
    static let viewport = CGSize(width: 402, height: 874)
    static let contractSHA256 = "2294f03d7fa1079b737ff6274aad36555d1a3acad018b8f0f0659a3251e8487c"

    private struct TimedSnapshot {
        let snapshot: HarnessSnapshot
        let record: HarnessFrameRecord
    }

    static func captureAll() async throws {
        let output = try outputDirectory()
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        // Warm ImageRenderer and W2 decoding outside measured capture time.
        let warmPlan = try RhythmHarnessPlan.make(sequence: .standard)
        _ = try render(plan: warmPlan, snapshot: warmPlan.snapshot(at: 0))

        var sequenceRecords: [HarnessSequenceRecord] = []
        for sequence in HarnessSequenceKind.allCases {
            let plan = try RhythmHarnessPlan.make(sequence: sequence)
            let timed = try await capture(plan: plan)
            let prefix = "402x874-\(sequence.rawValue)"
            let videoName = "\(prefix)-uncut-60fps.mp4"
            try await writeVideo(
                timed: timed,
                plan: plan,
                to: output.appendingPathComponent(videoName)
            )
            let selected = evenlySelected(timed, limit: 24)
            let selectedImages = try selected.map {
                try render(plan: plan, snapshot: $0.snapshot)
            }
            let sheetName = "\(prefix)-contact-sheet.png"
            try writeContactSheet(
                images: selectedImages,
                to: output.appendingPathComponent(sheetName),
                columns: 6,
                cellWidth: 134
            )
            let timelineName = "\(prefix)-timeline.png"
            try writeTimeline(plan: plan, to: output.appendingPathComponent(timelineName))
            sequenceRecords.append(makeSequenceRecord(
                plan: plan,
                timed: timed,
                videoFile: videoName,
                timelineFile: timelineName,
                contactSheetFile: sheetName
            ))
        }

        let manifest = HarnessEvidenceManifest(
            schemaVersion: 2,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            viewport: "402x874",
            timingSource: "CACurrentMediaTime target grid at 60 Hz; each snapshot samples actual capture wallclock before deferred rendering",
            sourceContract: "../card-deal-rhythm-contract-v1/DealRhythmContract.swift",
            sourceContractSHA256: contractSHA256,
            syntheticProgressUsed: false,
            productAudioIncluded: false,
            materialApprovalClaimed: false,
            sourceAssets: [
                "W2CardBack neutral body copied from the current native W2 harness",
                "W2Damage identity-neutral material layer",
            ],
            sequences: sequenceRecords
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

    private static func capture(plan: RhythmHarnessPlan) async throws -> [TimedSnapshot] {
        let frameDuration = 1 / Double(framesPerSecond)
        let frameCount = Int(ceil(plan.evidenceEndSeconds * Double(framesPerSecond))) + 1
        let start = CACurrentMediaTime() + 0.06
        var result: [TimedSnapshot] = []
        result.reserveCapacity(frameCount)
        var previousVisible: Set<Int> = []

        for index in 0..<frameCount {
            let targetElapsed = Double(index) * frameDuration
            try await wait(until: start + targetElapsed)
            let captureTime = CACurrentMediaTime()
            let elapsed = max(0, captureTime - start)
            let snapshot = plan.snapshot(at: elapsed)
            let visible = Set(snapshot.cards.map(\.index))
            let peeled = visible.subtracting(previousVisible).sorted()
            let phases = Dictionary(uniqueKeysWithValues: snapshot.cards.map {
                (String($0.index), $0.phase.rawValue)
            })
            result.append(TimedSnapshot(
                snapshot: snapshot,
                record: HarnessFrameRecord(
                    sequence: plan.sequence.rawValue,
                    frameIndex: index,
                    targetElapsedSeconds: targetElapsed,
                    captureElapsedSeconds: elapsed,
                    captureHostTime: captureTime,
                    activeCardIndices: snapshot.activeCardIndices,
                    activeCount: snapshot.activeCount,
                    visibleCardIndices: visible.sorted(),
                    phasesByCard: phases,
                    peeledCardIndices: peeled,
                    deckCount: snapshot.deckCount
                )
            ))
            previousVisible = visible
        }
        return result
    }

    private static func makeSequenceRecord(
        plan: RhythmHarnessPlan,
        timed: [TimedSnapshot],
        videoFile: String,
        timelineFile: String,
        contactSheetFile: String
    ) -> HarnessSequenceRecord {
        let frames = timed.map(\.record)
        let lifecycle = plan.schedule.indices.map { index in
            let scheduled = plan.schedule[index]
            let pulse = plan.profile.pulses[index]
            return HarnessLifecycleRecord(
                cardIndex: index,
                rhythmPhase: pulse.phase.rawValue,
                rhythmTargetSeconds: scheduled.rhythmTargetSeconds,
                actualStartSeconds: scheduled.actualStartSeconds,
                contactSeconds: scheduled.contactStartSeconds,
                settleSeconds: scheduled.settleStartSeconds,
                restWindowStartSeconds: scheduled.restWindowStartSeconds,
                capturedStartSeconds: firstObserved(
                    card: index,
                    phases: [.travel, .contact, .settle, .rest],
                    timed: timed
                ),
                capturedContactSeconds: firstObserved(
                    card: index,
                    phases: [.contact, .settle, .rest],
                    timed: timed
                ),
                capturedSettleSeconds: firstObserved(
                    card: index,
                    phases: [.settle, .rest],
                    timed: timed
                ),
                capturedRestSeconds: firstObserved(card: index, phases: [.rest], timed: timed),
                routeClass: scheduled.route.rawValue,
                contactClass: scheduled.contact.rawValue
            )
        }
        let maximumAtPeel = frames
            .filter { !$0.peeledCardIndices.isEmpty }
            .map(\.activeCount)
            .max() ?? 0
        let invisibleWait = maximumInvisibleWait(plan: plan)
        return HarnessSequenceRecord(
            sequence: plan.sequence.rawValue,
            captureFramesPerSecond: framesPerSecond,
            uncut: true,
            videoFile: videoFile,
            timelineFile: timelineFile,
            contactSheetFile: contactSheetFile,
            cancellationSeconds: plan.cancellationSeconds,
            cancellationClearSeconds: plan.cancellationDrainCompleteSeconds,
            maximumActiveCards: frames.map(\.activeCount).max() ?? 0,
            maximumActiveCardsAtPeel: maximumAtPeel,
            invisibleWaitSeconds: invisibleWait,
            lifecycle: lifecycle,
            frames: frames
        )
    }

    private static func firstObserved(
        card: Int,
        phases: Set<HarnessCardPhase>,
        timed: [TimedSnapshot]
    ) -> Double? {
        timed.first { item in
            item.snapshot.cards.contains {
                $0.index == card && phases.contains($0.phase)
            }
        }?.record.captureElapsedSeconds
    }

    private static func maximumInvisibleWait(plan: RhythmHarnessPlan) -> Double {
        guard plan.sequence == .reducedMotion else { return 0 }
        var maximum = 0.0
        for index in 1..<plan.schedule.count {
            let priorRest = plan.schedule[..<index].map(\.restWindowStartSeconds).max() ?? 0
            maximum = max(maximum, plan.schedule[index].actualStartSeconds - priorRest)
        }
        return max(0, maximum)
    }

    private static func render(
        plan: RhythmHarnessPlan,
        snapshot: HarnessSnapshot
    ) throws -> UIImage {
        let content = RhythmHarnessStage(plan: plan, snapshot: snapshot)
            .frame(width: viewport.width, height: viewport.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: viewport.width, height: viewport.height)
        guard let image = renderer.uiImage else { throw EvidenceError.renderFailed }
        return image
    }

    private static func evenlySelected(
        _ timed: [TimedSnapshot],
        limit: Int
    ) -> [TimedSnapshot] {
        guard timed.count > limit, limit > 1 else { return timed }
        return (0..<limit).map { index in
            let position = Double(index) * Double(timed.count - 1) / Double(limit - 1)
            return timed[Int(position.rounded())]
        }
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

    private static func writeTimeline(plan: RhythmHarnessPlan, to output: URL) throws {
        let size = CGSize(width: 1200, height: 500)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.035, green: 0.034, blue: 0.043, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let left = 110.0
            let right = 40.0
            let usable = size.width - left - right
            let scale = usable / max(plan.evidenceEndSeconds, 0.001)
            let colors = [
                UIColor(red: 0.34, green: 0.58, blue: 0.86, alpha: 1),
                UIColor(red: 0.90, green: 0.65, blue: 0.28, alpha: 1),
                UIColor(red: 0.67, green: 0.48, blue: 0.84, alpha: 1),
            ]
            for index in plan.schedule.indices {
                let card = plan.schedule[index]
                let durations = plan.durations[index]
                let y = 48 + Double(index) * 52
                NSString(string: "CARD \(index + 1) · \(plan.profile.pulses[index].phase.rawValue.uppercased())")
                    .draw(
                        at: CGPoint(x: 18, y: y - 7),
                        withAttributes: [
                            .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                            .foregroundColor: UIColor.white.withAlphaComponent(0.68),
                        ]
                    )
                let segments = [
                    (card.actualStartSeconds, durations.travelSeconds, colors[0]),
                    (card.contactStartSeconds, durations.contactSeconds, colors[1]),
                    (card.settleStartSeconds, durations.settleSeconds, colors[2]),
                ]
                for segment in segments {
                    let rect = CGRect(
                        x: left + segment.0 * scale,
                        y: y,
                        width: max(2, segment.1 * scale),
                        height: 18
                    )
                    segment.2.setFill()
                    UIBezierPath(roundedRect: rect, cornerRadius: 4).fill()
                }
            }
        }
        guard let data = image.pngData() else { throw EvidenceError.renderFailed }
        try data.write(to: output, options: .atomic)
    }

    private static func writeVideo(
        timed: [TimedSnapshot],
        plan: RhythmHarnessPlan,
        to output: URL
    ) async throws {
        guard let first = timed.first else { throw EvidenceError.videoFailed }
        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(viewport.width),
            AVVideoHeightKey: Int(viewport.height),
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(viewport.width),
                kCVPixelBufferHeightKey as String: Int(viewport.height),
            ]
        )
        guard writer.canAdd(input) else { throw EvidenceError.videoFailed }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? EvidenceError.videoFailed }
        writer.startSession(atSourceTime: .zero)
        guard let pool = adaptor.pixelBufferPool else { throw EvidenceError.videoFailed }
        let firstCapture = first.record.captureElapsedSeconds

        for item in timed {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(2))
            }
            let image = try render(plan: plan, snapshot: item.snapshot)
            var optionalBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
            guard let buffer = optionalBuffer else { throw EvidenceError.videoFailed }
            try draw(image: image, into: buffer)
            let seconds = max(0, item.record.captureElapsedSeconds - firstCapture)
            let time = CMTime(seconds: seconds, preferredTimescale: 60_000)
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw writer.error ?? EvidenceError.videoFailed
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? EvidenceError.videoFailed }
    }

    private static func draw(image: UIImage, into buffer: CVPixelBuffer) throws {
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
        ), let cgImage = image.cgImage else { throw EvidenceError.renderFailed }
        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
    }

    private static func wait(until target: Double) async throws {
        let remaining = target - CACurrentMediaTime()
        if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
    }

    private static func outputDirectory() throws -> URL {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw EvidenceError.outputUnavailable
        }
        return documents.appendingPathComponent("CardDealRhythmEvidenceV3", isDirectory: true)
    }
}

private enum EvidenceError: LocalizedError {
    case outputUnavailable
    case renderFailed
    case videoFailed

    var errorDescription: String? {
        switch self {
        case .outputUnavailable: "Evidence-Ausgabe nicht verfügbar"
        case .renderFailed: "Evidence-Frame konnte nicht gerendert werden"
        case .videoFailed: "Wallclock-Video konnte nicht geschrieben werden"
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
