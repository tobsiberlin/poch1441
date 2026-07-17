/// Eine komplette Poch-Runde (Spec Abschnitt 3): Antes → Geben → Melden (reihum, einzeln
/// ausgezahlt) → Pochen → Ausspielen → Abrechnung. Deterministisch aus Seed + Aktionsliste;
/// alles außer Poch-Aktionen und Anspielen läuft ohne Entscheidung ab. Der Event-Strom ist
/// die Quelle für UI-Inszenierung, Replays und den „Abend im Rückblick" (Spec 7a).
public struct Round: Equatable, Sendable {
    public enum Stage: Equatable, Sendable {
        case betting, playout, finished
    }

    public enum RoundEvent: Equatable, Sendable {
        case anted(perPlayer: Int)
        case dealt(upcard: Card)
        case melded(player: Int, pool: Pool, chips: Int)
        case bettingEnded(BettingPhase.Outcome)
        /// pot = alle gesetzten Chips der Bietphase; byShowdown = false heißt Sieg ohne Aufdecken.
        case pochWon(player: Int, pot: Int, pochPool: Int, byShowdown: Bool)
        case cardPlayed(PlayoutPhase.Play)
        case roundEnded(winner: Int, centerPool: Int, cardPayments: [Int])
    }

    public enum RoundError: Error, Equatable {
        case wrongStage
    }

    /// Ante pro Spieler: 1 Chip in jede der 9 Mulden (Spec Abschnitt 3).
    public static let antePerPlayer = Pool.allCases.count

    public private(set) var stage: Stage
    public private(set) var board: Board
    public private(set) var stacks: [Int]
    public let deal: Deal
    public private(set) var betting: BettingPhase
    public private(set) var playout: PlayoutPhase?
    public private(set) var events: [RoundEvent]
    /// Gewinner der Poch-Phase - führt das Ausspielen an; nil, wenn alle gepasst haben
    /// (dann führt der Spieler links vom Geber, Index 0).
    public private(set) var pochWinner: Int?

    /// Sitzkonvention wie Deal: Index 0 = links vom Geber. Alle Spieler müssen die Antes
    /// zahlen können - Zahlungsunfähige scheiden VOR der Runde aus (Match-Ebene).
    public init(stacks initialStacks: [Int], board initialBoard: Board, seed: UInt64) {
        precondition((3...6).contains(initialStacks.count), "Poch trägt 3-6 Spieler")
        precondition(
            initialStacks.allSatisfy { $0 >= Round.antePerPlayer },
            "Antes müssen zahlbar sein - Insolvenz wird vor der Runde behandelt (Spec Abschnitt 3)"
        )

        var board = initialBoard
        var stacks = initialStacks
        var events: [RoundEvent] = []

        // Antes: eine Bewegung, 9 Chips pro Spieler (Inszenierung als ein Ereignis, Spec 7a).
        for index in stacks.indices {
            stacks[index] -= Round.antePerPlayer
        }
        board.ante(playerCount: stacks.count)
        events.append(.anted(perPlayer: Round.antePerPlayer))

        let deal = Deal.deal(playerCount: stacks.count, seed: seed)
        events.append(.dealt(upcard: deal.upcard))

        // Melden: reihum ab links vom Geber, jede Mulde einzeln ausgezahlt (Spec Abschnitt 3).
        for (player, pools) in Melding.meldOrder(deal: deal) {
            for pool in Pool.allCases where pools.contains(pool) {
                let chips = board.collect(pool)
                stacks[player] += chips
                events.append(.melded(player: player, pool: pool, chips: chips))
            }
        }

        self.stage = .betting
        self.board = board
        self.stacks = stacks
        self.deal = deal
        self.betting = BettingPhase(stacks: stacks, hands: deal.hands, trump: deal.trump)
        self.playout = nil
        self.events = events
        self.pochWinner = nil
    }

    /// Engste erlaubte Sicht für die Botentscheidung des aktuell handelnden Sitzes.
    /// Fremde Hände bleiben in `Round`; Aufrufer erhalten nur eigene Karten und
    /// öffentlichen Bietzustand.
    public func botObservation(for player: Int) -> BotObservation? {
        guard stage == .betting,
              player == betting.turn,
              deal.hands.indices.contains(player),
              betting.seats.indices.contains(player) else { return nil }
        return BotObservation(
            ownHand: deal.hands[player],
            trump: deal.trump,
            currentBet: betting.currentBet,
            ownCommitted: betting.seats[player].committed
        )
    }

    /// Poch-Aktion des Spielers am Zug; bei Phasenende wird automatisch aufgelöst und
    /// ins Ausspielen gewechselt.
    public mutating func applyBet(_ action: BettingPhase.Action, by player: Int) throws {
        guard stage == .betting else { throw RoundError.wrongStage }
        try betting.apply(action, by: player)

        guard let outcome = betting.outcome else { return }
        events.append(.bettingEnded(outcome))

        stacks = betting.seats.map(\.stack)
        let pot = betting.seats.map(\.committed).reduce(0, +)

        switch outcome {
        case .allPassed:
            pochWinner = nil
        case .wonUncontested(let player):
            payPochPot(to: player, pot: pot, byShowdown: false)
        case .showdown(let players):
            let winner = Showdown.winner(among: players, hands: deal.hands, trump: deal.trump)
            payPochPot(to: winner, pot: pot, byShowdown: true)
        }

        playout = PlayoutPhase(
            hands: deal.hands,
            upcard: deal.upcard,
            firstLeader: pochWinner ?? 0
        )
        stage = .playout
    }

    /// Anspiel des aktuellen Führenden; Zwangszug-Ketten laufen automatisch, das Rundenende
    /// wird bei leerer Hand sofort abgerechnet.
    public mutating func applyLead(_ card: Card) throws {
        guard stage == .playout, var phase = playout else { throw RoundError.wrongStage }

        let playsBefore = phase.plays.count
        try phase.lead(card)
        playout = phase

        for play in phase.plays.dropFirst(playsBefore) {
            events.append(.cardPlayed(play))
        }

        guard let winner = phase.winner else { return }

        // Abrechnung: Mitte-Mulde + 1 Chip pro Restkarte von jedem Gegner, gedeckelt bei
        // Stack 0 - keine Schulden (Spec Abschnitt 3).
        let center = board.collect(.center)
        var payments = Array(repeating: 0, count: stacks.count)
        for player in stacks.indices where player != winner {
            let payment = min(phase.hands[player].count, stacks[player])
            payments[player] = payment
            stacks[player] -= payment
            stacks[winner] += payment
        }
        stacks[winner] += center
        events.append(.roundEnded(winner: winner, centerPool: center, cardPayments: payments))
        stage = .finished
    }

    private mutating func payPochPot(to player: Int, pot: Int, byShowdown: Bool) {
        pochWinner = player
        let pochPool = board.collect(.poch)
        stacks[player] += pot + pochPool
        events.append(.pochWon(player: player, pot: pot, pochPool: pochPool, byShowdown: byShowdown))
    }

    /// Gesamtchips im Rundensystem - Invariante: konstant über alle Aktionen. Während der
    /// Bietphase ist `betting` die Quelle der Stacks (Round.stacks wird erst beim Phasenende
    /// synchronisiert), danach `stacks` + Brett.
    public var totalChips: Int {
        switch stage {
        case .betting:
            return betting.seats.map { $0.stack + $0.committed }.reduce(0, +) + board.total
        case .playout, .finished:
            return stacks.reduce(0, +) + board.total
        }
    }
}
