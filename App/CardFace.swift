import PochKit
import SwiftUI

/// Kartenvorderseite: alle 32 Karten aus EINER deterministischen Vorlage
/// (`tools/gen_cards_vector_public_domain.py`) - weiße Karte, große Eck-Indizes,
/// Public-Domain-Vektorblatt, Provenance: assets/provenance/cardfronts-final.md.
/// Geteilt zwischen Phase 1 (Hand), Phase 2 (Kunststück-Glow §6b) und Phase 3 (Stopper §6c).
struct CardFace: View {
    let card: Card
    /// §6b: qualifizierendes Kunststück leuchtet - nur die eigene Hand.
    var highlighted: Bool = false
    /// §6c: Stopper-Karte glüht golden am Beat-Drop.
    var goldenStopper: Bool = false
    /// Größenfaktor (1 = Hand, ~0.62 = Deal-Animation, ~0.42 = Gegner-Fächer Phase 2).
    var scale: CGFloat = 1
    /// Ein darüberliegendes, bedeutungsvolleres Lernziel übernimmt VoiceOver.
    var isAccessibilityHidden: Bool = false

    private var accent: Color? {
        if goldenStopper { return Tokens.jewelGold }
        if highlighted { return Tokens.amethystText }
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

    /// Karton-Wölbung: deterministischer Seed pro Karte (leichte Asymmetrie im Fächer).
    private var bendPhase: Double {
        let sum = assetName.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(sum % 63) / 10.0
    }

    /// Transparenter Rand, in den die gehobenen Ecken hineinwölben (kein Clipping).
    private var bendPad: CGFloat { 3 * scale }

    /// Zustandsringe liegen vollständig außerhalb der gebackenen Asset-Silhouette.
    /// So bleiben Drucktextur, Handling-Rand und Alpha-Rundung der PNGs unverändert.
    private var accentLineWidth: CGFloat { max(0.75, 2 * scale) }

    var body: some View {
        // Alle 32 Karten als klassisches, vollständig materialisiertes Asset.
        // Keine Runtime-Fläche und kein Clip dürfen dessen Patina übermalen.
        svgCard(named: assetName)
            .frame(width: 52 * scale, height: 74 * scale)
            .overlay {
                if let accent {
                    RoundedRectangle(cornerRadius: 8 * scale + accentLineWidth)
                        .strokeBorder(accent.opacity(0.85), lineWidth: accentLineWidth)
                        .padding(-accentLineWidth)
                }
            }
            // Physische Wölbung als Render-Effekt (CardWarp.metal) - Layout bleibt
            // durch das padding/-padding-Paar unverändert, der Schatten folgt der
            // gewölbten Silhouette
            .padding(bendPad)
            .layerEffect(
                ShaderLibrary.cardWarp(
                    .float2(52 * scale + 2 * bendPad, 74 * scale + 2 * bendPad),
                    .float(1.6 * scale),
                    .float(bendPhase)),
                maxSampleOffset: CGSize(width: 0.56 * scale, height: 1.6 * scale))
            .padding(-bendPad)
            // Kontaktschatten zwischen überlappenden Karten (Fächer-Wette 8.7.:
            // Schatten ist Render-Eigenschaft, nie im Asset)
            .shadow(
                color: accent?.opacity(0.6) ?? .black.opacity(0.5),
                radius: accent != nil ? 8 : 4.8, x: -0.8 * scale, y: accent != nil ? 0 : 2.8)
            // Zweite, weiche Schattenlage: macht den Luftspalt spürbar - beide
            // Lagen folgen der gewölbten Silhouette, an den gehobenen Ecken
            // wird die Penumbra dadurch breiter (physische Kartenebenen)
            .shadow(
                color: accent != nil ? .clear : .black.opacity(0.20),
                radius: 8 * scale, x: -1.2 * scale, y: 3.8 * scale)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(card.rank.index) \(card.suit.symbol)")
            .accessibilityHidden(isAccessibilityHidden)
    }

    // MARK: - SVG-Asset (Bildkarten + Asse)

    private func svgCard(named name: String) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            // Die historischen Druckassets bleiben unverändert. Auf dem dunklen
            // Tisch erhalten rote Farben nur im Display-Compositing etwas mehr
            // Farbdichte, damit Herz/Karo nicht verwaschen wirken.
            .saturation(card.suit.isRed ? 1.55 : 1)
            .contrast(card.suit.isRed ? 1.04 : 1)
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
