import Observation
import PochKit

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

/// View-zugewandter Zustand: rendert nur, was aus der Runde kommt. Aktueller Fokus:
/// die Melde-Phase (Poch-Ring mit echten Mulden-Werten).
@Observable @MainActor
final class GameState {
    private var source: MatchSource
    /// Beobachtbare Spiegelung der aktuellen Runde - Änderungen lösen View-Updates aus.
    private(set) var round: Round

    init(source: MatchSource = BotMatchSource()) {
        self.source = source
        self.round = source.round
    }

    // MARK: - Melde-Phase-Werte (echte Engine-Daten)

    /// Chip-Stand einer Mulde.
    func chips(in pool: Pool) -> Int { round.board[pool] }
    var trump: Suit { round.deal.trump }
    var upcard: Card { round.deal.upcard }
    /// Menschen-Hand (Sitz 0 = links vom Geber).
    var humanHand: [Card] { round.deal.hands.first ?? [] }
    /// Chip-Konten der Gegner (Sitze 1...).
    var opponentStacks: [Int] { Array(round.stacks.dropFirst()) }

    func newRound() {
        source.newRound(seed: UInt64.random(in: 1...999_999))
        round = source.round
    }
}
