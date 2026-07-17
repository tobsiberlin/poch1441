import Testing
@testable import PochKit

/// Bot-Profile v1: Die Parameter müssen ECHTES, messbar unterschiedliches Verhalten
/// erzeugen (sonst wären die Charaktere nur Namen) - und dürfen nie das Regelwerk
/// verletzen (nur legale Aktionen, Chip-Erhaltung).
struct BotBrainTests {
    private let zaghaft = BotProfile(openAggression: 0.15, bluffFrequency: 0.03,
                                     riskTolerance: 0.3, raiseAggression: 0.2,
                                     thinkSecondsMin: 0.5, thinkSecondsMax: 1)
    private let draufgaenger = BotProfile(openAggression: 0.9, bluffFrequency: 0.45,
                                          riskTolerance: 0.85, raiseAggression: 0.8,
                                          thinkSecondsMin: 0.3, thinkSecondsMax: 0.6)

    private func observation(round: Round, player: Int) -> BotObservation {
        guard let observation = round.botObservation(for: player) else {
            fatalError("Test fordert Observation für einen nicht handelnden Sitz an")
        }
        return observation
    }

    /// Anforderung: Profile wählen ausschließlich legale Aktionen und die Runden-Invariante
    /// (Gesamtchips konstant) bleibt über komplette Profil-Runden erhalten.
    @Test func profileErzeugenNurLegaleAktionenUndErhaltenChips() throws {
        for seed in UInt64(1)...60 {
            var rng = SeededRNG(seed: seed &* 977)
            var round = Round(stacks: [60, 60, 60, 60], board: Board(), seed: seed)
            let total = round.totalChips
            let profiles = [zaghaft, draufgaenger, .neutral, zaghaft]
            var guardCounter = 0
            while round.stage == .betting, guardCounter < 200 {
                guardCounter += 1
                let player = round.betting.turn
                guard let legal = round.betting.legalActions(for: player) else { break }
                let action = BotBrain.action(profile: profiles[player],
                                             observation: observation(round: round, player: player),
                                             legal: legal, rng: &rng)
                try round.applyBet(action, by: player)
                #expect(round.totalChips == total, "Chip-Erhaltung verletzt (Seed \(seed))")
            }
            #expect(round.stage != .betting, "Bietphase terminiert nicht (Seed \(seed))")
        }
    }

    /// Anforderung: openAggression steuert die Eröffnungsfreude - der Draufgänger pocht
    /// über viele Runden strikt häufiger als der Zaghafte (sonst wäre der Parameter tot).
    @Test func aggressionOeffnetMessbarHaeufiger() {
        var opensDraufgaenger = 0
        var opensZaghaft = 0
        for seed in UInt64(1)...250 {
            let round = Round(stacks: [60, 60, 60], board: Board(), seed: seed)
            let player = round.betting.turn
            guard let legal = round.betting.legalActions(for: player),
                  legal.openRange != nil else { continue }
            var rngA = SeededRNG(seed: seed)
            var rngB = SeededRNG(seed: seed)
            if case .open = BotBrain.action(profile: draufgaenger,
                                            observation: observation(round: round, player: player),
                                            legal: legal, rng: &rngA) {
                opensDraufgaenger += 1
            }
            if case .open = BotBrain.action(profile: zaghaft,
                                            observation: observation(round: round, player: player),
                                            legal: legal, rng: &rngB) {
                opensZaghaft += 1
            }
        }
        #expect(opensDraufgaenger > opensZaghaft + 20,
                "Aggression wirkt nicht: \(opensDraufgaenger) vs \(opensZaghaft)")
    }

    /// Anforderung: bluffFrequency lässt schwache Hände gelegentlich stark auftreten -
    /// messbar als Mitgehen/Erhöhen trotz Handstärke unter 0,4 (der Zaghafte passt dort fast immer).
    @Test func bluffQuoteWirktBeiSchwacherHand() throws {
        var mutigTrotzSchwaeche = 0
        var zaghaftTrotzSchwaeche = 0
        var situationen = 0
        for seed in UInt64(1)...600 {
            // 6 Spieler: kleine Hände, schwache Paare kommen vor (bei 3 Spielern hat
            // jede Hand per Schubfach ein Paar). Teure Eröffnung erzwingen - billige
            // Mitgeh-Kosten kann jedes Profil zahlen und diskriminieren nichts.
            var round = Round(stacks: [60, 60, 60, 60, 60, 60], board: Board(), seed: seed)
            guard round.stage == .betting,
                  let firstLegal = round.betting.legalActions(for: round.betting.turn),
                  let open = firstLegal.openRange else { continue }
            try round.applyBet(.open(min(open.lowerBound + 4, open.upperBound)),
                               by: round.betting.turn)
            guard round.stage == .betting else { continue }
            let player = round.betting.turn
            guard BotBrain.strength(hand: round.deal.hands[player], trump: round.deal.trump) < 0.45,
                  let legal = round.betting.legalActions(for: player), legal.canCall else { continue }
            situationen += 1
            var rngA = SeededRNG(seed: seed)
            var rngB = SeededRNG(seed: seed)
            let currentObservation = observation(round: round, player: player)
            let mutig = BotBrain.action(profile: draufgaenger,
                                        observation: currentObservation,
                                        legal: legal, rng: &rngA)
            let zag = BotBrain.action(profile: zaghaft,
                                      observation: currentObservation,
                                      legal: legal, rng: &rngB)
            if mutig != .pass { mutigTrotzSchwaeche += 1 }
            if zag != .pass { zaghaftTrotzSchwaeche += 1 }
        }
        #expect(situationen > 15, "zu wenige Schwach-Hand-Situationen im Sample")
        #expect(mutigTrotzSchwaeche > zaghaftTrotzSchwaeche,
                "Bluff-Parameter wirkt nicht: \(mutigTrotzSchwaeche) vs \(zaghaftTrotzSchwaeche) bei \(situationen)")
    }

    /// Determinismus-Vertrag (Fundament von Save/Resume): dieselbe Bietrunde mit gleichem
    /// Seed, gleichen Profilen und gleichem RNG-Startwert erzeugt EXAKT dieselbe
    /// Aktionsfolge. Bricht das, weicht der fortgesetzte Spielstand vom verlassenen ab -
    /// genau der App-Bug vom 6.7. (Replay lief auf Cautious-Baseline statt auf dem Profil).
    @Test func bietfolgeIstReproduzierbarBeiGleichemSeed() throws {
        let profiles = [zaghaft, draufgaenger, .neutral, zaghaft]
        func playBetting(seed: UInt64) throws -> [BettingPhase.Action] {
            var rng = SeededRNG(seed: seed &* 31)
            var round = Round(stacks: [60, 60, 60, 60], board: Board(), seed: seed)
            var actions: [BettingPhase.Action] = []
            var guardCounter = 0
            while round.stage == .betting, guardCounter < 200 {
                guardCounter += 1
                let player = round.betting.turn
                guard let legal = round.betting.legalActions(for: player) else { break }
                let action = BotBrain.action(profile: profiles[player],
                                             observation: observation(round: round, player: player),
                                             legal: legal, rng: &rng)
                actions.append(action)
                try round.applyBet(action, by: player)
            }
            return actions
        }
        for seed in UInt64(1)...40 {
            let first = try playBetting(seed: seed)
            let second = try playBetting(seed: seed)
            #expect(first == second, "Bietfolge nicht reproduzierbar (Seed \(seed))")
            #expect(!first.isEmpty, "Leere Bietfolge - Test prüft nichts (Seed \(seed))")
        }
    }

    /// Anforderung: Denkpausen bleiben in der Profil-Spanne (Präsentations-Vertrag für die App).
    @Test func denkpauseBleibtInDerSpanne() {
        var rng = SeededRNG(seed: 7)
        for _ in 0..<100 {
            let seconds = BotBrain.thinkSeconds(profile: draufgaenger, rng: &rng)
            #expect(seconds >= 0.3 && seconds <= 0.6)
        }
    }

    /// Informationsgrenze aus Spec Abschnitt 5/6: Auch die Headless-Baseline erhält nur
    /// eigene Karten und öffentliche Gebotswerte. Bei identischer Observation und gleichem
    /// RNG bleibt die Aktion identisch; eine Fremdhand kann nicht übergeben werden.
    @Test func baselineEntscheidungIstVonFremdhaendenStrukturellGetrennt() {
        var round = Round(stacks: [60, 60, 60], board: Board(), seed: 19)
        let player = round.betting.turn
        guard let openRange = round.betting.legalActions(for: player)?.openRange else {
            Issue.record("Eröffnungsaktion fehlt")
            return
        }
        try? round.applyBet(.open(openRange.lowerBound), by: player)
        let actingPlayer = round.betting.turn
        guard let observation = round.botObservation(for: actingPlayer) else {
            Issue.record("Observation für handelnden Sitz fehlt")
            return
        }
        let fields = Set(Mirror(reflecting: observation).children.compactMap(\.label))
        #expect(fields == ["ownHand", "trump", "currentBet", "ownCommitted"])
        #expect(round.botObservation(for: player) == nil)

        let legal = BettingPhase.LegalActions(
            canPass: true,
            openRange: nil,
            canCall: true,
            raiseRange: 4...12
        )
        var firstRNG = SeededRNG(seed: 1441)
        var secondRNG = SeededRNG(seed: 1441)

        let first = MatchSimulator.baselineAction(
            policy: .cautious,
            observation: observation,
            legal: legal,
            rng: &firstRNG
        )
        let second = MatchSimulator.baselineAction(
            policy: .cautious,
            observation: observation,
            legal: legal,
            rng: &secondRNG
        )

        #expect(first == second)
    }

    /// Die Factory leitet die eigene Hand aus der Runde ab und gilt nur für den
    /// aktuell handelnden Sitz in der laufenden Bietphase.
    @Test func bietObservationIstAnZugUndPhaseGebunden() throws {
        var round = Round(stacks: [60, 60, 60], board: Board(), seed: 1_444)
        let actingPlayer = round.betting.turn
        let observation = try #require(round.botObservation(for: actingPlayer))

        #expect(observation.ownHand == round.deal.hands[actingPlayer])
        #expect(observation.trump == round.deal.trump)
        #expect(observation.currentBet == round.betting.currentBet)
        #expect(observation.ownCommitted == round.betting.seats[actingPlayer].committed)

        let otherPlayer = (actingPlayer + 1) % round.deal.hands.count
        #expect(round.botObservation(for: otherPlayer) == nil)

        while round.stage == .betting {
            try round.applyBet(.pass, by: round.betting.turn)
        }
        #expect(round.botObservation(for: actingPlayer) == nil)
    }

    /// Phase-3-Fairnessgrenze: Die Observation enthält nur legale eigene Karten
    /// und öffentliche Tischwerte. Fremde Resthände sind kein darstellbares Feld.
    @Test func ausspielObservationSchliesstFremdhaendeStrukturellAus() throws {
        let phase = PlayoutPhase(
            hands: [
                [Card(suit: .clubs, rank: .seven)],
                [Card(suit: .hearts, rank: .ace)],
                [Card(suit: .spades, rank: .king)],
            ],
            upcard: Card(suit: .diamonds, rank: .jack),
            firstLeader: 0
        )
        let observation = try #require(phase.botObservation(for: 0))
        let fields = Set(Mirror(reflecting: observation).children.compactMap(\.label))

        #expect(fields == ["legalLeads", "upcard", "playedCards", "remainingCounts"])
        #expect(phase.botObservation(for: 1) == nil)
    }

    /// Zwei Welten mit verschiedenen gegnerischen Karten ergeben bei identischer
    /// öffentlicher Observation exakt dieselbe reine Baseline-Entscheidung.
    @Test func ausspielEntscheidungIstVonFremdhaendenUnabhaengig() throws {
        let ownCards = [
            Card(suit: .hearts, rank: .nine),
            Card(suit: .clubs, rank: .seven),
        ]
        let upcard = Card(suit: .diamonds, rank: .jack)
        let firstWorld = PlayoutPhase(
            hands: [
                ownCards,
                [Card(suit: .spades, rank: .seven)],
                [Card(suit: .diamonds, rank: .seven)],
            ],
            upcard: upcard,
            firstLeader: 0
        )
        let secondWorld = PlayoutPhase(
            hands: [
                ownCards,
                [Card(suit: .spades, rank: .king)],
                [Card(suit: .diamonds, rank: .ace)],
            ],
            upcard: upcard,
            firstLeader: 0
        )

        let firstObservation = try #require(firstWorld.botObservation(for: 0))
        let secondObservation = try #require(secondWorld.botObservation(for: 0))

        #expect(firstObservation == secondObservation)
        #expect(BotBrain.lead(observation: firstObservation)
                == BotBrain.lead(observation: secondObservation))
        #expect(BotBrain.lead(observation: firstObservation)
                == Card(suit: .clubs, rank: .seven))
    }
}
