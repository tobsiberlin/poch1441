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

        expect(phase2.contains("mitgehen, erhöhen oder passen"),
               "Pochen must teach the eligible responses")
        expect(phase2.contains("guidedResultCopy"),
               "The guided Poch lesson must teach the public result")
        expect(phase2.contains("pochShowdownSummary"),
               "The guided Poch lesson must explain an actual showdown")
        expect(phase2.contains("Vierling schlägt Drilling")
               && !phase2.contains("Anzahl vor Rang"),
               "The showdown must explain the comparison in a natural sentence")
        expect(phase2.contains("Die Chips bleiben liegen. In der nächsten Runde kommt der neue Einsatz dazu"),
               "All-pass carry-over must be framed as future value")
        expect(!phase2.contains("return \"Einsatz ansehen\""),
               "The first bidding CTA must describe the next decision, not an info view")
        expect(!phase2.contains("Danach startet der Kartenstrom"),
               "Beginner copy must not call the playout a Kartenstrom")

        expect(!phase3.contains("KETTE LÄUFT"),
               "Phase 3 must not expose the unexplained Kette läuft status")
        expect(!phase3.contains("RISS \\(marker)"),
               "Phase 3 must name the visible end instead of a Riss")
        expect(phase3.contains("KARTENFARBE: HERZ")
               && phase3.contains("Starte mit dem Herz-Buben"),
               "Phase 3 must identify the first concrete action")
        expect(phase3.contains("Kartenfarbe")
               && phase3.contains("Herz-Buben")
               && phase3.contains("Herz-Dame"),
               "Phase 3 must define suit and teach the first concrete heart row")
        expect(phase3.contains("REIHE ENDET BEI \\(marker)"),
               "Phase 3 must make the end of a card row visible")
        expect(phase3.contains("1 Chip für jede Restkarte")
               || phase3.contains("1 Chip pro Restkarte")
               || phase3.contains("für jede übrige Handkarte 1 Chip"),
               "The settlement must explain where remaining-card chips come from")
        expect(phase3.contains("phase3ReduceMotion ? nil"),
               "Phase 3 motion must retain a Reduced Motion path")

        let beginnerSurface = content + phase2 + phase3
        for forbidden in [
            "Extra-Topf", "Paar-Topf", "Markierte Karte spielen", "Jetzt zählt Tempo",
            "DU STARTET", "MULDE BLEIBT", "KETTE LÄUFT", "Kartenstrom",
            "Dein Trumpf-König trifft", "Deine Karten öffnen den Poch"
        ] {
            expect(!beginnerSurface.contains(forbidden),
                   "Beginner surface must not expose legacy wording: \(forbidden)")
        }
        expect(content.contains("guidedBoardTourStep"),
               "The first round must stop for a visible board tour")
        expect(content.contains("firstRun.cinematic.bonus.title")
               && content.contains("firstRun.cinematic.bidding.title")
               && content.contains("firstRun.cinematic.playout.title"),
               "The board tour must introduce trump wins, the Poch and playout")
        expect(content.contains("firstRun.boardTour.next"),
               "Every board-tour stop must wait for an explicit confirmation")
        expect(content.contains("guidedBoardTourCameraReady")
               && content.contains("guidedBoardTourCameraOffset")
               && content.contains("rotation3DEffect"),
               "The tour must establish, dolly and add restrained parallax instead of snapping between diagrams")
        expect(content.contains("guidedTrumpTableCard")
               && content.contains("CardBack(scale: cardScale)")
               && content.contains("CardFace(card: game.upcard"),
               "Trump must be revealed on a physical table card, not only in a badge")
        expect(content.contains("guidedAnteContactTick += 1")
               && content.contains("surface: guidedAnteContactSurface"),
               "Every visible funding-chip impact must emit its own contact feedback")
        expect(content.contains("game.completeGuidedTableFunding()"),
               "The final visible chip contact must not add a bundled duplicate acknowledgement")
        expect(localizations.contains("Trumpffarbe Karo")
               && localizations.contains("die Karte bleibt in deiner Hand"),
               "Melding must not imply that the card leaves the hand")
        expect(localizations.contains("König und Dame - das ist die Hochzeit")
               && localizations.contains("gemeinsam gewinnen beide zusätzlich die Hochzeit"),
               "King and Queen must use an explained everyday name")
        expect(localizations.contains("Wer zuerst keine Karten mehr vor sich hat"),
               "The first action must explain why the center matters")
        expect(!localizations.contains("Ziehe den Stein in die Mitte"),
               "Beginner copy must use Chip consistently")
        expect(localizations.contains("tutorial.bidding.combo.body"),
               "The bidding prelude must describe the actual qualifying combination")
        expect(localizations.contains("Poch-Pott")
               && localizations.contains("Bonusfelder")
               && localizations.contains("Hand leerspielen"),
               "The tutorial must use the canonical beginner vocabulary")
        expect(content.contains("ruleTile(\"7-8-9\", \"Folge\"")
               && !content.contains("ruleTile(\"7-10\", \"Sequenz\""),
               "The rules overview must show the actual 7-8-9 Folge")
        expect(content.contains("Farbe der offenen Tischkarte")
               && !content.contains("Trumpf\", \"entscheidet Gleichstand"),
               "The glossary must explain trump before mentioning edge-case tie breaks")
        expect(content.contains("tableReadRow(\"Bonusfelder\"")
               && content.contains("tableReadRow(\"Poch-Pott\""),
               "Help must preserve the same field names as the guided round")
        expect(!localizations.contains("tutorial.bidding.pair.body"),
               "A scripted triple must not be mislabeled as a pair")
        expect(localizations.contains("\"phase3.metric.total\""),
               "Settlement labels must be localized")
        expect(localizations.contains("\"GESAMT\""),
               "German settlement copy must use Gesamt, not Total")
        expect(localizations.contains("\"value\" : \"Trumpf zeigen\""),
               "The first phase must use its canonical visible name")
        expect(localizations.contains("\"value\" : \"Pochen\""),
               "The second phase must teach the game's canonical term")
        expect(localizations.contains("\"value\" : \"Hand leerspielen\""),
               "The third phase must use its canonical visible name")
        expect(localizations.contains("\"value\" : \"MITTE\""),
               "The central end prize must use the established name Mitte")
        for legacyGermanValue in [
            "\"value\" : \"Bonus-Töpfe ansehen\"",
            "\"value\" : \"Werte sammeln. Die Mitte bleibt für den Schluss.\"",
            "\"value\" : \"Dein Trumpf-König trifft\""
        ] {
            expect(!localizations.contains(legacyGermanValue),
                   "German beginner copy must not retain: \(legacyGermanValue)")
        }
        expect(localizations.contains("\"value\" : \"Gewinn einsammeln\""),
               "The meld payout CTA must name the visible consequence")
        for legacyGermanTerm in ["Bonus-Töpfe", "Poch-Topf", "Weiter zum Ausspielen", "Finale", "Sequenz"] {
            expect(!localizations.contains("\"value\" : \"(legacyGermanTerm)"),
                   "German beginner copy must not lead with unexplained terminology: \(legacyGermanTerm)")
        }

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
