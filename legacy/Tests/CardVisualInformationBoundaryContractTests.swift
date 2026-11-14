import Foundation

@main
struct CardVisualInformationBoundaryContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static func main() throws {
        let dealOverlay = try source("App/DealOverlay.swift")
        let phase3 = try source("App/Phase3View.swift")

        expect(!dealOverlay.contains("CardFace("),
               "DealOverlay must render hidden cards exclusively as CardBack")
        expect(!dealOverlay.contains("assetName"),
               "DealOverlay must not inspect a face asset identity")
        expect(!contains(pattern: #"upcard\s*\.\s*rank"#, in: dealOverlay),
               "DealOverlay must not route a hidden rank into view identity or motion")
        expect(dealOverlay.contains(#".id("fly-\(generation)-\(i)-slot-\(order[i].slot)")"#),
               "Deal flights need an identity made only from generation, sequence, and slot")
        let visibleBackCount = dealOverlay.components(separatedBy: "CardBack(").count - 1
        let materialVariantCount = dealOverlay.components(separatedBy: "materialVariant:").count - 1
        expect(visibleBackCount == materialVariantCount,
               "Every visible deal back must receive an identity-neutral material variant")

        let materialRoute = try section(
            in: dealOverlay,
            from: "private enum DealBackMaterial",
            through: "/// Gemeinsame Ruheposen"
        )
        for forbidden in [#"\bCard\b"#, #"\bRank\b"#, #"\bSuit\b"#, #"asset(Name|ID)"#] {
            expect(!contains(pattern: forbidden, in: materialRoute),
                   "Back material routing must not receive hidden identity: \(forbidden)")
        }

        let flyingBack = try section(
            in: dealOverlay,
            from: "private struct FlyingBack: View",
            through: "/// Der Puls"
        )
        for forbidden in ["CardFace(", "Card(", "upcard", "rank", "suit", "assetName"] {
            expect(!flyingBack.contains(forbidden),
                   "FlyingBack motion must not depend on hidden \(forbidden) identity")
        }
        expect(flyingBack.contains("materialVariant: DealBackMaterial.variant("),
               "The flying back must use the shared public placement route")

        expect(phase3.contains("let lastPlay = lastRevealedPlay"),
               "Phase 3 must gate a card arrival through lastRevealedPlay")
        expect(phase3.contains("game.revealedPlayEvents.last"),
               "lastRevealedPlay must come from the public reveal stream")
        let arrivalGate = try section(
            in: phase3,
            from: "Phase3CardArrival(card: lastPlay.card",
            through: ".allowsHitTesting(false)"
        )
        expect(arrivalGate.contains("Phase3CardArrival(card: lastPlay.card"),
               "The flight face must use the already revealed play")
        expect(arrivalGate.contains(#".id("arrival-\(playGeneration)-\(playSequence)")"#),
               "Revealed-card flights need public presentation identity")
        expect(arrivalGate.contains(".allowsHitTesting(false)"),
               "The revealed-card flight must remain non-interactive")

        expect(phase3.contains("game.revealedPlayEvents.prefix(settledPlays)"),
               "Tableau cards must be limited to plays whose flights have settled")
        let settledChains = try section(
            in: phase3,
            from: "private var settledChains:",
            through: "// MARK: - Rundenende"
        )
        expect(settledChains.contains("for play in game.revealedPlayEvents.prefix(settledPlays)"),
               "Settled chains must not include a merely revealed in-flight card")

        let humanHand = try section(
            in: phase3,
            from: "private func handFan(canvas:",
            through: "// MARK: - Rundenende"
        )
        expect(humanHand.contains("let cards = game.displayedHumanHand"),
               "Interactive face buttons must be limited to the human hand")
        expect(humanHand.contains(".contentShape(Rectangle())"),
               "Human card buttons need a stable rectangular hit shape independent of face alpha")

        FileHandle.standardOutput.write(
            Data("CardVisualInformationBoundaryContractTests: PASS\n".utf8)
        )
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static func section(in source: String,
                                from startMarker: String,
                                through endMarker: String) throws -> String {
        guard let start = source.range(of: startMarker)?.lowerBound,
              let end = source.range(of: endMarker, range: start..<source.endIndex)?.upperBound else {
            throw ContractError.missingSection("\(startMarker) ... \(endMarker)")
        }
        return String(source[start..<end])
    }

    private static func contains(pattern: String, in source: String) -> Bool {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return true }
        return expression.firstMatch(
            in: source,
            range: NSRange(source.startIndex..<source.endIndex, in: source)
        ) != nil
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(
                Data("CardVisualInformationBoundaryContractTests: \(message)\n".utf8)
            )
            Foundation.exit(EXIT_FAILURE)
        }
    }

    private enum ContractError: Error {
        case missingSection(String)
    }
}
