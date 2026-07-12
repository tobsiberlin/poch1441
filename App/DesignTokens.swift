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

    // Geführte Runde: Kontext bleibt sichtbar, konkurriert aber nicht mit dem Lernschritt.
    static let guidedFocusBlur: CGFloat = 0.8
    static let guidedFocusOpacity: Double = 0.58
    static let guidedFocusTransition: Double = 0.32

    // Ring-Geometrie (konzept §5): nahezu full-width wie der Mockup-Anker,
    // ohne die Portrait-Safe-Area zu verletzen.
    static let ringRadius: CGFloat = 158
    static let tileDiameter: CGFloat = 56
    static let centerDiameter: CGFloat = 84
    static let tileCorner: CGFloat = 16
    static let phase2BoardScale: CGFloat = 0.60
    static let phase2StageHeight: CGFloat = 246

    // Gefuehrte Melde-Runde: eigene Komposition statt der tieferen Position des
    // regulaeren Austeilrituals. Brett, Spotlight und Coach verwenden dieselbe Geometrie.
    static let guidedMeldBoardScale: CGFloat = 0.92
    static let guidedMeldBoardOffsetY: CGFloat = 8
    static let guidedMeldFocusTop: CGFloat = 184
    static let guidedMeldCoachGap: CGFloat = 82

    // Phase-2-Timing (Parameter-Lock §4: Änderung nur nach Vorher/Nachher-Vergleich).
    /// Feder des wachsenden Poch-Potts bei neuen Einsätzen.
    static let p2PotSpring: Double = 0.48
    /// Flug der Poch-Chips in die violette Mulde: klarer Vorschub mit ruhigem Einrasten.
    static let p2PochFlight: Double = 0.72
    /// Materialkontakt liegt exakt nach der ersten vollständig angekommenen Münze.
    static let p2PochImpactDelay: Double = 0.72
    /// Reaktion bleibt bis nach Materialkontakt und Mimikausschlag lesbar stehen.
    static let p2ReactionHold: Double = 0.92

    // Phasen-Morph (§5b, Parameter-Lock §4): Ring/Tokens fliegen zwischen den Akten.
    static let aktMorph: Double = 0.68

    // Phase-1-Deal / Trumpf-Beat (§6a, Parameter-Lock - Tobsi-Entscheide).
    /// Kaskaden-Takt des Austeilens: bewusst sichtbar, damit Kartenruecken als
    /// Deal-Ritual wirken statt als technischer Zaehlersprung.
    static let p1DealStep: Double = 0.18
    static let p1GuidedDealStep: Double = 0.62
    static let p1GuidedDealFinishStep: Double = 0.24
    /// Flugdauer einer einzelnen Karte vom Stapel in die Hand.
    static let p1Flight: Double = 0.56
    /// Freeze vor dem Trumpf-Flip: 150 ms.
    static let p1TrumpFreeze: Double = 0.68
    /// Radialer Lichtpuls übers Brett nach dem Trumpf-Flip.
    static let p1Pulse: Double = 0.6
    /// Minimale Haptik-Kadenz für schnelle Abrechnungsserien. Beim Austeilen
    /// wird Haptik direkt an die tatsächlich gelandete Karte gekoppelt.
    static let hapticCadence: Double = 0.11
    /// Melde-Strom (§6a b): Takt pro Meldung (Mulde pulst, Münzen fliegen, Zähler rollt).
    static let p1MeldStep: Double = 1.08

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
    static let p1CoinFlight: Double = 0.70

    // Phase-3-Timing (Parameter-Lock §4, konzept §6c - Tobsi-Entscheide).
    /// Kaskaden-Takt der Zwangskarten: jede Karte landet sichtbar, bevor die
    /// naechste startet. Das verhindert ueberlagerte Fluege und Geisterkarten.
    static let p3CascadeStep: Double = 0.64
    /// Sichtbarer Flug einer Karte vom Sitz in den zentralen Kettenfächer.
    static let p3CardFlight: Double = 0.54
    /// Der Faecher uebernimmt die Karte kurz vor dem vollstaendigen Ausblenden
    /// der Flugkarte. So gibt es weder Doppelbild noch sichtbare Luecke.
    static let p3CardSettleDelay: Double = 0.49
    /// Beat-Drop am Kettenriss: 350 ms Stille, Stopper glüht golden, Anspielrecht wandert.
    static let p3BeatDrop: Double = 0.52
    /// Die letzte Karte bleibt als Abschlussbild stehen, bevor die Abrechnung beginnt.
    static let p3FinalCardHold: Double = 0.92
    /// Eiszeit-Vakuum (§6c c, Tobsi-Entscheid): bewusste Zäsur nach dem Freeze.
    static let p3Vakuum: Double = 0.66
    /// Straf-Strom: Haptik-Ticks gedeckelt (viele Restkarten = beschleunigt, nie zäh).
    static let p3PunishTickCap = 12
    /// Straf-/Centerpot-Flug: parallel genug fuer Tempo, lang genug fuer Richtung.
    static let p3PunishFlight: Double = 0.78
    /// Winner-Impact nach den ersten ankommenden Chips.
    static let p3PunishImpactDelay: Double = 0.76
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
