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

    /// Vivid-Variante der Kategorie-Farbe (Neon-Theme §7): dieselbe Hue, strahlend.
    var jewelVivid: Color {
        switch self {
        case .ace, .king, .queen, .jack, .ten: return Tokens.goldVivid
        case .mariage:  return Tokens.roseVivid
        case .sequence: return Tokens.smaragdVivid
        case .poch:     return Tokens.amethystVivid
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
