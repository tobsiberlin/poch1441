import PochKit
import SwiftUI
import UIKit

private struct Phase2StageGeometry {
    private static let minimumLandscapeAspectRatio: CGFloat = 4.0 / 3.0
    static let portraitSliderVisualRightEdge: CGFloat = 81

    let layoutFrame: CGRect
    let isLandscape: Bool

    @MainActor
    static func resolve(in size: CGSize,
                        safeArea: EdgeInsets,
                        globalFrame: CGRect) -> Phase2StageGeometry {
        let safeFrame = CGRect(x: safeArea.leading,
                               y: safeArea.top,
                               width: max(0, size.width
                                   - safeArea.leading - safeArea.trailing),
                               height: max(1, size.height
                                   - safeArea.top - safeArea.bottom))
        let visibleGlobalFrame = globalFrame.intersection(UIScreen.main.bounds)
        let visibleLocalFrame = visibleGlobalFrame.isNull
            ? safeFrame
            : visibleGlobalFrame.offsetBy(dx: -globalFrame.minX,
                                          dy: -globalFrame.minY)
        let safeVisibleFrame = safeFrame.intersection(visibleLocalFrame)
        let layoutFrame = safeVisibleFrame.isNull ? visibleLocalFrame : safeVisibleFrame
        let isLandscape = layoutFrame.width / max(1, layoutFrame.height)
            >= minimumLandscapeAspectRatio
        return Phase2StageGeometry(layoutFrame: layoutFrame,
                                   isLandscape: isLandscape)
    }
}

private enum Phase2PortraitLayout {
    static let accessibilityCompactBettingStageHeight: CGFloat = 158
    static let accessibilityResultStageHeight: CGFloat = 186
    static let accessibilityResultDecisionHeight: CGFloat = 184
    static let accessibilityCompactBoardScale: CGFloat = 0.68
    static let accessibilityRegularBoardScale: CGFloat = 0.76
    static let accessibilityResultBoardScale: CGFloat = 0.72
    static let accessibilityResultActionLift: CGFloat = 24
    static let compactBettingHandReserve: CGFloat = 168
    static let standardResultHandReserve: CGFloat = 138
    static let standardResultSeatOffset: CGFloat = 80
    static let guidedBoardScale: CGFloat = 1.12
    static let guidedPreludeDecisionHeight: CGFloat = 170
    static let guidedCompactPreludeDecisionHeight: CGFloat = 170
    static let guidedDecisionHeight: CGFloat = 142
    static let guidedResultDecisionHeight: CGFloat = 212
}

private enum Phase2PayoutAnchor: Hashable {
    case board
    case human
    case opponent(Int)
}

private struct Phase2PayoutFramePreferenceKey: PreferenceKey {
    static let defaultValue: [Phase2PayoutAnchor: CGRect] = [:]

    static func reduce(value: inout [Phase2PayoutAnchor: CGRect],
                       nextValue: () -> [Phase2PayoutAnchor: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct Phase2PayoutFrameModifier: ViewModifier {
    let anchor: Phase2PayoutAnchor

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: Phase2PayoutFramePreferenceKey.self,
                    value: [anchor: proxy.frame(in: .named("phase2.payout.stage"))]
                )
            }
        }
    }
}

private extension View {
    func phase2PayoutAnchor(_ anchor: Phase2PayoutAnchor) -> some View {
        modifier(Phase2PayoutFrameModifier(anchor: anchor))
    }
}

/// Phase 2 (Pochen) - der psychologische Kern (§6b) im Kompressions-Layout (§5b, Akt 2):
/// Gegner rücken als Kardinalpunkt-Tokens nah (§5c, Platzhalter bis Charakterstil-Urteil),
/// die echte Poch-Mulde bleibt materiell sichtbar und wird nur semantisch akzentuiert.
/// Unten: Hand (Kunststück leuchtet) + Biet-Slider mit personifizierter Limit-Wand.
struct Phase2View: View {
    private enum GuidedFocus {
        case none
        case hand
        case range
        case actions
        case opponents
    }

    private struct PresentedReaction: Equatable {
        let seat: Int
        let action: SeatAction
    }

    let game: GameState
    let theme: Theme
    /// Phasen-Morph-Namespace (§5b) - geteilt mit ContentView/Phase3View.
    let morph: Namespace.ID
    let assistHints: Bool
    let soundEnabled: Bool
    let hapticsEnabled: Bool
    let isGuidedRound: Bool
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var bid = 1.0
    @State private var presentedPot = 0
    @State private var pendingPot: Int?
    @State private var transferPresentationActive = false
    @State private var settledBetTransfer = 0
    @State private var payoutPresentationActive = false
    @State private var payoutPresentationCompleted = false
    @State private var payoutPresentationGeneration = 0
    @State private var payoutStartScheduled = false
    @State private var payoutImpact = 0
    @State private var guidedPreludeStep = 0
    @State private var featuredReaction: PresentedReaction?
    @State private var queuedReactions: [PresentedReaction] = []
    @State private var reactionPresentationGeneration = 0
    @State private var payoutAnchorFrames: [Phase2PayoutAnchor: CGRect] = [:]
    #if DEBUG || INTERNAL_QA
    @State private var qaPochFlight = 0
    @State private var qaCoinTranscriptContact = 0
    @State private var qaCoinTranscriptRest = 0
    #endif

    private var phase2ReduceMotion: Bool {
        #if DEBUG || INTERNAL_QA
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-reduceMotionQA")
        #else
        reduceMotion
        #endif
    }

    var body: some View {
        GeometryReader { proxy in
            let stage = Phase2StageGeometry.resolve(in: proxy.size,
                                                    safeArea: proxy.safeAreaInsets,
                                                    globalFrame: proxy.frame(in: .global))
            let width = stage.layoutFrame.width
            let height = stage.layoutFrame.height

            if stage.isLandscape {
                landscapeStage(width: width, height: height)
                    .frame(width: width, height: height)
                    .position(x: stage.layoutFrame.midX, y: stage.layoutFrame.midY)
            } else {
                portraitStage(width: width, height: height)
                    .frame(width: width, height: height)
                    .position(x: stage.layoutFrame.midX, y: stage.layoutFrame.midY)
            }
        }
        .coordinateSpace(name: "phase2.payout.stage")
        .onPreferenceChange(Phase2PayoutFramePreferenceKey.self) { frames in
            // Ein Sitz kann im Schnitt/Gegenschnitt kurz aus der sichtbaren
            // Komposition verschwinden. Sein zuletzt tatsächlich gemessener
            // Rahmen bleibt deshalb bis zum Rundenende das Auszahlungsziel.
            payoutAnchorFrames.merge(frames, uniquingKeysWith: { _, latest in latest })
        }
        .onAppear {
            resetBid()
            presentedPot = game.pot
            transferPresentationActive = false
            settledBetTransfer = game.betTransfer
            scheduleGuidedPrelude()
            startPayoutPresentationIfNeeded()
            game.resumeBettingIfNeeded()
            #if DEBUG || INTERNAL_QA
            if let argument = ProcessInfo.processInfo.arguments.first(where: {
                $0.hasPrefix("-tutorialBiddingStep=")
            }), let step = Int(argument.split(separator: "=").last ?? "0") {
                guidedPreludeStep = min(max(step, 0), 2)
            }
            #endif
        }
        .onChange(of: game.turnIndex) { resetBid() }
        .onChange(of: game.pot) { _, newValue in
            schedulePotPresentation(newValue)
        }
        .onChange(of: game.betTransfer) { _, transfer in
            guard !phase2ReduceMotion else {
                transferPresentationActive = transfer > settledBetTransfer
                return
            }
            transferPresentationActive = game.betTransfer > 0
        }
        .onChange(of: game.stage) { _, _ in
            startPayoutPresentationIfNeeded()
        }
        .onChange(of: game.seatActions) { previous, current in
            enqueueOpponentReactions(previous: previous, current: current)
        }
        .onChange(of: game.pochShock) { previous, current in
            guard soundEnabled,
                  previous != current,
                  game.lastBetKind.isPoch else { return }
            TableFoleyAudio.shared.playPochGesture(
                sequence: current,
                generation: game.betTransfer,
                seat: game.lastBetActor ?? game.turnIndex,
                playerCount: game.playerCount
            )
        }
        .onChange(of: phase2ReduceMotion) { _, isReduced in
            guard isReduced else { return }
            transferPresentationActive = game.betTransfer > settledBetTransfer
            if payoutPresentationActive {
                payoutPresentationGeneration += 1
            } else {
                startPayoutPresentationIfNeeded()
            }
        }
        .onDisappear {
            pendingPot = nil
            transferPresentationActive = false
            payoutPresentationActive = false
            payoutStartScheduled = false
            payoutPresentationGeneration += 1
            featuredReaction = nil
            queuedReactions.removeAll()
            reactionPresentationGeneration += 1
        }
        .sensoryFeedback(trigger: game.pochShock) { previous, current in
            guard hapticsEnabled, previous != current else { return nil }
            return .impact(weight: .heavy)
        }
        .sensoryFeedback(trigger: payoutImpact) { previous, current in
            guard hapticsEnabled, previous != current else { return nil }
            return .impact(weight: .medium)
        }
        .overlay {
            if game.betTransfer > settledBetTransfer {
                let transfer = game.betTransfer
                PochBetFlight(seat: game.lastBetActor ?? game.turnIndex,
                              amount: game.lastBetAmount,
                              kind: game.lastBetKind,
                              trigger: game.betTransfer,
                              reduceMotion: phase2ReduceMotion,
                              world: theme,
                              tint: theme.tint(.poch),
                              onImpact: { commitBetImpact(transfer: transfer) })
                    .id("poch-bet-\(game.betTransfer)")
                    .id("poch-bet-motion-\(phase2ReduceMotion)")
                    .allowsHitTesting(false)
            }
            if payoutPresentationActive,
               let result = game.pochResult {
                let generation = payoutPresentationGeneration
                PochPayoutFlight(winner: result.winner,
                                 winnerName: result.winner == 0
                                    ? String(localized: "phase2.result.you",
                                             defaultValue: "Du")
                                    : game.name(of: result.winner),
                                 amount: result.pot + result.pochPool,
                                 generation: generation,
                                 reduceMotion: phase2ReduceMotion,
                                 world: theme,
                                 activeSeats: game.activeUISeats,
                                 sourceFrame: payoutAnchorFrames[.board],
                                 targetFrame: payoutAnchorFrames[result.winner == 0
                                    ? .human
                                    : .opponent(result.winner)],
                                 onImpact: {
                                     commitPayoutImpact(generation: generation)
                                 })
                    .id("poch-payout-\(generation)-\(phase2ReduceMotion)")
                    .allowsHitTesting(false)
            }
            #if DEBUG || INTERNAL_QA
            if theme == .unterwegs,
               ProcessInfo.processInfo.arguments.contains("-transcriptCoinQA"),
               let plan = try? CertifiedCoinTranscript.bundled() {
                TranscriptCoinDrop(
                    plan: plan,
                    mode: .standard,
                    soundEnabled: soundEnabled,
                    hapticsEnabled: hapticsEnabled,
                    onContact: { qaCoinTranscriptContact += 1 },
                    onRest: { qaCoinTranscriptRest += 1 }
                )
                .allowsHitTesting(false)
            }
            if theme == .unterwegs,
               ProcessInfo.processInfo.arguments.contains("-transcriptCoinReducedMotionQA"),
               let plan = try? CertifiedCoinTranscript.bundled() {
                TranscriptCoinDrop(
                    plan: plan,
                    mode: .reducedMotion,
                    soundEnabled: soundEnabled,
                    hapticsEnabled: hapticsEnabled,
                    onContact: { qaCoinTranscriptContact += 1 },
                    onRest: { qaCoinTranscriptRest += 1 }
                )
                .allowsHitTesting(false)
            }
            if qaPochFlight > 0, !phase2ReduceMotion {
                PochBetFlight(seat: 0,
                              amount: 4,
                              kind: .raise,
                              trigger: qaPochFlight,
                              reduceMotion: false,
                              world: theme,
                              tint: theme.tint(.poch),
                              onImpact: {})
                    .allowsHitTesting(false)
            }
            #endif
        }
        #if DEBUG || INTERNAL_QA
        .task {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-pochActionQA") {
                try? await Task.sleep(for: .milliseconds(2_250))
                guard let range = game.humanLegal?.openRange else { return }
                game.humanOpen(1.clamped(to: range))
                return
            }
            guard arguments.contains("-pochFlightQA") else { return }
            try? await Task.sleep(for: .milliseconds(2_250))
            for _ in 0..<4 {
                qaPochFlight += 1
                try? await Task.sleep(for: .seconds(Tokens.p2PochFlight + 0.48))
            }
        }
        #endif
    }

    @ViewBuilder
    private func portraitStage(width w: CGFloat, height h: CGFloat) -> some View {
        // The guided prelude owns more copy than the free table. On short
        // phones a fixed Y-stage inevitably puts its action row into the hand.
        // Use the same measured vertical flow as Dynamic Type instead.
        if dynamicTypeSize.isAccessibilitySize || h < 720 {
            accessibilityPortraitStage(width: w, height: h)
        } else {
            fixedPortraitStage(width: w, height: h)
        }
    }

    private func accessibilityPortraitStage(width w: CGFloat,
                                            height h: CGFloat) -> some View {
        let socialFocus = featuredReaction != nil || (game.stage == .betting
            && (transferPresentationActive || game.turnIndex != 0))
        let boardHeight: CGFloat = 224
        return ScrollView(.vertical) {
            VStack(spacing: 24) {
                topArea
                    .frame(width: w, height: boardHeight)
                    // Auf kurzen Telefonen erzeugt der Kontaktschatten sonst
                    // einen optischen Zusammenstoß mit der Erklärung. Die
                    // Disc bleibt dominant, erhält aber eine klare Atemzone.
                    .scaleEffect(0.82)
                    .modifier(TableShake(
                        amplitude: phase2ReduceMotion ? 0 : Tokens.pochShakeAmp,
                        animatableData: CGFloat(game.pochShock)))
                    .animation(.linear(duration: Tokens.pochShake), value: game.pochShock)
                    // Die räumliche Disc wirft bewusst einen tiefen Kontaktschatten.
                    // Dieser gehört zur Brettbühne und darf nicht in die folgende
                    // Erklärung ragen.
                    .padding(.bottom, 24)

                if socialFocus {
                    pochenStatusLine
                        .frame(width: min(342, w - 24))
                    portraitsRow(maxPanelWidth: 112)
                        .frame(width: w, alignment: .top)
                        .frame(minHeight: 132, alignment: .top)
                } else {
                    pochenDecisionCard
                        .frame(width: min(342, w - 24), alignment: .top)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("phase2.decision")

                    if !isGuidedRound || guidedFocus == .actions {
                        actionArea
                            .frame(width: min(336, w - 28), alignment: .top)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("phase2.actions")
                            .allowsHitTesting(!isGuidedRound || guidedFocus == .actions)
                    }
                }

                if game.stage != .betting && !socialFocus {
                    portraitsRow(maxPanelWidth: 112)
                        .frame(width: w, alignment: .top)
                        .frame(minHeight: 132, alignment: .top)
                }

                handFan(cardScale: 1.28)
                    .frame(width: w - 8, height: 164, alignment: .bottom)
                    // Die Hand bleibt als Kontext bereits neben der
                    // Voraussetzung sichtbar. Versteckte Aktionsflächen
                    // dürfen sie nicht unter den ersten Viewport drücken.
                    .offset(y: isGuidedRound && guidedFocus != .actions ? -60 : -28)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("phase2.accessibility.scroll")
    }

    private func fixedPortraitStage(width w: CGFloat, height h: CGFloat) -> some View {
        let compactHeight = h < Tokens.phase2CompactHeight
        let veryCompactHeight = h < Tokens.phase2VeryCompactHeight
        let accessibilityResult = game.stage != .betting
            && dynamicTypeSize.isAccessibilitySize
        let accessibilityBetting = game.stage == .betting
            && dynamicTypeSize.isAccessibilitySize
        let opponentFocus = featuredReaction != nil || (game.stage == .betting
            && (transferPresentationActive || game.turnIndex != 0))
        // Phase 2 is staged as a shot/reverse-shot sequence. During the human
        // decision the board, rule and hand own the frame. Once somebody else
        // reacts, the copy gives way to a social close-up instead of squeezing
        // tiny portraits between the decision and the cards.
        let socialFocus = opponentFocus
        let topH = accessibilityResult
            ? min(Phase2PortraitLayout.accessibilityResultStageHeight, h * 0.28)
            : (accessibilityBetting
               ? (veryCompactHeight
                  ? min(Phase2PortraitLayout.accessibilityCompactBettingStageHeight,
                        max(152, h * 0.27))
                  : min(186, max(176, h * 0.29)))
               : (socialFocus
                  ? min(230, h * 0.35)
                  : min(Tokens.phase2StageHeight, h * 0.38)))
        let decisionTop = topH + (isGuidedRound ? 64 : Tokens.phase2BoardDecisionGap)
        let guidedPreludeActive = isGuidedRound && guidedPreludeStep < 2
        let decisionH: CGFloat = {
            if accessibilityResult {
                return Phase2PortraitLayout.accessibilityResultDecisionHeight
            }
            if dynamicTypeSize.isAccessibilitySize {
                return guidedPreludeActive ? 236 : (isGuidedRound ? 176 : 146)
            }
            if guidedPreludeActive {
                return compactHeight
                    ? Phase2PortraitLayout.guidedCompactPreludeDecisionHeight
                    : Phase2PortraitLayout.guidedPreludeDecisionHeight
            }
            if isGuidedRound, game.stage != .betting {
                return Phase2PortraitLayout.guidedResultDecisionHeight
            }
            return isGuidedRound ? Phase2PortraitLayout.guidedDecisionHeight : 104
        }()
        let actionGap: CGFloat = compactHeight ? 10 : 14
        let actionsTop = decisionTop + decisionH + actionGap
            - (accessibilityResult ? Phase2PortraitLayout.accessibilityResultActionLift : 0)
        let actionsH: CGFloat = game.stage == .betting
            ? (dynamicTypeSize.isAccessibilitySize ? 64 : 56)
            : resultActionAreaHeight
        let opponentRowHeight = veryCompactHeight
            ? Tokens.phase2VeryCompactOpponentRowHeight
            : (compactHeight
               ? Tokens.phase2CompactOpponentRowHeight
               : Tokens.phase2OpponentRowHeight)
        let seatsY = topH + (dynamicTypeSize.isAccessibilitySize ? 48 : 54)
        let guidedBoardScale = min(
            Phase2PortraitLayout.guidedBoardScale,
            max(0.76, (topH - 8) / max(compactRingDiameter, 1))
        )
        let boardScale: CGFloat = {
            if accessibilityResult {
                return Phase2PortraitLayout.accessibilityResultBoardScale
            }
            if accessibilityBetting {
                let minimumScale = veryCompactHeight
                    ? Phase2PortraitLayout.accessibilityCompactBoardScale
                    : Phase2PortraitLayout.accessibilityRegularBoardScale
                return min(0.82,
                           max(minimumScale,
                               (topH - 8) / max(compactRingDiameter, 1)))
            }
            if socialFocus {
                return min(1, max(0.82, (topH - 8) / max(compactRingDiameter, 1)))
            }
            return isGuidedRound ? guidedBoardScale : 1
        }()

        return ZStack(alignment: .top) {
            topArea
                .frame(width: w, height: topH)
                .scaleEffect(boardScale)
                .modifier(TableShake(
                    amplitude: phase2ReduceMotion ? 0 : Tokens.pochShakeAmp,
                    animatableData: CGFloat(game.pochShock)))
                .animation(.linear(duration: Tokens.pochShake), value: game.pochShock)
                .offset(y: 2)

            pochenDecisionCard
                .frame(width: min(342, w - 14))
                .frame(height: decisionH, alignment: .top)
                .offset(y: decisionTop)
                .zIndex(guidedPreludeActive ? 4 : 0)
                .opacity(socialFocus ? 0 : 1)
                .allowsHitTesting(!socialFocus)
                .accessibilityHidden(socialFocus)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("phase2.decision")

            actionArea
                .frame(width: min(336, w - 26), height: actionsH, alignment: .top)
                .offset(y: actionsTop)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("phase2.actions")
                .modifier(GuidedFocusModifier(
                    isActive: isGuidedRound,
                    isRelevant: guidedFocus == .actions,
                    reduceMotion: phase2ReduceMotion
                ))
                .allowsHitTesting(!isGuidedRound || guidedFocus == .actions)
                .opacity(socialFocus || (isGuidedRound && guidedFocus != .actions) ? 0 : 1)
                .accessibilityHidden(socialFocus || (isGuidedRound && guidedFocus != .actions))

            if socialFocus {
                pochenStatusLine
                    .frame(width: min(330, w - 28))
                    .offset(y: topH + 8)
                    .transition(phase2ReduceMotion ? .opacity : .move(edge: .bottom)
                        .combined(with: .opacity))

                portraitsRow(maxPanelWidth: veryCompactHeight
                             ? 98
                             : (compactHeight ? 103 : 108))
                    .frame(width: w, height: opponentRowHeight,
                           alignment: .top)
                    .offset(y: seatsY)
                    .modifier(GuidedFocusModifier(
                        isActive: isGuidedRound,
                        isRelevant: true,
                        reduceMotion: phase2ReduceMotion
                    ))
                    .allowsHitTesting(!isGuidedRound || guidedFocus == .opponents)
                    .transition(phase2ReduceMotion ? .opacity : .scale(scale: 0.96)
                        .combined(with: .opacity))
            }

            handFan(cardScale: compactHeight ? 1.48 : 1.62)
                .frame(width: w, height: compactHeight ? 138 : 150, alignment: .bottom)
                .position(x: w / 2,
                          y: h - (game.stage == .betting ? 58 : 0)
                              + (accessibilityResult ? 5 : 0))
                .allowsHitTesting(false)
                .opacity(accessibilityBetting && !socialFocus ? 0 : 1)
                .accessibilityHidden(accessibilityBetting && !socialFocus)
            // Die eigene Hand bleibt immer vollständig deckend. Opacity
            // auf dem gesamten Fächer lässt sonst Karten darunter durch-
            // scheinen und liest sich wie ein unscharfes Doppelbild.
        }
    }

    /// Kompakte Querformat-Bühne mit drei unabhängigen Zonen. Links liegen Range
    /// und Karten, in der Mitte die Entscheidung, rechts Disc und Gegnerplätze.
    private func landscapeStage(width w: CGFloat, height h: CGFloat) -> some View {
        let boardDiameter = compactRingDiameter
        let accessibilityResult = game.stage != .betting
            && dynamicTypeSize.isAccessibilitySize
        let accessibilityResultWidth = w - boardDiameter - 16
        let centerX = accessibilityResult ? accessibilityResultWidth / 2 : w * 0.38
        let decisionWidth = accessibilityResult
            ? accessibilityResultWidth
            : min(250, w * 0.39)
        let opponentWidth = min(292, w * 0.43)
        let actionHeight: CGFloat = game.stage == .betting
            ? (dynamicTypeSize.isAccessibilitySize ? 58 : 44)
            : resultActionAreaHeight
        let guidedPreludeActive = isGuidedRound && guidedPreludeStep < 2
        let decisionHeight: CGFloat = {
            if dynamicTypeSize.isAccessibilitySize {
                return game.stage == .betting ? 154 : 176
            }
            if guidedPreludeActive { return 144 }
            if isGuidedRound, game.stage != .betting { return 198 }
            return isGuidedRound ? 108 : 98
        }()
        let actionGap: CGFloat = dynamicTypeSize.isAccessibilitySize ? 10 : 8
        let actionCenterY = decisionHeight + actionGap + actionHeight / 2
        return ZStack(alignment: .top) {
            sliderPanel
                .scaleEffect(0.72)
                .position(x: 34, y: min(h * 0.38, 96))
                .modifier(GuidedFocusModifier(
                    isActive: isGuidedRound,
                    isRelevant: guidedFocus == .range || guidedFocus == .actions,
                    reduceMotion: phase2ReduceMotion
                ))
                .opacity(isGuidedRound && guidedPreludeStep < 2 ? 0 : 1)

            let landscapeBoardScale: CGFloat = 0.92
            compactRing
                .scaleEffect(landscapeBoardScale)
                .position(x: w - boardDiameter * landscapeBoardScale / 2 - 26,
                          y: boardDiameter * landscapeBoardScale / 2 + 8)
                .modifier(TableShake(
                    amplitude: phase2ReduceMotion ? 0 : Tokens.pochShakeAmp,
                    animatableData: CGFloat(game.pochShock)))
                .animation(.linear(duration: Tokens.pochShake), value: game.pochShock)

            trumpTableCard
                .scaleEffect(0.88)
                .position(
                    x: w - boardDiameter * landscapeBoardScale - 50,
                    y: 54
                )
                .zIndex(3)

            pochenDecisionCard
                .frame(width: decisionWidth,
                       height: decisionHeight,
                       alignment: .top)
                .position(x: centerX, y: decisionHeight / 2 + 1)
                .zIndex(guidedPreludeActive ? 4 : 0)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("phase2.decision")

            actionArea
                .frame(width: decisionWidth - 8, height: actionHeight, alignment: .top)
                .position(x: centerX, y: actionCenterY)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("phase2.actions")
                .modifier(GuidedFocusModifier(
                    isActive: isGuidedRound,
                    isRelevant: guidedFocus == .actions,
                    reduceMotion: phase2ReduceMotion
                ))
                .allowsHitTesting(!isGuidedRound || guidedFocus == .actions)
                .opacity(isGuidedRound && guidedFocus != .actions ? 0 : 1)

            portraitsRow(maxPanelWidth: 86)
                .frame(width: opponentWidth, height: 84, alignment: .top)
                .position(x: w - opponentWidth / 2,
                          y: max(boardDiameter + 46, h - 44))
                .modifier(GuidedFocusModifier(
                    isActive: isGuidedRound,
                    isRelevant: guidedFocus == .opponents,
                    reduceMotion: phase2ReduceMotion
                ))
                .opacity(isGuidedRound && guidedFocus != .opponents ? 0 : 1)
                .allowsHitTesting(!isGuidedRound || guidedFocus == .opponents)

            handFan(cardScale: 0.82)
                .frame(width: w * 0.42, height: 64, alignment: .bottom)
                .position(x: w * 0.34, y: h - 18)
                .allowsHitTesting(false)
        }
    }

    private var guidedFocus: GuidedFocus {
        guard isGuidedRound else { return .none }
        if game.stage != .betting { return .actions }
        if transferPresentationActive || game.turnIndex != 0 { return .opponents }
        if game.betting.currentBet > 0 || game.humanComboRank == nil { return .actions }
        switch guidedPreludeStep {
        case 0: return .hand
        case 1: return .range
        default: return .actions
        }
    }

    private func schedulePotPresentation(_ value: Int) {
        guard value > presentedPot, !phase2ReduceMotion else {
            presentedPot = value
            pendingPot = nil
            return
        }
        pendingPot = value
    }

    /// Jede öffentliche Gegnerentscheidung bekommt einen eigenen Auftritt. Die
    /// Engine darf mehrere Bots schnell nacheinander auflösen; die UI bewahrt
    /// trotzdem Reihenfolge, Sitz und mindestens 1,8 Sekunden Lesezeit.
    private func enqueueOpponentReactions(previous: [SeatAction],
                                           current: [SeatAction]) {
        let additions = current.indices.compactMap { seat -> PresentedReaction? in
            guard seat != 0,
                  previous.indices.contains(seat),
                  previous[seat] != current[seat],
                  isSettledReaction(current[seat]) else { return nil }
            return PresentedReaction(seat: seat, action: current[seat])
        }
        guard !additions.isEmpty else { return }
        queuedReactions.append(contentsOf: additions)
        startReactionSequenceIfNeeded()
    }

    private func startReactionSequenceIfNeeded() {
        guard featuredReaction == nil, !queuedReactions.isEmpty else { return }
        reactionPresentationGeneration += 1
        let generation = reactionPresentationGeneration
        featuredReaction = queuedReactions.removeFirst()
        scheduleReactionAdvance(generation: generation)
    }

    private func scheduleReactionAdvance(generation: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(isGuidedRound ? 2.15 : 1.85))
            guard generation == reactionPresentationGeneration else { return }

            if queuedReactions.isEmpty {
                withAnimation(phase2ReduceMotion ? nil : .easeOut(duration: 0.24)) {
                    featuredReaction = nil
                }
                if game.stage != .betting {
                    startPayoutPresentationIfNeeded()
                }
                return
            }

            // Der alte Sitz blendet aus, während der neue am tatsächlichen Sitz
            // aufblendet. Kein leeres Zwischenbild, kein springender Sammeltext.
            let next = queuedReactions.removeFirst()
            withAnimation(phase2ReduceMotion ? nil : .easeInOut(duration: 0.24)) {
                featuredReaction = next
            }
            scheduleReactionAdvance(generation: generation)
        }
    }

    private func isSettledReaction(_ action: SeatAction) -> Bool {
        switch action {
        case .passed, .opened, .called, .raised:
            return true
        case .none, .thinking:
            return false
        }
    }

    private func commitBetImpact(transfer: Int) {
        guard transfer == game.betTransfer,
              transfer > settledBetTransfer else { return }
        settledBetTransfer = transfer
        if soundEnabled {
            TableFoleyAudio.shared.playChipContact(
                sequence: transfer,
                generation: game.betTransfer,
                seat: game.lastBetActor ?? game.turnIndex,
                playerCount: game.playerCount,
                isPayout: false
            )
        }
        withAnimation(phase2ReduceMotion ? nil : .spring(duration: Tokens.p2PotSpring)) {
            presentedPot = pendingPot ?? game.pot
            pendingPot = nil
            transferPresentationActive = false
        }
        if game.stage != .betting {
            startPayoutPresentationIfNeeded()
        }
    }

    private func startPayoutPresentationIfNeeded() {
        guard game.stage != .betting else { return }
        guard game.betTransfer == settledBetTransfer else { return }
        guard game.pochResult != nil else {
            payoutPresentationCompleted = true
            return
        }
        guard !payoutPresentationActive,
              !payoutPresentationCompleted,
              !payoutStartScheduled else { return }
        payoutStartScheduled = true
        Task { @MainActor in
            // Einen Renderzyklus abwarten: So können der letzte öffentliche
            // Gegnerzug und die gemessenen Sitzanker zuerst am Tisch ankommen.
            try? await Task.sleep(for: .milliseconds(140))
            payoutStartScheduled = false
            guard game.stage != .betting,
                  game.betTransfer == settledBetTransfer,
                  featuredReaction == nil,
                  queuedReactions.isEmpty,
                  !payoutPresentationActive,
                  !payoutPresentationCompleted else { return }
            pendingPot = nil
            transferPresentationActive = false
            payoutPresentationGeneration += 1
            payoutPresentationActive = true
        }
    }

    private func commitPayoutImpact(generation: Int) {
        guard generation == payoutPresentationGeneration,
              payoutPresentationActive else { return }
        payoutPresentationActive = false
        payoutPresentationCompleted = true
        payoutImpact += 1
        if soundEnabled, let winner = game.pochResult?.winner {
            TableFoleyAudio.shared.playChipContact(
                sequence: game.pochResult?.pot ?? 0,
                generation: generation,
                seat: winner,
                playerCount: game.playerCount,
                isPayout: true
            )
        }
        withAnimation(phase2ReduceMotion ? nil : PhysicalMotion.materialSettle) {
            presentedPot = 0
        }
    }

    private var pochAccent: Color {
        theme.isTravelTable ? Tokens.jewelAmethyst : Tokens.amethystText
    }

    private func scheduleGuidedPrelude() {
        // Die geführte Runde erklärt erst die Voraussetzung und den Einsatz.
        // Die echte Poch-Aktion wird erst danach freigeschaltet. So behauptet
        // kein Timer, dass eine noch nicht getroffene Entscheidung verstanden ist.
        guidedPreludeStep = isGuidedRound ? 0 : 2
    }

    private func advanceGuidedPrelude() {
        guard guidedPreludeStep < 2 else { return }
        if guidedPreludeStep == 1,
           let range = game.humanLegal?.openRange {
            bid = Double(range.lowerBound)
        }
        withAnimation(phase2ReduceMotion
                      ? nil
                      : .easeInOut(duration: Tokens.guidedFocusTransition)) {
            guidedPreludeStep += 1
        }
    }

    private var pochenHint: String {
        if transferPresentationActive {
            let responder = game.name(of: game.turnIndex)
            let format = String(localized: "phase2.transfer.reply",
                                defaultValue: "Deine Chips liegen im Poch-Pott. Jetzt wählt %@: mitgehen, erhöhen oder passen.")
            return String(format: format, responder)
        }
        if game.stage != .betting {
            return String(localized: "phase2.hint.resolved",
                          defaultValue: "Der Poch-Pott ist entschieden. Als Nächstes spielt ihr eure Karten in Reihen aus.")
        }
        if game.turnIndex == 0 {
            if game.humanComboRank == nil {
                return String(localized: "phase2.hint.noPair",
                              defaultValue: "Du hast kein Paar. Tippe Passen - so behältst du deine Chips.")
            }
            let format = String(localized: "phase2.hint.open",
                                defaultValue: "Poche um %d Chips. Wer mitgeht, bleibt im Rennen um den Poch-Pott.")
            return String(format: format, Int(bid))
        }
        let format = String(localized: "phase2.hint.opponentTurn",
                            defaultValue: "%@ entscheidet jetzt: mitgehen, erhöhen oder passen.")
        return String(format: format, game.name(of: game.turnIndex))
    }

    /// Kompakter Mockup-Status statt grosser Coach-Box: Phase 2 soll wie ein
    /// Tischmoment wirken, nicht wie ein Tutorial-Screen.
    private var pochenStatusLine: some View {
        let status = pochenStatus
        return HStack(spacing: 8) {
            Circle()
                .fill(status.tint.opacity(0.86))
                .frame(width: 7, height: 7)
                .shadow(color: status.tint.opacity(theme.isTravelTable ? 0.22 : 0.18), radius: 4)
            Text(status.title)
                .font(.system(size: 18, weight: .heavy))
                .tracking(0.2)
                .foregroundStyle(status.tint)
                .contentTransition(.opacity)
            if let detail = status.detail {
                Text(detail)
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(Tokens.slate.opacity(0.76))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.035))
                .overlay(Capsule().strokeBorder(status.tint.opacity(0.20), lineWidth: 1))
        )
        .animation(.easeOut(duration: 0.18), value: game.turnIndex)
    }

    private var pochenStatus: (title: String, detail: String?, tint: Color) {
        if transferPresentationActive, let actor = game.lastBetActor {
            let action = actionPresentation(for: actor)
            return (game.name(of: actor).uppercased(), action.text.uppercased(), action.tone)
        }
        if game.stage != .betting {
            if let result = game.pochResult {
                if result.winner == 0 {
                    return (String(localized: "phase2.result.youWon", defaultValue: "POCH-POTT GEWONNEN"),
                            nil,
                            Tokens.jewelGold)
                }
                return (game.name(of: result.winner).uppercased(),
                        String(localized: "phase2.result.wins", defaultValue: "GEWINNT DEN POCH-POTT"),
                        Tokens.jewelGold)
            }
            return (String(localized: "phase2.result.noBid", defaultValue: "ALLE PASSEN"),
                    String(localized: "phase2.result.carries", defaultValue: "POCH-POTT WÄCHST WEITER"),
                    Tokens.slate)
        }
        if game.turnIndex == 0 {
            guard let combo = game.humanCombo else {
                return (String(localized: "phase2.status.pass",
                               defaultValue: "PASSEN"),
                        String(localized: "phase2.status.noPair",
                               defaultValue: "KEIN PAAR"),
                        Tokens.slate)
            }
            return (String(localized: "phase2.status.yourTurn",
                           defaultValue: "DU BIST DRAN"),
                    localizedCombo(combo).uppercased(),
                    pochAccent)
        }
        let action = actionPresentation(for: game.turnIndex)
        return (action.text.uppercased(), game.name(of: game.turnIndex).uppercased(), action.tone)
    }

    private var pochenDecisionCard: some View {
        let status = pochenStatus
        let committed = game.humanCommitted
        return VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 7) {
                if isGuidedRound {
                    guidedDecisionHeader
                    if guidedPreludeStep == 0,
                       game.stage == .betting,
                       game.turnIndex == 0,
                       let combo = game.humanCombo {
                        Text(localizedCombo(combo).uppercased())
                            .font(.system(size: 11.5, weight: .heavy))
                            .tracking(0.9)
                            .foregroundStyle(Tokens.jewelPlatin)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(pochAccent.opacity(0.34)))
                            .overlay(Capsule().strokeBorder(
                                pochAccent.opacity(0.72), lineWidth: 1
                            ))
                    }
                } else {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(status.tint.opacity(0.88))
                            .frame(width: 7, height: 7)
                            .shadow(color: status.tint.opacity(0.26), radius: 4)
                        Text(status.title)
                            .font(.system(size: 17.5, weight: .heavy))
                            .tracking(0.15)
                            .foregroundStyle(status.tint)
                            .lineLimit(1)
                        if let detail = status.detail {
                            Text(detail)
                                .font(.system(size: 10.5, weight: .heavy))
                                .tracking(0.8)
                                .foregroundStyle(Tokens.slate.opacity(0.66))
                                .lineLimit(1)
                        }
                    }
                }

                Text(isGuidedRound ? guidedDecisionBody : freeDecisionBody)
                    .font(dynamicTypeSize.isAccessibilitySize
                          ? .body.weight(.semibold)
                          : .system(size: isGuidedRound ? 13.2 : 13.0,
                                    weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(isGuidedRound ? 0.92 : 0.76))
                    .lineSpacing(isGuidedRound ? 1.8 : 1.2)
                    .lineLimit(isGuidedRound || dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("phase2.guided.body")

                if isGuidedRound,
                   let summary = game.pochShowdownSummary,
                   let runnerUp = summary.runnerUp,
                   let runnerUpCombo = summary.runnerUpCombo {
                    guidedShowdownDuel(summary: summary,
                                       runnerUp: runnerUp,
                                       runnerUpCombo: runnerUpCombo)
                }

                if isGuidedRound {
                    Rectangle()
                        .fill(guidedDecisionCopy.tint.opacity(0.16))
                        .frame(height: 1)
                }

                if game.stage == .betting, !isGuidedRound {
                    HStack(spacing: 8) {
                        pressureMetric(String(localized: "phase2.metric.yourBid",
                                              defaultValue: "DEIN GEBOT"),
                                       "\(Int(bid))",
                                       pochAccent)
                        pressureMetric(String(localized: "phase2.metric.inPoch",
                                              defaultValue: "IM POTT"),
                                       "\(game.pot + game.pochPool)", Tokens.jewelGold)
                        pressureMetric(String(localized: "phase2.metric.fromYou",
                                              defaultValue: "VON DIR"),
                                       "\(committed)", theme.isTravelTable ? Tokens.jewelSmaragd : Tokens.smaragdText)
                    }
                }

                if isGuidedRound, guidedPreludeStep == 0,
                   game.turnIndex == 0, game.betting.currentBet == 0 {
                    Button(action: advanceGuidedPrelude) {
                        HStack(spacing: 7) {
                            Text(dynamicTypeSize.isAccessibilitySize
                                 ? String(localized: "Einsatz")
                                 : guidedPreludeActionTitle)
                            Image(systemName: "arrow.right")
                        }
                        .font(dynamicTypeSize.isAccessibilitySize
                              ? .callout.weight(.bold)
                              : .system(size: 13.5, weight: .bold))
                        .foregroundStyle(Tokens.bgDeep)
                        .frame(maxWidth: .infinity,
                               minHeight: dynamicTypeSize.isAccessibilitySize ? 52 : 44)
                        .background(Capsule().fill(guidedDecisionCopy.tint))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(guidedPreludeActionTitle)
                    .accessibilityIdentifier("phase2.guided.prelude.action")
                    .transition(phase2ReduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity))
                }

                if isGuidedRound, guidedPreludeStep == 1,
                   game.turnIndex == 0, game.betting.currentBet == 0 {
                    guidedStakeChoices
                        .transition(phase2ReduceMotion
                                    ? .opacity
                                    : .move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [
                    (isGuidedRound ? guidedDecisionCopy.tint : status.tint).opacity(isGuidedRound ? 0.12 : 0.04),
                    Color(hex: 0x0B0910).opacity(0.92)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .strokeBorder((isGuidedRound ? guidedDecisionCopy.tint : status.tint)
                        .opacity(isGuidedRound ? 0.42 : 0.20), lineWidth: 1))
                .shadow(color: (isGuidedRound ? guidedDecisionCopy.tint : .black)
                    .opacity(isGuidedRound ? 0.10 : 0.36), radius: 16, y: 8)
        )
        .padding(.horizontal, 10)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func guidedShowdownDuel(summary: PochShowdownSummary,
                                    runnerUp: Int,
                                    runnerUpCombo: Combo) -> some View {
        let winnerName = summary.winner == 0
            ? String(localized: "phase2.result.you", defaultValue: "DU")
            : game.name(of: summary.winner).uppercased()
        let runnerName = runnerUp == 0
            ? String(localized: "phase2.result.you", defaultValue: "DU")
            : game.name(of: runnerUp).uppercased()

        return HStack(spacing: 8) {
            showdownComboBadge(name: winnerName,
                               seat: summary.winner,
                               combo: summary.winningCombo,
                               tint: Tokens.jewelGold)
            Image(systemName: "chevron.right.2")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Tokens.jewelGold.opacity(0.86))
            showdownComboBadge(name: runnerName,
                               seat: runnerUp,
                               combo: runnerUpCombo,
                               tint: Tokens.slate)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(
            format: String(localized: "phase2.showdown.accessibility",
                           defaultValue: "%1$@: %2$@ schlägt %3$@: %4$@"),
            winnerName,
            localizedCombo(summary.winningCombo),
            runnerName,
            localizedCombo(runnerUpCombo)
        ))
    }

    private func showdownComboBadge(name: String,
                                    seat: Int,
                                    combo: Combo,
                                    tint: Color) -> some View {
        let cards = showdownCards(seat: seat, combo: combo)
        return VStack(spacing: 4) {
            Text(name)
                .font(.system(size: 8.5, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(tint.opacity(0.9))

            HStack(spacing: -16) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    ZStack {
                        CardFace(card: card,
                                 highlighted: seat == 0,
                                 scale: 0.74,
                                 isAccessibilityHidden: true)
                        Color.clear
                            .frame(width: 52 * 0.74, height: 74 * 0.74)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(card.rank.index)\(card.suit.symbol)")
                            .accessibilityAddTraits(.isImage)
                            .accessibilityIdentifier(
                                "phase2.showdown.\(seat).card.\(card.suit.rawValue).\(card.rank.index)"
                            )
                    }
                        .rotationEffect(.degrees(showdownCardAngle(index: index,
                                                                  count: cards.count)),
                                        anchor: .bottom)
                        .zIndex(Double(index))
                }
            }
            .accessibilityElement(children: .contain)

            Text(localizedCombo(combo))
                .font(.system(size: 8.2, weight: .bold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .phase2PayoutAnchor(.opponent(seat))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("phase2.showdown.\(seat)")
    }

    /// Gegnerkarten verlassen die Informationsgrenze erst nach dem öffentlichen
    /// Showdown. Dann werden exakt die Karten gezeigt, aus denen die verglichene
    /// Kombination tatsächlich besteht.
    private func showdownCards(seat: Int, combo: Combo) -> [Card] {
        guard game.stage != .betting,
              game.pochShowdownSummary != nil,
              let roundSeat = game.roundSeat(forUISeat: seat),
              game.round.deal.hands.indices.contains(roundSeat) else { return [] }
        return Array(game.round.deal.hands[roundSeat]
            .filter { $0.rank == combo.rank }
            .prefix(showdownCardCount(combo.kind)))
    }

    private func showdownCardCount(_ kind: Combo.Kind) -> Int {
        switch kind {
        case .pair: 2
        case .triple: 3
        case .quad: 4
        }
    }

    private func showdownCardAngle(index: Int, count: Int) -> Double {
        guard count > 1 else { return 0 }
        return -4 + (8 * Double(index) / Double(count - 1))
    }

    private var freeDecisionBody: String {
        if assistHints {
            return pochenHint
        }
        return pochenStatus.detail ?? pochenStatus.title
    }

    /// Accessibility sizes use progressive disclosure: the visible card keeps
    /// the rule and the next action together, while the combo badge directly
    /// above it still names the concrete hand. The full explanation remains in
    /// the standard-size guided flow instead of being visually compressed.
    private var guidedDecisionBody: String {
        guard dynamicTypeSize.isAccessibilitySize,
              game.stage == .betting,
              game.turnIndex == 0,
              guidedPreludeStep == 0 else {
            return guidedDecisionCopy.body
        }
        return String(localized: "firstRun.cinematic.bidding.title",
                      defaultValue: "Mit gleichen Werten darfst du pochen.")
    }

    private var guidedDecisionHeader: some View {
        let copy = guidedDecisionCopy
        return HStack(spacing: 8) {
            Image(systemName: copy.step)
                .font(.system(size: 8.2, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.bgDeep)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(copy.tint))
            Text(copy.title)
                .font(dynamicTypeSize.isAccessibilitySize
                      ? .headline.weight(.heavy)
                      : .system(size: 16.5, weight: .heavy))
                .foregroundStyle(copy.tint)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityIdentifier("phase2.guided.title")
            Spacer(minLength: 0)
        }
    }

    private var guidedDecisionCopy: (step: String, title: String, body: String, tint: Color) {
        if game.stage != .betting {
            return guidedResultCopy
        }
        if transferPresentationActive {
            return (
                "arrow.down.to.line.compact",
                String(localized: "tutorial.bidding.transfer.title", defaultValue: "Der Einsatz steht."),
                String(localized: "tutorial.bidding.transfer.body", defaultValue: "Jetzt sind die anderen dran: mitgehen, erhöhen oder passen."),
                pochAccent
            )
        }
        if game.turnIndex != 0 {
            let format = String(localized: "tutorial.bidding.observe.body",
                                defaultValue: "%@ kann mitgehen, erhöhen oder passen.")
            let titleFormat = String(localized: "tutorial.bidding.observe.title",
                                     defaultValue: "%@ ist dran")
            let actor = game.name(of: game.turnIndex)
            return (
                "eye.fill",
                String(format: titleFormat, actor),
                String(format: format, actor),
                pochAccent
            )
        }
        if game.betting.currentBet > 0 {
            let callCost = max(0, game.betting.currentBet - game.humanCommitted)
            let reply: String
            if callCost == 1 {
                reply = String(localized: "tutorial.bidding.reply.body.one",
                               defaultValue: "Zahle 1 weiteren Chip, um im Gebot zu bleiben. Passt du, bist du raus; dein bisheriger Einsatz bleibt im Poch-Pott.")
            } else {
                let format = String(localized: "tutorial.bidding.reply.body.many",
                                    defaultValue: "Zahle %d weitere Chips, um im Gebot zu bleiben. Passt du, bist du raus; dein bisheriger Einsatz bleibt im Poch-Pott.")
                reply = String(format: format, callCost)
            }
            return (
                "arrow.left.arrow.right.circle.fill",
                String(localized: "tutorial.bidding.reply.title", defaultValue: "Mitgehen oder passen?"),
                reply,
                pochAccent
            )
        }
        guard let humanCombo = game.humanCombo else {
            return (
                "forward.fill",
                String(localized: "tutorial.bidding.noPair.title", defaultValue: "Du setzt diesmal aus."),
                String(localized: "tutorial.bidding.noPair.body", defaultValue: "Zum Pochen brauchst du mindestens zwei gleiche Karten. Diesmal passt du und setzt nichts."),
                Tokens.slate
            )
        }
        switch guidedPreludeStep {
        case 0:
            let titleFormat = String(localized: "tutorial.bidding.pair.title",
                                     defaultValue: "%@: Du darfst pochen.")
            return (
                "rectangle.on.rectangle.angled",
                String(format: titleFormat, localizedCombo(humanCombo)),
                String(localized: "tutorial.bidding.combo.body",
                       defaultValue: "Mit mindestens zwei Karten desselben Werts darfst du pochen. Ein Drilling schlägt jedes Paar; ein Vierling jeden Drilling."),
                pochAccent
            )
        case 1:
            return (
                "dial.medium.fill",
                String(localized: "tutorial.bidding.stake.title", defaultValue: "Wie viel willst du riskieren?"),
                String(localized: "tutorial.bidding.stake.body", defaultValue: "1 Chip ist vorsichtig. Mit 2 Chips wächst der Poch-Pott - und dein Risiko."),
                pochAccent
            )
        default:
            let committedBid = Int(bid)
            let body: String
            if committedBid == 1 {
                body = String(localized: "tutorial.bidding.commit.body.one",
                              defaultValue: "Du setzt 1 Chip. Jetzt können die anderen mitgehen, erhöhen oder passen.")
            } else {
                let format = String(localized: "tutorial.bidding.commit.body.many",
                                    defaultValue: "Du setzt %d Chips. Jetzt können die anderen mitgehen, erhöhen oder passen.")
                body = String(format: format, committedBid)
            }
            return (
                "hand.tap.fill",
                String(localized: "tutorial.bidding.commit.title", defaultValue: "Jetzt pochen"),
                body,
                pochAccent
            )
        }
    }

    private var guidedResultCopy: (step: String, title: String, body: String, tint: Color) {
        if let summary = game.pochShowdownSummary {
            let winnerCombo = localizedCombo(summary.winningCombo)
            let title: String
            if summary.winner == 0 {
                let titleFormat = String(localized: "tutorial.bidding.showdown.you",
                                         defaultValue: "%@ gewinnen.")
                title = String(format: titleFormat, winnerCombo)
            } else {
                let titleFormat = String(localized: "tutorial.bidding.showdown.title",
                                         defaultValue: "%@ gewinnt den Poch-Pott")
                title = String(format: titleFormat, game.name(of: summary.winner))
            }
            let comparison: String
            if let runnerUpCombo = summary.runnerUpCombo {
                let format = String(localized: "tutorial.bidding.showdown.comparison",
                                    defaultValue: "%@ schlagen %@.")
                comparison = String(format: format,
                                    winnerCombo,
                                    sentenceContinuation(localizedCombo(runnerUpCombo)))
            } else {
                comparison = String(localized: "tutorial.bidding.showdown.rule",
                                    defaultValue: "Vierling schlägt Drilling, Drilling schlägt Paar. Bei derselben Kombination zählt der höhere Wert; bei gleichem Paar entscheidet Trumpf.")
            }
            let reward = summary.winner == 0
                ? String(localized: "tutorial.bidding.showdown.reward.you",
                         defaultValue: "Du nimmst den Poch-Pott.")
                : String(format: String(localized: "tutorial.bidding.showdown.reward.opponent",
                                        defaultValue: "%@ bekommt alle Chips im Poch-Pott."),
                         game.name(of: summary.winner))
            return ("rectangle.2.swap",
                    title,
                    comparison + " " + reward,
                    Tokens.jewelGold)
        }
        if let result = game.pochResult {
            let title = result.winner == 0
                ? String(localized: "tutorial.bidding.uncontested.you",
                         defaultValue: "Du gewinnst den Poch-Pott")
                : String(format: String(localized: "tutorial.bidding.uncontested.title",
                                        defaultValue: "%@ gewinnt den Poch-Pott"),
                         game.name(of: result.winner))
            return ("hand.thumbsup.fill",
                    title,
                    String(localized: "tutorial.bidding.uncontested.body",
                           defaultValue: "Alle anderen passen. Der letzte Spieler im Gebot nimmt den Poch-Pott - ohne Aufdecken."),
                    Tokens.jewelGold)
        }
        return ("arrow.clockwise",
                String(localized: "tutorial.bidding.allPassed.title", defaultValue: "Alle passen - der Poch-Pott wächst weiter"),
                String(localized: "tutorial.bidding.allPassed.body",
                       defaultValue: "Die Chips bleiben liegen. In der nächsten Runde kommt der neue Einsatz dazu."),
                Tokens.slate)
    }

    private func sentenceContinuation(_ value: String) -> String {
        guard Locale.current.language.languageCode?.identifier == "de",
              let first = value.first else { return value }
        return first.lowercased() + String(value.dropFirst())
    }

    private func localizedCombo(_ combo: Combo) -> String {
        if Locale.current.language.languageCode?.identifier == "de" {
            let amount: String
            switch combo.kind {
            case .pair: amount = "Zwei"
            case .triple: amount = "Drei"
            case .quad: amount = "Vier"
            }
            let rank: String
            switch combo.rank {
            case .seven: rank = "Siebener"
            case .eight: rank = "Achter"
            case .nine: rank = "Neuner"
            case .ten: rank = "Zehner"
            case .jack: rank = "Buben"
            case .queen: rank = "Damen"
            case .king: rank = "Könige"
            case .ace: rank = "Asse"
            }
            return "\(amount) \(rank)"
        }
        let format: String
        switch combo.kind {
        case .pair:
            format = String(localized: "tutorial.bidding.combo.pair", defaultValue: "Paar · %@")
        case .triple:
            format = String(localized: "tutorial.bidding.combo.triple", defaultValue: "Drilling · %@")
        case .quad:
            format = String(localized: "tutorial.bidding.combo.quad", defaultValue: "Vierling · %@")
        }
        return String(format: format, combo.rank.index)
    }

    private var guidedPreludeActionTitle: String {
        switch guidedPreludeStep {
        case 0:
            return String(localized: "tutorial.bidding.action.toStake",
                          defaultValue: "Einsatz wählen")
        default:
            return "Weiter"
        }
    }

    private var guidedStakeChoices: some View {
        HStack(spacing: 8) {
            guidedStakeChoice(
                amount: 1,
                title: String(localized: "tutorial.bidding.stake.safe",
                              defaultValue: "1 Chip"),
                caption: String(localized: "tutorial.bidding.stake.safe.caption",
                                defaultValue: "kleiner Einsatz")
            )
            if (game.humanLegal?.openRange?.upperBound ?? 1) >= 2 {
                guidedStakeChoice(
                    amount: 2,
                    title: String(localized: "tutorial.bidding.stake.bold",
                                  defaultValue: "2 Chips"),
                    caption: String(localized: "tutorial.bidding.stake.bold.caption",
                                    defaultValue: "doppelter Einsatz")
                )
            }
        }
    }

    private func guidedStakeChoice(amount: Int,
                                   title: String,
                                   caption: String) -> some View {
        Button {
            guard let range = game.humanLegal?.openRange else { return }
            bid = Double(amount.clamped(to: range))
            withAnimation(phase2ReduceMotion
                          ? nil
                          : .easeInOut(duration: Tokens.guidedFocusTransition)) {
                guidedPreludeStep = 2
            }
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
                Text(caption)
                    .font(.system(size: 9.5, weight: .semibold))
                    .opacity(0.72)
            }
            .foregroundStyle(amount == 1 ? Tokens.jewelPlatin : Tokens.bgDeep)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                Capsule()
                    .fill(amount == 1
                          ? Color.white.opacity(0.065)
                          : Tokens.jewelGold)
                    .overlay(Capsule().strokeBorder(
                        amount == 1
                            ? Tokens.jewelPlatin.opacity(0.24)
                            : Tokens.jewelGold.opacity(0.92),
                        lineWidth: 1
                    ))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(caption)")
        .accessibilityIdentifier("phase2.guided.stake.\(amount)")
    }

    private func localizedTendency(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    private func stakeDial(status: (title: String, detail: String?, tint: Color)) -> some View {
        let active = game.stage == .betting && game.turnIndex == 0 && game.humanComboRank != nil
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [
                    status.tint.opacity(active ? 0.28 : 0.12),
                    Color(hex: 0x0B0910).opacity(0.92)
                ], center: .topLeading, startRadius: 3, endRadius: 50))
                .overlay(Circle().strokeBorder(status.tint.opacity(active ? 0.45 : 0.22), lineWidth: 1.2))
                .overlay(Circle().strokeBorder(Tokens.jewelPlatin.opacity(0.08), lineWidth: 5).padding(3))
                .shadow(color: status.tint.opacity(active ? 0.16 : 0.04), radius: 10, y: 5)

            VStack(spacing: -1) {
                Text(active
                     ? String(localized: "phase2.stakeDial.set", defaultValue: "SETZE")
                     : String(localized: "phase2.metric.poch", defaultValue: "POCH"))
                    .font(.system(size: 7, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(status.tint.opacity(0.82))
                Text(active ? "\(Int(bid))" : "\(presentedPot)")
                    .font(.system(size: 25, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .contentTransition(.numericText())
                Text("+\(game.pochPool)")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(Tokens.jewelGold.opacity(0.82))
            }
        }
        .frame(width: 68, height: 68)
        .accessibilityLabel(active
                            ? String(format: String(localized: "phase2.accessibility.stake",
                                                    defaultValue: "Einsatz %d"),
                                     Int(bid))
                            : String(format: String(localized: "phase2.accessibility.poch",
                                                    defaultValue: "Poch %d"),
                                     presentedPot))
    }

    private var pochenHintPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.jewelAmethyst)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Tokens.jewelAmethyst.opacity(0.13)))
            Text(pochenHint)
                .font(.system(size: 10.2, weight: .semibold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.76))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: 310)
        .background(
            Capsule()
                .fill(Color(hex: 0x100E15).opacity(0.78))
                .overlay(Capsule().strokeBorder(Tokens.jewelAmethyst.opacity(0.18), lineWidth: 1))
        )
    }

    // MARK: - Slider LINKS / Ring RECHTS (Mockup-Delta Phase 2)

    private var topArea: some View {
        GeometryReader { proxy in
            let sliderVisualRightEdge = Phase2StageGeometry.portraitSliderVisualRightEdge
            let freeStageCenterX = sliderVisualRightEdge
                + (proxy.size.width - sliderVisualRightEdge) / 2
            let boardCenterX = isGuidedRound ? proxy.size.width / 2 : freeStageCenterX
            let boardLeftEdge = boardCenterX - compactRingDiameter / 2
            let trumpCenterX = isGuidedRound
                ? max(34, boardLeftEdge / 2)
                : sliderVisualRightEdge + (boardLeftEdge - sliderVisualRightEdge) / 2
            ZStack {
                sliderPanel
                    .position(x: 36, y: proxy.size.height / 2 + 1)
                    .modifier(GuidedFocusModifier(
                        isActive: isGuidedRound,
                        isRelevant: guidedFocus == .range || guidedFocus == .actions,
                        reduceMotion: phase2ReduceMotion
                    ))
                    .opacity(isGuidedRound ? 0 : 1)
                    .allowsHitTesting(!isGuidedRound)
                compactRing
                    .position(x: boardCenterX,
                              y: proxy.size.height / 2)
                    .modifier(GuidedFocusModifier(
                        isActive: isGuidedRound,
                        isRelevant: isGuidedRound || guidedFocus == .opponents,
                        reduceMotion: phase2ReduceMotion
                    ))

                trumpTableCard
                    .position(x: trumpCenterX,
                              y: min(54, proxy.size.height * 0.28))
                    .zIndex(3)
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// Die offene Tischkarte bleibt auch beim Pochen als physische Karte im
    /// Bild. So muss niemand eine winzige Rang-Kapsel im globalen HUD entziffern.
    private var trumpTableCard: some View {
        VStack(spacing: 0) {
            CardFace(card: game.upcard,
                     highlighted: false,
                     scale: 0.80,
                     isAccessibilityHidden: true)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: 0x0B0910).opacity(0.88))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Tokens.jewelGold.opacity(0.34), lineWidth: 1))
                .shadow(color: .black.opacity(0.34), radius: 9, y: 5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Trumpf", defaultValue: "Trumpf"))
        .accessibilityValue("\(game.upcard.rank.index)\(game.upcard.suit.symbol)")
        .accessibilityIdentifier("phase2.trump.card")
    }

    /// Vertikaler Biet-Slider links: Drehtrick (.rotationEffect), Track als gefräste Rille.
    private var sliderPanel: some View {
        let sliderRange = game.humanLegal.flatMap { l in l.openRange ?? l.raiseRange }
        let isActive = game.turnIndex == 0 && game.stage == .betting && sliderRange != nil
        let atWall = sliderRange.map { Int(bid) >= $0.upperBound } ?? false

        return VStack(spacing: 6) {
            Text(String(localized: "phase2.metric.yourBid", defaultValue: "DEIN GEBOT"))
                .font(.system(size: 11.5, weight: .semibold)).tracking(1.8)
                .foregroundStyle(Tokens.slate)

            ZStack {
                if let range = sliderRange {
                    bidRail(range: range, isActive: isActive, atWall: atWall)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.black.opacity(0.30))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.07), lineWidth: 1))
                        .frame(width: 32, height: 150)
                }
            }
            .sensoryFeedback(trigger: atWall) { previous, current in
                guard hapticsEnabled, !previous, current else { return nil }
                return .impact(flexibility: .rigid)
            }

            Text("\(Int(bid))")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(isActive ? pochAccent : Tokens.slate.opacity(0.3))
                .contentTransition(.numericText())
                .frame(minWidth: 48)
        }
        .opacity(sliderRange == nil ? 0 : (isActive ? 1 : 0.45))
        .animation(.easeOut(duration: 0.2), value: isActive)
        .frame(width: 66)
    }

    private func bidRail(range: ClosedRange<Int>, isActive: Bool, atWall: Bool) -> some View {
        let lower = Double(range.lowerBound)
        let upper = Double(range.upperBound)
        let span = max(upper - lower, 1)
        let progress = min(max((bid - lower) / span, 0), 1)

        return GeometryReader { proxy in
            let h = proxy.size.height
            let knobY = h - CGFloat(progress) * h

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(LinearGradient(colors: [
                        Color.black.opacity(0.42),
                        Color(hex: 0x141018).opacity(0.92)
                    ], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(Tokens.jewelGold.opacity(0.24), lineWidth: 1))

                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(colors: [
                        pochAccent.opacity(isActive ? 0.82 : 0.32),
                        Tokens.jewelAmethyst.opacity(isActive ? 0.76 : 0.28)
                    ], startPoint: .top, endPoint: .bottom))
                    .frame(width: 20, height: max(6, CGFloat(progress) * h - 9))
                    .padding(.bottom, 5)
                    .shadow(color: pochAccent.opacity(isActive ? 0.16 : 0), radius: 7)

                Capsule()
                    .fill(LinearGradient(colors: [
                        Tokens.jewelPlatin.opacity(0.96),
                        Tokens.jewelGold.opacity(0.92),
                        Color(hex: 0x7B4F35)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Capsule().strokeBorder(Color.black.opacity(0.44), lineWidth: 1))
                    .overlay(Capsule().strokeBorder(Tokens.jewelPlatin.opacity(0.32), lineWidth: 0.7).padding(2))
                    .frame(width: 48, height: 26)
                    .shadow(color: .black.opacity(0.58), radius: 8, y: 4)
                    .shadow(color: atWall ? Tokens.jewelGold.opacity(0.44) : .clear, radius: 7)
                    .position(x: proxy.size.width / 2, y: min(max(knobY, 14), h - 14))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isActive else { return }
                        let y = min(max(value.location.y, 0), h)
                        let nextProgress = 1 - Double(y / h)
                        bid = (lower + nextProgress * span).rounded()
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(localized: "Einsatz")))
            .accessibilityValue(Text("\(Int(bid))"))
            .accessibilityAdjustableAction { direction in
                guard isActive else { return }
                switch direction {
                case .increment:
                    bid = min(upper, bid + 1)
                case .decrement:
                    bid = max(lower, bid - 1)
                @unknown default:
                    break
                }
            }
            .animation(phase2ReduceMotion
                       ? .linear(duration: 0)
                       : .spring(duration: 0.18),
                       value: bid)
        }
        .frame(width: 54, height: 150)
    }

    /// Kompakter Poch-Ring rechts: miniaturisierte Mulden mit Chip-Werten (§5b Morph-Anker).
    private var compactRing: some View {
        let scale = Tokens.phase2BoardScale
        let r = Tokens.ringRadius * scale
        let tileDia = Tokens.tileDiameter * scale
        let d = r * 2 + tileDia
        return ZStack {
            TableWorldBoardBase(world: theme, diameter: d)
                .opacity(0.88)
                .position(x: d / 2, y: d / 2)
            pochPotMini.position(TableWorldBoardGeometry.wellCenter(for: .center,
                                                                    in: d,
                                                                    world: theme))
            ForEach(PochRing.anchors.filter { $0.pool != .poch }) { anchor in
                miniTile(anchor.pool, dia: tileDia)
                    .matchedGeometryEffect(id: "tile-\(anchor.pool.rawValue)", in: morph)
                    .position(TableWorldBoardGeometry.wellCenter(for: anchor.pool,
                                                                 in: d,
                                                                 world: theme))
            }
            ForEach(PochRing.anchors.filter { $0.pool != .poch }) { anchor in
                PocketValueMarker(world: theme,
                                  pool: anchor.pool,
                                  chips: game.chips(in: anchor.pool),
                                  tint: theme.tint(anchor.pool),
                                  compact: true)
                    .position(TableWorldBoardGeometry.notationCenter(for: anchor.pool,
                                                                     in: d,
                                                                     world: theme))
            }
        }
        .frame(width: d, height: d)
        .tableWorldSpatialPresentation(world: theme, diameter: d)
        .phase2PayoutAnchor(.board)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "phase2.board.accessibility",
                                   defaultValue: "Poch-Brett"))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("table.world.phase2.board")
    }

    private var compactRingDiameter: CGFloat {
        let scale = Tokens.phase2BoardScale
        return Tokens.ringRadius * 2 * scale + Tokens.tileDiameter * scale
    }

    private func pm49Offset(_ angle: Double, radius: CGFloat) -> CGSize {
        let rad = angle * .pi / 180
        return CGSize(width: radius * sin(rad), height: -radius * cos(rad))
    }

    /// §5b Signatur-Flug: P1-Poch-Mulde löst sich und wird zum Pott im Ring-Zentrum.
    private var pochPotMini: some View {
        let growth = 1 + CGFloat(min(presentedPot, 40)) / 400
        return ZStack {
            if presentedPot > 0 {
                TableWorldPiecePile(world: theme,
                                    count: presentedPot,
                                    diameter: Tokens.centerDiameter * 0.42,
                                    compartment: .poch,
                                    placement: .well,
                                    pieceDiameterOverride: Tokens.tableTokenDiameter
                                        * Tokens.phase2BoardScale
                                        * Tokens.r1CompactTokenScale)
                    .offset(y: 1.5)
                    .transition(phase2ReduceMotion
                                ? .opacity
                                : .scale(scale: 0.72).combined(with: .opacity))
            }

            Text(String(localized: "phase2.metric.poch", defaultValue: "POCH"))
                .font(.system(size: 5.8, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(theme.isTravelTable
                    ? pochAccent.opacity(0.76)
                    : Tokens.jewelPlatin.opacity(0.58))
                .offset(y: -15)

            Text("\(presentedPot)")
                .font(.system(size: 8.2, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.jewelGold.opacity(0.92))
                .offset(y: 15)
                .contentTransition(.numericText())
        }
        .frame(width: Tokens.centerDiameter * 0.54, height: Tokens.centerDiameter * 0.54)
        .background {
            if theme.isTravelTable {
                Circle()
                    .fill(LinearGradient(
                        colors: [Tokens.jewelAmethyst.opacity(0.45),
                                 Tokens.jewelAmethyst.opacity(0.18)],
                        startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(
                        LinearGradient(
                            colors: [pochAccent.opacity(0.76),
                                     pochAccent.opacity(0.26)],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.75))
                    .shadow(color: pochAccent.opacity(0.14), radius: 5)
            } else {
                Circle()
                    .strokeBorder(Color(hex: 0x6C7176).opacity(0.48), lineWidth: 0.65)
            }
        }
        .matchedGeometryEffect(id: "pochPot", in: morph)
        .scaleEffect(phase2ReduceMotion ? 1 : growth)
        .animation(phase2ReduceMotion
                   ? .linear(duration: 0)
                   : .spring(duration: Tokens.p2PotSpring),
                   value: presentedPot)
    }

    private func miniTile(_ pool: Pool, dia: CGFloat) -> some View {
        let chips = game.chips(in: pool)
        return ZStack {
            if chips > 0 {
                TableWorldPiecePile(world: theme,
                                    count: chips,
                                    diameter: dia,
                                    compartment: TravelCompartment(pool: pool),
                                    placement: .well,
                                    pieceDiameterOverride: Tokens.tableTokenDiameter
                                        * Tokens.phase2BoardScale
                                        * Tokens.r1CompactTokenScale)
            }
        }
        .frame(width: dia, height: dia)
    }

    // MARK: - Gegner-Token

    private func token(seat: Int, width: CGFloat) -> some View {
        let s = game.bettingSeat(of: seat)
        let isTurn = game.turnIndex == seat && game.stage == .betting
        let featured = featuredReaction?.seat == seat ? featuredReaction : nil
        let publicAction = featured?.action ?? game.seatActions[seat]
        let reaction = actionPresentation(action: publicAction, seat: seat)
        let resultSettled = game.stage != .betting
        let didWin = game.pochResult?.winner == seat
        let mood = didWin ? OpponentMood.winning
            : moodPresentation(for: seat, action: publicAction, isTurn: isTurn)
        return OpponentPanel(seat: seat,
                             name: game.name(of: seat),
                             stack: presentedStack(of: seat),
                             cards: game.displayedCardCount(of: seat),
                             actionText: resultSettled && featured == nil ? "" : reaction.text,
                             actionTint: resultSettled && featured == nil ? .clear : reaction.tone,
                             isActive: s?.isActive ?? false,
                             isFocus: isTurn || didWin || featured != nil,
                             mood: mood,
                             width: width,
                             tendencyTitle: tendencyTitle(for: seat),
                             showsSpeechBubble: featured != nil
                                || (game.stage == .betting
                                    && featuredReaction == nil
                                        && isTurn
                                        && game.seatActions[seat] == .thinking),
                             morph: morph,
                             reduceMotionOverride: phase2ReduceMotion)
            .accessibilityIdentifier("phase2.opponent.\(seat)")
            .phase2PayoutAnchor(.opponent(seat))
    }

    private func tendencyTitle(for seat: Int) -> String? {
        guard !isGuidedRound,
              let disclosure = game.opponentTendencyDisclosure,
              disclosure.opponentDisplayName == game.name(of: seat) else {
            return nil
        }
        return localizedTendency(disclosure.titleLocalizationKey)
    }

    private func presentedStack(of seat: Int) -> Int {
        let settled = game.displayedStack(of: seat)
        guard !payoutPresentationCompleted,
              let result = game.pochResult,
              result.winner == seat else { return settled }
        return max(0, settled - result.pot - result.pochPool)
    }

    /// Auftritt = Reaktion auf den öffentlichen Spielstand (§6b) - nie ein Hand-Leak.
    private func actionPresentation(for seat: Int) -> (text: String, tone: Color) {
        actionPresentation(action: game.seatActions[seat], seat: seat)
    }

    private func actionPresentation(action: SeatAction,
                                    seat: Int) -> (text: String, tone: Color) {
        let s = game.bettingSeat(of: seat)
        switch action {
        case .thinking:
            return (String(localized: "phase2.reaction.thinking",
                           defaultValue: "überlegt …"), Tokens.slate)
        case .passed:
            return (String(localized: "phase2.reaction.passed",
                           defaultValue: "passt"), Tokens.slate)
        case .opened(let n):
            return (String(format: String(localized: "phase2.reaction.opened",
                                          defaultValue: "pocht %d!"), n),
                    pochAccent)
        case .called:
            return (String(localized: "phase2.reaction.called",
                           defaultValue: "geht mit"), Tokens.jewelGold)
        case .raised(let n):
            return (String(format: String(localized: "phase2.reaction.raised",
                                          defaultValue: "erhöht auf %d"), n),
                    pochAccent)
        case .none:
            return ("", (s?.committed ?? 0) > 0
                    ? Tokens.jewelGold
                    : Tokens.slate.opacity(0.62))
        }
    }

    private func moodPresentation(for seat: Int,
                                  action: SeatAction,
                                  isTurn: Bool) -> OpponentMood {
        if isTurn,
           transferPresentationActive,
           game.lastBetKind == .raise,
           game.lastBetActor != seat {
            return .surprised
        }
        switch action {
        case .thinking:
            return .thinking
        case .passed:
            return .passed
        case .opened, .raised:
            return .pressure
        case .called:
            return .called
        case .none:
            if isTurn { return .thinking }
            return (game.bettingSeat(of: seat)?.committed ?? 0) > 0 ? .tense : .neutral
        }
    }

    // MARK: - Gegner-Portraits UNTEN (§5c Akt 2)

    private func portraitsRow(maxPanelWidth: CGFloat,
                              panelScale: CGFloat = 1) -> some View {
        GeometryReader { proxy in
            let seats = game.activeUISeats.filter { $0 != 0 }
            let gap: CGFloat = seats.count > 3 ? 5 : 8
            let available = proxy.size.width - 28 - gap * CGFloat(max(0, seats.count - 1))
            let panelWidth = min(maxPanelWidth,
                                 max(64, available / CGFloat(max(1, seats.count))))
            ZStack {
                Capsule()
                    .fill(LinearGradient(colors: [
                        .clear,
                        Tokens.jewelGold.opacity(0.055),
                        .clear
                    ], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .padding(.horizontal, 42)
                    .offset(y: -5)

                HStack(spacing: gap) {
                    ForEach(seats, id: \.self) { seat in
                        token(seat: seat, width: panelWidth)
                            .scaleEffect(panelScale)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("phase2.opponents")
    }

    // MARK: - Hand (identisch zu Phase 1: grosser Mockup-Faecher am unteren Rand)

    private func handFan(cardScale: CGFloat) -> some View {
        let cards = game.humanHand
        let isHighlighted = game.stage == .betting
        let combo = isHighlighted ? game.humanCombo : nil
        let N = cards.count
        let spreadDeg = min(Double(N) * 7.0, 38.0)
        let totalW: CGFloat = min(CGFloat(N) * 30, 224) * (cardScale / 1.62)
        return VStack(spacing: 7) {
            if let combo, !isGuidedRound {
                Text(String(
                    format: String(localized: "phase2.hand.combo",
                                   defaultValue: "%@ - deine stärkste Gruppe"),
                    localizedCombo(combo)
                ))
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.96))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(pochAccent.opacity(0.24))
                        .overlay(Capsule().strokeBorder(pochAccent.opacity(0.62), lineWidth: 1))
                )
                .accessibilityIdentifier("phase2.hand.combo")
                .transition(phase2ReduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
            }

            ZStack {
                ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                    let t: CGFloat = N > 1 ? CGFloat(i) / CGFloat(N - 1) : 0.5
                    let angle = N > 1 ? -spreadDeg / 2 + Double(t) * spreadDeg : 0.0
                    let xOff: CGFloat = N > 1 ? -totalW / 2 + t * totalW : 0
                    let belongsToCombo = isHighlighted && card.rank == game.humanComboRank
                    CardFace(card: card,
                             highlighted: belongsToCombo,
                             scale: cardScale)
                        .offset(x: xOff)
                        .rotationEffect(.degrees(angle), anchor: .bottom)
                        .zIndex(Double(i))
                        .accessibilityIdentifier(belongsToCombo
                            ? "phase2.hand.combo.card.\(card.suit.rawValue).\(card.rank.index)"
                            : "phase2.hand.card.\(card.suit.rawValue).\(card.rank.index)")
                        .accessibilityAddTraits(belongsToCombo ? .isSelected : [])
                }
            }
            .frame(height: 74 * cardScale * 0.62)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("phase2.hand")
        .phase2PayoutAnchor(.human)
    }

    // MARK: - Aktions-Buttons (2-spaltig)

    private var tensionBar: some View {
        return HStack(spacing: 8) {
            wagerMetric(String(localized: "phase2.metric.yourBid",
                               defaultValue: "DEIN GEBOT"),
                        "\(Int(bid))", pochAccent)
            wagerMetric(String(localized: "phase2.metric.inPoch",
                               defaultValue: "IM POTT"),
                        "\(game.pot + game.pochPool)", Tokens.jewelGold)
            wagerMetric(String(localized: "phase2.metric.fromYou",
                               defaultValue: "VON DIR"),
                        "\(game.humanCommitted)", Tokens.jewelSmaragd)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 13)
            .fill(Color.white.opacity(0.035))
            .overlay(RoundedRectangle(cornerRadius: 13)
                .strokeBorder(Tokens.jewelGold.opacity(0.16), lineWidth: 1)))
        .shadow(color: .black.opacity(0.24), radius: 8, y: 4)
    }

    private func wagerMetric(_ title: String, _ value: String, _ tint: Color,
                             muted: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9.5, weight: .heavy))
                .tracking(0.65)
                .foregroundStyle(Tokens.slate.opacity(0.72))
                .lineLimit(1)
            Text(value)
                .font(.system(size: value.count > 5 ? 11 : 14, weight: .heavy))
                .foregroundStyle(muted ? Tokens.jewelPlatin.opacity(0.72) : tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    private func pressureMetric(_ title: String, _ value: String, _ tint: Color,
                                muted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9.5, weight: .heavy))
                .tracking(0.65)
                .foregroundStyle(Tokens.slate.opacity(0.66))
                .lineLimit(1)
            Text(value)
                .font(.system(size: value.count > 5 ? 11 : 14, weight: .heavy))
                .foregroundStyle(muted ? Tokens.jewelPlatin.opacity(0.72) : tint)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var actionArea: some View {
        if game.stage != .betting {
            resultBanner
        } else if game.turnIndex == 0, let legal = game.humanLegal {
            humanActionButtons(legal)
        } else {
            waitHint
        }
    }

    private var waitHint: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    @ViewBuilder private func humanActionButtons(_ legal: BettingPhase.LegalActions) -> some View {
        let callCost = max(0, game.betting.currentBet - game.humanCommitted)
        let canOpen = legal.openRange != nil
        let canRaise = legal.raiseRange != nil
        HStack(spacing: 7) {
            if legal.canPass {
                actionButton(String(localized: "phase2.action.pass",
                                    defaultValue: "Passen"), style: .quiet,
                             systemImage: "xmark",
                             identifier: "phase2.action.pass") { game.humanPass() }
            }
            if legal.canCall {
                actionButton(callActionTitle(cost: callCost),
                             style: .gold,
                             systemImage: "arrow.left.arrow.right",
                             identifier: "phase2.action.call") { game.humanCall() }
            }
            if canRaise {
                actionButton(String(format: String(localized: "phase2.action.raise",
                                                   defaultValue: "Auf %d erhöhen"),
                                    Int(bid)), style: .amethyst,
                             systemImage: "arrow.up",
                             identifier: "phase2.action.raise") {
                    if let raise = legal.raiseRange {
                        game.humanRaise(to: Int(bid).clamped(to: raise))
                    }
                }
            } else if canOpen {
                actionButton(openActionTitle(amount: Int(bid)), style: .amethyst,
                             systemImage: "hand.tap.fill",
                             identifier: "phase2.action.open") {
                    if let open = legal.openRange {
                        game.humanOpen(Int(bid).clamped(to: open))
                    }
                }
            }
        }
        .padding(.horizontal, 2)
        .animation(phase2ReduceMotion ? nil : .easeInOut(duration: 0.20),
                   value: game.betting.currentBet)
    }

    private func callActionTitle(cost: Int) -> String {
        guard cost > 0 else {
            return String(localized: "phase2.action.call", defaultValue: "Mitgehen")
        }
        if cost == 1 {
            return String(localized: "phase2.action.call.cost.one",
                          defaultValue: "Für 1 Chip mitgehen")
        }
        let format = String(localized: "phase2.action.call.cost.many",
                            defaultValue: "Für %d Chips mitgehen")
        return String(format: format, cost)
    }

    private func openActionTitle(amount: Int) -> String {
        if amount == 1 {
            return String(localized: "phase2.action.open.one",
                          defaultValue: "Mit 1 Chip pochen")
        }
        let format = String(localized: "phase2.action.open",
                            defaultValue: "Mit %d Chips pochen")
        return String(format: format, amount)
    }

    private func wallLabel(_ range: ClosedRange<Int>) -> some View {
        let holder = game.capHolder
        let text: String = {
            guard let holder else {
                return String(format: String(localized: "phase2.wall.highest",
                                             defaultValue: "Höchster Einsatz: %d Chips"),
                              range.upperBound)
            }
            if holder == 0 {
                return String(format: String(localized: "phase2.wall.you",
                                             defaultValue: "Maximal %d Chips - dein Vorrat setzt die Grenze"),
                              range.upperBound)
            }
            return String(format: String(localized: "phase2.wall.opponent",
                                         defaultValue: "Maximal %1$d Chips - mehr kann %2$@ nicht mitgehen"),
                          range.upperBound,
                          game.name(of: holder))
        }()
        return Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Tokens.slate)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Ergebnis (Bietrunde vorbei; Phase 3 folgt als nächste Iteration)

    private var resultBanner: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    resultActions
                }
            } else {
                HStack(spacing: 10) {
                    resultActions
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Tokens.jewelGold.opacity(0.22), lineWidth: 1)))
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("phase2.result")
    }

    @ViewBuilder private var resultActions: some View {
        actionButton(String(localized: "tutorial.bidding.action.continue",
                            defaultValue: "Hand leerspielen"), style: .gold,
                     isEnabled: payoutControlsEnabled,
                     systemImage: "play.fill",
                     identifier: "phase2.continue") { onContinue() }
            .accessibilityIdentifier("phase2.continue")
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var resultActionAreaHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 96 : 64
    }

    private var payoutControlsEnabled: Bool {
        game.pochResult == nil || payoutPresentationCompleted
    }

    // MARK: - Bausteine

    private enum ButtonTone { case quiet, gold, amethyst }

    private func actionButton(_ label: String, style: ButtonTone,
                              isEnabled: Bool = true,
                              systemImage: String? = nil,
                              identifier: String? = nil,
                              action: @escaping () -> Void) -> some View {
        let foreground = actionForeground(style: style, isEnabled: isEnabled)
        let fill = actionFill(style: style, isEnabled: isEnabled)
        let stroke = actionStroke(style: style, isEnabled: isEnabled)
        return Button(action: action) {
            ResilientActionLabel(
                label,
                systemImage: dynamicTypeSize.isAccessibilitySize
                    || verticalSizeClass == .compact ? nil : systemImage
            )
            .foregroundStyle(foreground)
            .background(
                Capsule()
                    .fill(fill)
                    .overlay(Capsule().strokeBorder(stroke.opacity(0.82), lineWidth: 1.15))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(isEnabled ? 0.08 : 0.03), lineWidth: 0.7).padding(1.6))
                    .shadow(color: style == .amethyst && isEnabled ? pochAccent.opacity(0.14) : .black.opacity(0.18),
                            radius: style == .amethyst && isEnabled ? 10 : 4,
                            y: style == .amethyst && isEnabled ? 5 : 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.54)
        .accessibilityIdentifier(identifier ?? "")
    }

    private func actionForeground(style: ButtonTone, isEnabled: Bool) -> Color {
        guard isEnabled else { return Tokens.slate.opacity(0.46) }
        return style == .quiet ? Tokens.slate : Tokens.jewelPlatin
    }

    private func actionFill(style: ButtonTone, isEnabled: Bool) -> Color {
        if isEnabled && style == .amethyst {
            return Tokens.jewelAmethyst.opacity(0.65)
        }
        if isEnabled && style == .gold {
            return Tokens.jewelGold.opacity(0.14)
        }
        return Color.white.opacity(isEnabled ? 0.055 : 0.025)
    }

    private func actionStroke(style: ButtonTone, isEnabled: Bool) -> Color {
        guard isEnabled else { return Tokens.slate.opacity(0.20) }
        switch style {
        case .amethyst: return pochAccent.opacity(0.76)
        case .gold: return Tokens.jewelGold.opacity(0.6)
        case .quiet: return Tokens.slate.opacity(0.4)
        }
    }

    private func resetBid() {
        if let legal = game.humanLegal, let range = legal.openRange ?? legal.raiseRange {
            bid = Double(range.lowerBound)
        }
    }
}

private struct PochPayoutFlight: View {
    let winner: Int
    let winnerName: String
    let amount: Int
    let generation: Int
    let reduceMotion: Bool
    let world: TableWorld
    let activeSeats: [Int]
    let sourceFrame: CGRect?
    let targetFrame: CGRect?
    let onImpact: () -> Void

    @State private var landed = false
    @State private var completionScheduled = false
    @State private var transaction: CoinTransferTransaction

    init(
        winner: Int,
        winnerName: String,
        amount: Int,
        generation: Int,
        reduceMotion: Bool,
        world: TableWorld,
        activeSeats: [Int],
        sourceFrame: CGRect?,
        targetFrame: CGRect?,
        onImpact: @escaping () -> Void
    ) {
        self.winner = winner
        self.winnerName = winnerName
        self.amount = amount
        self.generation = generation
        self.reduceMotion = reduceMotion
        self.world = world
        self.activeSeats = activeSeats
        self.sourceFrame = sourceFrame
        self.targetFrame = targetFrame
        self.onImpact = onImpact
        _transaction = State(initialValue: CoinTransferTransaction(
            eventID: Self.eventID(generation: generation),
            generation: generation,
            motionPreference: reduceMotion ? .reduceMotion : .standard
        ))
    }

    var body: some View {
        GeometryReader { proxy in
            let stage = Phase2StageGeometry.resolve(in: proxy.size,
                                                    safeArea: proxy.safeAreaInsets,
                                                    globalFrame: proxy.frame(in: .global))
            let origin = sourceFrame.map { CGPoint(x: $0.midX, y: $0.midY) }
                ?? boardCenter(in: stage)
            let target = targetFrame.map { frame in
                CGPoint(x: frame.midX,
                        y: winner == 0 ? frame.minY + 12 : frame.midY)
            } ?? winnerPoint(in: stage)
            let tokenCount = min(max(amount, 1), 5)

            ZStack {
                #if DEBUG || INTERNAL_QA
                if landed,
                   ProcessInfo.processInfo.arguments.contains("-pochPayoutQA") {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("QA payout landed")
                        .accessibilityIdentifier("phase2.payout.landed")
                }
                #endif

                HStack(spacing: 7) {
                    Circle()
                        .fill(world.tint(.poch).opacity(0.22))
                        .overlay(Circle().strokeBorder(world.tint(.poch).opacity(0.72),
                                                       lineWidth: 1.2))
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(winnerName.uppercased())
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.9)
                            .foregroundStyle(Tokens.jewelPlatin.opacity(0.74))
                        Text("+\(amount)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(world.tint(.poch))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color(hex: 0x0B0910).opacity(0.92))
                        .overlay(Capsule().strokeBorder(world.tint(.poch).opacity(0.34),
                                                        lineWidth: 1))
                )
                .position(x: target.x, y: target.y - 26)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(winnerName)
                .accessibilityValue("+\(amount)")
                .accessibilityIdentifier("phase2.payout.target")

                ForEach(0..<tokenCount, id: \.self) { index in
                    let offset = landingOffset(index: index)
                    ImpactFlight(
                        from: origin,
                        to: CGPoint(x: target.x + offset.width,
                                    y: target.y + offset.height),
                        duration: Tokens.p2PayoutFlight,
                        delay: Double(index) * Tokens.p2PayoutStagger,
                        arcHeight: PhysicalMotion.shallowArcHeight(
                            from: origin,
                            to: target,
                            minimum: 12,
                            maximum: 24),
                        lateralBias: CGFloat(index - 2) * 3,
                        onImpact: {
                            guard index == tokenCount - 1 else { return }
                            registerImpact()
                        },
                        onCancel: cancelTransaction
                    ) { _ in
                        TableWorldPiece(world: world,
                                        size: 22,
                                        seed: UInt64(max(amount, 0)) + 14_410,
                                        index: index,
                                        compartment: .poch)
                            .shadow(color: .black.opacity(0.62), radius: 5, y: 4)
                    }
                    .opacity(landed ? 0 : 1)
                }
            }
        }
        .onAppear(perform: beginTransaction)
    }

    private static func eventID(generation: Int) -> String {
        "poch-payout-\(generation)"
    }

    private func beginTransaction() {
        let eventID = Self.eventID(generation: generation)
        if reduceMotion {
            guard transaction.performReducedMotionTransfer(
                eventID: eventID,
                generation: generation,
                applyAtomically: {}
            ) == .accepted else { return }
            landed = true
            scheduleCompletionHold()
            return
        }
        guard transaction.depart(eventID: eventID, generation: generation) == .accepted else {
            return
        }
        _ = transaction.enterAirborne(eventID: eventID, generation: generation)
    }

    private func registerImpact() {
        let eventID = Self.eventID(generation: generation)
        guard transaction.registerImpact(
            eventID: eventID,
            generation: generation,
            applyAtomically: {}
        ) == .accepted else { return }
        landed = true
        _ = transaction.beginSettling(eventID: eventID, generation: generation)
        scheduleCompletionHold()
    }

    private func scheduleCompletionHold() {
        guard !completionScheduled else { return }
        completionScheduled = true
        Task { @MainActor in
            // Der Empfänger bleibt nach der Landung bewusst stehen. Auch ohne
            // Flugbewegung ist Ursache -> Ziel damit lesbar statt nur korrekt.
            try? await Task.sleep(for: .seconds(1.85))
            let eventID = Self.eventID(generation: generation)
            _ = transaction.complete(eventID: eventID, generation: generation)
            onImpact()
        }
    }

    private func cancelTransaction() {
        let eventID = Self.eventID(generation: generation)
        _ = transaction.cancel(eventID: eventID, generation: generation)
    }

    private func boardCenter(in stage: Phase2StageGeometry) -> CGPoint {
        let diameter = compactBoardDiameter
        if stage.isLandscape {
            return CGPoint(x: stage.layoutFrame.maxX - diameter / 2 - 2,
                           y: stage.layoutFrame.minY + diameter / 2 + 2)
        }
        let boardX = Phase2StageGeometry.portraitSliderVisualRightEdge
            + (stage.layoutFrame.width
                - Phase2StageGeometry.portraitSliderVisualRightEdge) / 2
        let stageHeight = min(Tokens.phase2StageHeight,
                              stage.layoutFrame.height * 0.37)
        return CGPoint(x: stage.layoutFrame.minX + boardX,
                       y: stage.layoutFrame.minY + stageHeight / 2 + 2)
    }

    private func winnerPoint(in stage: Phase2StageGeometry) -> CGPoint {
        if winner == 0 {
            return stage.isLandscape
                ? CGPoint(x: stage.layoutFrame.minX + stage.layoutFrame.width * 0.34,
                          y: stage.layoutFrame.maxY - 24)
                : CGPoint(x: stage.layoutFrame.midX,
                          y: stage.layoutFrame.maxY - 64)
        }

        let opponents = activeSeats.filter { $0 != 0 }
        let index = opponents.firstIndex(of: winner) ?? 0
        let count = max(opponents.count, 1)
        if stage.isLandscape {
            let areaWidth = min(292, stage.layoutFrame.width * 0.43)
            let startX = stage.layoutFrame.maxX - areaWidth
            return CGPoint(x: startX + areaWidth * (CGFloat(index) + 0.5) / CGFloat(count),
                           y: max(stage.layoutFrame.minY + compactBoardDiameter + 46,
                                  stage.layoutFrame.maxY - 44))
        }
        return CGPoint(x: stage.layoutFrame.minX
            + stage.layoutFrame.width * (CGFloat(index) + 0.5) / CGFloat(count),
                       y: stage.layoutFrame.maxY
                           - Tokens.phase2HandReservedHeight + 38)
    }

    private var compactBoardDiameter: CGFloat {
        Tokens.ringRadius * 2 * Tokens.phase2BoardScale
            + Tokens.tileDiameter * Tokens.phase2BoardScale
    }

    private func landingOffset(index: Int) -> CGSize {
        let offsets = [
            CGSize(width: -8, height: 3),
            CGSize(width: 7, height: 5),
            CGSize(width: -2, height: -5),
            CGSize(width: 8, height: -3),
            CGSize(width: 1, height: 7)
        ]
        return offsets[index % offsets.count]
    }
}

private struct PochBetFlight: View {
    let seat: Int
    let amount: Int
    let kind: BetTransferKind
    let trigger: Int
    let reduceMotion: Bool
    let world: TableWorld
    let tint: Color
    let onImpact: () -> Void

    @State private var landed = false
    @State private var transaction: CoinTransferTransaction

    init(
        seat: Int,
        amount: Int,
        kind: BetTransferKind,
        trigger: Int,
        reduceMotion: Bool,
        world: TableWorld,
        tint: Color,
        onImpact: @escaping () -> Void
    ) {
        self.seat = seat
        self.amount = amount
        self.kind = kind
        self.trigger = trigger
        self.reduceMotion = reduceMotion
        self.world = world
        self.tint = tint
        self.onImpact = onImpact
        _transaction = State(initialValue: CoinTransferTransaction(
            eventID: Self.eventID(generation: trigger),
            generation: trigger,
            motionPreference: reduceMotion ? .reduceMotion : .standard
        ))
    }

    var body: some View {
        GeometryReader { proxy in
            let stage = Phase2StageGeometry.resolve(in: proxy.size,
                                                    safeArea: proxy.safeAreaInsets,
                                                    globalFrame: proxy.frame(in: .global))
            let w = stage.layoutFrame.width
            let h = stage.layoutFrame.height
            let scale = Tokens.phase2BoardScale
            let ringDiameter = Tokens.ringRadius * 2 * scale + Tokens.tileDiameter * scale
            let portraitBoardX = Phase2StageGeometry.portraitSliderVisualRightEdge
                + (w - Phase2StageGeometry.portraitSliderVisualRightEdge) / 2
            let target = stage.isLandscape
                ? CGPoint(x: stage.layoutFrame.maxX - ringDiameter / 2 - 2,
                          y: stage.layoutFrame.minY + ringDiameter / 2 + 2)
                : CGPoint(x: stage.layoutFrame.minX + portraitBoardX,
                          y: stage.layoutFrame.minY
                              + min(Tokens.phase2StageHeight, h * 0.37) / 2)
            let localOrigin = originPoint(seat: seat, w: w, h: h)
            let origin = CGPoint(x: stage.layoutFrame.minX + localOrigin.x,
                                 y: stage.layoutFrame.minY + localOrigin.y)
            let tokenCount = min(max(amount, 1), 4)
            ZStack {
                ForEach(0..<tokenCount, id: \.self) { i in
                    let offset = landingOffset(index: i)
                    ImpactFlight(
                        from: origin,
                        to: CGPoint(x: target.x + offset.width,
                                    y: target.y + offset.height),
                        duration: Tokens.p2PochFlight,
                        delay: Double(i) * 0.055,
                        arcHeight: PhysicalMotion.shallowArcHeight(
                            from: origin,
                            to: target,
                            minimum: 7,
                            maximum: kind.isPoch ? 14 : 11),
                        lateralBias: curveBias(for: seat) * 0.08 + CGFloat(i - 1) * 2,
                        onImpact: {
                            guard i == tokenCount - 1 else { return }
                            registerImpact()
                        },
                        onCancel: cancelTransaction
                    ) { _ in
                        TableWorldPiece(world: world,
                                        size: kind.isPoch ? 22 : 21,
                                        seed: UInt64(max(trigger, 0)) + 1_441,
                                        index: i,
                                        compartment: .poch)
                            .shadow(color: .black.opacity(0.64), radius: 6, y: 4)
                    }
                    .opacity(landed ? 0 : 1)
                    .id("poch-chip-\(trigger)-\(i)")
                }
            }
        }
        .onAppear(perform: beginTransaction)
    }

    private static func eventID(generation: Int) -> String {
        "poch-bet-\(generation)"
    }

    private func beginTransaction() {
        let eventID = Self.eventID(generation: trigger)
        if reduceMotion {
            guard transaction.performReducedMotionTransfer(
                eventID: eventID,
                generation: trigger,
                applyAtomically: { onImpact() }
            ) == .accepted else { return }
            landed = true
            return
        }
        guard transaction.depart(eventID: eventID, generation: trigger) == .accepted else {
            return
        }
        _ = transaction.enterAirborne(eventID: eventID, generation: trigger)
    }

    private func registerImpact() {
        let eventID = Self.eventID(generation: trigger)
        guard transaction.registerImpact(
            eventID: eventID,
            generation: trigger,
            applyAtomically: { onImpact() }
        ) == .accepted else { return }
        landed = true
        _ = transaction.beginSettling(eventID: eventID, generation: trigger)
        _ = transaction.complete(eventID: eventID, generation: trigger)
    }

    private func cancelTransaction() {
        let eventID = Self.eventID(generation: trigger)
        _ = transaction.cancel(eventID: eventID, generation: trigger)
    }

    private func originPoint(seat: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        switch seat {
        case 1: return CGPoint(x: w * 0.20, y: h * 0.73)
        case 2: return CGPoint(x: w * 0.50, y: h * 0.73)
        case 3: return CGPoint(x: w * 0.80, y: h * 0.73)
        default: return CGPoint(x: w * 0.78, y: h * 0.48)
        }
    }

    private func curveBias(for seat: Int) -> CGFloat {
        switch seat {
        case 1: return 24
        case 2: return -12
        case 3: return -24
        default: return -30
        }
    }

    private func landingOffset(index: Int) -> CGSize {
        let offsets = [
            CGSize(width: -7, height: 4),
            CGSize(width: 6, height: 5),
            CGSize(width: -1, height: -5),
            CGSize(width: 5, height: -3)
        ]
        return offsets[index % offsets.count]
    }
}

private struct GuidedFocusModifier: ViewModifier {
    let isActive: Bool
    let isRelevant: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let isDeemphasized = isActive && !isRelevant
        content
            // Fokus bleibt scharf. Blur lässt Kartenindizes und feine
            // Brettkanten wie fehlerhafte Doppelbilder wirken.
            .opacity(isDeemphasized ? 0.42 : 1)
            .scaleEffect(isActive && isRelevant && !reduceMotion ? 1.012 : 1)
            .animation(
                reduceMotion
                    ? .linear(duration: 0.16)
                    : .easeInOut(duration: Tokens.guidedFocusTransition),
                value: isRelevant
            )
            .accessibilityHidden(isActive && !isRelevant)
    }
}


extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
