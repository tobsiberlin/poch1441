import AppKit
import AVFoundation
import CoreImage
import CryptoKit
import Foundation

struct Vector3: Codable, Sendable {
    let x: Double
    let y: Double
    let z: Double
}

struct Quaternion: Codable, Sendable {
    let w: Double
    let x: Double
    let y: Double
    let z: Double

    var yaw: Double {
        atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z))
    }

    var coinAxisZ: Double {
        1 - 2 * (x * x + y * y)
    }
}

struct TranscriptSample: Decodable, Sendable {
    let time: Double
    let position: Vector3
    let orientation: Quaternion
    let contacts: [String]
}

struct SeedTranscript: Decodable, Sendable {
    let seed: UInt64
    let samples: [TranscriptSample]
}

struct TranscriptBundle: Decodable, Sendable {
    let transcripts: [SeedTranscript]
}

struct CommitPolicy: Decodable, Sendable {
    let commitPoint: String
    let freeFlight: String
    let postContact: String
}

struct SelectionSummary: Decodable, Sendable {
    let availableTranscriptCount: Int
    let protectedHistoryLength: Int
    let repeatWithinProtectedHistory: Bool
}

struct GateSummary: Decodable, Sendable {
    let verdict: String
    let checks: Int
    let failures: [String]
    let commitPolicy: CommitPolicy
    let selection: SelectionSummary
}

struct WorldLightProfile: Encodable, Sendable {
    let id = "track-b-lamp-left-v1"
    let screenAzimuthRadians = 2.46
    let keyDirection = Vector3(x: -0.72, y: -0.58, z: 0.38)
    let ambientStrength = 0.22
    let contactShadowOffset = Vector3(x: 2.4, y: 3.2, z: 0)
}

struct TimeGateReceipt: Encodable, Sendable {
    let verdict = "TECHNICAL_GREEN_HUMAN_PENDING"
    let inheritedGateSummarySHA256: String
    let inheritedTranscriptsSHA256: String
    let inheritedChecks: Int
    let inheritedTranscriptCount: Int
    let selectedSeed: UInt64
    let selectedSampleIndices: [Int]
    let selectedTimes: [Double]
    let contactFrameCount: Int
    let projectedCoinDiameterPixels = 19.8
    let cropSizePixels = 76
    let supersampleScale = 6
    let channels: [String]
    let worldLightProfile: WorldLightProfile
    let uncutProofGenerated: Bool
    let uncutProofFrameRate: Int?
    let uncutProofFrameCount: Int?
    let uncutProofFinalTime: Double?
}

enum MaterialTimeGate {
    private static let outputSize = CGSize(width: 402, height: 874)
    private static let supersample = 6
    private static let projectedDiameter = 19.8
    private static let sampleIndices = [0, 4, 8, 12, 16, 18, 19, 20, 21, 28]

    static func writeAppSpriteAtlas(repository: URL,
                                    outputURL: URL) throws -> Int {
        let transcriptURL = repository.appendingPathComponent(
            "tasks/reviews/coin-motion-transcript-gate-v1/Evidence/coin-6dof-transcripts-12-seeds.json"
        )
        let transcriptData = try Data(contentsOf: transcriptURL)
        guard digest(transcriptData)
                == "76e883093a396548b07060d29d3f2149857240c1026cd1fefe35450de52d98be",
              let transcript = try JSONDecoder().decode(
                TranscriptBundle.self,
                from: transcriptData
              ).transcripts.first(where: { $0.seed == 1_441 }),
              let restIndex = transcript.samples.firstIndex(where: {
                $0.contacts.contains("restCertified")
              }) else {
            throw GateError.inheritedEvidenceChanged
        }

        let coinURL = repository.appendingPathComponent(
            "App/Assets.xcassets/TravelCent0.imageset/travel-cent-0.png"
        )
        guard let sourceCoin = NSBitmapImageRep(data: try Data(contentsOf: coinURL)) else {
            throw GateError.missingAsset
        }
        let alphaBounds = try alphaBounds(of: sourceCoin)
        let light = WorldLightProfile()
        var indices = Array(stride(from: 0, through: restIndex, by: 4))
        if indices.last != restIndex { indices.append(restIndex) }
        let frames = try indices.map { index in
            try renderSpriteFrame(
                coinURL: coinURL,
                alphaBounds: alphaBounds,
                sample: transcript.samples[index],
                light: light
            )
        }
        let atlas = try transparentContactSheet(
            frames: frames,
            panelSize: CGSize(width: 192, height: 192),
            columns: 7
        )
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try png(atlas).write(to: outputURL, options: .atomic)
        return frames.count
    }

    static func run(repository: URL,
                    outputDirectory: URL,
                    uncutProofURL: URL? = nil) throws -> TimeGateReceipt {
        let v1Evidence = repository.appendingPathComponent(
            "tasks/reviews/coin-motion-transcript-gate-v1/Evidence",
            isDirectory: true
        )
        let summaryData = try Data(contentsOf: v1Evidence.appendingPathComponent("gate-summary.json"))
        let transcriptData = try Data(contentsOf: v1Evidence
            .appendingPathComponent("coin-6dof-transcripts-12-seeds.json"))
        let decoder = JSONDecoder()
        let summary = try decoder.decode(GateSummary.self, from: summaryData)
        let bundle = try decoder.decode(TranscriptBundle.self, from: transcriptData)
        guard summary.verdict == "GREEN",
              summary.checks == 106,
              summary.failures.isEmpty,
              summary.commitPolicy.commitPoint == "release",
              summary.commitPolicy.freeFlight == "committedTimeScaleOnly",
              summary.commitPolicy.postContact == "finishTranscriptThenVisibleCountermove",
              summary.selection.availableTranscriptCount == 12,
              summary.selection.protectedHistoryLength == 8,
              !summary.selection.repeatWithinProtectedHistory,
              let transcript = bundle.transcripts.first,
              sampleIndices.allSatisfy({ transcript.samples.indices.contains($0) }) else {
            throw GateError.inheritedEvidenceChanged
        }

        let worldURL = repository.appendingPathComponent(
            "tasks/reviews/track-b-screen-mockup-assets/world-master-snackbox-v3-clean-mug.png"
        )
        let coinURL = repository.appendingPathComponent(
            "App/Assets.xcassets/TravelCent0.imageset/travel-cent-0.png"
        )
        guard let world = NSImage(contentsOf: worldURL),
              let sourceCoin = NSBitmapImageRep(data: try Data(contentsOf: coinURL)) else {
            throw GateError.missingAsset
        }
        let alphaBounds = try alphaBounds(of: sourceCoin)
        let light = WorldLightProfile()
        let samples = sampleIndices.map { transcript.samples[$0] }
        let frames = try samples.map {
            try renderFrame(world: world,
                            coinURL: coinURL,
                            alphaBounds: alphaBounds,
                            sample: $0,
                            light: light)
        }
        try FileManager.default.createDirectory(at: outputDirectory,
                                                withIntermediateDirectories: true)
        let fullStrip = try contactSheet(frames: frames,
                                         panelSize: outputSize,
                                         columns: 5)
        try png(fullStrip).write(
            to: outputDirectory.appendingPathComponent("orientation-contact-strip-10x-402x874.png"),
            options: .atomic
        )

        let crops = try zip(frames, samples).map { frame, sample in
            let center = projectedCenter(worldSize: world.size, sample: sample)
            return try cropped(frame,
                               rect: CGRect(x: floor(center.x - 38),
                                            y: floor(center.y - 38),
                                            width: 76,
                                            height: 76))
        }
        let cropStrip = try contactSheet(frames: crops,
                                         panelSize: CGSize(width: 76, height: 76),
                                         columns: 5)
        try png(cropStrip).write(
            to: outputDirectory.appendingPathComponent("orientation-contact-crop-strip-10x-76.png"),
            options: .atomic
        )

        let uncutIndices: [Int]
        if let uncutProofURL {
            guard let restIndex = transcript.samples.firstIndex(where: {
                $0.contacts.contains("restCertified")
            }) else {
                throw GateError.missingRestCertification
            }
            var indices = Array(stride(from: 0, through: restIndex, by: 4))
            if indices.last != restIndex {
                indices.append(restIndex)
            }
            try renderUncutProof(
                world: world,
                coinURL: coinURL,
                alphaBounds: alphaBounds,
                transcript: transcript,
                sampleIndices: indices,
                light: light,
                outputURL: uncutProofURL
            )
            uncutIndices = indices
        } else {
            uncutIndices = []
        }

        let receipt = TimeGateReceipt(
            inheritedGateSummarySHA256: digest(summaryData),
            inheritedTranscriptsSHA256: digest(transcriptData),
            inheritedChecks: summary.checks,
            inheritedTranscriptCount: bundle.transcripts.count,
            selectedSeed: transcript.seed,
            selectedSampleIndices: sampleIndices,
            selectedTimes: samples.map(\.time),
            contactFrameCount: samples.filter { !$0.contacts.isEmpty }.count,
            channels: [
                "flattened light-neutral aged-copper albedo",
                "directional height/normal approximation for relief and rim",
                "coin-local roughness and oxidation islands",
                "world-locked edge and specular response",
                "separate height-aware ground shadow",
                "front-lip occlusion recomposition",
            ],
            worldLightProfile: light,
            uncutProofGenerated: uncutProofURL != nil,
            uncutProofFrameRate: uncutProofURL == nil ? nil : 60,
            uncutProofFrameCount: uncutProofURL == nil ? nil : uncutIndices.count,
            uncutProofFinalTime: uncutIndices.last.map { transcript.samples[$0].time }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(receipt).write(
            to: outputDirectory.appendingPathComponent("technical-receipt.json"),
            options: .atomic
        )
        return receipt
    }

    private static func renderUncutProof(world: NSImage,
                                         coinURL: URL,
                                         alphaBounds: CGRect,
                                         transcript: SeedTranscript,
                                         sampleIndices: [Int],
                                         light: WorldLightProfile,
                                         outputURL: URL) throws {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: outputURL)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(outputSize.width),
            AVVideoHeightKey: Int(outputSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 4_800_000,
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoMaxKeyFrameIntervalKey: 60,
            ],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(outputSize.width),
                kCVPixelBufferHeightKey as String: Int(outputSize.height),
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            ]
        )
        guard writer.canAdd(input) else { throw GateError.videoEncodingFailed }
        writer.add(input)
        guard writer.startWriting() else { throw GateError.videoEncodingFailed }
        writer.startSession(atSourceTime: .zero)

        for (frameIndex, sampleIndex) in sampleIndices.enumerated() {
            let frame = try renderFrame(
                world: world,
                coinURL: coinURL,
                alphaBounds: alphaBounds,
                sample: transcript.samples[sampleIndex],
                light: light
            )
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.001)
            }
            let pixelBuffer = try makePixelBuffer(from: frame)
            let presentationTime = CMTime(value: Int64(frameIndex), timescale: 60)
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                writer.cancelWriting()
                throw GateError.videoEncodingFailed
            }
        }
        input.markAsFinished()
        let completion = DispatchSemaphore(value: 0)
        writer.finishWriting { completion.signal() }
        completion.wait()
        guard writer.status == .completed,
              fileManager.fileExists(atPath: outputURL.path) else {
            throw GateError.videoEncodingFailed
        }
    }

    private static func renderSpriteFrame(coinURL: URL,
                                          alphaBounds: CGRect,
                                          sample: TranscriptSample,
                                          light: WorldLightProfile) throws -> NSBitmapImageRep {
        let logicalCell = CGSize(width: 64, height: 64)
        let highSize = CGSize(width: logicalCell.width * CGFloat(supersample),
                              height: logicalCell.height * CGFloat(supersample))
        let bitmap = try makeBitmap(size: highSize)
        let context = try graphicsContext(for: bitmap)
        let floorCenter = CGPoint(x: logicalCell.width / 2,
                                  y: logicalCell.height / 2)
        let elevationPixels = min(max(sample.position.z - 0.0008, 0) / 0.0532 * 15.5, 15.5)
        let faceCenter = CGPoint(x: floorCenter.x,
                                 y: floorCenter.y + elevationPixels)
        let localLightAngle = light.screenAzimuthRadians - sample.orientation.yaw
        let material = try processedAlbedoAndRelief(
            sourceURL: coinURL,
            alphaBounds: alphaBounds,
            lightAngle: localLightAngle
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.compositingOperation = .copy
        NSColor.clear.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: highSize)).fill()
        context.compositingOperation = .sourceOver
        drawGroundShadow(center: floorCenter.scaled(by: CGFloat(supersample)),
                         elevationPixels: elevationPixels,
                         light: light)
        drawCoin(material: material,
                 center: faceCenter.scaled(by: CGFloat(supersample)),
                 yaw: sample.orientation.yaw,
                 axisZ: sample.orientation.coinAxisZ,
                 localLightAngle: localLightAngle)
        NSGraphicsContext.restoreGraphicsState()

        // The gate renderer is 6x supersampled. Downsampling to a @3x asset
        // retains the admitted 19.8-point projection while avoiding runtime CI.
        return try downsample(bitmap, to: CGSize(width: 192, height: 192))
    }

    private static func makePixelBuffer(from bitmap: NSBitmapImageRep) throws -> CVPixelBuffer {
        guard let image = bitmap.cgImage else { throw GateError.renderFailure }
        var optionalBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(outputSize.width),
            Int(outputSize.height),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            ] as CFDictionary,
            &optionalBuffer
        )
        guard status == kCVReturnSuccess, let buffer = optionalBuffer else {
            throw GateError.videoEncodingFailed
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer),
              let context = CGContext(
                data: baseAddress,
                width: Int(outputSize.width),
                height: Int(outputSize.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
              ) else {
            throw GateError.videoEncodingFailed
        }
        context.translateBy(x: 0, y: outputSize.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: outputSize))
        return buffer
    }

    private static func renderFrame(world: NSImage,
                                    coinURL: URL,
                                    alphaBounds: CGRect,
                                    sample: TranscriptSample,
                                    light: WorldLightProfile) throws -> NSBitmapImageRep {
        let highSize = CGSize(width: outputSize.width * CGFloat(supersample),
                              height: outputSize.height * CGFloat(supersample))
        let bitmap = try makeBitmap(size: highSize)
        let context = try graphicsContext(for: bitmap)
        let baseScale = max(outputSize.width / world.size.width,
                            outputSize.height / world.size.height)
        let finalWorldRect = CGRect(
            x: (outputSize.width - world.size.width * baseScale) * 0.5,
            y: (outputSize.height - world.size.height * baseScale) * 0.5,
            width: world.size.width * baseScale,
            height: world.size.height * baseScale
        )
        let worldRect = finalWorldRect.scaled(by: CGFloat(supersample))
        let floorCenter = projectedCenter(worldSize: world.size, sample: sample)
        let elevationPixels = min(max(sample.position.z - 0.0008, 0) / 0.0532 * 15.5, 15.5)
        let faceCenter = CGPoint(x: floorCenter.x,
                                 y: floorCenter.y + elevationPixels)
            .scaled(by: CGFloat(supersample))
        let highFloorCenter = floorCenter.scaled(by: CGFloat(supersample))
        let localLightAngle = light.screenAzimuthRadians - sample.orientation.yaw
        let material = try processedAlbedoAndRelief(sourceURL: coinURL,
                                                    alphaBounds: alphaBounds,
                                                    lightAngle: localLightAngle)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        world.draw(in: worldRect,
                   from: CGRect(origin: .zero, size: world.size),
                   operation: .copy,
                   fraction: 1)
        drawGroundShadow(center: highFloorCenter,
                         elevationPixels: elevationPixels,
                         light: light)
        drawCoin(material: material,
                 center: faceCenter,
                 yaw: sample.orientation.yaw,
                 axisZ: sample.orientation.coinAxisZ,
                 localLightAngle: localLightAngle)
        recomposeFrontLip(world: world,
                          worldRect: worldRect,
                          sourceSize: world.size)
        NSGraphicsContext.restoreGraphicsState()
        return try downsample(bitmap, to: outputSize)
    }

    private static func projectedCenter(worldSize: CGSize,
                                        sample: TranscriptSample) -> CGPoint {
        let scale = max(outputSize.width / worldSize.width,
                        outputSize.height / worldSize.height)
        let worldRect = CGRect(
            x: (outputSize.width - worldSize.width * scale) * 0.5,
            y: (outputSize.height - worldSize.height * scale) * 0.5,
            width: worldSize.width * scale,
            height: worldSize.height * scale
        )
        let sourceCenter = CGPoint(x: 648, y: worldSize.height - 704)
        return CGPoint(
            x: worldRect.minX + sourceCenter.x * scale
                + sample.position.x / 0.049 * 51,
            y: worldRect.minY + sourceCenter.y * scale
                - sample.position.y / 0.039 * 40
        )
    }

    private static func processedAlbedoAndRelief(sourceURL: URL,
                                                 alphaBounds: CGRect,
                                                 lightAngle: Double) throws -> NSImage {
        guard let source = CIImage(contentsOf: sourceURL) else {
            throw GateError.missingAsset
        }
        var albedo = source
            .applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 0.72,
                "inputShadowAmount": 0.28,
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.54,
                kCIInputContrastKey: 1.10,
                kCIInputBrightnessKey: -0.070,
            ])
            .applyingFilter("CIGammaAdjust", parameters: ["inputPower": 1.10])
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.2,
                kCIInputIntensityKey: 0.92,
            ])

        let directionX = cos(lightAngle)
        let directionY = sin(lightAngle)
        let weights: [CGFloat] = [
            CGFloat(-directionX - directionY), CGFloat(-directionY), CGFloat(directionX - directionY),
            CGFloat(-directionX), 0, CGFloat(directionX),
            CGFloat(-directionX + directionY), CGFloat(directionY), CGFloat(directionX + directionY),
        ]
        let normalResponse = source
            .applyingFilter("CIPhotoEffectMono")
            .applyingFilter("CIConvolution3X3", parameters: [
                "inputWeights": CIVector(values: weights, count: 9),
                "inputBias": 0.5,
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 0.52,
                kCIInputBrightnessKey: -0.01,
            ])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.28),
            ])
        albedo = normalResponse.applyingFilter("CIOverlayBlendMode", parameters: [
            kCIInputBackgroundImageKey: albedo,
        ])

        let alphaMask = source.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ])
        albedo = albedo.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: source.extent),
            kCIInputMaskImageKey: alphaMask,
        ])
        let crop = alphaBounds.insetBy(dx: -2, dy: -2).intersection(source.extent)
        let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
        guard let cgImage = ciContext.createCGImage(albedo, from: crop) else {
            throw GateError.renderFailure
        }
        return NSImage(cgImage: cgImage, size: crop.size)
    }

    private static func drawGroundShadow(center: CGPoint,
                                         elevationPixels: Double,
                                         light: WorldLightProfile) {
        let scale = CGFloat(supersample)
        let elevation = CGFloat(elevationPixels)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(
            width: (light.contactShadowOffset.x + elevation * 0.24) * scale,
            height: -(light.contactShadowOffset.y + elevation * 0.18) * scale
        )
        shadow.shadowBlurRadius = (2.1 + elevation * 0.18) * scale
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.62 - elevation * 0.018)
        shadow.set()
        NSColor.black.withAlphaComponent(max(0.04, 0.14 - elevation * 0.005)).setFill()
        NSBezierPath(ovalIn: CGRect(x: center.x - 10.8 * scale,
                                    y: center.y - 4.4 * scale,
                                    width: 22.8 * scale,
                                    height: 8.4 * scale)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawCoin(material: NSImage,
                                 center: CGPoint,
                                 yaw: Double,
                                 axisZ: Double,
                                 localLightAngle: Double) {
        let scale = CGFloat(supersample)
        let diameter = CGFloat(projectedDiameter) * scale
        let faceCompression = 0.64 * max(0.94, abs(axisZ))
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.scaleX(by: 1, yBy: faceCompression)
        transform.rotate(byRadians: yaw)
        transform.concat()

        let edge = NSBezierPath(ovalIn: CGRect(x: -diameter * 0.515,
                                              y: -diameter * 0.535,
                                              width: diameter * 1.03,
                                              height: diameter * 1.03))
        NSColor(calibratedRed: 0.28, green: 0.105, blue: 0.040, alpha: 0.98).setFill()
        edge.fill()
        material.draw(in: CGRect(x: -diameter * 0.5,
                                 y: -diameter * 0.5 + 0.8 * scale,
                                 width: diameter,
                                 height: diameter),
                      from: CGRect(origin: .zero, size: material.size),
                      operation: .sourceOver,
                      fraction: 0.96)
        drawOxidationIslands(diameter: diameter)
        drawReliefEdges(diameter: diameter, localLightAngle: localLightAngle)
        drawSpecularEdge(diameter: diameter, localLightAngle: localLightAngle)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawOxidationIslands(diameter: CGFloat) {
        let islands = [
            CGRect(x: diameter * 0.12, y: -diameter * 0.23,
                   width: diameter * 0.15, height: diameter * 0.085),
            CGRect(x: -diameter * 0.29, y: diameter * 0.09,
                   width: diameter * 0.10, height: diameter * 0.065),
            CGRect(x: diameter * 0.02, y: diameter * 0.25,
                   width: diameter * 0.075, height: diameter * 0.055),
        ]
        for (index, rect) in islands.enumerated() {
            let color = index == 0
                ? NSColor(calibratedRed: 0.08, green: 0.18, blue: 0.12, alpha: 0.19)
                : NSColor(calibratedRed: 0.15, green: 0.08, blue: 0.035, alpha: 0.16)
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    private static func drawReliefEdges(diameter: CGFloat,
                                        localLightAngle: Double) {
        let direction = CGPoint(x: cos(localLightAngle), y: sin(localLightAngle))
        let offset = diameter * 0.020
        let font = NSFont.systemFont(ofSize: diameter * 0.48, weight: .black)
        let text = "1" as NSString
        let origin = CGPoint(x: -diameter * 0.16, y: -diameter * 0.26)
        text.draw(at: CGPoint(x: origin.x - direction.x * offset,
                              y: origin.y - direction.y * offset),
                  withAttributes: [
                    .font: font,
                    .foregroundColor: NSColor(calibratedRed: 0.16,
                                              green: 0.055,
                                              blue: 0.018,
                                              alpha: 0.52),
                  ])
        text.draw(at: CGPoint(x: origin.x + direction.x * offset,
                              y: origin.y + direction.y * offset),
                  withAttributes: [
                    .font: font,
                    .foregroundColor: NSColor(calibratedRed: 0.88,
                                              green: 0.58,
                                              blue: 0.37,
                                              alpha: 0.45),
                  ])
        let ring = NSBezierPath(ovalIn: CGRect(x: -diameter * 0.43,
                                              y: -diameter * 0.43,
                                              width: diameter * 0.86,
                                              height: diameter * 0.86))
        NSColor(calibratedWhite: 0.90, alpha: 0.11).setStroke()
        ring.lineWidth = diameter * 0.014
        ring.stroke()
    }

    private static func drawSpecularEdge(diameter: CGFloat,
                                         localLightAngle: Double) {
        let roughness = 0.74
        let halfSpan = 34.0 * roughness
        let angle = localLightAngle * 180 / .pi
        let arc = NSBezierPath()
        arc.appendArc(withCenter: .zero,
                      radius: diameter * 0.485,
                      startAngle: angle - halfSpan,
                      endAngle: angle + halfSpan,
                      clockwise: false)
        NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.48, alpha: 0.42).setStroke()
        arc.lineWidth = diameter * 0.024
        arc.lineCapStyle = .round
        arc.stroke()
    }

    private static func recomposeFrontLip(world: NSImage,
                                           worldRect: CGRect,
                                           sourceSize: CGSize) {
        let scaleX = worldRect.width / sourceSize.width
        let scaleY = worldRect.height / sourceSize.height
        func point(_ x: CGFloat, _ topY: CGFloat) -> CGPoint {
            CGPoint(x: worldRect.minX + x * scaleX,
                    y: worldRect.minY + (sourceSize.height - topY) * scaleY)
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
            throw GateError.renderFailure
        }
        return CGRect(x: minimumX, y: minimumY,
                      width: maximumX - minimumX + 1,
                      height: maximumY - minimumY + 1)
    }

    private static func contactSheet(frames: [NSBitmapImageRep],
                                     panelSize: CGSize,
                                     columns: Int) throws -> NSBitmapImageRep {
        let rows = Int(ceil(Double(frames.count) / Double(columns)))
        let sheetSize = CGSize(width: panelSize.width * CGFloat(columns),
                               height: panelSize.height * CGFloat(rows))
        let sheet = try makeBitmap(size: sheetSize)
        let context = try graphicsContext(for: sheet)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .none
        NSColor.black.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: sheetSize)).fill()
        for (index, frame) in frames.enumerated() {
            let column = index % columns
            let row = index / columns
            let image = NSImage(size: frame.size)
            image.addRepresentation(frame)
            image.draw(in: CGRect(x: CGFloat(column) * panelSize.width,
                                  y: sheetSize.height - CGFloat(row + 1) * panelSize.height,
                                  width: panelSize.width,
                                  height: panelSize.height),
                       from: CGRect(origin: .zero, size: frame.size),
                       operation: .copy,
                       fraction: 1)
        }
        NSGraphicsContext.restoreGraphicsState()
        return sheet
    }

    private static func transparentContactSheet(frames: [NSBitmapImageRep],
                                                panelSize: CGSize,
                                                columns: Int) throws -> NSBitmapImageRep {
        let rows = Int(ceil(Double(frames.count) / Double(columns)))
        let sheetSize = CGSize(width: panelSize.width * CGFloat(columns),
                               height: panelSize.height * CGFloat(rows))
        let sheet = try makeBitmap(size: sheetSize)
        let context = try graphicsContext(for: sheet)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.compositingOperation = .copy
        NSColor.clear.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: sheetSize)).fill()
        for (index, frame) in frames.enumerated() {
            let column = index % columns
            let row = index / columns
            let image = NSImage(size: panelSize)
            image.addRepresentation(frame)
            image.draw(in: CGRect(
                x: CGFloat(column) * panelSize.width,
                y: sheetSize.height - CGFloat(row + 1) * panelSize.height,
                width: panelSize.width,
                height: panelSize.height
            ), from: CGRect(origin: .zero, size: frame.size),
               operation: .copy,
               fraction: 1)
        }
        NSGraphicsContext.restoreGraphicsState()
        return sheet
    }

    private static func cropped(_ source: NSBitmapImageRep,
                                rect: CGRect) throws -> NSBitmapImageRep {
        let imageRect = CGRect(x: rect.minX,
                               y: CGFloat(source.pixelsHigh) - rect.maxY,
                               width: rect.width,
                               height: rect.height)
        guard let image = source.cgImage?.cropping(to: imageRect) else {
            throw GateError.renderFailure
        }
        return NSBitmapImageRep(cgImage: image)
    }

    private static func downsample(_ source: NSBitmapImageRep,
                                   to size: CGSize) throws -> NSBitmapImageRep {
        let target = try makeBitmap(size: size)
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

    private static func makeBitmap(size: CGSize) throws -> NSBitmapImageRep {
        guard let bitmap = NSBitmapImageRep(
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
        ) else { throw GateError.renderFailure }
        bitmap.size = size
        return bitmap
    }

    private static func graphicsContext(for bitmap: NSBitmapImageRep) throws -> NSGraphicsContext {
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw GateError.renderFailure
        }
        return context
    }

    private static func png(_ image: NSBitmapImageRep) throws -> Data {
        guard let result = image.representation(using: .png, properties: [:]) else {
            throw GateError.renderFailure
        }
        return result
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum GateError: Error {
    case inheritedEvidenceChanged
    case missingAsset
    case renderFailure
    case missingRestCertification
    case videoEncodingFailed
}

private extension CGRect {
    func scaled(by scale: CGFloat) -> CGRect {
        CGRect(x: origin.x * scale, y: origin.y * scale,
               width: size.width * scale, height: size.height * scale)
    }
}

private extension CGPoint {
    func scaled(by scale: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
    }
}
