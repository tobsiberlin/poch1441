import SwiftUI

/// Jewel-Farbwelt + Layout-Konstanten (konzept §5). Matte, satte Juwelen-Töne auf
/// fast-schwarzem Grund.
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

    // Lesefarben für Text und Fokus auf dunklem Grund. Die Materialfarben bleiben
    // bewusst tief; UI-Typografie braucht dagegen verlässlichen Kontrast.
    static let amethystText  = Color(hex: 0xA98BD0)
    static let smaragdText   = Color(hex: 0x58A58C)

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
    // Der kompakte Phase-2-Auftritt folgt dem freigegebenen Mockup: Die Disc ist
    // ein präziser Tischanker, aber nicht die dominante Vollbildfläche aus Phase 1.
    static let phase2BoardScale: CGFloat = 0.45
    static let phase2StageHeight: CGFloat = 246
    static let phase2CompactHeight: CGFloat = 760
    static let phase2OpponentRowHeight: CGFloat = 116
    static let phase2OpponentGapCompact: CGFloat = 8
    static let phase2OpponentGapRegular: CGFloat = 18
    static let phase2HandReservedHeight: CGFloat = 176

    // Gefuehrte Melde-Runde: eigene Komposition statt der tieferen Position des
    // regulaeren Austeilrituals. Brett, Spotlight und Coach verwenden dieselbe Geometrie.
    static let guidedMeldBoardScale: CGFloat = 0.92
    static let guidedMeldBoardOffsetY: CGFloat = 8
    static let guidedMeldFocusTop: CGFloat = 184
    static let guidedMeldCoachGap: CGFloat = 34
    static let guidedMeldLearningBoardMin: CGFloat = 236
    static let guidedMeldLearningBoardMax: CGFloat = 306
    static let guidedMeldLearningCoachHeight: CGFloat = 138
    static let guidedMeldLearningHandCompact: CGFloat = 112
    static let guidedMeldLearningHandRegular: CGFloat = 146
    static let guidedMeldLearningGap: CGFloat = 7
    static let guidedOpeningTokenSize: CGFloat = 38
    static let guidedOpeningSourceGap: CGFloat = 66
    static let guidedOpeningSnapRadius: CGFloat = 58
    /// One player's nine antes arrive as a compact radial wave. The short
    /// stagger preserves source-to-target causality without turning 36 tokens
    /// into a long unskippable cutscene.
    static let guidedAnteFlight: Double = 0.34
    static let guidedAnteStagger: Double = 0.045
    static let guidedAnteWaveRest: Double = 0.18
    /// DEBUG motion-review pauses. They keep each cause/effect state readable
    /// in simulator recordings without affecting the interactive tutorial.
    static let guidedQAStateHold: Double = 0.86
    static let guidedQAOutcomeHold: Double = 1.10
    /// Der letzte Melde-Hinweis verlässt zuerst die Bühne. Erst danach zieht
    /// sich das Brett in die Poch-Komposition zusammen.
    static let guidedPhaseHandoffRest: Double = 0.24

    // Physische Spielsteine. Außenmulden und Mitte verwenden denselben
    // gedachten Durchmesser; nur der verfügbare Ablageraum unterscheidet sich.
    /// R1 füllt rund 41 % der 56-pt-Außenmulde. Derselbe physische
    /// Durchmesser gilt auch in der größeren Mitte.
    static let tableTokenDiameter: CGFloat = 23
    static let tableTokenToFloorRatio: CGFloat = 0.60
    static let tableTokenOverlap: CGFloat = 0.40
    static let outerWellFloorRatio: CGFloat = 0.68

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
    static let p1DealStep: Double = 0.32
    static let p1GuidedDealStep: Double = 0.62
    static let p1GuidedDealFinishStep: Double = 0.24
    /// Flugdauer einer einzelnen Karte vom Stapel in die Hand.
    static let p1Flight: Double = 0.42
    /// Freeze vor dem Trumpf-Flip: 150 ms.
    static let p1TrumpFreeze: Double = 0.68
    /// Radialer Lichtpuls übers Brett nach dem Trumpf-Flip.
    static let p1Pulse: Double = 0.6
    /// Minimale Haptik-Kadenz für schnelle Abrechnungsserien. Beim Austeilen
    /// wird Haptik direkt an die tatsächlich gelandete Karte gekoppelt.
    static let hapticCadence: Double = 0.11
    /// Melde-Strom (§6a b): Takt pro Meldung (Mulde pulst, Münzen fliegen, Zähler rollt).
    static let p1MeldStep: Double = 1.08

    /// Große Auszahlungen bleiben selten, werden aber ausschließlich über Gewicht,
    /// Kontakt und Materialkante betont - nie über Partikel, Shake oder Screen-Flash.
    static let grandPayoutThreshold = 12

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
