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
    let onContinue: () -> Void
    let onNewRound: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bid = 1.0

    var body: some View {
        VStack(spacing: 0) {
            topArea
                .modifier(TableShake(
                    amplitude: reduceMotion ? 0 : Tokens.pochShakeAmp,
                    animatableData: CGFloat(game.pochShock)))
                .animation(.linear(duration: Tokens.pochShake), value: game.pochShock)
            Spacer(minLength: 8)
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
                RoundedRectangle(cornerRadius: 6)
                    .fill(.black.opacity(0.28))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 1))
                    .frame(width: 30, height: 150)
                if let range = sliderRange {
                    Slider(value: $bid,
                           in: Double(range.lowerBound)...Double(range.upperBound),
                           step: 1)
                        .tint(Tokens.amethystVivid)
                        .frame(width: 150)
                        .rotationEffect(.degrees(-90))
                        .disabled(!isActive)
                }
            }
            .sensoryFeedback(.impact(flexibility: .rigid), trigger: atWall)

            Text("\(Int(bid))")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(isActive ? Tokens.amethystVivid : Tokens.slate.opacity(0.3))
                .contentTransition(.numericText())
                .frame(minWidth: 48)

            chipStack(count: Int(bid))

            if let range = sliderRange {
                // Wand-Indikator: glüht gold am Anschlag (§6b)
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        colors: [Tokens.jewelPlatin.opacity(atWall ? 0.9 : 0.5),
                                 Color(hex: 0x39353F)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 22, height: 6)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(
                        atWall ? Tokens.goldVivid.opacity(0.9) : Tokens.slate.opacity(0.3),
                        lineWidth: 1))
                    .shadow(color: atWall ? Tokens.goldVivid.opacity(0.4) : .clear, radius: 4)
                wallLabel(range)
            }
        }
        .opacity(isActive ? 1 : 0.45)
        .animation(.easeOut(duration: 0.2), value: isActive)
        .frame(width: 90)
    }

    /// Kompakter Poch-Ring rechts: miniaturisierte Mulden mit Chip-Werten (§5b Morph-Anker).
    private var compactRing: some View {
        let scale: CGFloat = 0.40
        let r = Tokens.ringRadius * scale
        let tileDia = Tokens.tileDiameter * scale
        let d = r * 2 + tileDia
        return ZStack {
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Tokens.jewelAmethyst.opacity(0.28),
                                 Tokens.jewelAmethyst.opacity(0.08)],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75)
                .frame(width: r * 2, height: r * 2)
                .position(x: d / 2, y: d / 2)
            pochPotMini.position(x: d / 2, y: d / 2)
            ForEach(PochRing.anchors.filter { $0.pool != .poch }) { anchor in
                miniTile(anchor.pool, dia: tileDia)
                    .matchedGeometryEffect(id: "tile-\(anchor.pool.rawValue)", in: morph)
                    .position(x: d / 2 + anchor.offset.width * scale,
                              y: d / 2 + anchor.offset.height * scale)
            }
        }
        .frame(width: d, height: d)
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
        let tint = theme.tint(pool)
        let label = pool.indexLabel
        return VStack(spacing: 0) {
            Text(label).font(.system(size: label.count > 2 ? 6 : 9, weight: .bold))
            Text("\(game.chips(in: pool))").font(.system(size: 8, weight: .semibold))
                .contentTransition(.numericText())
        }
        .foregroundStyle(tint)
        .frame(width: dia, height: dia)
        .background(
            RoundedRectangle(cornerRadius: Tokens.tileCorner * 0.4)
                .fill(.black.opacity(theme.tileFillOpacity))
                .overlay(RoundedRectangle(cornerRadius: Tokens.tileCorner * 0.4)
                    .strokeBorder(
                        LinearGradient(
                            colors: [tint.opacity(theme.isNeon ? 1 : 0.85), tint.opacity(0.3)],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.5))
        )
    }

    // MARK: - Gegner-Token (Platzhalter-Vektor bis Charakterstil entschieden)

    private func token(seat: Int) -> some View {
        let s = game.betting.seats[seat]
        let isTurn = game.turnIndex == seat && game.stage == .betting
        return VStack(spacing: 4) {
            ZStack {
                // Verdeckte Hand als Mini-Fächer (§6b Bluff-Sprache) - lugt hinter dem
                // Token hervor. Kontaktschatten = Render-Eigenschaft (Fächer-Wette 8.7.),
                // nie ins Asset eingebacken.
                ForEach(-1...1, id: \.self) { i in
                    CardBack(scale: 0.42)
                        .rotationEffect(.degrees(Double(i) * 14), anchor: .bottom)
                        .offset(x: CGFloat(i) * 7, y: -30)
                        .shadow(color: .black.opacity(0.45), radius: 3, x: -2, y: 2)
                }
                Circle()
                    .fill(Color(hex: 0x201D24))
                    .overlay(Circle().strokeBorder(
                        isTurn ? Tokens.amethystVivid : Tokens.jewelGold.opacity(0.35),
                        lineWidth: isTurn ? 2 : 1))
                Text(String(game.name(of: seat).prefix(1)))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin)
            }
            .frame(width: 62, height: 62)
            .matchedGeometryEffect(id: "token\(seat)", in: morph)
            .scaleEffect(isTurn && !reduceMotion ? 1.07 : 1)
            .animation(.easeInOut(duration: 0.28), value: isTurn)

            Text(game.name(of: seat)).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.9))
            Text("\(s.stack)").font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.jewelGold.opacity(0.9))
            bubble(for: seat)
        }
        .opacity(s.isActive ? 1 : 0.38)
        .saturation(s.isActive ? 1 : 0.1)
        .animation(.easeInOut(duration: 0.3), value: s.isActive)
    }

    /// Auftritt = Reaktion auf den öffentlichen Spielstand (§6b) - nie ein Hand-Leak.
    private func bubble(for seat: Int) -> some View {
        let s = game.betting.seats[seat]
        let (text, tone): (String, Color) = {
            switch game.seatActions[seat] {
            case .thinking: return ("überlegt …", Tokens.slate)
            case .passed: return ("passt", Tokens.slate)
            case .opened(let n): return ("pocht \(n)!", Tokens.amethystVivid)
            case .called: return ("geht mit", Tokens.jewelGold)
            case .raised(let n): return ("erhöht auf \(n)", Tokens.amethystVivid)
            case .none:
                return s.committed > 0 ? ("setzt \(s.committed)", Tokens.jewelGold) : (" ", .clear)
            }
        }()
        return Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tone == .clear ? .clear : Tokens.jewelPlatin.opacity(0.95))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(tone.opacity(tone == .clear ? 0 : 0.28)))
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
        .padding(.horizontal, 4)
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
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton("Passen", style: .quiet) { game.humanPass() }
                if legal.canCall {
                    let cost = game.betting.currentBet - game.betting.seats[0].committed
                    actionButton("Mitgehen · \(cost)", style: .gold) { game.humanCall() }
                }
            }
            if let open = legal.openRange {
                actionButton("Pochen \(Int(bid))!", style: .amethyst) {
                    game.humanOpen(Int(bid).clamped(to: open))
                }
            } else if let raise = legal.raiseRange {
                actionButton("Erhöhen auf \(Int(bid))", style: .amethyst) {
                    game.humanRaise(to: Int(bid).clamped(to: raise))
                }
            }
            if legal.canPass && !legal.canCall && legal.openRange == nil {
                Text("Ohne Kunststück kein Gebot - du kannst nur passen.")
                    .font(.system(size: 12)).foregroundStyle(Tokens.slate)
            }
        }
        .padding(.horizontal, 4)
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
        VStack(spacing: 8) {
            if let r = game.pochResult {
                Text("Der Poch-Pott geht an \(game.name(of: r.winner))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin)
                Text(r.byShowdown
                     ? "\(r.pot) Einsatz + \(r.pochPool) Mulde · per Showdown"
                     : "\(r.pot) Einsatz + \(r.pochPool) Mulde · ohne Aufdecken - der Bluff bleibt geheim")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.slate)
                    .multilineTextAlignment(.center)
            } else {
                Text("Alle passen - die Poch-Mulde bleibt stehen")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin)
                Text("\(game.pochPool) Chips warten hier nächste Runde")
                    .font(.system(size: 12)).foregroundStyle(Tokens.slate)
            }
            HStack(spacing: 10) {
                actionButton("Neue Runde", style: .quiet) { onNewRound() }
                actionButton("Weiter · Ausspielen", style: .gold) { onContinue() }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Bausteine

    private enum ButtonTone { case quiet, gold, amethyst }

    private func actionButton(_ label: String, style: ButtonTone,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(style == .quiet ? Tokens.slate : Tokens.jewelPlatin)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(
                    Capsule().fill(style == .amethyst
                                   ? Tokens.jewelAmethyst.opacity(0.65)
                                   : Color.white.opacity(0.05))
                        .overlay(Capsule().strokeBorder(
                            style == .amethyst ? Tokens.amethystVivid.opacity(0.8)
                            : style == .gold ? Tokens.jewelGold.opacity(0.6)
                            : Tokens.slate.opacity(0.4),
                            lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    /// Chip-Stapel in der Bietzone: wächst mit dem Gebot (max. 9 sichtbar).
    private func chipStack(count: Int) -> some View {
        let shown = min(max(count, 1), 9)
        return ZStack(alignment: .bottom) {
            ForEach(0..<shown, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: [Tokens.amethystVivid.opacity(0.85),
                                                  Tokens.jewelAmethyst],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                    .frame(width: 20, height: 6)
                    .offset(y: CGFloat(-i) * 4)
            }
        }
        .frame(width: 22, height: 44, alignment: .bottom)
        .animation(.spring(duration: 0.2), value: shown)
    }

    private func resetBid() {
        if let legal = game.humanLegal, let range = legal.openRange ?? legal.raiseRange {
            bid = Double(range.lowerBound)
        }
    }
}


extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
