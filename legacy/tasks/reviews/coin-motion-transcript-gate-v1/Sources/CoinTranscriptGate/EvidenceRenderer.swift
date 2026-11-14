import AppKit
import Foundation

struct WorldLightProfile: Encodable, Sendable {
    let id = "track-b-lamp-left-v1"
    let keyDirectionScreen = Vector3(x: -0.72, y: -0.58, z: 0.38)
    let shadowOffsetPixels = Vector3(x: 2.4, y: 3.2, z: 0)
    let shadowBlurPixels = 2.2
    let ambientStrength = 0.22
}

struct VisualEvidenceReceipt: Encodable, Sendable {
    let output = "Evidence/402x874-track-b-queen-contact.png"
    let viewportWidth: Int
    let viewportHeight: Int
    let worldAsset: String
    let coinAsset: String
    let lightProfile: WorldLightProfile
    let separateGroundShadowLayer: Bool
    let frontLipOcclusionRecomposited: Bool
    let materialSignature: String
}

enum EvidenceRenderer {
    static func render(restingState: CoinState) throws -> VisualEvidenceReceipt {
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let repository = current.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let worldURL = repository.appendingPathComponent(
            "tasks/reviews/track-b-screen-mockup-assets/world-master-snackbox-v3-clean-mug.png"
        )
        let coinURL = repository.appendingPathComponent(
            "App/Assets.xcassets/TravelCent0.imageset/travel-cent-0.png"
        )
        guard let world = NSImage(contentsOf: worldURL),
              let coin = NSImage(contentsOf: coinURL) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let width = 402
        let height = 874
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw CocoaError(.coderInvalidValue)
        }
        representation.size = NSSize(width: width, height: height)
        guard let graphics = NSGraphicsContext(bitmapImageRep: representation) else {
            throw CocoaError(.coderInvalidValue)
        }

        let sourceSize = world.size
        let scale = max(CGFloat(width) / sourceSize.width,
                        CGFloat(height) / sourceSize.height)
        let worldRect = CGRect(
            x: (CGFloat(width) - sourceSize.width * scale) * 0.5,
            y: (CGFloat(height) - sourceSize.height * scale) * 0.5,
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        let sourceCenter = CGPoint(x: 648, y: sourceSize.height - 704)
        let projectedCenter = CGPoint(
            x: worldRect.minX + sourceCenter.x * scale
                + restingState.position.x / 0.049 * 51,
            y: worldRect.minY + sourceCenter.y * scale
                - restingState.position.y / 0.039 * 40
        )
        let light = WorldLightProfile()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        graphics.imageInterpolation = .high
        world.draw(in: worldRect,
                   from: CGRect(origin: .zero, size: sourceSize),
                   operation: .copy,
                   fraction: 1)

        drawGroundShadow(center: projectedCenter, light: light)
        drawCoinThickness(center: projectedCenter)
        drawCoin(coin, center: projectedCenter, yaw: restingState.orientation.yaw)
        recomposeFrontLip(world: world,
                          worldRect: worldRect,
                          sourceSize: sourceSize,
                          center: projectedCenter)
        NSGraphicsContext.restoreGraphicsState()

        guard let png = representation.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let evidenceDirectory = current.appendingPathComponent("Evidence", isDirectory: true)
        try FileManager.default.createDirectory(at: evidenceDirectory,
                                                withIntermediateDirectories: true)
        try png.write(to: evidenceDirectory
            .appendingPathComponent("402x874-track-b-queen-contact.png"),
                      options: .atomic)

        let receipt = VisualEvidenceReceipt(
            viewportWidth: width,
            viewportHeight: height,
            worldAsset: "track-b-screen-mockup-assets/world-master-snackbox-v3-clean-mug.png",
            coinAsset: "App/Assets.xcassets/TravelCent0.imageset/travel-cent-0.png",
            lightProfile: light,
            separateGroundShadowLayer: true,
            frontLipOcclusionRecomposited: true,
            materialSignature: "aged real copper on aged smoke-clear polycarbonate"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(receipt).write(
            to: evidenceDirectory.appendingPathComponent("visual-evidence-receipt.json"),
            options: .atomic
        )
        return receipt
    }

    private static func drawGroundShadow(center: CGPoint,
                                         light: WorldLightProfile) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(width: light.shadowOffsetPixels.x,
                                     height: -light.shadowOffsetPixels.y)
        shadow.shadowBlurRadius = light.shadowBlurPixels
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.62)
        shadow.set()
        NSColor.black.withAlphaComponent(0.18).setFill()
        NSBezierPath(ovalIn: CGRect(x: center.x - 10.8,
                                    y: center.y - 5.1,
                                    width: 23.4,
                                    height: 10.2)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawCoinThickness(center: CGPoint) {
        let edge = NSBezierPath(ovalIn: CGRect(x: center.x - 10.9,
                                              y: center.y - 7.1,
                                              width: 21.8,
                                              height: 12.8))
        NSColor(calibratedRed: 0.27, green: 0.095, blue: 0.035, alpha: 0.96).setFill()
        edge.fill()
        NSColor(calibratedWhite: 0.08, alpha: 0.62).setStroke()
        edge.lineWidth = 0.6
        edge.stroke()
    }

    private static func drawCoin(_ image: NSImage,
                                 center: CGPoint,
                                 yaw: Double) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y + 1.1)
        transform.rotate(byRadians: yaw)
        transform.scaleX(by: 1, yBy: 0.61)
        transform.concat()
        image.draw(in: CGRect(x: -11.2, y: -11.2, width: 22.4, height: 22.4),
                   from: CGRect(origin: .zero, size: image.size),
                   operation: .sourceOver,
                   fraction: 0.93)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func recomposeFrontLip(world: NSImage,
                                           worldRect: CGRect,
                                           sourceSize: CGSize,
                                           center: CGPoint) {
        NSGraphicsContext.saveGraphicsState()
        let lip = NSBezierPath()
        lip.move(to: CGPoint(x: center.x - 17.5, y: center.y - 5.0))
        lip.curve(to: CGPoint(x: center.x + 17.5, y: center.y - 4.5),
                  controlPoint1: CGPoint(x: center.x - 8.5, y: center.y - 10.5),
                  controlPoint2: CGPoint(x: center.x + 9.5, y: center.y - 10.0))
        lip.line(to: CGPoint(x: center.x + 19.0, y: center.y - 14.0))
        lip.line(to: CGPoint(x: center.x - 19.0, y: center.y - 14.0))
        lip.close()
        lip.addClip()
        world.draw(in: worldRect,
                   from: CGRect(origin: .zero, size: sourceSize),
                   operation: .sourceOver,
                   fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }
}
