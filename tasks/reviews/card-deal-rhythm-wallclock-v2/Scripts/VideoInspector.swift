import AVFoundation
import CoreMedia
import Foundation

private struct Inspection: Codable {
    let path: String
    let videoTrackCount: Int
    let audioTrackCount: Int
    let width: Int
    let height: Int
    let nominalFrameRate: Float
    let durationSeconds: Double
    let frameCount: Int
}

@main
private enum VideoInspector {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else {
            throw InspectorError.usage
        }

        let path = CommandLine.arguments[1]
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let videoTrack = videoTracks.first else {
            throw InspectorError.missingVideo
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let transformedSize = naturalSize.applying(transform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let duration = try await asset.load(.duration)

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw InspectorError.unreadableVideo
        }
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? InspectorError.unreadableVideo
        }

        var frameCount = 0
        while output.copyNextSampleBuffer() != nil {
            frameCount += 1
        }
        guard reader.status == .completed else {
            throw reader.error ?? InspectorError.unreadableVideo
        }

        let inspection = Inspection(
            path: path,
            videoTrackCount: videoTracks.count,
            audioTrackCount: audioTracks.count,
            width: Int(abs(transformedSize.width.rounded())),
            height: Int(abs(transformedSize.height.rounded())),
            nominalFrameRate: nominalFrameRate,
            durationSeconds: CMTimeGetSeconds(duration),
            frameCount: frameCount
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(inspection))
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}

private enum InspectorError: Error {
    case usage
    case missingVideo
    case unreadableVideo
}
