import PochKit
import SwiftUI

/// Phase 1 (Melden) - erster echter Screen: der Poch-Ring rendert die echten Mulden-Werte
/// aus PochKit, Gegner als schmale Top-Bar (§5c Phase-1-Zustand), die Hand unten.
/// Feel-Animationen (40-ms-Deal, Meld-Juice) und die Phasen 2/3 folgen.
struct ContentView: View {
    @State private var game = GameState()
    /// Theme-Umschalter (§7): Premium (matt) ↔ Vivid-Electronic/„Neon" (strahlend).
    /// Ab Start verfügbar; DEBUG-Launch-Arg "-neon YES", später Settings-Toggle.
    @AppStorage("neon") private var neon = false
    private var theme: Theme { neon ? .neon : .premium }

    var body: some View {
        ZStack {
            // Material-Tiefe: warmes Bühnenlicht hinter dem Ring, Vignette zum Rand (kein Flat-Void).
            RadialGradient(gradient: Gradient(colors: [Tokens.bgLift, Tokens.bgDeep]),
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 6, endRadius: 540)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                opponentTopBar
                Spacer(minLength: 8)
                ringView
                Spacer(minLength: 8)
                handView
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 18)
        }
        // Tap = neue Runde (Fundament-QA, bis das echte Spiel drankommt)
        .contentShape(Rectangle())
        .onTapGesture { game.newRound() }
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Text("POCH").font(.system(size: 26, weight: .bold)).foregroundStyle(Tokens.jewelPlatin)
                Text("1441").font(.system(size: 26, weight: .light)).foregroundStyle(Tokens.jewelGold)
            }
            Text("PHASE 1 · MELDEN")
                .font(.system(size: 11, weight: .semibold)).tracking(2.5)
                .foregroundStyle(Tokens.slate)
            trumpChip
        }
    }

    private var trumpChip: some View {
        let up = game.upcard
        return HStack(spacing: 5) {
            Text("Trumpf").font(.system(size: 12, weight: .medium)).foregroundStyle(Tokens.slate)
            Text("\(up.rank.index)\(up.suit.symbol)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(up.suit.isRed ? Color(hex: 0xD07A85) : Tokens.jewelPlatin)
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.05))
            .overlay(Capsule().strokeBorder(Tokens.jewelGold.opacity(0.35), lineWidth: 1)))
        .padding(.top, 3)
    }

    // MARK: - §5c Phase-1: Gegner als schmale Top-Bar

    private var opponentTopBar: some View {
        HStack(spacing: 14) {
            ForEach(Array(game.opponentStacks.enumerated()), id: \.offset) { idx, stack in
                VStack(spacing: 3) {
                    Circle().fill(.white.opacity(0.08))
                        .overlay(Circle().strokeBorder(Tokens.jewelGold.opacity(0.35), lineWidth: 1))
                        .frame(width: 34, height: 34)
                        .overlay(Text("\(idx + 1)").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Tokens.slate))
                    Text("\(stack)").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Tokens.jewelGold.opacity(0.9))
                }
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Der Poch-Ring

    private var ringView: some View {
        let d = Tokens.ringRadius * 2 + Tokens.tileDiameter
        return ZStack {
            Circle().strokeBorder(
                LinearGradient(colors: [Tokens.jewelGold.opacity(theme.ringLineOpacity * 1.6),
                                        Tokens.jewelGold.opacity(theme.ringLineOpacity * 0.5)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1)
                .frame(width: Tokens.ringRadius * 2, height: Tokens.ringRadius * 2)
            centerTile
            ForEach(PochRing.anchors) { anchor in
                muldeTile(anchor.pool).offset(anchor.offset)
            }
        }
        .frame(width: d, height: d)
    }

    private func muldeTile(_ pool: Pool) -> some View {
        let long = pool.indexLabel.count > 2
        let tint = theme.tint(pool)
        return VStack(spacing: 1) {
            Text(pool.indexLabel).font(.system(size: long ? 9 : 16, weight: .bold))
            Text("\(game.chips(in: pool))").font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(tint)
        .frame(width: Tokens.tileDiameter, height: Tokens.tileDiameter)
        .background(
            RoundedRectangle(cornerRadius: Tokens.tileCorner)
                // Oberfläche: leichte vertikale Wölbung (oben minimal heller) = Material-Tiefe
                .fill(LinearGradient(colors: [.white.opacity(0.05),
                                              .black.opacity(theme.tileFillOpacity)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: Tokens.tileCorner)
                    // Metallkante fängt Licht oben, dunkelt unten - Material statt Dauer-Glow
                    .strokeBorder(LinearGradient(colors: [tint.opacity(theme.isNeon ? 1 : 0.95),
                                                          tint.opacity(theme.isNeon ? 0.7 : 0.4)],
                                                 startPoint: .top, endPoint: .bottom),
                                  lineWidth: theme.borderWidth))
        )
        .shadow(color: tint.opacity(theme.glowOpacity), radius: theme.tileGlow)
        .shadow(color: tint.opacity(theme.isNeon ? 0.55 : 0), radius: theme.tileGlow * 0.45)
    }

    private var centerTile: some View {
        VStack(spacing: 1) {
            Text("MITTE").font(.system(size: 8, weight: .semibold)).tracking(1)
            Text("\(game.chips(in: .center))").font(.system(size: 19, weight: .bold))
        }
        .foregroundStyle(Tokens.jewelPlatin)
        .frame(width: Tokens.centerDiameter, height: Tokens.centerDiameter)
        .background(
            Circle()
                .fill(LinearGradient(colors: [.white.opacity(0.06), .black.opacity(0.5)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(
                    LinearGradient(colors: [Tokens.jewelPlatin, Tokens.jewelPlatin.opacity(0.45)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: theme.borderWidth))
                .shadow(color: Tokens.jewelPlatin.opacity(theme.isNeon ? 0.7 : 0.22), radius: theme.centerGlow)
        )
    }

    // MARK: - Hand (clean Platzhalter-Karten)

    private var handView: some View {
        HStack(spacing: -14) {
            ForEach(Array(game.humanHand.enumerated()), id: \.offset) { _, card in
                cardView(card)
            }
        }
    }

    private func cardView(_ card: Card) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(spacing: -2) {
                    Text(card.rank.index).font(.system(size: 15, weight: .bold))
                    Text(card.suit.symbol).font(.system(size: 12))
                }
                Spacer()
            }
            Spacer()
            Text(card.suit.symbol).font(.system(size: 22))
            Spacer()
        }
        .foregroundStyle(card.suit.isRed ? Color(hex: 0xB22A2A) : Color(hex: 0x1A1A22))
        .padding(7)
        .frame(width: 52, height: 74)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xF3EFE6)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
    }
}

#Preview { ContentView() }
