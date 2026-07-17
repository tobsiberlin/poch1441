import Foundation

@main
struct UIInformationBoundaryContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static func main() throws {
        let state = try source("App/GameState.swift")
        let views = try [
            source("App/ContentView.swift"),
            source("App/Phase2View.swift"),
            source("App/Phase3View.swift")
        ].joined(separator: "\n")

        expect(!state.contains("func displayedHand(of:"),
               "GameState must not expose complete hands for arbitrary seats")
        expect(!state.contains("var playout: PlayoutPhase?"),
               "GameState must not expose the complete playout engine state")
        expect(state.contains("var displayedHumanHand: [Card]"),
               "The view still needs an explicit human-hand API")
        expect(state.contains("func displayedCardCount(of seat: Int) -> Int"),
               "Opponent views need counts instead of card arrays")
        expect(state.contains("var revealedPlayEvents: [PlayoutPhase.Play]"),
               "Phase 3 needs a public-event stream limited by presentation state")
        expect(!contains(pattern: #"game\.playout(?![A-Za-z])"#, in: views),
               "Views must not read the complete playout engine state")
        expect(!views.contains("displayedHand(of:"),
               "Views must not request arbitrary seat hands")

        FileHandle.standardOutput.write(Data("UIInformationBoundaryContractTests: PASS\n".utf8))
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
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
                Data("UIInformationBoundaryContractTests: \(message)\n".utf8)
            )
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
