import Foundation

@main
struct CardFaceRenderContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    private static let suits = ["clubs", "diamonds", "hearts", "spades"]
    private static let ranks = ["ace", "king", "queen", "jack", "ten", "nine", "eight", "seven"]

    static func main() throws {
        try assetCatalogCoversTheCompleteDeck()
        try runtimePreservesTheMaterializedAssetSurface()
        try phaseThreeStateRingStaysOutsideTheCardSurface()
        FileHandle.standardOutput.write(Data("CardFaceRenderContractTests: PASS\n".utf8))
    }

    private static func assetCatalogCoversTheCompleteDeck() throws {
        let cards = root.appendingPathComponent("App/Assets.xcassets/Cards")
        let expectedNames = Set(suits.flatMap { suit in
            ranks.map { rank in "card_\(suit)_\(rank)" }
        })
        let actualNames = try Set(FileManager.default.contentsOfDirectory(
            at: cards,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).compactMap { url -> String? in
            guard url.pathExtension == "imageset" else { return nil }
            return url.deletingPathExtension().lastPathComponent
        })

        expect(actualNames == expectedNames,
               "CardFace naming must resolve exactly the complete 32-card asset set")

        for name in expectedNames {
            let imageset = cards.appendingPathComponent("\(name).imageset")
            try expectPNG(imageset.appendingPathComponent("\(name)@2x.png"), width: 312, height: 444)
            try expectPNG(imageset.appendingPathComponent("\(name)@3x.png"), width: 468, height: 666)
        }
    }

    private static func runtimePreservesTheMaterializedAssetSurface() throws {
        let source = try String(
            contentsOf: root.appendingPathComponent("App/CardFace.swift"),
            encoding: .utf8
        )
        expect(source.contains(#"return "card_\(suitStr)_\(rankStr)""#),
               "CardFace must resolve the public card asset naming contract")
        expect(source.contains("Image(name)") &&
               source.contains(".aspectRatio(contentMode: .fit)"),
               "CardFace must render the asset without cropping or aspect distortion")
        expect(!source.contains(".clipShape("),
               "The PNG alpha silhouette must not be replaced by a runtime rounded clip")
        expect(!source.contains("Color.black.opacity(0.42)") &&
               !source.contains("Color.white.opacity(0.20)"),
               "Clean runtime border strokes must not cover the baked handling rim")
        expect(source.contains(".padding(-accentLineWidth)"),
               "Semantic state rings must remain outside the materialized card surface")

        guard let bodyStart = source.range(of: "    var body: some View {")?.lowerBound,
              let helperStart = source.range(of: "    private func svgCard", range: bodyStart..<source.endIndex)?.lowerBound else {
            fail("CardFace body and asset helper must remain inspectable")
        }
        let runtimeBody = source[bodyStart..<helperStart]
        expect(!runtimeBody.contains(".fill("),
               "CardFace runtime composition must not flatten the build-time paper texture")
    }

    private static func phaseThreeStateRingStaysOutsideTheCardSurface() throws {
        let source = try String(
            contentsOf: root.appendingPathComponent("App/Phase3View.swift"),
            encoding: .utf8
        )
        expect(source.contains(".padding(-1.4)"),
               "Phase-three lead affordance must remain outside the patinated card surface")
        expect(!source.contains(".padding(2)"),
               "Phase-three lead affordance must not inset a clean ring over the card asset")
    }

    private static func expectPNG(_ url: URL, width: Int, height: Int) throws {
        let data = try Data(contentsOf: url)
        expect(data.count >= 26 && Array(data.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10],
               "\(url.lastPathComponent) must be a PNG")
        let bytes = [UInt8](data.prefix(26))
        func integer(at offset: Int) -> Int {
            bytes[offset..<offset + 4].reduce(0) { ($0 << 8) | Int($1) }
        }
        expect(integer(at: 16) == width && integer(at: 20) == height,
               "\(url.lastPathComponent) must keep the canonical 52:74 dimensions")
        expect(bytes[25] == 6,
               "\(url.lastPathComponent) must keep an RGBA channel for its baked silhouette")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String
    ) {
        guard condition() else { fail(message()) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("CardFaceRenderContractTests: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
