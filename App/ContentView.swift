import PochKit
import SwiftUI

/// Spieltisch-Container: Phase 1 (Melde-Tableau, Poch-Ring) und Phase 2 (Pochen, §6b).
/// Der echte Phasen-Morph (.matchedGeometryEffect, §5b) folgt, sobald das Phase-3-Layout
/// steht - bis dahin schaltet ein harter Wechsel die Akte um.
struct ContentView: View {
    /// Die drei Akte (§5b) als View-Fortschritt; die Engine steht nach dem Melden
    /// bereits in .betting. Der echte Morph ersetzt später die harten Schnitte.
    private enum Akt { case melden, pochen, ausspielen }

    @State private var game = GameState()
    /// DEBUG-Launch-Args "-pochenStart"/"-ausspielStart" öffnen Akt 2/3 direkt
    /// (Screenshot-/QA-Läufe ohne Tap).
    @State private var akt: Akt = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ausspielStart") { return .ausspielen }
        if ProcessInfo.processInfo.arguments.contains("-pochenStart") { return .pochen }
        #endif
        return .melden
    }()
    /// Theme-Umschalter (§7): Premium (matt) ↔ Vivid-Electronic/„Neon" (strahlend).
    /// Ab Start verfügbar; DEBUG-Launch-Arg "-neon YES", später Settings-Toggle.
    @AppStorage("neon") private var neon = false
    private var theme: Theme { neon ? .neon : .premium }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Phasen-Morph (§5b): ein Namespace über alle drei Akte - Tokens, Poch-Tile und
    /// Mulden fliegen via matchedGeometryEffect an ihre neuen Positionen.
    @Namespace private var morph

    var body: some View {
        ZStack {
            // Material-Tiefe: warmes Bühnenlicht hinter dem Ring, Vignette zum Rand (kein Flat-Void).
            RadialGradient(gradient: Gradient(colors: [Tokens.bgLift, Tokens.bgDeep]),
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 6, endRadius: 540)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                switch akt {
                case .melden:
                    opponentTopBar
                    Spacer(minLength: 8)
                    ringView
                        .contentShape(Circle())
                        .onTapGesture { game.skipDeal() }  // Tap überspringt die Kaskade
                    Spacer(minLength: 8)
                    handView
                    phase1Footer
                case .pochen:
                    Phase2View(game: game, theme: theme, morph: morph,
                               onContinue: {
                                   withAnimation(.spring(duration: Tokens.aktMorph)) {
                                       akt = .ausspielen
                                   }
                                   game.beginPlayoutPresentation()
                               },
                               onNewRound: startNewRound)
                case .ausspielen:
                    Phase3View(game: game, theme: theme, morph: morph,
                               onNewRound: startNewRound)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 18)
            // Trumpf-Beat-Inszenierung liegt als hitTest-freie Schicht über Akt 1
            .overlay { if akt == .melden { DealOverlay(game: game) } }
        }
        .onAppear {
            if akt == .melden { game.runDealPresentation(reduceMotion: reduceMotion) }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: game.hapticTick)
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-ausspielStart") {
                game.debugSkipToPlayout()
                game.beginPlayoutPresentation()
                // -autoLead: niedrigste Karte anspielen (Kaskaden-QA ohne UI-Tap)
                if args.contains("-autoLead"),
                   let card = game.displayedHand(of: 0)
                       .min(by: { $0.rank.rawValue < $1.rank.rawValue }) {
                    game.humanLead(card)
                }
            }
            // -morphDemo: automatischer Akt-Durchlauf für die Bewegungs-QA (Video ohne Tap)
            if args.contains("-morphDemo") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(.spring(duration: Tokens.aktMorph)) { akt = .pochen }
                    try? await Task.sleep(for: .seconds(3))
                    game.debugSkipToPlayout()
                    withAnimation(.spring(duration: Tokens.aktMorph)) { akt = .ausspielen }
                    game.beginPlayoutPresentation()
                }
            }
        }
        #endif
    }

    private func startNewRound() {
        game.newRound()
        withAnimation(.spring(duration: Tokens.aktMorph)) { akt = .melden }
        game.runDealPresentation(reduceMotion: reduceMotion)
    }

    // MARK: - Kopf

    private var aktLabel: (text: String, tint: Color) {
        switch akt {
        case .melden: return ("PHASE 1 · MELDEN", Tokens.slate)
        case .pochen: return ("PHASE 2 · POCHEN", Tokens.amethystVivid.opacity(0.85))
        case .ausspielen: return ("PHASE 3 · AUSSPIELEN", Tokens.smaragdVivid.opacity(0.85))
        }
    }

    private var header: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Text("POCH").font(.system(size: 26, weight: .bold)).foregroundStyle(Tokens.jewelPlatin)
                Text("1441").font(.system(size: 26, weight: .light)).foregroundStyle(Tokens.jewelGold)
            }
            Text(aktLabel.text)
                .font(.system(size: 11, weight: .semibold)).tracking(2.5)
                .foregroundStyle(aktLabel.tint)
            trumpChip
        }
    }

    /// Übergang zu Akt 2 - später ersetzt der Phasen-Morph diesen Schnitt (§5b).
    private var phase1Footer: some View {
        HStack(spacing: 12) {
            Button {
                startNewRound()
            } label: {
                Text("Neue Runde").font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().strokeBorder(Tokens.slate.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            Button {
                withAnimation(.spring(duration: Tokens.aktMorph)) { akt = .pochen }
            } label: {
                Text("Weiter · Pochen").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().fill(Tokens.jewelAmethyst.opacity(0.65))
                        .overlay(Capsule().strokeBorder(Tokens.amethystVivid.opacity(0.8), lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 14)
    }

    private var trumpChip: some View {
        let up = game.upcard
        // Der Trumpf bleibt verdeckt, bis der Beat ihn flippt (§6a)
        let revealed = game.trumpRevealed || akt != .melden
        return HStack(spacing: 5) {
            Text("Trumpf").font(.system(size: 12, weight: .medium)).foregroundStyle(Tokens.slate)
            Text(revealed ? "\(up.rank.index)\(up.suit.symbol)" : "· ·")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(revealed
                                 ? (up.suit.isRed ? Color(hex: 0xD07A85) : Tokens.jewelPlatin)
                                 : Tokens.slate)
                .contentTransition(.opacity)
                .animation(.easeIn(duration: 0.2), value: revealed)
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
                        .matchedGeometryEffect(id: "token\(idx + 1)", in: morph)
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
        // .position statt .offset: echte Layout-Frames, damit matchedGeometryEffect
        // beim Morph die korrekten Flugbahnen misst (§5b).
        return ZStack {
            Circle().strokeBorder(
                LinearGradient(colors: [Tokens.jewelGold.opacity(theme.ringLineOpacity * 1.6),
                                        Tokens.jewelGold.opacity(theme.ringLineOpacity * 0.5)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1)
                .frame(width: Tokens.ringRadius * 2, height: Tokens.ringRadius * 2)
                .position(x: d / 2, y: d / 2)
            centerTile.position(x: d / 2, y: d / 2)
            ForEach(PochRing.anchors) { anchor in
                muldeTile(anchor.pool)
                    .matchedGeometryEffect(
                        id: anchor.pool == .poch ? "pochPot" : "tile-\(anchor.pool.rawValue)",
                        in: morph)
                    .position(x: d / 2 + anchor.offset.width,
                              y: d / 2 + anchor.offset.height)
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

    // MARK: - Hand (baut sich im Kaskaden-Takt auf, §6a)

    private var handView: some View {
        HStack(spacing: -14) {
            ForEach(Array(game.humanHand.prefix(game.humanDealtVisible).enumerated()),
                    id: \.offset) { _, card in
                CardFace(card: card)
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.12), value: game.humanDealtVisible)
        .frame(minHeight: 74)
    }
}

#Preview { ContentView() }
