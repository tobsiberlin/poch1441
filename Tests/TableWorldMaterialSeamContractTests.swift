import Foundation

@main
struct TableWorldMaterialSeamContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static func main() throws {
        let components = try source(at: "App/PlayComponents.swift")
        let travel = try source(at: "App/TravelTableRenderer.swift")
        let content = try source(at: "App/ContentView.swift")
        let phase2 = try source(at: "App/Phase2View.swift")
        let phase3 = try source(at: "App/Phase3View.swift")

        try boardBasisHasExactlyTwoCanonicalMaterials(components)
        try individualPieceSwitchesWithoutFallback(components)
        try pileSwitchesWithoutChangingCounts(components)
        try travelUsesOneDeterministicAssetResolver(travel)
        try centralStagesUseTheSharedSeam(content: content,
                                         phase2: phase2,
                                         phase3: phase3)

        FileHandle.standardOutput.write(
            Data("TableWorldMaterialSeamContractTests: PASS\n".utf8)
        )
    }

    private static func boardBasisHasExactlyTwoCanonicalMaterials(_ source: String) throws {
        let board = try section(in: source,
                                from: "struct TableWorldBoardBase: View",
                                through: "/// Ein einzelner regelneutraler Spielstein")
        expect(board.contains("case .pochDisc:"), "Board basis must render Track A")
        expect(board.contains("Image(\"PochDisc2026\")"),
               "Track A must use the canonical satin-aluminium 2026 Poch Disc")
        expect(!board.contains("PochRingPM49"),
               "The historical PM49 render must not remain a Track-A design anchor")
        expect(board.contains("case .unterwegs:"), "Board basis must render Track B")
        expect(board.contains("Image(\"TravelTray\")"), "Track B must use the approved travel tray")
        expect(board.components(separatedBy: ".accessibilityHidden(true)").count - 1 == 2,
               "Both bare board assets must stay decorative below semantic pool overlays")
        expect(!board.contains("default:"), "A new table world must not silently inherit a material")
    }

    private static func individualPieceSwitchesWithoutFallback(_ source: String) throws {
        let piece = try section(in: source,
                                from: "struct TableWorldPiece: View",
                                through: "enum TableWorldPiecePlacement")
        expect(piece.contains("R1Token(size: size, colorway: .naturalWhite)"),
               "Track A must render canonical R1 natural white")
        expect(piece.contains("TravelCentPiece(seed: seed,"),
               "Track B must render a deterministic approved 1-cent asset")
        expect(!piece.contains("TableChip"), "The shared seam must not reintroduce the legacy alias")
        expect(!piece.contains("default:"), "Piece material selection must remain exhaustive")
    }

    private static func pileSwitchesWithoutChangingCounts(_ source: String) throws {
        let pile = try section(in: source,
                               from: "struct TableWorldPiecePile: View",
                               through: "/// Engraved board notation")
        expect(pile.contains("TableTokenPile(count: count,"),
               "A free Track-A group must reuse stable R1 slots")
        expect(pile.contains("RecessedTokenPile(count: count,"),
               "A Track-A well must preserve its material lip")
        expect(pile.contains("TravelCoinPile(count: count,"),
               "Track B must reuse stable cent resting poses")
        expect(!pile.contains("min(count"),
               "The seam must pass the semantic count unchanged to material renderers")
        expect(!pile.contains("default:"), "Pile material selection must remain exhaustive")
    }

    private static func travelUsesOneDeterministicAssetResolver(_ source: String) throws {
        let pile = try section(in: source,
                               from: "struct TravelCoinPile: View",
                               through: "private extension TravelCompartment")
        expect(pile.contains("TravelCentAssetResolver.index(seed: seed,"),
               "Travel piles must use the shared deterministic variant resolver")
        expect(pile.contains("struct TravelCentPiece: View"),
               "Travel must expose the same approved material for a single coin")
        expect(pile.contains("TravelCoinLayout.poses(count: safeIndex + 1,"),
               "Single travel coins must share pile pose determinism")
        expect(pile.contains("static let variantCount = 6"),
               "Only the six approved one-cent surface variants may be selected")
    }

    private static func centralStagesUseTheSharedSeam(content: String,
                                                      phase2: String,
                                                      phase3: String) throws {
        let phase1Board = try section(in: content,
                                      from: "private var ringView: some View",
                                      through: "private var guidedIntroPool")
        expect(phase1Board.contains("TableWorldBoardBase(world: theme"),
               "Phase 1 must switch the complete board basis through TableWorld")
        let phase1Piles = try section(in: content,
                                      from: "private func pm49PoolOverlay",
                                      through: "private func presentedChips")
        expect(phase1Piles.contains("TableWorldPiecePile(world: theme"),
               "Phase 1 pool contents must switch through the shared pile seam")

        let compactBoard = try section(in: phase2,
                                       from: "private var compactRing: some View",
                                       through: "// MARK: - Gegner-Token")
        expect(compactBoard.contains("TableWorldBoardBase(world: theme"),
               "Phase 2 must switch the compact board basis through TableWorld")
        expect(compactBoard.contains("TableWorldPiecePile(world: theme"),
               "Phase 2 pools must switch through the shared pile seam")

        let betFlight = try section(in: phase2,
                                    from: "private struct PochBetFlight: View",
                                    through: "private func originPoint")
        expect(betFlight.contains("TableWorldPiece(world: world"),
               "Poch flights must keep the selected material in motion")
        expect(!betFlight.contains("R1Token("),
               "Track B Poch flights must never fall back to R1")
        expect(!phase3.contains("R1Token("),
               "Phase 3 results and payment streams must use the selected table material")
    }

    private static func source(at relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static func section(in source: String,
                                from startMarker: String,
                                through endMarker: String) throws -> String {
        guard let start = source.range(of: startMarker)?.lowerBound,
              let end = source.range(of: endMarker,
                                     range: start..<source.endIndex)?.upperBound else {
            fail("Unable to locate source section \(startMarker)")
        }
        return String(source[start..<end])
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(
            Data("TableWorldMaterialSeamContractTests: \(message)\n".utf8)
        )
        Foundation.exit(EXIT_FAILURE)
    }
}
