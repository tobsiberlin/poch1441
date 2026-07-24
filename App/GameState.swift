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

struct PochShowdownSummary: Equatable {
    let winner: Int
    let winningCombo: Combo
    let runnerUp: Int?
    let runnerUpCombo: Combo?
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
    #if DEBUG || INTERNAL_QA
    private var debugBoardPresentation: [Pool: Int] = [:]
    #endif
    /// Letzter sichtbarer Auftritt pro Sitz (Action-Bubble in Phase 2).
    private(set) var seatActions: [SeatAction]

    /// Präsentations-RNG der Bots (Denkpausen, Entscheidungen). Unabhängig vom Runden-Seed,
    /// damit Replays der Regel-Ebene stabil bleiben.
    private var botRNG = SeededRNG(seed: 0xC0FFEE)
    private var botTask: Task<Void, Never>?
    private let log = Logger(subsystem: "com.tobc.poch1441", category: "GameState")

    private(set) var opponentNames: [String]
    private let botProfiles: [String: BotProfile]
    private let opponentCatalog: OpponentRosterCatalog?
    private var tutorialOpponentLineup: OpponentLineup?
    private var opponentTendencySession = OpponentTendencyDisclosureSession()
    private(set) var opponentTendencyDisclosure: PublicOpponentTendencyDisclosure?

    init(source: MatchSource = BotMatchSource()) {
        let opponentCatalog = Self.loadOpponentRosterCatalog()
        self.source = source
        self.round = source.round
        self.seatActions = Array(repeating: .none, count: source.tablePlayerCount)
        self.completedMatchResult = nil
        self.botProfiles = Self.loadBotProfiles()
        self.opponentCatalog = opponentCatalog
        self.opponentNames = OpponentRoster.draw(
            opponentCount: max(0, source.tablePlayerCount - 1),
            excluding: []
        )
    }

    // MARK: - Gemeinsame Werte

    func chips(in pool: Pool) -> Int {
        #if DEBUG || INTERNAL_QA
        if let value = debugBoardPresentation[pool] { return value }
        #endif
        return round.board[pool]
    }
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
    var tutorialOpponentNames: [String] {
        guard let lineup = try? opponentCatalog?.curatedTutorialLineup() else { return [] }
        return lineup.seats.map(\.opponent.displayName)
    }

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

    /// Opens the optional opponent-reading beat only after the guided UI has observed a
    /// completed, public Poch decision. The lookup uses the curated public lineup rather
    /// than bot parameters or round-private state.
    func markFirstPochDecisionUnderstood(by uiSeat: Int) {
        guard uiSeat > 0,
              let tutorialOpponentLineup,
              let opponent = tutorialOpponentLineup.seats.first(where: {
                  $0.uiSeatIndex == uiSeat
              })?.opponent,
              let disclosure = opponentTendencySession
                  .discloseAfterUnderstandingFirstPochDecision(
                      madeBy: opponent.id,
                      in: tutorialOpponentLineup
                  ) else {
            return
        }
        opponentTendencyDisclosure = disclosure
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

    private static func loadOpponentRosterCatalog() -> OpponentRosterCatalog? {
        guard let url = Bundle.main.url(forResource: "BotProfiles", withExtension: "json") else {
            profileLog.error("BotProfiles.json fehlt im App-Bundle")
            return nil
        }
        do {
            return try OpponentRosterCatalog(data: Data(contentsOf: url))
        } catch {
            profileLog.error("Gegnerkatalog unlesbar: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    @discardableResult
    func newRound() -> Bool {
        guard stage == .finished else { return false }
        botTask?.cancel()
        cascadeTask?.cancel()
        dealTask?.cancel()
        guard source.advanceRound(completedRound: round,
                                  seed: UInt64.random(in: 1...999_999)) else {
            completedMatchResult = source.matchResult
            return false
        }
        round = source.round
        resetOpponentTendencyPresentation()
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
        resetOpponentTendencyPresentation()
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
        resetOpponentTendencyPresentation()
        completedMatchResult = nil
        resetPresentationState()
    }

    /// Startet eine reproduzierbare, regelkonforme Lernszene. Die Seeds liegen als
    /// Build-Time-Daten vor; die Engine bleibt für alle Karten und Ergebnisse die Wahrheit.
    func startTutorialRound(_ lesson: TutorialLesson = .meld) -> Bool {
        resetOpponentTendencyPresentation()
        guard applyCuratedTutorialLineup() else { return false }
        adoptRound(seed: tutorialSeed(for: lesson))
        if lesson == .playout {
            advanceTutorialToPlayout()
        }
        return true
    }

    private func applyCuratedTutorialLineup() -> Bool {
        guard let opponentCatalog else {
            Self.profileLog.error("Tutorialbesetzung ist nicht verfügbar")
            return false
        }
        do {
            let lineup = try opponentCatalog.curatedTutorialLineup()
            tutorialOpponentLineup = lineup
            opponentNames = lineup.seats
                .sorted { $0.uiSeatIndex < $1.uiSeatIndex }
                .map(\.opponent.displayName)
            return true
        } catch {
            Self.profileLog.error("Tutorialbesetzung konnte nicht geladen werden: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func resetOpponentTendencyPresentation() {
        tutorialOpponentLineup = nil
        opponentTendencySession = OpponentTendencyDisclosureSession()
        opponentTendencyDisclosure = nil
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
        resetMeldPresentation()
        playPresentationGeneration += 1
        revealedPlays = 0
        landedPlays = 0
        guidedPlayoutPresentation = false
        betTransfer = 0
        lastBetActor = nil
        lastBetAmount = 0
        lastBetKind = .call
        endPhase = .none
    }

    private func tutorialSeed(for lesson: TutorialLesson) -> UInt64 {
        #if DEBUG || INTERNAL_QA
        if lesson == .playout,
           let override = ProcessInfo.processInfo.arguments.first(where: {
               $0.hasPrefix("-guidedPlayoutSeedQA=")
           }),
           let seed = UInt64(override.split(separator: "=").last ?? "") {
            return seed
        }
        #endif
        let fallback: [TutorialLesson: UInt64] = [
            .meld: playerCount == 3 ? 1_444 : 20,
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

    /// Erst nach dem öffentlichen Showdown verfügbar. Vorher bleiben alle gegnerischen
    /// Karten hinter der GameState-Grenze verborgen.
    var pochShowdownSummary: PochShowdownSummary? {
        guard let result = pochResult, result.byShowdown else { return nil }
        guard let showdownPlayers = round.events.compactMap({ event -> [Int]? in
            guard case .bettingEnded(.showdown(let players)) = event else { return nil }
            return players
        }).last else { return nil }

        let ranked = showdownPlayers.compactMap { roundSeat -> (Int, Combo)? in
            guard round.deal.hands.indices.contains(roundSeat),
                  let combo = ComboEvaluator.best(in: round.deal.hands[roundSeat], trump: trump)
            else { return nil }
            return (uiSeat(forRoundSeat: roundSeat), combo)
        }.sorted { lhs, rhs in
            lhs.1.beats(rhs.1)
        }
        guard let winner = ranked.first(where: { $0.0 == result.winner }) else { return nil }
        let runnerUp = ranked.first(where: { $0.0 != result.winner })
        return PochShowdownSummary(
            winner: winner.0,
            winningCombo: winner.1,
            runnerUp: runnerUp?.0,
            runnerUpCombo: runnerUp?.1
        )
    }

    // MARK: - Phase 2 - Aktionen

    func humanPass() { applyHuman(.pass) }
    func humanOpen(_ amount: Int) { applyHuman(.open(amount)) }
    func humanCall() { applyHuman(.call) }
    func humanRaise(to amount: Int) { applyHuman(.raise(to: amount)) }

    /// Phase-2-Einstieg ist idempotent. Nach Geberrotation kann der erste
    /// Rundensitz einem Bot gehören; dann darf die Bietrunde nicht auf einen
    /// menschlichen Impuls warten.
    func resumeBettingIfNeeded() {
        runBotsIfNeeded()
    }

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
            guard let observation = round.botObservation(for: seat) else { return }
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

    var humanCombo: Combo? {
        ComboEvaluator.best(in: humanHand, trump: trump)
    }

    var humanComboRank: Rank? { humanCombo?.rank }

    // MARK: - Phase 3 (Ausspielen) - Kaskaden-Präsentation (§6c)

    /// Die Engine löst Zwangsketten instant - die UI enthüllt die Plays im 180-ms-Takt
    /// (Parameter-Lock), mit 350-ms-Beat-Drop am Kettenriss. `revealedPlays` ist der
    /// Präsentations-Zeiger in den Play-Strom.
    private(set) var playPresentationGeneration = 0
    private(set) var revealedPlays = 0
    private(set) var landedPlays = 0
    private(set) var guidedPlayoutPresentation = false
    private var cascadeTask: Task<Void, Never>?

    var hasPlayout: Bool { round.playout != nil }
    var resolvedPlayCount: Int { round.playout?.plays.count ?? 0 }
    /// Ausschließlich bereits präsentierte öffentliche Kartenereignisse. Zukünftige
    /// Zwangskarten und die verbliebenen Gegnerhände bleiben hinter GameState.
    var revealedPlayEvents: [PlayoutPhase.Play] {
        guard let phase = round.playout else { return [] }
        return Array(phase.plays.prefix(revealedPlays))
    }
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

    /// Die erste Lernreihe bleibt eine echte Engine-Reihe. Wir wählen lediglich ein
    /// didaktisch ergiebiges legales Anspiel: drei bis fünf sichtbare Karten, der Mensch
    /// legt die letzte mögliche Karte und behält danach mindestens zwei freie Anspiele.
    var guidedRecommendedOpeningCard: Card? {
        guard guidedPlayoutPresentation,
              revealedPlays == 0,
              let phase = round.playout,
              let humanRoundSeat,
              phase.leader == humanRoundSeat else { return nil }

        return phase.hands[humanRoundSeat]
            .compactMap { card -> (card: Card, playCount: Int)? in
                var candidate = phase
                guard (try? candidate.lead(card)) != nil,
                      candidate.winner == nil,
                      (3...5).contains(candidate.plays.count),
                      candidate.plays.last?.player == humanRoundSeat,
                      candidate.hands[humanRoundSeat].count >= 2
                else { return nil }
                return (card, candidate.plays.count)
            }
            .sorted { lhs, rhs in
                let lhsDistance = abs(lhs.playCount - 4)
                let rhsDistance = abs(rhs.playCount - 4)
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                return lhs.card.rank < rhs.card.rank
            }
            .first?.card
    }

    /// Während einer geführten Reihe bleibt eine eigene Zwangskarte in der Hand sichtbar,
    /// bis sie wirklich angetippt wurde. Fremde verdeckte Karten werden nicht vorab geleakt.
    var guidedRequiredHumanFollowCard: Card? {
        guard guidedPlayoutPresentation,
              let phase = round.playout,
              phase.plays.indices.contains(revealedPlays),
              let humanRoundSeat else { return nil }
        let next = phase.plays[revealedPlays]
        guard !next.isLead, next.player == humanRoundSeat else { return nil }
        return next.card
    }

    var guidedPlayoutCanAdvance: Bool {
        guard guidedPlayoutPresentation,
              let phase = round.playout,
              landedPlays == revealedPlays else { return false }
        if phase.plays.indices.contains(revealedPlays) {
            return phase.plays[revealedPlays].player != humanRoundSeat
        }
        return stage == .playout && cascadeIdle && phase.leader != humanRoundSeat
    }

    func canHumanPlay(_ card: Card, guided: Bool) -> Bool {
        guard let phase = round.playout,
              let humanRoundSeat else { return false }
        if guided, guidedPlayoutPresentation {
            guard landedPlays == revealedPlays else { return false }
            if let required = guidedRequiredHumanFollowCard {
                return card == required
            }
            guard stage == .playout else { return false }
            guard cascadeIdle, phase.leader == humanRoundSeat else { return false }
            if revealedPlays == 0, let opening = guidedRecommendedOpeningCard {
                return card == opening
            }
            return phase.hands[humanRoundSeat].contains(card)
        }
        return cascadeIdle
            && phase.leader == humanRoundSeat
            && phase.hands[humanRoundSeat].contains(card)
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

    /// Die eigene sichtbare Hand darf als Kartenliste an die View. Gegner werden
    /// ausschließlich über `displayedCardCount(of:)` beschrieben.
    var displayedHumanHand: [Card] { displayedCards(of: 0) }

    func displayedCardCount(of seat: Int) -> Int {
        displayedCards(of: seat).count
    }

    /// Deal minus enthüllte Plays, nicht der Engine-Stand, der der Präsentation
    /// vorausläuft. Bleibt privat, damit keine View eine Gegnerhand erhalten kann.
    private func displayedCards(of seat: Int) -> [Card] {
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

    func configureGuidedPlayoutPresentation(_ enabled: Bool) {
        guidedPlayoutPresentation = enabled
        cascadeTask?.cancel()
        if !enabled {
            runCascadeIfNeeded()
        }
    }

    /// Anspiel des Menschen - nur wenn er führt und die Kaskade eingeholt ist.
    private func startPlayPresentation() {
        guard let phase = round.playout,
              phase.plays.indices.contains(revealedPlays) else { return }
        let sequence = revealedPlays + 1
        let play = phase.plays[revealedPlays]
        let eventID = playEventID(
            sequence: sequence,
            generation: playPresentationGeneration
        )
        presentation.begin(id: eventID,
                           kind: .playedCard,
                           source: "seat-\(uiSeat(forRoundSeat: play.player))",
                           target: "table-chain")
        revealedPlays = sequence
    }

    @discardableResult
    func markPlayLanded(sequence: Int, generation: Int) -> Bool {
        guard generation == playPresentationGeneration,
              sequence == landedPlays + 1,
              presentation.impact(id: playEventID(
                sequence: sequence,
                generation: generation
              )) else { return false }
        landedPlays = sequence
        hapticTick += 1
        presentation.complete(id: playEventID(
            sequence: sequence,
            generation: generation
        ))
        return true
    }

    /// Reduced Motion settles the currently visible card at contact and then
    /// invalidates every completion captured by the spatial flight it replaces.
    func settlePlayPresentationForReducedMotion(sequence: Int, generation: Int) {
        guard generation == playPresentationGeneration else { return }
        _ = markPlayLanded(sequence: sequence, generation: generation)
        playPresentationGeneration += 1
    }

    private func playEventID(sequence: Int, generation: Int) -> String {
        "play-\(generation)-\(sequence)"
    }

    func humanLead(_ card: Card, guided: Bool = false) {
        if guided {
            guidedPlayoutPresentation = true
            cascadeTask?.cancel()
        }
        guard canHumanPlay(card, guided: guided) else { return }

        if guided, guidedRequiredHumanFollowCard == card {
            startPlayPresentation()
            finishGuidedPlayoutIfNeeded()
            return
        }

        guard stage == .playout, let phase = round.playout, let humanRoundSeat,
              phase.leader == humanRoundSeat, cascadeIdle else { return }
        do {
            try round.applyLead(card)
            startPlayPresentation()
            if guided {
                finishGuidedPlayoutIfNeeded()
            } else {
                runCascadeIfNeeded()
            }
        } catch {
            log.error("Illegales Anspiel: \(String(describing: error))")
        }
    }

    /// Bestätigung für den nächsten automatisch vorgeschriebenen Gegnerzug oder ein
    /// gegnerisches Anspiel. Genau eine Karte wird öffentlich - danach wartet die Lernreise.
    func advanceGuidedPlayoutPresentation() {
        guard guidedPlayoutCanAdvance,
              let phase = round.playout else { return }
        cascadeTask?.cancel()

        if phase.plays.indices.contains(revealedPlays) {
            startPlayPresentation()
            finishGuidedPlayoutIfNeeded()
            return
        }

        guard stage == .playout else { return }
        let leaderUISeat = uiSeat(forRoundSeat: phase.leader)
        guard let observation = phase.botObservation(for: phase.leader),
              let card = BotBrain.lead(observation: observation) else { return }
        do {
            try round.applyLead(card)
            seatActions[leaderUISeat] = .none
            startPlayPresentation()
            finishGuidedPlayoutIfNeeded()
        } catch {
            log.error("Illegales geführtes Bot-Anspiel: \(String(describing: error))")
        }
    }

    private func finishGuidedPlayoutIfNeeded() {
        guard guidedPlayoutPresentation,
              stage != .playout,
              cascadeIdle,
              endPhase == .none else { return }
        cascadeTask?.cancel()
        cascadeTask = Task { await runEndSequence() }
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
                      let observation = current.botObservation(for: current.leader),
                      let card = BotBrain.lead(observation: observation)
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

    #if DEBUG || INTERNAL_QA
    /// QA-Helfer (Launch-Arg -ausspielStart): Bietrunde per Alle-passen überspringen,
    /// damit Screenshots direkt in Phase 3 starten. Nur DEBUG, nie Release (§6).
    func debugSkipToPlayout() {
        while stage == .betting {
            do { try round.applyBet(.pass, by: betting.turn) } catch { return }
        }
    }

    /// QA-Helfer für die physische Poch-Auszahlung. Die Runde wird ausschließlich
    /// mit legalen Engine-Aktionen beendet: Der erste bietberechtigte Sitz eröffnet,
    /// weitere Berechtigte gehen mit, alle anderen passen.
    func debugResolvePochPayout() {
        var guardCount = 0
        while stage == .betting, guardCount < 40 {
            guardCount += 1
            let seat = betting.turn
            guard let legal = betting.legalActions(for: seat) else { return }
            let action: BettingPhase.Action
            if let openRange = legal.openRange {
                action = .open(min(2, openRange.upperBound))
            } else if legal.canCall {
                action = .call
            } else {
                action = .pass
            }
            do {
                let committedBefore = betting.seats[seat].committed
                try round.applyBet(action, by: seat)
                let uiSeat = uiSeat(forRoundSeat: seat)
                seatActions[uiSeat] = Self.display(action)
                registerTransfer(actor: uiSeat,
                                 amount: betting.seats[seat].committed - committedBefore,
                                 action: action)
            } catch {
                log.error("Poch-Auszahlungs-QA konnte die Bietrunde nicht beenden: \(String(describing: error), privacy: .public)")
                return
            }
        }
    }

    /// QA-only öffentlicher Boardzustand für die visuelle Kapazitätsgrenze.
    /// Der produktive MatchSource und die Regelpfade bleiben unverändert.
    func debugPrimeSaturatedPile() {
        debugBoardPresentation[.sequence] = R1TokenSlots.capacity + 1
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
    private(set) var r1ImpactTick = 0
    private(set) var r1ImpactGroupSize = 1
    private(set) var r1ImpactSurface: R1ContactSurface = .outerWell
    private var dealTask: Task<Void, Never>?

    func beginGuidedOpeningToken() {
        presentation.begin(id: "first-run-opening-token",
                           kind: .tableToken,
                           source: "player-seat-0",
                           target: "pool-center")
    }

    func beginGuidedTableFunding() {
        presentation.begin(id: "first-run-table-funding",
                           kind: .tableToken,
                           source: "stable-player-seats",
                           target: "all-nine-pools")
    }

    func markGuidedTableFundingLanded(groupSize: Int) {
        beginGuidedTableFunding()
        guard presentation.impact(id: "first-run-table-funding") else { return }
        recordR1Impact(groupSize: groupSize, surface: .outerWell)
        presentation.complete(id: "first-run-table-funding")
    }

    func markGuidedOpeningTokenLanded() {
        beginGuidedOpeningToken()
        guard presentation.impact(id: "first-run-opening-token") else { return }
        recordR1Impact(groupSize: 1, surface: .centerWell)
        presentation.complete(id: "first-run-opening-token")
    }

    private func recordR1Impact(groupSize: Int, surface: R1ContactSurface) {
        r1ImpactGroupSize = max(1, groupSize)
        r1ImpactSurface = surface
        r1ImpactTick += 1
    }

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
    /// Monotone Identität einer Phase-1-Präsentation. Alte SwiftUI-Completions
    /// dürfen nach Rundentausch oder erneutem Tutorialstart keinen neuen Transfer
    /// mit demselben Sequenzindex treffen.
    private(set) var meldPresentationGeneration = 0
    /// Mulde, die gerade pulst (aktive Meldung).
    private(set) var pulsingPool: Pool?

    /// Anzeige-Wert einer Mulde: Beim Start eines Transfers verlässt der Haufen
    /// die Mulde und wird zum Flugobjekt. Das Gewinnerkonto wächst weiterhin
    /// erst beim Kontakt (`meldShown`), sodass kein Stein doppelt sichtbar ist.
    func displayedChips(in pool: Pool) -> Int {
        #if DEBUG || INTERNAL_QA
        if let value = debugBoardPresentation[pool] { return value }
        #endif
        return round.board[pool] + meldEvents.dropFirst(startedMelds)
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
        resetMeldPresentation()
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
        resetMeldPresentation()
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
            let groupTarget = min(
                totalDeals,
                startedDeals + Tokens.p1GuidedDealConcurrency
            )
            while startedDeals < groupTarget, !Task.isCancelled {
                if !reduceMotion {
                    try? await Task.sleep(for: .seconds(Tokens.p1GuidedDealFinishStep))
                }
                guard !Task.isCancelled else { return }
                startNextDeal()
                if reduceMotion { markDealLanded(startedDeals - 1) }
            }
            await waitForDealsToLand(groupTarget)
        }
    }

    func revealGuidedTrumpf() {
        guard !trumpRevealed else { return }
        trumpRevealed = true
        lightPulse += 1
        hapticTick += 1
    }

    func revealNextGuidedMeld(reduceMotion: Bool) async {
        guard startedMelds < meldEvents.count else { return }
        let generation = meldPresentationGeneration
        let sequence = startNextMeld()
        if reduceMotion {
            markMeldLanded(sequence, generation: generation)
        }
        await waitForMeldToLand(sequence, generation: generation)
    }

    func revealAllGuidedMelds(reduceMotion: Bool) async {
        while startedMelds < meldEvents.count, !Task.isCancelled {
            await revealNextGuidedMeld(reduceMotion: reduceMotion)
            guard !Task.isCancelled, startedMelds < meldEvents.count else { return }
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(180))
            }
        }
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

    /// Settles every still pending Phase-1 presentation atomically. This is the
    /// product path for a live Reduce Motion change and for leaving Phase 1 while
    /// a material transfer is still in flight.
    func settlePhase1Presentation() {
        skipDeal()
    }

    private func dealLoop() async {
        let total = totalDeals
        while startedDeals < total, !Task.isCancelled {
            while startedDeals - landedDeals >= 2, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
            }
            #if DEBUG || INTERNAL_QA
            let cadence = Tokens.p1DealCadence
            let delay = cadence[startedDeals % cadence.count]
            #else
            let delay = Tokens.p1DealStep
            #endif
            try? await Task.sleep(for: .seconds(delay))
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
            let generation = meldPresentationGeneration
            let sequence = startNextMeld()
            await waitForMeldToLand(sequence, generation: generation)
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
        let deadline = ContinuousClock.now.advanced(
            by: .seconds(Tokens.p1GuidedDealRecoveryDeadline)
        )
        while landedDeals < target, !Task.isCancelled {
            if ContinuousClock.now >= deadline {
                let recoveryTarget = min(target, startedDeals)
                for sequence in landedDeals..<recoveryTarget
                where !landedDealIndices.contains(sequence) {
                    markDealLanded(sequence)
                }
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    func markMeldLanded(_ sequence: Int, generation: Int) {
        guard generation == meldPresentationGeneration,
              sequence == meldShown,
              sequence < startedMelds else { return }
        let eventID = meldEventID(sequence, generation: generation)
        guard presentation.impact(id: eventID) else { return }
        meldShown += 1
        pulsingPool = nil
        let groupSize = meldEvents.indices.contains(sequence)
            ? meldEvents[sequence].chips
            : 1
        recordR1Impact(groupSize: groupSize, surface: .playerStack)
        presentation.complete(id: eventID)
    }

    @discardableResult
    private func startNextMeld() -> Int {
        guard startedMelds < meldEvents.count else { return meldEvents.count }
        let sequence = startedMelds
        let meld = meldEvents[sequence]
        presentation.begin(id: meldEventID(sequence,
                                            generation: meldPresentationGeneration),
                           kind: .meldToken,
                           source: "pool-\(meld.pool.rawValue)",
                           target: "seat-\(meld.player)")
        pulsingPool = meld.pool
        startedMelds += 1
        return sequence
    }

    private func meldEventID(_ sequence: Int, generation: Int) -> String {
        "meld-\(generation)-\(round.deal.upcard.rank.rawValue)-\(sequence)"
    }

    private func waitForMeldToLand(_ sequence: Int, generation: Int) async {
        let deadline = ContinuousClock.now.advanced(
            by: .seconds(Tokens.p1GuidedMeldRecoveryDeadline)
        )
        while meldShown <= sequence, !Task.isCancelled {
            if ContinuousClock.now >= deadline {
                markMeldLanded(sequence, generation: generation)
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func resetMeldPresentation() {
        meldPresentationGeneration &+= 1
        startedMelds = 0
        meldShown = 0
        pulsingPool = nil
    }

    #if DEBUG || INTERNAL_QA
    /// Deterministic product presentation for the Phase-1 payout UI tests. The
    /// underlying meld event still comes from the curated PochKit tutorial round.
    func debugStartMeldPayout() {
        dealTask?.cancel()
        startedDeals = totalDeals
        landedDeals = totalDeals
        landedDealIndices.removeAll(keepingCapacity: true)
        trumpRevealed = true
        presentation.setFirstRunBeat(.proveMeld)
    }

    /// Begins one real material transfer without awaiting its contact so the UI
    /// test can exercise a phase handoff while that transfer is visibly active.
    func debugBeginNextMeldPayout() {
        _ = startNextMeld()
    }
    #endif
}
