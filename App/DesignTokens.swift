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
    static let phase2BoardScale: CGFloat = 0.54
    static let phase2StageHeight: CGFloat = 260
    static let phase2CompactHeight: CGFloat = 760
    static let phase2OpponentRowHeight: CGFloat = 116
    static let phase2OpponentGapCompact: CGFloat = 8
    static let phase2OpponentGapRegular: CGFloat = 18
    static let phase2HandReservedHeight: CGFloat = 210
    static let phase2ResultHandReservedHeight: CGFloat = 154

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
    /// Im ersten Spiel setzt immer genau eine Person ein. Der größere Abstand
    /// hält höchstens drei Chips gleichzeitig in Bewegung; Quelle, Ziel und
    /// Spieler bleiben dadurch lesbar statt als radiale Salve zu erscheinen.
    static let guidedAnteFlight: Double = 0.32
    static let guidedAnteStagger: Double = 0.105
    static let guidedAnteWaveRest: Double = 0.22
    /// Reagiert während einer laufenden Welle zeitnah auf einen Wechsel der
    /// systemweiten Einstellung "Bewegung reduzieren".
    static let guidedAnteMotionPreferencePoll: Double = 0.05
    /// DEBUG motion-review pauses. They keep each cause/effect state readable
    /// in simulator recordings without affecting the interactive tutorial.
    static let guidedQAStateHold: Double = 0.86
    static let guidedQAOutcomeHold: Double = 1.10
    /// Der letzte Melde-Hinweis verlässt zuerst die Bühne. Erst danach zieht
    /// sich das Brett in die Poch-Komposition zusammen.
    static let guidedPhaseHandoffRest: Double = 0.24

    // Physische Spielsteine. Außenmulden und Mitte verwenden denselben
    // gedachten Durchmesser; nur der verfügbare Ablageraum unterscheidet sich.
    /// Die bestätigte Produktreferenz zeigt R1 mit rund 70-74 % der sichtbaren
    /// Muldenöffnung. Derselbe physische Durchmesser gilt auch in der Mitte.
    static let tableTokenDiameter: CGFloat = 40.5
    static let r1CompactTokenScale: CGFloat = 0.950
    static let tableTokenToFloorRatio: CGFloat = 0.74
    static let tableTokenOverlap: CGFloat = 0.40
    static let phase1OuterWellDiameter: CGFloat = 58
    static let phase1CenterWellDiameter: CGFloat = 88
    /// Die R1-PNGs besitzen einen 340er Produktionsrahmen; die maximale
    /// Alpha-Ausdehnung des Keramikkörpers misst rund 308 px. `size` bezeichnet
    /// deshalb die vollständige sichtbare Hüllkurve und bleibt im Mulden-Fit.
    static let r1AssetScale: CGFloat = 1.085
    static let r1MeasuredAlphaWidthRatio: CGFloat = 294.0 / 340.0
    /// Größter gemessener Abstand eines sichtbaren Alpha-Pixels vom
    /// Produktionsmittelpunkt, normiert auf den 340-px-Canvas.
    static let r1MeasuredAlphaRadiusRatio: CGFloat = 168.870 / 340.0
    /// Nur die textile Innenöffnung ist Ablagefläche. Der äußere Metallring
    /// gehört nicht zur Mulde und darf nie R1-Alpha zeigen.
    static let outerWellFloorRatio: CGFloat = 0.95
    /// Matte R1-Keramik. Die Materialbasis wird in `build_r1_ceramic_assets.py`
    /// gebacken; zur Laufzeit bleiben nur weltfeste Relief- und Kontakthinweise.
    static let r1NaturalFace = Color(hex: 0xDEDAD6)
    static let r1TerracottaFace = Color(hex: 0xB3775F)
    static let r1SageFace = Color(hex: 0x828776)
    static let r1SlateFace = Color(hex: 0x6F7074)
    static let r1OchreFace = Color(hex: 0xB58742)
    static let r1ContactShadowOpacity: Double = 0.86
    static let r1ContactShadowElevationFade: Double = 0.15
    static let r1ContactShadowRadiusRatio: CGFloat = 0.012
    static let r1ContactShadowXRatio: CGFloat = 0.014
    static let r1ContactShadowYRatio: CGFloat = 0.018
    static let r1CastShadowOpacity: Double = 0.62
    static let r1CastShadowElevationFade: Double = 0.05
    static let r1CastShadowRadiusRatio: CGFloat = 0.035
    static let r1CastShadowXRatio: CGFloat = 0.028
    static let r1CastShadowYRatio: CGFloat = 0.070
    /// Höher liegende R1 werfen einen weicheren, weiter versetzten Schatten auf
    /// die darunterliegende Scheibe; der Kontaktschatten bleibt lokal hart.
    static let r1CastShadowElevationRadiusRatio: CGFloat = 0.025
    static let r1CastShadowElevationXRatio: CGFloat = 0.014
    static let r1CastShadowElevationYRatio: CGFloat = 0.045
    /// Der maximale Viererstapel braucht bei 39 pt rund 1,45 pt sichtbaren Hub.
    /// Zusammen mit der gebackenen Seitenwand entsteht so eine lesbare Lage,
    /// ohne dass die Scheiben über den textilen Muldenboden hinauswandern.
    static let r1PileElevationLiftRatio: CGFloat = 0.310
    /// Außenmulden nutzen die textile Öffnung nahezu vollständig; die größere
    /// Mittelmulde darf den gleichen physischen Stapel weiter auffächern.
    /// Beide Werte bleiben innerhalb des aus Alpha-Hülle und Bodenradius
    /// berechneten Fits, sodass kein Stein über dem Metallring erscheint.
    static let r1OuterPileSpread: CGFloat = 0.82
    static let r1CenterPileSpread: CGFloat = 1.50
    /// Kleine Setzabweichung zur optischen Mitte des Textilbodens. Die räumliche
    /// Einfassung übernimmt der echte Asset-Metallring, nicht ein harter Offset.
    static let r1WellPileVerticalInsetRatio: CGFloat = 0.025
    /// Die große Innenmulde besitzt bereits eine gerichtete obere Wand. Ihr
    /// Stapel sitzt deshalb geometrisch exakt im gemeinsamen Mittelpunkt.
    static let r1CenterWellPileVerticalInsetRatio: CGFloat = 0
    // Track-A-Kamera. Der gesamte physische Stack wird gemeinsam gekippt, damit
    // Asset, Gravuren und ruhende Steine dieselbe Perspektive behalten.
    static let pochDiscPitch: Double = 16.0
    static let pochDiscPerspective: CGFloat = 0.24
    static let pochDiscStageScale: CGFloat = 1.052
    /// Das akzeptierte 1254er Asset enthält einen großen transparenten
    /// Produktionsrand. Der physische Außenring liegt bei (626, 590) mit
    /// Radius 489 px und wird hier auf den semantischen Disc-Raum normalisiert.
    static let pochDiscAssetScale: CGFloat = 1.26
    static let pochDiscAssetOffsetXRatio: CGFloat = 0.0010
    static let pochDiscAssetOffsetYRatio: CGFloat = 0.0372
    static let pochDiscSidewallExtensionRatio: CGFloat = 0.019
    static let pochDiscContactShadowRadiusRatio: CGFloat = 0.014
    static let pochDiscContactShadowXRatio: CGFloat = 0.006
    static let pochDiscContactShadowYRatio: CGFloat = 0.024
    static let pochDiscCastShadowRadiusRatio: CGFloat = 0.042
    static let pochDiscCastShadowXRatio: CGFloat = 0.025
    static let pochDiscCastShadowYRatio: CGFloat = 0.085

    // Phase-2-Timing (Parameter-Lock §4: Änderung nur nach Vorher/Nachher-Vergleich).
    /// Feder des wachsenden Poch-Potts bei neuen Einsätzen.
    static let p2PotSpring: Double = 0.48
    /// Flug der Poch-Chips in die violette Mulde: klarer Vorschub mit ruhigem Einrasten.
    static let p2PochFlight: Double = 0.72
    /// Materialkontakt liegt exakt nach der ersten vollständig angekommenen Münze.
    static let p2PochImpactDelay: Double = 0.72
    /// Gebündelte Auszahlung vom Poch-Pott zum Gewinner. Das Ergebnis steht
    /// bereits fest, daher bleibt dieser Weg knapper als der Einsatzflug.
    static let p2PayoutFlight: Double = 0.62
    static let p2PayoutStagger: Double = 0.05
    /// Reaktion bleibt bis nach Materialkontakt und Mimikausschlag lesbar stehen.
    static let p2ReactionHold: Double = 0.92

    // Phasen-Morph (§5b, Parameter-Lock §4): Ring/Tokens fliegen zwischen den Akten.
    static let aktMorph: Double = 0.68

    // Phase-1-Deal / Trumpf-Beat (§6a, Parameter-Lock - Tobsi-Entscheide).
    /// Kaskaden-Takt des Austeilens: bewusst sichtbar, damit Kartenruecken als
    /// Deal-Ritual wirken statt als technischer Zaehlersprung.
    static let p1DealStep: Double = 0.32
    /// Ein kurzer, wiederholbarer Rhythmus ersetzt das metronomische Austeilen.
    /// Der Mittelwert bleibt nahe am bisherigen 320-ms-Takt; nur Akzente und
    /// kleine Atempausen variieren, ohne die deterministische Regelrunde anzurühren.
    static let p1DealCadence: [Double] = [0.27, 0.31, 0.29, 0.38, 0.26, 0.33, 0.30, 0.36]
    static let p1GuidedDealStep: Double = 0.34
    static let p1GuidedDealFinishStep: Double = 0.09
    static let p1GuidedDealConcurrency = 4
    /// SwiftUI can occasionally suppress an animation-completion callback while
    /// UI automation snapshots a busy scene. A guided group still reaches its
    /// physical contact state after this bounded presentation deadline.
    static let p1GuidedDealRecoveryDeadline: Double = 0.86
    /// The opening montage earns attention, but never holds the first human
    /// decision hostage to a full-deck presentation.
    static let p1GuidedOpeningMontageMaximum: Double = 9.5
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
    static let p1GuidedMeldRecoveryDeadline: Double = 1.45
    /// Einzelne schwere R1 verlassen die Mulde leicht versetzt. Der letzte
    /// tatsächliche Kontakt schaltet erst danach den sichtbaren Gewinnerstack frei.
    static let p1MeldTokenDiameter: CGFloat = 31
    static let p1MeldTokenMinimumDiameter: CGFloat = 26
    static let p1MeldTokenMaximumDiameter: CGFloat = 39
    static let p1MeldOuterAnchorSpanRatio: CGFloat = 0.676
    static let p1MeldTokenStagger: Double = 0.12
    static let p1MeldPhysicalLimit = 5

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
