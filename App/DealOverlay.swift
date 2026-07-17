import PochKit
import SwiftUI

/// Trumpf-Beat-Inszenierung (§6a): Kartenrücken fliegen sichtbar vom Stapel
/// (Ring-Zentrum) in die Hände; nach dem Freeze schießt der radiale Lichtpuls in
/// Trumpffarbe übers Brett. Reine Präsentations-Schicht über GameState-Zählern -
/// hitTest-frei, damit keine Taps geschluckt werden.
struct DealOverlay: View {
    let game: GameState
    let theme: Theme
    let poolPositions: [Pool: CGPoint]
    var showsSeatTargets = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let boardCenter = CGPoint(x: w / 2, y: h * 0.46)
            // Eigener Kartenanker: Die zentrale Gewinnmulde bleibt jederzeit lesbar.
            // The PM49 board nearly fills the width. Keep the dealing stack in
            // the quiet band below it instead of covering the right-hand well.
            let deck = CGPoint(x: w * 0.78, y: h * 0.66)
            ZStack {
                if game.landedDeals < game.totalDeals && !game.trumpRevealed {
                    if showsSeatTargets {
                        DealSeatTargets(game: game, w: w, h: h)
                    }
                    if game.startedDeals > game.landedDeals {
                        DealDeckAnchor(at: deck)
                    }
                }

                // Flug-Fenster: mehrere Karten bleiben gleichzeitig lesbar, ohne dass
                // die Runde als schneller Zaehlerwechsel wirkt.
                if !reduceMotion, game.landedDeals < game.totalDeals {
                    let order = game.dealOrder
                    let window = game.landedDeals..<min(game.startedDeals, order.count)
                    ForEach(Array(window), id: \.self) { i in
                        FlyingBack(from: deck,
                                   to: target(order[i], w: w, h: h),
                                   seat: order[i].seat,
                                   slot: order[i].slot,
                                   sequence: i,
                                   onImpact: { game.markDealLanded(i) })
                            .id("fly\(i)-\(game.round.deal.upcard.rank.rawValue)")
                    }
                }
                // Radialer Lichtpuls in Trumpffarbe (Belohnungs-Akzent, kein Dauer-Glow)
                if game.lightPulse > 0 {
                    PulseRing(tint: trumpTint)
                        .position(boardCenter)
                        .id("pulse\(game.lightPulse)")
                }
                // Melde-Strom (§6a b): Münzen fliegen von der pulsierenden Mulde zum Gewinner
                if !reduceMotion, let pool = game.pulsingPool,
                   game.meldShown < game.startedMelds,
                   game.meldShown < game.meldEvents.count {
                    let meld = game.meldEvents[game.meldShown]
                    let from = poolPosition(pool, deck: boardCenter)
                    let to = playerTarget(meld.player, w: w, h: h)
                    MeldPayoutTarget(name: game.name(of: meld.player),
                                     amount: meld.chips,
                                     tint: theme.tint(pool))
                        .position(to)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    CoinStream(from: from,
                               to: to,
                               tint: theme.tint(pool),
                               amount: meld.chips,
                               onImpact: { game.markMeldLanded(game.meldShown) })
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
            let x = w / 2 + (CGFloat(entry.slot) - 3.5) * 34
            return CGPoint(x: x, y: h - 116)
        }
        return opponentTarget(entry.seat, w: w, h: h)
    }

    private func playerTarget(_ seat: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        seat == 0 ? CGPoint(x: w / 2, y: h - 158)
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
        if let resolved = poolPositions[pool] {
            return resolved
        }
        if let anchor = PochRing.anchors.first(where: { $0.pool == pool }) {
            return CGPoint(x: deck.x + anchor.offset.width,
                           y: deck.y + anchor.offset.height)
        }
        return deck  // .center
    }
}

/// Sichtbares Ziel eines Meldegewinns. Der Transfer endet nie im leeren Raum:
/// Name, Betrag und Materialanker bleiben bis zum Kontakt eindeutig lesbar.
private struct MeldPayoutTarget: View {
    let name: String
    let amount: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0x0B0910).opacity(0.92))
                    .overlay(Circle().strokeBorder(tint.opacity(0.42), lineWidth: 1))
                R1Token(tint: tint, size: 18)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 0) {
                Text(name.uppercased())
                    .font(.system(size: 7.5, weight: .heavy))
                    .tracking(0.9)
                    .foregroundStyle(Tokens.jewelPlatin.opacity(0.72))
                    .lineLimit(1)
                Text("+\(amount)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(hex: 0x0B0910).opacity(0.90))
                .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1))
                .shadow(color: .black.opacity(0.44), radius: 8, y: 4)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(name))
        .accessibilityValue(Text("+\(amount)"))
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
        game.dealOrder.prefix(game.landedDeals).filter { $0.seat == seat }.count
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

/// Münz-Strom einer Meldung: gestaffelte Chips in Kategorie-Farbe fliegen zur
/// Gewinner-Position (Bogen-Flugbahn = Hand-Gate, v1 gerade + gestaffelt).
private struct CoinStream: View {
    let from: CGPoint
    let to: CGPoint
    let tint: Color
    let amount: Int
    let onImpact: () -> Void

    var body: some View {
        ImpactFlight(from: from,
                     to: to,
                     duration: Tokens.p1CoinFlight,
                     arcHeight: PhysicalMotion.shallowArcHeight(from: from,
                                                                to: to,
                                                                minimum: 7,
                                                                maximum: 12),
                     onImpact: onImpact) { progress in
            let count = min(max(amount, 1), 4)
            let compression = progress > 0.90
                ? 1 - (progress - 0.90) / 0.10 * 0.055
                : 1
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    let pose = R1TokenSlots.pose(for: index)
                    R1Token(tint: tint, size: 22)
                        .rotationEffect(.degrees(pose.rotation))
                        .offset(R1TokenSlots.offset(for: index,
                                                    tokenDiameter: 22))
                }
            }
            .scaleEffect(compression)
            .rotationEffect(.degrees(Double(progress) * 2.8))
            .shadow(color: .black.opacity(0.42),
                    radius: progress > 0.86 ? 3 : 8,
                    y: progress > 0.86 ? 2 : 5)
        }
    }
}

/// Ein einzelner fliegender Rücken. Der sichtbare Zielstapel wächst erst im
/// Kontakt-Frame, sodass die Karte nie gleichzeitig fliegt und gelandet ist.
private struct FlyingBack: View {
    let from: CGPoint
    let to: CGPoint
    let seat: Int
    let slot: Int
    let sequence: Int
    let onImpact: () -> Void

    var body: some View {
        let duration = PhysicalMotion.duration(from: from,
                                               to: to,
                                               pointsPerSecond: 640,
                                               minimum: Tokens.p1Flight,
                                               maximum: Tokens.p1Flight + 0.16)
        ImpactFlight(from: from,
                     to: to,
                     duration: duration,
                     arcHeight: PhysicalMotion.shallowArcHeight(from: from,
                                                                to: to,
                                                                minimum: 18,
                                                                maximum: 34),
                     lateralBias: CGFloat((sequence % 3) - 1) * 6,
                     onImpact: onImpact) { progress in
            CardBack(scale: seat == 0 ? 1.24 : 1.14)
                .shadow(color: .black.opacity(0.56),
                        radius: progress > 0.82 ? 4 : 12,
                        y: progress > 0.82 ? 3 : 8)
                .rotationEffect(.degrees(
                    launchAngle + (landingAngle - launchAngle) * Double(progress)
                ))
                .scaleEffect(1.02 + ((seat == 0 ? 0.90 : 0.82) - 1.02) * progress)
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
