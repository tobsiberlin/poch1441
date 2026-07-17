import PochKit
import SwiftUI

/// Phase 2 (Pochen) - der psychologische Kern (§6b) im Kompressions-Layout (§5b, Akt 2):
/// Gegner rücken als Kardinalpunkt-Tokens nah (§5c, Platzhalter bis Charakterstil-Urteil),
/// der violette Poch-Pott ist der Held im Zentrum, der entsättigte Ring tritt als Echo
/// zurück. Unten: Hand (Kunststück leuchtet) + Biet-Slider mit personifizierter Limit-Wand.
struct Phase2View: View {
    private enum GuidedFocus {
        case none
        case hand
        case range
        case actions
        case opponents
    }

    let game: GameState
    let theme: Theme
    /// Phasen-Morph-Namespace (§5b) - geteilt mit ContentView/Phase3View.
    let morph: Namespace.ID
    let assistHints: Bool
    let isGuidedRound: Bool
    let onContinue: () -> Void
    let onNewRound: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bid = 1.0
    @State private var presentedPot = 0
    @State private var pendingPot: Int?
    @State private var transferPresentationActive = false
    @State private var guidedPreludeStep = 0
    #if DEBUG
    @State private var qaPochFlight = 0
    #endif

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let w = proxy.size.width
            let topH = min(Tokens.phase2StageHeight, h * 0.35)
            let decisionTop = topH + 8
            let guidedPreludeActive = isGuidedRound && guidedPreludeStep < 2
            let decisionH: CGFloat = guidedPreludeActive ? 166 : (isGuidedRound ? 116 : 104)
            let compactHeight = h < Tokens.phase2CompactHeight
            let actionGap: CGFloat = compactHeight ? 0 : 12
            let actionsTop = decisionTop + decisionH + actionGap
            let actionsH: CGFloat = 48
            let opponentGap = compactHeight
                ? Tokens.phase2OpponentGapCompact
                : Tokens.phase2OpponentGapRegular
            let naturalSeatsTop = actionsTop + actionsH + opponentGap
            let latestSeatsTop = h - Tokens.phase2HandReservedHeight
            let seatsY = min(naturalSeatsTop, latestSeatsTop)

            ZStack(alignment: .top) {
                topArea
                    .frame(width: w, height: topH)
                    .modifier(TableShake(
                        amplitude: reduceMotion ? 0 : Tokens.pochShakeAmp,
                        animatableData: CGFloat(game.pochShock)))
                    .animation(.linear(duration: Tokens.pochShake), value: game.pochShock)
                    .offset(y: 2)

                pochenDecisionCard
                    .frame(width: min(342, w - 14))
                    .frame(height: decisionH, alignment: .top)
                    .offset(y: decisionTop)

                actionArea
                    .frame(width: min(336, w - 26), height: actionsH, alignment: .top)
                    .offset(y: actionsTop)
                    .modifier(GuidedFocusModifier(
                        isActive: isGuidedRound,
                        isRelevant: guidedFocus == .actions,
                        reduceMotion: reduceMotion
                    ))
                    .allowsHitTesting(!isGuidedRound || guidedFocus == .actions)
                    .opacity(isGuidedRound && guidedFocus != .actions ? 0 : 1)

                portraitsRow(maxPanelWidth: compactHeight ? 96 : 106)
                    .frame(width: w, height: Tokens.phase2OpponentRowHeight,
                           alignment: .top)
                    .offset(y: seatsY)
                    .modifier(GuidedFocusModifier(
                        isActive: isGuidedRound,
                        isRelevant: guidedFocus == .opponents,
                        reduceMotion: reduceMotion
                    ))
                    .opacity(isGuidedRound && guidedFocus != .opponents ? 0 : 1)
                    .allowsHitTesting(!isGuidedRound || guidedFocus == .opponents)

                handFan
                    .frame(width: w, height: 150, alignment: .bottom)
                    .position(x: w / 2, y: h - 58)
                    // Die eigene Hand bleibt immer vollständig deckend. Opacity
                    // auf dem gesamten Fächer lässt sonst Karten darunter durch-
                    // scheinen und liest sich wie ein unscharfes Doppelbild.
            }
        }
        .onAppear {
            resetBid()
            presentedPot = game.pot
            scheduleGuidedPrelude()
            #if DEBUG
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
        .onChange(of: game.betTransfer) { _, _ in
            transferPresentationActive = game.betTransfer > 0
        }
        .onDisappear {
            pendingPot = nil
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.pochShock)
        .overlay {
            if game.betTransfer > 0, !reduceMotion {
                PochBetFlight(seat: game.lastBetActor ?? game.turnIndex,
                              amount: game.lastBetAmount,
                              kind: game.lastBetKind,
                              trigger: game.betTransfer,
                              tint: theme.tint(.poch),
                              onImpact: commitBetImpact)
                    .allowsHitTesting(false)
            }
            #if DEBUG
            if qaPochFlight > 0, !reduceMotion {
                PochBetFlight(seat: 0,
                              amount: 4,
                              kind: .raise,
                              trigger: qaPochFlight,
                              tint: theme.tint(.poch),
                              onImpact: {})
                    .allowsHitTesting(false)
            }
            #endif
        }
        #if DEBUG
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

    private var guidedFocus: GuidedFocus {
        guard isGuidedRound else { return .none }
        if transferPresentationActive || game.turnIndex != 0 { return .opponents }
        if game.betting.currentBet > 0 || game.humanComboRank == nil { return .actions }
        switch guidedPreludeStep {
        case 0: return .hand
        case 1: return .range
        default: return .actions
        }
    }

    private func schedulePotPresentation(_ value: Int) {
        guard value > presentedPot, !reduceMotion else {
            presentedPot = value
            pendingPot = nil
            return
        }
        pendingPot = value
    }

    private func commitBetImpact() {
        withAnimation(.spring(duration: Tokens.p2PotSpring)) {
            presentedPot = pendingPot ?? game.pot
            pendingPot = nil
            transferPresentationActive = false
        }
    }

    private var pochAccent: Color {
        theme.isTravelTable ? Tokens.jewelAmethyst : Tokens.amethystText
    }

    private func scheduleGuidedPrelude() {
        guidedPreludeStep = 0
    }

    private func advanceGuidedPrelude() {
        guard guidedPreludeStep < 2 else { return }
        withAnimation(.easeInOut(duration: Tokens.guidedFocusTransition)) {
            guidedPreludeStep += 1
        }
    }

    private var pochenHint: String {
        if transferPresentationActive {
            let responder = game.name(of: game.turnIndex)
            let format = String(localized: "phase2.transfer.reply",
                                defaultValue: "Der Einsatz rastet ein. Danach antwortet %@.")
            return String(format: format, responder)
        }
        if game.stage != .betting {
            return "Der Poch ist entschieden. Danach startet der Kartenstrom."
        }
        if game.turnIndex == 0 {
            return game.humanComboRank == nil
                ? "Kein Paar: Passen ist sicher. Danach beginnt das Ausspielen."
                : "Setze \(Int(bid)) Chip. Wer mitgeht, spielt um Einsatz und Poch-Mulde."
        }
        return "\(game.name(of: game.turnIndex)) entscheidet: mitgehen, erhöhen oder passen."
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
                    .font(.system(size: 11, weight: .semibold))
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
                return (game.name(of: result.winner).uppercased(), "NIMMT DEN POCH", Tokens.jewelGold)
            }
            return ("KEIN POCH", "MULDE BLEIBT", Tokens.slate)
        }
        if game.turnIndex == 0 {
            return game.humanComboRank == nil
                ? ("PASSEN", "KEIN PAAR", Tokens.slate)
                : ("DEIN ZUG", "\(game.humanComboRank?.index ?? "")-PAAR", pochAccent)
        }
        let action = actionPresentation(for: game.turnIndex)
        return (action.text.uppercased(), game.name(of: game.turnIndex).uppercased(), action.tone)
    }

    private var pochenDecisionCard: some View {
        let status = pochenStatus
        let cap = game.capHolder.map { game.name(of: $0) } ?? "offen"
        let committed = game.humanCommitted
        return VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 7) {
                if isGuidedRound {
                    guidedDecisionHeader
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

                Text(isGuidedRound ? guidedDecisionCopy.body : pochenHint)
                    .font(.system(size: isGuidedRound ? 11.4 : 11.2, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(isGuidedRound ? 0.92 : 0.76))
                    .lineSpacing(isGuidedRound ? 1.8 : 1.2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if isGuidedRound {
                    Rectangle()
                        .fill(guidedDecisionCopy.tint.opacity(0.16))
                        .frame(height: 1)
                }

                HStack(spacing: 8) {
                    pressureMetric("EINSATZ", "\(Int(bid))", pochAccent)
                    pressureMetric("MULDE", "+\(game.pochPool)", Tokens.jewelGold)
                    pressureMetric("LIMIT", cap, Tokens.slate, muted: true)
                    pressureMetric("DU", "\(committed)", theme.isTravelTable ? Tokens.jewelSmaragd : Tokens.smaragdText)
                }

                if isGuidedRound, guidedPreludeStep < 2,
                   game.turnIndex == 0, game.betting.currentBet == 0 {
                    Button(action: advanceGuidedPrelude) {
                        HStack(spacing: 7) {
                            Text(String(localized: "tutorial.continue",
                                        defaultValue: "Weiter"))
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Tokens.bgDeep)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(guidedDecisionCopy.tint))
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
                .font(.system(size: 16.5, weight: .heavy))
                .foregroundStyle(copy.tint)
                .lineLimit(1)
                .contentTransition(.opacity)
            Spacer(minLength: 0)
            if let detail = pochenStatus.detail {
                Text(detail)
                    .font(.system(size: 9.2, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.64))
                    .lineLimit(1)
            }
        }
    }

    private var guidedDecisionCopy: (step: String, title: String, body: String, tint: Color) {
        if transferPresentationActive || game.turnIndex != 0 {
            let format = String(localized: "tutorial.bidding.observe.body",
                                defaultValue: "%@ reagiert. Verfolge zuerst die Münze, dann seine Entscheidung.")
            return (
                "eye.fill",
                String(localized: "tutorial.bidding.observe.title", defaultValue: "Reaktion lesen"),
                String(format: format, game.name(of: game.turnIndex)),
                Tokens.jewelGold
            )
        }
        if game.betting.currentBet > 0 {
            let callCost = max(0, game.betting.currentBet - game.humanCommitted)
            let format = String(localized: "tutorial.bidding.reply.body",
                                defaultValue: "Mitgehen kostet %d. Passen schützt deine Chips; erhöhen baut Druck auf.")
            return (
                "arrow.left.arrow.right.circle.fill",
                String(localized: "tutorial.bidding.reply.title", defaultValue: "Kosten vergleichen"),
                String(format: format, callCost),
                pochAccent
            )
        }
        if game.humanComboRank == nil {
            return (
                "forward.fill",
                String(localized: "tutorial.bidding.noPair.title", defaultValue: "Kein Paar"),
                String(localized: "tutorial.bidding.noPair.body", defaultValue: "Ohne Paar kannst du nicht pochen. Tippe Passen und gehe ohne Verlust weiter."),
                Tokens.slate
            )
        }
        switch guidedPreludeStep {
        case 0:
            let format = String(localized: "tutorial.bidding.pair.body",
                                defaultValue: "Dein %@-Paar erlaubt dir, den Poch zu eröffnen.")
            return (
                "rectangle.on.rectangle.angled",
                String(localized: "tutorial.bidding.pair.title", defaultValue: "Paar erkannt"),
                String(format: format, game.humanComboRank?.index ?? ""),
                pochAccent
            )
        case 1:
            return (
                "dial.medium.fill",
                String(localized: "tutorial.bidding.stake.title", defaultValue: "Einsatz wählen"),
                String(localized: "tutorial.bidding.stake.body", defaultValue: "Die Range links zeigt deinen erlaubten Einsatz. 1 Chip ist ein ruhiger Test."),
                Tokens.jewelGold
            )
        default:
            let format = String(localized: "tutorial.bidding.commit.body",
                                defaultValue: "Tippe Pochen %d. Danach reagieren die anderen nacheinander.")
            return (
                "hand.tap.fill",
                String(localized: "tutorial.bidding.commit.title", defaultValue: "Pochen"),
                String(format: format, Int(bid)),
                pochAccent
            )
        }
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
                Text(active ? "SETZE" : "POCH")
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
        .accessibilityLabel(active ? "Einsatz \(Int(bid))" : "Poch \(presentedPot)")
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
            let boardDiameter = compactRingDiameter
            ZStack {
                sliderPanel
                    .position(x: 36, y: proxy.size.height / 2 + 1)
                    .modifier(GuidedFocusModifier(
                        isActive: isGuidedRound,
                        isRelevant: guidedFocus == .range,
                        reduceMotion: reduceMotion
                    ))
                    .opacity(isGuidedRound && guidedPreludeStep == 0 ? 0.08 : 1)
                compactRing
                    .position(x: proxy.size.width - boardDiameter / 2 - 1,
                              y: proxy.size.height / 2)
                    .modifier(GuidedFocusModifier(
                        isActive: isGuidedRound,
                        isRelevant: guidedFocus == .opponents,
                        reduceMotion: reduceMotion
                    ))
            }
        }
        .frame(maxHeight: 222)
    }

    /// Vertikaler Biet-Slider links: Drehtrick (.rotationEffect), Track als gefräste Rille.
    private var sliderPanel: some View {
        let sliderRange = game.humanLegal.flatMap { l in l.openRange ?? l.raiseRange }
        let isActive = game.turnIndex == 0 && game.stage == .betting && sliderRange != nil
        let atWall = sliderRange.map { Int(bid) >= $0.upperBound } ?? false

        return VStack(spacing: 6) {
            Text("RANGE")
                .font(.system(size: 10, weight: .semibold)).tracking(2.5)
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
            .sensoryFeedback(.impact(flexibility: .rigid), trigger: atWall)

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
            .animation(.spring(duration: 0.18), value: bid)
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
            Image("PochRingPM49")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: d, height: d)
                .clipShape(Circle())
                .opacity(0.88)
                .shadow(color: .black.opacity(0.62), radius: 10, y: 6)
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
            if !theme.isTravelTable {
                PM49FrontLipOverlay(size: d)
                    .position(x: d / 2, y: d / 2)
            }
            ForEach(PochRing.anchors.filter { $0.pool != .poch }) { anchor in
                PocketValueMarker(pool: anchor.pool,
                                  chips: game.chips(in: anchor.pool),
                                  tint: theme.tint(anchor.pool),
                                  compact: true,
                                  showChipCount: false)
                    .position(TableWorldBoardGeometry.notationCenter(for: anchor.pool,
                                                                     in: d,
                                                                     world: theme))
            }
        }
        .frame(width: d, height: d)
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
                RecessedTokenPile(count: presentedPot,
                                  tint: Tokens.jewelGold,
                                  diameter: Tokens.centerDiameter * 0.42,
                                  showCount: false)
                    .offset(y: 1.5)
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
            }

            Text("POCH")
                .font(.system(size: 5.8, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(pochAccent.opacity(0.76))
                .offset(y: -15)

            Text("\(presentedPot)")
                .font(.system(size: 8.2, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.jewelGold.opacity(0.92))
                .offset(y: 15)
                .contentTransition(.numericText())
        }
        .frame(width: Tokens.centerDiameter * 0.54, height: Tokens.centerDiameter * 0.54)
        .background(
            Circle()
                .fill(LinearGradient(
                    colors: [Tokens.jewelAmethyst.opacity(0.45),
                             Tokens.jewelAmethyst.opacity(0.18)],
                    startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(
                    LinearGradient(
                        colors: [pochAccent.opacity(theme.isTravelTable ? 0.76 : 0.68),
                                 pochAccent.opacity(0.26)],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75))
                .shadow(color: pochAccent.opacity(theme.isTravelTable ? 0.14 : 0.08), radius: 5)
        )
        .matchedGeometryEffect(id: "pochPot", in: morph)
        .scaleEffect(reduceMotion ? 1 : growth)
        .animation(.spring(duration: Tokens.p2PotSpring), value: presentedPot)
    }

    private func miniTile(_ pool: Pool, dia: CGFloat) -> some View {
        let chips = game.chips(in: pool)
        return ZStack {
            if chips > 0 {
                RecessedTokenPile(count: chips,
                                  tint: theme.tint(pool),
                                  diameter: dia,
                                  showCount: false)
            } else {
                Circle()
                    .fill(theme.tint(pool).opacity(theme.isTravelTable ? 0.44 : 0.36))
                    .frame(width: 2.2, height: 2.2)
            }
        }
        .frame(width: dia, height: dia)
    }

    // MARK: - Gegner-Token

    private func token(seat: Int, width: CGFloat) -> some View {
        let s = game.bettingSeat(of: seat)
        let isTurn = game.turnIndex == seat && game.stage == .betting
        let reaction = actionPresentation(for: seat)
        let mood = moodPresentation(for: seat, isTurn: isTurn)
        return OpponentPanel(seat: seat,
                             name: game.name(of: seat),
                             stack: (s?.stack ?? 0) + (s?.committed ?? 0),
                             cards: game.displayedHand(of: seat).count,
                             actionText: reaction.text,
                             actionTint: reaction.tone,
                             isActive: s?.isActive ?? false,
                             isFocus: isTurn,
                             mood: mood,
                             width: width,
                             morph: morph)
    }

    /// Auftritt = Reaktion auf den öffentlichen Spielstand (§6b) - nie ein Hand-Leak.
    private func actionPresentation(for seat: Int) -> (text: String, tone: Color) {
        let s = game.bettingSeat(of: seat)
        switch game.seatActions[seat] {
        case .thinking: return ("überlegt …", Tokens.slate)
        case .passed: return ("passt", Tokens.slate)
        case .opened(let n): return ("pocht \(n)!", pochAccent)
        case .called: return ("geht mit", Tokens.jewelGold)
        case .raised(let n): return ("erhöht \(n)", pochAccent)
        case .none:
            let committed = s?.committed ?? 0
            return committed > 0 ? ("setzt \(committed)", Tokens.jewelGold) : ("bereit", Tokens.slate.opacity(0.62))
        }
    }

    private func moodPresentation(for seat: Int, isTurn: Bool) -> OpponentMood {
        if isTurn,
           transferPresentationActive,
           game.lastBetKind == .raise,
           game.lastBetActor != seat {
            return .surprised
        }
        switch game.seatActions[seat] {
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

    private func portraitsRow(maxPanelWidth: CGFloat) -> some View {
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
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
        }
    }

    // MARK: - Hand (identisch zu Phase 1: grosser Mockup-Faecher am unteren Rand)

    private var handFan: some View {
        let cards = game.humanHand
        let isHighlighted = game.stage == .betting
        let N = cards.count
        let cardScale: CGFloat = 1.62
        let spreadDeg = min(Double(N) * 7.0, 38.0)
        let totalW: CGFloat = min(CGFloat(N) * 30, 224)
        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                let t: CGFloat = N > 1 ? CGFloat(i) / CGFloat(N - 1) : 0.5
                let angle = N > 1 ? -spreadDeg / 2 + Double(t) * spreadDeg : 0.0
                let xOff: CGFloat = N > 1 ? -totalW / 2 + t * totalW : 0
                CardFace(card: card,
                         highlighted: isHighlighted && card.rank == game.humanComboRank,
                         scale: cardScale)
                    .offset(x: xOff)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .zIndex(Double(i))
            }
        }
        .frame(height: 74 * cardScale * 0.62)
    }

    // MARK: - Aktions-Buttons (2-spaltig)

    private var tensionBar: some View {
        let cap = game.capHolder.map { game.name(of: $0) } ?? "offen"
        let committed = game.humanCommitted
        return HStack(spacing: 8) {
            wagerMetric("EINSATZ", "\(presentedPot)", pochAccent)
            wagerMetric("MULDE", "+\(game.pochPool)", Tokens.jewelGold)
            wagerMetric("LIMIT", cap, Tokens.slate, muted: true)
            wagerMetric("DU", "\(committed)", Tokens.jewelSmaragd)
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
                .font(.system(size: 7, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(Tokens.slate.opacity(0.72))
                .lineLimit(1)
            Text(value)
                .font(.system(size: value.count > 5 ? 10 : 13, weight: .heavy))
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
                .font(.system(size: 6.7, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(Tokens.slate.opacity(0.66))
                .lineLimit(1)
            Text(value)
                .font(.system(size: value.count > 5 ? 9.2 : 12.6, weight: .heavy))
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
                actionButton("Passen", style: .quiet) { game.humanPass() }
            }
            if legal.canCall {
                actionButton(callCost > 0 ? "Mitgehen \(callCost)" : "Mitgehen",
                             style: .gold) { game.humanCall() }
            }
            if canRaise {
                actionButton("Erhöhen \(Int(bid))", style: .amethyst) {
                    if let raise = legal.raiseRange {
                        game.humanRaise(to: Int(bid).clamped(to: raise))
                    }
                }
            } else if canOpen {
                actionButton("Pochen \(Int(bid))", style: .amethyst) {
                    if let open = legal.openRange {
                        game.humanOpen(Int(bid).clamped(to: open))
                    }
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func wallLabel(_ range: ClosedRange<Int>) -> some View {
        let holder = game.capHolder
        let text: String = {
            guard let holder else { return "Limit \(range.upperBound)" }
            return holder == 0
                ? "Limit \(range.upperBound) · dein Konto deckelt"
                : "Limit \(range.upperBound) · \(game.name(of: holder)) kann nicht mehr mit"
        }()
        return Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Tokens.slate)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Ergebnis (Bietrunde vorbei; Phase 3 folgt als nächste Iteration)

    private var resultBanner: some View {
        VStack(spacing: 10) {
            if let r = game.pochResult {
                HStack(spacing: 10) {
                    R1Token(tint: pochAccent, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(game.name(of: r.winner)) nimmt den Poch")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Tokens.jewelPlatin)
                        Text(r.byShowdown ? "Showdown · \(r.pot + r.pochPool) Chips"
                                          : "Bluff bleibt verdeckt · \(r.pot + r.pochPool) Chips")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Tokens.slate)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 10) {
                    R1Token(tint: Tokens.jewelAmethyst, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Niemand pocht")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Tokens.jewelPlatin)
                        Text("\(game.pochPool) Chips bleiben in der Mulde")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Tokens.slate)
                    }
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 10) {
                actionButton("Neue Runde", style: .quiet) { onNewRound() }
                actionButton("Weiter · Ausspielen", style: .gold) { onContinue() }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Tokens.jewelGold.opacity(0.22), lineWidth: 1)))
        .padding(.top, 4)
    }

    // MARK: - Bausteine

    private enum ButtonTone { case quiet, gold, amethyst }

    private func actionButton(_ label: String, style: ButtonTone,
                              isEnabled: Bool = true,
                              action: @escaping () -> Void) -> some View {
        let foreground = actionForeground(style: style, isEnabled: isEnabled)
        let fill = actionFill(style: style, isEnabled: isEnabled)
        let stroke = actionStroke(style: style, isEnabled: isEnabled)
        return Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: actionSymbol(for: label, style: style))
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(foreground.opacity(isEnabled ? 0.92 : 0.48))
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(stroke.opacity(isEnabled ? 0.22 : 0.05)))
                Text(label)
                    .font(.system(size: 12.8, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(foreground)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
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

    private func actionSymbol(for label: String, style: ButtonTone) -> String {
        if label.hasPrefix("Passen") { return "xmark" }
        if label.hasPrefix("Mitgehen") { return "arrow.right" }
        if label.hasPrefix("Erhöhen") { return "chevron.up" }
        if label.hasPrefix("Pochen") { return "hand.tap.fill" }
        if label.hasPrefix("Weiter") { return "play.fill" }
        if label.hasPrefix("Neue") { return "arrow.clockwise" }
        switch style {
        case .quiet: return "circle"
        case .gold: return "checkmark"
        case .amethyst: return "hand.tap.fill"
        }
    }

    private func resetBid() {
        if let legal = game.humanLegal, let range = legal.openRange ?? legal.raiseRange {
            bid = Double(range.lowerBound)
        }
    }
}

private struct PochBetFlight: View {
    let seat: Int
    let amount: Int
    let kind: BetTransferKind
    let trigger: Int
    let tint: Color
    let onImpact: () -> Void

    @State private var landed = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let scale = Tokens.phase2BoardScale
            let ringDiameter = Tokens.ringRadius * 2 * scale + Tokens.tileDiameter * scale
            let topAreaHeight = Tokens.phase2StageHeight
            let target = CGPoint(x: w - ringDiameter / 2,
                                 y: topAreaHeight / 2 + 4)
            let origin = originPoint(seat: seat, w: w, h: h)
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
                            landed = true
                            onImpact()
                        }
                    ) { progress in
                        R1Token(tint: i == 0 ? Tokens.jewelGold : tint,
                                  size: kind.isPoch ? 22 : 21)
                            .rotationEffect(.degrees(Double(i - 1) * 2 + Double(progress) * 3))
                            .rotation3DEffect(.degrees(sin(Double(progress) * .pi) * 2.2),
                                              axis: (x: 0.82, y: 0.18, z: 0),
                                              perspective: 0.22)
                            .scaleEffect(1 + sin(progress * .pi) * 0.018)
                            .shadow(color: .black.opacity(0.64),
                                    radius: progress > 0.84 ? 3 : 7,
                                    y: progress > 0.84 ? 2 : 5)
                    }
                    .opacity(landed ? 0 : 1)
                    .id("poch-chip-\(trigger)-\(i)")
                }
            }
        }
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
    }
}


extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
