/// Phase 1 - Melden (Spec Abschnitt 3):
/// Trumpf-Honors kassieren ihre Mulde, Trumpf-König+Dame die Mariage, Trumpf-7-8-9 die Sequenz.
/// Die Mulde der offen liegenden Trumpfkarte wird nicht gewonnen (sie bleibt stehen).
public enum Melding {
    /// Alle Mulden, die eine Hand bei gegebener Trumpflage kassiert.
    public static func pools(for hand: [Card], upcard: Card) -> Set<Pool> {
        let trump = upcard.suit
        var won = Set<Pool>()

        for card in hand where card.suit == trump {
            if let pool = Pool.honorPool(for: card.rank) {
                won.insert(pool)
            }
        }

        let holdsTrump: (Rank) -> Bool = { hand.contains(Card(suit: trump, rank: $0)) }
        if holdsTrump(.king) && holdsTrump(.queen) {
            won.insert(.mariage)
        }
        if holdsTrump(.seven) && holdsTrump(.eight) && holdsTrump(.nine) {
            won.insert(.sequence)
        }

        // Die offene Trumpfkarte gewinnt nie eine Mulde - da sie in keiner Hand liegt, kann ihre
        // Honor-Mulde ohnehin niemand melden; die Regel ist damit konstruktiv erfüllt.
        return won
    }

    /// Melde-Reihenfolge: reihum ab links vom Geber, jede Meldung einzeln (Spec Abschnitt 3, Runde 5).
    /// Liefert pro Spieler (in Sitzreihenfolge) die gewonnenen Mulden.
    public static func meldOrder(deal: Deal) -> [(player: Int, pools: Set<Pool>)] {
        deal.hands.enumerated().map { (player: $0.offset, pools: pools(for: $0.element, upcard: deal.upcard)) }
    }
}
