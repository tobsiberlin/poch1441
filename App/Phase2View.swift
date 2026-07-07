import PochKit
import SwiftUI

/// Phase 2 (Pochen) - der psychologische Kern (§6b) im Kompressions-Layout (§5b, Akt 2):
/// Gegner rücken als Kardinalpunkt-Tokens nah (§5c, Platzhalter bis Charakterstil-Urteil),
/// der violette Poch-Pott ist der Held im Zentrum, der entsättigte Ring tritt als Echo
/// zurück. Unten: Hand (Kunststück leuchtet) + Biet-Slider mit personifizierter Limit-Wand.
struct Phase2View: View {
    let game: GameState
    let theme: Theme
    let onNewRound: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bid = 1.0
    /// Zählt Poch-Schläge des Spielers für die .heavy-Haptik (§6b Signaturgeste;
    /// Tischschlag-Animation folgt im Game-Feel-Pass unter Parameter-Lock).
    @State private var pochBeat = 0

    var body: some View {
        VStack(spacing: 0) {
            duelArea
            Spacer(minLength: 6)
            handView
            controls
                .frame(minHeight: 148, alignment: .top)
                .padding(.top, 12)
        }
        .onAppear(perform: resetBid)
        .onChange(of: game.turnIndex) { resetBid() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: pochBeat)
    }

    // MARK: - Duell-Bühne (Kardinalpunkte um den Poch-Pott)

    private var duelArea: some View {
        ZStack {
            ringEcho
            pochPot
            token(seat: 2).offset(y: -132)
            token(seat: 1).offset(x: -122, y: -26)
            token(seat: 3).offset(x: 122, y: -26)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 372)
    }

    /// §5b Akt 2: die 8 Mulden entsättigen zu Schiefer und weichen zurück - hier als
    /// ruhiges Echo, der volle Morph kommt mit .matchedGeometryEffect.
    private var ringEcho: some View {
        ZStack {
            Circle().strokeBorder(Tokens.slate.opacity(0.10), lineWidth: 1)
                .frame(width: Tokens.ringRadius * 1.7, height: Tokens.ringRadius * 1.7)
            ForEach(PochRing.anchors) { anchor in
                Circle().fill(Tokens.slate.opacity(anchor.pool == .poch ? 0 : 0.16))
                    .frame(width: 9, height: 9)
                    .offset(CGSize(width: anchor.offset.width * 0.85,
                                   height: anchor.offset.height * 0.85))
            }
        }
        .offset(y: 8)
    }

    /// Der violette Poch-Pott - der Preis und Anker von Phase 2 (§5b: wird promotet,
    /// während der Ring zurücktritt). Wächst sichtbar mit den Einsätzen.
    private var pochPot: some View {
        let growth = 1 + CGFloat(min(game.pot, 40)) / 400
        return VStack(spacing: 1) {
            Text("POCH-POTT").font(.system(size: 9, weight: .semibold)).tracking(1.5)
                .foregroundStyle(Tokens.amethystVivid.opacity(0.85))
            Text("\(game.pot)").font(.system(size: 34, weight: .bold))
                .foregroundStyle(Tokens.jewelPlatin)
                .contentTransition(.numericText())
            Text("+ Mulde \(game.pochPool)").font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.amethystVivid.opacity(0.75))
        }
        .frame(width: 128, height: 128)
        .background(
            Circle()
                .fill(LinearGradient(colors: [Tokens.jewelAmethyst.opacity(0.55),
                                              Tokens.jewelAmethyst.opacity(0.22)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(
                    LinearGradient(colors: [Tokens.amethystVivid.opacity(theme.isNeon ? 1 : 0.8),
                                            Tokens.amethystVivid.opacity(0.35)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: theme.borderWidth))
                .shadow(color: Tokens.amethystVivid.opacity(theme.isNeon ? 0.6 : 0.25),
                        radius: theme.isNeon ? 26 : 12)
        )
        .scaleEffect(reduceMotion ? 1 : growth)
        .animation(.spring(duration: Tokens.p2PotSpring), value: game.pot)
        .offset(y: 26)
    }

    // MARK: - Gegner-Token (Platzhalter-Vektor bis Charakterstil entschieden)

    private func token(seat: Int) -> some View {
        let s = game.betting.seats[seat]
        let isTurn = game.turnIndex == seat && game.stage == .betting
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.07))
                    .overlay(Circle().strokeBorder(
                        isTurn ? Tokens.amethystVivid : Tokens.jewelGold.opacity(0.35),
                        lineWidth: isTurn ? 2 : 1))
                Text(String(game.name(of: seat).prefix(1)))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin)
            }
            .frame(width: 62, height: 62)
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

    // MARK: - Hand (§6b: dein Kunststück leuchtet - nur deine Hand, kein Gegner-Leak)

    private var handView: some View {
        HStack(spacing: -14) {
            ForEach(Array(game.humanHand.enumerated()), id: \.offset) { _, card in
                CardFace(card: card, highlighted: card.rank == game.humanComboRank
                         && game.stage == .betting)
            }
        }
    }

    // MARK: - Biet-Steuerung

    @ViewBuilder private var controls: some View {
        if game.stage != .betting {
            resultBanner
        } else if game.turnIndex == 0, let legal = game.humanLegal {
            humanControls(legal)
        } else {
            waitHint
        }
    }

    private var waitHint: some View {
        Text("\(game.name(of: game.turnIndex)) überlegt …")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Tokens.slate)
            .padding(.top, 26)
    }

    @ViewBuilder private func humanControls(_ legal: BettingPhase.LegalActions) -> some View {
        let sliderRange = legal.openRange ?? legal.raiseRange
        VStack(spacing: 10) {
            if let range = sliderRange {
                bidSlider(range)
            } else if legal.canPass && !legal.canCall {
                Text("Ohne Kunststück kein Gebot - du kannst nur passen.")
                    .font(.system(size: 12)).foregroundStyle(Tokens.slate)
            }
            HStack(spacing: 10) {
                actionButton("Passen", style: .quiet) { game.humanPass() }
                if legal.canCall {
                    let cost = game.betting.currentBet - game.betting.seats[0].committed
                    actionButton("Mitgehen · \(cost)", style: .gold) { game.humanCall() }
                }
                if let open = legal.openRange {
                    actionButton("Pochen \(Int(bid))!", style: .amethyst) {
                        pochBeat += 1
                        game.humanOpen(Int(bid).clamped(to: open))
                    }
                } else if let raise = legal.raiseRange {
                    actionButton("Erhöhen auf \(Int(bid))", style: .amethyst) {
                        pochBeat += 1
                        game.humanRaise(to: Int(bid).clamped(to: raise))
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    /// Slider bis zur HARTEN Decke: die Wand am Spurende gehört dem knappsten Spieler
    /// und ist mit ihm beschriftet (§6b) - transparent statt Rätsel.
    private func bidSlider(_ range: ClosedRange<Int>) -> some View {
        let atWall = Int(bid) >= range.upperBound
        return VStack(spacing: 5) {
            HStack(spacing: 10) {
                Text("\(Int(bid))")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Tokens.amethystVivid)
                    .frame(minWidth: 34)
                    .contentTransition(.numericText())
                Slider(value: $bid,
                       in: Double(range.lowerBound)...Double(range.upperBound),
                       step: 1)
                    .tint(Tokens.amethystVivid)
                    .disabled(range.lowerBound == range.upperBound)
                RoundedRectangle(cornerRadius: 2)
                    .fill(atWall ? Tokens.jewelGold : Tokens.slate.opacity(0.7))
                    .frame(width: 4, height: 30)
            }
            wallLabel(range)
        }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: atWall)
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
                actionButton("Neue Runde", style: .gold) { onNewRound() }
            }
            Text("Phase 3 (Ausspielen) folgt als nächste Iteration")
                .font(.system(size: 10)).foregroundStyle(Tokens.slate.opacity(0.7))
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
