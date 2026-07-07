import PochKit
import SwiftUI

/// Clean Karten-Vorderseite (Platzhalter-Stufe, konzept §4: klarer Index + Farbe,
/// Lesbarkeit vor Pracht). Geteilt zwischen Phase 1 (Hand) und Phase 2 (Paar-Glow §6b).
struct CardFace: View {
    let card: Card
    /// §6b: dein qualifizierendes Kunststück leuchtet ("du darfst pochen") - nur die
    /// eigene Hand, nie ein Gegner-Leak. Glow = Belohnungs-Akzent in Amethyst.
    var highlighted: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(spacing: -2) {
                    Text(card.rank.index).font(.system(size: 15, weight: .bold))
                    Text(card.suit.symbol).font(.system(size: 12))
                }
                Spacer()
            }
            Spacer()
            Text(card.suit.symbol).font(.system(size: 22))
            Spacer()
        }
        .foregroundStyle(card.suit.isRed ? Color(hex: 0xB22A2A) : Color(hex: 0x1A1A22))
        .padding(7)
        .frame(width: 52, height: 74)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xF3EFE6)))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(highlighted ? Tokens.amethystVivid.opacity(0.85) : .black.opacity(0.15),
                          lineWidth: highlighted ? 1.5 : 0.5))
        .shadow(color: highlighted ? Tokens.amethystVivid.opacity(0.5) : .black.opacity(0.4),
                radius: highlighted ? 7 : 3, y: highlighted ? 0 : 2)
    }
}
