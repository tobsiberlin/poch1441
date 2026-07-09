import PochKit
import SwiftUI

/// Trumpf-Beat-Inszenierung (§6a): Kartenrücken fliegen im 40-ms-Takt vom Stapel
/// (Ring-Zentrum) in die Hände; nach dem Freeze schießt der radiale Lichtpuls in
/// Trumpffarbe übers Brett. Reine Präsentations-Schicht über GameState-Zählern -
/// hitTest-frei, damit keine Taps geschluckt werden.
struct DealOverlay: View {
    let game: GameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let deck = CGPoint(x: w / 2, y: h * 0.46)
            ZStack {
                // Flug-Fenster: die letzten ~3 ausgeteilten Karten sind in der Luft
                if !reduceMotion, game.dealtCount < game.totalDeals {
                    let order = game.dealOrder
                    let window = max(0, game.dealtCount - 3)..<min(game.dealtCount, order.count)
                    ForEach(Array(window), id: \.self) { i in
                        FlyingBack(from: deck,
                                   to: target(order[i], w: w, h: h))
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
            // Hand-Slot unten (8 Karten, Breite 52, Überlappung -14)
            let x = w / 2 + (CGFloat(entry.slot) - 3.5) * 38
            return CGPoint(x: x, y: h - 96)
        }
        // Gegner-Token in der Top-Bar
        let x = w / 2 + CGFloat(entry.seat - 2) * 48
        return CGPoint(x: x, y: 118)
    }

    private func playerTarget(_ seat: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        seat == 0 ? CGPoint(x: w / 2, y: h - 96)
                  : CGPoint(x: w / 2 + CGFloat(seat - 2) * 48, y: 118)
    }

    private func poolPosition(_ pool: Pool, deck: CGPoint) -> CGPoint {
        if let anchor = PochRing.anchors.first(where: { $0.pool == pool }) {
            return CGPoint(x: deck.x + anchor.offset.width,
                           y: deck.y + anchor.offset.height)
        }
        return deck  // .center
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
                              delay: Tokens.p1CoinFlight + 0.18)
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
        let point = bezier(progress)
        TableChip(tint: tint, size: 12)
            .rotation3DEffect(.degrees(Double(progress) * 360 + Double(index) * 18),
                              axis: (x: 0.4, y: 0.8, z: 0.1))
            .scaleEffect(1 - progress * 0.15)
            .position(point)
            .opacity(progress >= 0.98 ? 0.08 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).delay(delay)) {
                    progress = 1
                }
            }
    }

    private func bezier(_ t: CGFloat) -> CGPoint {
        let mid = CGPoint(x: (from.x + to.x) / 2 + CGFloat(index - 1) * 10,
                          y: min(from.y, to.y) - 58 - CGFloat(index % 2) * 14)
        let inv = 1 - t
        return CGPoint(
            x: inv * inv * from.x + 2 * inv * t * mid.x + t * t * to.x,
            y: inv * inv * from.y + 2 * inv * t * mid.y + t * t * to.y
        )
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
            Circle()
                .strokeBorder(tint.opacity(fired ? 0 : 0.42), lineWidth: fired ? 1 : 4)
                .frame(width: fired ? 54 : 15, height: fired ? 54 : 15)
            Circle()
                .fill(Tokens.jewelPlatin.opacity(fired ? 0 : 0.20))
                .frame(width: fired ? 10 : 18, height: fired ? 10 : 18)
                .blur(radius: fired ? 4 : 1)
        }
        .position(at)
        .opacity(started && !fired ? 1 : 0)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                started = true
                withAnimation(.easeOut(duration: 0.34)) {
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
    @State private var arrived = false

    var body: some View {
        CardBack(scale: 0.62)
            .shadow(color: .black.opacity(0.45), radius: 4, y: 3)
            .scaleEffect(arrived ? 0.34 : 1)
            .opacity(arrived ? 0 : 1)
            .position(arrived ? to : from)
            .onAppear {
                withAnimation(.easeOut(duration: Tokens.p1Flight)) {
                    arrived = true
                }
            }
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
