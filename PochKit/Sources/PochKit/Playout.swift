/// Phase 3 - Ausspielen (Spec Abschnitt 3): Der Führende legt eine beliebige Karte; wer die
/// nächsthöhere Karte derselben Farbe hält, muss sie legen (Zwangszug, läuft automatisch).
/// Die Kette reißt, wenn die benötigte Karte in keiner Hand mehr ist - Ass erreicht, offene
/// Trumpfkarte oder bereits gespielt. Wer die letzte Karte legte, eröffnet neu. Die Runde
/// endet sofort, sobald eine Hand leer ist - auch mitten in der Kette.
public struct PlayoutPhase: Equatable, Sendable {
    public enum PlayError: Error, Equatable {
        case phaseOver
        case cardNotInLeadersHand
    }

    /// Gespielte Karte mit Kontext - Grundlage für UI-Inszenierung und „Abend im Rückblick".
    public struct Play: Equatable, Sendable {
        public let player: Int
        public let card: Card
        public let isLead: Bool
    }

    public private(set) var hands: [[Card]]
    public let upcard: Card
    public private(set) var leader: Int
    public private(set) var winner: Int?
    public private(set) var plays: [Play]

    public init(hands: [[Card]], upcard: Card, firstLeader: Int) {
        precondition(hands.indices.contains(firstLeader), "Führender muss am Tisch sitzen")
        self.hands = hands
        self.upcard = upcard
        self.leader = firstLeader
        self.winner = nil
        self.plays = []
    }

    /// Restkarten pro Spieler - Basis für die Auszahlung am Rundenende (1 Chip pro Restkarte).
    public var remainingCounts: [Int] {
        hands.map(\.count)
    }

    /// Der Führende eröffnet mit einer beliebigen Handkarte; die Zwangszug-Kette läuft danach
    /// automatisch ab.
    public mutating func lead(_ card: Card) throws {
        guard winner == nil else { throw PlayError.phaseOver }
        guard let index = hands[leader].firstIndex(of: card) else { throw PlayError.cardNotInLeadersHand }

        hands[leader].remove(at: index)
        plays.append(Play(player: leader, card: card, isLead: true))
        if hands[leader].isEmpty {
            winner = leader
            return
        }
        runChain(from: card)
    }

    private mutating func runChain(from leadCard: Card) {
        var currentCard = leadCard
        var lastPlayer = leader

        while winner == nil, let next = currentCard.higherNeighbor {
            guard let holder = hands.firstIndex(where: { $0.contains(next) }) else {
                break // Kette reißt: Ass wäre der nil-Fall darüber; hier Trumpfkarte oder bereits gespielt
            }
            if let cardIndex = hands[holder].firstIndex(of: next) {
                hands[holder].remove(at: cardIndex)
            }
            plays.append(Play(player: holder, card: next, isLead: false))
            if hands[holder].isEmpty {
                winner = holder
                return
            }
            lastPlayer = holder
            currentCard = next
        }
        leader = lastPlayer
    }
}

private extension Card {
    /// Die nächsthöhere Karte derselben Farbe - nil oberhalb des Asses.
    var higherNeighbor: Card? {
        Rank(rawValue: rank.rawValue + 1).map { Card(suit: suit, rank: $0) }
    }
}
