import AppKit
import AVFoundation
import Foundation

guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: extract_video_frames <video> <output-directory> [count] [start-seconds] [end-seconds]\n".utf8))
    exit(2)
}

let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let frameCount = max(2, CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3]) ?? 6 : 6)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let asset = AVURLAsset(url: videoURL)
let duration = try await asset.load(.duration)
let seconds = CMTimeGetSeconds(duration)
guard seconds.isFinite, seconds > 0 else {
    throw NSError(domain: "PochVideoQA", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid video duration"])
}
let startSeconds = max(0, CommandLine.arguments.count > 4 ? Double(CommandLine.arguments[4]) ?? 0 : 0)
let requestedEnd = CommandLine.arguments.count > 5 ? Double(CommandLine.arguments[5]) ?? seconds : seconds
let endSeconds = max(startSeconds + 0.01, min(seconds - 0.01, requestedEnd))

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
generator.maximumSize = CGSize(width: 512, height: 512)

for index in 0..<frameCount {
    let fraction = Double(index) / Double(frameCount - 1)
    let sampleSeconds = startSeconds + ((endSeconds - startSeconds) * fraction)
    let time = CMTime(seconds: sampleSeconds, preferredTimescale: 600)
    let (image, _) = try await generator.image(at: time)
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        continue
    }
    let path = outputURL.appendingPathComponent(String(format: "frame-%02d.png", index + 1))
    try png.write(to: path)
}

print(String(format: "%.2fs", seconds))
