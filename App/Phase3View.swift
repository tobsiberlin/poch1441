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
    let onNewRound: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            opponentsRow
            centerpotChip
            chainsArea
            Spacer(minLength: 8)
            if game.stage == .playout || game.endPhase < .done {
                statusLine
                handView
            } else {
                resultBanner
            }
        }
        // Straf-Strom (§6c c): Chips fliegen PARALLEL von jedem Verlierer zum Sieger
        .overlay {
            if game.endPhase == .punishing, let result = game.roundResult, !reduceMotion {
                PunishStreams(result: result)
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
            ZStack {
                Circle().fill(.white.opacity(0.05))
                    .overlay(Circle().strokeBorder(
                        isLeader ? Tokens.jewelGold : Tokens.slate.opacity(0.4),
                        lineWidth: isLeader ? 2 : 1))
                Text(String(game.name(of: seat).prefix(1)))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isLeader ? Tokens.jewelPlatin : Tokens.slate)
            }
            .frame(width: 44, height: 44)
            .matchedGeometryEffect(id: "token\(seat)", in: morph)
            Text(game.name(of: seat)).font(.system(size: 10, weight: .medium))
                .foregroundStyle(isLeader ? Tokens.jewelPlatin.opacity(0.9) : Tokens.slate)
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

    /// Der Centerpot (Platin) - ruhiger Anker; leuchtet im Eiszeit-Vakuum auf (§6c c).
    private var centerpotChip: some View {
        let glowing = game.endPhase == .frozen || game.endPhase == .punishing
        let value = game.roundResult?.centerPool ?? game.chips(in: .center)
        return HStack(spacing: 5) {
            Text("Centerpot").font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.slate)
            Text("\(value)").font(.system(size: 13, weight: .bold))
                .foregroundStyle(Tokens.jewelPlatin)
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(glowing ? 0.10 : 0.04))
            .overlay(Capsule().strokeBorder(
                Tokens.jewelPlatin.opacity(glowing ? 0.9 : 0.3), lineWidth: 1))
            .shadow(color: Tokens.jewelPlatin.opacity(glowing ? 0.5 : 0),
                    radius: glowing ? 10 : 0))
        .scaleEffect(glowing ? 1.12 : 1)
        .animation(.spring(duration: 0.3), value: glowing)
        .padding(.top, 8)
    }

    // MARK: - Die Ketten (lesbare Sequenz, §6c a)

    private var chainsArea: some View {
        let chains = game.revealedChains
        let frozen = game.endPhase >= .frozen
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(chains.enumerated()), id: \.offset) { index, chain in
                        chainRow(chain,
                                 isCurrent: index == chains.count - 1,
                                 chainClosed: index < chains.count - 1 || game.cascadeIdle)
                            .id(index)
                    }
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: 330)
            // Eiszeit-Vakuum (§6c c): in der ms des Rundenendes entsättigt alles zu Schiefer
            .saturation(frozen ? 0.08 : 1)
            .opacity(frozen ? 0.55 : 1)
            .animation(.easeOut(duration: 0.12), value: frozen)
            .onChange(of: chains.count) {
                withAnimation { proxy.scrollTo(chains.count - 1, anchor: .bottom) }
            }
        }
    }

    private func chainRow(_ chain: [PlayoutPhase.Play], isCurrent: Bool,
                          chainClosed: Bool) -> some View {
        HStack(spacing: -22) {
            ForEach(Array(chain.enumerated()), id: \.offset) { index, play in
                CardFace(card: play.card,
                         goldenStopper: isCurrent && chainClosed && index == chain.count - 1
                             && game.stage == .playout,
                         scale: isCurrent ? 0.86 : 0.62)
            }
        }
        .opacity(isCurrent ? 1 : 0.42)
        .animation(.easeOut(duration: 0.15), value: chain.count)
    }

    // MARK: - Status + Hand

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
            .padding(.bottom, 10)
            .animation(.easeInOut(duration: 0.2), value: game.cascadeIdle)
    }

    private var handView: some View {
        let canLead = game.cascadeIdle && game.playout?.leader == 0
            && game.stage == .playout
        return HStack(spacing: -14) {
            ForEach(Array(game.displayedHand(of: 0).enumerated()), id: \.offset) { _, card in
                Button {
                    game.humanLead(card)
                } label: {
                    CardFace(card: card)
                }
                .buttonStyle(.plain)
                .disabled(!canLead)
            }
        }
        .opacity(canLead ? 1 : 0.75)
        .padding(.bottom, 4)
    }

    // MARK: - Rundenende (Baseline-Banner; Eiszeit-Vakuum kommt im Game-Feel-Pass §6c)

    private var resultBanner: some View {
        VStack(spacing: 8) {
            if let r = game.roundResult {
                Text(r.winner == 0 ? "Du gewinnst die Runde!"
                                   : "\(game.name(of: r.winner)) gewinnt die Runde")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin)
                Text("Centerpot \(r.centerPool) (Platin) + \(r.payments.reduce(0, +)) aus Restkarten")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.slate)
            }
            Button {
                onNewRound()
            } label: {
                Text("Neue Runde").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().fill(Tokens.jewelGold.opacity(0.25))
                        .overlay(Capsule().strokeBorder(Tokens.jewelGold.opacity(0.7), lineWidth: 1)))
            }
            .buttonStyle(.plain)
            Text("Eiszeit-Vakuum + Straf-Strom folgen im Game-Feel-Pass")
                .font(.system(size: 10)).foregroundStyle(Tokens.slate.opacity(0.7))
        }
        .padding(.bottom, 16)
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
                ForEach(Array(result.payments.enumerated()), id: \.offset) { seat, payment in
                    if payment > 0, seat != result.winner {
                        let from = position(seat: seat, w: w, h: h)
                        ForEach(0..<min(payment, 5), id: \.self) { i in
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Tokens.jewelPlatin.opacity(0.9),
                                             Tokens.jewelGold.opacity(0.7)],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(width: 9, height: 9)
                                .position(flown ? winnerPos : from)
                                .opacity(flown ? 0.05 : 1)
                                .animation(.easeIn(duration: 0.5)
                                    .delay(Double(i) * 0.07), value: flown)
                        }
                    }
                }
            }
            .onAppear { flown = true }
        }
    }

    private func position(seat: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        seat == 0 ? CGPoint(x: w / 2, y: h - 90)
                  : CGPoint(x: w / 2 + CGFloat(seat - 2) * 70, y: 46)
    }
}
