/// Eine Partie über mehrere Runden (Spec Abschnitt 3, Partie-Ende & Kantenfälle):
/// Ausscheiden vor dem Geben bei Ante-Insolvenz, Geber-Rotation über die Verbliebenen,
/// Mulden-Übertrag zwischen Runden, Partie-Ende bei < 3 Zahlungsfähigen bzw. Rundenlimit,
/// Wertung über alle Spieler (Ausgeschiedene behalten Restchips), Tie-Break über gewonnene
/// Ausspiel-Phasen, danach geteilter Sieg. Nicht gewonnene Mulden verfallen ersatzlos.
public struct Match: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        case classic
        case quick(roundLimit: Int)
    }

    public struct MatchResult: Equatable, Sendable {
        /// Tisch-Sitze; mehr als ein Eintrag = geteilter Sieg nach Tie-Break.
        public let winners: [Int]
        public let finalStacks: [Int]
        public let roundsPlayed: Int
    }

    /// Unsichtbares Sicherheitsnetz gegen theoretisch endlose Classic-Partien (Review-Runde 8):
    /// real nie erreicht (0 Treffer in 2400 Simulationen), erzwingt aber deterministisch die
    /// Wertung nach Chipstand. Kein Regelbestandteil - reines Engine-Safety-Net.
    public let safetyRoundCap: Int

    public let mode: Mode
    public private(set) var stacks: [Int]
    public private(set) var isEliminated: [Bool]
    public private(set) var board: Board
    public private(set) var dealer: Int
    public private(set) var roundsPlayed: Int
    public private(set) var playoutWins: [Int]
    public private(set) var result: MatchResult?

    public init(playerCount: Int, startingStack: Int, mode: Mode, firstDealer: Int = 0, safetyRoundCap: Int = 500) {
        precondition((3...6).contains(playerCount), "Poch trägt 3-6 Spieler")
        precondition(startingStack >= Round.antePerPlayer, "Startstack muss die erste Ante decken")
        precondition((0..<playerCount).contains(firstDealer))
        precondition(safetyRoundCap > 0)
        self.safetyRoundCap = safetyRoundCap
        self.mode = mode
        self.stacks = Array(repeating: startingStack, count: playerCount)
        self.isEliminated = Array(repeating: false, count: playerCount)
        self.board = Board()
        self.dealer = firstDealer
        self.roundsPlayed = 0
        self.playoutWins = Array(repeating: 0, count: playerCount)
        self.result = nil
    }

    /// Beginnt die nächste Runde - oder beendet die Partie (Rundenlimit bzw. weniger als
    /// 3 Zahlungsfähige, Spec Abschnitt 3). Liefert die Runde plus das Sitz-Mapping
    /// (Runden-Index → Tisch-Sitz); Runden-Index 0 sitzt links vom Geber, der Geber selbst
    /// erhält als Letzter Karten.
    public mutating func startRound(seed: UInt64) -> (round: Round, tableSeats: [Int])? {
        guard result == nil else { return nil }
        if roundsPlayed >= safetyRoundCap {
            finish()
            return nil
        }
        if case .quick(let limit) = mode, roundsPlayed >= limit {
            finish()
            return nil
        }

        // Ausscheiden VOR dem Geben: wer die 9 Antes nicht aufbringt (behält Restchips).
        for seat in stacks.indices where !isEliminated[seat] && stacks[seat] < Round.antePerPlayer {
            isEliminated[seat] = true
        }
        let activeCount = isEliminated.filter { !$0 }.count
        guard activeCount >= 3 else {
            finish()
            return nil
        }

        var order: [Int] = []
        var seat = dealer
        for _ in 0..<stacks.count {
            seat = (seat + 1) % stacks.count
            if !isEliminated[seat] {
                order.append(seat)
            }
        }
        let round = Round(stacks: order.map { stacks[$0] }, board: board, seed: seed)
        return (round, order)
    }

    /// Übernimmt das Ergebnis einer abgeschlossenen Runde und rotiert das Geberrecht im
    /// Uhrzeigersinn zum nächsten nicht ausgeschiedenen Spieler.
    public mutating func finishRound(_ round: Round, tableSeats: [Int]) {
        precondition(round.stage == .finished, "Runde muss abgeschlossen sein")
        for (roundIndex, tableSeat) in tableSeats.enumerated() {
            stacks[tableSeat] = round.stacks[roundIndex]
        }
        board = round.board
        roundsPlayed += 1

        if case .roundEnded(let winner, _, _)? = round.events.last {
            playoutWins[tableSeats[winner]] += 1
        }

        var next = (dealer + 1) % stacks.count
        while isEliminated[next] {
            next = (next + 1) % stacks.count
        }
        dealer = next
    }

    private mutating func finish() {
        guard let top = stacks.max() else { return }
        let leaders = stacks.indices.filter { stacks[$0] == top }
        var winners = leaders
        if leaders.count > 1, let bestWins = leaders.map({ playoutWins[$0] }).max() {
            winners = leaders.filter { playoutWins[$0] == bestWins }
        }
        result = MatchResult(winners: winners, finalStacks: stacks, roundsPlayed: roundsPlayed)
    }
}
