/// Bot-Charaktere v1 (Phase 4): datengetriebene Verhaltensparameter statt der
/// Cautious-Baseline. Reine Entscheidungsschicht über der öffentlichen State-API -
/// das eingefrorene Regelwerk (Gate A) bleibt unangetastet, Bots sehen nie fremde Karten.
///
/// Die ausgelieferten Archetypen leben als JSON in der App (BotProfiles.json);
/// PochKit stellt nur Mechanik + Deutung der Parameter.
public enum PlayoutStyle: String, Codable, CaseIterable, Sendable {
    /// Sucht Starts, die mehrere eigene Karten in derselben Folge freigeben.
    case runner
    /// Hält die Initiative bevorzugt an bekannten Bruchstellen.
    case anchor
    /// Drosselt gegnerische Folgekarten, sobald jemand kurz vor dem Ende steht.
    case hunter
    /// Wechselt lesbar zwischen Tempo und Kontrolle, abhängig vom Tischstand.
    case opportunist
}

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
    /// Öffentliche Phase-3-Heuristik. Sie erweitert niemals die Informationsgrenze.
    public let playoutStyle: PlayoutStyle

    public init(openAggression: Double, bluffFrequency: Double, riskTolerance: Double,
                raiseAggression: Double, thinkSecondsMin: Double, thinkSecondsMax: Double,
                playoutStyle: PlayoutStyle = .opportunist) {
        self.openAggression = openAggression
        self.bluffFrequency = bluffFrequency
        self.riskTolerance = riskTolerance
        self.raiseAggression = raiseAggression
        self.thinkSecondsMin = thinkSecondsMin
        self.thinkSecondsMax = thinkSecondsMax
        self.playoutStyle = playoutStyle
    }

    /// Neutrales Fallback-Profil (entspricht grob der bisherigen Baseline).
    public static let neutral = BotProfile(openAggression: 0.45, bluffFrequency: 0.1,
                                           riskTolerance: 0.5, raiseAggression: 0.5,
                                           thinkSecondsMin: 0.5, thinkSecondsMax: 1.05,
                                           playoutStyle: .opportunist)

    private enum CodingKeys: String, CodingKey {
        case openAggression
        case bluffFrequency
        case riskTolerance
        case raiseAggression
        case thinkSecondsMin
        case thinkSecondsMax
        case playoutStyle
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        openAggression = try values.decode(Double.self, forKey: .openAggression)
        bluffFrequency = try values.decode(Double.self, forKey: .bluffFrequency)
        riskTolerance = try values.decode(Double.self, forKey: .riskTolerance)
        raiseAggression = try values.decode(Double.self, forKey: .raiseAggression)
        thinkSecondsMin = try values.decode(Double.self, forKey: .thinkSecondsMin)
        thinkSecondsMax = try values.decode(Double.self, forKey: .thinkSecondsMax)
        playoutStyle = try values.decodeIfPresent(PlayoutStyle.self, forKey: .playoutStyle)
            ?? .opportunist
    }
}

/// Vollständige Informationsgrenze für eine Botentscheidung. Sie enthält bewusst
/// nur die eigene Hand und öffentlichen Bietzustand. Fremde Hände können einem Bot
/// damit weder versehentlich noch durch spätere Profiländerungen zugänglich werden.
public struct BotObservation: Equatable, Sendable {
    public let ownHand: [Card]
    public let trump: Suit
    public let currentBet: Int
    public let ownCommitted: Int

    /// Nur PochKit erzeugt diese Sicht aus der laufenden Bietphase. So kann ein
    /// App-Aufrufer keine fremde Hand als scheinbar eigene Bot-Hand einschleusen.
    init(ownHand: [Card], trump: Suit, currentBet: Int, ownCommitted: Int) {
        self.ownHand = ownHand
        self.trump = trump
        self.currentBet = currentBet
        self.ownCommitted = ownCommitted
    }
}

/// Vollständige Informationsgrenze für ein Bot-Anspiel in Phase 3. Die Engine
/// übergibt ausschließlich die eigenen legalen Anspielkarten und am Tisch bereits
/// öffentliche Informationen. Fremde Resthände sind strukturell nicht darstellbar.
public struct PlayoutBotObservation: Equatable, Sendable {
    public let ownSeat: Int
    public let legalLeads: [Card]
    public let upcard: Card
    public let playedCards: [Card]
    public let remainingCounts: [Int]

    /// Nur PochKit darf die Observation erzeugen; App- und Bot-Code können dadurch
    /// keine beliebige Kartenmenge als scheinbar legale Sicht einschleusen.
    init(ownSeat: Int,
         legalLeads: [Card],
         upcard: Card,
         playedCards: [Card],
         remainingCounts: [Int]) {
        self.ownSeat = ownSeat
        self.legalLeads = legalLeads
        self.upcard = upcard
        self.playedCards = playedCards
        self.remainingCounts = remainingCounts
    }
}

public enum BotBrain {
    private struct LeadFeatures {
        let card: Card
        let chainLength: Int
        let ownCardsReleased: Int
        let opponentCardsReleased: Int
        let retainsLead: Bool
        let immediateStop: Bool
        let rankStrength: Double
    }

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
    public static func action(profile: BotProfile, observation: BotObservation,
                              legal: BettingPhase.LegalActions,
                              rng: inout SeededRNG) -> BettingPhase.Action {
        let honest = strength(hand: observation.ownHand, trump: observation.trump)
        let bluffing = honest < 0.4 && rng.nextDouble01() < profile.bluffFrequency
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

        let cost = observation.currentBet - observation.ownCommitted
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
        return rng.nextDouble(in: low...high)
    }

    /// Bestehende Phase-3-Baseline als reine Entscheidung: niedrigste legale Karte.
    /// Die Strategie bleibt bewusst unverändert; insbesondere erhält sie keinen
    /// `PlayoutPhase` und damit keine gegnerischen Resthände.
    public static func lead(observation: PlayoutBotObservation) -> Card? {
        observation.legalLeads.min { $0.rank.rawValue < $1.rank.rawValue }
    }

    /// Profilierte Ausspielentscheidung. Jede Bewertung wird ausschließlich aus der
    /// eigenen Hand und bereits öffentlichen Tischinformationen abgeleitet. Da jede Karte
    /// im Poch-Blatt eindeutig ist, lässt sich erkennen, ob eine Folge an Trumpfkarte,
    /// bereits gespielter Karte oder Ass stoppt - aber nie, welcher Gegner eine unbekannte
    /// Folgekarte hält.
    public static func lead(profile: BotProfile,
                            observation: PlayoutBotObservation,
                            rng: inout SeededRNG) -> Card? {
        guard !observation.legalLeads.isEmpty else { return nil }
        let candidates = observation.legalLeads.sorted {
            if $0.suit.rawValue != $1.suit.rawValue {
                return $0.suit.rawValue < $1.suit.rawValue
            }
            return $0.rank.rawValue < $1.rank.rawValue
        }
        let ownCount = observation.legalLeads.count
        let closestOpponent = observation.remainingCounts.indices
            .filter { $0 != observation.ownSeat }
            .map { observation.remainingCounts[$0] }
            .min() ?? ownCount

        var bestCard = candidates[0]
        var bestScore = -Double.infinity
        for card in candidates {
            let features = leadFeatures(for: card, observation: observation)
            let base = score(features,
                             style: profile.playoutStyle,
                             ownCount: ownCount,
                             closestOpponent: closestOpponent)
            // Kleine deterministische Unruhe verhindert mechanisch identische Wiederholungen,
            // ohne die erkennbare Stil-Signatur zu überdecken.
            let score = base + rng.nextDouble(in: -0.045...0.045)
            if score > bestScore {
                bestScore = score
                bestCard = card
            }
        }
        return bestCard
    }

    private static func score(_ features: LeadFeatures,
                              style: PlayoutStyle,
                              ownCount: Int,
                              closestOpponent: Int) -> Double {
        let runnerScore = Double(features.ownCardsReleased) * 4.8
            - Double(features.opponentCardsReleased) * 0.72
            + Double(features.chainLength) * 0.12
            - features.rankStrength * 0.18
        let anchorScore = (features.retainsLead ? 6.0 : 0)
            + (features.immediateStop ? 2.4 : 0)
            + Double(features.ownCardsReleased) * 0.9
            - Double(features.opponentCardsReleased) * 1.45
            + features.rankStrength * 0.34
        let danger = closestOpponent <= 2
        let hunterScore = (features.retainsLead ? (danger ? 5.8 : 3.4) : 0)
            + Double(features.ownCardsReleased) * (danger ? 1.7 : 1.25)
            - Double(features.opponentCardsReleased) * (danger ? 3.7 : 1.35)
            + (features.immediateStop && danger ? 1.8 : 0)

        switch style {
        case .runner:
            return runnerScore
        case .anchor:
            return anchorScore
        case .hunter:
            return hunterScore
        case .opportunist:
            if ownCount <= 2 { return runnerScore * 1.08 + anchorScore * 0.18 }
            if closestOpponent <= 2 { return hunterScore * 1.05 + anchorScore * 0.22 }
            return runnerScore * 0.54 + anchorScore * 0.52
        }
    }

    private static func leadFeatures(for lead: Card,
                                     observation: PlayoutBotObservation) -> LeadFeatures {
        let ownCards = Set(observation.legalLeads)
        let unavailable = Set(observation.playedCards).union([observation.upcard])
        var current = lead
        var chainLength = 1
        var ownCardsReleased = 1
        var opponentCardsReleased = 0
        var lastCardIsOwn = true

        while let nextRank = Rank(rawValue: current.rank.rawValue + 1) {
            let next = Card(suit: current.suit, rank: nextRank)
            guard !unavailable.contains(next) else { break }
            chainLength += 1
            if ownCards.contains(next) {
                ownCardsReleased += 1
                lastCardIsOwn = true
            } else {
                opponentCardsReleased += 1
                lastCardIsOwn = false
            }
            current = next
        }

        return LeadFeatures(
            card: lead,
            chainLength: chainLength,
            ownCardsReleased: ownCardsReleased,
            opponentCardsReleased: opponentCardsReleased,
            retainsLead: lastCardIsOwn,
            immediateStop: chainLength == 1,
            rankStrength: Double(lead.rank.rawValue - Rank.seven.rawValue) / 7.0
        )
    }
}

extension ClosedRange<Int> {
    fileprivate func clampedAmount(_ value: Int) -> Int {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
