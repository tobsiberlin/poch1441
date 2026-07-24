import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

@main
struct R1MaterialContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static func main() throws {
        let components = try source(at: "App/PlayComponents.swift")
        let layout = try source(at: "App/R1TokenLayout.swift")
        let effects = try source(at: "App/Effects.swift")
        let ring = try source(at: "App/PochRing.swift")
        let content = try source(at: "App/ContentView.swift")
        let impactFlight = try source(at: "App/ImpactFlight.swift")
        let dealOverlay = try source(at: "App/DealOverlay.swift")
        let tokens = try source(at: "App/DesignTokens.swift")
        let generator = try source(at: "tools/build_r1_ceramic_assets.py")

        try r1RendererUsesTheReferencePalette(components, generator: generator)
        try r1AssetsShareTheCanonicalSilhouette(tokens: tokens, generator: generator)
        try pochDiscAssetNormalizationStaysShared(components, ring: ring)
        try pochDiscMaterialGradeStaysShared(components, ring: ring)
        try saturatedPilesRevealTheirPublicValue(components)
        try r1ScaleAndLightingStayPhysical(components, generator: generator)
        try restingPosesAreStableAndVaried(layout)
        try contactFeedbackIsImpactBoundAndBundled(effects)
        try fundingMotionRemainsPhysicalAndInterruptible(content: content,
                                                         impactFlight: impactFlight,
                                                         effects: effects,
                                                         dealOverlay: dealOverlay)
        try ceramicAudioVariantsMeetTheRuntimeContract(effects)

        FileHandle.standardOutput.write(Data("R1MaterialContractTests: PASS\n".utf8))
    }

    private static func pochDiscMaterialGradeStaysShared(_ components: String,
                                                         ring: String) throws {
        let grade = root.appendingPathComponent(
            "App/Assets.xcassets/PochDiscMaterialGrade.imageset/poch-disc-material-grade.png"
        )
        expect(FileManager.default.fileExists(atPath: grade.path),
               "Track A needs its deterministic material-grade asset")
        expect(components.contains("struct PochDiscMaterialImage: View"),
               "Disc base and foreground lips need one shared material source")
        expect(components.components(separatedBy: "PochDiscMaterialImage(size:").count - 1 >= 1,
               "The Track-A base must render the shared material source")
        expect(!ring.contains("PochDiscFrontLipOverlay"),
               "Track A must not redraw complete gray well rings over the source asset")
        expect(!components.contains("PochDiscWellFloorOverlay"),
               "The old runtime brightness duplicate must not return")
        expect(!components.contains(".brightness(Tokens.pochDiscWellFloorLift)"),
               "Velvet must be built once, not brightened at runtime")
        expect(components.contains("PochDiscSuitEngravingOverlay(size: size)"),
               "The satin outer frame needs the dark vector suit engravings")
    }

    private static func r1RendererUsesTheReferencePalette(
        _ source: String,
        generator: String
    ) throws {
        for colorway in ["naturalWhite", "terracotta", "sage", "slate", "ochre"] {
            expect(source.contains("case \(colorway)"),
                   "R1 colorway \(colorway) is missing")
        }
        for asset in ["R1NaturalWhite", "R1Terracotta", "R1Sage", "R1Slate", "R1Ochre"] {
            expect(source.contains("\"\(asset)\""),
                   "R1 material asset \(asset) is missing from the renderer")
            let imageset = root.appendingPathComponent("App/Assets.xcassets/\(asset).imageset")
            expect(FileManager.default.fileExists(atPath: imageset.path),
                   "R1 imageset \(asset) is missing")
        }

        let renderer = try section(in: source,
                                   from: "struct R1Token: View",
                                   through: "typealias TableChip = R1Token")
        expect(renderer.contains("_ = tint"),
               "Legacy pool/player tint must remain explicitly ignored")
        expect(!renderer.contains("Text("),
               "R1 must not render values or currency on the token")
        expect(!renderer.contains("stroke("),
               "R1 must not draw the W2 signet as runtime line art")
        expect(generator.contains("def signet_relief_fields()")
               && generator.contains("relief_highlight_px"),
               "R1 must bake the faceted W2 blind emboss into its ceramic material")
        expect(!source.contains("R1CenterMark"),
               "R1 must not substitute arbitrary chevron, square, or diamond marks")
        expect(source.contains("static func resolve(compartment: TravelCompartment, index: Int)"),
               "R1 needs a deterministic material resolver tied to the physical well")
        expect(source.contains("case .jack: palette = [.ochre]"),
               "The reference ochre material must reach the jack well")
    }

    private static func r1AssetsShareTheCanonicalSilhouette(
        tokens: String,
        generator: String
    ) throws {
        expect(FileManager.default.fileExists(atPath: root
            .appendingPathComponent("tools/build_r1_ceramic_assets.py").path),
               "R1 needs a reproducible build-time ceramic material generator")
        expect(FileManager.default.fileExists(atPath: root
            .appendingPathComponent("tools/r1-material/r1-alpha-mask.png").path),
               "R1 needs a locked source alpha hull")
        expect(generator.contains("def taller_alpha(source: Image.Image)"),
               "R1 height must extend only the projected ceramic wall")
        let assets = [
            (name: "R1NaturalWhite", filename: "r1-natural-white.png",
             nativeVariation: 0.006...0.015, compactMinimum: 0.005),
            (name: "R1Terracotta", filename: "r1-terracotta.png",
             nativeVariation: 0.008...0.018, compactMinimum: 0.005),
            (name: "R1Sage", filename: "r1-sage.png",
             nativeVariation: 0.025...0.045, compactMinimum: 0.010),
            (name: "R1Slate", filename: "r1-slate.png",
             nativeVariation: 0.045...0.070, compactMinimum: 0.015),
            (name: "R1Ochre", filename: "r1-ochre.png",
             nativeVariation: 0.010...0.022, compactMinimum: 0.005)
        ]
        var referenceAlpha: [UInt8]?

        for asset in assets {
            let url = root.appendingPathComponent(
                "App/Assets.xcassets/\(asset.name).imageset/\(asset.filename)"
            )
            let data = try Data(contentsOf: url)
            let header = Array(data.prefix(26))
            expect(header.count == 26 && Array(header.prefix(8)) == [
                0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
            ], "\(asset.name) must be a PNG")
            expect(String(bytes: header[12..<16], encoding: .ascii) == "IHDR",
                   "\(asset.name) must start with a canonical PNG IHDR chunk")

            let width = integer(fromBigEndianBytes: header[16..<20])
            let height = integer(fromBigEndianBytes: header[20..<24])
            expect(width == 340 && height == 340,
                   "\(asset.name) must be exactly 340 x 340 pixels")
            expect(header[24] == 8 && header[25] == 6,
                   "\(asset.name) must be an 8-bit RGBA PNG")

            let alpha = try decodedAlpha(at: url, width: width, height: height)
            expect(cornersAreTransparent(alpha, width: width, height: height),
                   "\(asset.name) must keep transparent alpha corners")
            expect(Set(alpha).count >= 16,
                   "\(asset.name) needs a continuous antialias edge, not a quantized fringe")
            let bounds = alphaBounds(alpha, width: width, height: height)
            expect(bounds.width == 294 && bounds.height == 318,
                   "\(asset.name) must retain the measured 294 x 318 elevated alpha hull")
            if let referenceAlpha {
                expect(alpha == referenceAlpha,
                       "\(asset.name) must share the exact R1 silhouette")
            } else {
                referenceAlpha = alpha
            }

            let nativePixels = try rasterizedPixels(at: url, width: width, height: height)
            let nativeFace = luminances(in: nativePixels,
                                        canvasWidth: width,
                                        xRange: 140..<200,
                                        yRange: 240..<270)
            let nativeMean = nativeFace.reduce(0, +) / Double(nativeFace.count)
            let nativeVariation = standardDeviation(nativeFace) / nativeMean
            expect(asset.nativeVariation.contains(nativeVariation),
                   "\(asset.name) must retain its reference-specific material spectrum")
            expect(nativeFace.max() ?? 1 < 0.92,
                   "\(asset.name) must not contain a plastic specular hotspot")

            let compactPixels = try rasterizedPixels(at: url, width: 39, height: 39)
            let compactFace = luminances(in: compactPixels,
                                         canvasWidth: 39,
                                         xRange: 10..<16,
                                         yRange: 24..<30)
            let compactMean = compactFace.reduce(0, +) / Double(compactFace.count)
            expect(standardDeviation(compactFace) / compactMean >= asset.compactMinimum,
                   "\(asset.name) mineral grain must survive at the 39 pt product size")
        }
        expect(tokens.contains("static let r1AssetScale: CGFloat = 1.085"),
               "R1 size must normalize the maximum 308 px alpha hull, not an obsolete crop")
        expect(tokens.contains("static let r1MeasuredAlphaRadiusRatio: CGFloat"),
               "R1 geometry needs the measured alpha radius as a named contract")
    }

    private static func alphaBounds(_ alpha: [UInt8],
                                    width: Int,
                                    height: Int) -> (width: Int, height: Int) {
        var minimumX = width
        var minimumY = height
        var maximumX = -1
        var maximumY = -1
        for y in 0..<height {
            for x in 0..<width where alpha[y * width + x] > 0 {
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }
        guard maximumX >= minimumX, maximumY >= minimumY else { return (0, 0) }
        return (maximumX - minimumX + 1, maximumY - minimumY + 1)
    }

    private static func decodedAlpha(at url: URL,
                                     width: Int,
                                     height: Int) throws -> [UInt8] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fail("Unable to decode R1 material asset \(url.lastPathComponent)")
        }
        expect(image.width == width && image.height == height,
               "Decoded R1 dimensions must match the PNG header")

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                  ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        expect(rendered, "Unable to rasterize R1 alpha data")
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }

    private static func rasterizedPixels(at url: URL,
                                         width: Int,
                                         height: Int) throws -> [UInt8] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fail("Unable to decode R1 material asset \(url.lastPathComponent)")
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                  ) else {
                return false
            }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        expect(rendered, "Unable to rasterize R1 material RGB data")
        return pixels
    }

    private static func luminances(in pixels: [UInt8],
                                   canvasWidth: Int,
                                   xRange: Range<Int>,
                                   yRange: Range<Int>) -> [Double] {
        yRange.flatMap { y in
            xRange.map { x in
                let index = (y * canvasWidth + x) * 4
                let red = Double(pixels[index]) / 255
                let green = Double(pixels[index + 1]) / 255
                let blue = Double(pixels[index + 2]) / 255
                return red * 0.2126 + green * 0.7152 + blue * 0.0722
            }
        }
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(values.count)
        return sqrt(variance)
    }

    private static func cornersAreTransparent(_ alpha: [UInt8],
                                              width: Int,
                                              height: Int) -> Bool {
        let cornerSide = 16
        let xRanges = [0..<cornerSide, (width - cornerSide)..<width]
        let yRanges = [0..<cornerSide, (height - cornerSide)..<height]
        return xRanges.allSatisfy { xRange in
            yRanges.allSatisfy { yRange in
                yRange.allSatisfy { y in
                    xRange.allSatisfy { x in alpha[y * width + x] == 0 }
                }
            }
        }
    }

    private static func integer(fromBigEndianBytes bytes: ArraySlice<UInt8>) -> Int {
        bytes.reduce(0) { ($0 << 8) | Int($1) }
    }

    private static func pochDiscAssetNormalizationStaysShared(_ source: String,
                                                              ring: String) throws {
        let base = try section(in: source,
                               from: "struct TableWorldBoardBase: View",
                               through: "private struct TableWorldSpatialPresentation")
        expect(base.contains("PochDiscMaterialImage(size: diameter)"),
               "Track A board base must use the normalized shared material image")
        expect(base.contains("Image(\"PochDiscCleanBase\")"),
               "Track A must use the halo-free build-time body while retaining source detail")
        expect(base.contains(".normalizedPochDiscAsset(diameter: size)"),
               "The shared material image must normalize the transparent source canvas")

        let spatial = try section(in: source,
                                  from: "private struct TableWorldSpatialPresentation",
                                  through: "extension View")
        expect(spatial.contains(".shadow(color: Color.black.opacity(0.68)"),
               "Track A needs its calibrated directed cast shadow")
        expect(!spatial.contains(".background {"),
               "A synthetic ambient ellipse must not recreate the removed round halo")
        expect(!ring.contains("PochDiscFrontLipOverlay"),
               "The physical source asset must remain the sole well-ring geometry")

        for anchor in [
            "case .king:     normalized = CGPoint(x: 0.5000, y: 0.1463)",
            "case .queen:    normalized = CGPoint(x: 0.7311, y: 0.2358)",
            "case .mariage:  normalized = CGPoint(x: 0.8426, y: 0.4639)",
            "case .jack:     normalized = CGPoint(x: 0.7462, y: 0.7080)",
            "case .ten:      normalized = CGPoint(x: 0.4990, y: 0.8135)",
            "case .sequence: normalized = CGPoint(x: 0.2498, y: 0.7100)",
            "case .poch:     normalized = CGPoint(x: 0.1564, y: 0.4649)",
            "case .ace:      normalized = CGPoint(x: 0.2679, y: 0.2358)",
            "case .center:   normalized = CGPoint(x: 0.5000, y: 0.5000)"
        ] {
            expect(ring.contains(anchor),
                   "every Track-A overlay must use the measured 1254-px asset center map")
        }
    }

    private static func saturatedPilesRevealTheirPublicValue(_ source: String) throws {
        let marker = try section(in: source,
                                 from: "struct PocketValueMarker: View",
                                 through: "struct PocketTile: View")
        expect(marker.contains("case .pochDisc: R1TokenSlots.capacity"),
               "Track A notation must derive saturation from the physical R1 capacity")
        expect(marker.contains("case .unterwegs: TravelCoinLayout.capacity"),
               "Track B notation must derive saturation from its physical coin capacity")
        expect(marker.contains("if chips > visiblePileCapacity"),
               "A saturated physical pile must reveal its public semantic value")
    }

    private static func r1ScaleAndLightingStayPhysical(
        _ source: String,
        generator: String
    ) throws {
        let renderer = try section(in: source,
                                   from: "struct R1Token: View",
                                   through: "typealias TableChip = R1Token")
        expect(!renderer.contains("Ellipse()"),
               "R1 shadows must follow the real alpha silhouette, not detached ovals")
        expect(renderer.contains("Image(colorway.assetName)"),
               "R1 must use the build-time material basis instead of flat circles")
        expect(renderer.contains(".scaleEffect(Tokens.r1AssetScale)"),
               "R1 must normalize the visible ceramic body inside the PNG canvas")
        expect(renderer.contains(".interpolation(.medium)"),
               "R1 precision teeth must survive the 39-pt product projection")
        expect(generator.contains("SIGNET_STROKE")
               && generator.contains("relief_dark_wall_px"),
               "R1 emboss needs a narrow trench and paired material light edge")

        let pile = try section(in: source,
                               from: "struct TableTokenPile: View",
                               through: "struct RecessedTokenPile: View")
        expect(!pile.contains(".rotationEffect(.degrees(pose.rotation))"),
               "World light and contact shadow must not rotate with the token")

        let recessed = try section(in: source,
                                   from: "struct RecessedTokenPile: View",
                                   through: "private struct R1WellFrontLip: Shape")
        expect(recessed.contains("tokenDiameterOverride"),
               "Compact and regular discs need an explicit shared physical token scale")
        expect(recessed.contains("let physicalTokenDiameter = min("),
               "Requested R1 size must never bypass the inner-well fit limit")
        expect(recessed.contains("diameter * verticalInsetRatio"),
               "R1 piles must use the compartment-specific recessed-well depth")
        expect(recessed.contains("Tokens.r1CenterWellPileVerticalInsetRatio"),
               "the centre pile must use the exact geometric midpoint")
        expect(recessed.contains("R1WellFrontLip()"),
               "The well may occlude tokens only with its local front lip")
        expect(recessed.contains("if compartment != .center"),
               "The raised center bezel must not receive a second compact catch arc")
        expect(!recessed.contains(".frame(width: diameter * 0.58, height: diameter * 0.14)"),
               "A broad synthetic group-shadow oval must not return")

        expect(renderer.contains("Tokens.r1CastShadowElevationRadiusRatio")
               && renderer.contains("Tokens.r1CastShadowElevationYRatio"),
               "stack elevation must widen and displace the physical cast shadow")
        expect(pile.contains("Tokens.r1PileElevationLiftRatio"),
               "overlapping R1 need a visible height lift instead of a flat rosette")
        expect(pile.contains("Tokens.r1CenterPileSpread")
               && pile.contains("Tokens.r1OuterPileSpread"),
               "R1 piles must expose their sidewalls and shadows within each physical floor")

    }

    private static func restingPosesAreStableAndVaried(_ source: String) throws {
        expect(source.contains("static let capacity = 12"),
               "R1 requires twelve deterministic resting slots")
        expect(source.contains("guard count > 0 else { return [] }"),
               "An empty group must not synthesize a visible R1 token")
        expect(source.contains("stableSalt(for compartment: TravelCompartment)"),
               "R1 pile variation must be tied to the physical compartment")
        expect(source.contains("seed ^ stableSalt(for: compartment)"),
               "R1 pile variation must remain replay-stable")
        expect(source.contains("jitterX") && source.contains("groupAngle"),
               "R1 piles must not repeat one cloned rosette")
    }

    private static func contactFeedbackIsImpactBoundAndBundled(_ source: String) throws {
        expect(source.contains(".onChange(of: trigger)"),
               "Ceramic sound must be bound to the impact trigger")
        expect(source.contains("R1ContactDynamics.resolve(surface: surface,"),
               "Surface and group size must share one contact mapping")
        expect(source.contains("groupSize: groupSize"),
               "The bundled group size must reach audio and haptics")
        expect(source.contains("now - lastContactTime >= 0.12"),
               "Rapid subordinate contacts must remain throttled")

        let feedback = try section(in: source,
                                   from: "struct R1ContactFeedback: ViewModifier",
                                   through: "extension View")
        expect(!feedback.contains("Task.sleep"),
               "R1 feedback must not own a second timeline")
    }

    private static func fundingMotionRemainsPhysicalAndInterruptible(
        content: String,
        impactFlight: String,
        effects: String,
        dealOverlay: String
    ) throws {
        let funding = try section(in: content,
                                  from: "private func runGuidedTableFundingImpact()",
                                  through: "private func cancelGuidedFunding()")
        expect(funding.contains("await runGuidedAnteSequence(generation: generation)"),
               "The product funding path must use the visible R1 wave")
        expect(funding.contains("guard generation == guidedFundingGeneration"),
               "A stale funding task must not clean up a restarted lesson")
        expect(!content.contains("guidedTableFundingTargeted"),
               "The former abstract funding line must not return")

        let sequence = try section(in: content,
                                   from: "private func runGuidedAnteSequence(generation:",
                                   through: "private func landGuidedAnte")
        expect(sequence.contains("while remaining > 0, !guidedReduceMotion"),
               "A live Reduce Motion change must end the visible wait")
        expect(sequence.contains("Tokens.guidedAnteMotionPreferencePoll"),
               "The motion preference polling cadence must remain tokenized")
        expect(sequence.contains("guard !Task.isCancelled"),
               "A cancelled tutorial wave must not materialize ghost R1")
        expect(sequence.contains("generation == guidedFundingGeneration"),
               "Every delayed landing must remain scoped to its funding run")
        expect(content.contains("game.markGuidedTableFundingLanded(groupSize: game.playerCount)"),
               "Bundled contact feedback must fire on the actual final R1 impact")

        expect(impactFlight.contains(".position(from)"),
               "Flight layout must stay anchored at its source")
        expect(impactFlight.contains(".modifier(FlightPathEffect(progress: progress"),
               "The animated path must use a per-frame transform instead of layout position")
        expect(impactFlight.contains("private struct FlightPathEffect: GeometryEffect"),
               "Curved material flight needs animatable path geometry")

        let travel = try section(in: effects,
                                 from: "static func travel(duration: Double)",
                                 through: "static func duration(from: CGPoint")
        expect(travel.contains(".linear(duration: duration)"),
               "The ballistic path must not ease out before material contact")

        let coinStream = try section(in: dealOverlay,
                                     from: "private struct CoinStream: View",
                                     through: "private struct FlyingBack: View")
        expect(!coinStream.contains("progress > 0.86"),
               "The R1 shadow must not pop to a new paint state before contact")
    }

    private static func ceramicAudioVariantsMeetTheRuntimeContract(_ source: String) throws {
        let expression = try NSRegularExpression(
            pattern: #"r1-ceramic-(?:outer|center|stack)-0[1-3]"#
        )
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        let names = Set(expression.matches(in: source, range: range).compactMap { match -> String? in
            guard let swiftRange = Range(match.range, in: source) else { return nil }
            return String(source[swiftRange])
        })
        expect(names.count == 9,
               "R1 requires three variants for outer well, center well, and player stack")

        expect(source.contains("case .playerStack:")
               && source.contains("variants = stackVariants"),
               "Player-stack contacts need their own softer ceramic-on-ceramic family")

        for name in names {
            let url = root.appendingPathComponent("App/Audio/\(name).caf")
            expect(FileManager.default.fileExists(atPath: url.path),
                   "Missing bundled contact sound: \(name).caf")

            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let duration = Double(file.length) / format.sampleRate
            expect(format.channelCount == 1,
                   "R1 contact sounds must stay mono")
            expect(format.sampleRate == 44_100,
                   "R1 contact sounds must stay at 44.1 kHz")
            expect((0.14...0.30).contains(duration),
                   "R1 contact sound duration must remain short and physical")
        }
    }

    private static func source(at relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath),
                   encoding: .utf8)
    }

    private static func section(in source: String,
                                from startMarker: String,
                                through endMarker: String) throws -> String {
        guard let start = source.range(of: startMarker)?.lowerBound,
              let end = source.range(of: endMarker, range: start..<source.endIndex)?.upperBound else {
            fail("Unable to locate source section \(startMarker)")
        }
        return String(source[start..<end])
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        if !condition() {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("R1MaterialContractTests: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
