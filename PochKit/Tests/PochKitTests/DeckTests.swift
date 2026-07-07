import XCTest
@testable import PochKit

final class DeckTests: XCTestCase {
    /// Spec Abschnitt 3: Das Blatt hat exakt 32 eindeutige Karten (8 Ränge x 4 Farben).
    func testStandard32HasExactly32UniqueCards() {
        XCTAssertEqual(Deck.standard32.count, 32)
        XCTAssertEqual(Set(Deck.standard32).count, 32)
    }

    /// Spec Abschnitt 5: Gleicher Seed liefert dieselbe Mischreihenfolge (Reproduzierbarkeit von Partien).
    func testSeededShuffleIsDeterministic() {
        var rng1 = SeededRNG(seed: 1441)
        var rng2 = SeededRNG(seed: 1441)
        XCTAssertEqual(Deck.standard32.shuffled(using: &rng1), Deck.standard32.shuffled(using: &rng2))
    }

    /// Spec Abschnitt 3: Rangfolge A > K > D > B > 10 > 9 > 8 > 7.
    func testRankOrdering() {
        XCTAssertTrue(Rank.ace > .king && Rank.king > .queen && Rank.queen > .jack)
        XCTAssertTrue(Rank.jack > .ten && Rank.ten > .nine && Rank.nine > .eight && Rank.eight > .seven)
    }
}
