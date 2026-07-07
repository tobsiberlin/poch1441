/// Phase 2 - Pochen als pure Zustandsmaschine (Spec Abschnitt 3, gepinnte Einsatz-/Insolvenz-
/// regeln und Kantenfälle). Die UI bezieht legale Aktionen und Gebotsgrenzen ausschließlich
/// von hier - sie rechnet nie eigene Grenzen (Review-Runde 3).
public struct BettingPhase: Equatable, Sendable {
    /// Codable für Save/Resume der App (deterministisches Replay der Aktionsfolge) -
    /// rein additive Konformität, kein Regel-Eingriff (Gate A).
    public enum Action: Equatable, Sendable, Codable {
        case pass
        /// Eröffnung mit Höchstgebot >= 1. Es gibt kein "Mitgehen 0" - Passen ist endgültig.
        case open(Int)
        case call
        case raise(to: Int)
    }

    public enum Outcome: Equatable, Sendable {
        /// Alle haben in der Eröffnungsrunde gepasst - die Poch-Mulde bleibt stehen.
        case allPassed
        /// Alle bis auf einen haben gepasst - Sieg ohne Aufdecken, der Bluff bleibt verdeckt.
        case wonUncontested(player: Int)
        /// Einsätze sind ausgeglichen - beste Kombination gewinnt.
        case showdown(players: [Int])
    }

    public enum ActionError: Error, Equatable {
        case phaseOver
        case notPlayersTurn
        case mayNotBid
        case noOpeningYet
        case alreadyOpened
        case bidOutOfBounds
    }

    public struct Seat: Equatable, Sendable {
        public internal(set) var stack: Int
        public internal(set) var committed: Int
        public internal(set) var isActive: Bool
        /// Hält mindestens ein Paar - ohne Paar weder Eröffnen noch Mitgehen (Spec Abschnitt 3).
        public let mayBid: Bool

        /// Bietberechtigt = aktiv, mit Paar und überhaupt mit Chips im Spiel. Nur diese Spieler
        /// schützt der Erhöhungs-Cap; ein 0-Chip-Spieler kann nie bieten und darf den Cap
        /// deshalb nicht auf 0 drücken (Kantenfall-Präzisierung, Spec Abschnitt 3).
        var isBidEligible: Bool {
            isActive && mayBid && stack + committed > 0
        }
    }

    public struct LegalActions: Equatable, Sendable {
        public let canPass: Bool
        public let openRange: ClosedRange<Int>?
        public let canCall: Bool
        public let raiseRange: ClosedRange<Int>?
    }

    public private(set) var seats: [Seat]
    public private(set) var currentBet: Int
    public private(set) var turn: Int
    public private(set) var outcome: Outcome?

    /// Startspieler ist links vom Geber (Index 0 der Deal-Sitzreihenfolge), sofern nicht anders gesetzt.
    public init(stacks: [Int], hands: [[Card]], trump: Suit, firstToAct: Int = 0) {
        precondition(stacks.count == hands.count, "Jeder Sitz braucht Stack und Hand")
        seats = zip(stacks, hands).map { stack, hand in
            Seat(
                stack: stack,
                committed: 0,
                isActive: true,
                mayBid: ComboEvaluator.best(in: hand, trump: trump) != nil
            )
        }
        currentBet = 0
        turn = firstToAct
    }

    /// Obergrenze für Gebote: Niemand darf höher bieten, als der knappste noch bietberechtigte
    /// Spieler insgesamt zahlen kann (kein All-in, keine Side-Pots). Wird nach jedem Passen neu
    /// berechnet - gesetzte Chips eines Passenden bleiben im Pott (Spec Abschnitt 3).
    public var bidCap: Int? {
        seats.filter(\.isBidEligible).map { $0.stack + $0.committed }.min()
    }

    /// Legale Aktionen des Spielers am Zug - Quelle der Slider-Grenzen in der Einsatz-UI.
    public func legalActions(for player: Int) -> LegalActions? {
        guard outcome == nil, player == turn, seats.indices.contains(player) else { return nil }
        let seat = seats[player]

        guard seat.isBidEligible, let cap = bidCap else {
            return LegalActions(canPass: true, openRange: nil, canCall: false, raiseRange: nil)
        }

        if currentBet == 0 {
            return LegalActions(
                canPass: true,
                openRange: cap >= 1 ? 1...cap : nil,
                canCall: false,
                raiseRange: nil
            )
        }
        return LegalActions(
            canPass: true,
            openRange: nil,
            canCall: seat.committed < currentBet,
            raiseRange: cap > currentBet ? (currentBet + 1)...cap : nil
        )
    }

    public mutating func apply(_ action: Action, by player: Int) throws {
        guard outcome == nil else { throw ActionError.phaseOver }
        guard player == turn else { throw ActionError.notPlayersTurn }
        guard let legal = legalActions(for: player) else { throw ActionError.phaseOver }

        switch action {
        case .pass:
            seats[player].isActive = false

        case .open(let amount):
            guard currentBet == 0 else { throw ActionError.alreadyOpened }
            guard let range = legal.openRange else { throw ActionError.mayNotBid }
            guard range.contains(amount) else { throw ActionError.bidOutOfBounds }
            commit(player, upTo: amount)
            currentBet = amount

        case .call:
            guard currentBet > 0 else { throw ActionError.noOpeningYet }
            guard legal.canCall else { throw ActionError.mayNotBid }
            commit(player, upTo: currentBet)

        case .raise(let to):
            guard currentBet > 0 else { throw ActionError.noOpeningYet }
            guard let range = legal.raiseRange else { throw ActionError.mayNotBid }
            guard range.contains(to) else { throw ActionError.bidOutOfBounds }
            commit(player, upTo: to)
            currentBet = to
        }

        settleAfterAction()
    }

    private mutating func commit(_ player: Int, upTo target: Int) {
        let delta = target - seats[player].committed
        precondition(delta >= 0 && delta <= seats[player].stack, "Cap-Invariante verletzt: Gebot nicht bezahlbar")
        seats[player].stack -= delta
        seats[player].committed = target
    }

    private mutating func settleAfterAction() {
        let actives = seats.indices.filter { seats[$0].isActive }

        if actives.isEmpty {
            outcome = .allPassed
            return
        }
        if currentBet > 0 {
            if actives.count == 1 {
                outcome = .wonUncontested(player: actives[0])
                return
            }
            if actives.allSatisfy({ seats[$0].committed == currentBet }) {
                outcome = .showdown(players: actives)
                return
            }
        }
        advanceTurn()
    }

    private mutating func advanceTurn() {
        var next = (turn + 1) % seats.count
        while !seats[next].isActive {
            next = (next + 1) % seats.count
        }
        turn = next
    }
}

public enum Showdown {
    /// Beste Kombination gewinnt den Pott + Poch-Mulde (Spec Abschnitt 3). Alle Beteiligten
    /// sind bietberechtigt und halten damit ein Kunststück; ein Trumpf-loser Paar-Gleichstand
    /// ist konstruktiv unmöglich (siehe Combo.beats).
    public static func winner(among players: [Int], hands: [[Card]], trump: Suit) -> Int {
        var bestPlayer: Int? = nil
        var bestCombo: Combo? = nil
        for player in players {
            guard let combo = ComboEvaluator.best(in: hands[player], trump: trump) else {
                preconditionFailure("Showdown-Teilnehmer ohne Kunststück - Bietrecht verletzt")
            }
            if let current = bestCombo {
                if combo.beats(current) {
                    bestPlayer = player
                    bestCombo = combo
                }
            } else {
                bestPlayer = player
                bestCombo = combo
            }
        }
        guard let winner = bestPlayer else {
            preconditionFailure("Showdown ohne Teilnehmer")
        }
        return winner
    }
}
