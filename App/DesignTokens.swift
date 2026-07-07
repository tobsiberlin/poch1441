import SwiftUI

/// Jewel-Farbwelt + Layout-Konstanten (konzept §5). Matte, satte Juwelen-Töne auf
/// fast-schwarzem Grund - NIE Neon.
enum Tokens {
    static let bgDark        = Color(hex: 0x0B0E14)
    // Material-Tiefe (Review-Konsens: warmes Tinten-Schwarz + Vignette statt Flat-#000).
    static let bgLift        = Color(hex: 0x15121A)  // leicht gehobene, warme Mitte (Bühnenlicht)
    static let bgDeep        = Color(hex: 0x07060A)  // tiefe, warme Ränder (Vignette)
    static let jewelGold     = Color(hex: 0xC5A059)  // die 5 Bilder (A/K/Q/J/10)
    static let jewelRose     = Color(hex: 0x8E2A43)  // Mariage
    static let jewelSmaragd  = Color(hex: 0x1A5E4E)  // Sequenz
    static let jewelAmethyst = Color(hex: 0x4A2E65)  // Poch
    static let jewelPlatin   = Color(hex: 0xE2E8F0)  // Mitte / Held
    static let slate         = Color(hex: 0x6B7280)  // inaktiv / entsättigt

    // Vivid-Varianten (Neon/Vivid-Electronic §7): dieselben Hue-Familien, aber
    // gesättigt-leuchtend statt matt - für das strahlende Theme.
    static let goldVivid     = Color(hex: 0xF0CE7A)
    static let roseVivid     = Color(hex: 0xE24E7B)
    static let smaragdVivid  = Color(hex: 0x2CD4A8)
    static let amethystVivid = Color(hex: 0xA06BE0)

    // Ring-Geometrie (konzept §5): R = 130, Tiles Ø 54, Mitte Ø 76.
    static let ringRadius: CGFloat = 130
    static let tileDiameter: CGFloat = 54
    static let centerDiameter: CGFloat = 76
    static let tileCorner: CGFloat = 16

    // Phase-2-Timing (Parameter-Lock §4: Änderung nur nach Vorher/Nachher-Vergleich).
    /// Feder des wachsenden Poch-Potts bei neuen Einsätzen.
    static let p2PotSpring: Double = 0.35

    // Phase-3-Timing (Parameter-Lock §4, konzept §6c - Tobsi-Entscheide).
    /// Kaskaden-Takt der Zwangskarten: konstant 180 ms/Karte (Zähl-Lesbarkeit vor Whoosh).
    static let p3CascadeStep: Double = 0.18
    /// Beat-Drop am Kettenriss: 350 ms Stille, Stopper glüht golden, Anspielrecht wandert.
    static let p3BeatDrop: Double = 0.35
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}
