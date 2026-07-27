import Foundation

@main
struct TableFoleyContractTests {
    private static let root = URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath
    )

    static func main() throws {
        let audio = try source("App/TableFoleyAudio.swift")
        let deal = try source("App/DealOverlay.swift")
        let content = try source("App/ContentView.swift")
        let phase2 = try source("App/Phase2View.swift")
        let phase3 = try source("App/Phase3View.swift")
        let builder = try source("tools/build_table_foley_audio.py")

        for variant in 1...3 {
            let suffix = String(format: "%02d", variant)
            expect(audio.contains("card-deal-\(suffix)"),
                   "Runtime must include card-deal-\(suffix)")
            expect(builder.contains("CardSource(\(variant),"),
                   "Builder must pin source \(variant)")
        }
        expect(audio.contains("R1ContactVariantResolver.resolve"),
               "Card contacts must vary deterministically")
        expect(!audio.contains("enableRate") && !audio.contains("player.rate"),
               "Real card Foley must not be disguised with pitch variation")
        expect(audio.contains("TableFoleySpatialModel.pan(seat: seat,")
               && audio.contains("playerCount: playerCount"),
               "Card contacts must stay spatially attached to 3-6 player seats")
        expect(audio.contains("let normalized = (index - center) / center")
               && audio.contains("normalized * 0.42"),
               "Seat panning must follow the same normalized table geometry")
        expect(audio.contains("PochAudioSession.prepareAmbientMixing()"),
               "Table Foley must establish the shared ambient audio policy")
        expect(deal.contains("playContactFoley()")
               && deal.contains("transaction.registerContact"),
               "Foley must trigger on the admitted physical contact")
        expect(deal.contains("guard reduceMotion, soundEnabled, current > previous"),
               "Reduced Motion must retain one causal contact without a flight")
        expect(audio.contains("func playCardReveal")
               && content.contains("playCardReveal("),
               "The physical trump flip must emit one causal card contact")
        expect(audio.contains("func playChipContact")
               && phase2.contains("commitBetImpact")
               && phase2.contains("commitPayoutImpact")
               && phase2.contains("playChipContact("),
               "Phase-2 bet and payout impacts must route ceramic Foley")
        expect(audio.contains("func playCardPlay")
               && phase3.contains("playCardPlay("),
               "Accepted Phase-3 card landings must route table Foley")

        FileHandle.standardOutput.write(Data("TableFoleyContractTests: PASS\n".utf8))
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("TableFoleyContractTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
