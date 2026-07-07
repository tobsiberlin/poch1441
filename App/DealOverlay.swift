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
                if !reduceMotion, game.dealtCount < game.totalDeals + 3 {
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
                        .position(x: w / 2, y: 108)
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

/// Münz-Strom einer Meldung: gestaffelte Chips in Kategorie-Farbe fliegen zur
/// Gewinner-Position (Bogen-Flugbahn = Hand-Gate, v1 gerade + gestaffelt).
private struct CoinStream: View {
    let from: CGPoint
    let to: CGPoint
    let tint: Color
    @State private var flown = false

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.55)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                    .frame(width: 11, height: 11)
                    .position(flown ? to : from)
                    .opacity(flown ? 0.1 : 1)
                    .animation(.easeIn(duration: Tokens.p1CoinFlight)
                        .delay(Double(i) * 0.06), value: flown)
            }
        }
        .onAppear { flown = true }
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
            .strokeBorder(tint.opacity(fired ? 0 : 0.9), lineWidth: fired ? 3 : 22)
            .frame(width: 60, height: 60)
            .scaleEffect(fired ? 18 : 0.4)
            .onAppear {
                withAnimation(.easeOut(duration: Tokens.p1Pulse)) { fired = true }
            }
    }
}
