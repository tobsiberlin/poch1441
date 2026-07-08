import PochKit
import SwiftUI

/// Kartenvorderseite mit klassischen SVG-Assets (htdebeer/SVG-cards, LGPL).
/// Bildkarten (J/Q/K) und Asse: echtes zweiköpfiges Spielkartendesign aus dem Asset-Katalog.
/// Zahlkarten (7-10): code-gerendertes Pip-Muster (sauber, konsistent, kein Asset-Overhead).
/// Geteilt zwischen Phase 1 (Hand), Phase 2 (Kunststück-Glow §6b) und Phase 3 (Stopper §6c).
struct CardFace: View {
    let card: Card
    /// §6b: qualifizierendes Kunststück leuchtet - nur die eigene Hand.
    var highlighted: Bool = false
    /// §6c: Stopper-Karte glüht golden am Beat-Drop.
    var goldenStopper: Bool = false
    /// Größenfaktor (1 = Hand, ~0.62 = Deal-Animation, ~0.42 = Gegner-Fächer Phase 2).
    var scale: CGFloat = 1

    private var accent: Color? {
        if goldenStopper { return Tokens.goldVivid }
        if highlighted { return Tokens.amethystVivid }
        return nil
    }

    private var ink: Color {
        card.suit.isRed ? Color(hex: 0x9E2436) : Color(hex: 0x201E26)
    }

    /// Asset-Name im Katalog: card_{suit}_{rank}
    private var assetName: String {
        let suitStr: String
        switch card.suit {
        case .hearts:   suitStr = "hearts"
        case .diamonds: suitStr = "diamonds"
        case .spades:   suitStr = "spades"
        case .clubs:    suitStr = "clubs"
        }
        let rankStr: String
        switch card.rank {
        case .ace:   rankStr = "ace"
        case .king:  rankStr = "king"
        case .queen: rankStr = "queen"
        case .jack:  rankStr = "jack"
        case .ten:   rankStr = "ten"
        case .nine:  rankStr = "nine"
        case .eight: rankStr = "eight"
        case .seven: rankStr = "seven"
        }
        return "card_\(suitStr)_\(rankStr)"
    }

    var body: some View {
        ZStack {
            // Alle 32 Karten als klassisches SVG-Asset
            svgCard(named: assetName)
        }
        .frame(width: 52 * scale, height: 74 * scale)
        .overlay(RoundedRectangle(cornerRadius: 8 * scale)
            .strokeBorder(
                accent?.opacity(0.85) ?? .clear,
                lineWidth: accent != nil ? 2 : 0))
        .shadow(
            color: accent?.opacity(0.6) ?? .black.opacity(0.4),
            radius: accent != nil ? 8 : 3, y: accent != nil ? 0 : 2)
    }

    // MARK: - SVG-Asset (Bildkarten + Asse)

    private func svgCard(named name: String) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8 * scale))
    }

    // MARK: - Zahlkarten 7-10 (code-gerendert)

    private var numberCard: some View {
        ZStack {
            // Elfenbein-Karton
            RoundedRectangle(cornerRadius: 8 * scale)
                .fill(LinearGradient(
                    colors: [Color(hex: 0xF8F3E7), Color(hex: 0xEBE3D0)],
                    startPoint: .top, endPoint: .bottom))
            // Hairline-Innenrahmen
            RoundedRectangle(cornerRadius: 5.5 * scale)
                .strokeBorder(Color(hex: 0xC7BCA3).opacity(0.55), lineWidth: 0.5 * scale)
                .padding(3 * scale)
            // Eck-Indizes
            VStack(spacing: 0) {
                HStack { indexBlock; Spacer() }
                Spacer()
                HStack { Spacer(); indexBlock.rotationEffect(.degrees(180)) }
            }
            .padding(4.5 * scale)
            // Pip-Muster
            pipGrid
            // Äußerer Rahmen
            RoundedRectangle(cornerRadius: 8 * scale)
                .strokeBorder(.black.opacity(0.18), lineWidth: 0.5 * scale)
        }
    }

    // MARK: - Pip-Grid

    private static let pipOffsets: [Rank: [(Double, Double)]] = [
        .seven: [
            (-0.28, -0.36), (0.28, -0.36),
            (0,     -0.12),
            (-0.28,  0.13), (0.28,  0.13),
            (-0.28,  0.36), (0.28,  0.36),
        ],
        .eight: [
            (-0.28, -0.36), (0.28, -0.36),
            (-0.28, -0.09), (0.28, -0.09),
            (-0.28,  0.09), (0.28,  0.09),
            (-0.28,  0.36), (0.28,  0.36),
        ],
        .nine: [
            (-0.28, -0.36), (0.28, -0.36),
            (-0.28, -0.10), (0.28, -0.10),
            (0,      0.00),
            (-0.28,  0.10), (0.28,  0.10),
            (-0.28,  0.36), (0.28,  0.36),
        ],
        .ten: [
            (-0.28, -0.38), (0.28, -0.38),
            (0,     -0.20),
            (-0.28, -0.06), (0.28, -0.06),
            (-0.28,  0.06), (0.28,  0.06),
            (0,      0.20),
            (-0.28,  0.38), (0.28,  0.38),
        ],
    ]

    private var pipGrid: some View {
        let zoneW: CGFloat = 32 * scale
        let zoneH: CGFloat = 46 * scale
        let offsets = Self.pipOffsets[card.rank] ?? []
        return ZStack {
            ForEach(Array(offsets.enumerated()), id: \.offset) { _, pos in
                Text(card.suit.symbol)
                    .font(.system(size: 8 * scale))
                    .foregroundStyle(ink)
                    .offset(x: CGFloat(pos.0) * zoneW, y: CGFloat(pos.1) * zoneH)
            }
        }
    }

    // MARK: - Index-Block

    private var indexBlock: some View {
        VStack(spacing: -1.5 * scale) {
            Text(card.rank.index)
                .font(.system(size: 13 * scale, weight: .semibold, design: .serif))
            Text(card.suit.symbol)
                .font(.system(size: 9 * scale))
        }
        .foregroundStyle(ink)
    }
}

#Preview("CardFace - alle Ränge") {
    ZStack {
        Color(hex: 0x0B0E14).ignoresSafeArea()
        VStack(spacing: 14) {
            HStack(spacing: -10) {
                CardFace(card: Card(suit: .hearts,   rank: .ace))
                CardFace(card: Card(suit: .spades,   rank: .king))
                CardFace(card: Card(suit: .diamonds, rank: .queen), highlighted: true)
                CardFace(card: Card(suit: .clubs,    rank: .jack))
            }
            HStack(spacing: -10) {
                CardFace(card: Card(suit: .spades,   rank: .ten), goldenStopper: true)
                CardFace(card: Card(suit: .hearts,   rank: .nine))
                CardFace(card: Card(suit: .clubs,    rank: .eight))
                CardFace(card: Card(suit: .diamonds, rank: .seven))
            }
            HStack(spacing: -8) {
                ForEach([Rank.seven, .nine, .jack, .ace], id: \.self) { r in
                    CardFace(card: Card(suit: .spades, rank: r), scale: 0.62)
                }
            }
        }
    }
}
