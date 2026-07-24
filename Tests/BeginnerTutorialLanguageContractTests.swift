import Foundation

@main
struct BeginnerTutorialLanguageContractTests {
    private static let root = URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath
    )

    static func main() throws {
        let phase2 = try source("App/Phase2View.swift")
        let phase3 = try source("App/Phase3View.swift")
        let content = try source("App/ContentView.swift")
        let localizations = try source("App/Localizable.xcstrings")
        let pochRing = try source("App/PochRing.swift")

        let prelude = try section(
            in: phase2,
            from: "private func scheduleGuidedPrelude()",
            through: "private var pochenHint"
        )
        expect(prelude.contains("guidedPreludeStep = isGuidedRound ? 0 : 2"),
               "The guided Poch lesson must start with the qualifying pair")
        expect(prelude.contains("if guidedPreludeStep == 1"),
               "The beginner must explicitly choose a safe stake")
        expect(prelude.contains("bid = Double(range.lowerBound)"),
               "The guided stake must resolve to the legal minimum")
        expect(prelude.contains("phase2ReduceMotion\n                      ? nil"),
               "Reduced Motion must not animate tutorial focus changes")
        expect(!prelude.contains("Task.sleep"),
               "A tutorial step must not be declared complete by a timer")
        expect(phase2.contains("guard !isGuidedRound,"),
               "The first guided round must not expose technical opponent analytics")

        expect(phase2.contains("Die anderen können mitgehen, erhöhen oder passen"),
               "Pochen must teach the eligible responses")
        expect(phase2.contains("guidedResultCopy"),
               "The guided Poch lesson must teach the public result")
        expect(phase2.contains("pochShowdownSummary"),
               "The guided Poch lesson must explain an actual showdown")
        expect(phase2.contains("Anzahl vor Rang"),
               "The showdown must teach quantity before rank")
        expect(phase2.contains("Der Poch-Topf bleibt liegen und wächst"),
               "All-pass carry-over must be framed as future value")
        expect(!phase2.contains("return \"Einsatz ansehen\""),
               "The first bidding CTA must describe the next decision, not an info view")
        expect(!phase2.contains("Danach startet der Kartenstrom"),
               "Beginner copy must not call the playout a Kartenstrom")

        expect(!phase3.contains("KETTE LÄUFT"),
               "Phase 3 must not expose the unexplained Kette läuft status")
        expect(!phase3.contains("RISS \\(marker)"),
               "Phase 3 must name the visible end instead of a Riss")
        expect(phase3.contains("TIPPE DEINE STARTKARTE"),
               "Phase 3 must identify the first concrete action")
        expect(phase3.contains("nächsthöhere Karte derselben Farbe"),
               "Phase 3 must teach ascending same-suit rows")
        expect(phase3.contains("REIHE ENDET BEI \\(marker)"),
               "Phase 3 must make the end of a card row visible")
        expect(phase3.contains("1 Chip pro Restkarte - solange"),
               "The settlement must explain where remaining-card chips come from")
        expect(phase3.contains("phase3ReduceMotion ? nil"),
               "Phase 3 motion must retain a Reduced Motion path")

        let beginnerSurface = content + phase2 + phase3
        for forbidden in [
            "Extra-Topf", "Paar-Topf", "Markierte Karte spielen", "Jetzt zählt Tempo",
            "DU STARTET", "MULDE BLEIBT", "KETTE LÄUFT"
        ] {
            expect(!beginnerSurface.contains(forbidden),
                   "Beginner surface must not expose legacy wording: \(forbidden)")
        }
        expect(content.contains("sieben Bonus-Töpfen, Poch-Topf und Mitte"),
               "The first screen must establish the three prize areas")
        expect(content.contains("Er bleibt in deiner Hand"),
               "Melding must not imply that the card leaves the hand")
        expect(content.contains("Mariage"),
               "King and Queen must not collide with the equal-rank pair term")
        expect(localizations.contains("Zieh deinen ersten Chip in die Mitte"),
               "The first action must name the shared payment and its destination")
        expect(!localizations.contains("Ziehe den Stein in die Mitte"),
               "Beginner copy must use Chip consistently")
        expect(localizations.contains("tutorial.bidding.combo.body"),
               "The bidding prelude must describe the actual qualifying combination")
        expect(localizations.contains("fordert Revanche"),
               "The completion must end on a human rematch hook instead of a dry rule recap")
        expect(!localizations.contains("tutorial.bidding.pair.body"),
               "A scripted triple must not be mislabeled as a pair")
        expect(localizations.contains("\"phase3.metric.total\""),
               "Settlement labels must be localized")
        expect(localizations.contains("\"GESAMT\""),
               "German settlement copy must use Gesamt, not Total")

        expect(pochRing.contains("case .sequence: return \"FOLGE\""),
               "The board must use a readable German label instead of SEQ")

        FileHandle.standardOutput.write(
            Data("BeginnerTutorialLanguageContractTests: PASS\n".utf8)
        )
    }

    private static func source(_ path: String) throws -> String {
        try String(
            contentsOf: root.appendingPathComponent(path),
            encoding: .utf8
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

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(
            Data("BeginnerTutorialLanguageContractTests: \(message)\n".utf8)
        )
        Foundation.exit(EXIT_FAILURE)
    }
}
