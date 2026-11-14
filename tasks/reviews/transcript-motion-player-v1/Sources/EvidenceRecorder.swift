import AVFoundation
import QuartzCore
import SwiftUI
import UIKit

struct TranscriptCallbackRecord: Codable, Sendable {
    let name: String
    let elapsedSeconds: Double
}

struct TranscriptFrameRecord: Codable, Sendable {
    let frameIndex: Int
    let targetElapsedSeconds: Double
    let captureElapsedSeconds: Double
    let phase: String
    let moving: Bool
    let contactDelivered: Bool
    let restDelivered: Bool
    let normalizedTime: Double
    let position: MotionPoint
}

struct TranscriptWallclockRecord: Codable, Sendable {
    let requestedFramesPerSecond: Int
    let timingSource: String
    let releaseElapsedSeconds: Double
    let frames: [TranscriptFrameRecord]
    let callbacks: [TranscriptCallbackRecord]
}

struct TranscriptRateSegmentRecord: Codable, Sendable {
    let requestedFramesPerSecond: Int
    let targetIntervalSeconds: Double
    let measuredIntervalsSeconds: [Double]
    let callbackNames: [String]
    let finalPhase: String
    let finalPosition: MotionPoint
}

struct TranscriptCancellationRecord: Codable, Sendable {
    let beforeReleaseCallbackCount: Int
    let beforeReleaseContactCount: Int
    let beforeReleaseRestCount: Int
    let committedCancelIgnored: Bool
    let committedCallbackNames: [String]
    let committedFinalPhase: String
    let committedFinalPosition: MotionPoint
}

struct TranscriptReducedMotionRecord: Codable, Sendable {
    let releaseLatencySeconds: Double
    let callbackNames: [String]
    let finalPhase: String
    let finalPosition: MotionPoint
}

struct TranscriptEvidenceManifest: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let viewport: String
    let productContractPath: String
    let productContractSHA256: String
    let productContractCompiledDirectly: Bool
    let planStableID: String
    let planValid: Bool
    let instantiatedPlanCount: Int
    let rendererNeutralPlayer: Bool
    let productHooksIncluded: Bool
    let audioIncluded: Bool
    let hapticsIncluded: Bool
    let wallclock: TranscriptWallclockRecord
    let rateSegments: [TranscriptRateSegmentRecord]
    let cancellation: TranscriptCancellationRecord
    let reducedMotion: TranscriptReducedMotionRecord
    let videoFile: String
    let contactSheetFile: String
}

@MainActor
private final class CallbackProbe {
    var origin = 0.0
    var events: [TranscriptCallbackRecord] = []

    func record(_ name: String) {
        events.append(TranscriptCallbackRecord(
            name: name,
            elapsedSeconds: max(0, CACurrentMediaTime() - origin)
        ))
    }
}

@MainActor
enum EvidenceRecorder {
    static let viewport = CGSize(width: 402, height: 874)
    private static let standardFramesPerSecond = 60

    private struct TimedSnapshot {
        let snapshot: TranscriptPlaybackSnapshot
        let record: TranscriptFrameRecord
    }

    static func captureAll() async throws {
        let plan = try CertifiedTranscript.validatedPlan()
        let output = try outputDirectory()
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let (wallclock, timed) = try await captureStandard(plan: plan)
        var rateSegments: [TranscriptRateSegmentRecord] = []
        for framesPerSecond in [60, 80, 120] {
            rateSegments.append(try await captureRateSegment(
                plan: plan,
                framesPerSecond: framesPerSecond
            ))
        }
        let cancellation = try captureCancellation(plan: plan)
        let reducedMotion = try captureReducedMotion(plan: plan)

        let videoFile = "402x874-standard-wallclock-uncut-60fps.mp4"
        try await writeVideo(
            timed: timed,
            to: output.appendingPathComponent(videoFile)
        )
        let contactSheetFile = "402x874-standard-wallclock-contact-sheet.png"
        try writeContactSheet(
            timed: evenlySelected(timed, limit: 18),
            to: output.appendingPathComponent(contactSheetFile)
        )

        let manifest = TranscriptEvidenceManifest(
            schemaVersion: 1,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            viewport: "402x874",
            productContractPath: "App/MotionPlaybackPlan.swift",
            productContractSHA256: CertifiedTranscript.sourceContractSHA256,
            productContractCompiledDirectly: true,
            planStableID: plan.stableID,
            planValid: plan.isValid,
            instantiatedPlanCount: 1,
            rendererNeutralPlayer: true,
            productHooksIncluded: false,
            audioIncluded: false,
            hapticsIncluded: false,
            wallclock: wallclock,
            rateSegments: rateSegments,
            cancellation: cancellation,
            reducedMotion: reducedMotion,
            videoFile: videoFile,
            contactSheetFile: contactSheetFile
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

    private static func captureStandard(
        plan: MotionPlaybackPlan
    ) async throws -> (TranscriptWallclockRecord, [TimedSnapshot]) {
        let probe = CallbackProbe()
        guard let player = TranscriptMotionPlayer(
            plan: plan,
            mode: .standard,
            onContact: { probe.record("onContact") },
            onRest: { probe.record("onRest") },
            onCancelBeforeRelease: { probe.record("onCancelBeforeRelease") }
        ) else { throw EvidenceError.invalidPlayer }

        let frameDuration = 1 / Double(standardFramesPerSecond)
        let releaseDelay = 0.10
        let end = releaseDelay + plan.restWindow.startTimeSeconds + 0.18
        let frameCount = Int(ceil(end / frameDuration)) + 1
        let start = CACurrentMediaTime() + 0.05
        probe.origin = start
        var releaseElapsed = 0.0
        var released = false
        var timed: [TimedSnapshot] = []

        for index in 0..<frameCount {
            let targetElapsed = Double(index) * frameDuration
            try await wait(until: start + targetElapsed)
            let captureTime = CACurrentMediaTime()
            let captureElapsed = max(0, captureTime - start)
            if !released, captureElapsed >= releaseDelay {
                released = true
                releaseElapsed = captureElapsed
                _ = player.release(at: captureTime)
            }
            let snapshot = player.advance(to: captureTime)
            let record = TranscriptFrameRecord(
                frameIndex: index,
                targetElapsedSeconds: targetElapsed,
                captureElapsedSeconds: captureElapsed,
                phase: snapshot.phase.rawValue,
                moving: snapshot.isMoving,
                contactDelivered: snapshot.contactDelivered,
                restDelivered: snapshot.restDelivered,
                normalizedTime: snapshot.sample.normalizedTime,
                position: snapshot.sample.position
            )
            timed.append(TimedSnapshot(snapshot: snapshot, record: record))
        }
        return (
            TranscriptWallclockRecord(
                requestedFramesPerSecond: standardFramesPerSecond,
                timingSource: "CACurrentMediaTime sampled against an absolute 60 Hz target grid; rendering deferred",
                releaseElapsedSeconds: releaseElapsed,
                frames: timed.map(\.record),
                callbacks: probe.events
            ),
            timed
        )
    }

    private static func captureRateSegment(
        plan: MotionPlaybackPlan,
        framesPerSecond: Int
    ) async throws -> TranscriptRateSegmentRecord {
        let probe = CallbackProbe()
        guard let player = TranscriptMotionPlayer(
            plan: plan,
            mode: .standard,
            onContact: { probe.record("onContact") },
            onRest: { probe.record("onRest") },
            onCancelBeforeRelease: { probe.record("onCancelBeforeRelease") }
        ) else { throw EvidenceError.invalidPlayer }
        let interval = 1 / Double(framesPerSecond)
        let frameCount = Int(ceil((plan.restWindow.startTimeSeconds + 0.08) / interval)) + 1
        let start = CACurrentMediaTime() + 0.04
        probe.origin = start
        var captures: [Double] = []
        var finalSnapshot = player.release(at: start)
        for index in 0..<frameCount {
            try await wait(until: start + Double(index) * interval)
            let now = CACurrentMediaTime()
            captures.append(now)
            finalSnapshot = player.advance(to: now)
        }
        return TranscriptRateSegmentRecord(
            requestedFramesPerSecond: framesPerSecond,
            targetIntervalSeconds: interval,
            measuredIntervalsSeconds: zip(captures, captures.dropFirst()).map { $1 - $0 },
            callbackNames: probe.events.map(\.name),
            finalPhase: finalSnapshot.phase.rawValue,
            finalPosition: finalSnapshot.sample.position
        )
    }

    private static func captureCancellation(
        plan: MotionPlaybackPlan
    ) throws -> TranscriptCancellationRecord {
        let beforeProbe = CallbackProbe()
        guard let before = TranscriptMotionPlayer(
            plan: plan,
            mode: .standard,
            onContact: { beforeProbe.record("onContact") },
            onRest: { beforeProbe.record("onRest") },
            onCancelBeforeRelease: { beforeProbe.record("onCancelBeforeRelease") }
        ) else { throw EvidenceError.invalidPlayer }
        beforeProbe.origin = CACurrentMediaTime()
        _ = before.cancel(at: 10)
        _ = before.cancel(at: 10.1)

        let committedProbe = CallbackProbe()
        guard let committed = TranscriptMotionPlayer(
            plan: plan,
            mode: .standard,
            onContact: { committedProbe.record("onContact") },
            onRest: { committedProbe.record("onRest") },
            onCancelBeforeRelease: { committedProbe.record("onCancelBeforeRelease") }
        ) else { throw EvidenceError.invalidPlayer }
        committedProbe.origin = CACurrentMediaTime()
        _ = committed.release(at: 20)
        _ = committed.advance(to: 20.22)
        let cancelled = committed.cancel(at: 20.22)
        _ = committed.advance(to: 20 + plan.contact.timeSeconds)
        let final = committed.advance(to: 20 + plan.restWindow.startTimeSeconds)

        return TranscriptCancellationRecord(
            beforeReleaseCallbackCount: beforeProbe.events.filter {
                $0.name == "onCancelBeforeRelease"
            }.count,
            beforeReleaseContactCount: beforeProbe.events.filter { $0.name == "onContact" }.count,
            beforeReleaseRestCount: beforeProbe.events.filter { $0.name == "onRest" }.count,
            committedCancelIgnored: cancelled.committedCancelIgnored,
            committedCallbackNames: committedProbe.events.map(\.name),
            committedFinalPhase: final.phase.rawValue,
            committedFinalPosition: final.sample.position
        )
    }

    private static func captureReducedMotion(
        plan: MotionPlaybackPlan
    ) throws -> TranscriptReducedMotionRecord {
        let probe = CallbackProbe()
        guard let player = TranscriptMotionPlayer(
            plan: plan,
            mode: .reducedMotion,
            onContact: { probe.record("onContact") },
            onRest: { probe.record("onRest") },
            onCancelBeforeRelease: { probe.record("onCancelBeforeRelease") }
        ) else { throw EvidenceError.invalidPlayer }
        let start = CACurrentMediaTime()
        probe.origin = start
        let final = player.release(at: start)
        let latency = CACurrentMediaTime() - start
        return TranscriptReducedMotionRecord(
            releaseLatencySeconds: latency,
            callbackNames: probe.events.map(\.name),
            finalPhase: final.phase.rawValue,
            finalPosition: final.sample.position
        )
    }

    private static func render(_ item: TimedSnapshot) throws -> UIImage {
        let content = TranscriptHarnessStage(
            snapshot: item.snapshot,
            elapsedSeconds: item.record.captureElapsedSeconds
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: viewport.width, height: viewport.height)
        guard let image = renderer.uiImage,
              Int(image.size.width) == Int(viewport.width),
              Int(image.size.height) == Int(viewport.height) else {
            throw EvidenceError.renderFailed
        }
        return image
    }

    private static func writeContactSheet(timed: [TimedSnapshot], to output: URL) throws {
        let images = try timed.map(render)
        let columns = 6
        let cellWidth = 134
        let cellHeight = Int(round(Double(cellWidth) * 874 / 402))
        let rows = Int(ceil(Double(images.count) / Double(columns)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: columns * cellWidth, height: rows * cellHeight),
            format: format
        )
        let sheet = renderer.image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: columns * cellWidth, height: rows * cellHeight))
            for (index, image) in images.enumerated() {
                image.draw(in: CGRect(
                    x: (index % columns) * cellWidth,
                    y: (index / columns) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                ))
            }
        }
        guard let data = sheet.pngData() else { throw EvidenceError.renderFailed }
        try data.write(to: output, options: .atomic)
    }

    private static func writeVideo(timed: [TimedSnapshot], to output: URL) async throws {
        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(viewport.width),
                AVVideoHeightKey: Int(viewport.height),
            ]
        )
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

        for (index, item) in timed.enumerated() {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(2))
            }
            var optionalBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
            guard let buffer = optionalBuffer else { throw EvidenceError.videoFailed }
            try draw(image: render(item), into: buffer)
            let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(standardFramesPerSecond))
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
        context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
    }

    private static func evenlySelected(_ values: [TimedSnapshot], limit: Int) -> [TimedSnapshot] {
        guard values.count > limit, limit > 1 else { return values }
        return (0..<limit).map { index in
            values[Int(round(Double(index) * Double(values.count - 1) / Double(limit - 1)))]
        }
    }

    private static func wait(until target: Double) async throws {
        let remaining = target - CACurrentMediaTime()
        if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
    }

    private static func outputDirectory() throws -> URL {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { throw EvidenceError.outputUnavailable }
        return documents.appendingPathComponent("TranscriptMotionPlayerV1", isDirectory: true)
    }
}

private enum EvidenceError: LocalizedError {
    case outputUnavailable
    case invalidPlayer
    case renderFailed
    case videoFailed

    var errorDescription: String? {
        switch self {
        case .outputUnavailable: "Evidence-Ausgabe nicht verfügbar"
        case .invalidPlayer: "TranscriptMotionPlayer lehnte den Plan ab"
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
