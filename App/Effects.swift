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
        RadialGradient(colors: [.clear, tint.opacity(flashed ? 0 : 0.30)],
                       center: .center, startRadius: 140, endRadius: 520)
            .ignoresSafeArea()
            .animation(.easeOut(duration: duration), value: flashed)
            .onAppear { flashed = true }
    }
}
