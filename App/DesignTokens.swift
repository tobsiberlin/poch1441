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

    // Ring-Geometrie (konzept §5): R = 145, Tiles Ø 54, Mitte Ø 76.
    static let ringRadius: CGFloat = 145
    static let tileDiameter: CGFloat = 54
    static let centerDiameter: CGFloat = 76
    static let tileCorner: CGFloat = 16

    // Phase-2-Timing (Parameter-Lock §4: Änderung nur nach Vorher/Nachher-Vergleich).
    /// Feder des wachsenden Poch-Potts bei neuen Einsätzen.
    static let p2PotSpring: Double = 0.35

    // Phasen-Morph (§5b, Parameter-Lock §4): Ring/Tokens fliegen zwischen den Akten.
    static let aktMorph: Double = 0.55

    // Phase-1-Deal / Trumpf-Beat (§6a, Parameter-Lock - Tobsi-Entscheide).
    /// Kaskaden-Takt des Austeilens: 40 ms/Karte.
    static let p1DealStep: Double = 0.04
    /// Flugdauer einer einzelnen Karte vom Stapel in die Hand.
    static let p1Flight: Double = 0.14
    /// Freeze vor dem Trumpf-Flip: 150 ms.
    static let p1TrumpFreeze: Double = 0.15
    /// Radialer Lichtpuls übers Brett nach dem Trumpf-Flip.
    static let p1Pulse: Double = 0.6
    /// Haptik-Kadenz, von der Karten-Anzahl ENTKOPPELT (§6 Auflage 4): exakt 90 ms.
    static let hapticCadence: Double = 0.09
    /// Melde-Strom (§6a b): Takt pro Meldung (Mulde pulst, Münzen fliegen, Zähler rollt).
    static let p1MeldStep: Double = 0.55

    // Balatro-Kollaps Stufe 2 (§6a e, Parameter-Lock).
    /// Zünd-Schwelle: per Headless-Sim kalibriert (pochsim kollaps, 11.557 Runden,
    /// 8.7.2026): T=12 -> 16,2% Zünd-Rate (Zielband 15-20%, rares Ende - konzept §6
    /// Auflage 3). Bei Ante-Eskalation später dynamisch Richtung 15+.
    static let jackpotKollapsThreshold = 12
    /// Screen-Shake des Kollaps: 150 ms, 3 pt (konzept: 2-3 px) - reduceMotion: 0.
    static let kollapsShake: Double = 0.15
    static let kollapsShakeAmp: Double = 3
    /// Farbgetönter Vignetten-Flash ("Wimpernschlag"); reduceMotion: 50-ms-Dissolve.
    static let kollapsFlash: Double = 0.28

    // "Der Poch" (§6b Signaturgeste, Parameter-Lock): Tischschlag.
    /// Dauer des Tisch-Zitterns (nur Tisch-Welt, HUD ruhig).
    static let pochShake: Double = 0.30
    /// Amplitude des Zitterns in Punkten (reduceMotion: 0).
    static let pochShakeAmp: Double = 4
    /// Flugdauer der Münzen von der Mulde zum Spieler.
    static let p1CoinFlight: Double = 0.4

    // Phase-3-Timing (Parameter-Lock §4, konzept §6c - Tobsi-Entscheide).
    /// Kaskaden-Takt der Zwangskarten: konstant 180 ms/Karte (Zähl-Lesbarkeit vor Whoosh).
    static let p3CascadeStep: Double = 0.18
    /// Beat-Drop am Kettenriss: 350 ms Stille, Stopper glüht golden, Anspielrecht wandert.
    static let p3BeatDrop: Double = 0.35
    /// Eiszeit-Vakuum (§6c c, Tobsi-Entscheid): bewusste Zäsur nach dem Freeze.
    static let p3Vakuum: Double = 0.4
    /// Straf-Strom: Haptik-Ticks gedeckelt (viele Restkarten = beschleunigt, nie zäh).
    static let p3PunishTickCap = 12
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
