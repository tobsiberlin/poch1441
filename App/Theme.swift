import PochKit
import SwiftUI

/// Übergangsname für bestehende View-Schnittstellen. Die Produktauswahl ist eine
/// `TableWorld`; eine dritte Farbstimmung oder regelrelevante Abzweigung existiert
/// nicht mehr.
typealias Theme = TableWorld

extension TableWorld {
    var isTravelTable: Bool { self == .unterwegs }

    /// Unterwegs bleibt etwas heller und unmittelbarer, ohne emissiven Casino-Glow.
    var tileGlow: CGFloat { isTravelTable ? 5 : 0 }
    var glowOpacity: Double { isTravelTable ? 0.24 : 0 }
    var tileFillOpacity: Double { isTravelTable ? 0.34 : 0.40 }
    var borderWidth: CGFloat { isTravelTable ? 1.25 : 1.5 }
    var ringLineOpacity: Double { isTravelTable ? 0.26 : 0.18 }
    var centerGlow: CGFloat { isTravelTable ? 8 : 10 }

    func tint(_ pool: Pool) -> Color { pool.jewel }

    var goldFocus: Color { Tokens.jewelGold }
    var roseFocus: Color { Tokens.jewelRose }
    var smaragdFocus: Color { Tokens.smaragdText }
    var amethystFocus: Color { Tokens.amethystText }
}
