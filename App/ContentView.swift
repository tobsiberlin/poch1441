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
                        .onTapGesture { game.skipDeal() }
                        .modifier(TableShake(
                            amplitude: reduceMotion ? 0 : Tokens.kollapsShakeAmp,
                            animatableData: CGFloat(game.kollapsShock)))
                        .animation(.linear(duration: Tokens.kollapsShake),
                                   value: game.kollapsShock)
                    Spacer(minLength: 10)
                    // Buttons ÜBER den Karten (nicht darunter) - Mockup-Komposition
                    phase1Footer
                    // Kartenfächer blendet am unteren Bildschirmrand aus (Bleed-Ästhetik)
                    handView
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
            // Phase 1: kein Bottom-Padding - Kartenfächer blendet am Bildschirmrand aus
            .padding(.bottom, akt == .melden ? 0 : 18)
            // Trumpf-Beat-Inszenierung liegt als hitTest-freie Schicht über Akt 1
            .overlay { if akt == .melden { DealOverlay(game: game) } }
            // Kollaps-Vignette: farbgetönter Wimpernschlag (§6a e);
            // reduceMotion: 50-ms-Dissolve statt Flash (§6 Auflage 2)
            .overlay {
                if game.kollapsShock > 0, let info = game.kollapsInfo, akt == .melden {
                    KollapsVignette(tint: theme.tint(info.pool),
                                    duration: reduceMotion ? 0.05 : Tokens.kollapsFlash)
                        .id("vignette\(game.kollapsShock)")
                        .allowsHitTesting(false)
                }
            }
        }
        .onAppear {
            if akt == .melden { game.runDealPresentation(reduceMotion: reduceMotion) }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: game.hapticTick)
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.kollapsShock)
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
            // -kollapsDemo: Threshold auf 1 - jede Meldung zündet (Kollaps-QA)
            if args.contains("-kollapsDemo") {
                GameState.kollapsThresholdOverride = 1
            }
            // -pochDemo: automatisches Eröffnungs-Gebot für die Tischschlag-QA
            if args.contains("-pochDemo") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    if let legal = game.humanLegal, let open = legal.openRange {
                        game.humanOpen(min(3, open.upperBound))
                    }
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

    /// Übergang zu Akt 2 - kompakte Pill-Zeile direkt über dem Kartenfächer.
    /// Mockup-Stil: kein Clutter, nur eine klare Weiter-Aktion + dezente Neue-Runde.
    private var phase1Footer: some View {
        HStack(spacing: 10) {
            Button {
                startNewRound()
            } label: {
                Text("↺").font(.system(size: 15))
                    .foregroundStyle(Tokens.slate.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.06))
                        .overlay(Circle().strokeBorder(Tokens.slate.opacity(0.3), lineWidth: 1)))
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                withAnimation(.spring(duration: Tokens.aktMorph)) { akt = .pochen }
            } label: {
                HStack(spacing: 6) {
                    Text("Pochen").font(.system(size: 15, weight: .semibold))
                    Text("›").font(.system(size: 17, weight: .medium))
                }
                .foregroundStyle(Tokens.jewelPlatin)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Capsule().fill(Tokens.jewelAmethyst.opacity(0.7))
                    .overlay(Capsule().strokeBorder(Tokens.amethystVivid.opacity(0.85), lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 4)
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
            ForEach(1..<4, id: \.self) { seat in
                VStack(spacing: 3) {
                    Circle().fill(.white.opacity(0.08))
                        .overlay(Circle().strokeBorder(Tokens.jewelGold.opacity(0.35), lineWidth: 1))
                        .frame(width: 34, height: 34)
                        .overlay(Text("\(seat)").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Tokens.slate))
                        .matchedGeometryEffect(id: "token\(seat)", in: morph)
                    // Konto rollt hoch, wenn der Melde-Strom auszahlt (§6a b)
                    Text("\(game.displayedStack(of: seat))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Tokens.jewelGold.opacity(0.9))
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.3), value: game.meldShown)
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
        let pulsing = game.pulsingPool == pool
        return VStack(spacing: 1) {
            Text(pool.indexLabel).font(.system(size: long ? 9 : 16, weight: .bold))
            // Anzeige-Wert: zahlt erst aus, wenn der Melde-Strom die Mulde erreicht
            Text("\(game.displayedChips(in: pool))").font(.system(size: 13, weight: .semibold))
                .contentTransition(.numericText())
        }
        .foregroundStyle(tint)
        .scaleEffect(pulsing ? 1.14 : 1)
        .animation(.spring(duration: 0.25), value: pulsing)
        .animation(.easeOut(duration: 0.3), value: game.meldShown)
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
            Text("\(game.displayedChips(in: .center))").font(.system(size: 19, weight: .bold))
                .contentTransition(.numericText())
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

    // MARK: - Hand (Mockup-Fächer: groß, angewinkelt, Bleed am unteren Bildschirmrand)

    private var handView: some View {
        let cards = Array(game.humanHand.prefix(game.humanDealtVisible))
        let N = cards.count
        // Fächer-Parameter: breite Spreizung, Karten leicht überlappend, Mockup-Optik
        let spreadDeg = min(Double(N) * 7.5, 40.0)
        let totalW: CGFloat = min(CGFloat(N) * 38, 252)
        let cardScale: CGFloat = 1.55

        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                let t: CGFloat = N > 1 ? CGFloat(i) / CGFloat(N - 1) : 0.5
                let angle = N > 1 ? -spreadDeg / 2 + Double(t) * spreadDeg : 0
                let xOff: CGFloat = N > 1 ? -totalW / 2 + t * totalW : 0

                CardFace(card: card, scale: cardScale)
                    .offset(x: xOff)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .zIndex(Double(i))
                    .transition(.scale(scale: 0.86, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.12), value: game.humanDealtVisible)
        // Nur ~60% der Kartenhöhe sichtbar - Rest blendet am Bildschirmrand aus
        .frame(height: 74 * cardScale * 0.60)
    }
}

#Preview { ContentView() }
