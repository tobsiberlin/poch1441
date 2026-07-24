import PochKit
import SwiftUI

private struct NewMatchConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            String(localized: "match.restart.title", defaultValue: "Neue Partie beginnen?"),
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button(
                String(localized: "match.restart.confirm", defaultValue: "Neue Partie"),
                role: .destructive,
                action: onConfirm
            )
            Button(
                String(localized: "match.restart.cancel", defaultValue: "Abbrechen"),
                role: .cancel
            ) {}
        } message: {
            Text(String(
                localized: "match.restart.message",
                defaultValue: "Die laufende Partie und ihr Zwischenstand gehen verloren."
            ))
        }
    }
}

/// Die Lernmarkierung folgt dem wirklich gerenderten Kartenrahmen. Ein fehlendes
/// Ziel erzeugt bewusst keinen Ersatzpunkt im leeren Raum.
private struct TutorialCardAnchorPreferenceKey: PreferenceKey {
    static let defaultValue: [Card: Anchor<CGRect>] = [:]

    static func reduce(value: inout [Card: Anchor<CGRect>],
                       nextValue: () -> [Card: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

/// Spieltisch-Container: Phase 1 (Melde-Tableau, Poch-Ring) und Phase 2 (Pochen, §6b).
/// Der echte Phasen-Morph (.matchedGeometryEffect, §5b) folgt, sobald das Phase-3-Layout
/// steht - bis dahin schaltet ein harter Wechsel die Akte um.
struct ContentView: View {
    /// Die drei Akte (§5b) als View-Fortschritt; die Engine steht nach dem Melden
    /// bereits in .betting. Der echte Morph ersetzt später die harten Schnitte.
    private enum Akt: Equatable { case melden, pochen, ausspielen }
    private enum AppOverlay { case menu, tutorial, help, settings }
    private enum TutorialRunScope: Equatable {
        case fullJourney
        case lesson(TutorialLesson)
    }
    private struct GuidedAnteWaveState: Equatable {
        let contributor: Int
        let pools: [Pool]
        let generation: Int
    }

    @State private var game = GameState()
    /// DEBUG-Launch-Args "-pochenStart"/"-ausspielStart" öffnen Akt 2/3 direkt
    /// (Screenshot-/QA-Läufe ohne Tap).
    @State private var akt: Akt = {
        #if DEBUG || INTERNAL_QA
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
    // Versionierter First-Run-Key: Build 12 ersetzt die Lernmenü-Anmutung durch
    // einen einmaligen Cold Open am echten Tisch. Bestehende interne Tester
    // sollen diese grundlegend neue Einladung genau einmal erleben.
    @AppStorage("didStartFirstTableV4") private var didStartFirstTable = false
    @AppStorage("tutorialProgressMask") private var tutorialProgressMask = 0
    /// Track B bleibt bis zur vollständigen Board-/Materialmigration aus dem
    /// Produktpfad. DEBUG kann beide Welten für Integrationsscreens explizit wählen.
    private var theme: Theme {
        #if DEBUG || INTERNAL_QA
        if let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("-tableWorld=")
        }), let value = argument.split(separator: "=").last {
            return TableWorld.resolve(String(value))
        }
        #endif
        return .pochDisc
    }
    @State private var activeOverlay: AppOverlay?
    @State private var showsNewMatchConfirmation = false
    @State private var phaseCurtain: Akt?
    @State private var guidedRoundActive = false
    @State private var selectedTutorialLesson: TutorialLesson = .meld
    @State private var activeTutorialLesson: TutorialLesson?
    @State private var activeTutorialScope: TutorialRunScope?
    @State private var completedTutorialLesson: TutorialLesson?
    @State private var tutorialMilestoneLesson: TutorialLesson?
    @State private var showsTutorialLessonPicker = false
    @State private var guidedMeldBusy = false
    @State private var guidedMeldTask: Task<Void, Never>?
    @State private var guidedMeldInterruptionTask: Task<Void, Never>?
    @State private var guidedMeldGeneration = 0
    @State private var guidedOpeningDrag: CGSize = .zero
    @State private var guidedOpeningSettled = false
    @State private var guidedFundingTask: Task<Void, Never>?
    @State private var guidedFundingGeneration = 0
    @State private var guidedAntePoolCounts: [Pool: Int] = [:]
    @State private var guidedAnteLandedEvents: Set<Int> = []
    @State private var guidedAnteWave: GuidedAnteWaveState?
    #if DEBUG || INTERNAL_QA
    @State private var debugReduceMotionOverride = false
    #endif
    #if INTERNAL_QA
    @State private var showsInternalCoinQA = false
    #endif
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

    private var guidedReduceMotion: Bool {
        #if DEBUG || INTERNAL_QA
        reduceMotion
            || debugReduceMotionOverride
            || ProcessInfo.processInfo.arguments.contains("-reduceMotionQA")
        #else
        reduceMotion
        #endif
    }

    private var firstRunOpeningStyle: FirstRunOpeningStyle {
        #if DEBUG || INTERNAL_QA
        if ProcessInfo.processInfo.arguments.contains("-firstRunOpening=tableCinematic") {
            return .tableCinematic
        }
        #endif
        return .timeSwipe
    }

    private var phase1SettlesImmediately: Bool {
        #if DEBUG || INTERNAL_QA
        // Stage-3 Reduced-Motion QA still needs real presentation events so the
        // transcript callback can prove the same causal contact without a flight.
        if ProcessInfo.processInfo.arguments.contains("-transcriptDealReducedMotionQA") {
            return false
        }
        #endif
        return guidedReduceMotion || !tableEffects
    }

    var body: some View {
        #if DEBUG || INTERNAL_QA
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
            tableBackground
            if showsPhysicalTableSurface {
                phaseAtmosphere
            }
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
                               soundEnabled: sound,
                               hapticsEnabled: haptics,
                               isGuidedRound: guidedRoundActive,
                               onContinue: {
                                   if transition(to: .ausspielen) {
                                       game.beginPlayoutPresentation()
                                   }
                               })
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
                            reduceMotion: phase1SettlesImmediately,
                            showsSeatTargets: true,
                            showsSeatIdentities: !guidedRoundActive
                        )
                    }
                }
            }
            .overlay { overlayPanel }
            .overlay { tutorialCompletionOverlay }
            .overlay(alignment: .top) { tutorialMilestoneOverlay }
            .overlay {
                if akt == .melden, activeOverlay == nil,
                   completedTutorialLesson == nil,
                   !guidedRoundActive && assistHints && moveCoach {
                    guidedCoachPlacement
                }
            }
            .overlay {
                if let phaseCurtain {
                    phaseCurtainView(phaseCurtain)
                        .transition(guidedReduceMotion
                                    ? .opacity
                                    : .scale(scale: 0.96).combined(with: .opacity))
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

            if !showFirstRunIntro,
               activeOverlay == nil,
               completedTutorialLesson == nil,
               matchEndResult == nil {
                utilityButtons
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .topTrailing)
                    .padding(.horizontal, 18)
                    .safeAreaPadding(.top, 6)
                    .zIndex(90)
            }

            if showFirstRunIntro {
                firstRunIntro
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onAppear {
            #if DEBUG || INTERNAL_QA
            let args = ProcessInfo.processInfo.arguments
            let startsGuidedQA = args.contains("-tutorialSeed")
                || args.contains("-tutorialMotionQA")
                || args.contains("-tutorialBidding")
                || args.contains("-tutorialPlayout")
                || args.contains("-dealTableauQA")
                || args.contains("-meldPayoutQA")
                || args.contains(where: { $0.hasPrefix("-tutorialMeldStep=") })
            if args.contains("-firstRun") {
                showFirstRunIntro = true
            } else if args.dropFirst().isEmpty, !didStartFirstTable {
                showFirstRunIntro = true
            } else if args.dropFirst().isEmpty {
                activeOverlay = .menu
            } else if akt == .melden, !startsGuidedQA {
                game.runDealPresentation(reduceMotion: phase1SettlesImmediately)
            }
            #else
            if !didStartFirstTable {
                showFirstRunIntro = true
            } else {
                activeOverlay = .menu
            }
            #endif
        }
        .sensoryFeedback(trigger: game.hapticTick) { previous, current in
            guard haptics, previous != current else { return nil }
            return .impact(weight: .light)
        }
        .modifier(NewMatchConfirmationModifier(
            isPresented: $showsNewMatchConfirmation,
            onConfirm: {
                activeOverlay = nil
                startNewMatch()
            }
        ))
        .r1ContactFeedback(trigger: game.r1ImpactTick,
                           groupSize: game.r1ImpactGroupSize,
                           surface: game.r1ImpactSurface)
        .onChange(of: game.endPhase) { _, phase in
            guard phase == .done, guidedRoundActive else { return }
            completeTutorialRound()
        }
        .onChange(of: guidedReduceMotion) { _, isReduced in
            guard isReduced, akt == .melden else { return }
            game.settlePhase1Presentation()
        }
        .onChange(of: tableEffects) { _, effectsEnabled in
            guard !effectsEnabled, akt == .melden else { return }
            game.settlePhase1Presentation()
        }
        #if DEBUG || INTERNAL_QA
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-resetTutorialProgressQA") {
                tutorialProgressMask = 0
                completedTutorialLesson = nil
            }
            if let playerArgument = args.first(where: { $0.hasPrefix("-players=") }),
               let count = Int(playerArgument.split(separator: "=").last ?? "4") {
                playerCount = min(max(count, 3), 6)
                game.configurePlayerCount(playerCount)
            }
            if args.contains("-dealTableauQA") {
                transition(to: .melden)
                game.runDealPresentation(reduceMotion: true)
            }
            if args.contains("-pochenStart") {
                transition(to: .pochen)
            }
            if args.contains("-pochPayoutQA") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    game.debugResolvePochPayout()
                }
            }
            if args.contains("-boardOverflowQA") {
                game.debugPrimeSaturatedPile()
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
            if args.contains("-meldPayoutQA") {
                selectedTutorialLesson = .meld
                let testsFullJourney = args.contains("-meldPayoutFastTransitionQA")
                startGuidedRound(testsFullJourney ? nil : .meld)
                game.debugStartMeldPayout()
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
        #if INTERNAL_QA
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-internalCoinQA") {
                showFirstRunIntro = false
                activeOverlay = nil
                showsInternalCoinQA = true
            } else if args.contains("-settings") {
                showFirstRunIntro = false
                activeOverlay = .settings
            }
        }
        .fullScreenCover(isPresented: $showsInternalCoinQA) {
            InternalCoinQAScreen(soundEnabled: $sound, hapticsEnabled: $haptics)
        }
        #endif
    }

    private var phaseAtmosphere: some View {
        let opacity = theme.isTravelTable ? 0.10 : 0.07
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

    private var showsPhysicalTableSurface: Bool {
        activeOverlay == nil && !showFirstRunIntro
    }

    @ViewBuilder
    private var tableBackground: some View {
        if showsPhysicalTableSurface {
            GeometryReader { viewport in
                Image("PochTableConcrete")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: viewport.size.width,
                           height: viewport.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        } else {
            RadialGradient(gradient: Gradient(colors: [Tokens.bgLift, Tokens.bgDeep]),
                           center: UnitPoint(x: 0.5, y: 0.42),
                           startRadius: 6,
                           endRadius: 540)
                .ignoresSafeArea()
        }
    }

    private func startNewRound() {
        cancelGuidedFunding()
        cancelGuidedMeldFlow()
        guidedRoundActive = false
        activeTutorialLesson = nil
        activeTutorialScope = nil
        completedTutorialLesson = nil
        game.configurePlayerCount(playerCount)
        guard game.newRound() else {
            matchEndResult = game.matchResult
            return
        }
        transition(to: .melden)
        game.runDealPresentation(reduceMotion: phase1SettlesImmediately)
    }

    private func startNewMatch() {
        cancelGuidedFunding()
        cancelGuidedMeldFlow()
        game.restartMatch()
        matchEndResult = nil
        transition(to: .melden)
        game.runDealPresentation(reduceMotion: phase1SettlesImmediately)
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
        if guided {
            guard startGuidedRound() else { return }
        } else {
            didStartFirstTable = true
            guidedRoundActive = false
            activeTutorialLesson = nil
            activeTutorialScope = nil
            game.configurePlayerCount(playerCount)
            game.newRound()
            transition(to: .melden)
            game.runDealPresentation(reduceMotion: phase1SettlesImmediately)
        }
        withAnimation(.timingCurve(0.23, 1, 0.32, 1,
                                   duration: reduceMotion ? 0.08 : 0.34)) {
            showFirstRunIntro = false
        }
    }

    private var firstRunIntro: some View {
        FirstRunCinematic(
            opponentNames: game.tutorialOpponentNames,
            theme: theme,
            openingStyle: firstRunOpeningStyle,
            reduceMotion: guidedReduceMotion,
            soundEnabled: sound,
            hapticsEnabled: haptics,
            morph: morph,
            onTakeSeat: { enterFirstTable(guided: true) },
            onPlayWithoutGuide: { enterFirstTable(guided: false) }
        )
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
                     defaultValue: "Trumpf melden. Mit Paar bieten. Hand leeren, Mitte gewinnen.")
            : String(localized: "firstRun.goal",
                     defaultValue: "Trumpf holt Bonus-Töpfe. Mit mindestens einem Paar bietest du um den Poch-Topf. Die letzte Karte gewinnt die Mitte.")
    }

    private var firstRunPrimaryText: String {
        usesCompactFirstRunCopy
            ? String(localized: "firstRun.intro.primary.compact",
                     defaultValue: "Erste Runde")
            : String(localized: "firstRun.intro.primary",
                     defaultValue: "Erste Runde spielen")
    }

    private var firstRunSecondaryText: String {
        usesCompactFirstRunCopy
            ? String(localized: "firstRun.intro.secondary.compact",
                     defaultValue: "Ohne Hilfe")
            : String(localized: "firstRun.intro.secondary",
                     defaultValue: "Ohne Einführung spielen")
    }

    private func firstRunPortraitIntro(size: CGSize, safeArea: EdgeInsets) -> some View {
        let compactHeight = size.height < 900
        let boardSize = min(size.width * (compactHeight ? 0.64 : 0.72),
                            compactHeight ? 250 : 310,
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
                                defaultValue: "Eine Runde, drei Wege zu Chips. Hana spielt mit und zeigt dir, warum jeder Zug zählt."))
                        .font(.body.weight(.medium))
                        .foregroundStyle(Tokens.jewelPlatin.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 330)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .padding(.top, compactHeight ? 4 : 8)
                        .accessibilityIdentifier("firstRun.intro.body")

                    firstRunActStrip
                        .padding(.horizontal, 26)
                        .padding(.top, compactHeight ? 8 : 14)

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

                        TableTokenPile(count: playerCount,
                                       tint: Tokens.jewelGold,
                                       diameter: boardSize * 0.23,
                                       showCount: false)
                            .offset(y: -boardSize * 0.015)
                    }
                    .frame(width: boardSize, height: boardSize)
                    .tableWorldSpatialPresentation(world: .pochDisc,
                                                   diameter: boardSize)
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
                                               defaultValue: "Erste Runde spielen"))
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
                        defaultValue: "Eine Runde, drei Chancen auf den Topf. Hana zeigt dir jeden Zug direkt am Tisch."))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.74))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("firstRun.intro.body")

            firstRunActStrip

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
                                           defaultValue: "Erste Runde spielen"))

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

                TableTokenPile(count: playerCount,
                               tint: Tokens.jewelGold,
                               diameter: zones.board.width * 0.23,
                               showCount: false)
            }
            .frame(width: introBoardSide, height: introBoardSide)
            .tableWorldSpatialPresentation(world: .pochDisc,
                                           diameter: introBoardSide)
            .position(x: zones.board.midX - 4, y: size.height / 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(firstRunBoardAccessibilityLabel)
            .accessibilityIdentifier("firstRun.intro.board")
        }
    }

    private var firstRunBoardAccessibilityLabel: String {
        String(localized: "firstRun.intro.board.accessibility",
               defaultValue: "Poch-Brett mit sieben Bonus-Töpfen, Poch-Topf und Mitte")
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
                             morph: morph)
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

    @discardableResult
    private func startGuidedRound(_ lesson: TutorialLesson? = nil) -> Bool {
        cancelGuidedFunding()
        cancelGuidedMeldFlow()
        let initialLesson = lesson ?? .meld
        game.configurePlayerCount(4)
        guard game.startTutorialRound(initialLesson) else {
            guidedRoundActive = false
            activeTutorialLesson = nil
            activeTutorialScope = nil
            showFirstRunIntro = true
            return false
        }
        guidedRoundActive = true
        activeTutorialLesson = initialLesson
        activeTutorialScope = lesson.map(TutorialRunScope.lesson) ?? .fullJourney
        completedTutorialLesson = nil
        moveCoach = true
        activeOverlay = nil
        switch initialLesson {
        case .meld:
            game.presentation.startFirstRun()
            guidedMeldBusy = false
            guidedAntePoolCounts.removeAll(keepingCapacity: true)
            guidedAnteLandedEvents.removeAll(keepingCapacity: true)
            guidedAnteWave = nil
            transition(to: .melden)
            game.prepareGuidedDeal()
        case .bidding:
            game.settlePhase1Presentation()
            transition(to: .pochen)
        case .playout:
            game.settlePhase1Presentation()
            transition(to: .ausspielen)
            game.beginPlayoutPresentation()
        }
        return true
    }

    @discardableResult
    private func transition(to next: Akt) -> Bool {
        if guidedRoundActive,
           case .lesson(let lesson) = activeTutorialScope,
           tutorialLesson(for: akt) == lesson,
           tutorialLesson(for: next) != lesson {
            completeTutorialRound()
            return false
        }
        if akt == .melden, next != .melden {
            cancelGuidedFunding()
            cancelGuidedMeldFlow()
            game.settlePhase1Presentation()
        }
        recordTutorialTransition(from: akt, to: next)
        if guidedRoundActive {
            // Im Tutorial ist der Aktwechsel eine klare Übergabe. Ein animierter
            // Switch hält sonst alten und neuen Screen kurz gleichzeitig im
            // View-Tree und erzeugt doppelte Header, Bretter und Kartenfächer.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { akt = next }
            showPhaseCurtain(next)
        } else if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { akt = next }
        } else {
            withAnimation(.spring(duration: Tokens.aktMorph)) { akt = next }
            showPhaseCurtain(next)
        }
        return true
    }

    private func recordTutorialTransition(from current: Akt, to next: Akt) {
        guard guidedRoundActive, activeTutorialScope == .fullJourney else { return }
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
        cancelGuidedFunding()
        cancelGuidedMeldFlow()
        let lesson = activeTutorialLesson ?? .playout
        markTutorialComplete(lesson)
        activeOverlay = nil
        phaseCurtain = nil
        tutorialMilestoneLesson = nil
        moveCoach = false
        activeTutorialLesson = nil
        activeTutorialScope = nil
        guidedRoundActive = false
        withAnimation(guidedReduceMotion
                      ? .linear(duration: 0.10)
                      : .spring(response: 0.46, dampingFraction: 0.88)) {
            completedTutorialLesson = lesson
        }
    }

    private func markTutorialComplete(_ lesson: TutorialLesson) {
        tutorialProgressMask |= tutorialBit(for: lesson)
    }

    private func tutorialLesson(for act: Akt) -> TutorialLesson {
        switch act {
        case .melden: return .meld
        case .pochen: return .bidding
        case .ausspielen: return .playout
        }
    }

    private func showTutorialMilestone(_ lesson: TutorialLesson) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(guidedReduceMotion ? 120 : 1_100))
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
        guard tableEffects else { return }
        withAnimation(guidedReduceMotion
                      ? .linear(duration: 0.10)
                      : .easeOut(duration: 0.16)) {
            phaseCurtain = next
        }
        // Im ersten Spiel ist der Aktwechsel selbst ein Lernmoment. Er bleibt
        // stehen, bis der Mensch ihn bestätigt; kein Text verschwindet während
        // des Lesens. Im freien Spiel bleibt die kurze filmische Blende erhalten.
        guard !guidedRoundActive else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(guidedReduceMotion ? 420 : 850))
            guard phaseCurtain == next else { return }
            withAnimation(guidedReduceMotion
                          ? .linear(duration: 0.10)
                          : .easeOut(duration: 0.18)) {
                phaseCurtain = nil
            }
        }
    }

    @ViewBuilder private func phaseCurtainView(_ target: Akt) -> some View {
        let copy = curtainCopy(target)
        ZStack {
            PhaseCurtain(phase: copy.phase,
                         title: copy.title,
                         subtitle: copy.subtitle,
                         tint: copy.tint)
            if guidedRoundActive {
                VStack {
                    Spacer()
                    Button {
                        withAnimation(guidedReduceMotion
                                      ? .linear(duration: 0.10)
                                      : .easeOut(duration: 0.18)) {
                            phaseCurtain = nil
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(phaseCurtainActionTitle(target))
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Tokens.bgDeep)
                        .frame(maxWidth: 286, minHeight: 52)
                        .background(Capsule().fill(copy.tint))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tutorial.phaseCurtain.continue")
                    .padding(.bottom, 42)
                }
            }
        }
    }

    private func phaseCurtainActionTitle(_ target: Akt) -> String {
        switch target {
        case .melden:
            return String(localized: "tutorial.handoff.action.meld",
                          defaultValue: "Bonus-Töpfe ansehen")
        case .pochen:
            return String(localized: "tutorial.handoff.action.bidding",
                          defaultValue: "Jetzt pochen")
        case .ausspielen:
            return String(localized: "tutorial.handoff.action.playout",
                          defaultValue: "Karten ausspielen")
        }
    }

    private func curtainCopy(_ target: Akt) -> (phase: String, title: String, subtitle: String, tint: Color) {
        switch target {
        case .melden:
            return (String(localized: "tutorial.handoff.phase1", defaultValue: "PHASE 1"),
                    String(localized: "firstRun.act.meld", defaultValue: "Melden").uppercased(),
                    String(localized: "tutorial.handoff.meld",
                           defaultValue: "Werte sammeln. Die Mitte bleibt für den Schluss."),
                    Tokens.jewelGold)
        case .pochen:
            return (String(localized: "tutorial.handoff.phase2", defaultValue: "PHASE 2"),
                    String(localized: "firstRun.act.bidding", defaultValue: "Pochen").uppercased(),
                    String(localized: "tutorial.handoff.bidding",
                           defaultValue: "Gleiche Karten öffnen das Gebot. Wer bleibt, zeigt."),
                    Tokens.jewelAmethyst)
        case .ausspielen:
            return (String(localized: "tutorial.handoff.phase3", defaultValue: "PHASE 3"),
                    String(localized: "firstRun.act.playout", defaultValue: "Ausspielen").uppercased(),
                    String(localized: "tutorial.handoff.playout",
                           defaultValue: "Werde zuerst deine letzte Karte los. Dafür gibt es die Mitte."),
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
                                   defaultValue: "Hanas Hinweis"))
        .accessibilityValue(guidedLearningStateTitle)
        .accessibilityIdentifier("firstRun.learningState")
    }

    private var guidedLearningStateTitle: String {
        if akt == .ausspielen {
            return String(localized: "tutorial.lesson.playout.title",
                          defaultValue: "Ausspielen")
        }
        switch guidedLearningState {
        case .orientieren:
            return String(localized: "tutorial.learningState.orient",
                          defaultValue: "Schau hin")
        case .verbinden:
            return String(localized: "tutorial.learningState.connect",
                          defaultValue: "Dein Zug")
        case .beweisen:
            return String(localized: "tutorial.learningState.prove",
                          defaultValue: "Gewinn zeigen")
        case .loslassen:
            return String(localized: "tutorial.learningState.release",
                          defaultValue: "Geschafft")
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
                    guidedCoachRail
                        .frame(width: min(size.width - 42, guidedCoachWidth))
                        .position(x: size.width / 2, y: guidedCoachY(in: size, focus: frame))
                        .transition(guidedReduceMotion
                                    ? .opacity
                                    : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(guidedReduceMotion
                       ? .linear(duration: 0.10)
                       : .easeOut(duration: 0.18),
                       value: guidedMeldBusy)
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
                            defaultValue: "Wir füllen die Töpfe."))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin)
                Text(String(localized: "tutorial.meld.drag.body",
                            defaultValue: "Jeder legt einen Chip in jeden Topf. So gibt es gleich etwas zu gewinnen. Zieh deinen ersten Chip in die Mitte."))
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
                R1Token(size: Tokens.guidedOpeningTokenSize,
                        colorway: R1Colorway.resolve(compartment: .center,
                                                     index: 0))
                    .matchedGeometryEffect(id: "firstRunInvitationChip",
                                           in: morph,
                                           isSource: false)
                    .scaleEffect(distance < Tokens.guidedOpeningSnapRadius ? 0.94 : 1)
                    .frame(width: 44, height: 44)
                    .opacity(guidedReduceMotion && guidedOpeningSettled ? 0 : 1)
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
                                withAnimation(guidedReduceMotion
                                    ? .easeOut(duration: 0.08)
                                    : .spring(response: 0.34, dampingFraction: 0.88)) {
                                    guidedOpeningDrag = .zero
                                }
                            }
                        }
                )
                .accessibilityLabel(String(localized: "tutorial.meld.action.openTable",
                                           defaultValue: "Chip in die Mitte legen"))
                .accessibilityHint(String(localized: "tutorial.meld.drag.title",
                                          defaultValue: "Lege deinen ersten Chip in die Mitte"))
                .accessibilityIdentifier("firstRun.openingToken")
        }
    }

    private func settleGuidedOpeningToken(from source: CGPoint, to target: CGPoint) {
        guard !guidedOpeningSettled else { return }
        game.beginGuidedOpeningToken()
        if guidedReduceMotion {
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
        didStartFirstTable = true
        game.markGuidedOpeningTokenLanded()
        guidedAntePoolCounts[.center] = 1
        game.presentation.setFirstRunBeat(.fundTable)
        guidedCoachFocused = true
        guidedOpeningDrag = .zero
        guidedOpeningSettled = false
        runGuidedOpeningMontage()
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
        return VStack(alignment: .leading, spacing: 8) {
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
                cancelGuidedFunding()
                cancelGuidedMeldFlow()
                game.settlePhase1Presentation()
                withAnimation(.easeOut(duration: 0.16)) {
                    guidedRoundActive = false
                    activeTutorialLesson = nil
                    activeTutorialScope = nil
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.76))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .minimumScaleFactor(0.88)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }

            if guidedMontageCanSkip {
                Button(action: skipGuidedOpeningMontage) {
                    HStack(spacing: 7) {
                        Image(systemName: "forward.end.fill")
                        Text(String(localized: "tutorial.meld.action.skipMontage",
                                    defaultValue: "Direkt zum Trumpf"))
                    }
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.86))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.045))
                            .overlay(Capsule().strokeBorder(
                                guidedTint.opacity(0.28), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("firstRun.montage.skip")
            }

            if guidedMeldActionAvailable {
                Button(action: performGuidedMeldCoachAction) {
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
                           minHeight: dynamicTypeSize.isAccessibilitySize ? 68 : 44)
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
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: 0x111018).opacity(0.96))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(guidedTint.opacity(0.32), lineWidth: 1))
                .shadow(color: .black.opacity(0.48), radius: 20, y: 10)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("firstRun.coach")
    }

    private var guidedMeldActionAvailable: Bool {
        guard guidedRoundActive, akt == .melden, !guidedMeldBusy else { return false }
        if guidedMeldBeat == FirstRunBeat.revealTrump.rawValue
            || guidedMeldBeat == FirstRunBeat.connectMeld.rawValue
            || guidedMeldBeat == FirstRunBeat.proveMeld.rawValue
            || guidedMeldBeat == FirstRunBeat.release.rawValue {
            return true
        }
        return false
    }

    private func performGuidedMeldCoachAction() {
        if guidedMeldBeat == FirstRunBeat.connectMeld.rawValue {
            completeGuidedMeldMatch()
        } else {
            advanceGuidedMeld()
        }
    }

    private var guidedMontageCanSkip: Bool {
        guidedRoundActive
            && akt == .melden
            && guidedMeldBusy
            && guidedMeldBeat >= FirstRunBeat.fundTable.rawValue
            && guidedMeldBeat <= FirstRunBeat.completeHand.rawValue
    }

    private var guidedCoachInteractionAvailable: Bool {
        !guidedMeldBusy || guidedMontageCanSkip
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
        let generation = guidedMeldGeneration
        guidedMeldTask = Task { @MainActor in
            switch guidedMeldBeat {
            case 0:
                game.presentation.setFirstRunBeat(.fundTable)
            case 1:
                break
            case 2:
                await game.revealGuidedDealRound(reduceMotion: phase1SettlesImmediately)
                guard guidedMeldFlowIsCurrent(generation) else { return }
                game.presentation.setFirstRunBeat(.completeHand)
            case 3:
                await game.finishGuidedDeal(reduceMotion: phase1SettlesImmediately)
                guard guidedMeldFlowIsCurrent(generation) else { return }
                game.presentation.setFirstRunBeat(.revealTrump)
            case 4:
                game.revealGuidedTrumpf()
                game.presentation.setFirstRunBeat(.connectMeld)
            case 5:
                game.presentation.setFirstRunBeat(.proveMeld)
            case 6:
                #if DEBUG || INTERNAL_QA
                if ProcessInfo.processInfo.arguments.contains("-meldPayoutFastTransitionQA") {
                    game.debugBeginNextMeldPayout()
                    try? await Task.sleep(for: .milliseconds(240))
                    guard generation == guidedMeldGeneration,
                          guidedRoundActive,
                          akt == .melden else { return }
                    transition(to: .pochen)
                    return
                }
                #endif
                scheduleMeldPayoutQAInterruptionIfNeeded(generation: generation)
                await game.revealAllGuidedMelds(reduceMotion: phase1SettlesImmediately)
                guard guidedMeldFlowIsCurrent(generation) else { return }
                game.presentation.setFirstRunBeat(.release)
            case 7:
                transition(to: .pochen)
            default:
                break
            }
            guard guidedMeldFlowIsCurrent(generation) else { return }
            guidedMeldTask = nil
            guidedMeldBusy = false
            guidedCoachFocused = true
        }
    }

    /// Nach dem ersten selbst gesetzten Stein läuft genau eine kurze Montage:
    /// Der Tisch füllt sich und die Karten landen. Danach übernimmt der Mensch
    /// wieder mit dem Trumpf. So bleibt der Regelzustand unverändert, während
    /// passive "Weiter"-Taps aus dem ersten Spiel verschwinden.
    private func runGuidedOpeningMontage() {
        cancelGuidedFunding()
        cancelGuidedMeldFlow()
        let fundingGeneration = guidedFundingGeneration
        let flowGeneration = guidedMeldGeneration
        guidedMeldBusy = true
        game.beginGuidedTableFunding()
        guidedMeldTask = Task { @MainActor in
            let funded = await runGuidedAnteSequence(generation: fundingGeneration)
            guard funded,
                  fundingGeneration == guidedFundingGeneration,
                  guidedMeldFlowIsCurrent(flowGeneration) else { return }

            game.presentation.setFirstRunBeat(.firstCard)
            await game.revealGuidedDealRound(reduceMotion: phase1SettlesImmediately)
            guard guidedMeldFlowIsCurrent(flowGeneration) else { return }

            game.presentation.setFirstRunBeat(.completeHand)
            await game.finishGuidedDeal(reduceMotion: phase1SettlesImmediately)
            guard guidedMeldFlowIsCurrent(flowGeneration) else { return }

            game.presentation.setFirstRunBeat(.revealTrump)
            guidedMeldTask = nil
            guidedMeldBusy = false
            guidedCoachFocused = true
        }
        Task { @MainActor in
            try? await Task.sleep(
                for: .seconds(Tokens.p1GuidedOpeningMontageMaximum)
            )
            guard guidedMeldFlowIsCurrent(flowGeneration),
                  guidedMontageCanSkip else { return }
            skipGuidedOpeningMontage()
        }
    }

    /// Bringt ausschließlich die sichtbare Lernpräsentation an denselben sicheren
    /// Kapitelpunkt wie die vollständige Montage. Die Regelrunde bleibt dabei
    /// unverändert und bereits begonnene Flüge dürfen keine späten Writes liefern.
    private func skipGuidedOpeningMontage() {
        guard guidedMontageCanSkip else { return }
        cancelGuidedFunding()
        cancelGuidedMeldFlow()
        let generation = guidedMeldGeneration
        guidedMeldBusy = true
        guidedAnteLandedEvents.removeAll(keepingCapacity: true)
        guidedAntePoolCounts = Dictionary(
            uniqueKeysWithValues: Pool.allCases.map { ($0, game.playerCount) }
        )
        game.markGuidedTableFundingLanded(groupSize: game.playerCount)
        game.presentation.setFirstRunBeat(.firstCard)
        guidedMeldTask = Task { @MainActor in
            await game.revealGuidedDealRound(reduceMotion: true)
            guard guidedMeldFlowIsCurrent(generation) else { return }

            game.presentation.setFirstRunBeat(.completeHand)
            await game.finishGuidedDeal(reduceMotion: true)
            guard guidedMeldFlowIsCurrent(generation) else { return }

            game.presentation.setFirstRunBeat(.revealTrump)
            guidedMeldTask = nil
            guidedMeldBusy = false
            guidedCoachFocused = true
        }
    }

    private func completeGuidedMeldMatch() {
        guard guidedRoundActive,
              akt == .melden,
              guidedMeldBeat == FirstRunBeat.connectMeld.rawValue,
              !guidedMeldBusy else { return }
        game.presentation.setFirstRunBeat(.proveMeld)
        guidedCoachFocused = true
    }

    private func guidedMeldFlowIsCurrent(_ generation: Int) -> Bool {
        !Task.isCancelled
            && generation == guidedMeldGeneration
            && guidedRoundActive
            && akt == .melden
    }

    private func scheduleMeldPayoutQAInterruptionIfNeeded(generation: Int) {
        #if DEBUG || INTERNAL_QA
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-meldPayoutLiveReduceMotionQA") {
            guidedMeldInterruptionTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(240))
                guard guidedMeldFlowIsCurrent(generation), akt == .melden else { return }
                guidedMeldInterruptionTask = nil
                debugReduceMotionOverride = true
            }
        }
        #endif
    }

    private func runGuidedTableFundingImpact() {
        cancelGuidedFunding()
        let generation = guidedFundingGeneration
        guidedMeldBusy = true
        game.beginGuidedTableFunding()
        guidedFundingTask = Task { @MainActor in
            let completed = await runGuidedAnteSequence(generation: generation)
            guard generation == guidedFundingGeneration else { return }
            guard completed,
                  guidedRoundActive,
                  akt == .melden,
                  guidedMeldBeat == FirstRunBeat.fundTable.rawValue else {
                guidedAnteWave = nil
                guidedMeldBusy = false
                return
            }
            game.presentation.setFirstRunBeat(.firstCard)
            guidedFundingTask = nil
            guidedMeldBusy = false
            guidedCoachFocused = true
        }
    }

    private func cancelGuidedFunding() {
        guidedFundingGeneration += 1
        guidedFundingTask?.cancel()
        guidedFundingTask = nil
        guidedAnteWave = nil
        guidedMeldBusy = false
    }

    private func cancelGuidedMeldFlow() {
        guidedMeldGeneration += 1
        guidedMeldTask?.cancel()
        guidedMeldTask = nil
        guidedMeldInterruptionTask?.cancel()
        guidedMeldInterruptionTask = nil
        guidedMeldBusy = false
    }

    #if DEBUG || INTERNAL_QA
    private func runGuidedMeldMotionQA() {
        startGuidedRound()
        guidedAntePoolCounts[.center] = 1
        game.presentation.setFirstRunBeat(.fundTable)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Tokens.guidedQAStateHold))
            guidedMeldBusy = true
            await runGuidedAnteSequence(generation: guidedFundingGeneration)
            game.presentation.setFirstRunBeat(.firstCard)
            guidedMeldBusy = false
            try? await Task.sleep(for: .seconds(Tokens.guidedQAStateHold))
            guidedMeldBusy = true
            await game.revealGuidedDealRound(reduceMotion: phase1SettlesImmediately)
            game.presentation.setFirstRunBeat(.completeHand)
            guidedMeldBusy = false
            try? await Task.sleep(for: .seconds(Tokens.guidedQAOutcomeHold))
            guidedMeldBusy = true
            await game.finishGuidedDeal(reduceMotion: phase1SettlesImmediately)
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
            await game.revealAllGuidedMelds(reduceMotion: phase1SettlesImmediately)
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
                          defaultValue: "Chip in die Mitte legen")
        case 1:
            return String(localized: "tutorial.meld.action.ante",
                          defaultValue: "Alle Töpfe füllen")
        case 2:
            return String(localized: "tutorial.meld.action.firstDeal",
                          defaultValue: "Karten austeilen")
        case 3:
            return String(localized: "tutorial.meld.action.finishDeal",
                          defaultValue: "Austeilen abschließen")
        case 4:
            return String(localized: "tutorial.meld.action.revealTrump",
                          defaultValue: "Trumpf aufdecken")
        case 5:
            return String(localized: "tutorial.meld.action.connectClaim",
                          defaultValue: "Trumpf-König melden")
        case 6:
            return String(localized: "tutorial.meld.action.showClaim",
                          defaultValue: "Gewinn einsammeln")
        case 7:
            return String(localized: "tutorial.meld.action.continueBidding",
                          defaultValue: "Weiter zum Pochen")
        default:
            return String(localized: "tutorial.meld.action.showClaim",
                          defaultValue: "Gewinn einsammeln")
        }
    }

    private var guidedAntePoolOrder: [Pool] {
        PochRing.anchors.map(\.pool) + [.center]
    }

    @discardableResult
    private func runGuidedAnteSequence(generation: Int) async -> Bool {
        let allPools = guidedAntePoolOrder
        for contributor in 0..<game.playerCount {
            guard !Task.isCancelled, generation == guidedFundingGeneration else {
                if generation == guidedFundingGeneration { guidedAnteWave = nil }
                return false
            }
            let pools = contributor == 0
                ? allPools.filter { $0 != .center }
                : allPools
            guidedAnteWave = GuidedAnteWaveState(contributor: contributor,
                                                 pools: pools,
                                                 generation: generation)
            if guidedReduceMotion {
                for pool in pools {
                    landGuidedAnte(contributor: contributor,
                                   pool: pool,
                                   generation: generation)
                }
            } else {
                let duration = Tokens.guidedAnteFlight
                    + Double(max(0, pools.count - 1)) * Tokens.guidedAnteStagger
                    + Tokens.guidedAnteWaveRest
                guard await waitForGuidedAnteImpact(duration: duration,
                                                    generation: generation) else {
                    if generation == guidedFundingGeneration { guidedAnteWave = nil }
                    return false
                }
                for pool in pools {
                    landGuidedAnte(contributor: contributor,
                                   pool: pool,
                                   generation: generation)
                }
            }
        }
        if generation == guidedFundingGeneration { guidedAnteWave = nil }
        return true
    }

    private func waitForGuidedAnteImpact(duration: Double,
                                         generation: Int) async -> Bool {
        var remaining = duration
        while remaining > 0, !guidedReduceMotion {
            guard !Task.isCancelled, generation == guidedFundingGeneration else { return false }
            let interval = min(remaining, Tokens.guidedAnteMotionPreferencePoll)
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return false
            }
            remaining -= interval
        }
        return !Task.isCancelled && generation == guidedFundingGeneration
    }

    private func landGuidedAnte(contributor: Int,
                                pool: Pool,
                                generation: Int) {
        guard generation == guidedFundingGeneration,
              guidedRoundActive,
              akt == .melden,
              guidedMeldBeat == FirstRunBeat.fundTable.rawValue else { return }
        guard let poolIndex = guidedAntePoolOrder.firstIndex(of: pool) else { return }
        let eventID = contributor * Pool.allCases.count + poolIndex
        guard guidedAnteLandedEvents.insert(eventID).inserted else { return }
        guidedAntePoolCounts[pool, default: 0] += 1
        if contributor == game.playerCount - 1, pool == .center {
            game.markGuidedTableFundingLanded(groupSize: game.playerCount)
        }
    }

    private var guidedCopy: (step: String, title: String, text: String) {
        switch akt {
        case .melden:
            if guidedRoundActive {
                switch guidedMeldBeat {
                case 0:
                    return ("circle.fill",
                            String(localized: "tutorial.meld.table.title", defaultValue: "Wir füllen die Töpfe."),
                            String(localized: "tutorial.meld.table.body", defaultValue: "Jeder legt einen Chip in jeden Topf. So gibt es gleich etwas zu gewinnen. Zieh deinen ersten Chip in die Mitte."))
                case 1:
                    let actor = guidedAnteWave.map { wave in
                        wave.contributor == 0
                            ? String(localized: "phase2.result.you", defaultValue: "Du")
                            : game.name(of: wave.contributor)
                    } ?? String(localized: "tutorial.meld.ante.everyone",
                                defaultValue: "Der Tisch")
                    let titleFormat = String(localized: "tutorial.meld.ante.actor",
                                             defaultValue: "%@ setzt ein")
                    return ("circle.grid.3x3.fill",
                            String(format: titleFormat, actor),
                            String(localized: "tutorial.meld.ante.body", defaultValue: "Ein Chip wandert nacheinander in jeden Topf. So siehst du genau, wo der Einsatz landet."))
                case 2:
                    return ("rectangle.stack.fill",
                            String(localized: "tutorial.meld.firstDeal.title", defaultValue: "Verdeckte Hände entstehen"),
                            String(localized: "tutorial.meld.firstDeal.body", defaultValue: "Deine Karten siehst nur du. Bei Hana, Noah und Jonas bleiben die Werte verborgen."))
                case 3:
                    return ("hand.raised.fill",
                            String(localized: "tutorial.meld.hand.title", defaultValue: "Deine Hand ist vollständig"),
                            String(localized: "tutorial.meld.hand.body", defaultValue: "Jetzt zeigt die offene Tischkarte, welche Farbe deine Bonus-Töpfe gewinnen kann."))
                case 4:
                    return ("suit.diamond.fill",
                            String(localized: "tutorial.guide.trump.title", defaultValue: "Welche Farbe ist Trumpf?"),
                            String(localized: "tutorial.guide.trump.body", defaultValue: "Decke die Tischkarte auf. Sie bestimmt nur die Trumpffarbe und gehört zu keiner Hand."))
                case 5:
                    return ("point.topleft.down.to.point.bottomright.curvepath",
                            String(localized: "tutorial.meld.connect.title", defaultValue: "Dein Trumpf-König trifft"),
                            String(localized: "tutorial.meld.connect.body", defaultValue: "Der König-Topf gehört dem König in Trumpf. Du hältst ihn - melde ihn jetzt. Er bleibt in deiner Hand."))
                case 6:
                    return ("checkmark.seal.fill",
                            String(localized: "tutorial.meld.claim.title", defaultValue: "König und Hochzeit"),
                            String(localized: "tutorial.meld.claim.body", defaultValue: "Der König-Topf zahlt sofort. Mit der Trumpf-Dame bildet dein König außerdem die Hochzeit, traditionell Mariage genannt."))
                default:
                    return ("checkmark.circle.fill",
                            String(localized: "tutorial.meld.release.title", defaultValue: "Die Meldungen sind beendet"),
                            String(localized: "tutorial.meld.release.body", defaultValue: "Du hast König und Hochzeit gewonnen. Andere Bonus-Töpfe bleiben liegen und wachsen. Jetzt wartet der Poch-Topf."))
                }
            }
            if game.dealtCount < game.totalDeals {
                let format = String(localized: "tutorial.guide.deal.body",
                                    defaultValue: "Schon %d von %d Karten verteilt. Jede Karte bleibt sichtbar bei ihrem Spieler.")
                return ("rectangle.stack.fill",
                        String(localized: "tutorial.guide.deal.title", defaultValue: "Die Hände füllen sich"),
                        String(format: format, game.dealtCount, game.totalDeals))
            }
            if !game.trumpRevealed {
                return ("suit.diamond.fill",
                        String(localized: "tutorial.guide.trump.title", defaultValue: "Welche Farbe ist Trumpf?"),
                        String(localized: "tutorial.guide.trump.body", defaultValue: "Decke die Tischkarte auf. Sie bestimmt nur die Trumpffarbe und gehört zu keiner Hand."))
            }
            let openPools = PochRing.anchors
                .map(\.pool)
                .filter { game.displayedChips(in: $0) > 0 }
                .prefix(2)
                .map(beginnerPoolName)
                .joined(separator: " und ")
            let focus = openPools.isEmpty
                ? "Prüfe deine Trumpfkarten auf passende Bonus-Töpfe."
                : "Noch zu gewinnen: \(openPools)."
            return ("sparkles", "Bonus-Töpfe prüfen", "\(focus) Die Mitte gewinnt später, wer zuerst alle Handkarten loswird.")
        case .pochen:
            guard game.turnIndex == 0, let legal = game.humanLegal else {
                return ("eye.fill", "Die anderen sind dran", "\(game.name(of: game.turnIndex)) entscheidet. Du siehst sofort, ob jemand mitbietet oder aussteigt.")
            }
            let current = game.betting.currentBet
            let callCost = max(0, current - game.humanCommitted)
            if let range = legal.openRange {
                return ("hand.tap.fill", "Du darfst pochen", "Starte mit \(range.lowerBound) Chip. Bleiben mehrere dabei, gewinnt die stärkste Kartenkombination.")
            }
            if let range = legal.raiseRange {
                return ("arrow.up.circle.fill", "Mitgehen oder erhöhen", "Mitgehen kostet \(callCost). Erhöhe nur, wenn deine Kartenkombination das zusätzliche Risiko wert ist - höchstens bis \(range.upperBound).")
            }
            if legal.canCall {
                return ("arrow.left.arrow.right.circle.fill", "Bleibst du dabei?", "Mitgehen kostet \(callCost). Mit Passen behältst du deine übrigen Steine, gibst diesen Topf aber auf.")
            }
            return ("forward.fill", "Ohne Paar kein Gebot", "Tippe auf Passen. Danach spielt ihr Kartenreihen aus und jagt die Mitte.")
        case .ausspielen:
            if game.stage != .playout {
                return ("flag.checkered",
                        String(localized: "tutorial.guide.finish.title", defaultValue: "Runde lesen"),
                        String(localized: "tutorial.guide.finish.body", defaultValue: "Der Sieger nimmt die Mitte. Jeder Gegner zahlt 1 Chip pro Restkarte - solange sein Vorrat reicht."))
            }
            guard game.hasPlayout else {
                return ("rectangle.on.rectangle.angled", "Mach deine Hand leer", "Spielt aufsteigende Reihen derselben Farbe. Wer zuerst keine Handkarte mehr hat, gewinnt die Mitte.")
            }
            if game.playoutLeader == 0, game.cascadeIdle {
                return ("play.fill", "Starte eine Kartenreihe", "Tippe eine beliebige Karte. Danach folgt automatisch die nächsthöhere Karte derselben Farbe.")
            }
            if game.cascadeIdle {
                let leader = game.playoutLeader ?? 0
                return ("arrow.turn.down.right", "Eine neue Reihe beginnt", "\(game.name(of: leader)) darf die nächste Startkarte wählen.")
            }
            return ("link", "Die Reihe läuft aufwärts", "Die nächsthöhere Karte derselben Farbe folgt automatisch. Fehlt sie, beginnt der letzte Spieler eine neue Reihe.")
        }
    }

    private func beginnerPoolName(_ pool: Pool) -> String {
        switch pool {
        case .ace: return String(localized: "table.world.travel.field.ace", defaultValue: "Ass")
        case .king: return String(localized: "table.world.travel.field.king", defaultValue: "König")
        case .queen: return String(localized: "table.world.travel.field.queen", defaultValue: "Dame")
        case .jack: return String(localized: "table.world.travel.field.jack", defaultValue: "Bube")
        case .ten: return String(localized: "table.world.travel.field.ten", defaultValue: "Zehn")
        case .mariage: return String(localized: "table.world.travel.field.mariage", defaultValue: "Mariage")
        case .sequence: return String(localized: "table.world.travel.field.sequence", defaultValue: "Folge")
        case .poch: return String(localized: "table.world.travel.field.poch", defaultValue: "Poch")
        case .center: return String(localized: "table.world.travel.field.center", defaultValue: "Mitte")
        }
    }

    private var utilityButtons: some View {
        HStack(spacing: 7) {
            utilityButton(
                systemImage: "gearshape.fill",
                accessibilityLabel: String(localized: "chrome.settings",
                                           defaultValue: "Einstellungen"),
                identifier: "chrome.settings"
            ) {
                activeOverlay = .settings
            }
            utilityButton(
                systemImage: "pause.fill",
                accessibilityLabel: String(localized: "menu.pause", defaultValue: "Pause"),
                identifier: "chrome.pause"
            ) {
                activeOverlay = .menu
            }
        }
        .padding(.top, 6)
        .padding(.trailing, 2)
    }

    private func utilityButton(
        systemImage: String,
        accessibilityLabel: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.96))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(hex: 0x111017).opacity(0.88))
                        .overlay(Circle().strokeBorder(
                            Tokens.jewelGold.opacity(0.48), lineWidth: 1))
                        .shadow(color: .black.opacity(0.32), radius: 8, y: 4)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var overlayPanel: some View {
        if let activeOverlay {
            GeometryReader { proxy in
                ZStack {
                    Color.black.opacity(0.56)
                        .ignoresSafeArea()
                        .onTapGesture {
                            if self.activeOverlay != .menu {
                                self.activeOverlay = nil
                            }
                        }

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
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.62))
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(.white.opacity(0.045))
                                        .frame(width: 36, height: 36))
                            }
                            .buttonStyle(.plain)
                        }

                        if activeOverlay == .menu {
                            menuPhaseStrip
                        } else if activeOverlay != .tutorial {
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
                        .accessibilityIdentifier("overlay.body")
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: activeOverlay == .tutorial ? 0 : 12)
                        }
                        .frame(maxHeight: overlayBodyMaxHeight(activeOverlay,
                                                               viewportHeight: proxy.size.height))

                        overlayFooter(activeOverlay)
                    }
                    .padding(20)
                    .frame(maxWidth: 356,
                           maxHeight: overlayPanelMaxHeight(activeOverlay,
                                                           viewportHeight: proxy.size.height),
                           alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(colors: [Color(hex: 0x17141D), Color(hex: 0x0B0A10)],
                                                 startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Tokens.jewelGold.opacity(0.25), lineWidth: 1))
                            .shadow(color: .black.opacity(0.65), radius: 28, y: 16)
                    )
                    .padding(.horizontal, 18)
                    .transition(reduceMotion
                                ? .opacity
                                : .scale(scale: 0.96).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(reduceMotion
                       ? .linear(duration: 0.12)
                       : .spring(duration: 0.28),
                       value: self.activeOverlay != nil)
        }
    }

    private func overlayBodyMaxHeight(_ overlay: AppOverlay, viewportHeight: CGFloat) -> CGFloat {
        let reservedHeight: CGFloat = overlay == .tutorial ? 206 : 258
        let available = max(160, viewportHeight - reservedHeight)
        switch overlay {
        case .menu:
            return min(342, available)
        case .tutorial:
            return min(showsTutorialLessonPicker ? 350 : 218, available)
        case .help, .settings:
            return min(500, available)
        }
    }

    private func overlayPanelMaxHeight(_ overlay: AppOverlay, viewportHeight: CGFloat) -> CGFloat {
        let reservedHeight: CGFloat = overlay == .tutorial ? 206 : 258
        return min(max(280, viewportHeight - 24),
                   overlayBodyMaxHeight(overlay, viewportHeight: viewportHeight) + reservedHeight)
    }

    @ViewBuilder private var tutorialCompletionOverlay: some View {
        if let lesson = completedTutorialLesson {
            let allComplete = completedTutorialCount == TutorialLesson.allCases.count
            ZStack {
                Color.black.opacity(0.72)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    if allComplete {
                        tutorialRivalryHook
                    } else {
                        ZStack {
                            Circle()
                                .fill(tutorialLessonTint(lesson).opacity(0.13))
                                .frame(width: 88, height: 88)
                            Circle()
                                .strokeBorder(tutorialLessonTint(lesson).opacity(0.48), lineWidth: 1)
                                .frame(width: 72, height: 72)
                            Image(systemName: tutorialLessonIcon(lesson))
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(tutorialLessonTint(lesson))
                        }
                    }

                    VStack(spacing: 7) {
                        Text(String(localized: allComplete
                                    ? "tutorial.completion.rematch.eyebrow"
                                    : "tutorial.completion.eyebrow",
                                    defaultValue: allComplete
                                        ? "HANA WILL REVANCHE"
                                        : "AM TISCH GELERNT"))
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

                    if !allComplete {
                        tutorialCompletionProgress
                    }

                    VStack(spacing: 9) {
                        overlayPrimaryButton(
                            String(localized: allComplete
                                   ? "tutorial.completion.rematch"
                                   : "tutorial.completion.free",
                                   defaultValue: allComplete
                                       ? "Noch eine Runde"
                                       : "Freie Partie starten"),
                            tint: Tokens.jewelGold
                        ) {
                            startNewRound()
                        }
                        if !allComplete {
                            overlayInlineButton(
                                String(localized: "tutorial.completion.lessons",
                                       defaultValue: "Spielzüge ansehen"),
                                tint: tutorialLessonTint(lesson)
                            ) {
                                completedTutorialLesson = nil
                                showsTutorialLessonPicker = true
                                activeOverlay = .tutorial
                            }
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: 354)
                .accessibilityElement(children: .contain)
                .accessibilityValue("\(completedTutorialCount)/\(TutorialLesson.allCases.count)")
                .accessibilityIdentifier("tutorial.completion")
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [Color(hex: 0x17141D), Color(hex: 0x09080D)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(tutorialLessonTint(lesson).opacity(0.34), lineWidth: 1))
                        .shadow(color: .black.opacity(0.70), radius: 30, y: 18)
                )
                .padding(.horizontal, 18)
        .transition(guidedReduceMotion
                    ? .opacity
                    : .scale(scale: 0.94).combined(with: .opacity))
            }
            .zIndex(120)
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
                          defaultValue: "Nicht schlecht für die erste Runde.")
        }
        switch lesson {
        case .meld:
            return String(localized: "tutorial.completion.meld.title",
                          defaultValue: "Die Bonus-Töpfe gehören dir")
        case .bidding:
            return String(localized: "tutorial.completion.bidding.title",
                          defaultValue: "Du weißt, wann du pochst")
        case .playout:
            return String(localized: "tutorial.completion.playout.title",
                          defaultValue: "Du spielst deine Hand leer")
        }
    }

    private func tutorialCompletionBody(allComplete: Bool) -> String {
        if allComplete {
            let pool = carriedBonusPool.map(beginnerPoolName)
                ?? String(localized: "table.world.travel.field.sequence", defaultValue: "Folge")
            let format = String(localized: "tutorial.completion.all.body",
                                defaultValue: "„Nächstes Mal ohne meine Tipps.“ Der %@-Topf bleibt liegen und wächst. Hana will ihn zurück.")
            return String(format: format, pool)
        }
        return String(localized: "tutorial.completion.lesson.body",
                      defaultValue: "Nimm den Schwung mit an den freien Tisch - oder spiel den Zug noch einmal.")
    }

    private var carriedBonusPool: Pool? {
        let bonusPools: [Pool] = [.ace, .king, .queen, .jack, .ten, .mariage, .sequence]
        return bonusPools
            .filter { game.chips(in: $0) > 0 }
            .max {
                let left = game.chips(in: $0)
                let right = game.chips(in: $1)
                if left == right { return $0.rawValue < $1.rawValue }
                return left < right
            }
    }

    private var tutorialRivalryHook: some View {
        HStack(spacing: 18) {
            OpponentPortrait(
                seat: 1,
                name: game.tutorialOpponentNames.first ?? "Hana",
                caption: String(localized: "tutorial.completion.hana.caption",
                                defaultValue: "fordert Revanche"),
                isActive: true,
                isFocus: true,
                mood: .pressure,
                size: 72,
                showsText: true,
                morph: nil,
                reduceMotionOverride: guidedReduceMotion
            )

            if let pool = carriedBonusPool {
                VStack(spacing: 4) {
                    Text(String(localized: "tutorial.completion.carry.eyebrow",
                                defaultValue: "BLEIBT AUF DEM TISCH"))
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(Tokens.jewelGold.opacity(0.82))
                    TableTokenPile(count: game.chips(in: pool),
                                   tint: tutorialLessonTint(.meld),
                                   diameter: 70,
                                   compartment: TravelCompartment(pool: pool))
                    Text("\(beginnerPoolName(pool))-Topf")
                        .font(.system(size: 11.5, weight: .heavy))
                        .foregroundStyle(Tokens.jewelPlatin.opacity(0.90))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(beginnerPoolName(pool))-Topf, \(game.chips(in: pool)) Chips bleiben liegen")
            }
        }
        .frame(minHeight: 104)
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
                                       defaultValue: "%d von 3 Spielzügen"),
                        completedTutorialCount))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Tokens.slate)
        }
    }

    private func overlayTitle(_ overlay: AppOverlay) -> String {
        switch overlay {
        case .menu:
            return String(localized: "overlay.menu.title", defaultValue: "Deine Runde")
        case .tutorial:
            return String(localized: "overlay.tutorial.title", defaultValue: "Hana spielt mit")
        case .help:
            return String(localized: "overlay.help.title", defaultValue: "Poch auf einen Blick")
        case .settings:
            return String(localized: "overlay.settings.title", defaultValue: "Dein Tisch")
        }
    }

    private func overlaySubtitle(_ overlay: AppOverlay) -> String {
        switch overlay {
        case .menu:
            return String(localized: "overlay.menu.subtitle", defaultValue: "KURZ LUFT HOLEN")
        case .tutorial:
            return String(localized: "overlay.tutorial.subtitle", defaultValue: "DU GIBST DEN TON AN.")
        case .help:
            return String(localized: "overlay.help.subtitle", defaultValue: "DREI WEGE. EINE RUNDE.")
        case .settings:
            return String(localized: "overlay.settings.subtitle", defaultValue: "SPIELER - TON - HINWEISE")
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
            overlayTab(.tutorial, selected: selected, icon: "person.fill.questionmark",
                       title: String(localized: "overlay.tab.learn", defaultValue: "Mit Hana"))
            overlayTab(.help, selected: selected, icon: "book.closed.fill",
                       title: String(localized: "overlay.tab.rules", defaultValue: "Regeln"))
            overlayTab(.settings, selected: selected, icon: "slider.horizontal.3",
                       title: String(localized: "overlay.tab.settings", defaultValue: "Einstellungen"))
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
            coachBubble(game.tutorialOpponentNames.first ?? "Hana",
                        String(localized: "tutorial.firstTable.body",
                               defaultValue: "Ich spiele mit. Wenn's knifflig wird, bin ich da."))
            if showsTutorialLessonPicker {
                tutorialLessonPicker
                tutorialProgressStrip
            } else {
                Button {
                    showsTutorialLessonPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "list.bullet")
                        Text(String(localized: "tutorial.lesson.choose",
                                    defaultValue: "Eine Phase üben"))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.82))
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 13)
                        .fill(Color.white.opacity(0.045))
                        .overlay(RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(Tokens.jewelGold.opacity(0.22), lineWidth: 1)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tutorial.lessons.show")
            }
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
            return String(localized: "tutorial.lesson.meld.title", defaultValue: "Bonus-Töpfe")
        case .bidding:
            return String(localized: "tutorial.lesson.bidding.title", defaultValue: "Bieten")
        case .playout:
            return String(localized: "tutorial.lesson.playout.title", defaultValue: "Karten loswerden")
        }
    }

    private func tutorialLessonBody(_ lesson: TutorialLesson) -> String {
        switch lesson {
        case .meld:
            return String(localized: "tutorial.lesson.meld.body", defaultValue: "Trumpf erkennen")
        case .bidding:
            return String(localized: "tutorial.lesson.bidding.body", defaultValue: "Mit Paar bieten")
        case .playout:
            return String(localized: "tutorial.lesson.playout.body", defaultValue: "Reihen ausspielen")
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
            VStack(spacing: 8) {
                menuActionButton(
                    String(localized: "menu.playWithHana", defaultValue: "Mit Hana spielen"),
                    systemImage: "person.fill",
                    tint: Tokens.jewelGold
                ) {
                    activeOverlay = .tutorial
                }
                menuActionButton(
                    String(localized: "overlay.tab.rules", defaultValue: "Regeln"),
                    systemImage: "book.closed.fill",
                    tint: Tokens.jewelSmaragd
                ) {
                    activeOverlay = .help
                }
                menuActionButton(
                    String(localized: "overlay.tab.settings", defaultValue: "Einstellungen"),
                    systemImage: "slider.horizontal.3",
                    tint: Tokens.jewelAmethyst
                ) {
                    activeOverlay = .settings
                }
                menuActionButton(
                    String(localized: "match.result.new", defaultValue: "Neue Partie"),
                    systemImage: "arrow.clockwise",
                    tint: Tokens.slate
                ) {
                    showsNewMatchConfirmation = true
                }
            }
        }
    }

    private var menuHeroTitle: String {
        switch akt {
        case .melden:
            return String(localized: "menu.hero.meld.title", defaultValue: "Deine Karten warten")
        case .pochen:
            return String(localized: "menu.hero.bid.title", defaultValue: "Dein Gebot steht")
        case .ausspielen:
            return String(localized: "menu.hero.play.title", defaultValue: "Die Reihe bleibt offen")
        }
    }

    private var menuHeroText: String {
        switch akt {
        case .melden:
            return String(localized: "menu.hero.meld.body",
                          defaultValue: "Karten und Töpfe bleiben genau so liegen.")
        case .pochen:
            return String(localized: "menu.hero.bid.body",
                          defaultValue: "Dein Einsatz bleibt im Poch-Topf. Gleich geht das Gebot hier weiter.")
        case .ausspielen:
            return String(localized: "menu.hero.play.body",
                          defaultValue: "Deine Hand und die aktuelle Reihe bleiben genau so liegen.")
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
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Tokens.slate.opacity(0.72))
            }
            .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 13)
            .frame(minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 13)
                .fill(Color.white.opacity(0.042))
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(tint.opacity(0.22), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            tableReadingStrip
            visualRuleExamples
        }
    }

    private var tableReadingStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "help.overview.title", defaultValue: "Drei Wege zu gewinnen"))
                .font(.system(size: 13.5, weight: .heavy))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
            tableReadRow("Bonus-Töpfe",
                         String(localized: "help.bonus.body", defaultValue: "Bestimmte Trumpfkarten gewinnen sie sofort."),
                         Tokens.jewelGold)
            tableReadRow("Poch-Topf",
                         String(localized: "help.poch.body", defaultValue: "Mit gleichen Karten bietest du um ihn."),
                         Tokens.jewelAmethyst)
            tableReadRow("Mitte",
                         String(localized: "help.center.body", defaultValue: "Wer zuerst keine Karten mehr hat, gewinnt sie."),
                         Tokens.jewelSmaragd)
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
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
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
                glossaryChip("Kartenreihe", "Karten derselben Farbe", Tokens.jewelSmaragd)
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
                              String(localized: "help.visual.meld.body",
                                     defaultValue: "Dein Trumpf-König holt den König-Topf - und bleibt in deiner Hand."),
                              tint: Tokens.jewelGold,
                              visual: .meld)
            visualRuleExample("Pochen",
                              String(localized: "help.visual.bid.body",
                                     defaultValue: "Mit zwei gleichen Karten darfst du bieten. Bleiben mehrere, entscheidet die stärkste Gruppe."),
                              tint: Tokens.jewelAmethyst,
                              visual: .poch)
            visualRuleExample("Ausspielen",
                              String(localized: "help.visual.play.body",
                                     defaultValue: "Eine Farbe läuft aufwärts. Wer die Reihe beendet, eröffnet neu."),
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
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.70))
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
                        R1Token(size: 8.5,
                                colorway: R1Colorway.resolve(compartment: .center,
                                                             index: i))
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
                Text("REIHE")
                    .font(.system(size: 7.5, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(tint)
                    .offset(x: 39, y: -4)
            }
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            playerCountPicker
            settingToggle(String(localized: "settings.sound.title", defaultValue: "Ton"),
                          String(localized: "settings.sound.body", defaultValue: "Karten, Chips und Tisch hörbar machen."),
                          isOn: $sound, tint: Tokens.jewelGold)
            settingToggle(String(localized: "settings.haptics.title", defaultValue: "Haptik"),
                          String(localized: "settings.haptics.body", defaultValue: "Wichtige Treffer und Entscheidungen fühlbar machen."),
                          isOn: $haptics, tint: Tokens.jewelGold)
            settingToggle(String(localized: "settings.hints.title", defaultValue: "Zughilfe"),
                          String(localized: "settings.hints.body", defaultValue: "Markiert mögliche Karten, wenn du unsicher bist."),
                          isOn: $assistHints, tint: Tokens.jewelSmaragd)
            settingToggle(String(localized: "settings.coach.title", defaultValue: "Hana am Tisch"),
                          String(localized: "settings.coach.body", defaultValue: "Erklärt Risiko und Folgen, wenn du Hilfe möchtest."),
                          isOn: $moveCoach, tint: Tokens.jewelSmaragd)
            settingToggle(String(localized: "settings.effects.title", defaultValue: "Lebendiger Tisch"),
                          String(localized: "settings.effects.body", defaultValue: "Bewegung, Schatten und kurze Reaktionen."),
                          isOn: $tableEffects, tint: Tokens.jewelAmethyst)
            HStack(spacing: 8) {
                overlayInlineButton(
                    String(localized: "match.result.new", defaultValue: "Neue Partie"),
                    tint: Tokens.jewelGold
                ) {
                    showsNewMatchConfirmation = true
                }
                overlayInlineButton(
                    String(localized: "overlay.tutorial.title", defaultValue: "Mit Hana spielen"),
                    tint: Tokens.jewelSmaragd
                ) {
                    activeOverlay = .tutorial
                }
            }
            #if INTERNAL_QA
            overlayInlineButton(
                String(localized: "internal.coinQA.open", defaultValue: "Münzkontakt auf diesem iPhone testen", table: "InternalCoinQA"),
                tint: Tokens.jewelGold
            ) {
                activeOverlay = nil
                showsInternalCoinQA = true
            }
            .accessibilityIdentifier("settings.internalCoinQA")
            #endif
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.panel")
    }

    private var playerCountPicker: some View {
        HStack(spacing: 12) {
            Circle().fill(Tokens.jewelGold.opacity(0.78)).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text("Spieler")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
                Text(String(localized: "settings.players.body",
                            defaultValue: "Wähle, wie viele am Tisch sitzen."))
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
            cancelGuidedFunding()
            cancelGuidedMeldFlow()
            guidedRoundActive = false
            activeTutorialLesson = nil
            activeTutorialScope = nil
            playerCount = count
            game.configurePlayerCount(count)
            transition(to: .melden)
            game.runDealPresentation(reduceMotion: phase1SettlesImmediately)
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
            overlayProminentButton(String(localized: "menu.resume", defaultValue: "Zurück ins Spiel"),
                                   tint: guidedTint) {
                activeOverlay = nil
            }
        case .tutorial:
            overlayProminentButton(String(localized: showsTutorialLessonPicker
                                          ? "tutorial.lesson.start"
                                          : "tutorial.journey.start",
                                   defaultValue: showsTutorialLessonPicker
                                              ? "Phase starten"
                                              : "Runde beginnen"),
                                   tint: tutorialLessonTint(selectedTutorialLesson)) {
                if showsTutorialLessonPicker {
                    startGuidedRound(selectedTutorialLesson)
                } else {
                    startGuidedRound()
                }
            }
        case .help:
            overlayProminentButton(
                String(localized: "help.backToTable", defaultValue: "Zurück zum Tisch"),
                tint: Tokens.jewelSmaragd
            ) {
                activeOverlay = nil
            }
        case .settings:
            overlayProminentButton(String(localized: "settings.done", defaultValue: "Fertig"),
                                   tint: Tokens.jewelAmethyst) {
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

    private func overlayProminentButton(_ title: String, tint: Color,
                                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(Tokens.bgDeep)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Capsule().fill(LinearGradient(
                colors: [tint.opacity(0.98), tint.opacity(0.74)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )))
            .shadow(color: tint.opacity(0.20), radius: 12, y: 6)
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
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.70))
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
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.68))
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

    /// Phase 1 folgt dem aktuellen Kanon: Brett als Hauptdarsteller, Kartenfächer
    /// als unterer Bleed und in Landscape eine stabile linke Gegnerachse.
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
            ZStack(alignment: .bottom) {
                ringView
                    .scaleEffect(boardScale)
                    .offset(y: boardOffset)
                    .contentShape(Circle())
                    .onTapGesture(perform: advanceFromPhase1Board)
                    .animation(.spring(response: 0.62, dampingFraction: 0.86),
                               value: boardScale)

                if assistHints {
                    phase1ProgressButton
                        .offset(y: boardOffset + 12)
                }
            }
            .padding(.top, 4)
            Spacer(minLength: 0)
            handView
                .offset(y: -178)
                .padding(.bottom, -178)
        }
    }

    private var phase1ProgressButton: some View {
        let dealing = game.humanDealtVisible < game.humanHand.count
        let title = dealing
            ? String(localized: "tutorial.meld.action.finishDeal",
                     defaultValue: "Hand fertig geben")
            : String(localized: "tutorial.meld.action.continueBidding",
                     defaultValue: "Weiter: Chips setzen")
        return Button(action: advanceFromPhase1Board) {
            Label(title, systemImage: dealing ? "forward.fill" : "arrow.right")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(Tokens.jewelPlatin)
                .padding(.horizontal, 16)
                .frame(minHeight: 46)
                .background(
                    Capsule()
                        .fill(Color(hex: 0x111017).opacity(0.94))
                        .overlay(Capsule().strokeBorder(
                            Tokens.jewelGold.opacity(0.54), lineWidth: 1))
                        .shadow(color: .black.opacity(0.42), radius: 10, y: 5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("phase1.progress")
    }

    private func advanceFromPhase1Board() {
        if game.humanDealtVisible < game.humanHand.count {
            game.skipDeal()
        } else {
            transition(to: .pochen)
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
                phase1LandscapeOpponentAxis
                    .frame(width: min(92, proxy.size.width * 0.15),
                           height: proxy.size.height * 0.78)
                    .position(x: proxy.size.width * 0.095,
                              y: proxy.size.height * 0.48)

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
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("table.world.phase1.hand")
            }
        }
    }

    private var phase1LandscapeOpponentAxis: some View {
        VStack(spacing: 7) {
            ForEach(1..<game.playerCount, id: \.self) { seat in
                OpponentPortrait(seat: seat,
                                 name: game.name(of: seat),
                                 stack: game.displayedStack(of: seat),
                                 isActive: true,
                                 isFocus: false,
                                 size: 38,
                                 morph: morph)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: game.meldShown)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("table.world.phase1.opponents")
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

    @ViewBuilder
    private func guidedMeldAccessibilityStage(in size: CGSize) -> some View {
        let ringDiameter = Tokens.ringRadius * 2 + Tokens.tileDiameter
        let landscape = size.width > size.height
        let boardSide = landscape
            ? min(size.width - 44, size.height * 0.54, 132)
            : min(size.width - 44, 260)
        let handHeight = landscape
            ? min(132, size.height * 0.54)
            : max(132, min(180, size.height * 0.34))
        if landscape {
            let opponentsWidth: CGFloat = 56
            let compactBoardSide = min(boardSide, 122)
            let handWidth: CGFloat = 160
            let coachWidth = max(220,
                                 size.width
                                    - opponentsWidth
                                    - compactBoardSide
                                    - handWidth
                                    - 54)
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    VStack(spacing: 6) {
                        ForEach(1..<game.playerCount, id: \.self) { seat in
                            firstRunOpponent(name: game.name(of: seat), seat: seat, size: 42)
                        }
                    }
                    .frame(width: opponentsWidth,
                           height: max(180, size.height - 16))

                    ringView
                        .frame(width: ringDiameter, height: ringDiameter)
                        .scaleEffect(compactBoardSide / ringDiameter)
                        .frame(width: compactBoardSide, height: compactBoardSide)
                        .contentShape(Circle())
                        .allowsHitTesting(false)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("firstRun.learningBoard")

                    guidedCoachRail
                        .frame(width: coachWidth)
                        .opacity(guidedCoachInteractionAvailable ? 1 : 0)
                        .allowsHitTesting(guidedCoachInteractionAvailable)

                    ZStack {
                        compactAccessibilityLandscapeHand

                        Color.clear
                            .accessibilityElement()
                            .accessibilityLabel(String(localized: "tutorial.meld.hand.title",
                                                       defaultValue: "Deine Hand"))
                            .accessibilityIdentifier("firstRun.learningHand")
                            .allowsHitTesting(false)
                    }
                    .frame(width: handWidth,
                           height: max(132, min(174, size.height - 24)))
                    .clipped()
                }
                .frame(minWidth: size.width,
                       minHeight: size.height)
                .padding(.horizontal, 8)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("firstRun.learningScroll")
            .animation(.easeOut(duration: 0.18), value: guidedMeldBusy)
        } else {
            ScrollView(.vertical) {
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
                        .opacity(guidedCoachInteractionAvailable ? 1 : 0)
                        .allowsHitTesting(guidedCoachInteractionAvailable)

                    ZStack(alignment: .bottom) {
                        guidedHandView
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
                            .allowsHitTesting(false)
                    }
                    .frame(width: size.width - 24,
                           height: handHeight,
                           alignment: .bottom)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("firstRun.learningScroll")
            .animation(.easeOut(duration: 0.18), value: guidedMeldBusy)
        }
    }

    private func guidedMeldSpatialStage(in proxy: GeometryProxy) -> some View {
        let zones = FirstRunStageZones.resolve(in: proxy.size,
                                               safeArea: proxy.safeAreaInsets)
        let ringDiameter = Tokens.ringRadius * 2 + Tokens.tileDiameter
        let boardScale = zones.board.width / ringDiameter
        return ZStack {
            guidedOpponentAxis(in: zones)

            ringView
                .scaleEffect(boardScale)
                .frame(width: ringDiameter, height: ringDiameter)
                .position(x: zones.board.midX, y: zones.board.midY)
                .contentShape(Circle())
                .allowsHitTesting(false)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("firstRun.learningBoard")

            guidedHandView
                .frame(width: zones.hand.width,
                       height: zones.hand.height,
                       alignment: .bottom)
                .clipped()
                .position(x: zones.hand.midX, y: zones.hand.midY)
                .allowsHitTesting(false)
                .zIndex(1)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("firstRun.learningHand")

            guidedCoachViewport(in: zones)
                .zIndex(2)
        }
        .overlayPreferenceValue(TutorialCardAnchorPreferenceKey.self) { anchors in
            if (guidedMeldBeat == FirstRunBeat.connectMeld.rawValue
                || (guidedMeldBeat == FirstRunBeat.proveMeld.rawValue
                    && game.startedMelds == game.meldShown)),
               let anchor = anchors[guidedIntroCard] {
                let visibleCardFrame = proxy[anchor].intersection(zones.hand)
                if !visibleCardFrame.isNull,
                   visibleCardFrame.width > 1,
                   visibleCardFrame.height > 1 {
                    guidedMeldConnection(in: zones,
                                         ringDiameter: ringDiameter,
                                         cardFrame: visibleCardFrame)
                }
            }
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
        .opacity(guidedCoachInteractionAvailable ? 1 : 0)
        .allowsHitTesting(guidedCoachInteractionAvailable)
    }

    private func guidedMeldConnection(in zones: FirstRunStageZones,
                                      ringDiameter: CGFloat,
                                      cardFrame: CGRect) -> some View {
        let well = PochDiscGeometry.wellCenter(for: guidedIntroPool, in: ringDiameter)
        let wellPoint = CGPoint(
            x: zones.board.minX + well.x / ringDiameter * zones.board.width,
            y: zones.board.minY + well.y / ringDiameter * zones.board.height
        )
        let cardPoint = CGPoint(x: cardFrame.midX,
                                y: min(cardFrame.maxY, cardFrame.minY + 12))
        let routeX = min(zones.hand.maxX - 4, zones.decision.maxX + 10)

        return ZStack {
            Path { path in
                path.move(to: wellPoint)
                path.addLine(to: CGPoint(x: routeX, y: zones.decision.minY - 8))
                path.addLine(to: CGPoint(x: routeX, y: zones.decision.maxY + 8))
                path.addLine(to: cardPoint)
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
    }

    private var guidedIntroRank: Rank {
        switch guidedIntroPool {
        case .ace: .ace
        case .king: .king
        case .queen: .queen
        case .jack: .jack
        case .ten: .ten
        case .mariage: .king
        case .sequence: .seven
        case .poch, .center: .ace
        }
    }

    private var guidedIntroCard: Card {
        Card(suit: game.trump, rank: guidedIntroRank)
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
               let guidedAnteWave, !guidedReduceMotion {
                GuidedAnteWave(
                    contributor: guidedAnteWave.contributor,
                    contributorName: guidedAnteWave.contributor == 0
                        ? String(localized: "phase2.result.you", defaultValue: "Du")
                        : game.name(of: guidedAnteWave.contributor),
                    pools: guidedAnteWave.pools,
                    size: d,
                    onImpact: { pool in
                        landGuidedAnte(contributor: guidedAnteWave.contributor,
                                       pool: pool,
                                       generation: guidedAnteWave.generation)
                    }
                )
                .id("ante-wave-\(guidedAnteWave.generation)-\(guidedAnteWave.contributor)")
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
            ForEach(PochRing.anchors) { anchor in
                if !guidedRoundActive || guidedMeldBeat >= 5 {
                    PocketValueMarker(world: theme,
                                      pool: anchor.pool,
                                      chips: guidedRoundActive && guidedMeldBeat == 0
                                        ? 0 : game.displayedChips(in: anchor.pool),
                                      tint: theme.tint(anchor.pool))
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
        .tableWorldSpatialPresentation(world: theme, diameter: d)
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
                                    diameter: Tokens.phase1OuterWellDiameter,
                                    compartment: TravelCompartment(pool: pool),
                                    placement: .well,
                                    pieceDiameterOverride: Tokens.tableTokenDiameter)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: Tokens.phase1OuterWellDiameter,
               height: Tokens.phase1OuterWellDiameter)
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
                            tint.opacity(0.72),
                            Tokens.jewelPlatin.opacity(0.34),
                            tint.opacity(0.42)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 2.2,
                                           lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(12))
                    .scaleEffect(fired ? 1.04 : 0.94)
                    .opacity(fired ? 0 : 1)

                Circle()
                    .fill(tint.opacity(0.075))
                    .frame(width: 42, height: 42)
                    .scaleEffect(fired ? 1.03 : 0.97)
                    .opacity(fired ? 0 : 1)
            }
            .frame(width: Tokens.phase1OuterWellDiameter,
                   height: Tokens.phase1OuterWellDiameter)
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
                                    diameter: Tokens.phase1CenterWellDiameter,
                                    compartment: .center,
                                    placement: .well,
                                    pieceDiameterOverride: Tokens.tableTokenDiameter)
            }
        }
        .frame(width: Tokens.centerDiameter, height: Tokens.centerDiameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "board.center", defaultValue: "Mitte"))
        .accessibilityValue("\(chips)")
    }

    private func presentedChips(in pool: Pool) -> Int {
#if DEBUG || INTERNAL_QA
        if pool == .center,
           ProcessInfo.processInfo.arguments.contains("-emptyCenterMaterialQA") {
            return 0
        }
#endif
        guard guidedRoundActive, akt == .melden else {
            return game.displayedChips(in: pool)
        }
        if guidedMeldBeat == 0 { return 0 }
        if guidedMeldBeat == 1 { return guidedAntePoolCounts[pool, default: 0] }
        return game.displayedChips(in: pool)
    }

    private struct GuidedAnteWave: View {
        let contributor: Int
        let contributorName: String
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
                    ) { _ in
                        R1Token(size: Tokens.tableTokenDiameter,
                                colorway: R1Colorway.resolve(
                                    compartment: TravelCompartment(pool: pool),
                                    index: contributor
                                ),
                                markRotation: Double(index - 4) * 1.2,
                                surfaceVariant: contributor)
                            .shadow(color: .black.opacity(0.48), radius: 5, y: 4)
                    }
                }

                Text(String(format: String(localized: "tutorial.meld.ante.actor",
                                           defaultValue: "%@ setzt ein"),
                            contributorName))
                    .font(.system(size: 9.5, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.90))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(Capsule().fill(Color.black.opacity(0.72)))
                    .position(x: min(max(sourcePoint.x, 54), size - 54),
                              y: min(max(sourcePoint.y, 22), size - 22))
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

    /// Das Tutorial zeigt und erklärt eine konkrete Karte. Deshalb entspricht
    /// sein Layout-Rahmen der voll sichtbaren Karte; andernfalls würde der obere
    /// Teil zwar gerendert, aber außerhalb der berührbaren SwiftUI-Fläche liegen.
    private var guidedHandView: some View {
        handFan(cardScale: 1.62, reservesFullCardHeight: true)
    }

    private var landscapeHandView: some View {
        handFan(cardScale: 1.04)
    }

    /// AX XXXL on a short landscape phone needs the complete fan beside the
    /// explanation instead of below it. The smaller physical cards preserve
    /// their full touch target while keeping every card inside the stage.
    private var compactAccessibilityLandscapeHand: some View {
        handFan(cardScale: 0.74, reservesFullCardHeight: true)
    }

    private func handFan(cardScale: CGFloat,
                         reservesFullCardHeight: Bool = false) -> some View {
        let cards = Array(game.humanHand.prefix(game.humanDealtVisible))
        let totalSlots = game.humanHand.count

        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                let pose = DealTableauLayout.humanPose(
                    slot: i,
                    totalSlots: totalSlots,
                    cardScale: cardScale
                )
                let isGuidedTarget = guidedRoundActive
                    && guidedMeldBeat == FirstRunBeat.connectMeld.rawValue
                    && card == guidedIntroCard

                Group {
                    if isGuidedTarget {
                        CardFace(
                            card: card,
                            goldenStopper: true,
                            scale: cardScale
                        )
                        .accessibilityIdentifier("firstRun.meldTargetCard")
                    } else {
                        CardFace(
                            card: card,
                            goldenStopper: false,
                            scale: cardScale,
                            isAccessibilityHidden: false
                        )
                        .accessibilityIdentifier(
                            "phase1.hand.card.\(card.suit.rawValue).\(card.rank.rawValue)"
                        )
                    }
                }
                    .anchorPreference(key: TutorialCardAnchorPreferenceKey.self,
                                      value: .bounds) { [card: $0] }
                    .offset(pose.offset)
                    .rotationEffect(.degrees(pose.rotationDegrees), anchor: .bottom)
                    .zIndex(isGuidedTarget ? Double(cards.count + 1) : Double(i))
                    .transition(.scale(scale: 0.86, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.12), value: game.humanDealtVisible)
        // Nur ~60% der Kartenhöhe sichtbar - Rest blendet am Bildschirmrand aus
        .frame(height: 74 * cardScale * (reservesFullCardHeight ? 1 : 0.62))
    }
}

#Preview { ContentView() }
