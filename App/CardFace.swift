import PochKit
import SwiftUI

/// Premium-Kartenvorderseite (konzept §4: klarer Index + Farbe, Lesbarkeit vor Pracht).
/// Material statt Flat-Weiß: warmer Elfenbein-Karton mit feiner vertikaler Aufhellung
/// und Hairline-Innenrahmen; Serif-Indizes (Verwandtschaft zum 1441-Signet), zweiter
/// Index punktsymmetrisch unten rechts (echte Karten-Sprache). Geteilt zwischen
/// Phase 1 (Hand), Phase 2 (Kunststück-Glow §6b) und Phase 3 (Kaskade, Stopper-Gold §6c).
struct CardFace: View {
    let card: Card
    /// §6b: dein qualifizierendes Kunststück leuchtet - nur die eigene Hand.
    var highlighted: Bool = false
    /// §6c: die Stopper-Karte glüht golden am Beat-Drop.
    var goldenStopper: Bool = false
    /// Größenfaktor (1 = Hand, ~0.86 = gespielte Sequenz).
    var scale: CGFloat = 1

    private var accent: Color? {
        if goldenStopper { return Tokens.goldVivid }
        if highlighted { return Tokens.amethystVivid }
        return nil
    }

    /// Tiefes Weinrot / warmes Tinten-Schwarz statt Knallfarben - premium, lesbar.
    private var ink: Color {
        card.suit.isRed ? Color(hex: 0x9E2436) : Color(hex: 0x201E26)
    }

    var body: some View {
        ZStack {
            // Karton: warmes Elfenbein, oben minimal heller (Material-Wölbung wie die Tiles)
            RoundedRectangle(cornerRadius: 8 * scale)
                .fill(LinearGradient(colors: [Color(hex: 0xF8F3E7), Color(hex: 0xEBE3D0)],
                                     startPoint: .top, endPoint: .bottom))
            // Hairline-Innenrahmen (klassische Karten-Sprache, extrem dezent)
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
            // Zentrum: großes Pip mit hauchdünnem Tiefen-Schatten (Druck-Anmutung)
            Text(card.suit.symbol)
                .font(.system(size: 23 * scale))
                .foregroundStyle(ink)
                .shadow(color: .black.opacity(0.14), radius: 0.4 * scale, y: 0.6 * scale)
        }
        .frame(width: 52 * scale, height: 74 * scale)
        .overlay(RoundedRectangle(cornerRadius: 8 * scale)
            .strokeBorder(accent?.opacity(0.85) ?? .black.opacity(0.18),
                          lineWidth: accent != nil ? 1.5 : 0.5))
        .shadow(color: accent?.opacity(0.55) ?? .black.opacity(0.4),
                radius: accent != nil ? 7 : 3, y: accent != nil ? 0 : 2)
    }

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

#Preview("CardFace Material") {
    ZStack {
        Color(hex: 0x0B0E14).ignoresSafeArea()
        VStack(spacing: 18) {
            HStack(spacing: -14) {
                CardFace(card: Card(suit: .hearts, rank: .ten))
                CardFace(card: Card(suit: .spades, rank: .ace), highlighted: true)
                CardFace(card: Card(suit: .clubs, rank: .queen))
                CardFace(card: Card(suit: .diamonds, rank: .seven), goldenStopper: true)
            }
            HStack(spacing: -10) {
                ForEach([Rank.seven, .eight, .nine], id: \.self) { r in
                    CardFace(card: Card(suit: .spades, rank: r), scale: 0.62)
                }
            }
        }
    }
}
