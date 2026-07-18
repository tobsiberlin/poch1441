import Foundation

@main
struct Phase2PresentationContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static func main() throws {
        let source = try String(
            contentsOf: root.appendingPathComponent("App/Phase2View.swift"),
            encoding: .utf8
        )
        let gameState = try String(
            contentsOf: root.appendingPathComponent("App/GameState.swift"),
            encoding: .utf8
        )
        let impactFlight = try String(
            contentsOf: root.appendingPathComponent("App/ImpactFlight.swift"),
            encoding: .utf8
        )

        expect(source.contains(".id(\"poch-bet-\\(game.betTransfer)\")"),
               "Every bet transfer needs a fresh flight state")
        expect(source.contains("commitBetImpact(transfer: transfer)"),
               "Bet contacts must be bound to their transfer generation")
        expect(source.contains("guard game.betTransfer == settledBetTransfer"),
               "The payout must wait for the final paid bet to land")
        expect(source.contains("guard !phase2ReduceMotion else"),
               "Reduced Motion must settle without an invisible bet flight")

        let payout = try section(in: source,
                                 from: "private struct PochPayoutFlight: View",
                                 through: "private struct PochBetFlight: View")
        expect(payout.contains("ImpactFlight("),
               "The winner payout must use the shared contact-driven flight")
        expect(payout.contains("activeSeats: [Int]"),
               "Winner targets must derive from the active public seat layout")
        expect(payout.contains("onImpact()"),
               "The payout may settle only at material contact")

        let result = try section(in: source,
                                 from: "private var resultBanner: some View",
                                 through: "// MARK: - Bausteine")
        expect(result.components(separatedBy: "isEnabled: payoutControlsEnabled").count - 1 == 2,
               "Both Phase-2 exits must wait for the payout to land")
        expect(source.contains(".accessibilityAdjustableAction"),
               "The bid rail needs a non-drag accessibility path")
        expect(source.contains("game.resumeBettingIfNeeded()"),
               "Phase 2 must resume when the rotated opening seat is a bot")
        expect(source.contains("stack: presentedStack(of: seat)"),
               "Winner stacks must remain causal until material contact")
        expect(source.contains("let settled = game.displayedStack(of: seat)"),
               "Opponent stacks must expose their engine value after contact")
        expect(source.contains("let freeStageCenterX = sliderVisualRightEdge"),
               "Portrait Phase 2 must center the board in the free slider-to-edge stage")
        expect(source.contains(".position(x: freeStageCenterX,"),
               "The compact board must use the free-stage center instead of hugging the edge")

        let pot = try section(in: source,
                              from: "private var pochPotMini: some View",
                              through: "private func miniTile")
        expect(pot.contains("if theme.isTravelTable"),
               "Only Track B may retain the colored Poch-pot material treatment")
        expect(pot.contains(".strokeBorder(Color(hex: 0x6C7176).opacity(0.48)"),
               "Track A must leave the real center-well material visible")
        expect(pot.contains("Tokens.jewelPlatin.opacity(0.58)"),
               "Track-A Poch text must stay neutral instead of tinting the center purple")
        expect(gameState.contains("registerTransfer(actor: uiSeat"),
               "Payout QA must exercise the production transfer presentation path")
        expect(impactFlight.contains("private struct FlightPathEffect: GeometryEffect"),
               "Material flights must evaluate their quadratic path per frame")

        let newRound = try section(in: gameState,
                                   from: "func newRound() -> Bool",
                                   through: "func restartMatch()")
        expect(precedes("guard stage == .finished", "botTask?.cancel()", in: newRound),
               "An invalid New Round request must not cancel live game tasks")

        FileHandle.standardOutput.write(
            Data("Phase2PresentationContractTests: PASS\n".utf8)
        )
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

    private static func precedes(_ first: String,
                                 _ second: String,
                                 in source: String) -> Bool {
        guard let firstRange = source.range(of: first),
              let secondRange = source.range(of: second) else { return false }
        return firstRange.lowerBound < secondRange.lowerBound
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(
            Data("Phase2PresentationContractTests: \(message)\n".utf8)
        )
        Foundation.exit(EXIT_FAILURE)
    }
}
