import PochKit
import SwiftUI

/// Clean Karten-Vorderseite (Platzhalter-Stufe, konzept §4: klarer Index + Farbe,
/// Lesbarkeit vor Pracht). Geteilt zwischen Phase 1 (Hand), Phase 2 (Paar-Glow §6b)
/// und Phase 3 (Kaskaden-Sequenz, kompakt + Stopper-Gold §6c).
struct CardFace: View {
    let card: Card
    /// §6b: dein qualifizierendes Kunststück leuchtet ("du darfst pochen") - nur die
    /// eigene Hand, nie ein Gegner-Leak. Glow = Belohnungs-Akzent in Amethyst.
    var highlighted: Bool = false
    /// §6c: die Stopper-Karte glüht golden am Beat-Drop.
    var goldenStopper: Bool = false
    /// Größenfaktor (1 = Hand, ~0.82 = gespielte Sequenz).
    var scale: CGFloat = 1

    private var accent: Color? {
        if goldenStopper { return Tokens.goldVivid }
        if highlighted { return Tokens.amethystVivid }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(spacing: -2 * scale) {
                    Text(card.rank.index).font(.system(size: 15 * scale, weight: .bold))
                    Text(card.suit.symbol).font(.system(size: 12 * scale))
                }
                Spacer()
            }
            Spacer()
            Text(card.suit.symbol).font(.system(size: 22 * scale))
            Spacer()
        }
        .foregroundStyle(card.suit.isRed ? Color(hex: 0xB22A2A) : Color(hex: 0x1A1A22))
        .padding(7 * scale)
        .frame(width: 52 * scale, height: 74 * scale)
        .background(RoundedRectangle(cornerRadius: 8 * scale).fill(Color(hex: 0xF3EFE6)))
        .overlay(RoundedRectangle(cornerRadius: 8 * scale)
            .strokeBorder(accent?.opacity(0.85) ?? .black.opacity(0.15),
                          lineWidth: accent != nil ? 1.5 : 0.5))
        .shadow(color: accent?.opacity(0.55) ?? .black.opacity(0.4),
                radius: accent != nil ? 7 : 3, y: accent != nil ? 0 : 2)
    }
}
