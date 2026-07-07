/// Bot-Charaktere v1 (Phase 4): datengetriebene Verhaltensparameter statt der
/// Cautious-Baseline. Reine Entscheidungsschicht über der öffentlichen State-API -
/// das eingefrorene Regelwerk (Gate A) bleibt unangetastet, Bots sehen nie fremde Karten.
///
/// Die ausgelieferten Archetypen leben als JSON in der App (BotProfiles.json);
/// PochKit stellt nur Mechanik + Deutung der Parameter.
public struct BotProfile: Codable, Sendable, Equatable {
    /// 0-1: Eröffnungsfreude - hohe Werte pochen auch mit mittlerer Hand.
    public let openAggression: Double
    /// 0-1: Anteil bewusst starker Auftritte trotz schwacher Hand.
    public let bluffFrequency: Double
    /// 0-1: Kosten-Toleranz beim Mitgehen.
    public let riskTolerance: Double
    /// 0-1: Erhöhungs-Freude bei starker Hand.
    public let raiseAggression: Double
    /// Denkpausen-Spanne in Sekunden (nur Präsentation, nie Regelwirkung).
    public let thinkSecondsMin: Double
    public let thinkSecondsMax: Double

    public init(openAggression: Double, bluffFrequency: Double, riskTolerance: Double,
                raiseAggression: Double, thinkSecondsMin: Double, thinkSecondsMax: Double) {
        self.openAggression = openAggression
        self.bluffFrequency = bluffFrequency
        self.riskTolerance = riskTolerance
        self.raiseAggression = raiseAggression
        self.thinkSecondsMin = thinkSecondsMin
        self.thinkSecondsMax = thinkSecondsMax
    }

    /// Neutrales Fallback-Profil (entspricht grob der bisherigen Baseline).
    public static let neutral = BotProfile(openAggression: 0.45, bluffFrequency: 0.1,
                                           riskTolerance: 0.5, raiseAggression: 0.5,
                                           thinkSecondsMin: 0.5, thinkSecondsMax: 1.05)
}

public enum BotBrain {
    /// Handstärke 0-1 aus der öffentlichen Kunststück-Bewertung.
    /// Kein Paar → sehr schwach; Paar/Drilling/Vierling steigen deutlich, Rang feint nach.
    static func strength(hand: [Card], trump: Suit) -> Double {
        guard let combo = ComboEvaluator.best(in: hand, trump: trump) else { return 0.12 }
        let rank01 = Double(combo.rank.rawValue - 7) / 7.0
        switch combo.kind {
        case .pair: return 0.34 + rank01 * 0.2
        case .triple: return 0.62 + rank01 * 0.18
        case .quad: return 0.88 + rank01 * 0.1
        }
    }

    /// Bietentscheidung eines Profils. Wählt ausschließlich aus den übergebenen legalen
    /// Aktionen; deterministisch pro (Profil, Zustand, RNG-Stand).
    public static func action(profile: BotProfile, round: Round, player: Int,
                              legal: BettingPhase.LegalActions,
                              rng: inout SeededRNG) -> BettingPhase.Action {
        let honest = strength(hand: round.deal.hands[player], trump: round.deal.trump)
        let bluffing = honest < 0.4 && Double.random(in: 0..<1, using: &rng) < profile.bluffFrequency
        let effective = min(1.0, honest + (bluffing ? 0.38 : 0))

        if let open = legal.openRange {
            let threshold = 0.62 - 0.3 * profile.openAggression
            if effective >= threshold {
                // Einsatzhöhe absolut gedeckelt: die Economy ist auf kleine Eröffnungen
                // kalibriert - Aggression wirkt über Häufigkeit UND Höhe, aber nie den
                // ganzen Cap (Balance-Befund 6.7.: Wirt eröffnete sonst mit 18)
                let headroom = Double(min(open.upperBound - open.lowerBound, 6))
                let amount = open.lowerBound
                    + Int((headroom * profile.openAggression * effective).rounded())
                return .open(open.clampedAmount(amount))
            }
            return .pass
        }

        let cost = round.betting.currentBet - round.betting.seats[player].committed
        if legal.canCall {
            if let raise = legal.raiseRange, effective >= 0.84 - 0.26 * profile.raiseAggression {
                let headroom = Double(min(raise.upperBound - raise.lowerBound, 5))
                let to = raise.lowerBound
                    + Int((headroom * 0.5 * (profile.raiseAggression + effective) / 2).rounded())
                return .raise(to: raise.clampedAmount(to))
            }
            let affordable = 1.0 + 6.0 * profile.riskTolerance * effective
            if Double(cost) <= affordable || effective >= 0.72 {
                return .call
            }
        }
        return .pass
    }

    /// Denkpause des Profils in Sekunden (Präsentations-Tempo, kein Regelwerk).
    public static func thinkSeconds(profile: BotProfile, rng: inout SeededRNG) -> Double {
        let low = min(profile.thinkSecondsMin, profile.thinkSecondsMax)
        let high = max(profile.thinkSecondsMin, profile.thinkSecondsMax)
        return Double.random(in: low...high, using: &rng)
    }
}

extension ClosedRange<Int> {
    fileprivate func clampedAmount(_ value: Int) -> Int {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
