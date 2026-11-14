/// Französische Farben des 32er-Blatts (Spec Abschnitt 3); das Artwork liegt in der App, die Logik bleibt symbolneutral.
public enum Suit: String, CaseIterable, Codable, Hashable, Sendable {
    case hearts, diamonds, spades, clubs
}

/// Ränge des 32er-Blatts, aufsteigend 7 bis Ass (Rangfolge A-K-D-B-10-9-8-7, Spec Abschnitt 3).
public enum Rank: Int, CaseIterable, Codable, Hashable, Sendable, Comparable {
    case seven = 7, eight = 8, nine = 9, ten = 10
    case jack = 11, queen = 12, king = 13, ace = 14

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct Card: Codable, Hashable, Sendable {
    public let suit: Suit
    public let rank: Rank

    public init(suit: Suit, rank: Rank) {
        self.suit = suit
        self.rank = rank
    }
}

public enum Deck {
    /// Das kanonische 32er-Blatt (Spec Abschnitt 3).
    public static let standard32: [Card] = Suit.allCases.flatMap { suit in
        Rank.allCases.map { Card(suit: suit, rank: $0) }
    }
}
