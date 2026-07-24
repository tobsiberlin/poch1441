import Foundation

@main
struct CardBackW3SelectionContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    private static let script = "tools/gen_card_back_w3_selection.py"

    private struct Report: Decodable, Equatable {
        let canvas: [Int]
        let favorite: Int
        let favoriteName: String
        let palette: [String: String]
        let candidates: [Candidate]
    }

    private struct Candidate: Decodable, Equatable {
        let number: Int
        let slug: String
        let name: String
        let direction: String
        let damageVariant: Int
        let damage: String
        let scores: Scores
        let verdict: String
        let favorite: Bool?
        let cleanRotationRms: Double
        let phonePatternContrast: Double
        let damageAlphaCoverage: Double
        let svgSha256: String
        let pngSha256: String
    }

    private struct Scores: Decodable, Equatable {
        let authenticity: Double
        let phone: Double
        let printability: Double
        var mean: Double { (authenticity + phone + printability) / 3 }
    }

    static func main() throws {
        try sourceIsCodeNativeAndProductionSafe()
        try selectionIsDeterministicDistinctAndLegible()
        print("CardBackW3SelectionContractTests: PASS")
    }

    private static func sourceIsCodeNativeAndProductionSafe() throws {
        let source = try String(
            contentsOf: root.appendingPathComponent(script), encoding: .utf8
        )
        expect(source.contains("rsvg-convert") && source.contains("candidate_svg"),
               "W3 must remain a code-native SVG pipeline")
        expect(!source.lowercased().contains("imagegen") &&
               !source.lowercased().contains("replicate"),
               "W3 selection must not invoke image generation services")
        expect(source.contains("back_damage_overlay") && source.contains("V10.2"),
               "Every W3 candidate must demonstrate the approved V10.2 damage system")
        expect(!source.contains("App/Assets.xcassets") &&
               !source.contains("Assets_Raw/cards/final"),
               "W3 selection must not write App or production assets")
        expect(source.contains("rotate(180 500 700)"),
               "W3 patterns must explicitly construct 180-degree symmetry")
    }

    private static func selectionIsDeterministicDistinctAndLegible() throws {
        let manager = FileManager.default
        let base = manager.temporaryDirectory
            .appendingPathComponent("poch-w3-selection-\(UUID().uuidString)")
        let first = base.appendingPathComponent("first")
        let second = base.appendingPathComponent("second")
        defer { try? manager.removeItem(at: base) }
        try manager.createDirectory(at: base, withIntermediateDirectories: true)
        try generate(first)
        try generate(second)

        let firstFiles = try relativeFiles(in: first)
        let secondFiles = try relativeFiles(in: second)
        expect(firstFiles == secondFiles && firstFiles.count == 17,
               "W3 must emit the same six SVGs, six PNGs, HTML, report, and review sheets")
        for path in firstFiles {
            try expect(Data(contentsOf: first.appendingPathComponent(path)) ==
                       Data(contentsOf: second.appendingPathComponent(path)),
                       "W3 output must be byte-deterministic: \(path)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let report = try decoder.decode(
            Report.self,
            from: Data(contentsOf: first.appendingPathComponent("w3-selection-report.json"))
        )
        expect(report.canvas == [1_000, 1_400] && report.candidates.count == 6,
               "W3 must contain six 1000x1400 candidates")
        expect(report.candidates.map(\.number) == Array(1...6),
               "W3 candidate order changed")
        expect(Set(report.candidates.map(\.direction)).count == 6 &&
               Set(report.candidates.map(\.slug)).count == 6,
               "W3 directions must remain materially distinct")
        expect(report.palette == [
            "paper": "#D4C5A7", "indigo": "#34495B", "charcoal": "#292C2D",
        ], "W3 palette escaped warm paper plus restrained indigo/charcoal")

        for candidate in report.candidates {
            expect(candidate.cleanRotationRms <= 1.2,
                   "Candidate \(candidate.number) lost 180-degree symmetry")
            expect(candidate.phonePatternContrast >= 5,
                   "Candidate \(candidate.number) pattern disappears at phone size")
            expect((0.0005...0.04).contains(candidate.damageAlphaCoverage),
                   "Candidate \(candidate.number) does not visibly demonstrate V10.2 damage")
            expect((7.5...10).contains(candidate.scores.authenticity) &&
                   (7.5...10).contains(candidate.scores.phone) &&
                   (7.5...10).contains(candidate.scores.printability),
                   "Candidate \(candidate.number) self-assessment escaped the review scale")
            expect(candidate.svgSha256.count == 64 && candidate.pngSha256.count == 64,
                   "Candidate \(candidate.number) needs complete SVG/PNG digests")

            let stem = String(format: "candidate-%02d-%@", candidate.number, candidate.slug)
            let png = try Data(contentsOf: first.appendingPathComponent("\(stem).png"))
            expect(pngDimensions(png) == (1_000, 1_400) && [UInt8](png)[25] == 6,
                   "Candidate \(candidate.number) must be a transparent 1000x1400 RGBA PNG")
            let svg = try String(
                contentsOf: first.appendingPathComponent("\(stem).svg"), encoding: .utf8
            )
            expect(!svg.contains("<text") && !svg.contains(candidate.name),
                   "Candidate labels or lettering must never be drawn inside a card")
            expect(svg.contains("width=\"1000\"") && svg.contains("height=\"1400\"") &&
                   svg.components(separatedBy: "<rect x=\"").count >= 4,
                   "Candidate must preserve canvas plus double worn border geometry")
        }

        let best = report.candidates.max { $0.scores.mean < $1.scores.mean }
        expect(report.favorite == 2 && report.favoriteName == "Guilloche-Bandgewebe" &&
               best?.number == 2 && report.candidates[1].favorite == true,
               "Guilloche-Bandgewebe must remain the evidence-backed W3 favorite")

        let phone = try Data(contentsOf: first.appendingPathComponent("w3-phone-fan.png"))
        let atlas = try Data(contentsOf: first.appendingPathComponent("w3-selection-atlas.png"))
        let detail = try Data(contentsOf: first.appendingPathComponent("w3-detail-sheet.png"))
        expect(pngDimensions(phone) == (390, 180), "W3 phone fan must use a 390 px stage")
        expect(pngDimensions(atlas) == (656, 1_448), "W3 atlas must remain a 2x3 review")
        expect(pngDimensions(detail) == (960, 536), "W3 detail sheet must preserve 1:1 crops")

        let html = try String(
            contentsOf: first.appendingPathComponent("index.html"), encoding: .utf8
        )
        expect(html.components(separatedBy: "<figcaption>").count - 1 == 6 &&
               html.contains("@media(max-width:720px)"),
               "HTML must label candidates outside cards and remain phone-responsive")
        expect(!html.contains("position:absolute"),
               "HTML labels must not be overlaid onto the card artwork")
    }

    private static func generate(_ output: URL) throws {
        let process = Process()
        process.currentDirectoryURL = root
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", script, "--output", output.path]
        process.standardOutput = Pipe()
        process.standardError = FileHandle.standardError
        try process.run()
        process.waitUntilExit()
        expect(process.terminationStatus == 0, "W3 generator failed")
    }

    private static func relativeFiles(in directory: URL) throws -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return [] }
        return try enumerator.compactMap { value in
            guard let url = value as? URL,
                  try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
            else { return nil }
            guard let index = url.pathComponents.lastIndex(of: directory.lastPathComponent)
            else { return nil }
            return url.pathComponents.dropFirst(index + 1).joined(separator: "/")
        }.sorted()
    }

    private static func pngDimensions(_ data: Data) -> (Int, Int) {
        let bytes = [UInt8](data)
        expect(bytes.count >= 26 && Array(bytes.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10],
               "Review evidence must be PNG")
        func integer(_ offset: Int) -> Int {
            bytes[offset..<offset + 4].reduce(0) { ($0 << 8) | Int($1) }
        }
        return (integer(16), integer(20))
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool,
                               _ message: String) rethrows {
        if try !condition() {
            FileHandle.standardError.write(Data("CardBackW3SelectionContractTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
