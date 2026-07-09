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
    let onNewRound: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            opponentsRow
            centerpotRow
            playedCardsFan
            Spacer(minLength: 10)
            if game.stage == .playout {
                statusLine
                handFan
            } else if game.endPhase < .done {
                settlementStatus
            } else {
                resultBanner
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        // Straf-Strom (§6c c): Chips fliegen PARALLEL von jedem Verlierer zum Sieger
        .overlay {
            if game.endPhase == .punishing, let result = game.roundResult, !reduceMotion {
                PunishStreams(result: result)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if game.endPhase == .punishing, let result = game.roundResult, !reduceMotion {
                CenterPotRelease(result: result)
                    .allowsHitTesting(false)
            }
        }
        // Rundenende-Juice skaliert mit dem Pott (§6c Auflage 1): Platin-Vignette
        // nur beim genuin fetten Centerpot, nie als Dauer-Ritual
        .overlay {
            if game.endPhase == .punishing, let result = game.roundResult,
               result.centerPool + result.payments.reduce(0, +)
                   >= Tokens.jackpotKollapsThreshold {
                KollapsVignette(tint: Tokens.jewelPlatin,
                                duration: reduceMotion ? 0.05 : Tokens.kollapsFlash)
                    .allowsHitTesting(false)
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Gegner als ruhiger Rahmen (§5c Phase 3: matter Schiefer, Fokus aufs Rennen)

    private var opponentsRow: some View {
        HStack(spacing: 26) {
            ForEach(1..<(game.playout?.hands.count ?? 4), id: \.self) { seat in
                slateToken(seat: seat)
            }
        }
        .padding(.top, 12)
    }

    private func slateToken(seat: Int) -> some View {
        let isLeader = game.playout?.leader == seat && game.stage == .playout
        let restCards = game.displayedHand(of: seat).count
        return VStack(spacing: 3) {
            OpponentPortrait(seat: seat,
                             name: game.name(of: seat),
                             isActive: true,
                             isFocus: isLeader,
                             size: 46,
                             morph: morph)
            Text("\(restCards) Karten").font(.system(size: 9))
                .foregroundStyle(Tokens.slate.opacity(0.8))
            Text("\(game.displayedEndStack(of: seat))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.jewelGold.opacity(0.9))
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.6), value: game.endPhase)
        }
        .saturation(isLeader ? 1 : 0.2)
        .opacity(isLeader ? 1 : 0.55)
        .animation(.easeInOut(duration: 0.25), value: isLeader)
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
            .animation(.spring(duration: 0.3), value: glowing)

            if pastChains > 0 {
                Text("\(pastChains) \(pastChains == 1 ? "Stich" : "Stiche")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.slate.opacity(0.7))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.04))
                        .overlay(Capsule().strokeBorder(Tokens.slate.opacity(0.25), lineWidth: 1)))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: pastChains)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    // MARK: - Dramatischer Fächer (§5b Akt 3, Mockup-Delta)

    /// Grosser angewinkelter Fächer der aktuellen Kette + Poch-Medaillon.
    /// Muster identisch mit ContentView::handView (.offset + .rotationEffect anchor:.bottom).
    private var playedCardsFan: some View {
        let chains = game.revealedChains
        let currentChain = chains.last ?? []
        let displayCards = currentChain.isEmpty
            ? Array(game.displayedHand(of: 0).prefix(8))
            : currentChain.map(\.card)
        let frozen = game.endPhase >= .frozen
        let N = displayCards.count
        let previewMode = currentChain.isEmpty
        let cardScale: CGFloat = previewMode ? 1.44 : 1.62
        let spreadDeg = N > 1
            ? min(Double(N) * (previewMode ? 10.8 : 13.0), previewMode ? 72.0 : 62.0)
            : 0.0
        let totalW: CGFloat = N > 1
            ? min(CGFloat(N - 1) * (previewMode ? 42 : 58), previewMode ? 304 : 254)
            : 0

        return ZStack {
            ForEach(Array(displayCards.enumerated()), id: \.offset) { i, card in
                let t: CGFloat = N > 1 ? CGFloat(i) / CGFloat(N - 1) : 0.5
                let angle = N > 1 ? -spreadDeg / 2 + Double(t) * spreadDeg : 0.0
                let xOff: CGFloat = N > 1 ? -totalW / 2 + t * totalW : 0

                CardFace(card: card,
                         goldenStopper: !currentChain.isEmpty
                             && game.cascadeIdle
                             && i == N - 1
                             && game.stage == .playout,
                         scale: cardScale)
                    .offset(x: xOff)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .zIndex(Double(i + 1))
                    .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: 74 * cardScale * (previewMode ? 1.24 : 1.16))
        .overlay {
            ZStack {
                medallion
                    .offset(y: previewMode ? 36 : 42)
                sideDeck
                    .offset(x: 92, y: previewMode ? 44 : 50)
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            chainStateBadge
                .offset(y: -28)
        }
        .saturation(frozen ? 0.08 : 1)
        .opacity(frozen ? 0.55 : 1)
        .animation(.easeOut(duration: 0.12), value: frozen)
        .animation(.easeOut(duration: 0.2), value: N)
    }

    @ViewBuilder private var chainStateBadge: some View {
        if game.stage == .playout {
            let chains = game.revealedChains
            let current = chains.last ?? []
            let last = current.last?.card
            let leader = game.playout?.leader ?? 0
            if !game.cascadeIdle {
                phaseBadge(title: "KETTE", value: "läuft", tint: Tokens.jewelSmaragd)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else if let last, !current.isEmpty {
                let next = leader == 0 ? "DU" : game.name(of: leader).uppercased()
                phaseBadge(title: "RISS \(last.rank.index)\(last.suit.symbol)",
                           value: next,
                           tint: leader == 0 ? Tokens.jewelGold : Tokens.jewelSmaragd)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
    }

    private func phaseBadge(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint.opacity(0.88))
                .frame(width: 7, height: 7)
                .shadow(color: tint.opacity(0.28), radius: 4)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 7.8, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(tint.opacity(0.88))
                Text(value)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [
                    Color(hex: 0x17141D).opacity(0.86),
                    Color(hex: 0x09080D).opacity(0.86)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.38), radius: 9, y: 5)
        )
        .animation(.easeOut(duration: 0.18), value: game.cascadeIdle)
    }

    /// Poch-Medaillon: Herz-Symbol als Zentrum des Fächers (§0 Signatur).
    private var medallion: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [
                    Color(hex: 0x241B22),
                    Color(hex: 0x100F15)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().strokeBorder(Tokens.jewelGold.opacity(0.62), lineWidth: 2.0))
                .overlay(Circle().strokeBorder(Color.black.opacity(0.75), lineWidth: 4).padding(5))
                .overlay(Circle().strokeBorder(Tokens.jewelPlatin.opacity(0.14), lineWidth: 1).padding(9))
                .frame(width: 92, height: 92)
                .shadow(color: .black.opacity(0.72), radius: 12, y: 7)
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [
                    Tokens.smaragdVivid.opacity(theme.isNeon ? 0.9 : 0.64),
                    Tokens.jewelAmethyst.opacity(theme.isNeon ? 0.9 : 0.58)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 34)
                .rotationEffect(.degrees(45))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Tokens.jewelPlatin.opacity(0.35), lineWidth: 1)
                    .rotationEffect(.degrees(45)))
                .shadow(color: Tokens.smaragdVivid.opacity(theme.isNeon ? 0.34 : 0.10),
                        radius: theme.isNeon ? 14 : 5)
            Text("♥")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(Tokens.jewelPlatin.opacity(0.82))
                .offset(y: -1)
        }
        .accessibilityLabel("Poch-Medaillon")
    }

    private var sideDeck: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.black.opacity(0.42))
                .frame(width: 39, height: 54)
                .offset(x: 4, y: 5)
            CardBack(scale: 0.45)
                .rotationEffect(.degrees(2))
                .shadow(color: .black.opacity(0.58), radius: 9, y: 5)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Tokens.jewelGold.opacity(0.38), lineWidth: 0.9)
                .frame(width: 39, height: 54)
        }
        .opacity(0.92)
        .accessibilityHidden(true)
    }

    // MARK: - Status + Hand

    private var settlementStatus: some View {
        VStack(spacing: 10) {
            if let result = game.roundResult {
                let total = result.centerPool + result.payments.reduce(0, +)
                Text(result.winner == 0 ? "Die Mitte wandert zu dir"
                                         : "Die Mitte wandert zu \(game.name(of: result.winner))")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
                HStack(spacing: 8) {
                    settlementPill("MITTE", "\(result.centerPool)", Tokens.jewelPlatin)
                    settlementPill("RESTKARTEN", "+\(total - result.centerPool)", Tokens.jewelGold)
                    settlementPill("TOTAL", "\(total)", Tokens.jewelSmaragd)
                }
                .frame(maxWidth: 328)
            } else {
                Text("Abrechnung läuft")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.92))
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 104)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
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

    private var statusLine: some View {
        let leader = game.playout?.leader ?? 0
        let text: String = {
            guard game.cascadeIdle else { return "Die Kette läuft …" }
            return leader == 0 ? "Du spielst an - wähle eine Karte"
                               : "\(game.name(of: leader)) spielt an …"
        }()
        return Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(game.cascadeIdle && leader == 0
                             ? Tokens.jewelGold : Tokens.slate)
            .padding(.top, 2)
            .padding(.bottom, 20)
            .zIndex(5)
            .animation(.easeInOut(duration: 0.2), value: game.cascadeIdle)
    }

    /// Angewinkelter Handfächer (Muster von ContentView::handView, §5b Akt 3 Spielerhand).
    private var handFan: some View {
        let cards = game.displayedHand(of: 0)
        let canLead = game.cascadeIdle && game.playout?.leader == 0
            && game.stage == .playout
        let N = cards.count
        let cardScale: CGFloat = 1.22
        let spreadDeg = min(Double(N) * 7.0, 36.0)
        let totalW: CGFloat = min(CGFloat(N) * 30, 220)

        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                let t: CGFloat = N > 1 ? CGFloat(i) / CGFloat(N - 1) : 0.5
                let angle = N > 1 ? -spreadDeg / 2 + Double(t) * spreadDeg : 0.0
                let xOff: CGFloat = N > 1 ? -totalW / 2 + t * totalW : 0

                Button { game.humanLead(card) } label: {
                    CardFace(card: card, scale: cardScale)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9 * cardScale)
                                .strokeBorder(Tokens.jewelGold.opacity(canLead ? 0.62 : 0),
                                              lineWidth: canLead ? 1.4 : 0)
                                .padding(2)
                        )
                        .shadow(color: canLead ? Tokens.jewelGold.opacity(0.18) : .clear,
                                radius: canLead ? 10 : 0,
                                y: canLead ? 2 : 0)
                }
                .buttonStyle(.plain)
                .disabled(!canLead)
                .offset(x: xOff)
                .offset(y: canLead ? -4 * (1 - abs(t - 0.5) * 1.2) : 0)
                .rotationEffect(.degrees(angle), anchor: .bottom)
                .zIndex(Double(i))
                .transition(.scale(scale: 0.86, anchor: .bottom).combined(with: .opacity))
            }
        }
        .opacity(canLead ? 1 : 0.75)
        .animation(.easeInOut(duration: 0.22), value: canLead)
        .animation(.easeOut(duration: 0.12), value: N)
        .frame(height: 74 * cardScale * 0.82, alignment: .bottom)
    }

    // MARK: - Rundenende

    private var resultBanner: some View {
        VStack(spacing: 14) {
            if let r = game.roundResult {
                let payments = r.payments.reduce(0, +)
                VStack(spacing: 6) {
                    Text(r.winner == 0 ? "Du gewinnst" : "\(game.name(of: r.winner)) gewinnt")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Tokens.jewelPlatin)
                    Text("Runde abgeschlossen")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.9)
                        .foregroundStyle(Tokens.smaragdVivid.opacity(0.82))
                }

                HStack(spacing: 10) {
                    resultMetric("MITTE", "\(r.centerPool)", Tokens.jewelPlatin)
                    resultMetric("STRAFE", "+\(payments)", Tokens.jewelGold)
                    resultMetric("TOTAL", "\(r.centerPool + payments)", Tokens.smaragdVivid)
                }

                recapStrip(game.roundRecap)

                VStack(spacing: 7) {
                    ForEach(Array(r.payments.enumerated()), id: \.offset) { seat, payment in
                        if seat != r.winner {
                            paymentRow(name: game.name(of: seat),
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
                Text("Nächste Runde")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Tokens.bgDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Tokens.jewelGold)
                        .overlay(Capsule().strokeBorder(Tokens.jewelPlatin.opacity(0.35), lineWidth: 1)))
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
            recapPill("KETTEN", "\(recap.chains)")
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

    private func paymentRow(name: String, payment: Int, stack: Int) -> some View {
        HStack(spacing: 8) {
            TableChip(tint: payment > 0 ? Tokens.jewelGold : Tokens.slate, size: 14)
            Text(name)
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

/// Straf-Strom (§6c c): pro Verlierer ein PARALLELER Chip-Strom zum Sieger
/// (nie sequenzielle Einzelflüge - Auflage). Zahlungen visuell auf 5 Chips gedeckelt.
private struct PunishStreams: View {
    let result: (winner: Int, centerPool: Int, payments: [Int])
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
                                    tint: Tokens.jewelGold,
                                    index: i,
                                    lane: seat,
                                    trigger: flown)
                        }
                    }
                }
                ChipArrivalImpact(at: winnerPos,
                                  tint: result.winner == 0 ? Tokens.jewelGold : Tokens.jewelSmaragd,
                                  trigger: flown)
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
    let tint: Color
    let index: Int
    let lane: Int
    let trigger: Bool

    var body: some View {
        let t: CGFloat = trigger ? 1 : 0
        let p = point(t)
        TableChip(tint: tint, size: 10)
            .rotation3DEffect(.degrees(Double(t) * 340 + Double(index) * 22),
                              axis: (x: 0.5, y: 0.7, z: 0.1))
            .position(p)
            .opacity(trigger ? 0.22 : 1)
            .shadow(color: tint.opacity(trigger ? 0.16 : 0), radius: trigger ? 8 : 0)
            .animation(.easeInOut(duration: Tokens.p3PunishFlight)
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

                ForEach(0..<10, id: \.self) { i in
                    let angle = Double(i) * 137.5 * .pi / 180
                    Capsule()
                        .fill(i % 3 == 0 ? Tokens.jewelPlatin.opacity(0.82) : Tokens.jewelGold.opacity(0.58))
                        .frame(width: 2.2, height: 9)
                        .rotationEffect(.radians(angle))
                        .position(x: center.x + (released ? 58 : 24) * cos(angle),
                                  y: center.y + (released ? 58 : 24) * sin(angle))
                        .opacity(released ? 0 : 0.92)
                        .animation(.easeOut(duration: 0.52).delay(Double(i) * 0.014), value: released)
                }

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

private struct ChipArrivalImpact: View {
    let at: CGPoint
    let tint: Color
    let trigger: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(tint.opacity(trigger ? 0 : 0.42), lineWidth: trigger ? 1 : 3)
                .frame(width: trigger ? 52 : 22, height: trigger ? 52 : 22)
                .position(at)
                .opacity(trigger ? 0 : 1)
                .animation(.easeOut(duration: 0.46).delay(Tokens.p3PunishImpactDelay), value: trigger)
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) * 60 * .pi / 180
                TableChip(tint: tint, size: 5.5)
                    .position(x: at.x + (trigger ? 22 : 7) * cos(angle),
                              y: at.y + (trigger ? 22 : 7) * sin(angle))
                    .opacity(trigger ? 0 : 0.74)
                    .animation(.easeOut(duration: 0.52)
                        .delay(Tokens.p3PunishImpactDelay - 0.04 + Double(i) * 0.025),
                        value: trigger)
            }
        }
    }
}
