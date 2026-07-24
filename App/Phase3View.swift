import PochKit
import SwiftUI

/// Phase 3 (Ausspielen) - das Renn-Layout (§5b Akt 3, §6c): die Gegner verharren als
/// matte Schiefer-Tokens am Rand, das Zentrum gehört den gespielten Ketten (lesbare
/// Sequenz, Mitzählen bleibt möglich). Kaskaden-Takt und Beat-Drop kommen aus GameState;
/// die Stopper-Karte glüht golden, das Anspielrecht wandert sichtbar.
struct Phase3View: View {
    let game: GameState
    let theme: Theme
    /// Phasen-Morph-Namespace (§5b) - geteilt mit ContentView/Phase2View.
    let morph: Namespace.ID
    let assistHints: Bool
    let isGuidedRound: Bool
    let onNewRound: () -> Void
    @State private var settledPlays = 0
    @State private var pendingHumanFlightSource: Phase3HumanFlightSource?

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let playSequence = game.revealedPlays
            let playGeneration = game.playPresentationGeneration
            let awaitingFirstLead = game.stage == .playout
                && game.revealedPlays == 0
                && game.cascadeIdle
            let compactHeight = h < 720
            // Beim ersten Anspiel braucht die Erklärung eine eigene Bühne oberhalb
            // der Mitte. Danach rückt der Status näher an die laufende Kette.
            let statusY = awaitingFirstLead
                ? min(h * (compactHeight ? 0.18 : 0.20), compactHeight ? 120 : 140)
                : min(h * (compactHeight ? 0.40 : 0.555), compactHeight ? 278 : 398)
            let playedTopOffset = Phase3CardGeometry.playedTopOffset
                - (compactHeight && !awaitingFirstLead ? 66 : 0)
            let opponentsY = awaitingFirstLead
                ? (compactHeight
                   ? min(max(statusY + 160, h * 0.60), h - 178)
                   : min(max(statusY + 190, h * 0.71), h - 170))
                : (compactHeight
                   ? min(max(statusY + 132, h - 210), h - 175)
                   : min(max(statusY + 112, h - 220), h - 192))
            ZStack(alignment: .top) {
                playedCardsFan
                    .frame(width: w)
                    .offset(y: playedTopOffset)

                if game.stage == .playout, !phase3ReduceMotion, let lastPlay = lastRevealedPlay {
                    let seat = game.uiSeat(forRoundSeat: lastPlay.player)
                    let futureChain = game.revealedChains.last ?? [lastPlay]
                    let targetPose = Phase3CardGeometry.playedTargetPose(
                        index: max(futureChain.count - 1, 0),
                        count: max(futureChain.count, 1),
                        canvasWidth: w,
                        topOffset: playedTopOffset
                    )
                    let humanSource = seat == 0
                        && pendingHumanFlightSource?.sequence == playSequence
                        && pendingHumanFlightSource?.generation == playGeneration
                        ? pendingHumanFlightSource?.pose
                        : nil
                    Phase3CardArrival(card: lastPlay.card,
                                      seat: seat,
                                      trigger: playSequence,
                                      generation: playGeneration,
                                      canvas: CGSize(width: w, height: h),
                                      opponentsY: opponentsY,
                                      humanSourcePose: humanSource,
                                      targetPose: targetPose,
                                      onImpact: {
                                          guard game.markPlayLanded(
                                            sequence: playSequence,
                                            generation: playGeneration
                                          ) else { return }
                                          settledPlays = max(settledPlays, playSequence)
                                          if pendingHumanFlightSource?.sequence == playSequence,
                                             pendingHumanFlightSource?.generation == playGeneration {
                                              pendingHumanFlightSource = nil
                                          }
                                      })
                        .id("arrival-\(playGeneration)-\(playSequence)")
                        .allowsHitTesting(false)
                }

                if game.stage == .playout {
                    statusLine
                        .frame(width: min(320, w - 24))
                        .position(x: w / 2, y: statusY)
                    if isGuidedRound, game.guidedPlayoutCanAdvance {
                        guidedAdvanceButton
                            .frame(width: min(286, w - 42))
                            .position(x: w / 2, y: statusY + 72)
                    }
                    opponentsRow
                        .frame(width: w)
                        .position(x: w / 2, y: opponentsY)
                    handFan(canvas: CGSize(width: w, height: h))
                        .frame(width: w,
                               height: Phase3CardGeometry.handContainerHeight,
                               alignment: .bottom)
                        .position(x: w / 2,
                                  y: h - Phase3CardGeometry.handCenterBottomInset)
                } else if game.endPhase <= .frozen {
                    finalMomentStatus
                        .frame(width: min(336, w - 24))
                        .position(x: w / 2, y: statusY)
                    opponentsRow
                        .frame(width: w)
                        .position(x: w / 2, y: opponentsY)
                } else if game.endPhase < .done {
                    settlementStatus
                        .frame(width: w)
                        .position(x: w / 2, y: min(h * 0.64, 450))
                } else {
                    resultBanner
                        .position(x: w / 2, y: min(h * 0.58, 424))
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("table.world.phase3")
        // Straf-Strom (§6c c): Chips fliegen PARALLEL von jedem Verlierer zum Sieger
        .overlay {
            if game.endPhase == .punishing, let result = game.roundResult, !phase3ReduceMotion {
                PunishStreams(result: result, world: theme)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            game.configureGuidedPlayoutPresentation(isGuidedRound)
            if phase3ReduceMotion, game.revealedPlays > game.landedPlays {
                let generation = game.playPresentationGeneration
                game.settlePlayPresentationForReducedMotion(
                    sequence: game.revealedPlays,
                    generation: generation
                )
            }
            settledPlays = min(game.landedPlays, game.resolvedPlayCount)
        }
        .onChange(of: game.revealedPlays) { _, newValue in
            if phase3ReduceMotion {
                let generation = game.playPresentationGeneration
                guard game.markPlayLanded(
                    sequence: newValue,
                    generation: generation
                ) else { return }
                settledPlays = max(settledPlays, newValue)
            }
        }
        .onChange(of: phase3ReduceMotion) { _, isReduced in
            guard isReduced,
                  game.revealedPlays > game.landedPlays else { return }
            let generation = game.playPresentationGeneration
            game.settlePlayPresentationForReducedMotion(
                sequence: game.revealedPlays,
                generation: generation
            )
            settledPlays = max(settledPlays, game.landedPlays)
            pendingHumanFlightSource = nil
        }
        .overlay {
            if game.endPhase == .punishing, let result = game.roundResult, !phase3ReduceMotion {
                CenterPotRelease(result: result)
                    .allowsHitTesting(false)
            }
        }
        #if DEBUG
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-phase3ActionQA") else { return }
            try? await Task.sleep(for: .milliseconds(1_200))
            guard game.playoutLeader == 0,
                  let card = game.displayedHumanHand.first else { return }
            game.humanLead(card)
        }
        #endif
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var phase3ReduceMotion: Bool {
        #if DEBUG
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-reduceMotionQA")
        #else
        reduceMotion
        #endif
    }

    // MARK: - Gegner als ruhiger Rahmen (§5c Phase 3: matter Schiefer, Fokus aufs Rennen)

    private var opponentsRow: some View {
        HStack(spacing: 24) {
            ForEach(game.activeUISeats.filter { $0 != 0 }, id: \.self) { seat in
                slateToken(seat: seat)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func slateToken(seat: Int) -> some View {
        let isLeader = game.playoutLeader == seat && game.stage == .playout
        let isWinner = game.stage != .playout
            && game.roundResult?.winner == seat
            && game.endPhase <= .frozen
        let guidedReaction = guidedOpponentReaction(for: seat)
        let focused = isWinner || guidedReaction.isFocus || (isLeader && guidedReaction.mood == nil)
        let restCards = game.displayedCardCount(of: seat)
        return OpponentPortrait(seat: seat,
                                name: game.name(of: seat),
                                caption: "\(restCards) Karten",
                                isActive: true,
                                isFocus: focused,
                                mood: isWinner
                                    ? .winning
                                    : (guidedReaction.mood ?? (isLeader ? .pressure : .neutral)),
                                size: 42,
                                morph: morph,
                                reduceMotionOverride: phase3ReduceMotion)
        .saturation(focused ? 1 : (isGuidedRound ? 0.50 : 0.2))
        .opacity(focused ? 1 : (isGuidedRound ? 0.68 : 0.48))
        .animation(phase3ReduceMotion ? nil : .easeInOut(duration: 0.25), value: focused)
    }

    /// In der Lernrunde reagiert immer genau ein Gesicht auf eine öffentliche
    /// Ursache. So wirkt der Tisch menschlich, ohne private Gegnerkarten zu
    /// verraten oder die eigentliche Kartenentscheidung zu übertönen.
    private func guidedOpponentReaction(for seat: Int) -> (mood: OpponentMood?, isFocus: Bool) {
        guard isGuidedRound else { return (nil, false) }
        guard game.landedPlays > 0,
              let last = game.revealedPlayEvents.prefix(game.landedPlays).last else {
            return seat == 1 ? (.thinking, true) : (nil, false)
        }

        let actorSeat = game.uiSeat(forRoundSeat: last.player)
        if actorSeat == seat {
            return (game.cascadeIdle ? .pressure : .called, true)
        }
        if actorSeat == 0, seat == 1 {
            return (game.cascadeIdle ? .surprised : .thinking, true)
        }
        return (nil, false)
    }

    /// Centerpot + Kettenhistorie in einer kompakten Zeile.
    private var centerpotRow: some View {
        let glowing = game.endPhase == .frozen || game.endPhase == .punishing
        let value = game.roundResult?.centerPool ?? game.chips(in: .center)
        let pastChains = max(0, game.revealedChains.count - 1)
        return HStack(spacing: 10) {
            HStack(spacing: 5) {
                Text("Centerpot").font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                Text("\(value)").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(glowing ? 0.10 : 0.04))
                .overlay(Capsule().strokeBorder(
                    Tokens.jewelPlatin.opacity(glowing ? 0.9 : 0.3), lineWidth: 1))
                .shadow(color: Tokens.jewelPlatin.opacity(glowing ? 0.5 : 0),
                        radius: glowing ? 10 : 0))
            .scaleEffect(glowing ? 1.12 : 1)
            .animation(phase3ReduceMotion ? nil : .spring(duration: 0.3), value: glowing)

            if pastChains > 0 {
                Text("\(pastChains) \(pastChains == 1 ? "gespielte Reihe" : "gespielte Reihen")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.slate.opacity(0.7))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.04))
                        .overlay(Capsule().strokeBorder(Tokens.slate.opacity(0.25), lineWidth: 1)))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(phase3ReduceMotion ? nil : .easeOut(duration: 0.2), value: pastChains)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    // MARK: - Dramatischer Fächer (§5b Akt 3, Mockup-Delta)

    /// Grosser angewinkelter Fächer der aktuellen Kette + Poch-Medaillon.
    /// Muster identisch mit ContentView::handView (.offset + .rotationEffect anchor:.bottom).
    private var playedCardsFan: some View {
        let chains = settledChains
        let currentChain = chains.last ?? []
        let finalCards = Array(game.revealedPlayEvents.prefix(settledPlays).suffix(8)).map(\.card)
        let finalTableau = game.stage != .playout && !finalCards.isEmpty
        let displayCards = finalTableau
            ? finalCards
            : currentChain.map(\.card)
        let frozen = game.endPhase >= .frozen
        let N = displayCards.count
        let previewMode = currentChain.isEmpty && !finalTableau
        let cardScale = Phase3CardGeometry.playedCardScale(
            previewMode: previewMode,
            finalTableau: finalTableau
        )

        return ZStack {
            ForEach(Array(displayCards.enumerated()), id: \.element) { i, card in
                let pose = Phase3CardGeometry.playedLocalPose(
                    index: i,
                    count: N,
                    previewMode: previewMode,
                    finalTableau: finalTableau
                )

                CardFace(card: card,
                         goldenStopper: !finalTableau && !currentChain.isEmpty
                             && game.cascadeIdle
                             && i == N - 1
                             && game.stage == .playout,
                         scale: cardScale)
                    .offset(x: pose.point.x, y: pose.point.y)
                    .rotationEffect(.degrees(pose.rotationDegrees), anchor: .bottom)
                    .zIndex(Double(i + 1))
                    .transition(phase3ReduceMotion
                                ? .opacity
                                : .scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: Phase3CardGeometry.playedFrameHeight(
            previewMode: previewMode,
            finalTableau: finalTableau
        ))
        .overlay {
            ZStack {
                medallion
                    .offset(y: previewMode ? 98 : 58)
                sideDeck
                    .offset(x: 136, y: previewMode ? 84 : 44)
            }
            .allowsHitTesting(false)
        }
        .padding(.bottom, previewMode ? 128 : 112)
        .saturation(frozen ? 0.08 : 1)
        .opacity(frozen ? 0.55 : 1)
        .animation(phase3ReduceMotion ? nil : .easeOut(duration: 0.12), value: frozen)
        .animation(phase3ReduceMotion ? nil : .easeOut(duration: 0.18), value: settledPlays)
    }

    private var settledChains: [[PlayoutPhase.Play]] {
        var chains: [[PlayoutPhase.Play]] = []
        for play in game.revealedPlayEvents.prefix(settledPlays) {
            if play.isLead || chains.isEmpty {
                chains.append([play])
            } else {
                chains[chains.count - 1].append(play)
            }
        }
        return chains
    }

    /// Poch-Medaillon: ruhiger Hauptpot-Anker im Kartenstrom.
    private var medallion: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [
                    Color(hex: 0x252229),
                    Color(hex: 0x0F0E13)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().strokeBorder(Tokens.jewelGold.opacity(0.70), lineWidth: 2.0))
                .overlay(Circle().strokeBorder(Color.black.opacity(0.75), lineWidth: 4).padding(5))
                .overlay(Circle().strokeBorder(Tokens.jewelPlatin.opacity(0.14), lineWidth: 1).padding(9))
                .frame(width: 116, height: 116)
                .shadow(color: .black.opacity(0.72), radius: 12, y: 7)
            Circle()
                .fill(RadialGradient(colors: [
                    Tokens.jewelPlatin.opacity(0.14),
                    Color.clear
                ], center: .topLeading, startRadius: 2, endRadius: 44))
                .frame(width: 92, height: 92)
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [
                    Tokens.jewelSmaragd.opacity(theme.isTravelTable ? 0.66 : 0.58),
                    Tokens.jewelAmethyst.opacity(theme.isTravelTable ? 0.60 : 0.52)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 54, height: 54)
                .rotationEffect(.degrees(45))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Tokens.jewelPlatin.opacity(0.30), lineWidth: 1)
                    .rotationEffect(.degrees(45)))
                .shadow(color: theme.smaragdFocus.opacity(theme.isTravelTable ? 0.16 : 0.10),
                        radius: theme.isTravelTable ? 7 : 5)
            VStack(spacing: -1) {
                Text("MITTE")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.66))
                Text("\(game.chips(in: .center))")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.90))
            }
        }
        .accessibilityLabel("Poch-Medaillon")
    }

    private var sideDeck: some View {
        let deckW: CGFloat = 40
        let deckH: CGFloat = 56
        return ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.black.opacity(0.42))
                .frame(width: deckW, height: deckH)
                .offset(x: 3, y: 4)
            CardBack(
                materialVariant: CardBackMaterialPlan.variantIndex(
                    roundGeneration: game.meldPresentationGeneration,
                    dealSequence: 0,
                    seat: 0,
                    slot: 0
                ),
                scale: 0.50
            )
                .rotationEffect(.degrees(2))
                .shadow(color: .black.opacity(0.58), radius: 9, y: 5)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Tokens.jewelGold.opacity(0.38), lineWidth: 0.9)
                .frame(width: deckW, height: deckH)
        }
        .opacity(0.92)
        .accessibilityHidden(true)
    }

    // MARK: - Status + Hand

    private var settlementStatus: some View {
        VStack(spacing: 13) {
            if let result = game.roundResult {
                let total = result.centerPool + result.payments.reduce(0, +)
                VStack(spacing: 4) {
                    Text(String(localized: "phase3.result.eyebrow",
                                defaultValue: "RUNDENENDE"))
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(2.2)
                        .foregroundStyle(theme.smaragdFocus.opacity(0.80))
                    Text(result.winner == 0 ? "Du nimmst die Mitte"
                                             : "\(game.name(of: result.winner)) nimmt die Mitte")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Tokens.jewelPlatin.opacity(0.94))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                winnerStrip(result.winner,
                            remainingPayments: total - result.centerPool)
                HStack(spacing: 8) {
                    settlementPill(String(localized: "phase3.metric.center", defaultValue: "MITTE"),
                                   "\(result.centerPool)", Tokens.jewelPlatin)
                    settlementPill(String(localized: "phase3.metric.remaining", defaultValue: "RESTKARTEN"),
                                   "+\(total - result.centerPool)", Tokens.jewelGold)
                    settlementPill(String(localized: "phase3.metric.total", defaultValue: "GESAMT"),
                                   "\(total)", Tokens.jewelSmaragd)
                }
                .frame(maxWidth: 328)
                recapStrip(game.roundRecap)
            } else {
                Text("Abrechnung läuft")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: 352)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [
                    Color(hex: 0x17141D).opacity(0.92),
                    Color(hex: 0x09080D).opacity(0.94)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Tokens.jewelGold.opacity(0.22), lineWidth: 1))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(LinearGradient(colors: [
                            Tokens.jewelGold.opacity(0.28),
                            Tokens.jewelSmaragd.opacity(0.18),
                            .clear
                        ], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                        .padding(.horizontal, 18)
                }
                .shadow(color: .black.opacity(0.54), radius: 22, y: 14)
        )
        .padding(.bottom, 72)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func winnerStrip(_ winner: Int, remainingPayments: Int) -> some View {
        HStack(spacing: 10) {
            OpponentPortrait(seat: winner,
                             name: game.name(of: winner),
                             isActive: true,
                             isFocus: true,
                             mood: .winning,
                             size: 38,
                             showsText: false,
                             morph: morph)
            VStack(alignment: .leading, spacing: 2) {
                Text(winnerCaption(winner))
                    .font(.system(size: 12.5, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
                Text(String(format: String(localized: "phase3.result.total",
                                           defaultValue: "Dazu kommen %d Chips aus den Restkarten der anderen."),
                            remainingPayments))
                    .font(.system(size: 9.8, weight: .semibold))
                    .foregroundStyle(Tokens.slate.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            Spacer(minLength: 0)
            HStack(spacing: -4) {
                ForEach(0..<3, id: \.self) { i in
                    TableWorldPiece(world: theme,
                                    size: 15,
                                    index: i,
                                    compartment: .center)
                        .offset(y: CGFloat(i) * -2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.045))
                .overlay(Capsule().strokeBorder(Tokens.jewelGold.opacity(0.18), lineWidth: 1))
        )
    }

    private func winnerCaption(_ winner: Int) -> String {
        if winner == 0 {
            return String(localized: "phase3.result.you.finish",
                          defaultValue: "Dein letzter Zug entscheidet.")
        }
        let format = String(localized: "phase3.result.opponent.finish",
                            defaultValue: "%@ schließt die Runde ab.")
        return String(format: format, game.name(of: winner))
    }

    private func settlementPill(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 6.8, weight: .heavy))
                .tracking(1)
                .foregroundStyle(Tokens.slate.opacity(0.72))
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.045))
            .overlay(Capsule().strokeBorder(tint.opacity(0.24), lineWidth: 1)))
    }

    private var finalMomentStatus: some View {
        let recap = game.roundRecap
        let marker = recap.finalCard.map { "\($0.rank.index)\($0.suit.symbol)" } ?? "·"
        let title: String = {
            guard let seat = recap.finalPlayer else { return "" }
            if seat == 0 {
                return String(localized: "phase3.final.you",
                              defaultValue: "Du hast deine Hand geleert")
            }
            let format = String(localized: "phase3.final.opponent",
                                defaultValue: "%@ hat zuerst keine Karten mehr")
            return String(format: format, game.name(of: seat))
        }()

        return VStack(spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Tokens.jewelGold.opacity(0.90))
                    .frame(width: 7, height: 7)
                Text(String(localized: "phase3.final.eyebrow",
                            defaultValue: "LETZTE KARTE"))
                    .font(.system(size: 8.2, weight: .heavy))
                    .tracking(1.35)
                    .foregroundStyle(Tokens.jewelGold.opacity(0.86))
                Text(marker)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.88))
            }
            Text(title)
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(finalSettlementExplanation)
                .font(.system(size: 10.2, weight: .semibold))
                .foregroundStyle(Tokens.slate.opacity(0.82))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(height: 86)
        .background(
            LinearGradient(colors: [
                Color.clear,
                Color.black.opacity(0.68),
                Color.clear
            ], startPoint: .top, endPoint: .bottom)
            .frame(width: 352, height: 108)
        )
        .transition(.opacity)
    }

    private var finalSettlementExplanation: String {
        guard let winner = game.roundRecap.finalPlayer else { return "" }
        if winner == 0 {
            return String(localized: "phase3.final.you.body",
                          defaultValue: "Du nimmst die Mitte. Jeder Gegner zahlt dir 1 Chip pro Restkarte - solange sein Vorrat reicht.")
        }
        let format = String(localized: "phase3.final.opponent.body",
                            defaultValue: "%@ nimmt die Mitte. Du zahlst 1 Chip pro Restkarte - solange dein Vorrat reicht.")
        return String(format: format, game.name(of: winner))
    }

    private var statusLine: some View {
        if isGuidedRound {
            return AnyView(guidedStatusLine)
        }
        let leader = game.playoutLeader ?? 0
        let last = game.revealedChains.last?.last?.card
        let marker = last.map { "\($0.rank.index)\($0.suit.symbol)" } ?? "·"
        let firstLead = game.revealedPlays == 0 && game.cascadeIdle
        let title: String = {
            guard game.cascadeIdle else {
                return String(localized: "phase3.chain.running", defaultValue: "DIE REIHE LÄUFT AUFWÄRTS")
            }
            if firstLead {
                if leader == 0 {
                    return String(localized: "phase3.start.you", defaultValue: "TIPPE DEINE STARTKARTE")
                }
                let format = String(localized: "phase3.start.opponent",
                                    defaultValue: "%@ LEGT DIE STARTKARTE")
                return String(format: format, game.name(of: leader).uppercased())
            }
            if leader == 0 {
                return String(localized: "phase3.lead.you", defaultValue: "DU BEGINNST EINE NEUE REIHE")
            }
            let format = String(localized: "phase3.lead.opponent",
                                defaultValue: "%@ BEGINNT EINE NEUE REIHE")
            return String(format: format, game.name(of: leader).uppercased())
        }()
        let detail: String = {
            guard game.cascadeIdle else {
                return String(localized: "phase3.chain.detail", defaultValue: "Jetzt folgt die nächsthöhere Karte derselben Farbe. Fehlt sie, endet die Reihe.")
            }
            if firstLead {
                return String(localized: "phase3.start.detail",
                              defaultValue: "Tippe eine beliebige Karte. Danach folgt automatisch die nächsthöhere Karte derselben Farbe.")
            }
            if leader == 0, assistHints {
                return String(localized: "phase3.lead.hint",
                              defaultValue: "Du hast die letzte mögliche Karte gelegt. Wähle jetzt eine neue Startkarte.")
            }
            return leader == 0
                ? String(localized: "phase3.lead.you.detail",
                         defaultValue: "Du hast die letzte mögliche Karte gelegt. Wähle jetzt eine neue Startkarte.")
                : String(localized: "phase3.lead.opponent.detail",
                         defaultValue: "Wer die letzte mögliche Karte legt, beginnt die nächste Reihe.")
        }()
        return AnyView(VStack(spacing: 7) {
            HStack(spacing: 7) {
                Circle()
                    .fill((game.cascadeIdle ? Tokens.jewelGold : Tokens.jewelSmaragd).opacity(0.88))
                    .frame(width: 7, height: 7)
                Text(firstLead
                     ? String(localized: "phase3.start.eyebrow", defaultValue: "ERSTER ZUG")
                     : (game.cascadeIdle ? "REIHE ENDET BEI \(marker)" : marker))
                    .font(.system(size: 8.2, weight: .heavy))
                    .tracking(1.25)
                    .foregroundStyle((game.cascadeIdle ? Tokens.jewelGold : Tokens.jewelSmaragd).opacity(0.84))
            }
            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(game.cascadeIdle && leader == 0
                                 ? Tokens.jewelGold : theme.smaragdFocus)
            Text(detail)
                .font(.system(size: isGuidedRound ? 11.2 : 10.2, weight: .semibold))
                .foregroundStyle(isGuidedRound
                                 ? Tokens.jewelPlatin.opacity(0.82)
                                 : Tokens.slate.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
            .padding(.top, 2)
            .padding(.bottom, 0)
            .frame(height: 78)
            .background(
                LinearGradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.58),
                    Color.clear
                ], startPoint: .top, endPoint: .bottom)
                .frame(width: 340, height: 100)
            )
            .accessibilityElement(children: .combine)
            .zIndex(5)
        )
    }

    private var guidedStatusLine: some View {
        let copy = guidedStatusCopy
        return VStack(spacing: 7) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Tokens.jewelGold.opacity(0.90))
                    .frame(width: 7, height: 7)
                Text(copy.eyebrow)
                    .font(.system(size: 8.2, weight: .heavy))
                    .tracking(1.25)
                    .foregroundStyle(Tokens.jewelGold.opacity(0.88))
            }
            Text(copy.title)
                .font(.system(size: 16, weight: .heavy))
                .tracking(0.45)
                .foregroundStyle(Tokens.jewelGold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
            Text(copy.detail)
                .font(.system(size: 11.2, weight: .semibold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.86))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.88)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(minHeight: 90)
        .background(
            LinearGradient(colors: [
                Color.clear,
                Color.black.opacity(0.64),
                Color.clear
            ], startPoint: .top, endPoint: .bottom)
            .frame(width: 340, height: 118)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("phase3.guided.explanation")
        .zIndex(5)
    }

    private var guidedAdvanceButton: some View {
        Button {
            game.advanceGuidedPlayoutPresentation()
        } label: {
            ResilientActionLabel(guidedAdvanceTitle, systemImage: "arrow.right")
                .font(.system(size: 12.5, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.88))
                .background(
                    Capsule()
                        .fill(Tokens.jewelGold)
                        .shadow(color: Tokens.jewelGold.opacity(0.20), radius: 10, y: 4)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("phase3.guided.advance")
        .zIndex(8)
    }

    private var guidedAdvanceTitle: String {
        guard let phase = game.round.playout else {
            return String(localized: "phase3.guided.next", defaultValue: "Nächste Karte ansehen")
        }
        if phase.plays.indices.contains(game.revealedPlays) {
            return String(localized: "phase3.guided.next", defaultValue: "Nächste Karte ansehen")
        }
        let format = String(localized: "phase3.guided.opponent.lead.action",
                            defaultValue: "%@ eröffnet die nächste Reihe")
        return String(format: format, game.name(of: game.uiSeat(forRoundSeat: phase.leader)))
    }

    private var guidedStatusCopy: Phase3GuidedStatusCopy {
        let events = game.revealedPlayEvents
        guard let last = events.last else {
            let card = game.guidedRecommendedOpeningCard
            let label = card.map(cardLabel) ?? String(localized: "phase3.guided.card",
                                                        defaultValue: "eine Karte")
            return Phase3GuidedStatusCopy(
                eyebrow: String(localized: "phase3.guided.first.eyebrow",
                                 defaultValue: "DEINE ERSTE REIHE"),
                title: String(format: String(localized: "phase3.guided.first.title",
                                             defaultValue: "LEGE %@"), label),
                detail: String(format: String(localized: "phase3.guided.first.detail",
                                              defaultValue: "%@ eröffnet die Reihe. Danach geht dieselbe Farbe Karte für Karte aufwärts."),
                               label)
            )
        }

        let seat = game.uiSeat(forRoundSeat: last.player)
        let actor = seat == 0
            ? String(localized: "phase3.guided.you", defaultValue: "Du")
            : game.name(of: seat)
        let currentLabel = cardLabel(last.card)

        if game.cascadeIdle {
            let nextRank = Rank(rawValue: last.card.rank.rawValue + 1)
            let ending: String
            if let nextRank {
                let missing = cardLabel(Card(suit: last.card.suit, rank: nextRank))
                if seat == 0 {
                    ending = String(format: String(localized: "phase3.guided.break.missing.you",
                                                   defaultValue: "%@ fehlt. Du hast die letzte mögliche Karte gelegt und eröffnest deshalb neu."),
                                    missing)
                } else {
                    ending = String(format: String(localized: "phase3.guided.break.missing.opponent",
                                                   defaultValue: "%@ fehlt. %@ hat die letzte mögliche Karte gelegt und eröffnet deshalb neu."),
                                    missing, actor)
                }
            } else {
                if seat == 0 {
                    ending = String(format: String(localized: "phase3.guided.break.ace.you",
                                                   defaultValue: "Mit %@ ist die Reihe vollständig. Du hast sie geschlossen und eröffnest deshalb neu."),
                                    currentLabel)
                } else {
                    ending = String(format: String(localized: "phase3.guided.break.ace.opponent",
                                                   defaultValue: "Mit %@ ist die Reihe vollständig. %@ hat sie geschlossen und eröffnet deshalb neu."),
                                    currentLabel, actor)
                }
            }
            let title = seat == 0
                ? String(localized: "phase3.guided.new.you",
                         defaultValue: "WÄHLE DEINE NEUE STARTKARTE")
                : String(format: String(localized: "phase3.guided.new.opponent",
                                        defaultValue: "%@ ERÖFFNET NEU"), actor.uppercased())
            let choice = seat == 0
                ? String(format: String(localized: "phase3.guided.new.choice",
                                        defaultValue: " Du entscheidest selbst - alle %d Karten in deiner Hand sind gültige Starts."),
                         game.displayedHumanHand.count)
                : ""
            return Phase3GuidedStatusCopy(
                eyebrow: String(format: String(localized: "phase3.guided.break.eyebrow",
                                               defaultValue: "REIHE ENDET BEI %@"), currentLabel),
                title: title,
                detail: ending + choice
            )
        }

        let previous = events.dropLast().last
        let reason: String
        if last.isLead {
            if seat == 0 {
                reason = String(format: String(localized: "phase3.guided.reason.lead.you",
                                               defaultValue: "Du eröffnest mit %@. Jetzt sucht der Tisch die nächsthöhere Karte derselben Farbe."),
                                currentLabel)
            } else {
                reason = String(format: String(localized: "phase3.guided.reason.lead.opponent",
                                               defaultValue: "%@ eröffnet mit %@. Jetzt sucht der Tisch die nächsthöhere Karte derselben Farbe."),
                                actor, currentLabel)
            }
        } else if let previous {
            if seat == 0 {
                reason = String(format: String(localized: "phase3.guided.reason.follow.you",
                                               defaultValue: "Du legst %@, weil sie direkt auf %@ folgt und dieselbe Farbe hat."),
                                currentLabel, cardLabel(previous.card))
            } else {
                reason = String(format: String(localized: "phase3.guided.reason.follow.opponent",
                                               defaultValue: "%@ legt %@, weil sie direkt auf %@ folgt und dieselbe Farbe hat."),
                                actor, currentLabel, cardLabel(previous.card))
            }
        } else {
            reason = seat == 0
                ? String(format: String(localized: "phase3.guided.reason.card.you",
                                        defaultValue: "Du legst %@."), currentLabel)
                : String(format: String(localized: "phase3.guided.reason.card.opponent",
                                        defaultValue: "%@ legt %@."), actor, currentLabel)
        }

        let playedEyebrow = seat == 0
            ? String(format: String(localized: "phase3.guided.played.eyebrow.you",
                                    defaultValue: "DU LEGST %@"), currentLabel)
            : String(format: String(localized: "phase3.guided.played.eyebrow.opponent",
                                    defaultValue: "%@ LEGT %@"), actor.uppercased(), currentLabel)

        if let required = game.guidedRequiredHumanFollowCard {
            let requiredLabel = cardLabel(required)
            return Phase3GuidedStatusCopy(
                eyebrow: playedEyebrow,
                title: String(format: String(localized: "phase3.guided.follow.title",
                                             defaultValue: "TIPPE DEIN %@"), requiredLabel),
                detail: reason + " " + String(format: String(localized: "phase3.guided.follow.detail",
                                                              defaultValue: "Du hältst die nächste Karte der Reihe: %@."),
                                                 requiredLabel)
            )
        }

        return Phase3GuidedStatusCopy(
            eyebrow: playedEyebrow,
            title: game.guidedPlayoutCanAdvance
                ? String(localized: "phase3.guided.watch.title",
                         defaultValue: "WER HAT DIE NÄCHSTE KARTE?")
                : String(localized: "phase3.guided.row.title",
                         defaultValue: "DIE REIHE LÄUFT AUFWÄRTS"),
            detail: reason
        )
    }

    private func cardLabel(_ card: Card) -> String {
        "\(card.rank.index)\(card.suit.symbol)"
    }

    private var lastRevealedPlay: PlayoutPhase.Play? {
        game.revealedPlayEvents.last
    }

    /// Angewinkelter Handfächer (Muster von ContentView::handView, §5b Akt 3 Spielerhand).
    private func handFan(canvas: CGSize) -> some View {
        let cards = game.displayedHumanHand
        let N = cards.count

        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.element) { i, card in
                let pose = Phase3CardGeometry.handLocalPose(
                    index: i,
                    count: N,
                    raised: game.canHumanPlay(card, guided: isGuidedRound)
                )
                let canPlay = game.canHumanPlay(card, guided: isGuidedRound)

                ZStack {
                    CardFace(card: card,
                             scale: Phase3CardGeometry.handCardScale,
                             isAccessibilityHidden: true)
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 9 * Phase3CardGeometry.handCardScale + 1.4
                            )
                                .strokeBorder(Tokens.jewelGold.opacity(canPlay ? 0.70 : 0),
                                              lineWidth: canPlay ? 1.4 : 0)
                                .padding(-1.4)
                        )
                        .shadow(color: canPlay ? Tokens.jewelGold.opacity(0.22) : .clear,
                                radius: canPlay ? 10 : 0,
                                y: canPlay ? 2 : 0)

                    // Die Interaktionsfläche liegt getrennt über der Karte. Dadurch
                    // bleibt der Karton auch im deaktivierten Zustand voll deckend,
                    // während VoiceOver und UI-Tests weiterhin korrekt erkennen,
                    // welche Karte gerade gespielt werden darf.
                    Button {
                        pendingHumanFlightSource = Phase3HumanFlightSource(
                            sequence: game.revealedPlays + 1,
                            generation: game.playPresentationGeneration,
                            pose: Phase3CardGeometry.handSourcePose(
                                index: i,
                                count: N,
                                canvas: canvas,
                                raised: canPlay
                            )
                        )
                        game.humanLead(card, guided: isGuidedRound)
                    } label: {
                        Color.clear
                            .frame(width: 52 * Phase3CardGeometry.handCardScale,
                                   height: 74 * Phase3CardGeometry.handCardScale)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canPlay)
                    .accessibilityLabel(cardLabel(card))
                    .accessibilityIdentifier(
                        "phase3.hand.card.\(card.suit.rawValue).\(card.rank.rawValue)"
                    )
                }
                .offset(x: pose.point.x, y: pose.point.y)
                .rotationEffect(.degrees(pose.rotationDegrees), anchor: .bottom)
                .zIndex(Double(i))
                .transition(phase3ReduceMotion
                            ? .opacity
                            : .scale(scale: 0.86, anchor: .bottom).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("phase3.hand")
        .animation(phase3ReduceMotion ? nil : .easeOut(duration: 0.16), value: N)
        .frame(height: Phase3CardGeometry.handFrameHeight, alignment: .bottom)
    }

    // MARK: - Rundenende

    private var resultBanner: some View {
        VStack(spacing: 14) {
            if let r = game.roundResult {
                let payments = r.payments.reduce(0, +)
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        if r.winner != 0 {
                            OpponentPortrait(seat: r.winner,
                                             name: game.name(of: r.winner),
                                             isActive: true,
                                             isFocus: true,
                                             mood: .winning,
                                             size: 42,
                                             showsText: false,
                                             morph: nil)
                        }
                        VStack(alignment: r.winner == 0 ? .center : .leading, spacing: 4) {
                            Text(r.winner == 0 ? "Du gewinnst" : "\(game.name(of: r.winner)) gewinnt")
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(Tokens.jewelPlatin)
                            Text("Runde abgeschlossen")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.9)
                                .foregroundStyle(theme.smaragdFocus.opacity(0.82))
                        }
                    }
                }

                HStack(spacing: 10) {
                    resultMetric(String(localized: "phase3.metric.center", defaultValue: "MITTE"),
                                 "\(r.centerPool)", Tokens.jewelPlatin)
                    resultMetric(String(localized: "phase3.metric.remaining", defaultValue: "RESTKARTEN"),
                                 "+\(payments)", Tokens.jewelGold)
                    resultMetric(String(localized: "phase3.metric.total", defaultValue: "GESAMT"),
                                 "\(r.centerPool + payments)", theme.smaragdFocus)
                }

                recapStrip(game.roundRecap)

                VStack(spacing: 7) {
                    ForEach(Array(r.payments.enumerated()), id: \.offset) { seat, payment in
                        if seat != r.winner {
                            paymentRow(seat: seat,
                                       payment: payment,
                                       stack: game.displayedEndStack(of: seat))
                        }
                    }
                }
                .padding(.top, 2)
            }

            Button {
                onNewRound()
            } label: {
                ResilientActionLabel(
                    String(localized: "phase3.result.next",
                           defaultValue: "Nächste Runde"),
                    systemImage: "arrow.right"
                )
                    .foregroundStyle(Tokens.jewelPlatin)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [
                                Color(hex: 0x27221B),
                                Color(hex: 0x121015)
                            ], startPoint: .top, endPoint: .bottom))
                            .overlay(Capsule().strokeBorder(Tokens.jewelGold.opacity(0.72), lineWidth: 1.2))
                            .shadow(color: Tokens.jewelGold.opacity(0.12), radius: 10, y: 4)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: 350)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [
                Color(hex: 0x17141D),
                Color(hex: 0x0B0A10)
            ], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Tokens.jewelGold.opacity(0.28), lineWidth: 1))
            .shadow(color: .black.opacity(0.64), radius: 26, y: 16))
        .padding(.bottom, 20)
    }

    private func resultMetric(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 7.5, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(Tokens.slate.opacity(0.75))
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)))
    }

    private func recapStrip(_ recap: GameState.RoundRecap) -> some View {
        let final = recap.finalCard.map { "\($0.rank.index)\($0.suit.symbol)" } ?? "·"
        let finisher = recap.finalPlayer.map { game.name(of: $0) } ?? "·"
        return HStack(spacing: 8) {
            recapPill("REIHEN", "\(recap.chains)")
            recapPill("LÄNGSTE", "\(recap.longestChain)")
            recapPill("LETZTE", final)
            recapPill("FINISH", finisher)
        }
        .padding(.vertical, 2)
    }

    private func recapPill(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 6.8, weight: .bold))
                .tracking(1)
                .foregroundStyle(Tokens.slate.opacity(0.66))
            Text(value)
                .font(.system(size: value.count > 5 ? 9 : 11.5, weight: .bold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.035)))
    }

    private func paymentRow(seat: Int, payment: Int, stack: Int) -> some View {
        HStack(spacing: 8) {
            if seat == 0 {
                TableWorldPiece(world: theme,
                                size: 14,
                                compartment: .center)
            } else {
                OpponentPortrait(seat: seat,
                                 name: game.name(of: seat),
                                 isActive: true,
                                 mood: .passed,
                                 size: 22,
                                 showsText: false,
                                 morph: nil)
            }
            Text(game.name(of: seat))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.9))
            Spacer()
            Text(payment > 0 ? "-\(payment)" : "0")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(payment > 0 ? Tokens.jewelGold : Tokens.slate)
            Text("\(stack)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.slate)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.035)))
    }
}

/// Jede enthüllte Karte hat eine sichtbare Herkunft. Die Flugkarte liegt kurz
/// über dem bereits aktualisierten Fächer und blendet beim Einrasten aus.
private struct Phase3CardArrival: View {
    let card: Card
    let seat: Int
    let trigger: Int
    let generation: Int
    let canvas: CGSize
    let opponentsY: CGFloat
    let humanSourcePose: Phase3CardPose?
    let targetPose: Phase3CardPose
    let onImpact: () -> Void
    @State private var landed = false

    var body: some View {
        ImpactFlight(from: sourcePose.point,
                     to: targetPose.point,
                     duration: Tokens.p3CardFlight,
                     arcHeight: 54,
                     lateralBias: lateralBias,
                     onImpact: {
                         landed = true
                         onImpact()
                     }) { progress in
            let scaleRatio = interpolatedScale(progress: progress) / targetPose.scale
            CardFace(card: card, scale: targetPose.scale)
                .rotationEffect(.degrees(interpolatedAngle(progress: progress)),
                                anchor: .bottom)
                .scaleEffect(scaleRatio)
                .rotation3DEffect(.degrees(12 * Double(1 - progress)),
                                  axis: (x: 0.18, y: 0.72, z: 0.10),
                                  perspective: 0.42)
                .shadow(color: .black.opacity(0.64),
                        radius: progress > 0.8 ? 5 : 12,
                        y: progress > 0.8 ? 3 : 7)
            }
            .opacity(landed ? 0 : 1)
            .id("phase3-flight-\(generation)-\(trigger)")
    }

    private var sourcePose: Phase3CardPose {
        if seat == 0, let humanSourcePose {
            return humanSourcePose
        }
        return Phase3CardPose(
            point: opponentOrigin,
            rotationDegrees: opponentStartAngle,
            scale: 0.94
        )
    }

    private var opponentOrigin: CGPoint {
        switch seat {
        case 0:
            return CGPoint(x: canvas.width / 2, y: canvas.height - 36)
        case 1:
            return CGPoint(x: canvas.width * 0.21, y: opponentsY)
        case 2:
            return CGPoint(x: canvas.width * 0.50, y: opponentsY)
        default:
            return CGPoint(x: canvas.width * 0.79, y: opponentsY)
        }
    }

    private func interpolatedAngle(progress: CGFloat) -> Double {
        sourcePose.rotationDegrees
            + (targetPose.rotationDegrees - sourcePose.rotationDegrees) * Double(progress)
    }

    private func interpolatedScale(progress: CGFloat) -> CGFloat {
        sourcePose.scale + (targetPose.scale - sourcePose.scale) * progress
    }

    private var opponentStartAngle: Double {
        switch seat {
        case 1: return -17
        case 3: return 17
        default: return -5
        }
    }

    private var lateralBias: CGFloat {
        seat == 1 ? -24 : (seat == 3 ? 24 : 0)
    }
}

private struct Phase3HumanFlightSource {
    let sequence: Int
    let generation: Int
    let pose: Phase3CardPose
}

private struct Phase3GuidedStatusCopy {
    let eyebrow: String
    let title: String
    let detail: String
}

private struct Phase3CardPose {
    let point: CGPoint
    let rotationDegrees: Double
    let scale: CGFloat
}

private enum Phase3CardGeometry {
    private static let cardHeightAtUnitScale: CGFloat = 74
    static let handCardScale: CGFloat = 1.50
    static let handContainerHeight: CGFloat = 150
    static let handCenterBottomInset: CGFloat = 104
    static let handFrameHeight: CGFloat = cardHeightAtUnitScale * handCardScale * 0.92

    static let playedTopOffset: CGFloat = 52

    static func playedCardScale(previewMode: Bool, finalTableau: Bool) -> CGFloat {
        finalTableau ? 1.34 : (previewMode ? 1.34 : 1.42)
    }

    static func playedFrameHeight(previewMode: Bool, finalTableau: Bool) -> CGFloat {
        cardHeightAtUnitScale
            * playedCardScale(previewMode: previewMode, finalTableau: finalTableau)
            * (previewMode || finalTableau ? 1.76 : 1.40)
    }

    static func playedLocalPose(
        index: Int,
        count: Int,
        previewMode: Bool,
        finalTableau: Bool
    ) -> Phase3CardPose {
        let t: CGFloat = count > 1 ? CGFloat(index) / CGFloat(count - 1) : 0.5
        let broadFan = previewMode || finalTableau
        let spreadDegrees = count > 1
            ? min(Double(count) * (broadFan ? 9.8 : 10.8), broadFan ? 70.0 : 62.0)
            : 0
        let totalWidth: CGFloat = count > 1
            ? min(CGFloat(count - 1) * (broadFan ? 30 : 37), broadFan ? 218 : 206)
            : 0
        let xOffset: CGFloat = count > 1 ? -totalWidth / 2 + t * totalWidth : 0
        let crownLift = CGFloat(sin(Double(t) * .pi)) * (broadFan ? 44 : 34)
        let edgeDrop = abs(t - 0.5) * (broadFan ? 38 : 24)
        let angle = count > 1
            ? -spreadDegrees / 2 + Double(t) * spreadDegrees
            : 0
        return Phase3CardPose(
            point: CGPoint(x: xOffset, y: edgeDrop - crownLift),
            rotationDegrees: angle,
            scale: playedCardScale(previewMode: previewMode, finalTableau: finalTableau)
        )
    }

    static func playedTargetPose(index: Int,
                                 count: Int,
                                 canvasWidth: CGFloat,
                                 topOffset: CGFloat = playedTopOffset) -> Phase3CardPose {
        let local = playedLocalPose(
            index: index,
            count: count,
            previewMode: false,
            finalTableau: false
        )
        return Phase3CardPose(
            point: CGPoint(
                x: canvasWidth / 2 + local.point.x,
                y: topOffset
                    + playedFrameHeight(previewMode: false, finalTableau: false) / 2
                    + local.point.y
            ),
            rotationDegrees: local.rotationDegrees,
            scale: local.scale
        )
    }

    static func handLocalPose(index: Int, count: Int, raised: Bool) -> Phase3CardPose {
        let t: CGFloat = count > 1 ? CGFloat(index) / CGFloat(count - 1) : 0.5
        let spreadDegrees = min(Double(count) * 7.4, 44.0)
        let totalWidth: CGFloat = min(CGFloat(count) * 32, 246)
        let xOffset: CGFloat = count > 1 ? -totalWidth / 2 + t * totalWidth : 0
        let yOffset = raised ? -4 * (1 - abs(t - 0.5) * 1.2) : 0
        let angle = count > 1
            ? -spreadDegrees / 2 + Double(t) * spreadDegrees
            : 0
        return Phase3CardPose(
            point: CGPoint(x: xOffset, y: yOffset),
            rotationDegrees: angle,
            scale: handCardScale
        )
    }

    static func handSourcePose(
        index: Int,
        count: Int,
        canvas: CGSize,
        raised: Bool
    ) -> Phase3CardPose {
        let local = handLocalPose(index: index, count: count, raised: raised)
        let containerBottom = canvas.height
            - handCenterBottomInset
            + handContainerHeight / 2
        return Phase3CardPose(
            point: CGPoint(
                x: canvas.width / 2 + local.point.x,
                y: containerBottom
                    - cardHeightAtUnitScale * handCardScale / 2
                    + local.point.y
            ),
            rotationDegrees: local.rotationDegrees,
            scale: local.scale
        )
    }
}

/// Straf-Strom (§6c c): pro Verlierer ein PARALLELER Chip-Strom zum Sieger
/// (nie sequenzielle Einzelflüge - Auflage). Zahlungen visuell auf 5 Chips gedeckelt.
private struct PunishStreams: View {
    let result: (winner: Int, centerPool: Int, payments: [Int])
    let world: TableWorld
    @State private var flown = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let winnerPos = position(seat: result.winner, w: w, h: h)
            ZStack {
                ForEach(0..<min(result.centerPool, 8), id: \.self) { i in
                    EndChip(from: CGPoint(x: w / 2, y: h * 0.45),
                            to: winnerPos,
                            world: world,
                            tint: Tokens.jewelPlatin,
                            index: i,
                            lane: -1,
                            trigger: flown)
                }
                ForEach(Array(result.payments.enumerated()), id: \.offset) { seat, payment in
                    if payment > 0, seat != result.winner {
                        let from = position(seat: seat, w: w, h: h)
                        ForEach(0..<min(payment, 5), id: \.self) { i in
                            EndChip(from: from,
                                    to: winnerPos,
                                    world: world,
                                    tint: Tokens.jewelGold,
                                    index: i,
                                    lane: seat,
                                    trigger: flown)
                        }
                    }
                }
            }
            .onAppear { flown = true }
        }
    }

    private func position(seat: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        seat == 0 ? CGPoint(x: w / 2, y: h - 90)
                  : CGPoint(x: w / 2 + CGFloat(seat - 2) * 70, y: 96)
    }
}

private struct EndChip: View {
    let from: CGPoint
    let to: CGPoint
    let world: TableWorld
    let tint: Color
    let index: Int
    let lane: Int
    let trigger: Bool

    var body: some View {
        let t: CGFloat = trigger ? 1 : 0
        let p = point(t)
        TableWorldPiece(world: world,
                        size: 12,
                        seed: UInt64(max(index, 0)) + 1_441,
                        index: index,
                        compartment: lane < 0 ? .center : .poch)
            .rotationEffect(.degrees((Double(index % 3) - 1) * 6 + Double(t) * 12))
            .position(p)
            .opacity(trigger ? 0.10 : 1)
            .shadow(color: .black.opacity(0.48), radius: trigger ? 2 : 5, y: trigger ? 1 : 3)
            .animation(.easeOut(duration: Tokens.p3PunishFlight)
                .delay(Double(index) * 0.045 + laneDelay),
                       value: trigger)
    }

    private var laneDelay: Double {
        lane < 0 ? 0 : Double(lane % 3) * 0.035
    }

    private func point(_ t: CGFloat) -> CGPoint {
        let inv = 1 - t
        let side = lane < 0 ? CGFloat(index - 3) : CGFloat(lane - 2) * 18
        let control = CGPoint(x: (from.x + to.x) / 2 + side + CGFloat(index - 2) * 7,
                              y: min(from.y, to.y) - (lane < 0 ? 62 : 44))
        return CGPoint(
            x: inv * inv * from.x + 2 * inv * t * control.x + t * t * to.x,
            y: inv * inv * from.y + 2 * inv * t * control.y + t * t * to.y
        )
    }
}

/// Platin-Mitte öffnet sich kurz und gibt den Centerpot frei. Das ist bewusst
/// Material-Sog statt Lichtring: ein gefasster Pot, Staub/Splitter, dann Ruhe.
private struct CenterPotRelease: View {
    let result: (winner: Int, centerPool: Int, payments: [Int])
    @State private var released = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let center = CGPoint(x: w / 2, y: h * 0.45)
            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(colors: [
                            Tokens.jewelPlatin.opacity(released ? 0.06 : 0.72),
                            Tokens.jewelGold.opacity(released ? 0.03 : 0.28)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: released ? 1 : 4)
                    .frame(width: released ? 132 : 72, height: released ? 132 : 72)
                    .position(center)
                    .opacity(released ? 0 : 1)

                Text("+\(result.centerPool)")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.62))
                        .overlay(Capsule().strokeBorder(Tokens.jewelPlatin.opacity(0.32), lineWidth: 1)))
                    .position(x: center.x, y: center.y + (released ? -46 : -8))
                    .opacity(released ? 0 : 1)
                    .animation(.easeOut(duration: 0.58), value: released)
            }
            .onAppear {
                released = false
                withAnimation(.easeOut(duration: 0.62)) { released = true }
            }
        }
    }
}
