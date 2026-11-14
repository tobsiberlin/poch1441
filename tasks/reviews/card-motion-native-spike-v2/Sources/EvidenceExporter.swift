import QuartzCore
import SwiftUI
import UIKit

struct FixedEvidenceManifest: Codable, Sendable {
    struct Frame: Codable, Sendable {
        let file: String
        let width: Int
        let height: Int
        let segment: String
        let progress: Double
    }

    let generatedAt: String
    let frames: [Frame]
    let sourceAssets: [String]
}

struct RealtimeContactSheetResult: Codable, Sendable {
    let requestedFramesPerSecond: Double
    let effectiveFramesPerSecond: Double
    let frameCount: Int
    let durationSeconds: Double
    let missedDeadlineCount: Int
    let maximumLatenessMilliseconds: Double
    let file: String
}

@MainActor
enum EvidenceExporter {
    static func exportAll() async throws {
        let output = try outputDirectory()
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try exportFixedFrames(to: output)
        try await exportRealtimeContactSheet(to: output)
        try Data("complete\n".utf8).write(
            to: output.appendingPathComponent("export.complete"),
            options: .atomic
        )
    }

    private static func exportFixedFrames(to output: URL) throws {
        let viewports = [
            (name: "390x844", width: 390, height: 844),
            (name: "667x375", width: 667, height: 375),
            (name: "402x874", width: 402, height: 874),
        ]
        let progresses = [0.0, 0.25, 0.5, 0.75, 1.0]
        var frames: [FixedEvidenceManifest.Frame] = []

        for viewport in viewports {
            for segment in CardMotionSegment.allCases {
                for progress in progresses {
                    let image = try render(
                        segment: segment,
                        progress: progress,
                        width: viewport.width,
                        height: viewport.height
                    )
                    let suffix = String(format: "%03d", Int(progress * 100))
                    let fileName = "\(viewport.name)-\(segment.rawValue)-progress-\(suffix).png"
                    guard let data = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
                    try data.write(to: output.appendingPathComponent(fileName), options: .atomic)
                    frames.append(.init(
                        file: fileName,
                        width: viewport.width,
                        height: viewport.height,
                        segment: segment.rawValue,
                        progress: progress
                    ))
                }
            }
        }

        let manifest = FixedEvidenceManifest(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            frames: frames,
            sourceAssets: [
                "App/CardBack.swift + App/CardMaterialContract.swift (W2)",
                "App/Assets.xcassets/CardBackDamage/card_back_damage_04.imageset",
                "App/Assets.xcassets/Cards/card_hearts_ace.imageset (public V10 face)",
            ]
        )
        try JSONEncoder.pretty.encode(manifest).write(
            to: output.appendingPathComponent("manifest.json"),
            options: .atomic
        )
    }

    private static func exportRealtimeContactSheet(to output: URL) async throws {
        let framesPerSegment = 16
        let requestedFPS = 24.0
        let segments = CardMotionSegment.allCases
        let frameCount = framesPerSegment * segments.count
        var images: [UIImage] = []
        images.reserveCapacity(frameCount)
        var timestamps: [CFTimeInterval] = []
        var missedDeadlines = 0
        var maximumLateness = 0.0
        let start = CACurrentMediaTime()

        for frameIndex in 0..<frameCount {
            let target = start + Double(frameIndex) / requestedFPS
            let remaining = target - CACurrentMediaTime()
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            let actual = CACurrentMediaTime()
            let lateness = max(0, actual - target)
            if lateness > 1 / requestedFPS {
                missedDeadlines += 1
            }
            maximumLateness = max(maximumLateness, lateness)
            timestamps.append(actual)
            let segmentIndex = frameIndex / framesPerSegment
            let localIndex = frameIndex % framesPerSegment
            let progress = Double(localIndex) / Double(framesPerSegment - 1)
            images.append(try render(
                segment: segments[segmentIndex],
                progress: progress,
                width: 402,
                height: 874
            ))
        }

        let columns = 8
        let rows = Int(ceil(Double(images.count) / Double(columns)))
        let cellSize = CGSize(width: 134, height: 291.333_333)
        let sheetSize = CGSize(width: cellSize.width * Double(columns), height: cellSize.height * Double(rows))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: sheetSize, format: format)
        let sheet = renderer.image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: sheetSize))
            for (index, image) in images.enumerated() {
                let column = index % columns
                let row = index / columns
                image.draw(in: CGRect(
                    x: Double(column) * cellSize.width,
                    y: Double(row) * cellSize.height,
                    width: cellSize.width,
                    height: cellSize.height
                ))
            }
        }
        let fileName = "realtime-contact-sheet-402x874.png"
        guard let sheetData = sheet.pngData() else { throw CocoaError(.fileWriteUnknown) }
        try sheetData.write(to: output.appendingPathComponent(fileName), options: .atomic)

        let duration = max(0.000_001, (timestamps.last ?? start) - (timestamps.first ?? start))
        let result = RealtimeContactSheetResult(
            requestedFramesPerSecond: requestedFPS,
            effectiveFramesPerSecond: Double(max(0, timestamps.count - 1)) / duration,
            frameCount: images.count,
            durationSeconds: duration,
            missedDeadlineCount: missedDeadlines,
            maximumLatenessMilliseconds: maximumLateness * 1_000,
            file: fileName
        )
        try JSONEncoder.pretty.encode(result).write(
            to: output.appendingPathComponent("realtime-contact-sheet.json"),
            options: .atomic
        )
    }

    private static func render(
        segment: CardMotionSegment,
        progress: Double,
        width: Int,
        height: Int
    ) throws -> UIImage {
        let content = CardMotionStage(segment: segment, progress: progress)
            .frame(width: CGFloat(width), height: CGFloat(height))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: CGFloat(width), height: CGFloat(height))
        guard let image = renderer.uiImage else { throw CocoaError(.fileWriteUnknown) }
        return image
    }

    private static func outputDirectory() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return documents.appendingPathComponent("CardMotionEvidenceV2", isDirectory: true)
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

