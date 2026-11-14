/// Headless-Simulation kompletter Partien mit zufälligen legalen Aktionen - Grundlage der
/// Monte-Carlo-Economy-Kalibrierung (Spec Abschnitt 14, Phase 1) und später der Bot-Baselines.
/// Deterministisch pro Seed; keine LLM-Judges, nur zählbare Metriken (globale LFD-Regeln).
public enum MatchSimulator {
    /// Baseline-Policies für die Kalibrierung: `random` (chaotisch, Obergrenze der Chip-
    /// Geschwindigkeit) und `cautious` (foldet ohne gutes Blatt - näher an echtem Spiel).
    /// Echte Bot-Profile ersetzen beide in Phase 4.
    public enum Policy: String, Sendable {
        case random, cautious
    }

    public struct Stats: Equatable, Sendable {
        public let roundsPlayed: Int
        /// Entscheidungspunkte eines menschlichen Spielers: Poch-Aktionen + Anspiele.
        public let decisions: Int
        public let bankruptcies: Int
        public let winners: [Int]
        public let finalStacks: [Int]
        /// true, wenn der Sicherheitsdeckel griff (klassischer Modus terminiert nicht garantiert).
        public let endedByRoundCap: Bool
    }

    public static func simulate(
        playerCount: Int,
        startingStack: Int,
        mode: Match.Mode,
        seed: UInt64,
        roundCap: Int = 400,
        policy: Policy = .random
    ) -> Stats {
        var rng = SeededRNG(seed: seed)
        var match = Match(playerCount: playerCount, startingStack: startingStack, mode: mode)
        var decisions = 0
        var cappedOut = false

        while match.result == nil {
            if match.roundsPlayed >= roundCap {
                cappedOut = true
                break
            }
            guard let (started, tableSeats) = match.startRound(seed: rng.next()) else { break }
            var round = started

            while round.stage != .finished {
                switch round.stage {
                case .betting:
                    let player = round.betting.turn
                    guard let legal = round.betting.legalActions(for: player) else { break }
                    decisions += 1
                    guard let observation = round.botObservation(for: player) else { break }
                    try? round.applyBet(
                        baselineAction(policy: policy, observation: observation, legal: legal, rng: &rng),
                        by: player
                    )
                case .playout:
                    guard let phase = round.playout,
                          let observation = phase.botObservation(for: phase.leader),
                          !observation.legalLeads.isEmpty else { break }
                    decisions += 1
                    let card = policy == .random
                        ? observation.legalLeads[rng.nextInt(in: 0..<observation.legalLeads.count)]
                        : BotBrain.lead(observation: observation)
                    guard let card else { break }
                    try? round.applyLead(card)
                case .finished:
                    break
                }
            }
            match.finishRound(round, tableSeats: tableSeats)
        }

        return Stats(
            roundsPlayed: match.roundsPlayed,
            decisions: decisions,
            bankruptcies: match.isEliminated.filter { $0 }.count,
            winners: match.result?.winners ?? [],
            finalStacks: match.stacks,
            endedByRoundCap: cappedOut
        )
    }

    /// Baseline-Bietentscheidung für Headless-Simulationen. Die Signatur akzeptiert bewusst
    /// nur die eigene Hand und öffentlichen Bietzustand. Eine vollständige Runde und damit
    /// Fremdhände sind an dieser Informationsgrenze nicht verfügbar.
    public static func baselineAction(
        policy: Policy,
        observation: BotObservation,
        legal: BettingPhase.LegalActions,
        rng: inout SeededRNG
    ) -> BettingPhase.Action {
        switch policy {
        case .random:
            var actions: [BettingPhase.Action] = [.pass]
            if let open = legal.openRange { actions.append(.open(rng.nextInt(in: open))) }
            if legal.canCall { actions.append(.call) }
            if let raise = legal.raiseRange { actions.append(.raise(to: rng.nextInt(in: raise))) }
            return actions[rng.nextInt(in: 0..<actions.count)]

        case .cautious:
            guard let combo = ComboEvaluator.best(
                in: observation.ownHand,
                trump: observation.trump
            ) else {
                return .pass
            }
            if let open = legal.openRange {
                if combo.kind > .pair || combo.rank >= .king {
                    return .open(min(2, open.upperBound))
                }
                return .pass
            }
            if legal.canCall {
                let cost = observation.currentBet - observation.ownCommitted
                if combo.kind == .quad, let raise = legal.raiseRange {
                    return .raise(to: min(raise.lowerBound + 2, raise.upperBound))
                }
                if combo.kind >= .triple || (cost <= 3 && combo.rank >= .queen) {
                    return .call
                }
            }
            return .pass
        }
    }
}
