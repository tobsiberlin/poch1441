import XCTest
@testable import PochKit

/// Bluff-Integrität (eiserne Regel, Spec §6b) + Determinismus-Golden-Master.
final class TellGeneratorTests: XCTestCase {

    /// Der Tell hängt ausschließlich von Profil + öffentlichem Kontext + Seed ab. Die Funktion
    /// nimmt strukturell keine Hand entgegen (Compile-Zeit-Garantie); dieser Test sichert
    /// zusätzlich, dass identische Eingaben IMMER denselben Tell erzeugen - ein Regressionswächter
    /// gegen versehentliche Nichtdeterminismus-/Leak-Vektoren, wenn die UI später darauf aufbaut.
    func testTellDependsOnlyOnPublicContextProfileAndSeed() {
        let context = TellGenerator.PublicContext(currentBet: 6, raiseHappened: true, potChips: 20)
        for seed in UInt64(0)..<1000 {
            var a = SeededRNG(seed: seed)
            var b = SeededRNG(seed: seed)
            XCTAssertEqual(TellGenerator.tell(profile: .neutral, context: context, rng: &a),
                           TellGenerator.tell(profile: .neutral, context: context, rng: &b))
        }
    }

    /// Der Tell reagiert auf den ÖFFENTLICHEN Spielstand (nur eben nie auf die Hand) - die
    /// Gesten-Verteilung ist nicht degeneriert.
    func testTellReactsToPublicState() {
        var seen = Set<Tell.Gesture>()
        for seed in UInt64(0)..<300 {
            var rng = SeededRNG(seed: seed)
            let ctx = TellGenerator.PublicContext(currentBet: seed % 2 == 0 ? 0 : 8,
                                                  raiseHappened: seed % 2 == 1, potChips: Int(seed))
            seen.insert(TellGenerator.tell(profile: .neutral, context: ctx, rng: &rng).gesture)
        }
        XCTAssertGreaterThan(seen.count, 1)
    }

    /// Golden Master: pinnt die exakte RNG-Sequenz + das Deal-Ergebnis für einen festen Seed.
    /// Ändert ein Refactor den Determinismus (RNG-Primitive, Shuffle, Iterationsreihenfolge),
    /// schlägt dieser Test bewusst fehl - Determinismus ist ein Vertrag über Plattformen hinweg.
    func testDeterminismGoldenMaster() {
        var rng = SeededRNG(seed: 1441)
        let seq = (0..<4).map { _ in rng.next() }
        XCTAssertEqual(seq, [14545006869196403348, 18363662926645360346,
                             16732346251925884738, 12928019391960908766])
        let deal = Deal.deal(playerCount: 4, seed: 1441)
        XCTAssertEqual(deal.upcard, Card(suit: .spades, rank: .jack))
        XCTAssertEqual(deal.hands[0].first, Card(suit: .hearts, rank: .ten))
        XCTAssertEqual(deal.hands[0].count, 8)
    }
}
