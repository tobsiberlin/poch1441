import XCTest
@testable import PochKit

final class MeldingTests: XCTestCase {
    private let upcard = Card(suit: .hearts, rank: .seven) // Trumpf: Herz

    /// Spec Abschnitt 3: Trumpf-Honors kassieren ihre Mulde, Fremdfarben nicht.
    func testTrumpHonorsWinTheirPools() {
        let hand = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .ten),
            Card(suit: .spades, rank: .king), // kein Trumpf → keine König-Mulde
        ]
        XCTAssertEqual(Melding.pools(for: hand, upcard: upcard), [.ace, .ten])
    }

    /// Spec Abschnitt 3: Trumpf-König + Trumpf-Dame gewinnen zusätzlich die Mariage.
    func testMariageRequiresTrumpKingAndQueen() {
        let mariage = [Card(suit: .hearts, rank: .king), Card(suit: .hearts, rank: .queen)]
        XCTAssertEqual(Melding.pools(for: mariage, upcard: upcard), [.king, .queen, .mariage])

        let mixed = [Card(suit: .hearts, rank: .king), Card(suit: .spades, rank: .queen)]
        XCTAssertEqual(Melding.pools(for: mixed, upcard: upcard), [.king])
    }

    /// Spec Abschnitt 3: Sequenz = Trumpf-7-8-9 in einer Hand (Pagat-Pinning).
    func testSequenceRequiresTrumpSevenEightNine() {
        let sequenceUpcard = Card(suit: .hearts, rank: .ace)
        let hand = [
            Card(suit: .hearts, rank: .seven),
            Card(suit: .hearts, rank: .eight),
            Card(suit: .hearts, rank: .nine),
        ]
        XCTAssertEqual(Melding.pools(for: hand, upcard: sequenceUpcard), [.sequence])
    }

    /// Spec Abschnitt 3 (Review-Runde 8, explizit): Liegt Trumpf-König oder -Dame offen,
    /// ist die Mariage konstruktiv unmöglich - die Mulde bleibt stehen.
    func testMariageImpossibleWhenTrumpKingIsUpcard() {
        let kingUpcard = Card(suit: .hearts, rank: .king)
        let hand = [Card(suit: .hearts, rank: .queen), Card(suit: .hearts, rank: .ace)]
        XCTAssertEqual(Melding.pools(for: hand, upcard: kingUpcard), [.queen, .ace],
                       "Ohne haltbaren Trumpf-König kann niemand die Mariage melden")
    }

    /// Spec Abschnitt 3 (Review-Runde 8, explizit): Liegt Trumpf-7/8/9 offen, ist die
    /// Sequenz konstruktiv unmöglich - die Mulde bleibt stehen.
    func testSequenceImpossibleWhenTrumpEightIsUpcard() {
        let eightUpcard = Card(suit: .hearts, rank: .eight)
        let hand = [Card(suit: .hearts, rank: .seven), Card(suit: .hearts, rank: .nine)]
        XCTAssertEqual(Melding.pools(for: hand, upcard: eightUpcard), [],
                       "Ohne haltbare Trumpf-8 kann niemand die Sequenz melden")
    }

    /// Invariante (Spec Abschnitt 14): Die offene Trumpfkarte gewinnt nie eine Mulde -
    /// über alle Hände eines Deals wird die Honor-Mulde der Trumpfkarte nie ausgezahlt.
    func testUpcardHonorPoolIsNeverWonAcrossManySeededDeals() {
        for seed in UInt64(0)..<200 {
            let deal = Deal.deal(playerCount: 4, seed: seed)
            guard let excluded = Pool.honorPool(for: deal.upcard.rank) else { continue }
            for hand in deal.hands {
                XCTAssertFalse(
                    Melding.pools(for: hand, upcard: deal.upcard).contains(excluded),
                    "Seed \(seed): Mulde der offenen Trumpfkarte wurde gewonnen"
                )
            }
        }
    }
}
