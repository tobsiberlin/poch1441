import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct Scores: Codable {
    let identity: Double
    let rotate180: Double
    let horizontalMirror: Double
    let verticalMirror: Double
}

private struct Receipt: Codable {
    let status: String
    let video: String
    let referenceFrame: String
    let width: Int
    let height: Int
    let decodedFrameCount: Int
    let nominalFrameRate: Float
    let durationSeconds: Double
    let audioTrackCount: Int
    let bestOrientation: String
    let identityMargin: Double
    let meanAbsoluteRGBError: Scores
    let decodedFirstFrame: String
}

private enum VerificationError: LocalizedError {
    case usage
    case missingVideoTrack
    case cannotReadReference
    case cannotStartReader
    case cannotDecodeFrame
    case dimensionMismatch
    case cannotRasterize
    case cannotWriteImage

    var errorDescription: String? {
        switch self {
        case .usage: "Nutzung: VideoOrientationVerifier VIDEO REFERENCE_PNG RECEIPT_JSON DECODED_PNG"
        case .missingVideoTrack: "Video enthält keinen Bildtrack"
        case .cannotReadReference: "Referenz-PNG konnte nicht gelesen werden"
        case .cannotStartReader: "Videodecoder konnte nicht gestartet werden"
        case .cannotDecodeFrame: "Kein Videoframe konnte dekodiert werden"
        case .dimensionMismatch: "Dekodiertes Video und Referenz haben verschiedene Abmessungen"
        case .cannotRasterize: "Bilddaten konnten nicht in RGBA gerastert werden"
        case .cannotWriteImage: "Dekodierter Referenzframe konnte nicht geschrieben werden"
        }
    }
}

@main
private enum VideoOrientationVerifier {
    static func main() async throws {
        guard CommandLine.arguments.count == 5 else { throw VerificationError.usage }
        let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let referenceURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let receiptURL = URL(fileURLWithPath: CommandLine.arguments[3])
        let decodedURL = URL(fileURLWithPath: CommandLine.arguments[4])

        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { throw VerificationError.missingVideoTrack }
        let audioTrackCount = try await asset.loadTracks(withMediaType: .audio).count
        let nominalFrameRate = try await track.load(.nominalFrameRate)
        let duration = try await asset.load(.duration)

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw VerificationError.cannotStartReader }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? VerificationError.cannotStartReader }

        var firstImage: CGImage?
        var decodedFrameCount = 0
        let ciContext = CIContext(options: [.useSoftwareRenderer: true])
        while let sample = output.copyNextSampleBuffer() {
            decodedFrameCount += 1
            if firstImage == nil,
               let buffer = CMSampleBufferGetImageBuffer(sample) {
                let ciImage = CIImage(cvPixelBuffer: buffer)
                firstImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
            }
        }
        guard let decodedImage = firstImage else { throw VerificationError.cannotDecodeFrame }

        guard let source = CGImageSourceCreateWithURL(referenceURL as CFURL, nil),
              let referenceImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw VerificationError.cannotReadReference
        }
        guard decodedImage.width == referenceImage.width,
              decodedImage.height == referenceImage.height else {
            throw VerificationError.dimensionMismatch
        }

        let width = decodedImage.width
        let height = decodedImage.height
        let decoded = try rgba(decodedImage)
        let reference = try rgba(referenceImage)
        let scores = Scores(
            identity: meanAbsoluteRGBError(decoded, reference, width: width, height: height, transform: .identity),
            rotate180: meanAbsoluteRGBError(decoded, reference, width: width, height: height, transform: .rotate180),
            horizontalMirror: meanAbsoluteRGBError(decoded, reference, width: width, height: height, transform: .horizontalMirror),
            verticalMirror: meanAbsoluteRGBError(decoded, reference, width: width, height: height, transform: .verticalMirror)
        )
        let candidates = [
            ("identity", scores.identity),
            ("rotate180", scores.rotate180),
            ("horizontalMirror", scores.horizontalMirror),
            ("verticalMirror", scores.verticalMirror),
        ].sorted { $0.1 < $1.1 }
        let best = candidates[0]
        let nextBestNonIdentity = candidates
            .filter { $0.0 != "identity" }
            .map(\.1)
            .min() ?? .infinity
        let identityMargin = nextBestNonIdentity - scores.identity

        try writePNG(decodedImage, to: decodedURL)
        let passed = best.0 == "identity" && identityMargin >= 3 && scores.identity <= 18
        let receipt = Receipt(
            status: passed ? "PASS" : "RED",
            video: videoURL.lastPathComponent,
            referenceFrame: referenceURL.lastPathComponent,
            width: width,
            height: height,
            decodedFrameCount: decodedFrameCount,
            nominalFrameRate: nominalFrameRate,
            durationSeconds: CMTimeGetSeconds(duration),
            audioTrackCount: audioTrackCount,
            bestOrientation: best.0,
            identityMargin: identityMargin,
            meanAbsoluteRGBError: scores,
            decodedFirstFrame: decodedURL.lastPathComponent
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(receipt).write(to: receiptURL, options: .atomic)
        guard passed else {
            FileHandle.standardError.write(Data("Orientierungs-Gate RED: beste Zuordnung = \(best.0), Identity-Abstand = \(identityMargin)\n".utf8))
            Darwin.exit(1)
        }
    }

    private enum PixelTransform {
        case identity
        case rotate180
        case horizontalMirror
        case verticalMirror
    }

    private static func rgba(_ image: CGImage) throws -> [UInt8] {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw VerificationError.cannotRasterize }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }

    private static func meanAbsoluteRGBError(
        _ decoded: [UInt8],
        _ reference: [UInt8],
        width: Int,
        height: Int,
        transform: PixelTransform
    ) -> Double {
        var sum = 0.0
        var samples = 0
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let sourcePoint: (x: Int, y: Int)
                switch transform {
                case .identity: sourcePoint = (x, y)
                case .rotate180: sourcePoint = (width - 1 - x, height - 1 - y)
                case .horizontalMirror: sourcePoint = (width - 1 - x, y)
                case .verticalMirror: sourcePoint = (x, height - 1 - y)
                }
                let decodedOffset = (y * width + x) * 4
                let referenceOffset = (sourcePoint.y * width + sourcePoint.x) * 4
                for channel in 0..<3 {
                    sum += abs(Double(decoded[decodedOffset + channel]) - Double(reference[referenceOffset + channel]))
                    samples += 1
                }
            }
        }
        return sum / Double(max(samples, 1))
    }

    private static func writePNG(_ image: CGImage, to output: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { throw VerificationError.cannotWriteImage }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw VerificationError.cannotWriteImage
        }
    }
}
