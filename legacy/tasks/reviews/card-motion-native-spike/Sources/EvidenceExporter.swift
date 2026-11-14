import SwiftUI
import UIKit

struct EvidenceManifest: Codable, Sendable {
    struct Frame: Codable, Sendable {
        let file: String
        let width: Int
        let height: Int
        let progress: Double
    }

    let generatedAt: String
    let frames: [Frame]
    let sourceAssets: [String]
}

@MainActor
enum EvidenceExporter {
    static func export() throws {
        let fileManager = FileManager.default
        let output = try outputDirectory()
        try fileManager.createDirectory(at: output, withIntermediateDirectories: true)

        let viewports = [
            (name: "390x844", width: 390, height: 844),
            (name: "667x375", width: 667, height: 375),
            (name: "402x874", width: 402, height: 874),
        ]
        let progresses = [0.0, 0.25, 0.5, 0.75, 1.0]
        var frames: [EvidenceManifest.Frame] = []

        for viewport in viewports {
            for progress in progresses {
                let reveal = min(max((progress - 0.34) / 0.32, 0), 1)
                let content = CardMotionStage(
                    progress: progress,
                    revealProgress: reveal,
                    phaseLabel: progress < 0.34 ? "DEAL" : progress < 0.7 ? "REVEAL" : "PLAY"
                )
                .frame(width: CGFloat(viewport.width), height: CGFloat(viewport.height))

                let renderer = ImageRenderer(content: content)
                renderer.scale = 1
                renderer.proposedSize = ProposedViewSize(
                    width: CGFloat(viewport.width),
                    height: CGFloat(viewport.height)
                )
                guard let image = renderer.uiImage,
                      let data = image.pngData() else {
                    throw CocoaError(.fileWriteUnknown)
                }
                let suffix = String(format: "%03d", Int(progress * 100))
                let fileName = "\(viewport.name)-progress-\(suffix).png"
                try data.write(to: output.appendingPathComponent(fileName), options: .atomic)
                frames.append(.init(
                    file: fileName,
                    width: viewport.width,
                    height: viewport.height,
                    progress: progress
                ))
            }
        }

        let formatter = ISO8601DateFormatter()
        let manifest = EvidenceManifest(
            generatedAt: formatter.string(from: Date()),
            frames: frames,
            sourceAssets: [
                "App/CardBack.swift + App/CardMaterialContract.swift (W2 geometry)",
                "App/Assets.xcassets/CardBackDamage/card_back_damage_04.imageset",
                "App/Assets.xcassets/Cards/card_hearts_ace.imageset (public V10 face)",
            ]
        )
        let manifestData = try JSONEncoder.pretty.encode(manifest)
        try manifestData.write(to: output.appendingPathComponent("manifest.json"), options: .atomic)
        try Data("complete\n".utf8).write(
            to: output.appendingPathComponent("export.complete"),
            options: .atomic
        )
    }

    private static func outputDirectory() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return documents.appendingPathComponent("CardMotionEvidence", isDirectory: true)
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
