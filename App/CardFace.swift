import PochKit
import SwiftUI

/// Premium-Kartenvorderseite (konzept §4: klarer Index + Farbe, Lesbarkeit vor Pracht).
/// Rang-differenziertes Zentrum: Pip-Muster für 7-10, Rang-Letter für Bildkarten, große
/// Einzelpip für das Ass. Elfenbein-Karton + Hairline-Innenrahmen + Serif-Indizes.
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

    var body: some View {
        ZStack {
            // Karton: warmes Elfenbein, oben minimal heller (Material-Wölbung)
            RoundedRectangle(cornerRadius: 8 * scale)
                .fill(LinearGradient(
                    colors: [Color(hex: 0xF8F3E7), Color(hex: 0xEBE3D0)],
                    startPoint: .top, endPoint: .bottom))
            // Hairline-Innenrahmen (klassische Karten-Sprache)
            RoundedRectangle(cornerRadius: 5.5 * scale)
                .strokeBorder(Color(hex: 0xC7BCA3).opacity(0.55), lineWidth: 0.5 * scale)
                .padding(3 * scale)
            // Indizes: oben links + punktsymmetrisch unten rechts
            VStack(spacing: 0) {
                HStack { indexBlock; Spacer() }
                Spacer()
                HStack { Spacer(); indexBlock.rotationEffect(.degrees(180)) }
            }
            .padding(4.5 * scale)
            // Zentrum: rang-spezifisch
            centerBody
        }
        .frame(width: 52 * scale, height: 74 * scale)
        .overlay(RoundedRectangle(cornerRadius: 8 * scale)
            .strokeBorder(
                accent?.opacity(0.85) ?? .black.opacity(0.18),
                lineWidth: accent != nil ? 1.5 : 0.5))
        .shadow(
            color: accent?.opacity(0.55) ?? .black.opacity(0.4),
            radius: accent != nil ? 7 : 3, y: accent != nil ? 0 : 2)
    }

    // MARK: - Zentrum

    @ViewBuilder
    private var centerBody: some View {
        switch card.rank {
        case .ace:
            // Ass: ikonische Einzel-Pip, leicht übergroß und mit Tiefenschatten
            Text(card.suit.symbol)
                .font(.system(size: 30 * scale))
                .foregroundStyle(ink)
                .shadow(color: ink.opacity(0.22), radius: 1.5 * scale, y: 1 * scale)

        case .jack, .queen, .king:
            // Bildkarten: großer Rang-Buchstabe allein - Farbe + Eck-Index codieren die Farbe
            // bereits; ein zusätzliches Pip wäre Redundanz und macht die Karte generisch.
            Text(card.rank.index)
                .font(.system(size: 28 * scale, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
                .shadow(color: ink.opacity(0.15), radius: 1 * scale, y: 0.8 * scale)

        default:
            // Zahlkarten 7-10: klassische 2-spaltige Pip-Anordnung
            pipGrid
        }
    }

    // MARK: - Pip-Grid

    // Normalisierte (x, y) Offsets vom Kartenmittelpunkt.
    // Basis-Zone: 32 × 46 pt (bei scale 1), sicher im Abstand von den Eck-Indizes.
    // x-Offset: ±0.28 → ±9 pt | y-Offset: ±0.38 → ±17.5 pt
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

    // MARK: - Index-Block (oben links, 180° gedreht unten rechts)

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
            // Ass + Bildkarten
            HStack(spacing: -10) {
                CardFace(card: Card(suit: .hearts,   rank: .ace))
                CardFace(card: Card(suit: .spades,   rank: .king))
                CardFace(card: Card(suit: .diamonds, rank: .queen), highlighted: true)
                CardFace(card: Card(suit: .clubs,    rank: .jack))
            }
            // Zahlkarten 7-10
            HStack(spacing: -10) {
                CardFace(card: Card(suit: .spades,   rank: .ten), goldenStopper: true)
                CardFace(card: Card(suit: .hearts,   rank: .nine))
                CardFace(card: Card(suit: .clubs,    rank: .eight))
                CardFace(card: Card(suit: .diamonds, rank: .seven))
            }
            // Kleine Scale (Deal-Größe)
            HStack(spacing: -8) {
                ForEach([Rank.seven, .nine, .jack, .ace], id: \.self) { r in
                    CardFace(card: Card(suit: .spades, rank: r), scale: 0.62)
                }
            }
        }
    }
}
