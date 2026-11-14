import XCTest
@testable import PochKit

final class CombosTests: XCTestCase {
    private let trump = Suit.hearts

    /// Spec Abschnitt 3: Vierling > Drilling > Paar.
    func testQuadBeatsTripleBeatsPair() {
        let quad = Combo(kind: .quad, rank: .seven, containsTrump: true)
        let triple = Combo(kind: .triple, rank: .ace, containsTrump: true)
        let pair = Combo(kind: .pair, rank: .ace, containsTrump: true)
        XCTAssertTrue(quad.beats(triple))
        XCTAssertTrue(triple.beats(pair))
        XCTAssertFalse(pair.beats(triple))
    }

    /// Spec Abschnitt 3: Innerhalb gleicher Klasse zählt der höhere Rang.
    func testHigherRankWinsWithinSameKind() {
        let kings = Combo(kind: .pair, rank: .king, containsTrump: false)
        let tens = Combo(kind: .pair, rank: .ten, containsTrump: true)
        XCTAssertTrue(kings.beats(tens))
    }

    /// Spec Abschnitt 3: Bei gleichen Paaren gewinnt das Paar mit Trumpfkarte.
    func testTrumpBreaksTieBetweenEqualPairs() {
        let withTrump = Combo(kind: .pair, rank: .queen, containsTrump: true)
        let without = Combo(kind: .pair, rank: .queen, containsTrump: false)
        XCTAssertTrue(withTrump.beats(without))
        XCTAssertFalse(without.beats(withTrump))
    }

    /// Spec Abschnitt 3: Zwei Paare zählen nur als das höhere Paar.
    func testTwoPairsCountAsHigherPairOnly() {
        let hand = [
            Card(suit: .hearts, rank: .king), Card(suit: .spades, rank: .king),
            Card(suit: .clubs, rank: .nine), Card(suit: .diamonds, rank: .nine),
        ]
        let best = ComboEvaluator.best(in: hand, trump: trump)
        XCTAssertEqual(best, Combo(kind: .pair, rank: .king, containsTrump: true))
    }

    /// Spec Abschnitt 3: Drilling + Paar zählt nur als Drilling.
    func testTripleAndPairCountAsTripleOnly() {
        let hand = [
            Card(suit: .hearts, rank: .eight), Card(suit: .spades, rank: .eight), Card(suit: .clubs, rank: .eight),
            Card(suit: .diamonds, rank: .ace), Card(suit: .spades, rank: .ace),
        ]
        let best = ComboEvaluator.best(in: hand, trump: trump)
        XCTAssertEqual(best?.kind, .triple)
        XCTAssertEqual(best?.rank, .eight)
    }

    /// Spec Abschnitt 3: Ohne Paar kein Kunststück (kein Bietrecht).
    func testHandWithoutPairHasNoCombo() {
        let hand = [
            Card(suit: .hearts, rank: .ace), Card(suit: .spades, rank: .king),
            Card(suit: .clubs, rank: .queen), Card(suit: .diamonds, rank: .jack),
        ]
        XCTAssertNil(ComboEvaluator.best(in: hand, trump: trump))
    }
}
