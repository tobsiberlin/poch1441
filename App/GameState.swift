import Foundation
import Observation
import PochKit
import os

/// Quelle der Spielzustände (§7b Architektur-Seam). v1: lokal via Bots. v2 kann hier eine
/// Netzwerk-Quelle andocken, ohne dass der View-Code eine Zeile ändert.
@MainActor
protocol MatchSource {
    var round: Round { get }
    var tablePlayerCount: Int { get }
    var humanRoundSeat: Int? { get }
    var matchStacks: [Int] { get }
    var roundsPlayed: Int { get }
    var matchResult: Match.MatchResult? { get }
    func tableSeat(forRoundSeat roundSeat: Int) -> Int?
    func roundSeat(forTableSeat tableSeat: Int) -> Int?
    func resetMatch(seed: UInt64)
    @discardableResult
    func advanceRound(completedRound: Round, seed: UInt64) -> Bool
}

/// Lokale Quelle: eine vollständige PochKit-Partie gegen Bots. Tischsitze bleiben
/// stabil, Rundensitze rotieren regelkonform mit dem Geber.
@MainActor
final class BotMatchSource: MatchSource {
    private(set) var round: Round
    private let playerCount: Int
    private var match: Match
    private var tableSeats: [Int]

    init(seed: UInt64 = 1441, playerCount: Int = 4) {
        self.playerCount = playerCount
        var match = Match(playerCount: playerCount,
                          startingStack: 60,
                          mode: .quick(roundLimit: 12),
                          firstDealer: playerCount - 1)
        let started = match.startRound(seed: seed)
        self.match = match
        self.round = started?.round
            ?? Round(stacks: Array(repeating: 60, count: playerCount),
                     board: Board(), seed: seed)
        self.tableSeats = started?.tableSeats ?? Array(0..<playerCount)
    }

    var tablePlayerCount: Int { playerCount }
    var humanRoundSeat: Int? { roundSeat(forTableSeat: 0) }
    var matchStacks: [Int] { match.stacks }
    var roundsPlayed: Int { match.roundsPlayed }
    var matchResult: Match.MatchResult? { match.result }

    func tableSeat(forRoundSeat roundSeat: Int) -> Int? {
        guard tableSeats.indices.contains(roundSeat) else { return nil }
        return tableSeats[roundSeat]
    }

    func roundSeat(forTableSeat tableSeat: Int) -> Int? {
        tableSeats.firstIndex(of: tableSeat)
    }

    func resetMatch(seed: UInt64) {
        var fresh = Match(playerCount: playerCount,
                          startingStack: 60,
                          mode: .quick(roundLimit: 12),
                          firstDealer: playerCount - 1)
        guard let started = fresh.startRound(seed: seed) else { return }
        match = fresh
        round = started.round
        tableSeats = started.tableSeats
    }

    @discardableResult
    func advanceRound(completedRound: Round, seed: UInt64) -> Bool {
        guard completedRound.stage == .finished else { return false }
        match.finishRound(completedRound, tableSeats: tableSeats)
        guard let started = match.startRound(seed: seed) else { return false }
        round = started.round
        tableSeats = started.tableSeats
        return true
    }
}

/// Sichtbarer Auftritt eines Sitzes in der Bietrunde (§6b: Reaktion auf den ÖFFENTLICHEN
/// Zustand - nie auf verdeckte Karten).
enum SeatAction: Equatable {
    case none, thinking, passed, opened(Int), called, raised(Int)
}

enum BetTransferKind: Equatable {
    case call, open, raise

    var isPoch: Bool { self != .call }
}

enum TutorialLesson: String, CaseIterable, Codable, Identifiable {
    case meld
    case bidding
    case playout

    var id: String { rawValue }
}

private struct TutorialScenarioCatalog: Decodable {
    struct Lesson: Decodable {
        let id: TutorialLesson
        let seeds: [String: UInt64]
    }

    let version: Int
    let lessons: [Lesson]
}

private struct BotProfileCatalog: Decodable {
    struct Entry: Decodable {
        let name: String
        let profile: BotProfile
    }

    let version: Int
    let profiles: [Entry]
}

private enum OpponentGender {
    case woman
    case man
}

private struct OpponentIdentity {
    let name: String
    let gender: OpponentGender
}

private enum OpponentRoster {
    static let standard = [
        OpponentIdentity(name: "Liv", gender: .woman),
        OpponentIdentity(name: "Mara", gender: .woman),
        OpponentIdentity(name: "Nina", gender: .woman),
        OpponentIdentity(name: "Thomas", gender: .man),
        OpponentIdentity(name: "Jonas", gender: .man),
        OpponentIdentity(name: "Leon", gender: .man),
        OpponentIdentity(name: "Noah", gender: .man),
        OpponentIdentity(name: "Finn", gender: .man),
    ]

    static let diversity = [
        OpponentIdentity(name: "Hana", gender: .woman),
        OpponentIdentity(name: "Darius", gender: .man),
        OpponentIdentity(name: "Samir", gender: .man),
    ]

    static func draw(opponentCount: Int, excluding previous: [String]) -> [String] {
        guard opponentCount > 0 else { return [] }
        var fallback: [String] = []
        for _ in 0..<12 {
            guard let featured = diversity.randomElement() else { return [] }
            let targetMen = opponentCount.isMultiple(of: 2)
                ? opponentCount / 2
                : (opponentCount + 1) / 2
            let featuredMen = featured.gender == .man ? 1 : 0
            let menNeeded = max(0, targetMen - featuredMen)
            let womenNeeded = max(0, opponentCount - 1 - menNeeded)
            let men = standard.filter { $0.gender == .man }.shuffled().prefix(menNeeded)
            let women = standard.filter { $0.gender == .woman }.shuffled().prefix(womenNeeded)
            let roster = ([featured] + Array(men) + Array(women)).map(\.name).shuffled()
            fallback = roster
            if Set(roster) != Set(previous) { return roster }
        }
        return fallback
    }
}

/// View-zugewandter Zustand: rendert nur, was aus der Runde kommt. Fokus jetzt:
/// Melde-Tableau (Phase 1) + Bietrunde (Phase 2) mit Bot-Denkpausen.
@Observable @MainActor
final class GameState {
    private static let profileLog = Logger(subsystem: "com.tobc.poch1441",
                                           category: "BotProfiles")
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

    private(set) var opponentNames: [String]
    private let botProfiles: [String: BotProfile]

    init(source: MatchSource = BotMatchSource()) {
        self.source = source
        self.round = source.round
        self.seatActions = Array(repeating: .none, count: source.tablePlayerCount)
        self.completedMatchResult = nil
        self.botProfiles = Self.loadBotProfiles()
        self.opponentNames = OpponentRoster.draw(
            opponentCount: max(0, source.tablePlayerCount - 1),
            excluding: []
        )
    }

    // MARK: - Gemeinsame Werte

    func chips(in pool: Pool) -> Int { round.board[pool] }
    var trump: Suit { round.deal.trump }
    var upcard: Card { round.deal.upcard }
    /// Menschen-Hand. UI-Sitz 0 bleibt der Mensch; sein Rundensitz rotiert mit dem Geber.
    var humanHand: [Card] {
        guard let seat = humanRoundSeat, round.deal.hands.indices.contains(seat) else { return [] }
        return round.deal.hands[seat]
    }
    /// Chip-Konten der Gegner in stabiler UI-Sitzreihenfolge.
    var opponentStacks: [Int] { (1..<playerCount).map(displayedStack) }
    var stage: Round.Stage { round.stage }
    var playerCount: Int { source.tablePlayerCount }
    var activeUISeats: [Int] {
        round.deal.hands.indices.compactMap(source.tableSeat(forRoundSeat:))
    }
    var humanRoundSeat: Int? { source.humanRoundSeat }
    var roundsPlayed: Int { source.roundsPlayed }
    var matchStacks: [Int] { source.matchStacks }
    private(set) var completedMatchResult: Match.MatchResult?
    var matchResult: Match.MatchResult? { completedMatchResult ?? source.matchResult }

    func uiSeat(forRoundSeat roundSeat: Int) -> Int {
        source.tableSeat(forRoundSeat: roundSeat) ?? roundSeat
    }

    func roundSeat(forUISeat uiSeat: Int) -> Int? {
        source.roundSeat(forTableSeat: uiSeat)
    }

    func name(of seat: Int) -> String {
        guard seat > 0, !opponentNames.isEmpty else { return "Du" }
        return opponentNames[(seat - 1) % opponentNames.count]
    }

    private func botProfile(for uiSeat: Int) -> BotProfile {
        botProfiles[name(of: uiSeat)] ?? .neutral
    }

    private static func loadBotProfiles() -> [String: BotProfile] {
        guard let url = Bundle.main.url(forResource: "BotProfiles", withExtension: "json") else {
            profileLog.error("BotProfiles.json fehlt im App-Bundle")
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(BotProfileCatalog.self, from: data)
            guard catalog.version == 1 else {
                profileLog.error("Nicht unterstützte BotProfiles-Version: \(catalog.version)")
                return [:]
            }
            return Dictionary(uniqueKeysWithValues: catalog.profiles.map { ($0.name, $0.profile) })
        } catch {
            profileLog.error("BotProfiles unlesbar: \(String(describing: error), privacy: .public)")
            return [:]
        }
    }

    @discardableResult
    func newRound() -> Bool {
        botTask?.cancel()
        cascadeTask?.cancel()
        dealTask?.cancel()
        guard source.advanceRound(completedRound: round,
                                  seed: UInt64.random(in: 1...999_999)) else {
            completedMatchResult = source.matchResult
            return false
        }
        round = source.round
        resetPresentationState()
        return true
    }

    func restartMatch() {
        botTask?.cancel()
        cascadeTask?.cancel()
        dealTask?.cancel()
        source = BotMatchSource(seed: UInt64.random(in: 1...999_999), playerCount: playerCount)
        round = source.round
        opponentNames = OpponentRoster.draw(
            opponentCount: max(0, playerCount - 1),
            excluding: opponentNames
        )
        completedMatchResult = nil
        resetPresentationState()
    }

    func configurePlayerCount(_ count: Int) {
        let safeCount = min(max(count, 3), 6)
        guard safeCount != playerCount else { return }
        botTask?.cancel()
        cascadeTask?.cancel()
        dealTask?.cancel()
        source = BotMatchSource(seed: UInt64.random(in: 1...999_999), playerCount: safeCount)
        round = source.round
        opponentNames = OpponentRoster.draw(
            opponentCount: max(0, safeCount - 1),
            excluding: opponentNames
        )
        completedMatchResult = nil
        resetPresentationState()
    }

    /// Startet eine reproduzierbare, regelkonforme Lernszene. Die Seeds liegen als
    /// Build-Time-Daten vor; die Engine bleibt für alle Karten und Ergebnisse die Wahrheit.
    func startTutorialRound(_ lesson: TutorialLesson = .meld) {
        adoptRound(seed: tutorialSeed(for: lesson))
        if lesson == .playout {
            advanceTutorialToPlayout()
        }
    }

    private func adoptRound(seed: UInt64) {
        botTask?.cancel()
        cascadeTask?.cancel()
        dealTask?.cancel()
        source.resetMatch(seed: seed)
        round = source.round
        completedMatchResult = nil
        resetPresentationState()
    }

    private func resetPresentationState() {
        seatActions = Array(repeating: .none, count: playerCount)
        startedDeals = 0
        landedDeals = 0
        landedDealIndices.removeAll(keepingCapacity: true)
        presentation.reset()
        trumpRevealed = false
        lightPulse = 0
        startedMelds = 0
        meldShown = 0
        pulsingPool = nil
        revealedPlays = 0
        landedPlays = 0
        betTransfer = 0
        lastBetActor = nil
        lastBetAmount = 0
        lastBetKind = .call
        endPhase = .none
    }

    private func tutorialSeed(for lesson: TutorialLesson) -> UInt64 {
        let fallback: [TutorialLesson: UInt64] = [
            .meld: playerCount == 3 ? 1_444 : 1_442,
            .bidding: playerCount == 3 ? 1_441 : 7,
            .playout: 1_441
        ]
        guard let url = Bundle.main.url(forResource: "TutorialScenarios", withExtension: "json") else {
            log.error("TutorialScenarios.json fehlt im App-Bundle")
            return fallback[lesson] ?? 1_441
        }
        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(TutorialScenarioCatalog.self, from: data)
            guard catalog.version == 1,
                  let config = catalog.lessons.first(where: { $0.id == lesson }),
                  let seed = config.seeds[String(playerCount)]
            else {
                log.error("Keine Tutorial-Konfiguration für \(lesson.rawValue, privacy: .public) mit \(self.playerCount) Spielern")
                return fallback[lesson] ?? 1_441
            }
            return seed
        } catch {
            log.error("Tutorial-Konfiguration unlesbar: \(String(describing: error), privacy: .public)")
            return fallback[lesson] ?? 1_441
        }
    }

    private func advanceTutorialToPlayout() {
        while stage == .betting {
            do {
                try round.applyBet(.pass, by: betting.turn)
            } catch {
                log.error("Tutorial-Ausspielen konnte Pochen nicht regelkonform überspringen: \(String(describing: error), privacy: .public)")
                return
            }
        }
    }

    // MARK: - Phase 2 (Pochen) - Zustand

    var betting: BettingPhase { round.betting }
    /// Alle gesetzten Chips der laufenden Bietrunde (der violette Pott wächst sichtbar, §6b).
    var pot: Int { betting.seats.map(\.committed).reduce(0, +) }
    /// Stehende Poch-Mulde - geht zusätzlich an den Sieger.
    var pochPool: Int { round.board[.poch] }
    var turnIndex: Int { uiSeat(forRoundSeat: betting.turn) }
    var humanLegal: BettingPhase.LegalActions? {
        guard let seat = humanRoundSeat else { return nil }
        return betting.legalActions(for: seat)
    }
    var humanCommitted: Int {
        guard let seat = humanRoundSeat, betting.seats.indices.contains(seat) else { return 0 }
        return betting.seats[seat].committed
    }

    func bettingSeat(of uiSeat: Int) -> BettingPhase.Seat? {
        guard let seat = roundSeat(forUISeat: uiSeat), betting.seats.indices.contains(seat) else {
            return nil
        }
        return betting.seats[seat]
    }

    /// Wand-Besitzer (§6b): der knappste noch bietberechtigte Spieler deckelt jedes Gebot.
    /// Bietberechtigt = aktiv + Paar + Chips im Spiel (Spiegel der Engine-Regel).
    var capHolder: Int? {
        let eligible = betting.seats.indices.filter {
            let s = betting.seats[$0]
            return s.isActive && s.mayBid && s.stack + s.committed > 0
        }
        let roundSeat = eligible.min { a, b in
            betting.seats[a].stack + betting.seats[a].committed
                < betting.seats[b].stack + betting.seats[b].committed
        }
        return roundSeat.map(uiSeat(forRoundSeat:))
    }

    /// Ausgang der Bietrunde für das Ergebnis-Banner (nil solange offen).
    var pochResult: (winner: Int, pot: Int, pochPool: Int, byShowdown: Bool)? {
        for event in round.events {
            if case .pochWon(let player, let pot, let pool, let showdown) = event {
                return (uiSeat(forRoundSeat: player), pot, pool, showdown)
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
    private(set) var lastPochActor: Int?
    /// Jeder reale Chiptransfer bekommt einen eigenen Präsentationsimpuls. Calls
    /// bleiben ruhig, Eröffnen/Erhöhen tragen zusätzlich den schweren Poch-Schlag.
    private(set) var betTransfer = 0
    private(set) var lastBetActor: Int?
    private(set) var lastBetAmount = 0
    private(set) var lastBetKind: BetTransferKind = .call

    private func applyHuman(_ action: BettingPhase.Action) {
        guard stage == .betting, let humanRoundSeat, betting.turn == humanRoundSeat else { return }
        do {
            let committedBefore = betting.seats[humanRoundSeat].committed
            try round.applyBet(action, by: humanRoundSeat)
            seatActions[0] = Self.display(action)
            registerTransfer(actor: 0,
                             amount: betting.seats[humanRoundSeat].committed - committedBefore,
                             action: action)
            let transferDelay = max(0, betting.seats[humanRoundSeat].committed - committedBefore) > 0
                ? Tokens.p2PochImpactDelay + 0.24
                : 0.18
            runBotsIfNeeded(after: transferDelay)
        } catch {
            // UI bezieht Grenzen aus legalActions - hier zu landen ist ein Programmierfehler.
            log.error("Illegale Spieler-Aktion: \(String(describing: error))")
        }
    }

    /// Bot-Schleife: variable Denkpausen aus Profil + Rauschen (§6b - Tells zeigen den
    /// Charakter, nie die Hand; BotBrain sieht nur die öffentliche State-API).
    private func runBotsIfNeeded(after delay: Double = 0) {
        botTask?.cancel()
        guard stage == .betting, betting.outcome == nil,
              betting.turn != humanRoundSeat else { return }
        botTask = Task {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled, stage == .betting,
                  betting.outcome == nil, betting.turn != humanRoundSeat else { return }
            await botLoop()
        }
    }

    private func botLoop() async {
        while !Task.isCancelled, stage == .betting, betting.outcome == nil,
              betting.turn != humanRoundSeat {
            let seat = betting.turn
            let uiSeat = uiSeat(forRoundSeat: seat)
            seatActions[uiSeat] = .thinking
            let profile = botProfile(for: uiSeat)
            let pause = BotBrain.thinkSeconds(profile: profile, rng: &botRNG)
            try? await Task.sleep(for: .seconds(pause))
            guard !Task.isCancelled, stage == .betting, betting.turn == seat,
                  let legal = betting.legalActions(for: seat) else { return }
            let observation = BotObservation(
                ownHand: round.deal.hands[seat],
                trump: round.deal.trump,
                currentBet: round.betting.currentBet,
                ownCommitted: round.betting.seats[seat].committed
            )
            let action = BotBrain.action(profile: profile,
                                         observation: observation,
                                         legal: legal,
                                         rng: &botRNG)
            do {
                let committedBefore = betting.seats[seat].committed
                try round.applyBet(action, by: seat)
                seatActions[uiSeat] = Self.display(action)
                registerTransfer(actor: uiSeat,
                                 amount: betting.seats[seat].committed - committedBefore,
                                 action: action)
                // Der öffentliche Auftritt muss lesbar landen, bevor der nächste
                // Sitz übernimmt. Das verändert keine Regel, nur die Tischdramaturgie.
                try? await Task.sleep(for: .seconds(Tokens.p2ReactionHold))
            } catch {
                log.error("Illegale Bot-Aktion Sitz \(seat): \(String(describing: error))")
                return
            }
        }
    }

    private func registerTransfer(actor: Int, amount: Int, action: BettingPhase.Action) {
        guard amount > 0 else { return }
        let kind: BetTransferKind
        switch action {
        case .call:
            kind = .call
        case .open:
            kind = .open
        case .raise:
            kind = .raise
        case .pass:
            return
        }

        lastBetActor = actor
        lastBetAmount = amount
        lastBetKind = kind
        betTransfer += 1

        if kind.isPoch {
            lastPochActor = actor
            pochShock += 1
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
    private(set) var landedPlays = 0
    private var cascadeTask: Task<Void, Never>?

    var playout: PlayoutPhase? { round.playout }
    var playoutLeader: Int? {
        round.playout.map { uiSeat(forRoundSeat: $0.leader) }
    }

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
    enum EndPhase: Comparable { case none, finalCard, frozen, punishing, done }
    private(set) var endPhase: EndPhase = .none

    /// Anzeige-Konto am Rundenende: im Freeze noch VOR den Strafzahlungen, ab dem
    /// Straf-Strom rollen die Zähler auf den Endstand.
    func displayedEndStack(of seat: Int) -> Int {
        guard let roundSeat = roundSeat(forUISeat: seat),
              round.stacks.indices.contains(roundSeat) else {
            return source.matchStacks.indices.contains(seat) ? source.matchStacks[seat] : 0
        }
        guard let result = roundResult,
              endPhase == .finalCard || endPhase == .frozen || endPhase == .none else {
            return round.stacks[roundSeat]
        }
        if seat == result.winner {
            return round.stacks[roundSeat] - result.centerPool - result.payments.reduce(0, +)
        }
        return round.stacks[roundSeat] + result.payments[seat]
    }

    /// Sichtbare Hand eines Sitzes: Deal minus enthüllte Plays (nicht Engine-Stand,
    /// der der Präsentation vorausläuft).
    func displayedHand(of seat: Int) -> [Card] {
        guard let roundSeat = roundSeat(forUISeat: seat),
              round.deal.hands.indices.contains(roundSeat) else { return [] }
        guard let phase = round.playout else {
            return round.deal.hands[roundSeat]
        }
        let played = Set(phase.plays.prefix(revealedPlays)
            .filter { $0.player == roundSeat }.map(\.card))
        return round.deal.hands[roundSeat].filter { !played.contains($0) }
    }

    /// Rundenergebnis fürs Banner (nil solange offen).
    var roundResult: (winner: Int, centerPool: Int, payments: [Int])? {
        for event in round.events {
            if case .roundEnded(let winner, let pool, let payments) = event {
                var tablePayments = Array(repeating: 0, count: playerCount)
                for (roundSeat, payment) in payments.enumerated() {
                    let tableSeat = uiSeat(forRoundSeat: roundSeat)
                    if tablePayments.indices.contains(tableSeat) {
                        tablePayments[tableSeat] = payment
                    }
                }
                return (uiSeat(forRoundSeat: winner), pool, tablePayments)
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
            finalPlayer = uiSeat(forRoundSeat: play.player)
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
    private func startPlayPresentation() {
        guard let phase = round.playout,
              phase.plays.indices.contains(revealedPlays) else { return }
        let sequence = revealedPlays + 1
        let play = phase.plays[revealedPlays]
        let eventID = "play-\(sequence)"
        presentation.begin(id: eventID,
                           kind: .playedCard,
                           source: "seat-\(uiSeat(forRoundSeat: play.player))",
                           target: "table-chain")
        revealedPlays = sequence
    }

    func markPlayLanded(sequence: Int) {
        guard sequence > landedPlays,
              presentation.impact(id: "play-\(sequence)") else { return }
        landedPlays = sequence
        hapticTick += 1
        presentation.complete(id: "play-\(sequence)")
    }

    func humanLead(_ card: Card) {
        guard stage == .playout, let phase = round.playout, let humanRoundSeat,
              phase.leader == humanRoundSeat, cascadeIdle else { return }
        do {
            try round.applyLead(card)
            startPlayPresentation()
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
                startPlayPresentation()
                let chainEnded = revealedPlays == phase.plays.count
                    || phase.plays[revealedPlays].isLead
                if chainEnded {
                    // Beat-Drop: Stille, Stopper glüht, Anspielrecht wandert (§6c)
                    try? await Task.sleep(for: .seconds(Tokens.p3BeatDrop))
                }
            } else if stage != .playout {
                await runEndSequence()
                return
            } else if phase.leader != humanRoundSeat {
                // Bot spielt an: kurze Denkpause, dann niedrigste Karte
                // (Platzhalter-Heuristik; echte Anspiel-Taktik kommt mit den Bot-Profilen)
                let leaderUISeat = uiSeat(forRoundSeat: phase.leader)
                let pause = BotBrain.thinkSeconds(profile: botProfile(for: leaderUISeat),
                                                  rng: &botRNG)
                try? await Task.sleep(for: .seconds(pause))
                guard !Task.isCancelled, stage == .playout, cascadeIdle,
                      let current = round.playout, current.leader != humanRoundSeat,
                      let card = current.hands[current.leader]
                          .min(by: { $0.rank.rawValue < $1.rank.rawValue })
                else { continue }
                do {
                    try round.applyLead(card)
                    startPlayPresentation()
                } catch {
                    log.error("Illegales Bot-Anspiel: \(String(describing: error))")
                    return
                }
            } else {
                return  // Mensch führt - warten auf Tap
            }
        }
    }

    /// Finale (§6c c): letzte Karte lesbar halten -> Eiszeit-Vakuum -> paralleler
    /// Straf-Strom mit gedeckelter 90-ms-Tick-Kadenz -> Ergebnis.
    private func runEndSequence() async {
        guard endPhase == .none else { return }
        endPhase = .finalCard
        hapticTick += 1
        try? await Task.sleep(for: .seconds(Tokens.p3FinalCardHold))
        guard !Task.isCancelled else { return }
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
        landedPlays = revealedPlays
        endPhase = .done
    }

    /// QA-Helfer: Rundenende vorbereiten und in der sichtbaren Strafstrom-Phase halten,
    /// damit Centerpot-/Restkarten-Orchestrierung als Screenshot prüfbar ist.
    func debugShowPunishingEnd() {
        debugFinishPlayout()
        endPhase = .punishing
    }

    /// QA-Helfer: spielt die Partie zu Ende und lässt den echten finalen
    /// Präsentationsablauf ab der letzten Karte laufen.
    func debugShowFinalAct() {
        debugFinishPlayout()
        endPhase = .none
        cascadeTask?.cancel()
        cascadeTask = Task { await runEndSequence() }
    }

    /// QA-Helfer: spielt eine komplette Quick-Partie deterministisch bis zur
    /// Matchwertung. Prüft Rundenübertrag, Geberrotation und den Abschluss-Screen,
    /// ohne Release-Code oder Regeln zu umgehen.
    func debugFinishMatch() {
        var roundGuard = 0
        while matchResult == nil, roundGuard < 20 {
            roundGuard += 1
            debugFinishPlayout()
            guard newRound() else { break }
        }
    }
    #endif

    // MARK: - Phase 1: Deal-Präsentation / Trumpf-Beat (§6a)

    /// Engine und sichtbare Präsentation sind getrennt: eine gestartete Flugkarte
    /// wird erst beim Kontakt Teil der sichtbaren Hand.
    private(set) var startedDeals = 0
    private(set) var landedDeals = 0
    private var landedDealIndices: Set<Int> = []
    let presentation = PresentationDirector()
    var dealtCount: Int { landedDeals }
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
                order.append((uiSeat(forRoundSeat: seat), slots[seat]))
                slots[seat] += 1
            }
            seat = (seat + 1) % counts.count
        }
        return order
    }

    /// Sichtbare Handkarten des Menschen - hinkt dem Austeil-Zeiger um die Flugdauer
    /// (~2 Takte) hinterher, damit Karte erst "ankommt", dann erscheint.
    var humanDealtVisible: Int {
        dealOrder.prefix(landedDeals).filter { $0.seat == 0 }.count
    }

    // MARK: - Melde-Strom (§6a b) - Anzeige läuft der Engine hinterher

    /// Melde-Ereignisse der Runde in Engine-Reihenfolge.
    var meldEvents: [(player: Int, pool: Pool, chips: Int)] {
        round.events.compactMap {
            if case .melded(let player, let pool, let chips) = $0 {
                return (uiSeat(forRoundSeat: player), pool, chips)
            }
            return nil
        }
    }

    /// Bereits präsentierte Meldungen (0...meldEvents.count).
    private(set) var meldShown = 0
    /// Gestartete Meldetransfers. Sichtbare Konten folgen weiterhin nur `meldShown`.
    private(set) var startedMelds = 0
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
        guard let roundSeat = roundSeat(forUISeat: seat),
              round.stacks.indices.contains(roundSeat) else {
            return source.matchStacks.indices.contains(seat) ? source.matchStacks[seat] : 0
        }
        let stack = stage == .betting
            ? betting.seats[roundSeat].stack + betting.seats[roundSeat].committed
            : round.stacks[roundSeat]
        return stack - meldEvents.dropFirst(meldShown)
            .filter { $0.player == seat }
            .reduce(0) { $0 + $1.chips }
    }

    func runDealPresentation(reduceMotion: Bool) {
        dealTask?.cancel()
        startedDeals = 0
        landedDeals = 0
        landedDealIndices.removeAll(keepingCapacity: true)
        presentation.reset()
        trumpRevealed = false
        startedMelds = 0
        meldShown = 0
        pulsingPool = nil
        guard !reduceMotion else {
            // Safe-Mode (§6 Auflage 2): keine Flüge, sanfter Dissolve statt Puls -
            // Belohnung wandert in Haptik (ein einzelner Tick).
            startedDeals = totalDeals
            landedDeals = totalDeals
            trumpRevealed = true
            startedMelds = meldEvents.count
            meldShown = meldEvents.count
            hapticTick += 1
            return
        }
        dealTask = Task { await dealLoop() }
    }

    /// Geführte Runde: Präsentation pausiert zwischen den Erkenntnissen. Die
    /// Regelrunde ist bereits deterministisch gegeben; nur ihre Sichtbarkeit wächst.
    func prepareGuidedDeal() {
        dealTask?.cancel()
        startedDeals = 0
        landedDeals = 0
        landedDealIndices.removeAll(keepingCapacity: true)
        presentation.reset()
        trumpRevealed = false
        startedMelds = 0
        meldShown = 0
        pulsingPool = nil
    }

    func revealGuidedDealRound(reduceMotion: Bool) async {
        dealTask?.cancel()
        let target = min(totalDeals, startedDeals + playerCount)
        while startedDeals < target, !Task.isCancelled {
            if !reduceMotion {
                try? await Task.sleep(for: .seconds(Tokens.p1GuidedDealStep))
            }
            guard !Task.isCancelled else { return }
            startNextDeal()
            if reduceMotion { markDealLanded(startedDeals - 1) }
        }
        await waitForDealsToLand(target)
    }

    func finishGuidedDeal(reduceMotion: Bool) async {
        dealTask?.cancel()
        while startedDeals < totalDeals, !Task.isCancelled {
            if !reduceMotion {
                try? await Task.sleep(for: .seconds(Tokens.p1GuidedDealFinishStep))
            }
            guard !Task.isCancelled else { return }
            while startedDeals - landedDeals >= 2, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
            }
            startNextDeal()
            if reduceMotion { markDealLanded(startedDeals - 1) }
        }
        await waitForDealsToLand(totalDeals)
    }

    func revealGuidedTrumpf() {
        guard !trumpRevealed else { return }
        trumpRevealed = true
        lightPulse += 1
        hapticTick += 1
    }

    func revealNextGuidedMeld(reduceMotion: Bool) async {
        guard startedMelds < meldEvents.count else { return }
        let sequence = startNextMeld()
        if reduceMotion { markMeldLanded(sequence) }
        await waitForMeldToLand(sequence)
    }

    /// Tap überspringt sofort (§6a b): Kaskade bricht ab, Meldungen saugen sich
    /// in Lichtgeschwindigkeit zu den Gewinnern.
    func skipDeal() {
        guard landedDeals < totalDeals || !trumpRevealed || meldShown < meldEvents.count
        else { return }
        dealTask?.cancel()
        startedDeals = totalDeals
        landedDeals = totalDeals
        landedDealIndices.removeAll(keepingCapacity: true)
        presentation.cancelAll()
        if !trumpRevealed {
            trumpRevealed = true
            lightPulse += 1
        }
        startedMelds = meldEvents.count
        meldShown = meldEvents.count
        pulsingPool = nil
        hapticTick += 1
    }

    private func dealLoop() async {
        let total = totalDeals
        while startedDeals < total, !Task.isCancelled {
            while startedDeals - landedDeals >= 2, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
            }
            try? await Task.sleep(for: .seconds(Tokens.p1DealStep))
            guard !Task.isCancelled else { break }
            startNextDeal()
        }
        guard !Task.isCancelled else { return }
        await waitForDealsToLand(total)
        guard !Task.isCancelled else { return }
        // Der Beat: Spiel friert ein, dann Trumpf-Flip + radialer Puls (§6a)
        try? await Task.sleep(for: .seconds(Tokens.p1TrumpFreeze))
        guard !Task.isCancelled else { return }
        trumpRevealed = true
        lightPulse += 1
        hapticTick += 1

        // Melde-Strom (§6a b): rhythmisch reihum, Mulde pulst, Münzen fliegen
        try? await Task.sleep(for: .seconds(0.35))
        while startedMelds < meldEvents.count, !Task.isCancelled {
            let sequence = startNextMeld()
            await waitForMeldToLand(sequence)
            guard !Task.isCancelled else { break }
            try? await Task.sleep(for: .milliseconds(280))
        }
        pulsingPool = nil
    }

    func markDealLanded(_ sequence: Int) {
        guard sequence >= 0, sequence < startedDeals else { return }
        let eventID = dealEventID(sequence)
        guard presentation.impact(id: eventID) else { return }
        landedDealIndices.insert(sequence)
        while landedDealIndices.contains(landedDeals) {
            landedDealIndices.remove(landedDeals)
            landedDeals += 1
        }
        hapticTick += 1
        presentation.complete(id: eventID)
    }

    private func startNextDeal() {
        guard startedDeals < totalDeals else { return }
        let sequence = startedDeals
        let entry = dealOrder[sequence]
        presentation.begin(id: dealEventID(sequence),
                           kind: .dealCard,
                           source: "deck",
                           target: "seat-\(entry.seat)-slot-\(entry.slot)")
        startedDeals += 1
    }

    private func dealEventID(_ sequence: Int) -> String {
        "deal-\(round.deal.upcard.rank.rawValue)-\(sequence)"
    }

    private func waitForDealsToLand(_ target: Int) async {
        while landedDeals < target, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    func markMeldLanded(_ sequence: Int) {
        guard sequence == meldShown, sequence < startedMelds else { return }
        let eventID = meldEventID(sequence)
        guard presentation.impact(id: eventID) else { return }
        meldShown += 1
        pulsingPool = nil
        hapticTick += 1
        presentation.complete(id: eventID)
    }

    @discardableResult
    private func startNextMeld() -> Int {
        guard startedMelds < meldEvents.count else { return meldEvents.count }
        let sequence = startedMelds
        let meld = meldEvents[sequence]
        presentation.begin(id: meldEventID(sequence),
                           kind: .meldToken,
                           source: "pool-\(meld.pool.rawValue)",
                           target: "seat-\(meld.player)")
        pulsingPool = meld.pool
        startedMelds += 1
        return sequence
    }

    private func meldEventID(_ sequence: Int) -> String {
        "meld-\(round.deal.upcard.rank.rawValue)-\(sequence)"
    }

    private func waitForMeldToLand(_ sequence: Int) async {
        while meldShown <= sequence, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}
