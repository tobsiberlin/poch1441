/// Ergebnis des Gebens: alle Karten einzeln im Uhrzeigersinn verteilt, bis genau eine übrig
/// bleibt - diese liegt offen und bestimmt Trumpf. Ungleiche Handgrößen sind regelkonform
/// (Spec Abschnitt 3).
public struct Deal: Equatable, Sendable {
    /// Hände in Sitzreihenfolge, Index 0 = links vom Geber (erhält die erste Karte).
    public let hands: [[Card]]
    public let upcard: Card

    public var trump: Suit { upcard.suit }

    public static func deal(playerCount: Int, seed: UInt64) -> Deal {
        precondition((3...6).contains(playerCount), "Poch trägt 3-6 Spieler (Spec Abschnitt 3)")
        var rng = SeededRNG(seed: seed)
        let shuffled = rng.shuffled(Deck.standard32)

        var hands = Array(repeating: [Card](), count: playerCount)
        for (index, card) in shuffled.dropLast().enumerated() {
            hands[index % playerCount].append(card)
        }
        return Deal(hands: hands, upcard: shuffled[shuffled.count - 1])
    }
}
