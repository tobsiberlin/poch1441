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
    private static let opponentNames = ["Wirt", "Baronesse", "Ratsherr"]

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
        adoptRound(seed: UInt64.random(in: 1...999_999))
    }

    /// Startet eine bewusst freundliche Lernrunde: eigene Hand hat ein Poch-Kunststück,
    /// die Meldephase zeigt genug Tischereignisse, aber die Engine bleibt die Wahrheit.
    func startTutorialRound() {
        adoptRound(seed: Self.tutorialSeed(playerCount: round.stacks.count))
    }

    private func adoptRound(seed: UInt64) {
        botTask?.cancel()
        cascadeTask?.cancel()
        source.newRound(seed: seed)
        round = source.round
        seatActions = Array(repeating: .none, count: round.stacks.count)
        dealtCount = 0
        trumpRevealed = false
        lightPulse = 0
        meldShown = 0
        pulsingPool = nil
        revealedPlays = 0
        kollapsInfo = nil
        kollapsShock = 0
        endPhase = .none
    }

    private static func tutorialSeed(playerCount: Int) -> UInt64 {
        for seed in UInt64(1_441)..<UInt64(20_000) {
            let candidate = Round(stacks: Array(repeating: 60, count: playerCount),
                                  board: Board(),
                                  seed: seed)
            guard ComboEvaluator.best(in: candidate.deal.hands[0],
                                      trump: candidate.deal.trump) != nil
            else { continue }

            let melds = candidate.events.compactMap { event -> Pool? in
                if case .melded(let player, let pool, _) = event, player == 0 {
                    return pool
                }
                return nil
            }
            if melds.count >= 2 { return seed }
        }
        return 1_441
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

    /// "Der Poch" (§6b): jeder Tischschlag (Eröffnen/Erhöhen, Mensch wie Bot)
    /// triggert Zittern der Tisch-Welt + .heavy-Haptik.
    private(set) var pochShock = 0

    private func applyHuman(_ action: BettingPhase.Action) {
        guard stage == .betting, betting.turn == 0 else { return }
        do {
            try round.applyBet(action, by: 0)
            seatActions[0] = Self.display(action)
            if case .open = action { pochShock += 1 }
            if case .raise = action { pochShock += 1 }
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
                if case .open = action { pochShock += 1 }
                if case .raise = action { pochShock += 1 }
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

    // MARK: - Phase 3 (Ausspielen) - Kaskaden-Präsentation (§6c)

    /// Die Engine löst Zwangsketten instant - die UI enthüllt die Plays im 180-ms-Takt
    /// (Parameter-Lock), mit 350-ms-Beat-Drop am Kettenriss. `revealedPlays` ist der
    /// Präsentations-Zeiger in den Play-Strom.
    private(set) var revealedPlays = 0
    private var cascadeTask: Task<Void, Never>?

    var playout: PlayoutPhase? { round.playout }

    /// Enthüllte Plays, in Ketten gruppiert (jede Kette beginnt mit einem Anspiel).
    var revealedChains: [[PlayoutPhase.Play]] {
        guard let phase = round.playout else { return [] }
        var chains: [[PlayoutPhase.Play]] = []
        for play in phase.plays.prefix(revealedPlays) {
            if play.isLead || chains.isEmpty {
                chains.append([play])
            } else {
                chains[chains.count - 1].append(play)
            }
        }
        return chains
    }

    /// Kaskade eingeholt = alle Plays sichtbar, Tisch wartet aufs nächste Anspiel.
    var cascadeIdle: Bool {
        revealedPlays == (round.playout?.plays.count ?? 0)
    }

    /// Rundenende-Inszenierung (§6c c): Eiszeit-Vakuum -> Straf-Strom -> Banner.
    enum EndPhase: Comparable { case none, frozen, punishing, done }
    private(set) var endPhase: EndPhase = .none

    /// Anzeige-Konto am Rundenende: im Freeze noch VOR den Strafzahlungen, ab dem
    /// Straf-Strom rollen die Zähler auf den Endstand.
    func displayedEndStack(of seat: Int) -> Int {
        guard let result = roundResult, endPhase == .frozen || endPhase == .none else {
            return round.stacks[seat]
        }
        if seat == result.winner {
            return round.stacks[seat] - result.centerPool - result.payments.reduce(0, +)
        }
        return round.stacks[seat] + result.payments[seat]
    }

    /// Sichtbare Hand eines Sitzes: Deal minus enthüllte Plays (nicht Engine-Stand,
    /// der der Präsentation vorausläuft).
    func displayedHand(of seat: Int) -> [Card] {
        guard let phase = round.playout else {
            return seat == 0 ? humanHand : round.deal.hands[seat]
        }
        let played = Set(phase.plays.prefix(revealedPlays)
            .filter { $0.player == seat }.map(\.card))
        return round.deal.hands[seat].filter { !played.contains($0) }
    }

    /// Rundenergebnis fürs Banner (nil solange offen).
    var roundResult: (winner: Int, centerPool: Int, payments: [Int])? {
        for event in round.events {
            if case .roundEnded(let winner, let pool, let payments) = event {
                return (winner, pool, payments)
            }
        }
        return nil
    }

    struct RoundRecap {
        let chains: Int
        let longestChain: Int
        let finalCard: Card?
        let finalPlayer: Int?
    }

    var roundRecap: RoundRecap {
        var chainCount = 0
        var longest = 0
        var current = 0
        var finalCard: Card?
        var finalPlayer: Int?

        for event in round.events {
            guard case .cardPlayed(let play) = event else { continue }
            if play.isLead {
                if current > 0 { longest = max(longest, current) }
                chainCount += 1
                current = 1
            } else {
                current += 1
            }
            finalCard = play.card
            finalPlayer = play.player
        }
        longest = max(longest, current)
        return RoundRecap(chains: chainCount,
                          longestChain: longest,
                          finalCard: finalCard,
                          finalPlayer: finalPlayer)
    }

    /// Start der Phase-3-Präsentation (Aufruf beim Aktwechsel): enthüllt bereits
    /// gelaufene Ketten und lässt Bots anspielen, wenn sie führen.
    func beginPlayoutPresentation() {
        runCascadeIfNeeded()
    }

    /// Anspiel des Menschen - nur wenn er führt und die Kaskade eingeholt ist.
    func humanLead(_ card: Card) {
        guard stage == .playout, let phase = round.playout,
              phase.leader == 0, cascadeIdle else { return }
        do {
            try round.applyLead(card)
            revealedPlays += 1  // das eigene Anspiel erscheint sofort
            runCascadeIfNeeded()
        } catch {
            log.error("Illegales Anspiel: \(String(describing: error))")
        }
    }

    private func runCascadeIfNeeded() {
        cascadeTask?.cancel()
        cascadeTask = Task { await cascadeLoop() }
    }

    private func cascadeLoop() async {
        while !Task.isCancelled {
            guard let phase = round.playout else { return }
            if revealedPlays < phase.plays.count {
                // Zwangskarte im Kaskaden-Takt enthüllen
                try? await Task.sleep(for: .seconds(Tokens.p3CascadeStep))
                guard !Task.isCancelled else { return }
                revealedPlays += 1
                let chainEnded = revealedPlays == phase.plays.count
                    || phase.plays[revealedPlays].isLead
                if chainEnded {
                    // Beat-Drop: Stille, Stopper glüht, Anspielrecht wandert (§6c)
                    try? await Task.sleep(for: .seconds(Tokens.p3BeatDrop))
                }
            } else if stage != .playout {
                await runEndSequence()
                return
            } else if phase.leader != 0 {
                // Bot spielt an: kurze Denkpause, dann niedrigste Karte
                // (Platzhalter-Heuristik; echte Anspiel-Taktik kommt mit den Bot-Profilen)
                let pause = BotBrain.thinkSeconds(profile: .neutral, rng: &botRNG)
                try? await Task.sleep(for: .seconds(pause))
                guard !Task.isCancelled, stage == .playout, cascadeIdle,
                      let current = round.playout, current.leader != 0,
                      let card = current.hands[current.leader]
                          .min(by: { $0.rank.rawValue < $1.rank.rawValue })
                else { continue }
                do {
                    try round.applyLead(card)
                    revealedPlays += 1
                } catch {
                    log.error("Illegales Bot-Anspiel: \(String(describing: error))")
                    return
                }
            } else {
                return  // Mensch führt - warten auf Tap
            }
        }
    }

    /// Eiszeit-Vakuum (§6c c): sofortiger Freeze -> 400-ms-Zäsur (Centerpot glüht) ->
    /// paralleler Straf-Strom mit gedeckelter 90-ms-Tick-Kadenz -> Banner.
    private func runEndSequence() async {
        guard endPhase == .none else { return }
        endPhase = .frozen
        hapticTick += 1
        try? await Task.sleep(for: .seconds(Tokens.p3Vakuum))
        guard !Task.isCancelled else { return }
        endPhase = .punishing
        let resultValue = (roundResult?.centerPool ?? 0) + (roundResult?.payments.reduce(0, +) ?? 0)
        let ticks = min(resultValue, Tokens.p3PunishTickCap)
        for _ in 0..<ticks {
            hapticTick += 1
            try? await Task.sleep(for: .seconds(Tokens.hapticCadence))
            if Task.isCancelled { return }
        }
        try? await Task.sleep(for: .seconds(0.45))
        guard !Task.isCancelled else { return }
        endPhase = .done
    }

    #if DEBUG
    /// QA-Helfer (Launch-Arg -ausspielStart): Bietrunde per Alle-passen überspringen,
    /// damit Screenshots direkt in Phase 3 starten. Nur DEBUG, nie Release (§6).
    func debugSkipToPlayout() {
        while stage == .betting {
            do { try round.applyBet(.pass, by: betting.turn) } catch { return }
        }
    }

    /// QA-Helfer: spielt Phase 3 deterministisch zu Ende und springt direkt auf den
    /// finalen Banner. Nur fuer Screenshots/Design-Audit, nie Release.
    func debugFinishPlayout() {
        debugSkipToPlayout()
        guard var phase = round.playout else { return }
        var guardCount = 0
        while stage == .playout, guardCount < 80 {
            guardCount += 1
            phase = round.playout ?? phase
            let leader = phase.leader
            guard let card = phase.hands[leader]
                .min(by: { $0.rank.rawValue < $1.rank.rawValue }) else { break }
            do { try round.applyLead(card) } catch { break }
        }
        revealedPlays = round.playout?.plays.count ?? revealedPlays
        endPhase = .done
    }

    /// QA-Helfer: Rundenende vorbereiten und in der sichtbaren Strafstrom-Phase halten,
    /// damit Centerpot-/Restkarten-Orchestrierung als Screenshot prüfbar ist.
    func debugShowPunishingEnd() {
        debugFinishPlayout()
        endPhase = .punishing
    }
    #endif

    // MARK: - Phase 1: Deal-Präsentation / Trumpf-Beat (§6a)

    /// Visuell ausgeteilte Karten (0...31). Die Engine hat längst gegeben - das hier
    /// ist reine Inszenierung im 40-ms-Takt (Parameter-Lock).
    private(set) var dealtCount = 0
    private(set) var trumpRevealed = false
    /// Trigger des radialen Lichtpulses (Trumpf-Flip).
    private(set) var lightPulse = 0
    /// Haptik-Ticker in fester 90-ms-Kadenz - entkoppelt von der Karten-Anzahl
    /// (§6 Auflage 4: Taptic Engine schluckt zu schnelle Haptiks).
    private(set) var hapticTick = 0
    private var dealTask: Task<Void, Never>?

    var totalDeals: Int { round.deal.hands.map(\.count).reduce(0, +) }

    /// Austeil-Reihenfolge: reihum ab Sitz 0, erschöpfte Hände übersprungen (8/8/8/7).
    var dealOrder: [(seat: Int, slot: Int)] {
        let counts = round.deal.hands.map(\.count)
        var slots = Array(repeating: 0, count: counts.count)
        var order: [(seat: Int, slot: Int)] = []
        var seat = 0
        while order.count < counts.reduce(0, +) {
            if slots[seat] < counts[seat] {
                order.append((seat, slots[seat]))
                slots[seat] += 1
            }
            seat = (seat + 1) % counts.count
        }
        return order
    }

    /// Sichtbare Handkarten des Menschen - hinkt dem Austeil-Zeiger um die Flugdauer
    /// (~2 Takte) hinterher, damit Karte erst "ankommt", dann erscheint.
    var humanDealtVisible: Int {
        if dealtCount >= totalDeals { return round.deal.hands[0].count }
        return dealOrder.prefix(max(0, dealtCount - 2)).filter { $0.seat == 0 }.count
    }

    // MARK: - Melde-Strom (§6a b) - Anzeige läuft der Engine hinterher

    /// Melde-Ereignisse der Runde in Engine-Reihenfolge.
    var meldEvents: [(player: Int, pool: Pool, chips: Int)] {
        round.events.compactMap {
            if case .melded(let player, let pool, let chips) = $0 {
                return (player, pool, chips)
            }
            return nil
        }
    }

    /// Bereits präsentierte Meldungen (0...meldEvents.count).
    private(set) var meldShown = 0
    /// Stufe-2-Kollaps (§6a e): Trigger + Kontext der Explosion.
    private(set) var kollapsShock = 0
    private(set) var kollapsInfo: (pool: Pool, chips: Int, player: Int)?
    #if DEBUG
    /// QA-Override (-kollapsDemo): erzwingt Zündung bei jedem Meld.
    static var kollapsThresholdOverride: Int?
    #endif

    private var effectiveKollapsThreshold: Int {
        #if DEBUG
        if let override = Self.kollapsThresholdOverride { return override }
        #endif
        return Tokens.jackpotKollapsThreshold
    }
    /// Mulde, die gerade pulst (aktive Meldung).
    private(set) var pulsingPool: Pool?

    /// Anzeige-Wert einer Mulde: Engine-Stand PLUS noch nicht präsentierte Melde-Chips
    /// (die Engine hat beim Runden-Init längst kassiert - die Inszenierung zahlt einzeln aus).
    func displayedChips(in pool: Pool) -> Int {
        round.board[pool] + meldEvents.dropFirst(meldShown)
            .filter { $0.pool == pool }
            .reduce(0) { $0 + $1.chips }
    }

    /// Anzeige-Konto eines Sitzes: Engine-Stand MINUS noch nicht präsentierte Melde-Gewinne.
    func displayedStack(of seat: Int) -> Int {
        let stack = stage == .betting
            ? betting.seats[seat].stack + betting.seats[seat].committed
            : round.stacks[seat]
        return stack - meldEvents.dropFirst(meldShown)
            .filter { $0.player == seat }
            .reduce(0) { $0 + $1.chips }
    }

    func runDealPresentation(reduceMotion: Bool) {
        dealTask?.cancel()
        dealtCount = 0
        trumpRevealed = false
        meldShown = 0
        pulsingPool = nil
        guard !reduceMotion else {
            // Safe-Mode (§6 Auflage 2): keine Flüge, sanfter Dissolve statt Puls -
            // Belohnung wandert in Haptik (ein einzelner Tick).
            dealtCount = totalDeals
            trumpRevealed = true
            meldShown = meldEvents.count
            hapticTick += 1
            return
        }
        dealTask = Task { await dealLoop() }
    }

    /// Tap überspringt sofort (§6a b): Kaskade bricht ab, Meldungen saugen sich
    /// in Lichtgeschwindigkeit zu den Gewinnern.
    func skipDeal() {
        guard dealtCount < totalDeals || !trumpRevealed || meldShown < meldEvents.count
        else { return }
        dealTask?.cancel()
        dealtCount = totalDeals
        if !trumpRevealed {
            trumpRevealed = true
            lightPulse += 1
        }
        meldShown = meldEvents.count
        pulsingPool = nil
        hapticTick += 1
    }

    private func dealLoop() async {
        let total = totalDeals
        let haptics = Task { [weak self] in
            while let self, !Task.isCancelled, self.dealtCount < total {
                self.hapticTick += 1
                try? await Task.sleep(for: .seconds(Tokens.hapticCadence))
            }
        }
        while dealtCount < total, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Tokens.p1DealStep))
            guard !Task.isCancelled else { break }
            dealtCount += 1
        }
        haptics.cancel()
        guard !Task.isCancelled else { return }
        // Der Beat: Spiel friert ein, dann Trumpf-Flip + radialer Puls (§6a)
        try? await Task.sleep(for: .seconds(Tokens.p1TrumpFreeze))
        guard !Task.isCancelled else { return }
        trumpRevealed = true
        lightPulse += 1
        hapticTick += 1

        // Melde-Strom (§6a b): rhythmisch reihum, Mulde pulst, Münzen fliegen
        try? await Task.sleep(for: .seconds(0.35))
        while meldShown < meldEvents.count, !Task.isCancelled {
            let meld = meldEvents[meldShown]
            pulsingPool = meld.pool
            hapticTick += 1
            // Stufe 2: der Balatro-Kollaps zündet nur beim fetten Pott (Rarity-Lock)
            if meld.chips >= effectiveKollapsThreshold {
                kollapsInfo = (meld.pool, meld.chips, meld.player)
                kollapsShock += 1
            }
            try? await Task.sleep(for: .seconds(Tokens.p1MeldStep))
            guard !Task.isCancelled else { break }
            meldShown += 1
        }
        pulsingPool = nil
    }
}
