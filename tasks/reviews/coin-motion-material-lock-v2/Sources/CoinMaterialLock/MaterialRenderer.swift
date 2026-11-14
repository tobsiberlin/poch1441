import AppKit
import CoreImage
import Foundation

struct WorldLightProfile: Encodable, Sendable {
    let id = "track-b-lamp-left-v1"
    let keyDirectionScreen = Vector3(x: -0.72, y: -0.58, z: 0.38)
    let shadowOffsetPixels = Vector3(x: 2.4, y: 3.2, z: 0)
    let shadowBlurPixels = 2.2
    let ambientStrength = 0.22
}

struct MaterialReceipt: Encodable, Sendable {
    let mode: String
    let targetViewport = "402x874"
    let physicalCoinDiameterMeters = 0.019
    let projectedCoinDiameterPixels: Double
    let alphaCropPixels: [Int]
    let supersampleScale: Int
    let albedo = "aged real 1 euro cent copper"
    let relief = "source relief + directional convolution response"
    let edge = "1.67 mm worn copper edge"
    let response = "roughness-biased directional Track-B light"
    let groundShadowPass = true
    let frontLipOcclusionPass = true
    let worldLightProfile: WorldLightProfile
}

enum RenderMode: String {
    case cropGate = "crop-gate"
    case uncut = "uncut"
}

enum MaterialRenderer {
    private static let finalSize = CGSize(width: 402, height: 874)
    private static let supersample = 6
    private static let projectedDiameter = 19.8

    static func render(repository: URL,
                       state: TranscriptSample,
                       mode: RenderMode,
                       outputDirectory: URL) throws -> MaterialReceipt {
        let worldURL = repository.appendingPathComponent(
            "tasks/reviews/track-b-screen-mockup-assets/world-master-snackbox-v3-clean-mug.png"
        )
        let coinURL = repository.appendingPathComponent(
            "App/Assets.xcassets/TravelCent0.imageset/travel-cent-0.png"
        )
        let coinData = try Data(contentsOf: coinURL)
        guard let world = NSImage(contentsOf: worldURL),
              let sourceCoin = NSBitmapImageRep(data: coinData) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let alphaBounds = try alphaBounds(of: sourceCoin)
        let material = try processedMaterial(sourceURL: coinURL, alphaBounds: alphaBounds)
        let highSize = CGSize(width: finalSize.width * CGFloat(supersample),
                              height: finalSize.height * CGFloat(supersample))
        let highResolution = try bitmap(size: highSize)
        let graphics = try graphicsContext(for: highResolution)
        let sourceSize = world.size
        let baseScale = max(finalSize.width / sourceSize.width,
                            finalSize.height / sourceSize.height)
        let finalWorldRect = CGRect(
            x: (finalSize.width - sourceSize.width * baseScale) * 0.5,
            y: (finalSize.height - sourceSize.height * baseScale) * 0.5,
            width: sourceSize.width * baseScale,
            height: sourceSize.height * baseScale
        )
        let highWorldRect = finalWorldRect.scaled(by: CGFloat(supersample))
        let sourceCenter = CGPoint(x: 648, y: sourceSize.height - 704)
        let finalCenter = CGPoint(
            x: finalWorldRect.minX + sourceCenter.x * baseScale
                + state.position.x / 0.049 * 51,
            y: finalWorldRect.minY + sourceCenter.y * baseScale
                - state.position.y / 0.039 * 40
        )
        let center = finalCenter.scaled(by: CGFloat(supersample))
        let light = WorldLightProfile()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        graphics.imageInterpolation = .high
        world.draw(in: highWorldRect,
                   from: CGRect(origin: .zero, size: sourceSize),
                   operation: .copy,
                   fraction: 1)
        drawGroundShadow(center: center, light: light)
        drawWornEdge(center: center)
        drawMaterial(material, center: center, yaw: state.orientation.yaw)
        recomposeFrontLip(world: world,
                          worldRect: highWorldRect,
                          sourceSize: sourceSize)
        NSGraphicsContext.restoreGraphicsState()

        let target = try downsample(highResolution, to: finalSize)
        try FileManager.default.createDirectory(at: outputDirectory,
                                                withIntermediateDirectories: true)
        let cropRect = CGRect(x: floor(finalCenter.x - 38),
                              y: floor(finalCenter.y - 38),
                              width: 76,
                              height: 76)
        let crop = try cropped(target, rect: cropRect)
        try png(crop).write(
            to: outputDirectory.appendingPathComponent("material-crop-gate-actual-76x76.png"),
            options: .atomic
        )
        if mode == .uncut {
            try png(target).write(
                to: outputDirectory.appendingPathComponent("402x874-uncut-material-proof.png"),
                options: .atomic
            )
        }

        return MaterialReceipt(
            mode: mode.rawValue,
            projectedCoinDiameterPixels: Self.projectedDiameter,
            alphaCropPixels: [Int(alphaBounds.minX), Int(alphaBounds.minY),
                              Int(alphaBounds.width), Int(alphaBounds.height)],
            supersampleScale: supersample,
            worldLightProfile: light
        )
    }

    private static func alphaBounds(of image: NSBitmapImageRep) throws -> CGRect {
        var minimumX = image.pixelsWide
        var minimumY = image.pixelsHigh
        var maximumX = -1
        var maximumY = -1
        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                guard let color = image.colorAt(x: x, y: y),
                      color.alphaComponent > 0.035 else { continue }
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }
        guard maximumX >= minimumX, maximumY >= minimumY else {
            throw CocoaError(.coderInvalidValue)
        }
        return CGRect(x: minimumX,
                      y: minimumY,
                      width: maximumX - minimumX + 1,
                      height: maximumY - minimumY + 1)
    }

    private static func processedMaterial(sourceURL: URL,
                                          alphaBounds: CGRect) throws -> NSImage {
        guard let source = CIImage(contentsOf: sourceURL) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        var image = source
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.60,
                kCIInputContrastKey: 1.15,
                kCIInputBrightnessKey: -0.072,
            ])
            .applyingFilter("CIGammaAdjust", parameters: ["inputPower": 1.11])
            .applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.035])
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.35,
                kCIInputIntensityKey: 1.15,
            ])

        let relief = image
            .applyingFilter("CIPhotoEffectMono")
            .applyingFilter("CIConvolution3X3", parameters: [
                "inputWeights": CIVector(values: [
                    -1.0, -0.72, 0,
                    -0.72, 0, 0.72,
                    0, 0.72, 1.0,
                ], count: 9),
                "inputBias": 0.5,
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 0.64,
                kCIInputBrightnessKey: -0.015,
            ])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.34),
            ])
        image = relief.applyingFilter("CIOverlayBlendMode", parameters: [
            kCIInputBackgroundImageKey: image,
        ])

        let alphaMask = source.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ])
        let transparent = CIImage(color: .clear).cropped(to: source.extent)
        image = image.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: transparent,
            kCIInputMaskImageKey: alphaMask,
        ])

        let crop = alphaBounds.insetBy(dx: -2, dy: -2)
            .intersection(image.extent)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        guard let cgImage = context.createCGImage(image, from: crop) else {
            throw CocoaError(.coderInvalidValue)
        }
        return NSImage(cgImage: cgImage, size: crop.size)
    }

    private static func drawGroundShadow(center: CGPoint,
                                         light: WorldLightProfile) {
        let scale = CGFloat(supersample)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(width: light.shadowOffsetPixels.x * scale,
                                     height: -light.shadowOffsetPixels.y * scale)
        shadow.shadowBlurRadius = light.shadowBlurPixels * scale
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.64)
        shadow.set()
        NSColor.black.withAlphaComponent(0.13).setFill()
        NSBezierPath(ovalIn: CGRect(x: center.x - 10.8 * scale,
                                    y: center.y - 4.5 * scale,
                                    width: 23.0 * scale,
                                    height: 8.6 * scale)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawWornEdge(center: CGPoint) {
        let scale = CGFloat(supersample)
        let edgeRect = CGRect(x: center.x - 10.2 * scale,
                              y: center.y - 6.8 * scale,
                              width: 20.4 * scale,
                              height: 12.4 * scale)
        let edge = NSBezierPath(ovalIn: edgeRect)
        NSColor(calibratedRed: 0.31, green: 0.125, blue: 0.055, alpha: 0.98).setFill()
        edge.fill()
        NSColor(calibratedRed: 0.57, green: 0.30, blue: 0.16, alpha: 0.62).setStroke()
        edge.lineWidth = 0.72 * scale
        edge.stroke()
    }

    private static func drawMaterial(_ image: NSImage,
                                     center: CGPoint,
                                     yaw: Double) {
        let scale = CGFloat(supersample)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y + 0.65 * scale)
        transform.rotate(byRadians: yaw)
        transform.scaleX(by: 1, yBy: 0.64)
        transform.concat()
        let diameter = CGFloat(projectedDiameter) * scale
        image.draw(in: CGRect(x: -diameter * 0.5,
                              y: -diameter * 0.5,
                              width: diameter,
                              height: diameter),
                   from: CGRect(origin: .zero, size: image.size),
                   operation: .sourceOver,
                   fraction: 0.96)

        drawPatinaMarks(diameter: diameter)
        drawEmbossedOne(diameter: diameter)

        let reliefRing = NSBezierPath(ovalIn: CGRect(x: -diameter * 0.43,
                                                     y: -diameter * 0.43,
                                                     width: diameter * 0.86,
                                                     height: diameter * 0.86))
        NSColor(calibratedWhite: 0.88, alpha: 0.13).setStroke()
        reliefRing.lineWidth = 0.35 * scale
        reliefRing.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawPatinaMarks(diameter: CGFloat) {
        let stain = NSBezierPath(ovalIn: CGRect(x: diameter * 0.13,
                                               y: -diameter * 0.23,
                                               width: diameter * 0.13,
                                               height: diameter * 0.075))
        NSColor(calibratedRed: 0.10, green: 0.19, blue: 0.13, alpha: 0.20).setFill()
        stain.fill()

        let wear = NSBezierPath()
        wear.move(to: CGPoint(x: -diameter * 0.25, y: diameter * 0.18))
        wear.curve(to: CGPoint(x: diameter * 0.08, y: diameter * 0.24),
                   controlPoint1: CGPoint(x: -diameter * 0.13, y: diameter * 0.22),
                   controlPoint2: CGPoint(x: -diameter * 0.02, y: diameter * 0.17))
        NSColor(calibratedWhite: 0.84, alpha: 0.17).setStroke()
        wear.lineWidth = diameter * 0.013
        wear.stroke()
    }

    private static func drawEmbossedOne(diameter: CGFloat) {
        let font = NSFont.systemFont(ofSize: diameter * 0.48, weight: .black)
        let text = "1" as NSString
        let origin = CGPoint(x: -diameter * 0.16, y: -diameter * 0.26)
        text.draw(at: CGPoint(x: origin.x + diameter * 0.024,
                              y: origin.y - diameter * 0.024),
                  withAttributes: [
                    .font: font,
                    .foregroundColor: NSColor(calibratedRed: 0.20,
                                              green: 0.075,
                                              blue: 0.025,
                                              alpha: 0.54),
                  ])
        text.draw(at: CGPoint(x: origin.x - diameter * 0.022,
                              y: origin.y + diameter * 0.023),
                  withAttributes: [
                    .font: font,
                    .foregroundColor: NSColor(calibratedRed: 0.88,
                                              green: 0.56,
                                              blue: 0.34,
                                              alpha: 0.46),
                  ])
    }

    private static func recomposeFrontLip(world: NSImage,
                                           worldRect: CGRect,
                                           sourceSize: CGSize) {
        let scaleX = worldRect.width / sourceSize.width
        let scaleY = worldRect.height / sourceSize.height
        func point(_ sourceX: CGFloat, _ sourceTopY: CGFloat) -> CGPoint {
            CGPoint(x: worldRect.minX + sourceX * scaleX,
                    y: worldRect.minY + (sourceSize.height - sourceTopY) * scaleY)
        }
        NSGraphicsContext.saveGraphicsState()
        let lip = NSBezierPath()
        lip.move(to: point(603, 731))
        lip.curve(to: point(704, 724),
                  controlPoint1: point(625, 766),
                  controlPoint2: point(682, 765))
        lip.line(to: point(714, 790))
        lip.line(to: point(593, 796))
        lip.close()
        lip.addClip()
        world.draw(in: worldRect,
                   from: CGRect(origin: .zero, size: sourceSize),
                   operation: .sourceOver,
                   fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func bitmap(size: CGSize) throws -> NSBitmapImageRep {
        guard let result = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { throw CocoaError(.coderInvalidValue) }
        result.size = size
        return result
    }

    private static func graphicsContext(for bitmap: NSBitmapImageRep) throws -> NSGraphicsContext {
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw CocoaError(.coderInvalidValue)
        }
        return context
    }

    private static func downsample(_ source: NSBitmapImageRep,
                                   to size: CGSize) throws -> NSBitmapImageRep {
        let target = try bitmap(size: size)
        let context = try graphicsContext(for: target)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let image = NSImage(size: source.size)
        image.addRepresentation(source)
        image.draw(in: CGRect(origin: .zero, size: size),
                   from: CGRect(origin: .zero, size: source.size),
                   operation: .copy,
                   fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return target
    }

    private static func cropped(_ source: NSBitmapImageRep,
                                rect: CGRect) throws -> NSBitmapImageRep {
        let imageRect = CGRect(x: rect.minX,
                               y: CGFloat(source.pixelsHigh) - rect.maxY,
                               width: rect.width,
                               height: rect.height)
        guard let cgImage = source.cgImage?.cropping(to: imageRect) else {
            throw CocoaError(.coderInvalidValue)
        }
        return NSBitmapImageRep(cgImage: cgImage)
    }

    private static func png(_ image: NSBitmapImageRep) throws -> Data {
        guard let data = image.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}

private extension CGRect {
    func scaled(by scale: CGFloat) -> CGRect {
        CGRect(x: origin.x * scale,
               y: origin.y * scale,
               width: size.width * scale,
               height: size.height * scale)
    }
}

private extension CGPoint {
    func scaled(by scale: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
    }
}
