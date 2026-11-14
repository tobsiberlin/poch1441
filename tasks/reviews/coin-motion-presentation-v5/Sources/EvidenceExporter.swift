import Foundation
import os
import UIKit

struct FrameEvidence: Codable, Sendable {
    let viewport: String
    let frame: Int
    let time: Double
    let segment: CoinSegment
    let centerX: Double
    let centerY: Double
    let shadowCenterX: Double
    let shadowCenterY: Double
    let bottomGapMillimeters: Double
    let speedMetersPerSecond: Double
    let angularSpeedRadiansPerSecond: Double
    let collisionCount: Int
    let coinDrawCount: Int
    let coinBoundsInsideViewport: Bool
}

struct EvidenceManifest: Codable, Sendable {
    let generatedAt: String
    let projectGeometry: String
    let physicalCoin: String
    let framesPerSecond: Int
    let uncutSequences: [String: Int]
    let repeatedSeeds: [UInt64]
    let metrics: [CoinMotionMetrics]
    let minimumBottomGapMillimeters: Double
    let maximumCoinDrawCount: Int
    let allRestPointsInsideSafeZone: Bool
    let allEnergyRatiosBelowOne: Bool
    let reducedMotionHasInvisibleWait: Bool
}

@MainActor
enum EvidenceExporter {
    private static let log = Logger(
        subsystem: "com.tobc.reviews.coin-motion-presentation-v5",
        category: "Evidence"
    )

    static func exportAll() async {
        guard let renderer = CoinSceneRenderer() else {
            log.error("Renderer resources unavailable")
            return
        }
        let root = documentsURL.appendingPathComponent("CoinMotionEvidenceV5", isDirectory: true)
        do {
            if FileManager.default.fileExists(atPath: root.path) {
                try FileManager.default.removeItem(at: root)
            }
            try FileManager.default.createDirectory(at: root,
                                                    withIntermediateDirectories: true)
            let primaryPlan = CoinMotionPlan(seed: 1_441)
            var traces: [FrameEvidence] = []
            var sequenceCounts: [String: Int] = [:]
            for viewport in CoinViewport.required {
                let directory = root
                    .appendingPathComponent("uncut", isDirectory: true)
                    .appendingPathComponent(viewport.name, isDirectory: true)
                try FileManager.default.createDirectory(at: directory,
                                                        withIntermediateDirectories: true)
                let count = Int(ceil(primaryPlan.duration * 60)) + 1
                sequenceCounts[viewport.name] = count
                var viewportTrace: [FrameEvidence] = []
                for frame in 0..<count {
                    let time = Double(frame) / 60
                    let result = renderer.render(viewport: viewport,
                                                 plan: primaryPlan,
                                                 time: time)
                    let state = primaryPlan.state(at: time)
                    let frameURL = directory.appendingPathComponent(
                        String(format: "frame-%03d.png", frame)
                    )
                    try pngData(result.image).write(to: frameURL, options: .atomic)
                    let viewportBounds = CGRect(x: 0, y: 0,
                                                width: viewport.width,
                                                height: viewport.height)
                    let evidence = FrameEvidence(
                        viewport: viewport.name,
                        frame: frame,
                        time: time,
                        segment: state.segment,
                        centerX: result.coinCenter.x,
                        centerY: result.coinCenter.y,
                        shadowCenterX: result.shadowCenter.x,
                        shadowCenterY: result.shadowCenter.y,
                        bottomGapMillimeters: state.bottomGap * 1_000,
                        speedMetersPerSecond: state.linearVelocity.length,
                        angularSpeedRadiansPerSecond: state.angularVelocity.length,
                        collisionCount: state.collisionCount,
                        coinDrawCount: result.drawCount,
                        coinBoundsInsideViewport: viewportBounds.contains(result.coinBounds)
                    )
                    traces.append(evidence)
                    viewportTrace.append(evidence)
                }
                try JSONEncoder.pretty.encode(viewportTrace).write(
                    to: directory.appendingPathComponent("frame-trace.json"),
                    options: .atomic
                )
                try exportContactCrops(renderer: renderer,
                                       viewport: viewport,
                                       plan: primaryPlan,
                                       directory: directory)
                try exportSequenceSheet(renderer: renderer,
                                        viewport: viewport,
                                        plan: primaryPlan,
                                        directory: directory)
            }

            let plans = (0..<10).map { CoinMotionPlan(seed: 1_441 + UInt64($0) * 97) }
            try exportRepeatedThrows(renderer: renderer, plans: plans, root: root)
            try exportReducedMotion(renderer: renderer, plan: primaryPlan, root: root)

            let metrics = plans.map(\.metrics)
            let manifest = EvidenceManifest(
                generatedAt: ISO8601DateFormatter().string(from: Date()),
                projectGeometry: "Track B world-master 941x1672; active top-right well at source px (648,704); Safe-Zone radius 12.5 mm",
                physicalCoin: "1 Euro cent: radius 8.125 mm; thickness 1.67 mm; mass 2.30 g; current TravelCent0...5 artwork",
                framesPerSecond: 60,
                uncutSequences: sequenceCounts,
                repeatedSeeds: plans.map(\.seed),
                metrics: metrics,
                minimumBottomGapMillimeters: traces.map(\.bottomGapMillimeters).min() ?? 0,
                maximumCoinDrawCount: traces.map(\.coinDrawCount).max() ?? 0,
                allRestPointsInsideSafeZone: metrics.allSatisfy {
                    $0.safeZoneDistance <= CoinMotionPlan.safeZoneRadius
                },
                allEnergyRatiosBelowOne: metrics.allSatisfy {
                    $0.postContactEnergy < $0.preContactEnergy
                },
                reducedMotionHasInvisibleWait: false
            )
            try JSONEncoder.pretty.encode(manifest).write(
                to: root.appendingPathComponent("manifest.json"),
                options: .atomic
            )
            try Data("complete".utf8).write(
                to: root.appendingPathComponent("export.complete"),
                options: .atomic
            )
        } catch {
            log.error("Evidence export failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func exportContactCrops(renderer: CoinSceneRenderer,
                                           viewport: CoinViewport,
                                           plan: CoinMotionPlan,
                                           directory: URL) throws {
        let times = [
            max(0, plan.firstContactTime - 2.0 / 60),
            max(0, plan.firstContactTime - 1.0 / 60),
            plan.firstContactTime,
            plan.firstContactTime + 1.0 / 60,
            plan.secondContactTime,
            plan.slideStartTime,
            plan.restTime,
        ]
        let cropDirectory = directory.appendingPathComponent("contact-crops", isDirectory: true)
        try FileManager.default.createDirectory(at: cropDirectory,
                                                withIntermediateDirectories: true)
        var crops: [UIImage] = []
        for (index, time) in times.enumerated() {
            let result = renderer.render(viewport: viewport, plan: plan, time: time)
            guard let crop = crop(image: result.image,
                                  around: result.coinCenter,
                                  outputSide: min(160, viewport.height)) else { continue }
            crops.append(crop)
            try pngData(crop).write(
                to: cropDirectory.appendingPathComponent(String(format: "crop-%02d.png", index)),
                options: .atomic
            )
        }
        let sheet = horizontalSheet(images: crops, cellSide: 160)
        try pngData(sheet).write(to: directory.appendingPathComponent("contact-sheet.png"),
                                 options: .atomic)
    }

    private static func exportSequenceSheet(renderer: CoinSceneRenderer,
                                            viewport: CoinViewport,
                                            plan: CoinMotionPlan,
                                            directory: URL) throws {
        let fractions: [Double] = [0, 0.18, 0.36, 0.52, 0.70, 0.86, 1]
        let images = fractions.map {
            renderer.render(viewport: viewport,
                            plan: plan,
                            time: plan.duration * $0).image
        }
        let width = min(160, viewport.width)
        let height = max(1, Int(Double(width) * Double(viewport.height) / Double(viewport.width)))
        let sheet = horizontalSheet(images: images,
                                    cellSize: CGSize(width: width, height: height))
        try pngData(sheet).write(to: directory.appendingPathComponent("sequence-sheet.png"),
                                 options: .atomic)
    }

    private static func exportRepeatedThrows(renderer: CoinSceneRenderer,
                                             plans: [CoinMotionPlan],
                                             root: URL) throws {
        let directory = root.appendingPathComponent("repeated-throws", isDirectory: true)
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        let viewport = CoinViewport(name: "402x874", width: 402, height: 874)
        var rows: [UIImage] = []
        for plan in plans {
            let times = [
                0,
                plan.firstContactTime * 0.55,
                max(0, plan.firstContactTime - 1.0 / 60),
                plan.firstContactTime,
                plan.secondContactTime,
                plan.restTime,
            ]
            let crops = times.compactMap { time -> UIImage? in
                let result = renderer.render(viewport: viewport, plan: plan, time: time)
                return crop(image: result.image, around: result.coinCenter, outputSide: 112)
            }
            let row = horizontalSheet(images: crops, cellSide: 112)
            rows.append(row)
            try pngData(row).write(
                to: directory.appendingPathComponent("seed-\(plan.seed)-strip.png"),
                options: .atomic
            )
        }
        let montage = verticalSheet(images: rows)
        try pngData(montage).write(
            to: directory.appendingPathComponent("ten-seed-rhythm-sheet.png"),
            options: .atomic
        )
        try JSONEncoder.pretty.encode(plans.map(\.metrics)).write(
            to: directory.appendingPathComponent("ten-seed-metrics.json"),
            options: .atomic
        )
    }

    private static func exportReducedMotion(renderer: CoinSceneRenderer,
                                            plan: CoinMotionPlan,
                                            root: URL) throws {
        let viewport = CoinViewport(name: "402x874", width: 402, height: 874)
        let result = renderer.render(viewport: viewport,
                                     plan: plan,
                                     time: 0,
                                     reducedMotion: true)
        try pngData(result.image).write(
            to: root.appendingPathComponent("reduced-motion-immediate-rest.png"),
            options: .atomic
        )
        let state = plan.state(at: 0, reducedMotion: true)
        let payload: [String: Any] = [
            "latencyMilliseconds": 0,
            "segment": state.segment.rawValue,
            "positionMovement": false,
            "invisibleWait": false,
            "explanation": "The value change and final resting coin are committed in the initiating frame; only movement and impact feedback are omitted.",
        ]
        let data = try JSONSerialization.data(withJSONObject: payload,
                                              options: [.prettyPrinted, .sortedKeys])
        try data.write(to: root.appendingPathComponent("reduced-motion.json"),
                       options: .atomic)
    }

    private static func crop(image: UIImage,
                             around center: CGPoint,
                             outputSide: Int) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let side = min(CGFloat(outputSide), CGFloat(cgImage.width), CGFloat(cgImage.height))
        let x = min(max(0, center.x - side * 0.5), CGFloat(cgImage.width) - side)
        let y = min(max(0, center.y - side * 0.5), CGFloat(cgImage.height) - side)
        guard let result = cgImage.cropping(to: CGRect(x: x, y: y, width: side, height: side)) else {
            return nil
        }
        return UIImage(cgImage: result, scale: 1, orientation: .up)
    }

    private static func horizontalSheet(images: [UIImage], cellSide: Int) -> UIImage {
        horizontalSheet(images: images,
                        cellSize: CGSize(width: cellSide, height: cellSide))
    }

    private static func horizontalSheet(images: [UIImage], cellSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: cellSize.width * CGFloat(max(images.count, 1)),
                          height: cellSize.height)
        return UIGraphicsImageRenderer(size: size, format: format).image { output in
            output.cgContext.setFillColor(UIColor(red: 0.025, green: 0.020, blue: 0.018, alpha: 1).cgColor)
            output.cgContext.fill(CGRect(origin: .zero, size: size))
            for (index, image) in images.enumerated() {
                image.draw(in: CGRect(x: CGFloat(index) * cellSize.width,
                                      y: 0,
                                      width: cellSize.width,
                                      height: cellSize.height))
            }
        }
    }

    private static func verticalSheet(images: [UIImage]) -> UIImage {
        guard let first = images.first else { return UIImage() }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: first.size.width,
                          height: images.reduce(0) { $0 + $1.size.height })
        return UIGraphicsImageRenderer(size: size, format: format).image { output in
            output.cgContext.setFillColor(UIColor.black.cgColor)
            output.cgContext.fill(CGRect(origin: .zero, size: size))
            var y: CGFloat = 0
            for image in images {
                image.draw(at: CGPoint(x: 0, y: y))
                y += image.size.height
            }
        }
    }

    private static func pngData(_ image: UIImage) throws -> Data {
        guard let data = image.pngData() else { throw EvidenceError.pngEncoding }
        return data
    }

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

private enum EvidenceError: Error {
    case pngEncoding
}
