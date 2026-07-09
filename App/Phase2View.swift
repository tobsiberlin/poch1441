import PochKit
import SwiftUI

/// Phase 2 (Pochen) - der psychologische Kern (§6b) im Kompressions-Layout (§5b, Akt 2):
/// Gegner rücken als Kardinalpunkt-Tokens nah (§5c, Platzhalter bis Charakterstil-Urteil),
/// der violette Poch-Pott ist der Held im Zentrum, der entsättigte Ring tritt als Echo
/// zurück. Unten: Hand (Kunststück leuchtet) + Biet-Slider mit personifizierter Limit-Wand.
struct Phase2View: View {
    let game: GameState
    let theme: Theme
    /// Phasen-Morph-Namespace (§5b) - geteilt mit ContentView/Phase3View.
    let morph: Namespace.ID
    let assistHints: Bool
    let onContinue: () -> Void
    let onNewRound: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bid = 1.0
    #if DEBUG
    @State private var qaPochFlight = 0
    #endif

    var body: some View {
        VStack(spacing: 0) {
            topArea
                .modifier(TableShake(
                    amplitude: reduceMotion ? 0 : Tokens.pochShakeAmp,
                    animatableData: CGFloat(game.pochShock)))
                .animation(.linear(duration: Tokens.pochShake), value: game.pochShock)
            Spacer(minLength: 3)
            pochenStatusLine
            Spacer(minLength: 5)
            tensionBar
            Spacer(minLength: 7)
            actionArea
                .frame(minHeight: 90, alignment: .top)
            Spacer(minLength: 8)
            portraitsRow
            Spacer(minLength: 6)
            handFan
        }
        .onAppear(perform: resetBid)
        .onChange(of: game.turnIndex) { resetBid() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.pochShock)
        .overlay {
            if game.pochShock > 0, !reduceMotion {
                PochBetFlight(seat: game.turnIndex,
                              trigger: game.pochShock,
                              tint: Tokens.jewelAmethyst)
                    .allowsHitTesting(false)
            }
            #if DEBUG
            if qaPochFlight > 0, !reduceMotion {
                PochBetFlight(seat: 0,
                              trigger: qaPochFlight,
                              tint: Tokens.jewelAmethyst)
                    .allowsHitTesting(false)
            }
            #endif
        }
        #if DEBUG
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-pochFlightQA") else { return }
            try? await Task.sleep(for: .milliseconds(650))
            for _ in 0..<7 {
                qaPochFlight += 1
                try? await Task.sleep(for: .milliseconds(520))
            }
        }
        #endif
    }

    private var pochenHint: String {
        if game.stage != .betting {
            return "Der Poch ist entschieden. Danach startet der Kartenstrom."
        }
        if game.turnIndex == 0 {
            return game.humanComboRank == nil
                ? "Kein Paar: du kannst passen und Kraft fürs Ausspielen behalten."
                : "Du hast ein Paar. Biete nur so hoch, wie die Wand es erlaubt."
        }
        return "\(game.name(of: game.turnIndex)) entscheidet. Der Pott zeigt den Druck."
    }

    /// Kompakter Mockup-Status statt grosser Coach-Box: Phase 2 soll wie ein
    /// Tischmoment wirken, nicht wie ein Tutorial-Screen.
    private var pochenStatusLine: some View {
        let status = pochenStatus
        return HStack(spacing: 8) {
            Circle()
                .fill(status.tint.opacity(0.86))
                .frame(width: 7, height: 7)
                .shadow(color: status.tint.opacity(theme.isNeon ? 0.36 : 0.18), radius: 4)
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
        if game.stage != .betting {
            if let result = game.pochResult {
                return (game.name(of: result.winner).uppercased(), "NIMMT DEN POCH", Tokens.jewelGold)
            }
            return ("KEIN POCH", "MULDE BLEIBT", Tokens.slate)
        }
        if game.turnIndex == 0 {
            return game.humanComboRank == nil
                ? ("PASSEN", "KEIN PAAR", Tokens.slate)
                : ("DEIN ZUG", "PAAR DRÜCKT", Tokens.amethystVivid)
        }
        let action = actionPresentation(for: game.turnIndex)
        return (action.text.uppercased(), game.name(of: game.turnIndex).uppercased(), action.tone)
    }

    // MARK: - Slider LINKS / Ring RECHTS (Mockup-Delta Phase 2)

    private var topArea: some View {
        HStack(alignment: .center, spacing: 0) {
            sliderPanel
            Spacer()
            compactRing
        }
        .frame(maxHeight: 230)
        .padding(.top, 8)
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
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(isActive ? Tokens.amethystVivid : Tokens.slate.opacity(0.3))
                .contentTransition(.numericText())
                .frame(minWidth: 48)
        }
        .opacity(isActive ? 1 : 0.45)
        .animation(.easeOut(duration: 0.2), value: isActive)
        .frame(width: 90)
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
                        Tokens.amethystVivid.opacity(isActive ? 0.92 : 0.38),
                        Tokens.jewelAmethyst.opacity(isActive ? 0.76 : 0.28)
                    ], startPoint: .top, endPoint: .bottom))
                    .frame(width: 20, height: max(6, CGFloat(progress) * h - 9))
                    .padding(.bottom, 5)
                    .shadow(color: Tokens.amethystVivid.opacity(isActive ? 0.24 : 0), radius: 7)

                Capsule()
                    .fill(LinearGradient(colors: [
                        Tokens.jewelPlatin.opacity(0.96),
                        Tokens.jewelGold.opacity(0.92),
                        Color(hex: 0x7B4F35)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Capsule().strokeBorder(Color.black.opacity(0.44), lineWidth: 1))
                    .overlay(Capsule().strokeBorder(Tokens.jewelPlatin.opacity(0.32), lineWidth: 0.7).padding(2))
                    .frame(width: 52, height: 28)
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
        .frame(width: 56, height: 150)
    }

    /// Kompakter Poch-Ring rechts: miniaturisierte Mulden mit Chip-Werten (§5b Morph-Anker).
    private var compactRing: some View {
        let scale: CGFloat = 0.52
        let r = Tokens.ringRadius * scale
        let tileDia = Tokens.tileDiameter * scale
        let d = r * 2 + tileDia
        let overlayRadius = d * 0.33
        return ZStack {
            Image("PochRingPM49")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: d, height: d)
                .clipShape(Circle())
                .opacity(theme.isNeon ? 0.96 : 0.88)
                .shadow(color: .black.opacity(0.62), radius: 10, y: 6)
                .position(x: d / 2, y: d / 2)
            pochPotMini.position(x: d / 2, y: d / 2)
            ForEach(PochRing.anchors.filter { $0.pool != .poch }) { anchor in
                miniTile(anchor.pool, dia: tileDia)
                    .matchedGeometryEffect(id: "tile-\(anchor.pool.rawValue)", in: morph)
                    .position(x: d / 2 + pm49Offset(anchor.angle, radius: overlayRadius).width,
                              y: d / 2 + pm49Offset(anchor.angle, radius: overlayRadius).height)
            }
        }
        .frame(width: d, height: d)
    }

    private func pm49Offset(_ angle: Double, radius: CGFloat) -> CGSize {
        let rad = angle * .pi / 180
        return CGSize(width: radius * sin(rad), height: -radius * cos(rad))
    }

    /// §5b Signatur-Flug: P1-Poch-Mulde löst sich und wird zum Pott im Ring-Zentrum.
    private var pochPotMini: some View {
        let growth = 1 + CGFloat(min(game.pot, 40)) / 400
        return VStack(spacing: 0) {
            Text("POCH").font(.system(size: 7, weight: .semibold)).tracking(1)
                .foregroundStyle(Tokens.amethystVivid.opacity(0.8))
            Text("\(game.pot)").font(.system(size: 18, weight: .bold))
                .foregroundStyle(Tokens.jewelPlatin)
                .contentTransition(.numericText())
            Text("+ \(game.pochPool)").font(.system(size: 7))
                .foregroundStyle(Tokens.amethystVivid.opacity(0.65))
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
                        colors: [Tokens.amethystVivid.opacity(theme.isNeon ? 1 : 0.72),
                                 Tokens.amethystVivid.opacity(0.3)],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75))
                .shadow(color: Tokens.amethystVivid.opacity(theme.isNeon ? 0.5 : 0.12), radius: 5)
        )
        .matchedGeometryEffect(id: "pochPot", in: morph)
        .scaleEffect(reduceMotion ? 1 : growth)
        .animation(.spring(duration: Tokens.p2PotSpring), value: game.pot)
    }

    private func miniTile(_ pool: Pool, dia: CGFloat) -> some View {
        let chips = game.chips(in: pool)
        return ZStack {
            if chips > 0 {
                TableChip(tint: theme.tint(pool), size: max(6, dia * 0.28))
                    .offset(y: -dia * 0.05)
                Text("+\(chips)")
                    .font(.system(size: max(6, dia * 0.24), weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .shadow(color: .black.opacity(0.9), radius: 1, y: 1)
                    .offset(y: dia * 0.32)
            } else {
                Text(pool.indexLabel)
                    .font(.system(size: pool.indexLabel.count > 2 ? max(4, dia * 0.18) : max(6, dia * 0.28),
                                  weight: .heavy))
                    .foregroundStyle(theme.tint(pool).opacity(0.82))
                    .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
            }
        }
        .frame(width: dia, height: dia)
    }

    // MARK: - Gegner-Token (Platzhalter-Vektor bis Charakterstil entschieden)

    private func token(seat: Int) -> some View {
        let s = game.betting.seats[seat]
        let isTurn = game.turnIndex == seat && game.stage == .betting
        let reaction = actionPresentation(for: seat)
        return OpponentPanel(seat: seat,
                             name: game.name(of: seat),
                             stack: s.stack + s.committed,
                             cards: game.displayedHand(of: seat).count,
                             actionText: reaction.text,
                             actionTint: reaction.tone,
                             isActive: s.isActive,
                             isFocus: isTurn,
                             width: 106,
                             morph: morph)
    }

    /// Auftritt = Reaktion auf den öffentlichen Spielstand (§6b) - nie ein Hand-Leak.
    private func actionPresentation(for seat: Int) -> (text: String, tone: Color) {
        let s = game.betting.seats[seat]
        switch game.seatActions[seat] {
        case .thinking: return ("überlegt …", Tokens.slate)
        case .passed: return ("passt", Tokens.slate)
        case .opened(let n): return ("pocht \(n)!", Tokens.amethystVivid)
        case .called: return ("geht mit", Tokens.jewelGold)
        case .raised(let n): return ("erhöht \(n)", Tokens.amethystVivid)
        case .none:
            return s.committed > 0 ? ("setzt \(s.committed)", Tokens.jewelGold) : ("bereit", Tokens.slate.opacity(0.62))
        }
    }

    // MARK: - Gegner-Portraits UNTEN (§5c Akt 2)

    private var portraitsRow: some View {
        HStack(spacing: 0) {
            token(seat: 1)
            Spacer()
            token(seat: 2)
            Spacer()
            token(seat: 3)
        }
        .padding(.horizontal, 1)
    }

    // MARK: - Hand (§6b: dein Kunststück leuchtet, kleiner Fächer ganz unten)

    private var handFan: some View {
        let cards = game.humanHand
        let isHighlighted = game.stage == .betting
        let N = cards.count
        let cardScale: CGFloat = 1.0
        let spreadDeg = min(Double(N) * 6.5, 32.0)
        let totalW: CGFloat = min(CGFloat(N) * 28, 180)
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
        .frame(height: 74 * cardScale * 0.60)
    }

    // MARK: - Aktions-Buttons (2-spaltig)

    private var tensionBar: some View {
        let cap = game.capHolder.map { game.name(of: $0) } ?? "offen"
        let committed = game.betting.seats.indices.contains(0) ? game.betting.seats[0].committed : 0
        return HStack(spacing: 8) {
            wagerMetric("POTT", "\(game.pot)", Tokens.amethystVivid)
            wagerMetric("MULDE", "+\(game.pochPool)", Tokens.jewelGold)
            wagerMetric("LIMIT", cap, Tokens.slate, muted: true)
            wagerMetric("DU", "\(committed)", Tokens.jewelSmaragd)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
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
        Text("\(game.name(of: game.turnIndex)) überlegt …")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Tokens.slate)
            .padding(.top, 20)
    }

    @ViewBuilder private func humanActionButtons(_ legal: BettingPhase.LegalActions) -> some View {
        let callCost = max(0, game.betting.currentBet - game.betting.seats[0].committed)
        let canOpen = legal.openRange != nil
        let canRaise = legal.raiseRange != nil
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                actionButton("Passen",
                             style: .quiet,
                             isEnabled: legal.canPass) { game.humanPass() }
                actionButton(callCost > 0 ? "Mitgehen \(callCost)" : "Mitgehen",
                             style: .gold,
                             isEnabled: legal.canCall) { game.humanCall() }
            }
            HStack(spacing: 8) {
                actionButton("Pochen \(Int(bid))",
                             style: .amethyst,
                             isEnabled: canOpen) {
                    if let open = legal.openRange {
                        game.humanOpen(Int(bid).clamped(to: open))
                    }
                }
                actionButton("Erhöhen \(Int(bid))",
                             style: .amethyst,
                             isEnabled: canRaise) {
                    if let raise = legal.raiseRange {
                        game.humanRaise(to: Int(bid).clamped(to: raise))
                    }
                }
            }
            if legal.canPass && !legal.canCall && !canOpen && !canRaise {
                Text("Kein Paar: passen ist hier korrekt.")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Tokens.slate.opacity(0.82))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 3)
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
                    TableChip(tint: Tokens.amethystVivid, size: 28)
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
                    TableChip(tint: Tokens.jewelAmethyst, size: 28)
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
            Text(label)
                .font(.system(size: 13.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(fill)
                        .overlay(Capsule().strokeBorder(stroke, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.72)
    }

    private func actionForeground(style: ButtonTone, isEnabled: Bool) -> Color {
        guard isEnabled else { return Tokens.slate.opacity(0.46) }
        return style == .quiet ? Tokens.slate : Tokens.jewelPlatin
    }

    private func actionFill(style: ButtonTone, isEnabled: Bool) -> Color {
        if isEnabled && style == .amethyst {
            return Tokens.jewelAmethyst.opacity(0.65)
        }
        return Color.white.opacity(isEnabled ? 0.05 : 0.028)
    }

    private func actionStroke(style: ButtonTone, isEnabled: Bool) -> Color {
        guard isEnabled else { return Tokens.slate.opacity(0.20) }
        switch style {
        case .amethyst: return Tokens.amethystVivid.opacity(0.8)
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

private struct PochBetFlight: View {
    let seat: Int
    let trigger: Int
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let target = CGPoint(x: w * 0.74, y: h * 0.185)
            let origin = originPoint(seat: seat, w: w, h: h)
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    PochFlyingChip(from: origin,
                                   to: target,
                                   tint: i == 0 ? Tokens.jewelGold : tint,
                                   index: i,
                                   trigger: trigger)
                }
                PochImpactRing(at: target, tint: tint, trigger: trigger)
                    .id("poch-impact-\(trigger)")
            }
        }
    }

    private func originPoint(seat: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        switch seat {
        case 1: return CGPoint(x: w * 0.18, y: h * 0.78)
        case 2: return CGPoint(x: w * 0.50, y: h * 0.78)
        case 3: return CGPoint(x: w * 0.82, y: h * 0.78)
        default: return CGPoint(x: w * 0.50, y: h * 0.94)
        }
    }
}

private struct PochFlyingChip: View {
    let from: CGPoint
    let to: CGPoint
    let tint: Color
    let index: Int
    let trigger: Int
    @State private var progress: CGFloat = 0

    var body: some View {
        let p = point(progress)
        TableChip(tint: tint, size: 15)
            .rotation3DEffect(.degrees(Double(progress) * 390 + Double(index) * 25),
                              axis: (x: 0.35, y: 0.85, z: 0.12))
            .scaleEffect(1.08 - progress * 0.22)
            .position(p)
            .opacity(progress > 0.995 ? 0.22 : 1)
            .shadow(color: .black.opacity(0.44), radius: 5, y: 2.4)
            .shadow(color: tint.opacity(0.12), radius: 4)
            .onAppear {
                withAnimation(.easeInOut(duration: Tokens.p2PochFlight).delay(Double(index) * 0.04)) {
                    progress = 1
                }
            }
            .id("poch-chip-\(trigger)-\(index)")
    }

    private func point(_ t: CGFloat) -> CGPoint {
        let inv = 1 - t
        let control = CGPoint(x: (from.x + to.x) / 2 + CGFloat(index - 2) * 12,
                              y: min(from.y, to.y) - 84 - CGFloat(index % 2) * 18)
        return CGPoint(
            x: inv * inv * from.x + 2 * inv * t * control.x + t * t * to.x,
            y: inv * inv * from.y + 2 * inv * t * control.y + t * t * to.y
        )
    }
}

private struct PochImpactRing: View {
    let at: CGPoint
    let tint: Color
    let trigger: Int
    @State private var fired = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [
                        Tokens.jewelGold.opacity(fired ? 0 : 0.72),
                        tint.opacity(fired ? 0 : 0.42)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: fired ? 0.8 : 2.8)
                .frame(width: fired ? 46 : 16, height: fired ? 46 : 16)
            Circle()
                .fill(Color.black.opacity(fired ? 0 : 0.34))
                .overlay(Circle().strokeBorder(Tokens.jewelPlatin.opacity(fired ? 0 : 0.26), lineWidth: 0.9))
                .frame(width: fired ? 17 : 25, height: fired ? 17 : 25)
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * 45 * .pi / 180
                Capsule()
                    .fill(i % 2 == 0 ? Tokens.jewelGold.opacity(0.82) : tint.opacity(0.74))
                    .frame(width: 2.2, height: 6.8)
                    .rotationEffect(.radians(angle + .pi / 2))
                    .offset(x: (fired ? 24 : 10) * cos(angle),
                            y: (fired ? 24 : 10) * sin(angle))
                    .opacity(fired ? 0 : 0.92)
                    .animation(.easeOut(duration: 0.38).delay(Double(i) * 0.012), value: fired)
            }
        }
        .position(at)
        .opacity(fired ? 0 : 1)
        .onAppear {
            fired = false
            withAnimation(.easeOut(duration: 0.38).delay(Tokens.p2PochImpactDelay)) {
                fired = true
            }
        }
        .id("poch-impact-\(trigger)")
    }
}


extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
