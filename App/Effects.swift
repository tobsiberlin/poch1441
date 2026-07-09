import SwiftUI

/// Tisch-Zittern (Poch-Schlag §6b, Kollaps §6a e): N volle Oszillationen pro Trigger,
/// endet exakt bei 0 (Integer-Zustände sind Ruhelage) - nur Offset, kein
/// Layout-Thrashing (§9). Geteilt zwischen Phase 1 und 2.
struct TableShake: GeometryEffect {
    var amplitude: Double
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = amplitude * sin(Double(animatableData) * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

/// Kollaps-Vignette (§6a e): farbgetönter Flash für einen Wimpernschlag - Ränder
/// glühen in der Kategorie-Farbe auf, die Spielfläche bleibt lesbar
/// (Lesbarkeits-Licht-Regel §5).
struct KollapsVignette: View {
    let tint: Color
    let duration: Double
    @State private var flashed = false

    var body: some View {
        RadialGradient(colors: [.clear, tint.opacity(flashed ? 0 : 0.16)],
                       center: .center, startRadius: 140, endRadius: 520)
            .ignoresSafeArea()
            .animation(.easeOut(duration: duration), value: flashed)
            .onAppear { flashed = true }
    }
}

struct PhaseCurtain: View {
    let phase: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Text(phase)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2.2)
                    .foregroundStyle(tint.opacity(0.92))
                Text(title)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 330)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [
                        Color(hex: 0x17141D),
                        Color(hex: 0x0B0A10)
                    ], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(tint.opacity(0.34), lineWidth: 1))
                    .shadow(color: .black.opacity(0.62), radius: 26, y: 14)
            )
        }
        .allowsHitTesting(false)
    }
}
