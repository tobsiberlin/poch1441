import XCTest
@testable import PochKit

final class DealingTests: XCTestCase {
    /// Spec Abschnitt 3: Alle 32 Karten bleiben erhalten - Hände + offene Trumpfkarte, keine Duplikate.
    func testDealConservesAllCards() {
        for playerCount in 3...6 {
            let deal = Deal.deal(playerCount: playerCount, seed: 1441)
            let all = deal.hands.flatMap { $0 } + [deal.upcard]
            XCTAssertEqual(all.count, 32)
            XCTAssertEqual(Set(all).count, 32)
        }
    }

    /// Spec Abschnitt 3 (Review-Runde 9): Exakte Handgrößen pro Tischgröße - der Geber
    /// (letzter Index) bekommt NIE mehr Karten; bei ungleicher Teilung haben die Spieler
    /// links vom Geber eine mehr. „Geber eine weniger" gilt nur zufällig beim Vierertisch.
    func testExactHandSizesPerTableSize() {
        let expected: [Int: [Int]] = [
            3: [11, 10, 10],
            4: [8, 8, 8, 7],
            5: [7, 6, 6, 6, 6],
            6: [6, 5, 5, 5, 5, 5],
        ]
        for (playerCount, sizes) in expected {
            let deal = Deal.deal(playerCount: playerCount, seed: 1441)
            XCTAssertEqual(deal.hands.map(\.count), sizes, "\(playerCount) Spieler")
        }
    }

    /// Spec Abschnitt 3: Handgrößen dürfen ungleich sein, differieren aber höchstens um 1
    /// (reihum einzeln gegeben); Spieler links vom Geber bekommt die erste Karte.
    func testHandSizesDifferByAtMostOne() {
        for playerCount in 3...6 {
            let deal = Deal.deal(playerCount: playerCount, seed: 7)
            let sizes = deal.hands.map(\.count)
            XCTAssertEqual(sizes.reduce(0, +), 31)
            XCTAssertLessThanOrEqual(sizes.max()! - sizes.min()!, 1)
            XCTAssertEqual(sizes.max(), sizes[0], "Links vom Geber darf nie weniger Karten haben als spätere Sitze")
        }
    }

    /// Spec Abschnitt 5: Gleicher Seed → identischer Deal (Reproduzierbarkeit).
    func testDealIsDeterministicPerSeed() {
        XCTAssertEqual(Deal.deal(playerCount: 4, seed: 42), Deal.deal(playerCount: 4, seed: 42))
        XCTAssertNotEqual(Deal.deal(playerCount: 4, seed: 42), Deal.deal(playerCount: 4, seed: 43))
    }

    /// Board-Invariante (Spec Abschnitt 14): Chip-Summe bleibt über Ante + Abholung erhalten.
    func testBoardChipConservation() {
        var board = Board()
        board.ante(playerCount: 4)
        XCTAssertEqual(board.total, Pool.allCases.count * 4)

        let collected = board.collect(.ace)
        XCTAssertEqual(collected, 4)
        XCTAssertEqual(board[.ace], 0)
        XCTAssertEqual(board.total + collected, Pool.allCases.count * 4)

        board.add(5, to: .poch)
        XCTAssertEqual(board[.poch], 9)
    }
}
