import SwiftUI

#if DEBUG
struct BoardConceptView: View {
    var body: some View {
        ZStack {
            RadialGradient(colors: [
                Color(hex: 0x1B2530),
                Color(hex: 0x07060A)
            ], center: UnitPoint(x: 0.5, y: 0.28), startRadius: 40, endRadius: 720)
            .ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("POCH 1441")
                        .font(.system(size: 31, weight: .heavy))
                        .foregroundStyle(Tokens.jewelPlatin)
                    Text("PM100 + PM68 TOKEN-STUDIE")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(2.1)
                        .foregroundStyle(Tokens.jewelGold.opacity(0.84))
                }
                .padding(.top, 18)

                Image("PM100PM68Sim")
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Tokens.jewelGold.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.62), radius: 28, y: 18)
                    .padding(.horizontal, 12)

                VStack(spacing: 8) {
                    Text("Token-Regel")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.7)
                        .foregroundStyle(Tokens.slate)
                    Text("Schwere Glas-/Metall-Chips liegen als natürliche kleine Stapel in echten Mulden. Keine Punkte, keine flachen Coins.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Tokens.jewelPlatin.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: 0x101018).opacity(0.82))
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Tokens.jewelGold.opacity(0.16), lineWidth: 1))
                )
                .padding(.horizontal, 18)

                Spacer(minLength: 10)
            }
        }
    }
}
#endif
