import PochKit
import SwiftUI

/// Phase 3 (Ausspielen) - das Renn-Layout (§5b Akt 3, §6c): die Gegner verharren als
/// matte Schiefer-Tokens am Rand, das Zentrum gehört den gespielten Ketten (lesbare
/// Sequenz, Mitzählen bleibt möglich). Kaskaden-Takt und Beat-Drop kommen aus GameState;
/// die Stopper-Karte glüht golden, das Anspielrecht wandert sichtbar.
struct Phase3View: View {
    let game: GameState
    let theme: Theme
    let onNewRound: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            opponentsRow
            chainsArea
            Spacer(minLength: 8)
            if game.stage == .playout {
                statusLine
                handView
            } else {
                resultBanner
            }
        }
    }

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
            Text(game.name(of: seat)).font(.system(size: 10, weight: .medium))
                .foregroundStyle(isLeader ? Tokens.jewelPlatin.opacity(0.9) : Tokens.slate)
            Text("\(restCards) Karten").font(.system(size: 9))
                .foregroundStyle(Tokens.slate.opacity(0.8))
        }
        .saturation(isLeader ? 1 : 0.2)
        .opacity(isLeader ? 1 : 0.55)
        .animation(.easeInOut(duration: 0.25), value: isLeader)
    }

    // MARK: - Die Ketten (lesbare Sequenz, §6c a)

    private var chainsArea: some View {
        let chains = game.revealedChains
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
