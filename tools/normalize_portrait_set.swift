import AppKit
import Foundation
import Vision

enum PortraitNormalizationError: Error {
    case unreadable(URL)
    case noFace(URL)
    case cropFailed(URL)
    case encodeFailed(URL)
}

let states = ["Neutral", "Thinking", "Pressure", "Surprised", "Winning", "Defeated"]
let targetSize = CGSize(width: 512, height: 512)
let targetFaceWidthFraction: CGFloat = 0.66
let targetEyeCenterYFromTop: CGFloat = 0.38

struct FaceGeometry {
    let rect: CGRect
    let eyeMidpoint: CGPoint
}

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: normalize_portrait_set <input-directory> <output-directory>\n".utf8))
    exit(2)
}

let inputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func loadImage(_ url: URL) throws -> CGImage {
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { throw PortraitNormalizationError.unreadable(url) }
    return cgImage
}

func faceGeometry(in image: CGImage, source: URL) throws -> FaceGeometry {
    let request = VNDetectFaceLandmarksRequest()
    try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
    guard let face = request.results?.max(by: {
        $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
    }) else { throw PortraitNormalizationError.noFace(source) }

    let width = CGFloat(image.width)
    let height = CGFloat(image.height)
    let rect = CGRect(
        x: face.boundingBox.minX * width,
        y: (1 - face.boundingBox.maxY) * height,
        width: face.boundingBox.width * width,
        height: face.boundingBox.height * height
    )

    func center(of region: VNFaceLandmarkRegion2D?) -> CGPoint? {
        guard let points = region?.normalizedPoints, !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + CGFloat(point.x), y: partial.y + CGFloat(point.y))
        }
        let local = CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
        let imageX = (face.boundingBox.minX + local.x * face.boundingBox.width) * width
        let imageYFromBottom = (face.boundingBox.minY + local.y * face.boundingBox.height) * height
        return CGPoint(x: imageX, y: height - imageYFromBottom)
    }

    let left = center(of: face.landmarks?.leftEye)
    let right = center(of: face.landmarks?.rightEye)
    let eyeMidpoint: CGPoint
    if let left, let right {
        eyeMidpoint = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
    } else {
        eyeMidpoint = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.42)
    }
    return FaceGeometry(rect: rect, eyeMidpoint: eyeMidpoint)
}

func backgroundColor(for image: CGImage) -> CGColor {
    let bitmap = NSBitmapImageRep(cgImage: image)
    let points = [
        NSPoint(x: 8, y: 8),
        NSPoint(x: max(0, image.width - 9), y: 8),
        NSPoint(x: 8, y: max(0, image.height - 9)),
        NSPoint(x: max(0, image.width - 9), y: max(0, image.height - 9)),
    ]
    let colors = points.compactMap { point in
        bitmap.colorAt(x: Int(point.x), y: Int(point.y))?.usingColorSpace(.sRGB)
    }.sorted { lhs, rhs in
        lhs.redComponent + lhs.greenComponent + lhs.blueComponent
            < rhs.redComponent + rhs.greenComponent + rhs.blueComponent
    }
    let samples = Array(colors.prefix(2))
    guard !samples.isEmpty else {
        return CGColor(red: 0.035, green: 0.045, blue: 0.047, alpha: 1)
    }
    let divisor = CGFloat(samples.count)
    return CGColor(
        red: samples.reduce(0) { $0 + $1.redComponent } / divisor,
        green: samples.reduce(0) { $0 + $1.greenComponent } / divisor,
        blue: samples.reduce(0) { $0 + $1.blueComponent } / divisor,
        alpha: 1
    )
}

func normalizedImage(
    _ source: CGImage,
    geometry: FaceGeometry,
    scale: CGFloat,
    sourceURL: URL
) throws -> Data {
    guard let context = CGContext(
        data: nil,
        width: Int(targetSize.width),
        height: Int(targetSize.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw PortraitNormalizationError.cropFailed(sourceURL) }
    context.interpolationQuality = .high
    context.setFillColor(CGColor(red: 0.027, green: 0.024, blue: 0.039, alpha: 1))
    context.fill(CGRect(origin: .zero, size: targetSize))

    let sourceEyeCenterYFromBottom = CGFloat(source.height) - geometry.eyeMidpoint.y
    let targetEyeCenterYFromBottom = targetSize.height * (1 - targetEyeCenterYFromTop)
    let originX = targetSize.width * 0.5 - geometry.eyeMidpoint.x * scale
    let originY = targetEyeCenterYFromBottom - sourceEyeCenterYFromBottom * scale
    let destination = CGRect(
        x: originX,
        y: originY,
        width: CGFloat(source.width) * scale,
        height: CGFloat(source.height) * scale
    )
    context.draw(source, in: destination)
    guard let output = context.makeImage() else {
        throw PortraitNormalizationError.cropFailed(sourceURL)
    }
    let bitmap = NSBitmapImageRep(cgImage: output)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw PortraitNormalizationError.encodeFailed(sourceURL)
    }
    return data
}

let neutralURL = inputDirectory.appendingPathComponent("Neutral.png")
let neutral = try loadImage(neutralURL)
let neutralGeometry = try faceGeometry(in: neutral, source: neutralURL)
let scale = targetSize.width * targetFaceWidthFraction / neutralGeometry.rect.width

for state in states {
    let sourceURL = inputDirectory.appendingPathComponent("\(state).png")
    let destinationURL = outputDirectory.appendingPathComponent("\(state).png")
    let image = try loadImage(sourceURL)
    let geometry = try faceGeometry(in: image, source: sourceURL)
    try normalizedImage(image, geometry: geometry, scale: scale, sourceURL: sourceURL)
        .write(to: destinationURL)
}

print(String(format: "face %.3f scale %.3f",
             neutralGeometry.rect.width / CGFloat(neutral.width),
             scale))
