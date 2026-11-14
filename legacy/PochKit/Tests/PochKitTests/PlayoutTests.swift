import XCTest
@testable import PochKit

final class PlayoutTests: XCTestCase {
    private let upcard = Card(suit: .diamonds, rank: .seven) // Trumpf für die Runde, irrelevant fürs Ketten-Prinzip

    /// Spec Abschnitt 3: Wer die nächsthöhere Karte derselben Farbe hält, muss sie legen -
    /// die Kette läuft automatisch über die Hände.
    func testChainRunsForcedAcrossHands() throws {
        var p = PlayoutPhase(
            hands: [
                [Card(suit: .spades, rank: .seven), Card(suit: .hearts, rank: .king)],
                [Card(suit: .spades, rank: .eight), Card(suit: .hearts, rank: .queen)],
                [Card(suit: .spades, rank: .nine), Card(suit: .hearts, rank: .jack)],
            ],
            upcard: upcard,
            firstLeader: 0
        )
        try p.lead(Card(suit: .spades, rank: .seven))
        XCTAssertEqual(p.plays.map(\.player), [0, 1, 2])
        XCTAssertEqual(p.plays.map(\.isLead), [true, false, false])
        XCTAssertEqual(p.leader, 2, "Wer die letzte Karte der Kette legte, eröffnet neu")
        XCTAssertNil(p.winner)
    }

    /// Spec Abschnitt 3: Die Kette reißt an der offen liegenden Trumpfkarte.
    func testChainStopsAtUpcard() throws {
        let upcardTen = Card(suit: .spades, rank: .ten)
        var p = PlayoutPhase(
            hands: [
                [Card(suit: .spades, rank: .eight), Card(suit: .hearts, rank: .king)],
                [Card(suit: .spades, rank: .nine), Card(suit: .hearts, rank: .queen)],
                [Card(suit: .spades, rank: .jack), Card(suit: .hearts, rank: .jack)],
            ],
            upcard: upcardTen,
            firstLeader: 0
        )
        try p.lead(Card(suit: .spades, rank: .eight))
        XCTAssertEqual(p.plays.count, 2, "Die 10 liegt offen - nach der 9 reißt die Kette")
        XCTAssertEqual(p.leader, 1)
    }

    /// Spec Abschnitt 3: Am Ass reißt die Kette; der Leger des Asses eröffnet neu.
    func testChainStopsAtAce() throws {
        var p = PlayoutPhase(
            hands: [
                [Card(suit: .hearts, rank: .king), Card(suit: .spades, rank: .seven)],
                [Card(suit: .hearts, rank: .ace), Card(suit: .spades, rank: .eight)],
            ],
            upcard: upcard,
            firstLeader: 0
        )
        try p.lead(Card(suit: .hearts, rank: .king))
        XCTAssertEqual(p.plays.count, 2)
        XCTAssertEqual(p.leader, 1)
    }

    /// Spec Abschnitt 3 (Präzisierung Block 3): Die Kette reißt auch an einer bereits
    /// gespielten Karte - der zuvor fehlende dritte Stopp-Fall.
    func testChainStopsAtAlreadyPlayedCard() throws {
        var p = PlayoutPhase(
            hands: [
                [Card(suit: .spades, rank: .jack), Card(suit: .hearts, rank: .seven)],
                [Card(suit: .spades, rank: .queen), Card(suit: .spades, rank: .nine), Card(suit: .hearts, rank: .king)],
                [Card(suit: .spades, rank: .ten), Card(suit: .hearts, rank: .eight)],
            ],
            upcard: upcard,
            firstLeader: 0
        )
        try p.lead(Card(suit: .spades, rank: .jack))   // J → Q (P1), K in keiner Hand → P1 führt
        XCTAssertEqual(p.leader, 1)
        try p.lead(Card(suit: .spades, rank: .nine))   // 9 → 10 (P2), J bereits gespielt → Kette reißt
        XCTAssertEqual(p.plays.count, 4)
        XCTAssertEqual(p.leader, 2, "Nach dem Riss an der bereits gespielten Karte führt der letzte Leger")
    }

    /// Spec Abschnitt 3: Rundenende sofort bei leerer Hand - auch mitten in der Kette.
    func testWinnerImmediatelyWhenHandEmptiesMidChain() throws {
        var p = PlayoutPhase(
            hands: [
                [Card(suit: .clubs, rank: .seven), Card(suit: .hearts, rank: .nine)],
                [Card(suit: .clubs, rank: .eight)],                                    // leert sich mitten in der Kette
                [Card(suit: .clubs, rank: .nine), Card(suit: .clubs, rank: .ten)],
            ],
            upcard: upcard,
            firstLeader: 0
        )
        try p.lead(Card(suit: .clubs, rank: .seven))
        XCTAssertEqual(p.winner, 1, "P1 legt die Acht als letzte Handkarte - Runde endet sofort")
        XCTAssertEqual(p.plays.count, 2, "Die Neun von P2 wird nicht mehr gespielt")
        XCTAssertThrowsError(try p.lead(Card(suit: .hearts, rank: .nine))) { error in
            XCTAssertEqual(error as? PlayoutPhase.PlayError, .phaseOver)
        }
    }

    /// Invarianten-Fuzzer (Spec Abschnitt 14): Zufällige legale Anspiele über viele Seeds -
    /// jede Karte fällt höchstens einmal, die Phase terminiert immer mit einem Sieger,
    /// Karten bleiben erhalten (gespielt + Hände + Trumpfkarte = 32).
    func testRandomPlayoutsHoldInvariants() throws {
        for seed in UInt64(0)..<150 {
            var rng = SeededRNG(seed: seed)
            let playerCount = Int.random(in: 3...6, using: &rng)
            let deal = Deal.deal(playerCount: playerCount, seed: seed &+ 7)
            var p = PlayoutPhase(hands: deal.hands, upcard: deal.upcard, firstLeader: 0)

            var leads = 0
            while p.winner == nil {
                leads += 1
                XCTAssertLessThan(leads, 64, "Seed \(seed): Ausspielen terminiert nicht")
                let hand = p.hands[p.leader]
                let card = hand[Int.random(in: 0..<hand.count, using: &rng)]
                try p.lead(card)
            }

            let playedCards = p.plays.map(\.card)
            XCTAssertEqual(Set(playedCards).count, playedCards.count, "Seed \(seed): Karte doppelt gespielt")
            XCTAssertEqual(
                playedCards.count + p.remainingCounts.reduce(0, +) + 1, 32,
                "Seed \(seed): Karten-Erhaltung verletzt"
            )
            let winnerIndex = try XCTUnwrap(p.winner)
            XCTAssertEqual(p.hands[winnerIndex].count, 0, "Seed \(seed): Sieger hat noch Karten")
        }
    }
}
