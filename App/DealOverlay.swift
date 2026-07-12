import PochKit
import SwiftUI

/// Trumpf-Beat-Inszenierung (§6a): Kartenrücken fliegen sichtbar vom Stapel
/// (Ring-Zentrum) in die Hände; nach dem Freeze schießt der radiale Lichtpuls in
/// Trumpffarbe übers Brett. Reine Präsentations-Schicht über GameState-Zählern -
/// hitTest-frei, damit keine Taps geschluckt werden.
struct DealOverlay: View {
    let game: GameState
    var showsSeatTargets = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let deck = CGPoint(x: w / 2, y: h * 0.46)
            ZStack {
                if game.dealtCount < game.totalDeals && !game.trumpRevealed {
                    if showsSeatTargets {
                        DealSeatTargets(game: game, w: w, h: h)
                    }
                    DealDeckAnchor(at: deck)
                }

                // Flug-Fenster: mehrere Karten bleiben gleichzeitig lesbar, ohne dass
                // die Runde als schneller Zaehlerwechsel wirkt.
                if !reduceMotion, game.dealtCount < game.totalDeals {
                    let order = game.dealOrder
                    let window = max(0, game.dealtCount - 4)..<min(game.dealtCount, order.count)
                    ForEach(Array(window), id: \.self) { i in
                        FlyingBack(from: deck,
                                   to: target(order[i], w: w, h: h),
                                   seat: order[i].seat,
                                   slot: order[i].slot,
                                   sequence: i)
                            .id("fly\(i)-\(game.round.deal.upcard.rank.rawValue)")
                    }
                }
                // Radialer Lichtpuls in Trumpffarbe (Belohnungs-Akzent, kein Dauer-Glow)
                if game.lightPulse > 0 {
                    PulseRing(tint: trumpTint)
                        .position(deck)
                        .id("pulse\(game.lightPulse)")
                }
                // Melde-Strom (§6a b): Münzen fliegen von der pulsierenden Mulde zum Gewinner
                if !reduceMotion, let pool = game.pulsingPool,
                   game.meldShown < game.meldEvents.count {
                    let meld = game.meldEvents[game.meldShown]
                    let from = poolPosition(pool, deck: deck)
                    let to = playerTarget(meld.player, w: w, h: h)
                    CoinStream(from: from, to: to, tint: pool.jewelVivid)
                        .id("meld\(game.meldShown)")
                }
                // Stufe 2 - der Balatro-Kollaps (§6a e): Tile birst in Kategorie-Farbe,
                // schwebendes +N beim Gewinner. Rar per Sim-Threshold (Rarity-Lock).
                if game.kollapsShock > 0, let info = game.kollapsInfo {
                    KollapsBurst(at: poolPosition(info.pool, deck: deck),
                                 tint: info.pool.jewelVivid,
                                 reduceMotion: reduceMotion)
                        .id("kollaps\(game.kollapsShock)")
                    FloatingGain(text: "+\(info.chips)",
                                 at: playerTarget(info.player, w: w, h: h),
                                 tint: info.pool.jewelVivid)
                        .id("gain\(game.kollapsShock)")
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var trumpTint: Color {
        game.trump == .hearts || game.trump == .diamonds
            ? Tokens.jewelRose : Tokens.jewelPlatin
    }

    private func target(_ entry: (seat: Int, slot: Int), w: CGFloat, h: CGFloat) -> CGPoint {
        if entry.seat == 0 {
            let x = w / 2 + (CGFloat(entry.slot) - 3.5) * 34
            return CGPoint(x: x, y: h - 116)
        }
        return opponentTarget(entry.seat, w: w, h: h)
    }

    private func playerTarget(_ seat: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        seat == 0 ? CGPoint(x: w / 2, y: h - 96)
                  : opponentTarget(seat, w: w, h: h)
    }

    private func opponentTarget(_ seat: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        let count = max(1, game.playerCount - 1)
        let idx = CGFloat(seat - 1)
        let center = CGFloat(count - 1) / 2
        let spacing = min(CGFloat(126), w / CGFloat(max(count, 2)) * 0.88)
        let arc = abs(idx - center) * 14
        return CGPoint(x: w / 2 + (idx - center) * spacing,
                       y: h * 0.225 + arc * 0.18)
    }

    private func poolPosition(_ pool: Pool, deck: CGPoint) -> CGPoint {
        if let anchor = PochRing.anchors.first(where: { $0.pool == pool }) {
            return CGPoint(x: deck.x + anchor.offset.width,
                           y: deck.y + anchor.offset.height)
        }
        return deck  // .center
    }
}

private struct DealSeatTargets: View {
    let game: GameState
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        ZStack {
            ForEach(1..<game.playerCount, id: \.self) { seat in
                opponentSeat(seat)
            }
            humanSeat
        }
        .transition(.opacity)
    }

    private func opponentSeat(_ seat: Int) -> some View {
        let point = opponentPoint(seat)
        let dealt = dealtCount(for: seat)
        return ZStack {
            ZStack {
                ForEach(0..<min(max(dealt, 1), 4), id: \.self) { i in
                    CardBack(scale: 0.82)
                        .rotationEffect(.degrees(Double(i - 1) * 8))
                        .offset(x: CGFloat(i - 1) * 14,
                                y: 19 + CGFloat(i) * 1.5)
                        .opacity(dealt == 0 ? 0.04 : 0.78)
                        .shadow(color: .black.opacity(0.62), radius: 8, y: 5)
                }
            }

            OpponentPortrait(seat: seat,
                             name: game.name(of: seat),
                             isActive: true,
                             isFocus: dealt > 0,
                             mood: dealt > 0 ? .thinking : .neutral,
                             size: 44,
                             showsText: false,
                             morph: nil)

            Text(game.name(of: seat).uppercased())
                .font(.system(size: 7.5, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(Tokens.jewelPlatin.opacity(dealt > 0 ? 0.76 : 0.38))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.46)))
                .offset(y: 47)
        }
        .frame(width: 108, height: 94)
        .position(point)
        .opacity(dealt == 0 ? 0.48 : 0.96)
    }

    private var humanSeat: some View {
        let dealt = dealtCount(for: 0)
        return ZStack {
            ForEach(0..<min(max(dealt, 1), 5), id: \.self) { i in
                CardBack(scale: 1.08)
                    .rotationEffect(.degrees(Double(i - 2) * 6))
                    .offset(x: CGFloat(i - 2) * 27,
                            y: abs(CGFloat(i - 2)) * 3.6)
                    .opacity(humanSeatOpacity(dealt: dealt))
                    .shadow(color: .black.opacity(0.62), radius: 11, y: 7)
            }
        }
        .position(x: w / 2, y: h - 82)
        .opacity(0.76)
    }

    private func humanSeatOpacity(dealt: Int) -> Double {
        if dealt == 0 { return 0.04 }
        if dealt < 4 { return 0.78 }
        return 0.68
    }

    private func dealtCount(for seat: Int) -> Int {
        game.dealOrder.prefix(game.dealtCount).filter { $0.seat == seat }.count
    }

    private func opponentPoint(_ seat: Int) -> CGPoint {
        let count = max(1, game.playerCount - 1)
        let idx = CGFloat(seat - 1)
        let center = CGFloat(count - 1) / 2
        let spacing = min(CGFloat(126), w / CGFloat(max(count, 2)) * 0.88)
        let arc = abs(idx - center) * 14
        return CGPoint(x: w / 2 + (idx - center) * spacing,
                       y: h * 0.225 + arc * 0.18)
    }
}

private struct DealDeckAnchor: View {
    let at: CGPoint

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [
                    Tokens.jewelGold.opacity(0.13),
                    Color.clear
                ], center: .center, startRadius: 4, endRadius: 56))
                .frame(width: 116, height: 116)
            ForEach(0..<3, id: \.self) { i in
                CardBack(scale: 0.96)
                    .rotationEffect(.degrees(Double(i - 1) * 4))
                    .offset(x: CGFloat(i - 1) * 3, y: CGFloat(i) * -2)
                    .shadow(color: .black.opacity(0.50), radius: 11, y: 6)
            }
            Circle()
                .strokeBorder(Tokens.jewelPlatin.opacity(0.18), lineWidth: 1)
                .frame(width: 72, height: 72)
        }
        .position(at)
        .opacity(0.92)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }
}

/// Kollaps-Partikel: ~30 Splitter bersten radial in Kategorie-Farbe (goldener Winkel
/// statt RNG - deterministisch reproduzierbar). reduceMotion: nur kurzer Farb-Blink.
private struct KollapsBurst: View {
    let at: CGPoint
    let tint: Color
    let reduceMotion: Bool
    @State private var fired = false

    var body: some View {
        ZStack {
            if reduceMotion {
                Circle().fill(tint.opacity(fired ? 0 : 0.5))
                    .frame(width: 54, height: 54)
                    .position(at)
                    .animation(.easeOut(duration: 0.05), value: fired)
            } else {
                ForEach(0..<30, id: \.self) { i in
                    let angle = Double(i) * 137.5 * .pi / 180
                    let dist: CGFloat = 44 + CGFloat(i % 3) * 22
                    Circle()
                        .fill(tint)
                        .frame(width: CGFloat(3 + i % 3), height: CGFloat(3 + i % 3))
                        .position(x: at.x + (fired ? dist * cos(angle) : 0),
                                  y: at.y + (fired ? dist * sin(angle) : 0))
                        .opacity(fired ? 0 : 1)
                        .animation(.easeOut(duration: 0.55)
                            .delay(Double(i % 5) * 0.02), value: fired)
                }
            }
        }
        .onAppear { fired = true }
        .allowsHitTesting(false)
    }
}

/// Schwebendes "+N": steigt beim Gewinner auf und verblasst (§6a e).
private struct FloatingGain: View {
    let text: String
    let at: CGPoint
    let tint: Color
    @State private var risen = false

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(tint)
            .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
            .position(x: at.x, y: at.y + (risen ? 6 : 40))
            .opacity(risen ? 0 : 1)
            .animation(.easeOut(duration: 0.9), value: risen)
            .onAppear { risen = true }
    }
}

/// Münz-Strom einer Meldung: gestaffelte Chips in Kategorie-Farbe fliegen zur
/// Gewinner-Position (Bogen-Flugbahn = Hand-Gate, v1 gerade + gestaffelt).
private struct CoinStream: View {
    let from: CGPoint
    let to: CGPoint
    let tint: Color

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                FlyingChip(from: from,
                           to: to,
                           tint: tint,
                           index: i,
                           duration: Tokens.p1CoinFlight,
                           delay: Double(i) * 0.06)
            }
            ChipLandingRipple(at: to,
                              tint: tint,
                              delay: Tokens.p1CoinFlight + 0.17)
        }
    }
}

private struct FlyingChip: View {
    let from: CGPoint
    let to: CGPoint
    let tint: Color
    let index: Int
    let duration: Double
    let delay: Double
    @State private var progress: CGFloat = 0

    var body: some View {
        let point = PhysicalMotion.quadraticPoint(
            progress: progress,
            from: from,
            to: landingPoint,
            arcHeight: PhysicalMotion.shallowArcHeight(from: from,
                                                       to: landingPoint,
                                                       minimum: 7,
                                                       maximum: 12),
            lateralBias: CGFloat(index - 1) * 2.2
        )
        TableChip(tint: tint, size: 17)
            .rotationEffect(.degrees(Double(index - 1) * 2 + Double(progress) * 4))
            .rotation3DEffect(.degrees(sin(Double(progress) * .pi) * 3),
                              axis: (x: 0.82, y: 0.18, z: 0),
                              perspective: 0.28)
            .scaleEffect(1 + sin(progress * .pi) * 0.025)
            .position(point)
            .opacity(progress >= 0.985 ? 0 : 1)
            .onAppear {
                withAnimation(PhysicalMotion.travel(duration: duration).delay(delay)) {
                    progress = 1
                }
            }
    }

    private var landingPoint: CGPoint {
        let offsets = [
            CGSize(width: -6, height: 3),
            CGSize(width: 5, height: 4),
            CGSize(width: -1, height: -4),
            CGSize(width: 4, height: -3)
        ]
        let offset = offsets[index % offsets.count]
        return CGPoint(x: to.x + offset.width, y: to.y + offset.height)
    }
}

private struct ChipLandingRipple: View {
    let at: CGPoint
    let tint: Color
    let delay: Double
    @State private var started = false
    @State private var fired = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(fired ? 0 : 0.48))
                .frame(width: fired ? 30 : 15, height: fired ? 9 : 5)
                .blur(radius: fired ? 3 : 1)
                .offset(y: 5)
            TableChip(tint: tint, size: 17)
                .scaleEffect(fired ? 0.92 : 1.06, anchor: .bottom)
                .opacity(fired ? 0 : 0.94)
        }
        .position(at)
        .opacity(started && !fired ? 1 : 0)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                started = true
                withAnimation(.easeOut(duration: 0.18)) {
                    fired = true
                }
            }
        }
    }
}

/// Ein einzelner fliegender Rücken: animiert sich beim Erscheinen zum Ziel und
/// schrumpft dort weg (Ankunft "saugt" die Karte in Hand/Token).
private struct FlyingBack: View {
    let from: CGPoint
    let to: CGPoint
    let seat: Int
    let slot: Int
    let sequence: Int
    @State private var progress: CGFloat = 0

    var body: some View {
        let duration = PhysicalMotion.duration(from: from,
                                               to: to,
                                               pointsPerSecond: 640,
                                               minimum: Tokens.p1Flight,
                                               maximum: Tokens.p1Flight + 0.16)
        CardBack(scale: seat == 0 ? 1.24 : 1.14)
            .shadow(color: .black.opacity(0.56),
                    radius: progress > 0.82 ? 4 : 12,
                    y: progress > 0.82 ? 3 : 8)
            .rotationEffect(.degrees(launchAngle + (landingAngle - launchAngle) * Double(progress)))
            .scaleEffect(1.02 + ((seat == 0 ? 0.90 : 0.82) - 1.02) * progress)
            .opacity(progress >= 0.985 ? 0 : 1)
            .position(PhysicalMotion.quadraticPoint(
                progress: progress,
                from: from,
                to: to,
                arcHeight: PhysicalMotion.shallowArcHeight(from: from,
                                                           to: to,
                                                           minimum: 18,
                                                           maximum: 34),
                lateralBias: CGFloat((sequence % 3) - 1) * 6
            ))
            .onAppear {
                withAnimation(PhysicalMotion.travel(duration: duration)) {
                    progress = 1
                }
            }
    }

    private var launchAngle: Double {
        Double((sequence % 5) - 2) * 1.6
    }

    private var landingAngle: Double {
        if seat == 0 { return Double(slot - 3) * 4.5 }
        return Double((slot % 3) - 1) * 5.5
    }
}

/// Der Puls: ein expandierender Ring, der ausklingt - einmalig pro Trigger.
private struct PulseRing: View {
    let tint: Color
    @State private var fired = false

    var body: some View {
        Circle()
            .strokeBorder(tint.opacity(fired ? 0 : 0.16), lineWidth: fired ? 0.7 : 4.5)
            .frame(width: 96, height: 96)
            .scaleEffect(fired ? 3.15 : 0.82)
            .blur(radius: fired ? 1.8 : 0.2)
            .onAppear {
                withAnimation(.easeOut(duration: min(Tokens.p1Pulse, 0.34))) { fired = true }
            }
    }
}
