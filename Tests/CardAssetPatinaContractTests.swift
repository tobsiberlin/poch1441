import Foundation

@main
struct CardAssetPatinaContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    private static let scriptPath = "tools/gen_cards_vector_public_domain.py"
    private static let productionScriptPath = "tools/gen_card_damage_v10_reviews.py"
    private static let reviewCodes = ["AS", "KH", "QC", "10D"]

    private struct PatinaReport: Decodable, Equatable {
        let cards: [Card]

        struct Card: Decodable, Equatable {
            let alphaChangeFraction: Double
            let alphaChangedPixels: Int
            let alphaNickCount: Int
            let alphaNickMaxDepth: Int
            let alphaRemovedOpaquePixels: Int
            let assetName: String
            let code: String
            let cornerHandlingStrength: Double
            let cornerSoftness: Double
            let edgeFiberStrength: Double
            let edgeMatteRms: Double
            let edgeTextureRms: Double
            let folds: Int
            let gripZoneRms: Double
            let height: Int
            let handlingPolishRms: Double
            let inkEdgeGradient: Double
            let inkEdgeSoftening: Double
            let inkDrynessMax: Double
            let inkPorosity: Double
            let innerEdgeWidthRms: Double
            let indexContrast: Double
            let paperGrainLimit: Double
            let paperGrainRms: Double
            let paperLuminance: Double
            let paperNeutralSpread: Int
            let perimeterCoverage: Double
            let phoneCornerDifference: Double
            let phoneEdgeDifference: Double
            let printChroma: Double
            let printFade: Double
            let printRubOpacity: Double
            let printRubTraceCount: Int
            let printWearArea: Double
            let printWearLargeRoundComponents: Int
            let printWearMaxComponentPixels: Int
            let printWearOpacity: Double
            let registrationX: Int
            let registrationY: Int
            let saturation: Double
            let sha256: String
            let textureDirectionality: Double
            let texturePeriodicity: Double
            let width: Int
        }
    }

    static func main() throws {
        try sourceDeclaresBuildTimePatinaContract()
        try renderedReviewIsDeterministicAndLegible()
        try installedProductionMatchesFreshV10Stage()
        FileHandle.standardOutput.write(Data("CardAssetPatinaContractTests: PASS\n".utf8))
    }

    private static func sourceDeclaresBuildTimePatinaContract() throws {
        let source = try String(
            contentsOf: root.appendingPathComponent(scriptPath),
            encoding: .utf8
        )
        expect(source.contains("PAPER = (222, 220, 215, 255)"),
               "V8 card stock must remain neutral ivory-gray #DEDCD7")
        expect(source.contains("source_white = (") &&
               source.contains("source_white |"),
               "Legacy SVG white areas must be normalized into the V8 stock")
        expect(source.contains("PATINA_SATURATION = 0.59"),
               "Front saturation must remain inside the approved 0.57-0.61 band")
        expect(source.contains("EDGE_WEAR_MIN_PX = 12") &&
               source.contains("EDGE_WEAR_MAX_PX = 20"),
               "V8 handling wear must remain within the approved 12-20 px depth")
        expect(source.contains("PAPER_GRAIN_LIMIT = 0.02"),
               "Global paper fibre and micrograin must remain inside ±2%")
        expect(source.contains("def _isotropic_stock_grain") &&
               source.contains("def _multidirectional_fibres"),
               "V4 stock needs isotropic mottling and direction-balanced fibres")
        expect(!source.contains("vertical_source") && !source.contains("horizontal_source"),
               "Directional scanner-like texture sources must not return")
        expect(source.contains("def stock_texture_metrics"),
               "The 390 px review needs directionality and periodicity metrics")
        expect(source.contains("INK_EDGE_SOFTENING = 0.30") &&
               source.contains("INK_POROSITY_MAX = 0.14") &&
               source.contains("INK_DRYNESS_MAX = 0.035"),
               "Ink contours need restrained softness and dry-print porosity")
        expect(source.contains("PRINT_WEAR_AREA_MIN = 0.006") &&
               source.contains("PRINT_WEAR_AREA_MAX = 0.010") &&
               source.contains("PRINT_WEAR_OPACITY_MIN = 0.08") &&
               source.contains("PRINT_WEAR_OPACITY_MAX = 0.15"),
               "Large pips and figures need restrained, measurable print wear")
        expect(source.contains("PRINT_WEAR_MAX_COMPONENT_PX = 7") &&
               source.contains("def _micro_print_wear_mask") &&
               source.contains("def _large_round_component_count"),
               "V6 print wear must use bounded micro-pores and test connected components")
        expect(source.contains("FOLD_RIDGE_LEVEL = (12, 18)") &&
               source.contains("FOLD_SHADOW_LEVEL = (16, 23)") &&
               source.contains("FOLD_RIDGE_BLUR = 2.00") &&
               source.contains("FOLD_SHADOW_BLUR = 1.80") &&
               source.contains("FOLD_SHADOW_STRENGTH = 0.24"),
               "V7 folds must remain soft pressure traces without hard lines")
        expect(source.contains("EDGE_MATTE_STRENGTH = 0.12") &&
               source.contains("CORNER_HANDLING_STRENGTH = 0.28") &&
               source.contains("CORNER_SOFTNESS_MIN = 0.88") &&
               source.contains("CORNER_SOFTNESS_MAX = 1.12") &&
               source.contains("GRIP_ZONE_STRENGTH = 0.10") &&
               source.contains("HANDLING_POLISH_MAX = 0.025") &&
               source.contains("def _handling_polish"),
               "V9 needs individual matte grip zones, handled corners, and subtle paper polish")
        expect(source.contains("_blend_rgb(arr, (202, 202, 199), edge_gray)") &&
               source.contains("_blend_rgb(arr, (211, 210, 207), corner_handling)") &&
               source.contains("_blend_rgb(arr, (190, 190, 188), edge_fibres)"),
               "V8 edge wear must remain neutral gray without brown grime")
        expect(source.contains("def _perimeter_wear_masks") &&
               source.contains("def _tapered_edge_fibres"),
               "Edge material must use one continuous perimeter plus tapered fibres")
        expect(!source.contains("gap_box") && !source.contains("def _edge_wear_mask"),
               "Rectangular segmented abrasion must not return")
        expect(source.contains("hashlib.sha256(asset_name.encode"),
               "Patina seeds must derive from the public asset name with a stable hash")
        expect(source.contains("apply_build_time_patina(rendered, svg.name)"),
               "Patina must run after rendering and use the public SVG name")
        expect(source.contains("fold_count = int(rng.integers(1, 3))"),
               "Each well-used front needs one or two shallow folds")
        expect(source.contains("mask[protected] = 0"),
               "Print wear and folds must exclude protected index zones")
        expect(source.contains("ALPHA_NICK_MIN_COUNT = 1") &&
               source.contains("ALPHA_NICK_MAX_COUNT = 3") &&
               source.contains("ALPHA_NICK_MAX_DEPTH = 3") &&
               source.contains("ALPHA_NICK_MAX_CHANGED_PIXELS = 64") &&
               source.contains("def _subtle_alpha_nicks") &&
               source.contains("np.any(result > original_alpha)"),
               "V9 alpha variation must remain bounded and may never expand the silhouette")
        expect(source.contains("PRINT_RUB_OPACITY_MIN = 0.025") &&
               source.contains("PRINT_RUB_OPACITY_MAX = 0.045") &&
               source.contains("def _print_rub_traces"),
               "V9 needs one or two very weak tapered print-rub traces")
        expect(source.contains("add_mutually_exclusive_group(required=True)"),
               "The generator must require an explicit review or production mode")
        expect(source.contains("--write-production"),
               "Replacing production fronts must remain an explicit action")
        expect(source.contains("Direct V9 production writes are disabled"),
               "The legacy V9 writer must not bypass staged V10 promotion")
        expect(source.contains("PHONE_CARD_WIDTH = 72") &&
               source.contains("PHONE_CARD_HEIGHT = 103") &&
               source.contains("PHONE_HAND_TRANSLATIONS = (-116, -78, -40, 0, 40, 78, 116)") &&
               source.contains("PHONE_HAND_ROTATIONS = (-20, -13, -7, 0, 7, 13, 20)"),
               "Phone-hand evidence must preserve the canonical Track-B geometry")
        expect(source.contains("PHONE_HAND_CARDS = (\"10H\", \"AS\", \"10C\", \"KH\", \"10D\", \"8C\", \"9C\")") &&
               source.contains("def phone_hand_fan"),
               "Phone-hand evidence must use the canonical Track-B card sequence")
    }

    private static func renderedReviewIsDeterministicAndLegible() throws {
        let fileManager = FileManager.default
        let base = fileManager.temporaryDirectory
            .appendingPathComponent("poch-card-patina-tests-\(UUID().uuidString)")
        let first = base.appendingPathComponent("first")
        let second = base.appendingPathComponent("second")
        defer { try? fileManager.removeItem(at: base) }

        try renderReview(to: first)
        try renderReview(to: second)

        let firstReportData = try Data(contentsOf: first.appendingPathComponent("patina-report.json"))
        let secondReportData = try Data(contentsOf: second.appendingPathComponent("patina-report.json"))
        expect(firstReportData == secondReportData,
               "The same public asset names must produce byte-identical reports")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let report = try decoder.decode(PatinaReport.self, from: firstReportData)
        expect(report.cards.map(\.code) == reviewCodes,
               "The review must cover black/red, number/court representative cards")

        for card in report.cards {
            let firstPNG = try Data(contentsOf: first.appendingPathComponent("\(card.code).png"))
            let secondPNG = try Data(contentsOf: second.appendingPathComponent("\(card.code).png"))
            expect(firstPNG == secondPNG,
                   "\(card.code) must render deterministically from its public asset name")
            expect(pngDimensions(firstPNG) == (624, 888),
                   "\(card.code) must preserve the 624x888 master dimensions")
            expect(card.width == 624 && card.height == 888,
                   "\(card.code) report dimensions must match the PNG")
            expect((0.57...0.61).contains(card.saturation),
                   "\(card.code) saturation escaped the approved band")
            expect((1...2).contains(card.folds),
                   "\(card.code) must have one or two shallow folds")
            expect(card.perimeterCoverage >= 0.99,
                   "\(card.code) perimeter wear must be continuous")
            expect(card.innerEdgeWidthRms > 0.2,
                   "\(card.code) inner perimeter edge became digitally uniform")
            expect(card.edgeFiberStrength <= 0.45,
                   "\(card.code) edge fibres became grime-like")
            expect(card.edgeMatteRms > 0.05 && card.cornerHandlingStrength == 0.28,
                   "\(card.code) edge and corner handling became digitally uniform")
            expect((0.88...1.12).contains(card.cornerSoftness) && card.gripZoneRms >= 0.20,
                   "\(card.code) needs individual corner softness and side/lower grip wear")
            expect(card.edgeTextureRms >= 2.0,
                   "\(card.code) edge material disappears at mobile scale")
            expect(card.paperGrainLimit == 0.02 && card.paperGrainRms > 0,
                   "\(card.code) global paper micrograin escaped its ±2% contract")
            expect((216...224).contains(card.paperLuminance) && card.paperNeutralSpread <= 8,
                   "\(card.code) paper stock became too white, yellow, or brown")
            expect(card.textureDirectionality <= 1.08,
                   "\(card.code) stock texture has a dominant direction at 390 px")
            expect(card.texturePeriodicity <= 0.01,
                   "\(card.code) stock texture has a visible periodic repeat at 390 px")
            expect(card.inkEdgeSoftening <= 0.30 && card.inkPorosity <= 0.14 &&
                   card.inkDrynessMax <= 0.035,
                   "\(card.code) printed ink became blurry or damaged")
            expect(card.inkEdgeGradient > 0,
                   "\(card.code) ink contour metric must remain measurable")
            expect(card.printFade <= 0.125,
                   "\(card.code) dry-print fading became neglected or dirty")
            expect((0.006...0.010).contains(card.printWearArea),
                   "\(card.code) large-print wear escaped the 0.6-1.0% area contract")
            expect((0.08...0.15).contains(card.printWearOpacity),
                   "\(card.code) large-print wear escaped the 8-15% opacity contract")
            expect(card.printWearLargeRoundComponents == 0,
                   "\(card.code) print wear contains a round dropout wider than 3 px")
            expect(card.printWearMaxComponentPixels <= 7,
                   "\(card.code) print wear merged beyond a short tapered abrasion")
            expect((1...2).contains(card.printRubTraceCount) &&
                   (0.025...0.045).contains(card.printRubOpacity),
                   "\(card.code) print rub escaped the weak one-or-two-trace contract")
            expect(card.handlingPolishRms > 0 && card.handlingPolishRms <= 0.025,
                   "\(card.code) handling polish became absent or stain-like")
            expect(card.printChroma >= 0,
                   "\(card.code) print material metric must remain finite")
            expect(abs(card.registrationX) <= 1 && abs(card.registrationY) <= 1,
                   "\(card.code) print registration drift exceeds one pixel")
            expect(card.indexContrast >= 100,
                   "\(card.code) protected corner indices lost readable contrast")
            expect(card.phoneEdgeDifference >= 3.3,
                   "\(card.code) handling rim disappears at the Track-B phone-hand size")
            expect(card.phoneCornerDifference >= 3.3,
                   "\(card.code) softened corners disappear at the Track-B phone-hand size")
            expect(card.assetName == "\(card.code).svg",
                   "\(card.code) must expose its public SVG seed identity")
            expect(card.sha256.count == 64,
                   "\(card.code) report must contain a complete SHA-256 digest")
            expect((1...3).contains(card.alphaNickCount) &&
                   (1...3).contains(card.alphaNickMaxDepth),
                   "\(card.code) must have one to three shallow silhouette nicks")
            expect((1...64).contains(card.alphaChangedPixels) &&
                   card.alphaRemovedOpaquePixels <= card.alphaChangedPixels &&
                   card.alphaChangeFraction <= 0.00012,
                   "\(card.code) alpha variation exceeded the cared-for silhouette limit")
        }

        let firstSheet = try Data(contentsOf: first.appendingPathComponent("card-patina-review.png"))
        let secondSheet = try Data(contentsOf: second.appendingPathComponent("card-patina-review.png"))
        expect(firstSheet == secondSheet,
               "The 390 px four-card review sheet must also be deterministic")
        expect(pngDimensions(firstSheet) == (906, 1_308),
               "The mobile review must present each card at exactly 390 px")

        let firstOriginal = try Data(
            contentsOf: first.appendingPathComponent("card-patina-original-size.png")
        )
        let secondOriginal = try Data(
            contentsOf: second.appendingPathComponent("card-patina-original-size.png")
        )
        expect(firstOriginal == secondOriginal,
               "The original-size four-card review sheet must be deterministic")
        expect(pngDimensions(firstOriginal) == (1_374, 1_974),
               "The original-size review must present each 624x888 master without scaling")

        let firstPhoneHand = try Data(
            contentsOf: first.appendingPathComponent("card-patina-phone-hand.png")
        )
        let secondPhoneHand = try Data(
            contentsOf: second.appendingPathComponent("card-patina-phone-hand.png")
        )
        expect(firstPhoneHand == secondPhoneHand,
               "The canonical Track-B phone-hand fan must be deterministic")
        expect(pngDimensions(firstPhoneHand) == (390, 180),
               "Phone-hand evidence must use the canonical 390 px Track-B stage")
    }

    private static func installedProductionMatchesFreshV10Stage() throws {
        let fileManager = FileManager.default
        let base = fileManager.temporaryDirectory
            .appendingPathComponent("poch-card-production-stage-\(UUID().uuidString)")
        let stage = base.appendingPathComponent("stage")
        defer { try? fileManager.removeItem(at: base) }
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)

        let process = Process()
        process.currentDirectoryURL = root
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", productionScriptPath, "--stage-production", stage.path]
        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(
                data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8
            ) ?? "unknown production-stage error"
            fail("Fresh V10 production stage failed: \(message)")
        }

        let comparisons = [
            (stage.appendingPathComponent("Cards"),
             root.appendingPathComponent("App/Assets.xcassets/Cards")),
            (stage.appendingPathComponent("final"),
             root.appendingPathComponent("Assets_Raw/cards/final")),
            (stage.appendingPathComponent("CardBackDamage"),
             root.appendingPathComponent("App/Assets.xcassets/CardBackDamage")),
        ]
        for (fresh, installed) in comparisons {
            let freshFiles = try relativeFiles(in: fresh)
            let installedFiles = try relativeFiles(in: installed)
            expect(freshFiles == installedFiles,
                   "Installed V10 assets differ from a fresh deterministic production stage")
            for relativePath in freshFiles {
                let freshData = try Data(contentsOf: fresh.appendingPathComponent(relativePath))
                let installedData = try Data(contentsOf: installed.appendingPathComponent(relativePath))
                expect(freshData == installedData,
                       "Installed V10 asset differs from fresh stage: \(relativePath)")
            }
        }

        let rawMasters = try relativeFiles(in: stage.appendingPathComponent("final"))
        expect(rawMasters.count == 32 && rawMasters.allSatisfy { $0.hasSuffix(".png") },
               "V10 production stage must contain exactly 32 front masters")
        let cardRenditions = try relativeFiles(in: stage.appendingPathComponent("Cards"))
        expect(cardRenditions.count == 96,
               "V10 Cards stage must preserve 32 Contents files plus 64 2x/3x PNGs")
        for relativePath in rawMasters {
            let data = try Data(contentsOf: stage.appendingPathComponent("final/\(relativePath)"))
            expect(pngDimensions(data) == (624, 888),
                   "V10 raw front master changed canonical 624x888 dimensions")
        }
    }

    private static func relativeFiles(in directory: URL) throws -> [String] {
        let resolvedDirectory = directory.resolvingSymlinksInPath()
        guard let enumerator = FileManager.default.enumerator(
            at: resolvedDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return try enumerator.compactMap { element in
            guard let url = element as? URL,
                  try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
            else { return nil }
            guard let rootIndex = url.pathComponents.lastIndex(
                of: resolvedDirectory.lastPathComponent
            ) else { return nil }
            return url.pathComponents.dropFirst(rootIndex + 1).joined(separator: "/")
        }.sorted()
    }

    private static func renderReview(to output: URL) throws {
        let process = Process()
        process.currentDirectoryURL = root
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3", scriptPath,
            "--review-output", output.path,
            "--cards", reviewCodes.joined(separator: ","),
        ]
        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(
                data: stderr.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? "unknown generator error"
            fail("Review generator failed: \(message)")
        }
    }

    private static func pngDimensions(_ data: Data) -> (Int, Int) {
        expect(data.count >= 24 && Array(data.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10],
               "Generated evidence must be PNG")
        let bytes = [UInt8](data)
        func integer(at offset: Int) -> Int {
            bytes[offset..<offset + 4].reduce(0) { ($0 << 8) | Int($1) }
        }
        return (integer(at: 16), integer(at: 20))
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("CardAssetPatinaContractTests: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
