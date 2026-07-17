import PochKit
import SwiftUI

/// Spieltisch-Container: Phase 1 (Melde-Tableau, Poch-Ring) und Phase 2 (Pochen, §6b).
/// Der echte Phasen-Morph (.matchedGeometryEffect, §5b) folgt, sobald das Phase-3-Layout
/// steht - bis dahin schaltet ein harter Wechsel die Akte um.
struct ContentView: View {
    /// Die drei Akte (§5b) als View-Fortschritt; die Engine steht nach dem Melden
    /// bereits in .betting. Der echte Morph ersetzt später die harten Schnitte.
    private enum Akt: Equatable { case melden, pochen, ausspielen }
    private enum AppOverlay { case menu, tutorial, help, settings }
    private struct GuidedAnteWaveState: Equatable {
        let contributor: Int
        let pools: [Pool]
    }

    @State private var game = GameState()
    /// DEBUG-Launch-Args "-pochenStart"/"-ausspielStart" öffnen Akt 2/3 direkt
    /// (Screenshot-/QA-Läufe ohne Tap).
    @State private var akt: Akt = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ausspielStart") { return .ausspielen }
        if ProcessInfo.processInfo.arguments.contains("-pochenStart") { return .pochen }
        #endif
        return .melden
    }()
    @AppStorage("sound") private var sound = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("assistHints") private var assistHints = true
    @AppStorage("tableEffects") private var tableEffects = true
    @AppStorage("moveCoach") private var moveCoach = true
    @AppStorage("playerCount") private var playerCount = 4
    // Versionierter First-Run-Key: Bestehende TestFlight-Installationen sollen
    // den grundlegend neuen, ruhigen Einstieg genau einmal erneut erleben.
    @AppStorage("didStartFirstTableV2") private var didStartFirstTable = false
    @AppStorage("tutorialProgressMask") private var tutorialProgressMask = 0
    /// Track B bleibt bis zur vollständigen Board-/Materialmigration aus dem
    /// Produktpfad. DEBUG kann beide Welten für Integrationsscreens explizit wählen.
    private var theme: Theme {
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("-tableWorld=")
        }), let value = argument.split(separator: "=").last {
            return TableWorld.resolve(String(value))
        }
        #endif
        return .pochDisc
    }
    @State private var activeOverlay: AppOverlay?
    @State private var phaseCurtain: Akt?
    @State private var guidedRoundActive = false
    @State private var selectedTutorialLesson: TutorialLesson = .meld
    @State private var activeTutorialLesson: TutorialLesson?
    @State private var completedTutorialLesson: TutorialLesson?
    @State private var tutorialMilestoneLesson: TutorialLesson?
    @State private var guidedMeldBusy = false
    @State private var guidedOpeningDrag: CGSize = .zero
    @State private var guidedOpeningSettled = false
    @State private var guidedTableFundingTargeted = false
    @State private var guidedAntePoolCounts: [Pool: Int] = [:]
    @State private var guidedAnteLandedEvents: Set<Int> = []
    @State private var guidedAnteWave: GuidedAnteWaveState?
    @State private var showFirstRunIntro = false
    @State private var matchEndResult: Match.MatchResult?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ScaledMetric(relativeTo: .body) private var guidedActionFontSize: CGFloat = 17
    @AccessibilityFocusState private var guidedCoachFocused: Bool
    /// Phasen-Morph (§5b): ein Namespace über alle drei Akte - Tokens, Poch-Tile und
    /// Mulden fliegen via matchedGeometryEffect an ihre neuen Positionen.
    @Namespace private var morph

    private var guidedMeldBeat: Int {
        game.presentation.firstRunBeat.rawValue
    }

    private var guidedLearningState: DiscLearningState {
        game.presentation.discLearningState
    }

    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-travelTableProbe") {
            TravelTableMaterialProbe()
        } else {
            mainGameView
        }
        #else
        mainGameView
        #endif
    }

    private var mainGameView: some View {
        ZStack {
            // Material-Tiefe: warmes Bühnenlicht hinter dem Ring, Vignette zum Rand (kein Flat-Void).
            RadialGradient(gradient: Gradient(colors: [Tokens.bgLift, Tokens.bgDeep]),
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 6, endRadius: 540)
                .ignoresSafeArea()
            phaseAtmosphere
            VStack(spacing: 0) {
                if isGuidedOpeningBeat {
                    guidedOpeningHeader
                } else {
                    header
                }
                switch akt {
                case .melden:
                    phase1Stage
                case .pochen:
                    Phase2View(game: game, theme: theme, morph: morph,
                               assistHints: assistHints,
                               isGuidedRound: guidedRoundActive,
                               onContinue: {
                                   transition(to: .ausspielen)
                                   game.beginPlayoutPresentation()
                               },
                               onNewRound: startNewRound)
                case .ausspielen:
                    Phase3View(game: game, theme: theme, morph: morph,
                               assistHints: assistHints,
                               isGuidedRound: guidedRoundActive,
                               onNewRound: startNewRound)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            // Phase 1: kein Bottom-Padding - Kartenfächer blendet am Bildschirmrand aus
            .padding(.bottom, akt == .melden ? 0 : 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Trumpf-Beat-Inszenierung liegt als hitTest-freie Schicht über Akt 1
            .overlayPreferenceValue(TablePoolAnchorPreferenceKey.self) { anchors in
                GeometryReader { proxy in
                    if akt == .melden, tableEffects,
                       !guidedRoundActive || guidedMeldBeat > 1 {
                        DealOverlay(
                            game: game,
                            theme: theme,
                            poolPositions: anchors.mapValues { proxy[$0] },
                            showsSeatTargets: !guidedRoundActive
                        )
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if !isGuidedOpeningBeat {
                    utilityButtons
                        .padding(.trailing, 18)
                        .offset(x: -10)
                }
            }
            .overlay { overlayPanel }
            .overlay { tutorialCompletionOverlay }
            .overlay(alignment: .top) { tutorialMilestoneOverlay }
            .overlay {
                if akt == .melden, activeOverlay == nil,
                   !guidedRoundActive && assistHints && moveCoach {
                    guidedCoachPlacement
                }
            }
            .overlay {
                if let phaseCurtain {
                    phaseCurtainView(phaseCurtain)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .overlay {
                if let matchEndResult {
                    matchEndOverlay(matchEndResult)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .zIndex(110)
                }
            }
            .animation(.easeOut(duration: 0.18), value: phaseCurtain)

            if showFirstRunIntro {
                firstRunIntro
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onAppear {
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            let startsGuidedQA = args.contains("-tutorialSeed")
                || args.contains("-tutorialMotionQA")
                || args.contains("-tutorialBidding")
                || args.contains("-tutorialPlayout")
                || args.contains(where: { $0.hasPrefix("-tutorialMeldStep=") })
            if args.contains("-firstRun") {
                showFirstRunIntro = true
            } else if args.dropFirst().isEmpty, !didStartFirstTable {
                showFirstRunIntro = true
            } else if args.dropFirst().isEmpty {
                activeOverlay = .menu
            } else if akt == .melden, !startsGuidedQA {
                game.runDealPresentation(reduceMotion: reduceMotion)
            }
            #else
            if !didStartFirstTable {
                showFirstRunIntro = true
            } else {
                activeOverlay = .menu
            }
            #endif
        }
        .sensoryFeedback(.impact(weight: .light), trigger: haptics ? game.hapticTick : 0)
        .r1ContactFeedback(trigger: game.r1ImpactTick,
                           groupSize: game.r1ImpactGroupSize,
                           surface: game.r1ImpactSurface)
        .onChange(of: game.endPhase) { _, phase in
            guard phase == .done, guidedRoundActive else { return }
            completeTutorialRound()
        }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let playerArgument = args.first(where: { $0.hasPrefix("-players=") }),
               let count = Int(playerArgument.split(separator: "=").last ?? "4") {
                playerCount = min(max(count, 3), 6)
                game.configurePlayerCount(playerCount)
            }
            if args.contains("-pochenStart") {
                transition(to: .pochen)
            }
            if args.contains("-ausspielStart") {
                game.debugSkipToPlayout()
                transition(to: .ausspielen)
                if args.contains("-roundEnd") {
                    game.debugFinishPlayout()
                } else if args.contains("-roundPunishing") {
                    game.debugShowPunishingEnd()
                } else if args.contains("-finalAct") {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(Tokens.aktMorph + 0.18))
                        game.debugShowFinalAct()
                    }
                }
                if !args.contains("-holdPlayout") && !args.contains("-finalAct") {
                    game.beginPlayoutPresentation()
                }
                // -autoLead: niedrigste Karte anspielen (Kaskaden-QA ohne UI-Tap)
                if args.contains("-autoLead"),
                   let card = game.displayedHumanHand
                       .min(by: { $0.rank.rawValue < $1.rank.rawValue }) {
                    game.humanLead(card)
                }
            }
            // -pochDemo: automatisches Eröffnungs-Gebot für die Tischschlag-QA
            if args.contains("-pochDemo") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    if let legal = game.humanLegal, let open = legal.openRange {
                        game.humanOpen(min(3, open.upperBound))
                    }
                }
            }
            // -morphDemo: automatischer Akt-Durchlauf für die Bewegungs-QA (Video ohne Tap)
            if args.contains("-morphDemo") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    transition(to: .pochen)
                    try? await Task.sleep(for: .seconds(3))
                    game.debugSkipToPlayout()
                    transition(to: .ausspielen)
                    if !args.contains("-holdPlayout") {
                        game.beginPlayoutPresentation()
                    }
                }
            }
            if args.contains("-roundEnd"), !args.contains("-ausspielStart") {
                game.debugFinishPlayout()
                transition(to: .ausspielen)
            }
            if args.contains("-roundPunishing"), !args.contains("-ausspielStart") {
                game.debugShowPunishingEnd()
                transition(to: .ausspielen)
            }
            if args.contains("-finalAct"), !args.contains("-ausspielStart") {
                transition(to: .ausspielen)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(Tokens.aktMorph + 0.18))
                    game.debugShowFinalAct()
                }
            }
            if args.contains("-tutorialMotionQA") {
                runGuidedMeldMotionQA()
            } else if let stepArgument = args.first(where: { $0.hasPrefix("-tutorialMeldStep=") }),
               let step = Int(stepArgument.split(separator: "=").last ?? "0") {
                prepareGuidedMeldDebugStep(min(max(step, 0), 7))
            } else if args.contains("-tutorialSeed") {
                startGuidedRound()
            }
            if args.contains("-tutorialBidding") {
                selectedTutorialLesson = .bidding
                startGuidedRound(.bidding)
            }
            if args.contains("-tutorialPlayout") {
                selectedTutorialLesson = .playout
                startGuidedRound(.playout)
            }
            if args.contains("-tutorialComplete") {
                tutorialProgressMask = 0b111
                completedTutorialLesson = .playout
            }
            if args.contains("-tutorialMilestone") {
                guidedRoundActive = true
                showTutorialMilestone(.meld)
            }
            if args.contains("-guided") {
                guidedRoundActive = true
                moveCoach = true
            }
            if args.contains("-coachOff") {
                guidedRoundActive = false
                moveCoach = false
            }
            if args.contains("-dealDone") || args.contains("-skipDeal") {
                game.skipDeal()
            }
            if args.contains("-matchEnd") {
                game.debugFinishMatch()
                matchEndResult = game.matchResult
            }
            if args.contains("-tutorial") {
                activeOverlay = .tutorial
            } else if args.contains("-help") {
                activeOverlay = .help
            } else if args.contains("-settings") {
                activeOverlay = .settings
            } else if args.contains("-menu") || args.contains("-pause") {
                activeOverlay = .menu
            }
        }
        #endif
    }

    private var phaseAtmosphere: some View {
        let opacity = theme.isTravelTable ? 0.16 : 0.12
        return ZStack {
            switch akt {
            case .melden:
                RadialGradient(colors: [
                    Tokens.jewelGold.opacity(opacity * 0.56),
                    Tokens.jewelSmaragd.opacity(opacity * 0.42),
                    .clear
                ], center: UnitPoint(x: 0.50, y: 0.44), startRadius: 60, endRadius: 410)
                RadialGradient(colors: [
                    Tokens.jewelGold.opacity(opacity * 0.28),
                    .clear
                ], center: UnitPoint(x: 0.52, y: 0.73), startRadius: 28, endRadius: 270)
            case .pochen:
                RadialGradient(colors: [
                    Tokens.jewelAmethyst.opacity(opacity * 0.90),
                    .clear
                ], center: UnitPoint(x: 0.20, y: 0.50), startRadius: 20, endRadius: 310)
                RadialGradient(colors: [
                    Tokens.jewelGold.opacity(opacity * 0.36),
                    .clear
                ], center: UnitPoint(x: 0.72, y: 0.32), startRadius: 24, endRadius: 250)
            case .ausspielen:
                RadialGradient(colors: [
                    Tokens.jewelSmaragd.opacity(opacity * 0.88),
                    .clear
                ], center: UnitPoint(x: 0.50, y: 0.46), startRadius: 42, endRadius: 340)
                RadialGradient(colors: [
                    Tokens.jewelPlatin.opacity(opacity * 0.22),
                    .clear
                ], center: UnitPoint(x: 0.50, y: 0.78), startRadius: 26, endRadius: 250)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.45), value: akt)
        .animation(.easeInOut(duration: reduceMotion ? 0 : 0.22), value: theme)
    }

    private func startNewRound() {
        guidedRoundActive = false
        activeTutorialLesson = nil
        completedTutorialLesson = nil
        game.configurePlayerCount(playerCount)
        guard game.newRound() else {
            matchEndResult = game.matchResult
            return
        }
        transition(to: .melden)
        game.runDealPresentation(reduceMotion: reduceMotion)
    }

    private func startNewMatch() {
        game.restartMatch()
        matchEndResult = nil
        transition(to: .melden)
        game.runDealPresentation(reduceMotion: reduceMotion)
    }

    private func matchEndOverlay(_ result: Match.MatchResult) -> some View {
        let ranking = result.finalStacks.indices.sorted {
            if result.finalStacks[$0] == result.finalStacks[$1] { return $0 < $1 }
            return result.finalStacks[$0] > result.finalStacks[$1]
        }
        let humanWon = result.winners.contains(0)
        return ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
            Color.black.opacity(0.58).ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text(String(localized: "match.result.eyebrow", defaultValue: "PARTIE BEENDET"))
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(2.2)
                        .foregroundStyle(Tokens.jewelGold)
                    Text(humanWon
                         ? String(localized: "match.result.youWin", defaultValue: "Du gewinnst")
                         : String(localized: "match.result.complete", defaultValue: "Die Partie ist entschieden"))
                        .font(.system(size: 25, weight: .heavy))
                        .foregroundStyle(Tokens.jewelPlatin)
                        .multilineTextAlignment(.center)
                    Text(String(format: String(localized: "match.result.rounds",
                                               defaultValue: "%d Runden gespielt"),
                                result.roundsPlayed))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tokens.slate)
                }

                VStack(spacing: 8) {
                    ForEach(Array(ranking.enumerated()), id: \.element) { place, seat in
                        HStack(spacing: 10) {
                            Text("\(place + 1)")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(result.winners.contains(seat)
                                                 ? Tokens.jewelGold : Tokens.slate)
                                .frame(width: 20)
                            if seat != 0 {
                                OpponentPortrait(seat: seat,
                                                 name: game.name(of: seat),
                                                 isActive: true,
                                                 isFocus: result.winners.contains(seat),
                                                 mood: result.winners.contains(seat) ? .winning : .neutral,
                                                 size: 28,
                                                 showsText: false,
                                                 morph: nil)
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Tokens.jewelPlatin)
                            }
                            Text(game.name(of: seat))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Tokens.jewelPlatin)
                            Spacer()
                            Text("\(result.finalStacks[seat])")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(result.winners.contains(seat)
                                                 ? Tokens.jewelGold : Tokens.jewelPlatin.opacity(0.78))
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Capsule().fill(Color.white.opacity(0.045)))
                    }
                }

                Button(action: startNewMatch) {
                    Label(String(localized: "match.result.new", defaultValue: "Neue Partie"),
                          systemImage: "arrow.clockwise")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Tokens.bgDeep)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Capsule().fill(Tokens.jewelGold))
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color(hex: 0x111017).opacity(0.97))
                    .overlay(RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(Tokens.jewelGold.opacity(0.34), lineWidth: 1))
                    .shadow(color: .black.opacity(0.58), radius: 30, y: 18)
            )
            .padding(.horizontal, 22)
        }
    }

    private func enterFirstTable(guided: Bool) {
        didStartFirstTable = true
        withAnimation(.easeOut(duration: reduceMotion ? 0.08 : 0.28)) {
            showFirstRunIntro = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 90 : 420))
            guard !showFirstRunIntro else { return }
            if guided {
                startGuidedRound()
            } else {
                guidedRoundActive = false
                activeTutorialLesson = nil
                game.configurePlayerCount(playerCount)
                game.newRound()
                transition(to: .melden)
                game.runDealPresentation(reduceMotion: reduceMotion)
            }
        }
    }

    private var firstRunIntro: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [
                    Color(hex: 0x111018),
                    Tokens.bgDeep
                ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

                RadialGradient(colors: [
                    Tokens.jewelGold.opacity(0.14),
                    Color.clear
                ], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 10, endRadius: 280)
                .ignoresSafeArea()

                if proxy.size.width > proxy.size.height {
                    firstRunLandscapeIntro(size: proxy.size,
                                           safeArea: proxy.safeAreaInsets)
                } else {
                    firstRunPortraitIntro(size: proxy.size,
                                          safeArea: proxy.safeAreaInsets)
                }
            }
        }
    }

    private var usesCompactFirstRunCopy: Bool {
        switch dynamicTypeSize {
        case .accessibility3, .accessibility4, .accessibility5:
            true
        default:
            false
        }
    }

    private var firstRunGoalText: String {
        usesCompactFirstRunCopy
            ? String(localized: "firstRun.goal.compact",
                     defaultValue: "Karten los. Mitte gewinnen.")
            : String(localized: "firstRun.goal",
                     defaultValue: "Werde zuerst deine Karten los und gewinne die Mitte.")
    }

    private var firstRunPrimaryText: String {
        usesCompactFirstRunCopy
            ? String(localized: "firstRun.intro.primary.compact",
                     defaultValue: "Platz nehmen")
            : String(localized: "firstRun.intro.primary",
                     defaultValue: "Am Tisch Platz nehmen")
    }

    private var firstRunSecondaryText: String {
        usesCompactFirstRunCopy
            ? String(localized: "firstRun.intro.secondary.compact",
                     defaultValue: "Ohne Hilfe")
            : String(localized: "firstRun.intro.secondary",
                     defaultValue: "Ohne Einführung spielen")
    }

    private func firstRunPortraitIntro(size: CGSize, safeArea: EdgeInsets) -> some View {
        let compactHeight = size.height < 760
        let boardSize = min(size.width * (compactHeight ? 0.62 : 0.72),
                            compactHeight ? 232 : 310,
                            size.height * (compactHeight ? 0.34 : 0.36))
        let opponentSize: CGFloat = compactHeight ? 44 : 48

        return ScrollView(.vertical) {
            VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("POCH")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Tokens.jewelPlatin)
                        Text("1441")
                            .font(.title3.weight(.light))
                            .foregroundStyle(Tokens.jewelGold)
                    }
                    .accessibilityElement(children: .combine)

                    Text(String(localized: "tutorial.firstTable.title",
                                defaultValue: "Dein erster Tisch"))
                        .font(.title.weight(.heavy))
                        .foregroundStyle(Tokens.jewelPlatin)
                        .padding(.top, compactHeight ? 9 : 18)
                        .accessibilityIdentifier("firstRun.intro.title")

                    Text(String(localized: "firstRun.intro.body",
                                defaultValue: "In der Mitte wartet dein erster Gewinn. Hana zeigt dir immer nur den nächsten Zug."))
                        .font(.body.weight(.medium))
                        .foregroundStyle(Tokens.jewelPlatin.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 330)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .padding(.top, compactHeight ? 4 : 8)
                        .accessibilityIdentifier("firstRun.intro.body")

                    HStack(spacing: compactHeight ? 28 : 38) {
                        ForEach(Array(game.tutorialOpponentNames.enumerated()), id: \.offset) { index, name in
                            firstRunOpponent(name: name,
                                             seat: index + 1,
                                             size: index == 0 ? opponentSize + 6 : opponentSize)
                        }
                    }
                    .padding(.top, compactHeight ? 6 : 12)

                    ZStack {
                        TableWorldBoardBase(world: .pochDisc, diameter: boardSize)
                            .frame(width: boardSize, height: boardSize)
                            .saturation(theme.isTravelTable ? 0.96 : 0.88)
                            .shadow(color: .black.opacity(0.65), radius: 28, y: 18)

                        TableTokenPile(count: playerCount,
                                       tint: Tokens.jewelGold,
                                       diameter: boardSize * 0.23,
                                       showCount: false)
                            .offset(y: -boardSize * 0.015)
                    }
                    .frame(width: boardSize, height: boardSize)
                    .padding(.top, compactHeight ? 5 : 10)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(firstRunBoardAccessibilityLabel)
                    .accessibilityIdentifier("firstRun.intro.board")

                    HStack(spacing: 9) {
                        Image(systemName: "hand.raised.fill")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(Tokens.jewelGold)
                        Text(firstRunGoalText)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Tokens.jewelPlatin.opacity(0.88))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: 330, minHeight: 40)
                    .padding(.horizontal, 28)
                    .padding(.top, compactHeight ? 5 : 10)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("firstRun.intro.goal")

                    Button {
                        enterFirstTable(guided: true)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "chair.lounge.fill")
                                .font(.headline.weight(.semibold))
                            Text(firstRunPrimaryText)
                                .font(.headline.weight(.bold))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(Tokens.bgDeep)
                        .frame(maxWidth: .infinity, minHeight: compactHeight ? 50 : 54)
                        .background(Capsule().fill(Tokens.jewelGold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("firstRun.intro.primary")
                    .accessibilityLabel(String(localized: "firstRun.intro.primary",
                                               defaultValue: "Am Tisch Platz nehmen"))
                    .padding(.horizontal, 28)
                    .padding(.top, compactHeight ? 12 : 18)

                    Button {
                        enterFirstTable(guided: false)
                    } label: {
                        Text(firstRunSecondaryText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Tokens.jewelPlatin.opacity(0.76))
                            .frame(maxWidth: .infinity, minHeight: compactHeight ? 40 : 44)
                            .background(Color.white.opacity(0.001))
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("firstRun.intro.secondary")
                    .accessibilityLabel(String(localized: "firstRun.intro.secondary",
                                               defaultValue: "Ohne Einführung spielen"))
                    .padding(.horizontal, 28)
                    .padding(.bottom, max(compactHeight ? 8 : 18,
                                         safeArea.bottom + 8))
            }
            .padding(.top, compactHeight ? 8 : 28)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func firstRunLandscapeIntro(size: CGSize, safeArea: EdgeInsets) -> some View {
        let zones = FirstRunStageZones.resolve(in: size, safeArea: safeArea)
        let introBoardSide = min(zones.board.width * 0.82,
                                 size.height - safeArea.top - safeArea.bottom - 28)
        let decisionWidth = min(zones.decision.width + 18,
                                zones.board.minX - zones.decision.minX - 10)
        let decisionContent = VStack(spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("POCH")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Tokens.jewelPlatin)
                Text("1441")
                    .font(.headline.weight(.light))
                    .foregroundStyle(Tokens.jewelGold)
            }
            .accessibilityElement(children: .combine)

            Text(String(localized: "tutorial.firstTable.title",
                        defaultValue: "Dein erster Tisch"))
                .font(.title2.weight(.heavy))
                .foregroundStyle(Tokens.jewelPlatin)
                .accessibilityIdentifier("firstRun.intro.title")

            Text(String(localized: "firstRun.intro.body",
                        defaultValue: "In der Mitte wartet dein erster Gewinn. Hana zeigt dir immer nur den nächsten Zug."))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.74))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("firstRun.intro.body")

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: "hand.raised.fill")
                Text(firstRunGoalText)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .font(.caption.weight(.bold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.88))
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("firstRun.intro.goal")

            Button {
                enterFirstTable(guided: true)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chair.lounge.fill")
                        .imageScale(.medium)
                        .offset(y: -0.5)
                    Text(firstRunPrimaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                    .font(.body.weight(.bold))
                    .foregroundStyle(Tokens.bgDeep)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Tokens.jewelGold))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("firstRun.intro.primary")
            .accessibilityLabel(String(localized: "firstRun.intro.primary",
                                       defaultValue: "Am Tisch Platz nehmen"))

            Button {
                enterFirstTable(guided: false)
            } label: {
                Text(firstRunSecondaryText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.white.opacity(0.001))
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityIdentifier("firstRun.intro.secondary")
            .accessibilityLabel(String(localized: "firstRun.intro.secondary",
                                       defaultValue: "Ohne Einführung spielen"))
        }
        return ZStack {
            VStack(spacing: 8) {
                ForEach(Array(game.tutorialOpponentNames.enumerated()), id: \.offset) { index, name in
                    firstRunOpponent(name: name,
                                     seat: index + 1,
                                     size: index == 0 ? 54 : 46)
                }
            }
            .frame(width: zones.opponents.width, height: zones.opponents.height)
            .position(x: zones.opponents.midX, y: zones.opponents.midY)

            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical) {
                    decisionContent
                        .padding(.horizontal, 4)
                        .padding(.top, 10)
                        .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .frame(width: decisionWidth,
                       height: size.height - safeArea.top - safeArea.bottom - 16)
                .position(x: zones.decision.midX,
                          y: safeArea.top
                            + (size.height - safeArea.top - safeArea.bottom) / 2)
            } else {
                decisionContent
                    .frame(width: decisionWidth)
                    .position(x: zones.decision.midX,
                              y: size.height / 2)
            }

            ZStack {
                TableWorldBoardBase(world: .pochDisc, diameter: introBoardSide)
                    .saturation(theme.isTravelTable ? 0.96 : 0.88)
                    .shadow(color: .black.opacity(0.65), radius: 22, y: 12)

                TableTokenPile(count: playerCount,
                               tint: Tokens.jewelGold,
                               diameter: zones.board.width * 0.23,
                               showCount: false)
            }
            .frame(width: introBoardSide, height: introBoardSide)
            .position(x: zones.board.midX - 4, y: size.height / 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(firstRunBoardAccessibilityLabel)
            .accessibilityIdentifier("firstRun.intro.board")
        }
    }

    private var firstRunBoardAccessibilityLabel: String {
        String(localized: "firstRun.intro.board.accessibility",
               defaultValue: "Poch-Scheibe mit acht Gewinnfeldern und Mitte")
    }

    private func firstRunOpponent(name: String, seat: Int, size: CGFloat = 48) -> some View {
        let isCoach = seat == 1
        return VStack(spacing: 6) {
            OpponentPortrait(seat: seat,
                             name: name,
                             isActive: true,
                             isFocus: false,
                             mood: .neutral,
                             size: size,
                             showsText: false,
                             morph: nil)
                .overlay {
                    if isCoach {
                        Circle()
                            .strokeBorder(Tokens.jewelGold.opacity(0.78), lineWidth: 1.5)
                            .padding(-2)
                    }
                }
            Text(name)
                .font(.caption.weight(isCoach ? .bold : .semibold))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(isCoach
                    ? Tokens.jewelGold
                    : Tokens.jewelPlatin.opacity(0.82))
                .shadow(color: .black.opacity(0.92), radius: 2, y: 1)
        }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(name)
            .accessibilityIdentifier("firstRun.opponent.\(seat)")
    }

    private var firstRunActStrip: some View {
        HStack(spacing: 8) {
            firstRunAct("1", String(localized: "firstRun.act.meld", defaultValue: "Melden"), Tokens.jewelGold)
            firstRunActConnector
            firstRunAct("2", String(localized: "firstRun.act.bidding", defaultValue: "Pochen"), theme.amethystFocus)
            firstRunActConnector
            firstRunAct("3", String(localized: "firstRun.act.playout", defaultValue: "Ausspielen"), theme.smaragdFocus)
        }
        .accessibilityElement(children: .combine)
    }

    private func firstRunAct(_ number: String, _ title: String, _ tint: Color) -> some View {
        VStack(spacing: 5) {
            Text(number)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Tokens.bgDeep)
                .frame(width: 25, height: 25)
                .background(Circle().fill(tint))
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.84))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 72)
    }

    private var firstRunActConnector: some View {
        Rectangle()
            .fill(Tokens.jewelPlatin.opacity(0.14))
            .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
            .offset(y: -9)
    }

    private func startGuidedRound(_ lesson: TutorialLesson = .meld) {
        game.configurePlayerCount(4)
        guard game.startTutorialRound(lesson) else {
            guidedRoundActive = false
            activeTutorialLesson = nil
            showFirstRunIntro = true
            return
        }
        guidedRoundActive = true
        activeTutorialLesson = lesson
        completedTutorialLesson = nil
        moveCoach = true
        activeOverlay = nil
        switch lesson {
        case .meld:
            game.presentation.startFirstRun()
            guidedMeldBusy = false
            guidedAntePoolCounts.removeAll(keepingCapacity: true)
            guidedAnteLandedEvents.removeAll(keepingCapacity: true)
            guidedAnteWave = nil
            transition(to: .melden)
            game.prepareGuidedDeal()
        case .bidding:
            transition(to: .pochen)
        case .playout:
            transition(to: .ausspielen)
            game.beginPlayoutPresentation()
        }
    }

    private func transition(to next: Akt) {
        recordTutorialTransition(from: akt, to: next)
        if guidedRoundActive {
            // Im Tutorial ist der Aktwechsel eine klare Übergabe. Ein animierter
            // Switch hält sonst alten und neuen Screen kurz gleichzeitig im
            // View-Tree und erzeugt doppelte Header, Bretter und Kartenfächer.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { akt = next }
        } else {
            withAnimation(.spring(duration: Tokens.aktMorph)) { akt = next }
            showPhaseCurtain(next)
        }
    }

    private func recordTutorialTransition(from current: Akt, to next: Akt) {
        guard guidedRoundActive else { return }
        switch (current, next) {
        case (.melden, .pochen):
            markTutorialComplete(.meld)
            activeTutorialLesson = .bidding
        case (.pochen, .ausspielen):
            markTutorialComplete(.bidding)
            activeTutorialLesson = .playout
        default:
            break
        }
    }

    private func completeTutorialRound() {
        let lesson = activeTutorialLesson ?? .playout
        markTutorialComplete(lesson)
        activeTutorialLesson = nil
        guidedRoundActive = false
        withAnimation(.spring(response: 0.46, dampingFraction: 0.88)) {
            completedTutorialLesson = lesson
        }
    }

    private func markTutorialComplete(_ lesson: TutorialLesson) {
        tutorialProgressMask |= tutorialBit(for: lesson)
    }

    private func showTutorialMilestone(_ lesson: TutorialLesson) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 1_100))
            guard guidedRoundActive else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                tutorialMilestoneLesson = lesson
            }
            try? await Task.sleep(for: .milliseconds(1_350))
            guard tutorialMilestoneLesson == lesson else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                tutorialMilestoneLesson = nil
            }
        }
    }

    private func tutorialBit(for lesson: TutorialLesson) -> Int {
        switch lesson {
        case .meld: return 1 << 0
        case .bidding: return 1 << 1
        case .playout: return 1 << 2
        }
    }

    private func tutorialIsComplete(_ lesson: TutorialLesson) -> Bool {
        tutorialProgressMask & tutorialBit(for: lesson) != 0
    }

    private var completedTutorialCount: Int {
        TutorialLesson.allCases.filter(tutorialIsComplete).count
    }

    private func showPhaseCurtain(_ next: Akt) {
        guard tableEffects, !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.16)) { phaseCurtain = next }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            guard phaseCurtain == next else { return }
            withAnimation(.easeOut(duration: 0.18)) { phaseCurtain = nil }
        }
    }

    @ViewBuilder private func phaseCurtainView(_ target: Akt) -> some View {
        let copy = curtainCopy(target)
        PhaseCurtain(phase: copy.phase,
                     title: copy.title,
                     subtitle: copy.subtitle,
                     tint: copy.tint)
    }

    private func curtainCopy(_ target: Akt) -> (phase: String, title: String, subtitle: String, tint: Color) {
        switch target {
        case .melden:
            return ("PHASE 1", "MELDEN",
                    "Werte sammeln. Die Mitte bleibt fuer den Schluss.",
                    Tokens.jewelGold)
        case .pochen:
            return ("PHASE 2", "POCHEN",
                    "Paar zeigen, Druck machen, Limit lesen.",
                    Tokens.jewelAmethyst)
        case .ausspielen:
            return ("PHASE 3", "AUSSPIELEN",
                    "Ketten laufen. Wer zuerst leer ist, gewinnt die Mitte.",
                    Tokens.jewelSmaragd)
        }
    }

    // MARK: - Kopf

    private var aktLabel: (phase: String, title: String, tint: Color) {
        switch akt {
        case .melden: return ("PHASE 1", "MELDEN", Tokens.jewelGold)
        case .pochen: return ("PHASE 2", "POCHEN", theme.amethystFocus.opacity(0.85))
        case .ausspielen: return ("PHASE 3", "AUSSPIELEN", theme.smaragdFocus.opacity(0.85))
        }
    }

    private var isGuidedOpeningBeat: Bool {
        guidedRoundActive && akt == .melden && guidedMeldBeat == 0
    }

    private var guidedOpeningHeader: some View {
        HStack(spacing: 6) {
            Text("POCH")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Tokens.jewelPlatin)
            Text("1441")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Tokens.jewelGold)
        }
        .frame(height: verticalSizeClass == .compact ? 54 : 164, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        let label = aktLabel
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("POCH").font(.system(size: 26, weight: .bold)).foregroundStyle(Tokens.jewelPlatin)
                Text("1441").font(.system(size: 26, weight: .light)).foregroundStyle(Tokens.jewelGold)
            }
            VStack(spacing: 1) {
                Text(label.phase)
                    .font(.system(size: 8.5, weight: .heavy))
                    .tracking(2.1)
                    .foregroundStyle(Tokens.slate.opacity(0.72))
                Text(label.title)
                    .font(.system(size: 19, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(Tokens.jewelPlatin)
                    .shadow(color: label.tint.opacity(theme.isTravelTable ? 0.16 : 0.10),
                            radius: theme.isTravelTable ? 5 : 4, y: 2)
            }
            if akt == .pochen || (akt == .melden && game.trumpRevealed) {
                trumpChip
            }
            if guidedRoundActive && akt != .pochen {
                guidedPill
            }
        }
    }

    private var guidedPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "scope")
            Text(guidedLearningStateTitle)
        }
        .font(.system(size: 8.5, weight: .heavy))
        .tracking(1.2)
        .foregroundStyle(Tokens.bgDeep)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(guidedTint.opacity(0.92)))
        .shadow(color: guidedTint.opacity(0.18), radius: 8, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "tutorial.learningState.label",
                                   defaultValue: "Lernzustand"))
        .accessibilityValue(guidedLearningStateTitle)
        .accessibilityIdentifier("firstRun.learningState")
    }

    private var guidedLearningStateTitle: String {
        switch guidedLearningState {
        case .orientieren:
            return String(localized: "tutorial.learningState.orient",
                          defaultValue: "Orientieren")
        case .verbinden:
            return String(localized: "tutorial.learningState.connect",
                          defaultValue: "Verbinden")
        case .beweisen:
            return String(localized: "tutorial.learningState.prove",
                          defaultValue: "Beweisen")
        case .loslassen:
            return String(localized: "tutorial.learningState.release",
                          defaultValue: "Loslassen")
        }
    }

    private var guidedTint: Color {
        switch akt {
        case .melden: return Tokens.jewelGold
        case .pochen: return Tokens.jewelAmethyst
        case .ausspielen: return Tokens.jewelSmaragd
        }
    }

    @ViewBuilder private var guidedCoachPlacement: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let frame = guidedFocusFrame(in: size)
            let spotlightFrame = guidedSpotlightFrame(in: size, boardFrame: frame)
            ZStack {
                if akt == .melden {
                    guidedSpotlight(frame: spotlightFrame)
                        .allowsHitTesting(false)
                }

                if isGuidedOpeningBeat {
                    guidedOpeningInteraction(in: size, focus: frame)
                } else if akt == .melden {
                    if !guidedMeldBusy {
                        guidedCoachRail
                            .frame(width: min(size.width - 42, guidedCoachWidth))
                            .position(x: size.width / 2, y: guidedCoachY(in: size, focus: frame))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .animation(.easeOut(duration: 0.18), value: guidedMeldBusy)
        }
    }

    private func guidedOpeningInteraction(in size: CGSize, focus: CGRect) -> some View {
        let target = CGPoint(x: focus.midX, y: focus.midY)
        let landscape = size.width > size.height
        let source = landscape
            ? CGPoint(x: max(132, focus.minX - 112), y: focus.midY)
            : CGPoint(x: size.width / 2,
                      y: min(size.height - 124,
                             focus.maxY + Tokens.guidedOpeningSourceGap))
        let projected = CGPoint(x: source.x + guidedOpeningDrag.width,
                                y: source.y + guidedOpeningDrag.height)
        let distance = hypot(projected.x - target.x, projected.y - target.y)

        return ZStack {
            VStack(spacing: 5) {
                Text(String(localized: "tutorial.meld.drag.title",
                            defaultValue: "Ziehe den Stein in die Mitte"))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin)
                Text(String(localized: "tutorial.meld.drag.body",
                            defaultValue: "Dort wartet der Gewinn der letzten Phase."))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.66))
            }
            .multilineTextAlignment(.center)
            .position(x: source.x, y: source.y + 54)
            .opacity(guidedOpeningSettled ? 0 : 1)

            Circle()
                .strokeBorder(Tokens.jewelGold.opacity(distance < Tokens.guidedOpeningSnapRadius ? 0.74 : 0.28),
                              lineWidth: distance < Tokens.guidedOpeningSnapRadius ? 2 : 1)
                .frame(width: 76, height: 76)
                .position(target)
                .animation(.easeOut(duration: 0.12), value: distance)
                .accessibilityElement()
                .accessibilityLabel(String(localized: "board.center", defaultValue: "Mitte"))
                .accessibilityIdentifier("firstRun.openingTarget")

            Button {
                settleGuidedOpeningToken(from: source, to: target)
            } label: {
                R1Token(tint: Tokens.jewelGold,
                          size: Tokens.guidedOpeningTokenSize)
                    .scaleEffect(distance < Tokens.guidedOpeningSnapRadius ? 0.94 : 1)
                    .frame(width: 44, height: 44)
                    .opacity(reduceMotion && guidedOpeningSettled ? 0 : 1)
            }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .position(source)
                .offset(guidedOpeningDrag)
                .shadow(color: .black.opacity(0.72), radius: 9, y: 7)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            guard !guidedOpeningSettled else { return }
                            game.beginGuidedOpeningToken()
                            guidedOpeningDrag = value.translation
                        }
                        .onEnded { value in
                            guard !guidedOpeningSettled else { return }
                            let end = CGPoint(x: source.x + value.translation.width,
                                              y: source.y + value.translation.height)
                            let endDistance = hypot(end.x - target.x, end.y - target.y)
                            if endDistance <= Tokens.guidedOpeningSnapRadius {
                                settleGuidedOpeningToken(from: source, to: target)
                            } else {
                                withAnimation(reduceMotion
                                    ? .easeOut(duration: 0.08)
                                    : .spring(response: 0.34, dampingFraction: 0.88)) {
                                    guidedOpeningDrag = .zero
                                }
                            }
                        }
                )
                .accessibilityLabel(String(localized: "tutorial.meld.action.openTable",
                                           defaultValue: "Stein in die Mitte legen"))
                .accessibilityIdentifier("firstRun.openingToken")
        }
    }

    private func settleGuidedOpeningToken(from source: CGPoint, to target: CGPoint) {
        guard !guidedOpeningSettled else { return }
        game.beginGuidedOpeningToken()
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.08),
                          completionCriteria: .logicallyComplete) {
                guidedOpeningSettled = true
            } completion: {
                completeGuidedOpeningImpact()
            }
            return
        }
        guidedOpeningSettled = true
        withAnimation(.easeOut(duration: 0.16),
                      completionCriteria: .logicallyComplete) {
            guidedOpeningDrag = CGSize(width: target.x - source.x,
                                       height: target.y - source.y)
        } completion: {
            completeGuidedOpeningImpact()
        }
    }

    private func completeGuidedOpeningImpact() {
        guard isGuidedOpeningBeat else { return }
        game.markGuidedOpeningTokenLanded()
        guidedAntePoolCounts[.center] = 1
        game.presentation.setFirstRunBeat(.fundTable)
        guidedCoachFocused = true
        guidedOpeningDrag = .zero
        guidedOpeningSettled = false
    }

    private var guidedCoachWidth: CGFloat {
        switch akt {
        case .melden: return 334
        case .pochen: return 292
        case .ausspielen: return 328
        }
    }

    private func guidedFocusFrame(in size: CGSize) -> CGRect {
        switch akt {
        case .melden:
            let ringDiameter = Tokens.ringRadius * 2 + Tokens.tileDiameter
            let d = min(size.width * Tokens.guidedMeldBoardScale,
                        ringDiameter * Tokens.guidedMeldBoardScale)
            return CGRect(x: (size.width - d) / 2,
                          y: Tokens.guidedMeldFocusTop,
                          width: d,
                          height: d)
        case .pochen:
            return CGRect(x: 44,
                          y: max(344, size.height * 0.40),
                          width: size.width - 88,
                          height: 178)
        case .ausspielen:
            return CGRect(x: 18,
                          y: max(292, size.height * 0.30),
                          width: size.width - 36,
                          height: min(260, size.height * 0.30))
        }
    }

    private func guidedSpotlightFrame(in size: CGSize, boardFrame: CGRect) -> CGRect {
        guard akt == .melden, guidedMeldBeat >= 3 else { return boardFrame }
        return CGRect(x: 18,
                      y: max(boardFrame.maxY + 20, size.height - 154),
                      width: size.width - 36,
                      height: 132)
    }

    private func guidedCoachY(in size: CGSize, focus: CGRect) -> CGFloat {
        switch akt {
        case .melden:
            if guidedMeldBeat >= 3 {
                // Sobald Karten sichtbar sind, bleibt der Coach oberhalb der Hand.
                // So kann der Spieler Text und Kartenindizes gleichzeitig lesen.
                return max(focus.minY + 84, size.height - 264)
            }
            return min(size.height - 142,
                       focus.maxY + Tokens.guidedMeldCoachGap)
        case .pochen:
            return max(368, min(394, size.height * 0.43))
        case .ausspielen:
            return min(size.height - 242, focus.maxY + 34)
        }
    }

    private func guidedSpotlight(frame: CGRect) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let vertical = i % 2 == 0
                let x = vertical ? frame.midX : (i == 1 ? frame.maxX : frame.minX)
                let y = vertical ? (i == 0 ? frame.minY : frame.maxY) : frame.midY
                Capsule()
                    .fill(LinearGradient(colors: [
                        guidedTint.opacity(0.82),
                        Tokens.jewelPlatin.opacity(0.32),
                        guidedTint.opacity(0.82)
                    ], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 30, height: 2)
                    .rotationEffect(.degrees(vertical ? 0 : 90))
                    .position(x: x, y: y)
                    .shadow(color: guidedTint.opacity(theme.isTravelTable ? 0.16 : 0.10), radius: 5)
            }
        }
        .accessibilityHidden(true)
    }

    private var guidedCoachRail: some View {
        let copy = guidedCopy
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
            Image(systemName: copy.step)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Tokens.bgDeep)
                .frame(width: 30, height: 30)
                .background(Circle().fill(guidedTint))
            VStack(alignment: .leading, spacing: 3) {
                Text(copy.title)
                    .font(.system(size: min(guidedActionFontSize,
                                            dynamicTypeSize.isAccessibilitySize ? 24 : 19),
                                  weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(copy.title)
            .accessibilityValue(copy.text)
            .accessibilityFocused($guidedCoachFocused)
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    guidedRoundActive = false
                    moveCoach = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Tokens.slate)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            }

            if !usesCompactGuidedCoachCopy {
                Text(copy.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }

            if guidedRoundActive, akt == .melden, guidedMeldBeat > 0, guidedMeldBeat <= 7 {
                Button(action: advanceGuidedMeld) {
                    HStack(spacing: 8) {
                        if guidedMeldBusy {
                            ProgressView()
                                .tint(Tokens.bgDeep)
                        } else {
                            Text(guidedMeldActionTitle)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.88)
                            if !dynamicTypeSize.isAccessibilitySize {
                                Image(systemName: "arrow.right")
                            }
                        }
                    }
                    .font(.system(size: min(guidedActionFontSize,
                                            dynamicTypeSize.isAccessibilitySize ? 24 : 18),
                                  weight: .bold))
                    .foregroundStyle(Tokens.bgDeep)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity,
                           minHeight: dynamicTypeSize.isAccessibilitySize ? 68 : 48)
                    .background(
                        RoundedRectangle(cornerRadius: dynamicTypeSize.isAccessibilitySize ? 22 : 24,
                                         style: .continuous)
                            .fill(guidedTint)
                    )
                }
                .buttonStyle(.plain)
                .disabled(guidedMeldBusy)
                .accessibilityIdentifier("firstRun.coachAction")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: 0x111018).opacity(0.96))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(guidedTint.opacity(0.32), lineWidth: 1))
                .shadow(color: .black.opacity(0.48), radius: 20, y: 10)
        )
    }

    private var usesCompactGuidedCoachCopy: Bool {
        switch dynamicTypeSize {
        case .accessibility3, .accessibility4, .accessibility5:
            true
        default:
            false
        }
    }

    private func advanceGuidedMeld() {
        guard !guidedMeldBusy else { return }
        if guidedMeldBeat == FirstRunBeat.fundTable.rawValue {
            runGuidedTableFundingImpact()
            return
        }
        guidedMeldBusy = true
        Task { @MainActor in
            switch guidedMeldBeat {
            case 0:
                game.presentation.setFirstRunBeat(.fundTable)
            case 1:
                break
            case 2:
                await game.revealGuidedDealRound(reduceMotion: reduceMotion)
                game.presentation.setFirstRunBeat(.completeHand)
            case 3:
                await game.finishGuidedDeal(reduceMotion: reduceMotion)
                game.presentation.setFirstRunBeat(.revealTrump)
            case 4:
                game.revealGuidedTrumpf()
                game.presentation.setFirstRunBeat(.connectMeld)
            case 5:
                game.presentation.setFirstRunBeat(.proveMeld)
            case 6:
                await game.revealAllGuidedMelds(reduceMotion: reduceMotion)
                game.presentation.setFirstRunBeat(.release)
            case 7:
                transition(to: .pochen)
            default:
                break
            }
            guidedMeldBusy = false
            guidedCoachFocused = true
        }
    }

    private func runGuidedTableFundingImpact() {
        guidedMeldBusy = true
        guidedTableFundingTargeted = false
        game.beginGuidedTableFunding()
        withAnimation(.easeInOut(duration: reduceMotion ? 0.16 : 0.30),
                      completionCriteria: .logicallyComplete) {
            guidedTableFundingTargeted = true
        } completion: {
            game.markGuidedTableFundingLanded(groupSize: game.playerCount)
            guidedAntePoolCounts = Dictionary(
                uniqueKeysWithValues: Pool.allCases.map { ($0, game.playerCount) }
            )
            guidedTableFundingTargeted = false
            game.presentation.setFirstRunBeat(.firstCard)
            guidedMeldBusy = false
            guidedCoachFocused = true
        }
    }

    #if DEBUG
    private func runGuidedMeldMotionQA() {
        startGuidedRound()
        guidedAntePoolCounts[.center] = 1
        game.presentation.setFirstRunBeat(.fundTable)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Tokens.guidedQAStateHold))
            guidedMeldBusy = true
            await runGuidedAnteSequence()
            game.presentation.setFirstRunBeat(.firstCard)
            guidedMeldBusy = false
            try? await Task.sleep(for: .seconds(Tokens.guidedQAStateHold))
            guidedMeldBusy = true
            await game.revealGuidedDealRound(reduceMotion: reduceMotion)
            game.presentation.setFirstRunBeat(.completeHand)
            guidedMeldBusy = false
            try? await Task.sleep(for: .seconds(Tokens.guidedQAOutcomeHold))
            guidedMeldBusy = true
            await game.finishGuidedDeal(reduceMotion: reduceMotion)
            game.presentation.setFirstRunBeat(.revealTrump)
            guidedMeldBusy = false
            try? await Task.sleep(for: .seconds(Tokens.guidedQAStateHold))
            guidedMeldBusy = true
            game.revealGuidedTrumpf()
            game.presentation.setFirstRunBeat(.connectMeld)
            guidedMeldBusy = false
            try? await Task.sleep(for: .seconds(Tokens.guidedQAOutcomeHold))
            guidedMeldBusy = true
            game.presentation.setFirstRunBeat(.proveMeld)
            guidedMeldBusy = false
            try? await Task.sleep(for: .seconds(Tokens.guidedQAStateHold))
            guidedMeldBusy = true
            await game.revealAllGuidedMelds(reduceMotion: reduceMotion)
            game.presentation.setFirstRunBeat(.release)
            guidedMeldBusy = false
        }
    }

    private func prepareGuidedMeldDebugStep(_ step: Int) {
        startGuidedRound()
        Task { @MainActor in
            if step >= 1 {
                guidedAntePoolCounts = Dictionary(
                    uniqueKeysWithValues: Pool.allCases.map { ($0, 1) }
                )
                game.presentation.setFirstRunBeat(.fundTable)
            }
            if step >= 2 {
                guidedAntePoolCounts = Dictionary(
                    uniqueKeysWithValues: Pool.allCases.map { ($0, game.playerCount) }
                )
                game.presentation.setFirstRunBeat(.firstCard)
            }
            if step >= 3 {
                await game.revealGuidedDealRound(reduceMotion: true)
                game.presentation.setFirstRunBeat(.completeHand)
            }
            if step >= 4 {
                await game.finishGuidedDeal(reduceMotion: true)
                game.presentation.setFirstRunBeat(.revealTrump)
            }
            if step >= 5 {
                game.revealGuidedTrumpf()
                game.presentation.setFirstRunBeat(.connectMeld)
            }
            if step >= 6 {
                game.presentation.setFirstRunBeat(.proveMeld)
            }
            if step >= 7 {
                await game.revealAllGuidedMelds(reduceMotion: true)
                game.presentation.setFirstRunBeat(.release)
            }
        }
    }
    #endif

    private var guidedMeldActionTitle: String {
        switch guidedMeldBeat {
        case 0:
            return String(localized: "tutorial.meld.action.openTable",
                          defaultValue: "Stein in die Mitte legen")
        case 1:
            return String(localized: "tutorial.meld.action.ante",
                          defaultValue: "Einsätze reihum legen")
        case 2:
            return String(localized: "tutorial.meld.action.firstDeal",
                          defaultValue: "Erste Runde geben")
        case 3:
            return String(localized: "tutorial.meld.action.finishDeal",
                          defaultValue: "Hand fertig geben")
        case 4:
            return String(localized: "tutorial.meld.action.revealTrump",
                          defaultValue: "Trumpf aufdecken")
        case 5:
            return String(localized: "tutorial.meld.action.connectClaim",
                          defaultValue: "Karte und Mulde verbinden")
        case 6:
            return String(localized: "tutorial.meld.action.showClaim",
                          defaultValue: "Meldung zeigen")
        case 7:
            return String(localized: "tutorial.meld.action.continueBidding",
                          defaultValue: "Weiter zum Pochen")
        default:
            return String(localized: "tutorial.meld.action.showClaim",
                          defaultValue: "Meldung zeigen")
        }
    }

    private var guidedAntePoolOrder: [Pool] {
        PochRing.anchors.map(\.pool) + [.center]
    }

    private func runGuidedAnteSequence() async {
        let allPools = guidedAntePoolOrder
        for contributor in 0..<game.playerCount {
            guard !Task.isCancelled else { return }
            let pools = contributor == 0
                ? allPools.filter { $0 != .center }
                : allPools
            guidedAnteWave = GuidedAnteWaveState(contributor: contributor, pools: pools)
            if reduceMotion {
                for pool in pools {
                    landGuidedAnte(contributor: contributor, pool: pool)
                }
            } else {
                let duration = Tokens.guidedAnteFlight
                    + Double(max(0, pools.count - 1)) * Tokens.guidedAnteStagger
                    + Tokens.guidedAnteWaveRest
                try? await Task.sleep(for: .seconds(duration))
                for pool in pools {
                    landGuidedAnte(contributor: contributor, pool: pool)
                }
            }
        }
        guidedAnteWave = nil
    }

    private func landGuidedAnte(contributor: Int, pool: Pool) {
        guard let poolIndex = guidedAntePoolOrder.firstIndex(of: pool) else { return }
        let eventID = contributor * Pool.allCases.count + poolIndex
        guard guidedAnteLandedEvents.insert(eventID).inserted else { return }
        guidedAntePoolCounts[pool, default: 0] += 1
    }

    private var guidedCopy: (step: String, title: String, text: String) {
        switch akt {
        case .melden:
            if guidedRoundActive {
                switch guidedMeldBeat {
                case 0:
                    return ("circle.fill",
                            String(localized: "tutorial.meld.table.title", defaultValue: "Dein erster Stein"),
                            String(localized: "tutorial.meld.table.body", defaultValue: "Lege ihn in die Mitte. Sie wird am Ende der Runde gewonnen."))
                case 1:
                    return ("circle.grid.3x3.fill",
                            String(localized: "tutorial.meld.ante.title", defaultValue: "Dein Stein liegt"),
                            String(localized: "tutorial.meld.ante.body", defaultValue: "Die Mitte enthält jetzt 1. Als Nächstes legt jeder einen Stein in jede Mulde."))
                case 2:
                    return ("rectangle.stack.fill",
                            String(localized: "tutorial.meld.firstDeal.title", defaultValue: "Die erste Runde"),
                            String(localized: "tutorial.meld.firstDeal.body", defaultValue: "Gib einmal reihum. Jede Karte hat eine sichtbare Quelle und ein klares Ziel."))
                case 3:
                    return ("hand.raised.fill",
                            String(localized: "tutorial.meld.hand.title", defaultValue: "Deine Hand"),
                            String(localized: "tutorial.meld.hand.body", defaultValue: "Jetzt wird fertig gegeben. Danach siehst du deine vollständige Hand."))
                case 4:
                    return ("suit.diamond.fill",
                            String(localized: "tutorial.guide.trump.title", defaultValue: "Trumpf aufdecken"),
                            String(localized: "tutorial.guide.trump.body", defaultValue: "Die letzte offene Karte bestimmt die Trumpffarbe dieser Runde."))
                case 5:
                    return ("point.topleft.down.to.point.bottomright.curvepath",
                            String(localized: "tutorial.meld.connect.title", defaultValue: "Karte trifft Mulde"),
                            String(localized: "tutorial.meld.connect.body", defaultValue: "Dein Trumpf-König gehört zur König-Mulde. Verfolge die eine Verbindung."))
                case 6:
                    return ("checkmark.seal.fill",
                            String(localized: "tutorial.meld.claim.title", defaultValue: "Meldung erkennen"),
                            String(localized: "tutorial.meld.claim.body", defaultValue: "Passende Trumpfkarten holen die benannte äußere Mulde."))
                default:
                    return ("checkmark.circle.fill",
                            String(localized: "tutorial.meld.release.title", defaultValue: "Die Disc ist bereit"),
                            String(localized: "tutorial.meld.release.body", defaultValue: "Deine Meldung ist angekommen. Die Lernhilfen können jetzt verschwinden."))
                }
            }
            if game.dealtCount < game.totalDeals {
                let format = String(localized: "tutorial.guide.deal.body",
                                    defaultValue: "Rücken wandern reihum: %d von %d. Verfolge nur deinen Platz.")
                return ("rectangle.stack.fill",
                        String(localized: "tutorial.guide.deal.title", defaultValue: "Karten kommen"),
                        String(format: format, game.dealtCount, game.totalDeals))
            }
            if !game.trumpRevealed {
                return ("suit.diamond.fill",
                        String(localized: "tutorial.guide.trump.title", defaultValue: "Trumpf fällt"),
                        String(localized: "tutorial.guide.trump.body", defaultValue: "Die offene Karte bestimmt den Trumpf. Danach werden passende Meldungen ausgezahlt."))
            }
            let openPools = PochRing.anchors
                .map(\.pool)
                .filter { game.displayedChips(in: $0) > 0 }
                .prefix(2)
                .map(\.indexLabel)
                .joined(separator: " · ")
            let focus = openPools.isEmpty ? "Suche Wertungen in Hand und Tisch." : "Jetzt zahlen: \(openPools)."
            return ("sparkles", "Melden lesen", "\(focus) Die Mitte bleibt fürs Finale.")
        case .pochen:
            guard game.turnIndex == 0, let legal = game.humanLegal else {
                return ("eye.fill", "Antwort lesen", "\(game.name(of: game.turnIndex)) entscheidet. Schau, ob Chips in die Poch-Mitte wandern oder jemand aussteigt.")
            }
            let current = game.betting.currentBet
            let callCost = max(0, current - game.humanCommitted)
            if let range = legal.openRange {
                return ("hand.tap.fill", "Pochen eröffnen", "Dein Paar darf bieten: \(range.lowerBound)-\(range.upperBound). Klein testet, hoch baut Druck.")
            }
            if let range = legal.raiseRange {
                return ("arrow.up.circle.fill", "Antwort erzwingen", "Mitgehen kostet \(callCost). Erhöhen bis \(range.upperBound) vergrößert Einsatz und Risiko.")
            }
            if legal.canCall {
                return ("arrow.left.arrow.right.circle.fill", "Mitgehen oder raus", "Mitgehen kostet \(callCost). Passen rettet Chips, gibt die Mulde aber auf.")
            }
            return ("forward.fill", "Kein Paar", "Du kannst hier nicht pochen. Passen bringt dich sauber ins Ausspielen.")
        case .ausspielen:
            if game.stage != .playout {
                return ("flag.checkered",
                        String(localized: "tutorial.guide.finish.title", defaultValue: "Runde lesen"),
                        String(localized: "tutorial.guide.finish.body", defaultValue: "Mitte und Restkarten fließen zum Sieger. Danach beginnt eine freie Runde."))
            }
            guard game.hasPlayout else {
                return ("rectangle.on.rectangle.angled", "Ausspielen", "Die Mitte wartet. Wer zuerst leer ist, nimmt den Hauptpott.")
            }
            if game.playoutLeader == 0, game.cascadeIdle {
                return ("play.fill", "Kette starten", "Du führst. Niedrig starten hält mehr Anschlusskarten im Rennen.")
            }
            if game.cascadeIdle {
                let leader = game.playoutLeader ?? 0
                return ("arrow.turn.down.right", "Neues Anspiel", "\(game.name(of: leader)) führt die nächste Kette.")
            }
            return ("link", "Kette läuft", "Folgekarten springen automatisch. Beim Riss wechselt das Anspiel.")
        }
    }

    private var utilityButtons: some View {
        Button { activeOverlay = .menu } label: {
            Image(systemName: "pause.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.86))
                .frame(width: 38, height: 38)
                .background(Circle().fill(.black.opacity(0.24))
                    .overlay(Circle().strokeBorder(Tokens.jewelGold.opacity(0.22), lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .padding(.trailing, 2)
        .accessibilityLabel(String(localized: "menu.pause", defaultValue: "Pause"))
    }

    @ViewBuilder private var overlayPanel: some View {
        if let activeOverlay {
            ZStack {
                Color.black.opacity(0.56)
                    .ignoresSafeArea()
                    .onTapGesture { self.activeOverlay = nil }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(overlayTitle(activeOverlay))
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(Tokens.jewelPlatin)
                            Text(overlaySubtitle(activeOverlay))
                                .font(.system(size: 10.5, weight: .semibold))
                                .tracking(1.3)
                                .foregroundStyle(overlayTint(activeOverlay).opacity(0.82))
                        }
                        Spacer()
                        Button { self.activeOverlay = nil } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Tokens.slate)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }

                    if activeOverlay == .menu {
                        menuPhaseStrip
                    } else {
                        overlayTabs(activeOverlay)
                    }

                    ScrollView(showsIndicators: false) {
                        switch activeOverlay {
                        case .menu:
                            menuContent
                        case .tutorial:
                            tutorialContent
                        case .help:
                            helpContent
                        case .settings:
                            settingsContent
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 78)
                    }
                    .frame(maxHeight: 436)

                    overlayFooter(activeOverlay)
                }
                .padding(20)
                .frame(maxWidth: 356)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [Color(hex: 0x17141D), Color(hex: 0x0B0A10)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Tokens.jewelGold.opacity(0.25), lineWidth: 1))
                        .shadow(color: .black.opacity(0.65), radius: 28, y: 16)
                )
                .padding(.horizontal, 18)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
            .animation(.spring(duration: 0.28), value: self.activeOverlay != nil)
        }
    }

    @ViewBuilder private var tutorialCompletionOverlay: some View {
        if let lesson = completedTutorialLesson {
            let allComplete = completedTutorialCount == TutorialLesson.allCases.count
            ZStack {
                Color.black.opacity(0.72)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(tutorialLessonTint(lesson).opacity(0.13))
                            .frame(width: 88, height: 88)
                        Circle()
                            .strokeBorder(tutorialLessonTint(lesson).opacity(0.48), lineWidth: 1)
                            .frame(width: 72, height: 72)
                        Image(systemName: allComplete ? "checkmark.seal.fill" : tutorialLessonIcon(lesson))
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(tutorialLessonTint(lesson))
                    }

                    VStack(spacing: 7) {
                        Text(String(localized: "tutorial.completion.eyebrow",
                                    defaultValue: "LEKTION ABGESCHLOSSEN"))
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(2.0)
                            .foregroundStyle(tutorialLessonTint(lesson).opacity(0.86))
                        Text(tutorialCompletionTitle(lesson, allComplete: allComplete))
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(Tokens.jewelPlatin)
                            .multilineTextAlignment(.center)
                        Text(tutorialCompletionBody(allComplete: allComplete))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Tokens.slate)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    tutorialCompletionProgress

                    VStack(spacing: 9) {
                        overlayPrimaryButton(
                            String(localized: "tutorial.completion.free",
                                   defaultValue: "Freie Partie starten"),
                            tint: Tokens.jewelGold
                        ) {
                            startNewRound()
                        }
                        overlayInlineButton(
                            String(localized: "tutorial.completion.lessons",
                                   defaultValue: "Lektionen ansehen"),
                            tint: tutorialLessonTint(lesson)
                        ) {
                            completedTutorialLesson = nil
                            activeOverlay = .tutorial
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: 354)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [Color(hex: 0x17141D), Color(hex: 0x09080D)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(tutorialLessonTint(lesson).opacity(0.34), lineWidth: 1))
                        .shadow(color: .black.opacity(0.70), radius: 30, y: 18)
                )
                .padding(.horizontal, 18)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
            .zIndex(20)
        }
    }

    @ViewBuilder private var tutorialMilestoneOverlay: some View {
        if let lesson = tutorialMilestoneLesson, completedTutorialLesson == nil {
            HStack(spacing: 9) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Tokens.bgDeep)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(tutorialLessonTint(lesson)))
                Text(tutorialCompletionTitle(lesson, allComplete: false))
                    .font(.system(size: 11.5, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(hex: 0x111018).opacity(0.96))
                    .overlay(Capsule().strokeBorder(
                        tutorialLessonTint(lesson).opacity(0.34), lineWidth: 1))
                    .shadow(color: .black.opacity(0.48), radius: 14, y: 8)
            )
            .padding(.top, 118)
            .transition(reduceMotion
                        ? .opacity
                        : .move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(false)
            .zIndex(19)
        }
    }

    private func tutorialCompletionTitle(_ lesson: TutorialLesson, allComplete: Bool) -> String {
        if allComplete {
            return String(localized: "tutorial.completion.all.title",
                          defaultValue: "Bereit für den freien Tisch")
        }
        let format = String(localized: "tutorial.completion.lesson.title",
                            defaultValue: "%@ geschafft")
        return String(format: format, tutorialLessonTitle(lesson))
    }

    private func tutorialCompletionBody(allComplete: Bool) -> String {
        if allComplete {
            return String(localized: "tutorial.completion.all.body",
                          defaultValue: "Du kennst den Rhythmus aus Melden, Pochen und Ausspielen. Im freien Spiel bleiben Hinweise auf Wunsch aktiv.")
        }
        return String(localized: "tutorial.completion.lesson.body",
                      defaultValue: "Der Schritt sitzt. Du kannst direkt frei spielen oder die nächste Lektion gezielt beginnen.")
    }

    private var tutorialCompletionProgress: some View {
        HStack(spacing: 9) {
            ForEach(TutorialLesson.allCases) { lesson in
                let complete = tutorialIsComplete(lesson)
                Image(systemName: complete ? "checkmark" : tutorialLessonIcon(lesson))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(complete ? Tokens.bgDeep : Tokens.slate)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(complete
                                              ? tutorialLessonTint(lesson)
                                              : Color.white.opacity(0.05)))
                    .overlay(Circle().strokeBorder(tutorialLessonTint(lesson)
                        .opacity(complete ? 0 : 0.28), lineWidth: 1))
            }
            Text(String(format: String(localized: "tutorial.completion.progress",
                                       defaultValue: "%d von 3 Lektionen"),
                        completedTutorialCount))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Tokens.slate)
        }
    }

    private func overlayTitle(_ overlay: AppOverlay) -> String {
        switch overlay {
        case .menu: return "Pause"
        case .tutorial: return "Tutorial"
        case .help: return "Spielhilfe"
        case .settings: return "Einstellungen"
        }
    }

    private func overlaySubtitle(_ overlay: AppOverlay) -> String {
        switch overlay {
        case .menu: return "WEITER · HILFE · TISCH"
        case .tutorial: return "DREI AKTE · EIN RHYTHMUS"
        case .help: return "REGELN · MULDE · KETTE"
        case .settings: return "TISCH · MATERIAL · FEEDBACK"
        }
    }

    private func overlayTint(_ overlay: AppOverlay) -> Color {
        switch overlay {
        case .menu: return guidedTint
        case .tutorial: return Tokens.jewelGold
        case .help: return Tokens.jewelSmaragd
        case .settings: return Tokens.jewelAmethyst
        }
    }

    private func overlayTabs(_ selected: AppOverlay) -> some View {
        HStack(spacing: 6) {
            overlayTab(.tutorial, selected: selected, icon: "graduationcap.fill", title: "Lernen")
            overlayTab(.help, selected: selected, icon: "book.closed.fill", title: "Regeln")
            overlayTab(.settings, selected: selected, icon: "slider.horizontal.3", title: "Tisch")
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.045))
            .overlay(Capsule().strokeBorder(Tokens.jewelGold.opacity(0.14), lineWidth: 1)))
    }

    private func overlayTab(_ overlay: AppOverlay, selected: AppOverlay,
                            icon: String, title: String) -> some View {
        let active = overlay == selected
        let tint = overlayTint(overlay)
        return Button { activeOverlay = overlay } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .bold))
                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(active
                             ? overlayActiveForeground(overlay)
                             : Tokens.jewelPlatin.opacity(0.70))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Capsule().fill(active ? tint.opacity(0.92) : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private var tutorialContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            overlayHero(String(localized: "tutorial.firstTable.title", defaultValue: "Dein erster Tisch"),
                        String(localized: "tutorial.firstTable.body", defaultValue: "Du spielst sofort. Mira erklärt immer nur die eine Entscheidung, die jetzt zählt."),
                        tint: Tokens.jewelGold)
            tutorialLessonPicker
            coachBubble("Hana", String(localized: "tutorial.coach.body", defaultValue: "Drei Akte, drei klare Ziele. Ich bleibe am Tisch, bis du den Rhythmus selbst fühlst."))
            tutorialDecisionRail
            tutorialProgressStrip
            overlayStep("1",
                        String(localized: "tutorial.inline.title", defaultValue: "Direkt im Spiel lernen"),
                        String(localized: "tutorial.inline.body", defaultValue: "Hinweise erscheinen nur am aktuellen Zug. Regeln und Beispiele bleiben jederzeit im Reiter Regeln verfügbar."))
        }
    }

    private var tutorialLessonPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(String(localized: "tutorial.lesson.picker.title",
                            defaultValue: "Einstieg wählen"))
                    .font(.system(size: 13.5, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
                Spacer()
                Text("\(completedTutorialCount)/3")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Tokens.jewelGold.opacity(0.86))
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                ForEach(TutorialLesson.allCases) { lesson in
                    tutorialLessonButton(lesson)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.034))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tutorialLessonTint(selectedTutorialLesson).opacity(0.18), lineWidth: 1)))
    }

    private func tutorialLessonButton(_ lesson: TutorialLesson) -> some View {
        let selected = selectedTutorialLesson == lesson
        let tint = tutorialLessonTint(lesson)
        return Button {
            selectedTutorialLesson = lesson
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 5) {
                    Image(systemName: tutorialLessonIcon(lesson))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selected ? tint : Tokens.slate)
                    Text(tutorialLessonTitle(lesson))
                        .font(.system(size: 9.2, weight: .heavy))
                        .foregroundStyle(selected ? Tokens.jewelPlatin : Tokens.slate)
                        .lineLimit(1)
                    Text(tutorialLessonBody(lesson))
                        .font(.system(size: 7.8, weight: .semibold))
                        .foregroundStyle(Tokens.slate.opacity(0.80))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity)

                if tutorialIsComplete(lesson) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(Tokens.bgDeep)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(tint))
                        .padding(5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 11)
                .fill(selected ? tint.opacity(0.12) : Color.black.opacity(0.16))
                .overlay(RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(tint.opacity(selected ? 0.55 : 0.12), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func tutorialLessonTitle(_ lesson: TutorialLesson) -> String {
        switch lesson {
        case .meld:
            return String(localized: "tutorial.lesson.meld.title", defaultValue: "Melden")
        case .bidding:
            return String(localized: "tutorial.lesson.bidding.title", defaultValue: "Pochen")
        case .playout:
            return String(localized: "tutorial.lesson.playout.title", defaultValue: "Ausspielen")
        }
    }

    private func tutorialLessonBody(_ lesson: TutorialLesson) -> String {
        switch lesson {
        case .meld:
            return String(localized: "tutorial.lesson.meld.body", defaultValue: "von Anfang an")
        case .bidding:
            return String(localized: "tutorial.lesson.bidding.body", defaultValue: "Paar und Druck")
        case .playout:
            return String(localized: "tutorial.lesson.playout.body", defaultValue: "Kette und Riss")
        }
    }

    private func tutorialLessonTint(_ lesson: TutorialLesson) -> Color {
        switch lesson {
        case .meld: return Tokens.jewelGold
        case .bidding: return Tokens.jewelAmethyst
        case .playout: return Tokens.jewelSmaragd
        }
    }

    private func tutorialLessonIcon(_ lesson: TutorialLesson) -> String {
        switch lesson {
        case .meld: return "circle.grid.3x3.fill"
        case .bidding: return "hand.raised.fill"
        case .playout: return "rectangle.stack.fill"
        }
    }

    private var tutorialDecisionRail: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("So begleitet dich die erste Runde")
                .font(.system(size: 13.5, weight: .heavy))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
            HStack(spacing: 8) {
                tutorialDecisionChip("sehen", "welche Mulde zahlt", Tokens.jewelGold)
                tutorialDecisionChip("wägen", "ob Pochen lohnt", Tokens.jewelAmethyst)
                tutorialDecisionChip("spielen", "welche Karte führt", Tokens.jewelSmaragd)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.034))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Tokens.jewelGold.opacity(0.15), lineWidth: 1)))
    }

    private func tutorialDecisionChip(_ title: String, _ text: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(tint.opacity(0.92))
                .lineLimit(1)
            Text(text)
                .font(.system(size: 8.6, weight: .semibold))
                .foregroundStyle(Tokens.slate.opacity(0.88))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .padding(.horizontal, 5)
        .background(RoundedRectangle(cornerRadius: 11)
            .fill(Color.black.opacity(0.18))
            .overlay(RoundedRectangle(cornerRadius: 11)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)))
    }

    private var menuPhaseStrip: some View {
        HStack(spacing: 8) {
            phaseToken("1", "Melden", active: akt == .melden, tint: Tokens.jewelGold)
            Capsule().fill(Tokens.slate.opacity(0.18)).frame(height: 1)
            phaseToken("2", "Pochen", active: akt == .pochen, tint: Tokens.jewelAmethyst)
            Capsule().fill(Tokens.slate.opacity(0.18)).frame(height: 1)
            phaseToken("3", "Ausspielen", active: akt == .ausspielen, tint: Tokens.jewelSmaragd)
        }
        .padding(.horizontal, 4)
    }

    private func phaseToken(_ mark: String, _ title: String, active: Bool, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(mark)
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundStyle(active ? Tokens.bgDeep : Tokens.slate)
                .frame(width: 24, height: 24)
                .background(Circle().fill(active ? tint : Color.white.opacity(0.055)))
                .overlay(Circle().strokeBorder(tint.opacity(active ? 0.0 : 0.25), lineWidth: 1))
            Text(title)
                .font(.system(size: 8.2, weight: .semibold))
                .foregroundStyle(active ? Tokens.jewelPlatin : Tokens.slate.opacity(0.72))
                .lineLimit(1)
        }
        .frame(width: 64)
    }

    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            overlayHero(menuHeroTitle, menuHeroText, tint: guidedTint)
            HStack(spacing: 8) {
                menuMetric("Phase", menuMetricPhase, guidedTint)
                menuMetric("Trumpf", "\(game.upcard.rank.index)\(game.upcard.suit.symbol)", Tokens.jewelGold)
                menuMetric("Mitte", "\(game.displayedChips(in: .center))", Tokens.jewelPlatin)
            }
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    menuActionButton("Regeln", systemImage: "book.closed.fill", tint: Tokens.jewelSmaragd) {
                        activeOverlay = .help
                    }
                    menuActionButton("Tisch", systemImage: "slider.horizontal.3", tint: Tokens.jewelAmethyst) {
                        activeOverlay = .settings
                    }
                }
                HStack(spacing: 8) {
                    menuActionButton("Tutorial", systemImage: "graduationcap.fill", tint: Tokens.jewelGold) {
                        activeOverlay = .tutorial
                    }
                    menuActionButton("Neue Runde", systemImage: "arrow.clockwise", tint: Tokens.jewelRose) {
                        activeOverlay = nil
                        startNewRound()
                    }
                }
            }
            if guidedRoundActive {
                overlayStep("✓", "Geführte Runde aktiv", "Der Coach bleibt am Tisch und erklärt nur den nächsten Schritt.")
            } else {
                overlayStep("?", "Lernen ohne Druck", "Starte jederzeit eine geführte Runde über das Tutorial.")
            }
        }
    }

    private var menuHeroTitle: String {
        switch akt {
        case .melden: return "Tisch angehalten"
        case .pochen: return "Druckmoment pausiert"
        case .ausspielen: return "Kartenstrom pausiert"
        }
    }

    private var menuHeroText: String {
        switch akt {
        case .melden:
            return "Meldewerte und Mitte bleiben sichtbar. Du kannst fortsetzen, Regeln prüfen oder den Tisch neu starten."
        case .pochen:
            return "Der Einsatzstand bleibt erhalten. Prüfe Hilfe oder Einstellungen, ohne den Bietfluss zu verlieren."
        case .ausspielen:
            return "Anspielrecht, Centerpot und Hand bleiben erhalten. Der nächste Kartenimpuls wartet auf dich."
        }
    }

    private var menuMetricPhase: String {
        switch akt {
        case .melden: return "1"
        case .pochen: return "2"
        case .ausspielen: return "3"
        }
    }

    private func menuMetric(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 7.4, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(Tokens.slate.opacity(0.76))
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.038))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)))
    }

    private func menuActionButton(_ title: String, systemImage: String, tint: Color,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12.5, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.052))
                .overlay(Capsule().strokeBorder(tint.opacity(0.34), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            overlayHero("Schnellhilfe", "Alles Wichtige bleibt am Tisch sichtbar. Diese Seite ist die kompakte Regelkarte.")
            rulesGrid
            visualRuleExamples
            glossaryStrip
            tableReadingStrip
            overlayStep("A", "9 Mulden", "A, K, Q, J, 10, Mariage, Sequenz, Poch und Mitte. Außen wird gemeldet, innen wird am Ende gewonnen.")
            overlayStep("K", "Mariage", "König und Dame einer Farbe. In Trumpf zählt sie stärker.")
            overlayStep("Q", "Sequenz", "Zusammenhängende Karten einer Farbe. Trumpf entscheidet, wenn nötig.")
            overlayStep("J", "Poch", "Bieten nur mit Paar. Passen gibt Information, Mitgehen hält Druck, Erhöhen setzt die Wand.")
            overlayStep("10", "Ketten", "Ausspielen läuft aufsteigend weiter. Fehlt die nächste Karte, wechselt das Anspiel.")
        }
    }

    private var tableReadingStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Am Tisch lesen")
                .font(.system(size: 13.5, weight: .heavy))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
            tableReadRow("Farbiger Muldenrand", "zeigt Kategorie und Ziel der Chips", Tokens.jewelGold)
            tableReadRow("Violette Mitte", "Poch-Mulde: nur Paare kämpfen darum", Tokens.jewelAmethyst)
            tableReadRow("Großer Kartenfächer", "Kettenphase: jetzt zählt Reihenfolge", Tokens.jewelSmaragd)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.032))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Tokens.jewelSmaragd.opacity(0.16), lineWidth: 1)))
    }

    private func tableReadRow(_ title: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 4)
                .fill(tint.opacity(0.82))
                .frame(width: 5, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11.7, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
                Text(text)
                    .font(.system(size: 9.4, weight: .semibold))
                    .foregroundStyle(Tokens.slate.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
    }

    private var glossaryStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Begriffe")
                .font(.system(size: 13.5, weight: .heavy))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                glossaryChip("Trumpf", "entscheidet Gleichstand", Tokens.jewelGold)
                glossaryChip("Mitte", "Hauptpott am Ende", Tokens.jewelPlatin)
                glossaryChip("Wand", "aktuelles Bietlimit", Tokens.jewelAmethyst)
                glossaryChip("Kette", "laufende Kartenfolge", Tokens.jewelSmaragd)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.032))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Tokens.jewelGold.opacity(0.16), lineWidth: 1)))
    }

    private func glossaryChip(_ title: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint.opacity(0.82))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11.5, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
                Text(text)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Tokens.slate)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.20))
            .overlay(Capsule().strokeBorder(tint.opacity(0.20), lineWidth: 1)))
    }

    private var visualRuleExamples: some View {
        VStack(spacing: 8) {
            visualRuleExample("Melden",
                              "Werte und Figuren räumen Außenmulden ab.",
                              tint: Tokens.jewelGold,
                              visual: .meld)
            visualRuleExample("Pochen",
                              "Ein Paar eröffnet das Pochen. Das Limit begrenzt den Einsatz.",
                              tint: Tokens.jewelAmethyst,
                              visual: .poch)
            visualRuleExample("Ausspielen",
                              "Ketten laufen weiter, bis die nächste Karte fehlt.",
                              tint: Tokens.jewelSmaragd,
                              visual: .play)
        }
    }

    private enum RuleExampleVisual { case meld, poch, play }

    private func visualRuleExample(_ title: String, _ text: String,
                                   tint: Color,
                                   visual: RuleExampleVisual) -> some View {
        HStack(spacing: 12) {
            ruleExampleVisual(visual, tint: tint)
                .frame(width: 82, height: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .heavy))
                    .foregroundStyle(tint)
                Text(text)
                    .font(.system(size: 10.6, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.035))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)))
    }

    @ViewBuilder private func ruleExampleVisual(_ visual: RuleExampleVisual, tint: Color) -> some View {
        switch visual {
        case .meld:
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(Color.black.opacity(0.40))
                        .overlay(Circle().strokeBorder(i == 2 ? tint.opacity(0.82) : tint.opacity(0.35),
                                                       lineWidth: i == 2 ? 1.8 : 1))
                        .frame(width: 27, height: 27)
                        .offset(x: CGFloat(i - 2) * 17, y: CGFloat(abs(i - 2)) * 4 - 1)
                }
                HStack(spacing: -10) {
                    CardFace(card: Card(suit: .spades, rank: .ace), scale: 0.34)
                    CardFace(card: Card(suit: .diamonds, rank: .queen), scale: 0.34)
                }
                .rotationEffect(.degrees(-7), anchor: .bottom)
                .offset(x: -24, y: 7)
                HStack(spacing: -2) {
                    ForEach(0..<3, id: \.self) { i in
                        R1Token(tint: tint, size: 8.5)
                            .offset(y: CGFloat(i) * -2)
                    }
                }
                .offset(x: 28, y: 7)
            }
        case .poch:
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.34))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Tokens.jewelGold.opacity(0.25), lineWidth: 1))
                    .frame(width: 16, height: 52)
                    .offset(x: -36)
                RoundedRectangle(cornerRadius: 5)
                    .fill(tint.opacity(0.72))
                    .frame(width: 10, height: 22)
                    .offset(x: -36, y: 13)
                HStack(spacing: -14) {
                    CardFace(card: Card(suit: .hearts, rank: .king), scale: 0.38)
                    CardFace(card: Card(suit: .clubs, rank: .king), scale: 0.38)
                }
                .offset(x: 0, y: 4)
                Circle()
                    .fill(Color.black.opacity(0.44))
                    .overlay(Circle().strokeBorder(tint.opacity(0.60), lineWidth: 1.5))
                    .frame(width: 34, height: 34)
                    .offset(x: 37, y: 8)
                Text("7")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(tint)
                    .offset(x: 37, y: 8)
            }
        case .play:
            ZStack {
                HStack(spacing: -13) {
                    CardFace(card: Card(suit: .clubs, rank: .seven), scale: 0.38)
                        .rotationEffect(.degrees(-10), anchor: .bottom)
                    CardFace(card: Card(suit: .clubs, rank: .eight), scale: 0.38)
                    CardFace(card: Card(suit: .clubs, rank: .nine), scale: 0.38)
                        .rotationEffect(.degrees(10), anchor: .bottom)
                }
                .offset(x: -10, y: 4)
                Circle()
                    .fill(tint.opacity(0.85))
                    .frame(width: 8, height: 8)
                    .offset(x: 38, y: -17)
                Text("RISS")
                    .font(.system(size: 7.5, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(tint)
                    .offset(x: 39, y: -4)
            }
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            overlayHero("Tischgefühl", "Regeln und Information bleiben gleich. Du wählst nur Tisch und Material.")
            settingRow("Tisch", "Poch Disc · Graphit und R1", tint: Tokens.jewelGold)
            playerCountPicker
            settingToggle("Sound", "Vorbereitet für Münzen, Tischschlag und Kartenstrom.", isOn: $sound, tint: Tokens.jewelGold)
            settingToggle("Haptik", "Münzflüge, Poch-Schlag und Kettenstopps fühlbar machen.", isOn: $haptics, tint: Tokens.jewelGold)
            settingToggle("Assist-Hinweise", "Kurze Kontext-Hinweise, ohne verdeckte Karten zu verraten.", isOn: $assistHints, tint: Tokens.jewelSmaragd)
            settingToggle("Zug-Begleiter", "Erklärt Optionen, Risiko und nächsten Fokus während der Runde.", isOn: $moveCoach, tint: Tokens.jewelSmaragd)
            settingToggle("Tischeffekte", "Kartenwölbung, Schatten, Münzstrom und kurze Akzente.", isOn: $tableEffects, tint: Tokens.jewelAmethyst)
            settingRow("Bewegung", "Folgt iOS Reduce Motion", tint: Tokens.slate)
            settingRow("Sprache", "Deutsch · vorbereitet", tint: Tokens.jewelSmaragd)
            settingRow("Tutorial", "Wiederholen über den Hut-Button", tint: Tokens.jewelGold)
            settingRow("Rechtliches", "Impressum/Datenschutz vorbereitet", tint: Tokens.slate)
            HStack(spacing: 8) {
                overlayInlineButton("Neue Runde", tint: Tokens.jewelGold) {
                    activeOverlay = nil
                    startNewRound()
                }
                overlayInlineButton("Tutorial", tint: Tokens.jewelSmaragd) {
                    activeOverlay = .tutorial
                }
            }
            #if DEBUG
            settingRow("DEBUG", "-pochenStart · -ausspielStart · -holdPlayout", tint: Tokens.amethystText)
            #endif
        }
    }

    private var playerCountPicker: some View {
        HStack(spacing: 12) {
            Circle().fill(Tokens.jewelGold.opacity(0.78)).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text("Spieler")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
                Text(String(localized: "settings.players.body",
                            defaultValue: "3 bis 6 Personen. Der Tisch ordnet alle Plätze neu."))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            HStack(spacing: 5) {
                ForEach(3...6, id: \.self) { count in
                    playerCountButton(count)
                }
            }
            .padding(4)
            .background(Capsule().fill(Color.white.opacity(0.045))
                .overlay(Capsule().strokeBorder(Tokens.jewelGold.opacity(0.22), lineWidth: 1)))
        }
        .padding(.vertical, 2)
    }

    private func playerCountButton(_ count: Int) -> some View {
        let selected = playerCount == count
        return Button {
            playerCount = count
            game.configurePlayerCount(count)
            transition(to: .melden)
            game.runDealPresentation(reduceMotion: reduceMotion)
        } label: {
            Text("\(count)")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(selected ? Tokens.bgDeep : Tokens.slate)
                .frame(width: 34, height: 28)
                .background(Capsule().fill(selected ? Tokens.jewelGold : Color.clear))
                .overlay(Capsule().strokeBorder(selected ? Tokens.jewelPlatin.opacity(0.20) : Color.white.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var tutorialProgressStrip: some View {
        HStack(spacing: 8) {
            tutorialBeat("1", "Melden", .meld, Tokens.jewelGold)
            Capsule().fill(Tokens.slate.opacity(0.25)).frame(height: 1)
            tutorialBeat("2", "Pochen", .bidding, Tokens.jewelAmethyst)
            Capsule().fill(Tokens.slate.opacity(0.25)).frame(height: 1)
            tutorialBeat("3", "Ausspielen", .playout, Tokens.jewelSmaragd)
        }
        .padding(.horizontal, 4)
    }

    private func tutorialBeat(_ mark: String, _ title: String,
                              _ lesson: TutorialLesson, _ tint: Color) -> some View {
        let complete = tutorialIsComplete(lesson)
        return VStack(spacing: 4) {
            Text(complete ? "✓" : mark)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Tokens.bgDeep)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint))
            Text(title)
                .font(.system(size: 8.2, weight: .semibold))
                .foregroundStyle(Tokens.slate)
                .lineLimit(1)
        }
        .frame(width: 58)
    }

    @ViewBuilder private func overlayFooter(_ overlay: AppOverlay) -> some View {
        switch overlay {
        case .menu:
            overlayPrimaryButton("Weiter spielen", tint: guidedTint) {
                activeOverlay = nil
            }
        case .tutorial:
            overlayPrimaryButton(String(localized: "tutorial.lesson.start",
                                        defaultValue: "Lektion starten"),
                                 tint: tutorialLessonTint(selectedTutorialLesson)) {
                startGuidedRound(selectedTutorialLesson)
            }
        case .help:
            HStack(spacing: 8) {
                overlayInlineButton("Tutorial", tint: Tokens.jewelGold) {
                    activeOverlay = .tutorial
                }
                overlayInlineButton("Schließen", tint: Tokens.jewelSmaragd) {
                    activeOverlay = nil
                }
            }
        case .settings:
            overlayPrimaryButton("Fertig", tint: Tokens.jewelAmethyst) {
                activeOverlay = nil
            }
        }
    }

    private func overlayPrimaryButton(_ title: String, tint: Color,
                                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .heavy))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [
                            Color.white.opacity(0.07),
                            tint.opacity(0.23),
                            Color.black.opacity(0.20)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Capsule().strokeBorder(tint.opacity(0.58), lineWidth: 1))
                        .shadow(color: .black.opacity(0.34), radius: 10, y: 5)
                )
        }
        .buttonStyle(.plain)
    }

    private func overlayInlineButton(_ title: String, tint: Color,
                                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.white.opacity(0.045))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func overlayActiveForeground(_ overlay: AppOverlay) -> Color {
        overlay == .settings || overlay == .menu ? Tokens.jewelPlatin : Tokens.bgDeep
    }

    private func overlayHero(_ title: String, _ text: String, tint: Color = Tokens.jewelGold) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Tokens.slate)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)))
    }

    private enum GuideVisual { case ring, bid, fan }

    private func coachBubble(_ name: String, _ text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            OpponentPortrait(seat: 1,
                             name: name,
                             isActive: true,
                             isFocus: true,
                             size: 44,
                             showsText: false,
                             morph: morph)
            VStack(alignment: .leading, spacing: 3) {
                Text(name.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(Tokens.jewelGold.opacity(0.86))
                Text(text)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Tokens.jewelGold.opacity(0.18), lineWidth: 1)))
    }

    private func phaseGuide(_ mark: String, _ title: String, _ text: String,
                            tint: Color, visual: GuideVisual) -> some View {
        HStack(spacing: 12) {
            guideVisual(visual, tint: tint)
                .frame(width: 74, height: 58)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(mark)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Tokens.bgDeep)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(tint))
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Tokens.jewelPlatin)
                }
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.035))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)))
    }

    @ViewBuilder private func guideVisual(_ visual: GuideVisual, tint: Color) -> some View {
        switch visual {
        case .ring:
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.22))
                    .overlay(Circle().strokeBorder(Tokens.jewelGold.opacity(0.40), lineWidth: 1))
                    .frame(width: 54, height: 54)
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(i % 2 == 0 ? Tokens.jewelGold.opacity(0.88) : tint.opacity(0.80))
                        .frame(width: 7, height: 7)
                        .offset(y: -22)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
                Circle()
                    .fill(Tokens.jewelPlatin.opacity(0.22))
                    .overlay(Circle().strokeBorder(Tokens.jewelPlatin.opacity(0.45), lineWidth: 1))
                    .frame(width: 23, height: 23)
            }
        case .bid:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.black.opacity(0.30))
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(tint.opacity(0.72))
                            .frame(width: 13, height: 29)
                            .padding(.bottom, 4)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Tokens.jewelGold.opacity(0.26), lineWidth: 1))
                    .frame(width: 24, height: 52)
                VStack(spacing: 3) {
                    Text("EINSATZ")
                        .font(.system(size: 6, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(Tokens.slate)
                    Text("7")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(tint)
                }
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.16))
                    .overlay(Circle().strokeBorder(tint.opacity(0.48), lineWidth: 1)))
            }
        case .fan:
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.black.opacity(0.18), lineWidth: 1))
                        .frame(width: 28, height: 40)
                        .rotationEffect(.degrees(Double(i - 1) * 13))
                        .offset(x: CGFloat(i - 1) * 13, y: CGFloat(abs(i - 1)) * 2)
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                }
                Circle()
                    .fill(Color(hex: 0x17141D))
                    .overlay(Circle().strokeBorder(tint.opacity(0.74), lineWidth: 1.5))
                    .frame(width: 28, height: 28)
                    .offset(y: 10)
            }
        }
    }

    private var rulesGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ruleTile("A K Q J 10", "Werte", Tokens.jewelGold)
            ruleTile("K+Q", "Mariage", Tokens.jewelRose)
            ruleTile("7-10", "Sequenz", Tokens.jewelSmaragd)
            ruleTile("Paar", "Poch", Tokens.jewelAmethyst)
            ruleTile("Mitte", "Finale", Tokens.jewelPlatin)
            ruleTile("Leer", "Sieg", theme.smaragdFocus)
        }
    }

    private func ruleTile(_ mark: String, _ title: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(mark)
                .font(.system(size: mark.count > 5 ? 9 : 12, weight: .heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Tokens.slate)
                .lineLimit(1)
        }
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.035))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)))
    }

    private func overlayStep(_ mark: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(mark)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Tokens.bgDeep)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Tokens.jewelGold))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin)
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingRow(_ title: String, _ value: String, tint: Color) -> some View {
        HStack {
            Circle().fill(tint.opacity(0.75)).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.9))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.slate)
        }
        .padding(.vertical, 2)
    }

    private func settingToggle(_ title: String, _ text: String,
                               isOn: Binding<Bool>, tint: Color) -> some View {
        HStack(spacing: 12) {
            Circle().fill(tint.opacity(0.78)).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
                Text(text)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(tint)
        }
        .padding(.vertical, 2)
    }

    private var trumpChip: some View {
        let up = game.upcard
        // Der Trumpf bleibt verdeckt, bis der Beat ihn flippt (§6a)
        let revealed = game.trumpRevealed || akt != .melden
        return HStack(spacing: 5) {
            Text("Trumpf").font(.system(size: 12, weight: .medium)).foregroundStyle(Tokens.slate)
            Text(revealed ? "\(up.rank.index)\(up.suit.symbol)" : "· ·")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(revealed
                                 ? (up.suit.isRed ? Color(hex: 0xD07A85) : Tokens.jewelPlatin)
                                 : Tokens.slate)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: revealed)
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.05))
            .overlay(Capsule().strokeBorder(Tokens.jewelGold.opacity(0.35), lineWidth: 1)))
        .padding(.top, 3)
    }

    // MARK: - §5c Phase-1: Gegner als schmale Top-Bar

    private var opponentTopBar: some View {
        HStack(spacing: 20) {
            ForEach(1..<game.playerCount, id: \.self) { seat in
                OpponentPortrait(seat: seat,
                                 name: game.name(of: seat),
                                 stack: game.displayedStack(of: seat),
                                 isActive: true,
                                 isFocus: false,
                                 size: 34,
                                 morph: morph)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: game.meldShown)
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Der Poch-Ring

    /// Phase 1 folgt dem Mockup: Brett als Hauptdarsteller, keine Gegnerleiste im
    /// ersten Blick, Kartenfächer als unterer Bleed.
    @ViewBuilder private var phase1Stage: some View {
        if isGuidedOpeningBeat {
            guidedOpeningStage
        } else if guidedRoundActive {
            guidedMeldLearningStage
        } else {
            regularPhase1Stage
        }
    }

    private var guidedOpeningStage: some View {
        GeometryReader { proxy in
            let zones = FirstRunStageZones.resolve(in: proxy.size,
                                                   safeArea: proxy.safeAreaInsets)
            let ringDiameter = Tokens.ringRadius * 2 + Tokens.tileDiameter
            let boardScale = zones.board.width / ringDiameter

            ZStack {
                guidedOpponentAxis(in: zones)

                if guidedTableFundingTargeted {
                    Path { path in
                        path.move(to: CGPoint(x: zones.opponents.midX,
                                              y: zones.opponents.midY))
                        path.addLine(to: CGPoint(x: zones.board.midX,
                                                y: zones.board.midY))
                    }
                    .stroke(Tokens.jewelGold.opacity(0.74),
                            style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                ringView
                    .scaleEffect(boardScale)
                    .frame(width: ringDiameter, height: ringDiameter)
                    .position(x: zones.board.midX, y: zones.board.midY)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("firstRun.learningBoard")

                guidedOpeningInteraction(in: proxy.size, focus: zones.board)
            }
            .onChange(of: proxy.size) { _, _ in
                guard guidedOpeningDrag != .zero else { return }
                if guidedOpeningSettled {
                    completeGuidedOpeningImpact()
                } else {
                    guidedOpeningDrag = .zero
                }
            }
        }
    }

    @ViewBuilder private var regularPhase1Stage: some View {
        if verticalSizeClass == .compact {
            regularPhase1LandscapeStage
        } else {
            regularPhase1PortraitStage
        }
    }

    private var regularPhase1PortraitStage: some View {
        let dealActive = game.dealtCount < game.totalDeals && !game.trumpRevealed
        let boardScale = guidedRoundActive
            ? Tokens.guidedMeldBoardScale
            : (dealActive ? 0.82 : 0.90)
        let boardOffset = guidedRoundActive
            ? Tokens.guidedMeldBoardOffsetY
            : (dealActive ? 72 : 0)
        return VStack(spacing: 0) {
            ringView
                .scaleEffect(boardScale)
                .offset(y: boardOffset)
                .contentShape(Circle())
                .onTapGesture {
                    if game.humanDealtVisible < game.humanHand.count {
                        game.skipDeal()
                    } else {
                        transition(to: .pochen)
                    }
                }
                .animation(.spring(response: 0.62, dampingFraction: 0.86),
                           value: boardScale)
                .padding(.top, 4)
            Spacer(minLength: 0)
            handView
                .offset(y: -178)
                .padding(.bottom, -178)
        }
    }

    /// Landscape ist keine gedrehte Portrait-Spalte: Hand und Disc besitzen
    /// getrennte Bühnenhälften und können sich deshalb nicht gegenseitig decken.
    private var regularPhase1LandscapeStage: some View {
        GeometryReader { proxy in
            let ringDiameter = Tokens.ringRadius * 2 + Tokens.tileDiameter
            let boardSide = min(proxy.size.height * 0.84,
                                proxy.size.width * 0.42,
                                300)
            ZStack {
                ringView
                    .frame(width: ringDiameter, height: ringDiameter)
                    .scaleEffect(boardSide / ringDiameter)
                    .position(x: proxy.size.width * 0.74,
                              y: proxy.size.height * 0.48)
                    .contentShape(Circle())
                    .onTapGesture {
                        if game.humanDealtVisible < game.humanHand.count {
                            game.skipDeal()
                        } else {
                            transition(to: .pochen)
                        }
                    }

                landscapeHandView
                    .frame(width: proxy.size.width * 0.46,
                           height: min(104, proxy.size.height * 0.44),
                           alignment: .bottom)
                    .position(x: proxy.size.width * 0.24,
                              y: proxy.size.height - 26)
            }
        }
    }

    /// Geführtes Melden besitzt eine eigene, kollisionsfreie Lernbühne. Das
    /// freie Spiel bleibt groß und mockup-nah; im Tutorial werden Brett,
    /// Erklärung und Hand dagegen als drei feste vertikale Zonen komponiert.
    private var guidedMeldLearningStage: some View {
        GeometryReader { proxy in
            if dynamicTypeSize.isAccessibilitySize {
                guidedMeldAccessibilityStage(in: proxy.size)
            } else {
                guidedMeldSpatialStage(in: proxy)
            }
        }
    }

    private func guidedMeldAccessibilityStage(in size: CGSize) -> some View {
        let ringDiameter = Tokens.ringRadius * 2 + Tokens.tileDiameter
        let landscape = size.width > size.height
        let boardSide = landscape
            ? min(size.width - 44, size.height * 0.54, 132)
            : min(size.width - 44, 260)
        let handHeight = landscape
            ? min(132, size.height * 0.54)
            : max(132, min(180, size.height * 0.34))
        return ScrollView(.vertical) {
            VStack(spacing: 18) {
                HStack(spacing: 28) {
                    ForEach(1..<game.playerCount, id: \.self) { seat in
                        firstRunOpponent(name: game.name(of: seat), seat: seat)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 72)

                ringView
                    .frame(width: ringDiameter, height: ringDiameter)
                    .scaleEffect(boardSide / ringDiameter)
                    .frame(width: boardSide, height: boardSide)
                    .contentShape(Circle())
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("firstRun.learningBoard")

                guidedCoachRail
                    .frame(width: min(size.width - 36, guidedCoachWidth))
                    .opacity(guidedMeldBusy ? 0 : 1)
                    .allowsHitTesting(!guidedMeldBusy)

                ZStack(alignment: .bottom) {
                    Group {
                        if landscape {
                            landscapeHandView
                        } else {
                            handView
                        }
                    }
                    .frame(width: size.width - 24,
                           height: handHeight,
                           alignment: .bottom)
                    .clipped()

                    // Der messbare Handbereich entspricht dem wirklich sichtbaren
                    // Clip. Die einzelnen Karten bleiben zusätzlich als eigene
                    // VoiceOver-Elemente erreichbar.
                    Color.clear
                        .accessibilityElement()
                        .accessibilityLabel(String(localized: "tutorial.meld.hand.title",
                                                   defaultValue: "Deine Hand"))
                        .accessibilityIdentifier("firstRun.learningHand")
                }
                .frame(width: size.width - 24,
                       height: handHeight,
                       alignment: .bottom)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("firstRun.learningScroll")
        .animation(.easeOut(duration: 0.18), value: guidedMeldBusy)
    }

    private func guidedMeldSpatialStage(in proxy: GeometryProxy) -> some View {
        let zones = FirstRunStageZones.resolve(in: proxy.size,
                                               safeArea: proxy.safeAreaInsets)
        let ringDiameter = Tokens.ringRadius * 2 + Tokens.tileDiameter
        let boardScale = zones.board.width / ringDiameter
        return ZStack {
            guidedOpponentAxis(in: zones)

            if guidedTableFundingTargeted {
                Path { path in
                    path.move(to: CGPoint(x: zones.opponents.midX,
                                          y: zones.opponents.midY))
                    path.addLine(to: CGPoint(x: zones.board.midX,
                                            y: zones.board.midY))
                }
                .stroke(Tokens.jewelGold.opacity(0.74),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            ringView
                .scaleEffect(boardScale)
                .frame(width: ringDiameter, height: ringDiameter)
                .position(x: zones.board.midX, y: zones.board.midY)
                .contentShape(Circle())
                .allowsHitTesting(false)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("firstRun.learningBoard")

            if guidedMeldBeat == FirstRunBeat.connectMeld.rawValue
                || guidedMeldBeat == FirstRunBeat.proveMeld.rawValue {
                guidedMeldConnection(in: zones, ringDiameter: ringDiameter)
            }

            guidedCoachViewport(in: zones)

            handView
                .frame(width: zones.hand.width,
                       height: zones.hand.height,
                       alignment: .bottom)
                .clipped()
                .position(x: zones.hand.midX, y: zones.hand.midY)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("firstRun.learningHand")
        }
        .animation(.easeOut(duration: 0.18), value: guidedMeldBusy)
    }

    private func guidedCoachViewport(in zones: FirstRunStageZones) -> some View {
        ScrollView(.vertical) {
            guidedCoachRail
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: min(zones.decision.width, guidedCoachWidth),
               height: zones.decision.height,
               alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .position(x: zones.decision.midX, y: zones.decision.midY)
        .opacity(guidedMeldBusy ? 0 : 1)
        .allowsHitTesting(!guidedMeldBusy)
    }

    private func guidedMeldConnection(in zones: FirstRunStageZones,
                                      ringDiameter: CGFloat) -> some View {
        let well = PochDiscGeometry.wellCenter(for: guidedIntroPool, in: ringDiameter)
        let wellPoint = CGPoint(
            x: zones.board.minX + well.x / ringDiameter * zones.board.width,
            y: zones.board.minY + well.y / ringDiameter * zones.board.height
        )
        let cardPoint = guidedMeldCardPoint(in: zones.hand)

        return ZStack {
            Path { path in
                path.move(to: cardPoint)
                path.addLine(to: wellPoint)
            }
            .stroke(Tokens.jewelGold.opacity(0.82),
                    style: StrokeStyle(lineWidth: 1,
                                       lineCap: .round,
                                       dash: [3, 4]))

            Circle()
                .fill(Tokens.jewelGold)
                .frame(width: 6, height: 6)
                .position(cardPoint)
            Circle()
                .fill(Tokens.jewelGold)
                .frame(width: 6, height: 6)
                .position(wellPoint)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func guidedMeldCardPoint(in hand: CGRect) -> CGPoint {
        let cards = Array(game.humanHand.prefix(game.humanDealtVisible))
        let index = cards.firstIndex(where: { $0.rank == guidedIntroRank }) ?? 0
        let count = cards.count
        let totalWidth = min(CGFloat(count) * 30, 224)
        let progress = count > 1 ? CGFloat(index) / CGFloat(count - 1) : 0.5
        return CGPoint(x: hand.midX - totalWidth / 2 + progress * totalWidth,
                       y: hand.minY + 30)
    }

    private var guidedIntroRank: Rank {
        switch guidedIntroPool {
        case .ace: .ace
        case .king: .king
        case .queen: .queen
        case .jack: .jack
        case .ten: .ten
        case .mariage: .king
        case .sequence, .poch, .center: .ace
        }
    }

    @ViewBuilder
    private func guidedOpponentAxis(in zones: FirstRunStageZones) -> some View {
        if zones.isLandscape {
            VStack(spacing: 8) {
                ForEach(1..<game.playerCount, id: \.self) { seat in
                    firstRunOpponent(name: game.name(of: seat), seat: seat)
                }
            }
            .frame(width: zones.opponents.width, height: zones.opponents.height)
            .position(x: zones.opponents.midX, y: zones.opponents.midY)
        } else {
            HStack(spacing: 28) {
                ForEach(1..<game.playerCount, id: \.self) { seat in
                    firstRunOpponent(name: game.name(of: seat), seat: seat)
                }
            }
            .frame(width: zones.opponents.width, height: zones.opponents.height)
            .position(x: zones.opponents.midX, y: zones.opponents.midY)
        }
    }

    private var ringView: some View {
        let d = Tokens.ringRadius * 2 + Tokens.tileDiameter
        // .position statt .offset: echte Layout-Frames, damit matchedGeometryEffect
        // beim Morph die korrekten Flugbahnen misst (§5b).
        return ZStack {
            TableWorldBoardBase(world: theme, diameter: d)
                .position(x: d / 2, y: d / 2)
            if guidedRoundActive && guidedMeldBeat == 0 {
                guidedBoardVeil(size: d,
                                focusPools: [.center, guidedIntroPool])
                    .position(x: d / 2, y: d / 2)
                    .allowsHitTesting(false)
            } else if guidedRoundActive,
                      guidedMeldBeat == FirstRunBeat.connectMeld.rawValue
                        || guidedMeldBeat == FirstRunBeat.proveMeld.rawValue {
                guidedBoardVeil(size: d, focusPools: [guidedIntroPool])
                    .position(x: d / 2, y: d / 2)
                    .allowsHitTesting(false)
            }
            if guidedRoundActive, guidedMeldBeat == 1,
               let guidedAnteWave, !reduceMotion {
                GuidedAnteWave(
                    contributor: guidedAnteWave.contributor,
                    pools: guidedAnteWave.pools,
                    size: d,
                    onImpact: { pool in
                        landGuidedAnte(contributor: guidedAnteWave.contributor,
                                       pool: pool)
                    }
                )
                .id("ante-wave-\(guidedAnteWave.contributor)")
                .position(x: d / 2, y: d / 2)
            }
            if !guidedRoundActive || guidedMeldBeat > 0 {
                centerTile
                    .position(TableWorldBoardGeometry.wellCenter(for: .center,
                                                                 in: d,
                                                                 world: theme))
                    .anchorPreference(key: TablePoolAnchorPreferenceKey.self,
                                      value: .center) { [.center: $0] }
            }
            ForEach(PochRing.anchors) { anchor in
                if !guidedRoundActive || guidedMeldBeat > 0 {
                    pm49PoolOverlay(anchor.pool)
                        .matchedGeometryEffect(
                            id: anchor.pool == .poch ? "pochPot" : "tile-\(anchor.pool.rawValue)",
                            in: morph)
                        .position(TableWorldBoardGeometry.wellCenter(for: anchor.pool,
                                                                     in: d,
                                                                     world: theme))
                        .anchorPreference(key: TablePoolAnchorPreferenceKey.self,
                                          value: .center) { [anchor.pool: $0] }
                }
            }
            if !guidedRoundActive || guidedMeldBeat > 0 {
                if !theme.isTravelTable {
                    PochDiscFrontLipOverlay(size: d, includesCenter: true)
                        .position(x: d / 2, y: d / 2)
                }
            }
            ForEach(PochRing.anchors) { anchor in
                if !guidedRoundActive || guidedMeldBeat >= 5 {
                    PocketValueMarker(pool: anchor.pool,
                                      chips: guidedRoundActive && guidedMeldBeat == 0
                                        ? 0 : game.displayedChips(in: anchor.pool),
                                      tint: theme.tint(anchor.pool),
                                      showChipCount: false)
                        .position(TableWorldBoardGeometry.notationCenter(for: anchor.pool,
                                                                         in: d,
                                                                         world: theme))
                }
            }
            if guidedRoundActive && guidedMeldBeat == 0 {
                Text(String(localized: "board.center", defaultValue: "MITTE"))
                    .font(.system(size: 8.4, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
                    .position(PochDiscGeometry.wellCenter(for: .center, in: d))
            }
        }
        .frame(width: d, height: d)
        .accessibilityIdentifier("table.world.phase1.board")
    }

    private var guidedIntroPool: Pool {
        game.meldEvents.first?.pool ?? .ace
    }

    private func guidedBoardVeil(size: CGFloat, focusPools: [Pool]) -> some View {
        return Path { path in
            path.addRect(CGRect(origin: .zero, size: CGSize(width: size, height: size)))
            for pool in focusPools {
                let center = PochDiscGeometry.wellCenter(for: pool, in: size)
                let diameter = pool == .center ? size * 0.30 : size * 0.20
                path.addEllipse(in: CGRect(x: center.x - diameter / 2,
                                           y: center.y - diameter / 2,
                                           width: diameter,
                                           height: diameter))
            }
        }
        .fill(Color.black.opacity(0.72), style: FillStyle(eoFill: true))
        .frame(width: size, height: size)
        .clipShape(Circle())
        .compositingGroup()
    }

    private func pm49Offset(_ angle: Double, radius: CGFloat) -> CGSize {
        let rad = angle * .pi / 180
        return CGSize(width: radius * sin(rad), height: -radius * cos(rad))
    }

    private func pm49PoolOverlay(_ pool: Pool) -> some View {
        let pulsing = game.pulsingPool == pool
        let chips = presentedChips(in: pool)
        let tint = theme.tint(pool)
        return ZStack {
            if pulsing {
                PoolMaterialResponse(tint: tint)
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
            if chips > 0 {
                TableWorldPiecePile(world: theme,
                                    count: chips,
                                    diameter: 58,
                                    compartment: TravelCompartment(pool: pool),
                                    placement: .well)
                    .contentTransition(.numericText())
            } else {
                Circle()
                    .fill(tint.opacity(theme.isTravelTable ? 0.48 : 0.38))
                    .frame(width: 3.5, height: 3.5)
            }
        }
        .frame(width: 58, height: 58)
        .scaleEffect(pulsing ? 1.12 : 1)
        .animation(.spring(duration: 0.25), value: pulsing)
        .animation(.easeOut(duration: 0.3), value: game.meldShown)
    }

    /// A meld payout is acknowledged by the physical lip catching light once.
    /// No particles or floating score compete with the token transfer.
    private struct PoolMaterialResponse: View {
        let tint: Color
        @State private var fired = false

        var body: some View {
            ZStack {
                Circle()
                    .trim(from: 0.06, to: 0.44)
                    .stroke(
                        LinearGradient(colors: [
                            tint.opacity(fired ? 0.08 : 0.72),
                            Tokens.jewelPlatin.opacity(fired ? 0.03 : 0.34),
                            tint.opacity(fired ? 0.04 : 0.42)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: fired ? 0.8 : 2.2,
                                           lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(12))
                    .scaleEffect(fired ? 1.04 : 0.94)
                    .opacity(fired ? 0 : 1)

                Circle()
                    .fill(tint.opacity(fired ? 0 : 0.075))
                    .frame(width: 42, height: 42)
                    .scaleEffect(fired ? 1.03 : 0.97)
            }
            .frame(width: 58, height: 58)
            .onAppear {
                fired = false
                withAnimation(PhysicalMotion.materialSettle) { fired = true }
            }
        }
    }

    private var centerTile: some View {
        let chips = presentedChips(in: .center)
        return ZStack {
            if chips > 0 {
                TableWorldPiecePile(world: theme,
                                    count: chips,
                                    diameter: 88,
                                    compartment: .center,
                                    placement: .well)
            } else {
                Circle()
                    .fill(Tokens.jewelPlatin.opacity(0.30))
                    .frame(width: 4, height: 4)
            }

            Text(String(localized: "board.center", defaultValue: "MITTE"))
                .font(.system(size: 7.2, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.62))
                .offset(y: -38)

            if chips > 0 {
                Text("\(chips)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.jewelGold)
                    .contentTransition(.numericText())
                    .shadow(color: .black.opacity(0.92), radius: 2, y: 1)
                    .offset(y: 39)
            }
        }
        .frame(width: Tokens.centerDiameter, height: Tokens.centerDiameter)
    }

    private func presentedChips(in pool: Pool) -> Int {
        guard guidedRoundActive, akt == .melden else {
            return game.displayedChips(in: pool)
        }
        if guidedMeldBeat == 0 { return 0 }
        if guidedMeldBeat == 1 { return guidedAntePoolCounts[pool, default: 0] }
        return game.displayedChips(in: pool)
    }

    private struct GuidedAnteWave: View {
        let contributor: Int
        let pools: [Pool]
        let size: CGFloat
        let onImpact: (Pool) -> Void

        var body: some View {
            ZStack {
                ForEach(Array(pools.enumerated()), id: \.element) { index, pool in
                    let source = sourcePoint
                    let target = PochDiscGeometry.wellCenter(for: pool, in: size)
                    ImpactFlight(
                        from: source,
                        to: target,
                        duration: Tokens.guidedAnteFlight,
                        delay: Double(index) * Tokens.guidedAnteStagger,
                        arcHeight: PhysicalMotion.shallowArcHeight(
                            from: source,
                            to: target,
                            minimum: 8,
                            maximum: 16
                        ),
                        lateralBias: CGFloat(index - pools.count / 2) * 0.7,
                        onImpact: { onImpact(pool) }
                    ) { progress in
                        R1Token(tint: pool == .center ? Tokens.jewelGold : pool.jewel,
                                  size: 20)
                            .rotationEffect(.degrees(Double(index - 4) * 1.2
                                                     + Double(progress) * 7))
                            .scaleEffect(1 + sin(progress * .pi) * 0.018)
                    }
                }
            }
            .frame(width: size, height: size)
            .allowsHitTesting(false)
        }

        private var sourcePoint: CGPoint {
            let inset = size * 0.08
            switch contributor % 4 {
            case 0: return CGPoint(x: size / 2, y: size + inset)
            case 1: return CGPoint(x: -inset, y: size * 0.42)
            case 2: return CGPoint(x: size / 2, y: -inset)
            default: return CGPoint(x: size + inset, y: size * 0.42)
            }
        }
    }

    // MARK: - Hand (Mockup-Fächer: groß, angewinkelt, Bleed am unteren Bildschirmrand)

    private var handView: some View {
        handFan(cardScale: 1.62)
    }

    private var landscapeHandView: some View {
        handFan(cardScale: 1.04)
    }

    private func handFan(cardScale: CGFloat) -> some View {
        let cards = Array(game.humanHand.prefix(game.humanDealtVisible))
        let N = cards.count
        // Fächer-Parameter: breite Spreizung, Karten leicht überlappend, Mockup-Optik
        let spreadDeg = min(Double(N) * 7.0, 38.0)
        let scaleRatio = cardScale / 1.62
        let totalW: CGFloat = min(CGFloat(N) * 30, 224) * scaleRatio

        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                let t: CGFloat = N > 1 ? CGFloat(i) / CGFloat(N - 1) : 0.5
                let angle = N > 1 ? -spreadDeg / 2 + Double(t) * spreadDeg : 0
                let xOff: CGFloat = N > 1 ? -totalW / 2 + t * totalW : 0

                CardFace(card: card, scale: cardScale)
                    .offset(x: xOff)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .zIndex(Double(i))
                    .transition(.scale(scale: 0.86, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.12), value: game.humanDealtVisible)
        // Nur ~60% der Kartenhöhe sichtbar - Rest blendet am Bildschirmrand aus
        .frame(height: 74 * cardScale * 0.62)
    }
}

#Preview { ContentView() }
