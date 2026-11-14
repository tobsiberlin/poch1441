/// Die 9 Mulden des Pochbretts (Spec Abschnitt 3).
public enum Pool: String, CaseIterable, Codable, Hashable, Sendable {
    case ace, king, queen, jack, ten
    case mariage, sequence
    case poch
    case center

    /// Die Mulde, die zu einem Melde-Rang gehört (nur A/K/D/B/10 haben eigene Mulden).
    public static func honorPool(for rank: Rank) -> Pool? {
        switch rank {
        case .ace: return .ace
        case .king: return .king
        case .queen: return .queen
        case .jack: return .jack
        case .ten: return .ten
        default: return nil
        }
    }
}

/// Chip-Stände der Mulden. Nicht abgeholte Mulden bleiben stehen und wachsen über Runden
/// (Spec Abschnitt 3 - der eingebaute Jackpot).
public struct Board: Equatable, Codable, Sendable {
    public private(set) var chips: [Pool: Int]

    public init() {
        chips = Dictionary(uniqueKeysWithValues: Pool.allCases.map { ($0, 0) })
    }

    public subscript(pool: Pool) -> Int {
        chips[pool] ?? 0
    }

    /// Ante: 1 Chip pro Spieler in jede Mulde vor dem Geben.
    public mutating func ante(playerCount: Int) {
        for pool in Pool.allCases {
            chips[pool, default: 0] += playerCount
        }
    }

    /// Leert eine Mulde und gibt den Inhalt zurück (Gewinn-Abholung).
    public mutating func collect(_ pool: Pool) -> Int {
        let amount = chips[pool] ?? 0
        chips[pool] = 0
        return amount
    }

    /// Zahlt Chips in eine Mulde ein (z.B. Poch-Einsätze).
    public mutating func add(_ amount: Int, to pool: Pool) {
        precondition(amount >= 0, "Mulden kennen keine negativen Einzahlungen")
        chips[pool, default: 0] += amount
    }

    /// Gesamtbestand über alle Mulden (für die Chip-Erhaltungs-Invariante).
    public var total: Int {
        chips.values.reduce(0, +)
    }
}
