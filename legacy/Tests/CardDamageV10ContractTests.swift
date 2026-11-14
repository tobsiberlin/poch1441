import Foundation

@main
struct CardDamageV10ContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    private static let script = "tools/gen_card_damage_v10_reviews.py"

    private struct FrontReport: Decodable {
        let distribution: [String: Int]
        let cards: [FrontCard]
    }

    private struct FrontCard: Decodable {
        let code: String
        let damageType: String
        let indexContrast: Double
        let cornerChipPixels: Int
    }

    private struct BackReport: Decodable {
        let variantCount: Int
        let canvas: [Int]
        let sourceAlphaSha256: String
        let distribution: [String: Int]
        let phoneVariantOrder: [Int]
        let materialContract: BackMaterialContract
        let variants: [BackVariant]
    }

    private struct BackMaterialContract: Decodable {
        let version: String
        let stressLineLuminanceReductionPercent: Int
        let stressLineSegmentBreaks: [Int]
        let stressLineBranches: [Int]
        let repairFilmOpacityRange: [Double]
        let repairFilmWidthRange: [Int]
        let repairFilmReflectionEdges: Int
        let alphaPreserved: Bool
    }

    private struct BackVariant: Decodable {
        let variant: Int
        let primaryDamage: String
        let damageBbox: [Int]?
        let alphaSha256: String
    }

    static func main() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("poch-v10-damage-contract-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let firstFront = base.appendingPathComponent("front-1")
        let secondFront = base.appendingPathComponent("front-2")
        let firstBack = base.appendingPathComponent("back-1")
        let secondBack = base.appendingPathComponent("back-2")
        try run("--front-output", firstFront)
        try run("--front-output", secondFront)
        try run("--back-output", firstBack)
        try run("--back-output", secondBack)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let frontData = try Data(contentsOf: firstFront.appendingPathComponent("damage-report.json"))
        let secondFrontData = try Data(contentsOf: secondFront.appendingPathComponent("damage-report.json"))
        expect(frontData == secondFrontData,
               "Front damage report must be deterministic")
        let front = try decoder.decode(FrontReport.self, from: frontData)
        expect(front.distribution == ["stress_line": 6, "repair_film": 3,
                                      "corner_fold": 5, "corner_chip": 2, "none": 16],
               "Front damage distribution escaped the approved 6/3/5/2 plan")
        expect(front.cards.count == 32 && front.cards.map(\.code).uniqued().count == 32,
               "Front review must contain all 32 unique cards")
        expect(front.cards.allSatisfy { $0.indexContrast >= 100 },
               "Front damage obscured a protected index")
        expect(front.cards.filter { $0.damageType == "corner_chip" }
            .allSatisfy { (1...40).contains($0.cornerChipPixels) },
               "Corner chips exceeded the tiny cared-for limit")
        let firstFrontAtlas = try Data(contentsOf: firstFront.appendingPathComponent("damage-atlas.png"))
        let secondFrontAtlas = try Data(contentsOf: secondFront.appendingPathComponent("damage-atlas.png"))
        expect(firstFrontAtlas == secondFrontAtlas,
               "Front damage atlas must be deterministic")

        let backData = try Data(contentsOf: firstBack.appendingPathComponent("back-damage-report.json"))
        let secondBackData = try Data(contentsOf: secondBack.appendingPathComponent("back-damage-report.json"))
        expect(backData == secondBackData,
               "Back damage report must be deterministic")
        let back = try decoder.decode(BackReport.self, from: backData)
        expect((8...12).contains(back.variantCount) && back.variants.count == back.variantCount,
               "Back prototype count must remain between 8 and 12")
        expect(back.canvas == [1_000, 1_400], "Back variants changed the W2 canvas")
        expect(back.distribution == ["stress_line": 4, "repair_film": 3,
                                     "edge_compression": 2, "quiet": 1],
               "Back V10.2 distribution escaped the approved 4/3/2/1 plan")
        expect(back.materialContract.version == "V10.2" &&
               back.materialContract.stressLineLuminanceReductionPercent == 40 &&
               back.materialContract.stressLineSegmentBreaks == [2, 4] &&
               back.materialContract.stressLineBranches == [1, 2],
               "Back stress lines escaped the quieter interrupted V10.2 material model")
        expect(back.materialContract.repairFilmOpacityRange == [0.13, 0.15] &&
               back.materialContract.repairFilmWidthRange == [50, 66] &&
               back.materialContract.repairFilmReflectionEdges == 1,
               "Back repair film escaped the narrow integrated V10.2 material model")
        expect(back.materialContract.alphaPreserved,
               "Back V10.2 must declare silhouette preservation")
        expect(back.phoneVariantOrder.count == 7 && Set(back.phoneVariantOrder).count == 7,
               "Back phone fan must mix seven distinct material variants")
        expect(Set(back.variants.map(\.alphaSha256)) == Set([back.sourceAlphaSha256]),
               "Back variants must preserve one identical alpha silhouette")
        expect(back.variants.allSatisfy { variant in
            !(variant.primaryDamage.contains("rank") || variant.primaryDamage.contains("suit"))
        }, "Back variants leaked card identity")
        expect(back.variants.filter { $0.primaryDamage != "quiet" }
            .allSatisfy { $0.damageBbox?.count == 4 },
               "Every visible back damage needs a 1:1 crop location")
        let firstBackAtlas = try Data(contentsOf: firstBack.appendingPathComponent("back-damage-atlas.png"))
        let secondBackAtlas = try Data(contentsOf: secondBack.appendingPathComponent("back-damage-atlas.png"))
        expect(firstBackAtlas == secondBackAtlas,
               "Back damage atlas must be deterministic")
        let firstBackCrops = try Data(contentsOf: firstBack.appendingPathComponent("back-damage-crops-1x.png"))
        let secondBackCrops = try Data(contentsOf: secondBack.appendingPathComponent("back-damage-crops-1x.png"))
        expect(firstBackCrops == secondBackCrops,
               "Back 1:1 damage crops must be deterministic")
        expect(pngDimensions(firstBackCrops) == (1_140, 786),
               "Back damage crops must remain unscaled 1:1 evidence")
        let firstBackPhone = try Data(contentsOf: firstBack.appendingPathComponent("back-phone-hand.png"))
        let secondBackPhone = try Data(contentsOf: secondBack.appendingPathComponent("back-phone-hand.png"))
        expect(firstBackPhone == secondBackPhone && pngDimensions(firstBackPhone) == (390, 180),
               "Back phone hand must be deterministic on the 390 px stage")
        try productionPipelineAndInstalledOverlaysAreContracted()
        print("CardDamageV10ContractTests: PASS")
    }

    private static func productionPipelineAndInstalledOverlaysAreContracted() throws {
        let source = try String(
            contentsOf: root.appendingPathComponent(script), encoding: .utf8
        )
        expect(source.contains("--promote-production") &&
               source.contains("--backup-root") &&
               source.contains("assert_clean_production_paths"),
               "V10 production writes must remain explicit and dirty-path guarded")
        expect(source.contains("manifest-before.json") &&
               source.contains("manifest-stage.json") &&
               source.contains("manifest-after.json") &&
               source.contains("replace_production_from_stage"),
               "V10 production promotion must retain before/stage/after manifests and rollback")
        expect(source.contains("actool_validate") &&
               source.contains("back_damage_overlay"),
               "V10 production must validate the catalog and render pure damage overlays")

        let catalog = root.appendingPathComponent("App/Assets.xcassets/CardBackDamage")
        let expectedSets = Set((0..<10).map { String(format: "card_back_damage_%02d.imageset", $0) })
        let actualSets = try Set(FileManager.default.contentsOfDirectory(atPath: catalog.path)
            .filter { $0.hasSuffix(".imageset") })
        expect(actualSets == expectedSets,
               "Production must contain exactly card_back_damage_00...09")
        for index in 0..<10 {
            let name = String(format: "card_back_damage_%02d", index)
            let imageset = catalog.appendingPathComponent("\(name).imageset")
            let files = try Set(FileManager.default.contentsOfDirectory(atPath: imageset.path))
            expect(files == Set(["Contents.json", "\(name)@2x.png", "\(name)@3x.png"]),
                   "\(name) imageset contains unexpected or missing files")
            let two = try Data(contentsOf: imageset.appendingPathComponent("\(name)@2x.png"))
            let three = try Data(contentsOf: imageset.appendingPathComponent("\(name)@3x.png"))
            expect(pngDimensions(two) == (312, 444) && pngDimensions(three) == (468, 666),
                   "\(name) escaped the canonical 52:74 2x/3x canvas")
            expect([two, three].allSatisfy { [UInt8]($0)[25] == 6 },
                   "\(name) must remain an RGBA PNG")
        }

        let audit = Process()
        audit.currentDirectoryURL = root
        audit.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        audit.arguments = ["python3", "-c", Self.alphaAudit]
        audit.standardOutput = Pipe()
        audit.standardError = FileHandle.standardError
        try audit.run()
        audit.waitUntilExit()
        expect(audit.terminationStatus == 0,
               "Production back overlays contain a base, signet, opaque hull, or invalid alpha")
    }

    private static let alphaAudit = #"""
from pathlib import Path
from PIL import Image
import numpy as np

root = Path("App/Assets.xcassets/CardBackDamage")
paths = sorted(root.glob("*.imageset/*.png"))
assert len(paths) == 20
for path in paths:
    image = np.asarray(Image.open(path).convert("RGBA"), dtype=np.uint8)
    height, width = image.shape[:2]
    alpha = image[:, :, 3]
    assert not np.any(image[alpha == 0, :3])
    coverage = np.count_nonzero(alpha) / alpha.size
    quiet = "card_back_damage_09" in path.name
    assert coverage == 0 if quiet else 0 < coverage < 0.13
    assert alpha.max() < 200
    center = alpha[round(height * .35):round(height * .65),
                   round(width * .30):round(width * .70)]
    assert not np.any(center)
    corner_height, corner_width = height // 10, width // 10
    assert not np.any(alpha[:corner_height, :corner_width])
    assert not np.any(alpha[:corner_height, -corner_width:])
    assert not np.any(alpha[-corner_height:, :corner_width])
    assert not np.any(alpha[-corner_height:, -corner_width:])
"""#

    private static func run(_ flag: String, _ output: URL) throws {
        let process = Process()
        process.currentDirectoryURL = root
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", script, flag, output.path]
        process.standardOutput = Pipe()
        process.standardError = FileHandle.standardError
        try process.run()
        process.waitUntilExit()
        expect(process.terminationStatus == 0, "V10 review generator failed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("CardDamageV10ContractTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }

    private static func pngDimensions(_ data: Data) -> (Int, Int) {
        let bytes = [UInt8](data)
        expect(bytes.count >= 24 && Array(bytes.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10],
               "Evidence must be PNG")
        func integer(_ offset: Int) -> Int {
            bytes[offset..<offset + 4].reduce(0) { ($0 << 8) | Int($1) }
        }
        return (integer(16), integer(20))
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] { Array(Set(self)) }
}
