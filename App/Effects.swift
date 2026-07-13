import SwiftUI

/// Gemeinsame, deterministische Tischphysik. Die Funktionen liefern nur
/// Präsentationswerte; Regeln und Spielzustand bleiben vollständig in PochKit.
enum PhysicalMotion {
    static let materialSettle = Animation.timingCurve(0.22, 0.72, 0.18, 1,
                                                      duration: 0.34)

    static func travel(duration: Double) -> Animation {
        .timingCurve(0.22, 0.72, 0.18, 1.0, duration: duration)
    }

    static func duration(from: CGPoint,
                         to: CGPoint,
                         pointsPerSecond: CGFloat,
                         minimum: Double,
                         maximum: Double) -> Double {
        let distance = hypot(to.x - from.x, to.y - from.y)
        return min(maximum, max(minimum, Double(distance / pointsPerSecond)))
    }

    static func shallowArcHeight(from: CGPoint,
                                 to: CGPoint,
                                 minimum: CGFloat,
                                 maximum: CGFloat) -> CGFloat {
        let distance = hypot(to.x - from.x, to.y - from.y)
        return min(maximum, max(minimum, distance * 0.075))
    }

    static func quadraticPoint(progress: CGFloat,
                               from: CGPoint,
                               to: CGPoint,
                               arcHeight: CGFloat,
                               lateralBias: CGFloat = 0) -> CGPoint {
        let t = min(max(progress, 0), 1)
        let inverse = 1 - t
        let control = CGPoint(x: (from.x + to.x) / 2 + lateralBias,
                              y: (from.y + to.y) / 2 - arcHeight)
        return CGPoint(
            x: inverse * inverse * from.x + 2 * inverse * t * control.x + t * t * to.x,
            y: inverse * inverse * from.y + 2 * inverse * t * control.y + t * t * to.y
        )
    }
}

/// Tisch-Zittern für den Poch-Schlag: N volle Oszillationen pro Trigger,
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
