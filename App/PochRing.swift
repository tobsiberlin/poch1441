import PochKit
import SwiftUI

extension Pool {
    /// Kategorie-Farbe (konzept §5, „Farbe = Label").
    var jewel: Color {
        switch self {
        case .ace, .king, .queen, .jack, .ten: return Tokens.jewelGold
        case .mariage:  return Tokens.jewelRose
        case .sequence: return Tokens.jewelSmaragd
        case .poch:     return Tokens.jewelAmethyst
        case .center:   return Tokens.jewelPlatin
        }
    }

    /// Index-Label international (A/K/Q/J/10, konzept §5).
    var indexLabel: String {
        switch self {
        case .ace: return "A"
        case .king: return "K"
        case .queen: return "Q"
        case .jack: return "J"
        case .ten: return "10"
        case .mariage: return "MAR"
        case .sequence: return "SEQ"
        case .poch: return "POCH"
        case .center: return "MITTE"
        }
    }
}

/// Ein Fach im Poch-Ring: Pool + Winkel (im Uhrzeigersinn ab 12 Uhr).
struct RingAnchor: Identifiable {
    let pool: Pool
    let angle: Double  // Grad
    var id: Pool { pool }

    /// Versatz vom Ring-Zentrum in SwiftUI-Koordinaten (+x rechts, +y unten):
    /// x = R·sin(α), y = −R·cos(α).
    var offset: CGSize {
        let rad = angle * .pi / 180
        return CGSize(width: Tokens.ringRadius * sin(rad),
                      height: -Tokens.ringRadius * cos(rad))
    }
}

/// Resolves the visible centers of the rendered PM49 wells in the coordinate
/// space of the presentation overlay. Flights must originate from these anchors
/// instead of reconstructing the photographed board with idealized geometry.
struct TablePoolAnchorPreferenceKey: PreferenceKey {
    static let defaultValue: [Pool: Anchor<CGPoint>] = [:]

    static func reduce(value: inout [Pool: Anchor<CGPoint>],
                       nextValue: () -> [Pool: Anchor<CGPoint>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

enum PochRing {
    /// Die 8 äußeren Mulden im Uhrzeigersinn ab 12 Uhr (konzept §5).
    static let anchors: [RingAnchor] = [
        RingAnchor(pool: .king,     angle: 0),
        RingAnchor(pool: .queen,    angle: 45),
        RingAnchor(pool: .mariage,  angle: 90),
        RingAnchor(pool: .jack,     angle: 135),
        RingAnchor(pool: .ten,      angle: 180),
        RingAnchor(pool: .sequence, angle: 225),
        RingAnchor(pool: .poch,     angle: 270),
        RingAnchor(pool: .ace,      angle: 315),
    ]
}

/// Calibrated overlay geometry for the rendered PM49 board asset.
/// The photographed board is slightly foreshortened, so a mathematical circle
/// does not line up with the visible well floors.
enum PM49Geometry {
    static func wellCenter(for pool: Pool, in size: CGFloat) -> CGPoint {
        let normalized: CGPoint
        switch pool {
        case .king:     normalized = CGPoint(x: 0.512, y: 0.140)
        case .queen:    normalized = CGPoint(x: 0.735, y: 0.224)
        case .mariage:  normalized = CGPoint(x: 0.842, y: 0.435)
        case .jack:     normalized = CGPoint(x: 0.744, y: 0.674)
        case .ten:      normalized = CGPoint(x: 0.513, y: 0.797)
        case .sequence: normalized = CGPoint(x: 0.251, y: 0.671)
        case .poch:     normalized = CGPoint(x: 0.167, y: 0.433)
        case .ace:      normalized = CGPoint(x: 0.293, y: 0.222)
        case .center:   normalized = CGPoint(x: 0.510, y: 0.474)
        }
        return CGPoint(x: normalized.x * size, y: normalized.y * size)
    }

    static func notationCenter(for pool: Pool, in size: CGFloat) -> CGPoint {
        let center = wellCenter(for: .center, in: size)
        let well = wellCenter(for: pool, in: size)
        let progress: CGFloat = 0.61
        return CGPoint(x: center.x + (well.x - center.x) * progress,
                       y: center.y + (well.y - center.y) * progress)
    }
}

/// Reuses the photographed PM49 material as the foreground wall of every well.
/// Tokens therefore disappear behind the real graphite and inlay edge instead
/// of receiving a synthetic UI border.
struct PM49FrontLipOverlay: View {
    let size: CGFloat
    var includesCenter = false

    var body: some View {
        Image("PochRingPM49")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .mask {
                Canvas { context, _ in
                    var path = Path()
                    for pool in Pool.allCases where pool != .center {
                        addLip(for: pool, radius: size * 0.083, to: &path)
                    }
                    if includesCenter {
                        addLip(for: .center, radius: size * 0.125, to: &path)
                    }
                    context.stroke(path,
                                   with: .color(.white),
                                   style: StrokeStyle(lineWidth: size * 0.018,
                                                      lineCap: .round))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func addLip(for pool: Pool, radius: CGFloat, to path: inout Path) {
        let center = PM49Geometry.wellCenter(for: pool, in: size)
        path.move(to: CGPoint(x: center.x - radius * 0.96,
                              y: center.y + radius * 0.14))
        path.addQuadCurve(
            to: CGPoint(x: center.x + radius * 0.96,
                        y: center.y + radius * 0.14),
            control: CGPoint(x: center.x, y: center.y + radius * 1.92)
        )
    }
}

extension Suit {
    var symbol: String {
        switch self {
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .spades: return "♠"
        case .clubs: return "♣"
        }
    }
    var isRed: Bool { self == .hearts || self == .diamonds }
}

extension Rank {
    /// Internationaler Index (A/K/Q/J/10/9/8/7).
    var index: String {
        switch self {
        case .ace: return "A"
        case .king: return "K"
        case .queen: return "Q"
        case .jack: return "J"
        case .ten: return "10"
        case .nine: return "9"
        case .eight: return "8"
        case .seven: return "7"
        }
    }
}
