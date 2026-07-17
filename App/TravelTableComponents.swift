import Foundation

/// Semantische 8+1-Topologie von Track B. Diese Datei enthält bewusst keine
/// sichtbare Schalen- oder Münzdarstellung, solange deren Material nicht durch
/// die menschliche Ästhetikabnahme freigegeben ist.
enum TravelCompartment: String, CaseIterable, Identifiable, Sendable {
    case king
    case queen
    case mariage
    case jack
    case ten
    case sequence
    case poch
    case ace
    case center

    var id: Self { self }

    static let outerClockwise: [Self] = [
        .king, .queen, .mariage, .jack,
        .ten, .sequence, .poch, .ace
    ]
}

struct TravelNormalizedPoint: Equatable, Sendable {
    let x: Double
    let y: Double
}

enum TravelTableGeometry {
    static let compartments = TravelCompartment.outerClockwise + [.center]

    static func center(for compartment: TravelCompartment) -> TravelNormalizedPoint {
        switch compartment {
        case .king:     .init(x: 0.500, y: 0.145)
        case .queen:    .init(x: 0.716, y: 0.225)
        case .mariage:  .init(x: 0.826, y: 0.430)
        case .jack:     .init(x: 0.748, y: 0.666)
        case .ten:      .init(x: 0.520, y: 0.790)
        case .sequence: .init(x: 0.280, y: 0.704)
        case .poch:     .init(x: 0.195, y: 0.486)
        case .ace:      .init(x: 0.270, y: 0.252)
        case .center:   .init(x: 0.500, y: 0.480)
        }
    }

    static func normalizedFloorRadius(for compartment: TravelCompartment) -> Double {
        compartment == .center ? 0.142 : 0.091
    }

    static func normalizedWellDiameter(for compartment: TravelCompartment) -> Double {
        compartment == .center ? 0.318 : 0.212
    }
}

struct TravelCentScratch: Equatable, Sendable {
    let angle: Double
    let offset: Double
    let length: Double
    let opacity: Double
}

/// Kontrollierte Oberflächenvariation einer gleichwertigen 1-Cent-Münze. Die
/// Werte steuern später freigegebene Rastervarianten, nicht gezeichnete Tokens.
struct TravelCentVariant: Equatable, Sendable {
    let rotation: Double
    let patina: Double
    let oxidation: Double
    let edgeWear: Double
    let residualGloss: Double
    let reliefRotation: Double
    let scratches: [TravelCentScratch]

    static func resolve(seed: UInt64, index: Int) -> Self {
        var random = TravelStableRandom(
            seed: seed ^ UInt64(truncatingIfNeeded: index &* 0x45D9F3B)
        )
        let scratches = (0..<(2 + Int(random.next() % 3))).map { _ in
            TravelCentScratch(
                angle: random.unit(in: -68...68),
                offset: random.unit(in: -0.32...0.32),
                length: random.unit(in: 0.28...0.68),
                opacity: random.unit(in: 0.10...0.26)
            )
        }
        return Self(
            rotation: random.unit(in: -22...22),
            patina: random.unit(in: 0.08...0.42),
            oxidation: random.unit(in: 0.03...0.30),
            edgeWear: random.unit(in: 0.04...0.34),
            residualGloss: random.unit(in: 0.05...0.28),
            reliefRotation: random.unit(in: 0...360),
            scratches: scratches
        )
    }
}

struct TravelCoinRestingPose: Equatable, Sendable {
    let offset: TravelNormalizedPoint
    let rotation: Double
    let elevation: Double
    let variant: TravelCentVariant
}

enum TravelCoinLayout {
    static let capacity = 12

    private static let slots: [(x: Double, y: Double, angle: Double, elevation: Double)] = [
        ( 0.00,  0.00,  -3, 0.00), (-0.48,  0.13,   6, 0.02),
        ( 0.47,  0.16,  -8, 0.04), (-0.22, -0.43,  11, 0.06),
        ( 0.29, -0.40,  -4, 0.08), ( 0.02,  0.52,   8, 0.10),
        (-0.57, -0.18, -10, 0.12), ( 0.58, -0.13,   5, 0.14),
        (-0.43,  0.49,   3, 0.16), ( 0.45,  0.47,  -7, 0.18),
        ( 0.05, -0.61,  10, 0.20), (-0.25,  0.63,  -5, 0.22)
    ]

    static func poses(count: Int,
                      seed: UInt64,
                      compartment: TravelCompartment) -> [TravelCoinRestingPose] {
        let safeCount = min(max(count, 0), capacity)
        let compartmentSeed = seed ^ stableSalt(for: compartment)
        return slots.prefix(safeCount).enumerated().map { index, slot in
            let variant = TravelCentVariant.resolve(seed: compartmentSeed, index: index)
            return TravelCoinRestingPose(
                offset: .init(x: slot.x, y: slot.y),
                rotation: slot.angle + variant.rotation,
                elevation: slot.elevation,
                variant: variant
            )
        }
    }

    private static func stableSalt(for compartment: TravelCompartment) -> UInt64 {
        switch compartment {
        case .king:     0xA24BAED4963EE407
        case .queen:    0x9FB21C651E98DF25
        case .mariage:  0xC13FA9A902A6328F
        case .jack:     0x91E10DA5C79E7B1D
        case .ten:      0xD1B54A32D192ED03
        case .sequence: 0xABC98388FB8FAC03
        case .poch:     0x8CB92BA72F3D8DD7
        case .ace:      0xDB4F0B9175AE2165
        case .center:   0xBBE0563303A4615F
        }
    }
}

private struct TravelStableRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func unit(in range: ClosedRange<Double>) -> Double {
        let fraction = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    }
}
