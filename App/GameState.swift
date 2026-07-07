import Observation
import PochKit
import os

/// Quelle der Spielzustände (§7b Architektur-Seam). v1: lokal via Bots. v2 kann hier eine
/// Netzwerk-Quelle andocken, ohne dass der View-Code eine Zeile ändert.
@MainActor
protocol MatchSource {
    var round: Round { get }
    mutating func newRound(seed: UInt64)
}

/// Lokale Quelle: eine PochKit-Runde gegen Bots (v1-Scope, kein Netzwerk-Code).
@MainActor
final class BotMatchSource: MatchSource {
    private(set) var round: Round
    private let playerCount: Int

    init(seed: UInt64 = 1441, playerCount: Int = 4) {
        self.playerCount = playerCount
        round = Round(stacks: Array(repeating: 60, count: playerCount), board: Board(), seed: seed)
    }

    func newRound(seed: UInt64) {
        round = Round(stacks: Array(repeating: 60, count: playerCount), board: Board(), seed: seed)
    }
}

/// Sichtbarer Auftritt eines Sitzes in der Bietrunde (§6b: Reaktion auf den ÖFFENTLICHEN
/// Zustand - nie auf verdeckte Karten).
enum SeatAction: Equatable {
    case none, thinking, passed, opened(Int), called, raised(Int)
}

/// View-zugewandter Zustand: rendert nur, was aus der Runde kommt. Fokus jetzt:
/// Melde-Tableau (Phase 1) + Bietrunde (Phase 2) mit Bot-Denkpausen.
@Observable @MainActor
final class GameState {
    private var source: MatchSource
    /// Beobachtbare Spiegelung der aktuellen Runde - die Runde ist ein Wert, GameState
    /// führt die lebende Kopie (Aktionen mutieren hier, source liefert nur frische Runden).
    private(set) var round: Round
    /// Letzter sichtbarer Auftritt pro Sitz (Action-Bubble in Phase 2).
    private(set) var seatActions: [SeatAction]

    /// Präsentations-RNG der Bots (Denkpausen, Entscheidungen). Unabhängig vom Runden-Seed,
    /// damit Replays der Regel-Ebene stabil bleiben.
    private var botRNG = SeededRNG(seed: 0xC0FFEE)
    private var botTask: Task<Void, Never>?
    private let log = Logger(subsystem: "com.tobc.poch1441", category: "GameState")

    /// Platzhalter-Namen bis zum Charakter-Roster (§7.1, BotProfiles.json folgt mit
    /// der Meta-Progression). Sitzreihenfolge 1...3.
    private static let opponentNames = ["Nova", "Blade", "Glitch"]

    init(source: MatchSource = BotMatchSource()) {
        self.source = source
        self.round = source.round
        self.seatActions = Array(repeating: .none, count: source.round.stacks.count)
    }

    // MARK: - Gemeinsame Werte

    func chips(in pool: Pool) -> Int { round.board[pool] }
    var trump: Suit { round.deal.trump }
    var upcard: Card { round.deal.upcard }
    /// Menschen-Hand (Sitz 0 = links vom Geber).
    var humanHand: [Card] { round.deal.hands.first ?? [] }
    /// Chip-Konten der Gegner (Sitze 1...).
    var opponentStacks: [Int] { Array(round.stacks.dropFirst()) }
    var stage: Round.Stage { round.stage }

    func name(of seat: Int) -> String {
        seat == 0 ? "Du" : Self.opponentNames[(seat - 1) % Self.opponentNames.count]
    }

    func newRound() {
        botTask?.cancel()
        source.newRound(seed: UInt64.random(in: 1...999_999))
        round = source.round
        seatActions = Array(repeating: .none, count: round.stacks.count)
    }

    // MARK: - Phase 2 (Pochen) - Zustand

    var betting: BettingPhase { round.betting }
    /// Alle gesetzten Chips der laufenden Bietrunde (der violette Pott wächst sichtbar, §6b).
    var pot: Int { betting.seats.map(\.committed).reduce(0, +) }
    /// Stehende Poch-Mulde - geht zusätzlich an den Sieger.
    var pochPool: Int { round.board[.poch] }
    var turnIndex: Int { betting.turn }
    var humanLegal: BettingPhase.LegalActions? { betting.legalActions(for: 0) }

    /// Wand-Besitzer (§6b): der knappste noch bietberechtigte Spieler deckelt jedes Gebot.
    /// Bietberechtigt = aktiv + Paar + Chips im Spiel (Spiegel der Engine-Regel).
    var capHolder: Int? {
        let eligible = betting.seats.indices.filter {
            let s = betting.seats[$0]
            return s.isActive && s.mayBid && s.stack + s.committed > 0
        }
        return eligible.min { a, b in
            betting.seats[a].stack + betting.seats[a].committed
                < betting.seats[b].stack + betting.seats[b].committed
        }
    }

    /// Ausgang der Bietrunde für das Ergebnis-Banner (nil solange offen).
    var pochResult: (winner: Int, pot: Int, pochPool: Int, byShowdown: Bool)? {
        for event in round.events {
            if case .pochWon(let player, let pot, let pool, let showdown) = event {
                return (player, pot, pool, showdown)
            }
        }
        return nil
    }

    var allPassed: Bool {
        round.events.contains {
            if case .bettingEnded(.allPassed) = $0 { return true }
            return false
        }
    }

    // MARK: - Phase 2 - Aktionen

    func humanPass() { applyHuman(.pass) }
    func humanOpen(_ amount: Int) { applyHuman(.open(amount)) }
    func humanCall() { applyHuman(.call) }
    func humanRaise(to amount: Int) { applyHuman(.raise(to: amount)) }

    private func applyHuman(_ action: BettingPhase.Action) {
        guard stage == .betting, betting.turn == 0 else { return }
        do {
            try round.applyBet(action, by: 0)
            seatActions[0] = Self.display(action)
            runBotsIfNeeded()
        } catch {
            // UI bezieht Grenzen aus legalActions - hier zu landen ist ein Programmierfehler.
            log.error("Illegale Spieler-Aktion: \(String(describing: error))")
        }
    }

    /// Bot-Schleife: variable Denkpausen aus Profil + Rauschen (§6b - Tells zeigen den
    /// Charakter, nie die Hand; BotBrain sieht nur die öffentliche State-API).
    private func runBotsIfNeeded() {
        botTask?.cancel()
        guard stage == .betting, betting.outcome == nil, betting.turn != 0 else { return }
        botTask = Task { await botLoop() }
    }

    private func botLoop() async {
        while !Task.isCancelled, stage == .betting, betting.outcome == nil, betting.turn != 0 {
            let seat = betting.turn
            seatActions[seat] = .thinking
            let pause = BotBrain.thinkSeconds(profile: .neutral, rng: &botRNG)
            try? await Task.sleep(for: .seconds(pause))
            guard !Task.isCancelled, stage == .betting, betting.turn == seat,
                  let legal = betting.legalActions(for: seat) else { return }
            let action = BotBrain.action(profile: .neutral, round: round, player: seat,
                                         legal: legal, rng: &botRNG)
            do {
                try round.applyBet(action, by: seat)
                seatActions[seat] = Self.display(action)
            } catch {
                log.error("Illegale Bot-Aktion Sitz \(seat): \(String(describing: error))")
                return
            }
        }
    }

    private static func display(_ action: BettingPhase.Action) -> SeatAction {
        switch action {
        case .pass: return .passed
        case .open(let amount): return .opened(amount)
        case .call: return .called
        case .raise(let to): return .raised(to)
        }
    }

    // MARK: - §6b: dein qualifizierendes Kunststück leuchtet (nur eigene Hand)

    var humanComboRank: Rank? {
        ComboEvaluator.best(in: humanHand, trump: trump)?.rank
    }
}
