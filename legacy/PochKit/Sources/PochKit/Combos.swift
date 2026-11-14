/// Kunststück-Bewertung für die Poch-Phase (Spec Abschnitt 3, Phase 2):
/// Vierling > Drilling > Paar; innerhalb gleicher Klasse zählt der höhere Rang;
/// bei gleichen Paaren gewinnt das Paar mit Trumpfkarte.
public struct Combo: Equatable, Sendable {
    public enum Kind: Int, Comparable, Sendable {
        case pair = 1, triple = 2, quad = 3

        public static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public let kind: Kind
    public let rank: Rank
    public let containsTrump: Bool

    /// Strikte "schlägt"-Relation für den Showdown.
    /// Gleichstand zweier Paare ohne Trumpf ist konstruktiv unmöglich: Zwei Paare desselben
    /// Rangs bedeuten eine 2+2-Aufteilung aller vier Karten des Rangs - die Trumpfkarte des
    /// Rangs liegt dann zwingend in einem der beiden Paare (die offene Trumpfkarte hätte die
    /// 2+2-Aufteilung verhindert).
    public func beats(_ other: Combo) -> Bool {
        if kind != other.kind { return kind > other.kind }
        if rank != other.rank { return rank > other.rank }
        return containsTrump && !other.containsTrump
    }
}

public enum ComboEvaluator {
    /// Beste Kombination einer Hand oder nil, wenn kein Paar vorliegt.
    /// Zwei Paare zählen nur als das höhere Paar; Drilling + Paar zählt nur als Drilling (Spec Abschnitt 3).
    public static func best(in hand: [Card], trump: Suit) -> Combo? {
        var countsByRank: [Rank: Int] = [:]
        for card in hand {
            countsByRank[card.rank, default: 0] += 1
        }

        var best: Combo?
        // Nach Rang absteigend iterieren - Ergebnis ist zwar per `beats` ordnungsunabhängig,
        // aber feste Iterationsreihenfolge macht den Determinismus strukturell statt zufällig.
        for (rank, count) in countsByRank.sorted(by: { $0.key.rawValue > $1.key.rawValue }) where count >= 2 {
            let kind: Combo.Kind = count >= 4 ? .quad : (count == 3 ? .triple : .pair)
            let candidate = Combo(
                kind: kind,
                rank: rank,
                containsTrump: hand.contains(Card(suit: trump, rank: rank))
            )
            if best == nil || candidate.beats(best!) {
                best = candidate
            }
        }
        return best
    }
}
