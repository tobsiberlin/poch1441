import PochKit
import SwiftUI

/// Zwei Gesichter, eine Geometrie (konzept §7): dieselben Jewel-Farben, einmal
/// **matt** (Premium) und einmal **strahlend/emissiv** (Vivid-Electronic, „Neon").
/// Light-Touch: kein Protocol auf Vorrat - nur ein Konfig-Wert, der die ViewModifier
/// steuert. Der Glow kommt IMMER in der eigenen Kategorie-Farbe eines Elements
/// (Gold glüht gold, Amethyst glüht violett) - nie ein fremdes Cyan (das wäre der
/// Cyber-Casino-Rückfall, den wir verwerfen).
enum Theme {
    case premium, neon

    var isNeon: Bool { self == .neon }

    /// Emissive Bloom (0 im Premium) - breit + intensiv, „Leuchten von innen".
    var tileGlow: CGFloat { isNeon ? 18 : 0 }
    var glowOpacity: Double { isNeon ? 1.0 : 0 }
    /// Neon: dunklerer Kern, damit der Glow trägt; Premium: matt-neutral.
    var tileFillOpacity: Double { isNeon ? 0.28 : 0.40 }
    var borderWidth: CGFloat { isNeon ? 2 : 1.5 }
    var ringLineOpacity: Double { isNeon ? 0.5 : 0.18 }
    /// Mitte-Aura-Radius.
    var centerGlow: CGFloat { isNeon ? 32 : 10 }

    /// Kategorie-Farbe je Theme: matt (Premium) vs. vivid/strahlend (Neon).
    func tint(_ pool: Pool) -> Color { isNeon ? pool.jewelVivid : pool.jewel }

    /// Lesbare Fokusfarben dürfen heller als das physische Material sein, bleiben
    /// im Premium-Theme aber nicht emissiv.
    var goldFocus: Color { isNeon ? Tokens.goldVivid : Tokens.jewelGold }
    var roseFocus: Color { isNeon ? Tokens.roseVivid : Tokens.jewelRose }
    var smaragdFocus: Color { isNeon ? Tokens.smaragdVivid : Tokens.smaragdText }
    var amethystFocus: Color { isNeon ? Tokens.amethystVivid : Tokens.amethystText }
}
