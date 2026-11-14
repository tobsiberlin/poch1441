import CoreGraphics
import Foundation

struct R1TokenRestingPose: Equatable, Sendable {
    /// Mittelpunkt relativ zum Durchmesser eines einzelnen R1-Steins.
    let offset: CGSize
    let rotation: Double
    let elevation: Double
}

/// Deterministische, muldenspezifische Endlagen für die keramischen R1-Steine.
///
/// Vier vorbereitete, kompakte Haufentypen verhindern die geklonte Rosette. Die
/// gesamte Gruppe erhält je Mulde eine stabile Drehung, Spiegelung und kleine
/// Setzabweichungen. Bereits gelandete Steine behalten dadurch ihre Position,
/// wenn der Zähler wächst.
enum R1TokenSlots {
    static let capacity = 12

    private typealias Slot = (x: Double, y: Double, angle: Double, elevation: Double)

    /// Dichte, gerichtete Stapel wie in der Produktreferenz. Die ersten zwei
    /// Slots bilden eine klar lesbare Zweierlage; drei und vier erweitern sie
    /// asymmetrisch statt eine Blütenrosette um einen Mittelpunkt zu bauen.
    private static let templates: [[Slot]] = [
        [
            (-0.160,  0.040, -12, 0.00), ( 0.160, -0.030,   8, 0.04),
            (-0.035, -0.155,  14, 0.08), ( 0.055,  0.150,  -6, 0.12),
            ( 0.000,  0.000,   3, 0.14), (-0.120, -0.100,  -9, 0.15),
            ( 0.120,  0.100,  11, 0.16), (-0.070,  0.130, -15, 0.17),
            ( 0.080, -0.130,   6, 0.18), (-0.160,  0.000,  13, 0.19),
            ( 0.160,  0.000,  -7, 0.20), ( 0.000,  0.160,  10, 0.22)
        ],
        [
            (-0.160, -0.030,   9, 0.00), ( 0.160,  0.035, -13, 0.04),
            ( 0.020, -0.160,   5, 0.08), (-0.055,  0.150,  14, 0.12),
            ( 0.000, -0.010,  -4, 0.14), ( 0.125, -0.090,  12, 0.15),
            (-0.115,  0.105,  -8, 0.16), ( 0.075,  0.135,   7, 0.17),
            (-0.080, -0.130,  15, 0.18), ( 0.155,  0.005, -11, 0.19),
            (-0.155, -0.005,   6, 0.20), ( 0.000,  0.155,  -5, 0.22)
        ],
        [
            (-0.155,  0.055, -15, 0.00), ( 0.160, -0.025,   7, 0.04),
            (-0.070, -0.145,  11, 0.08), ( 0.035,  0.155,  -9, 0.12),
            ( 0.010,  0.000,   4, 0.14), ( 0.125,  0.090, -12, 0.15),
            (-0.135, -0.075,   8, 0.16), ( 0.090, -0.125,  14, 0.17),
            (-0.045,  0.145,  -6, 0.18), ( 0.160,  0.000,  10, 0.19),
            (-0.160,  0.000, -14, 0.20), ( 0.000, -0.160,   5, 0.22)
        ],
        [
            (-0.160,  0.010,  13, 0.00), ( 0.160, -0.040, -10, 0.04),
            ( 0.055,  0.150,   6, 0.08), (-0.045, -0.155, -14, 0.12),
            ( 0.000,  0.005,  -3, 0.14), (-0.110,  0.110,  15, 0.15),
            ( 0.125,  0.090,  -7, 0.16), (-0.100, -0.120,  10, 0.17),
            ( 0.085, -0.130, -12, 0.18), (-0.160, -0.005,   5, 0.19),
            ( 0.160,  0.005,  14, 0.20), ( 0.000,  0.160,  -8, 0.22)
        ]
    ]

    static func pose(for index: Int,
                     seed: UInt64 = 1_441,
                     compartment: TravelCompartment = .center) -> R1TokenRestingPose {
        let safeIndex = min(max(index, 0), capacity - 1)
        let slots = template(for: compartment)
        return resolvedPose(slot: slots[safeIndex],
                            index: safeIndex,
                            seed: seed,
                            compartment: compartment)
    }

    static func offset(for index: Int,
                       tokenDiameter: CGFloat,
                       seed: UInt64 = 1_441,
                       compartment: TravelCompartment = .center) -> CGSize {
        let pose = pose(for: index, seed: seed, compartment: compartment)
        return CGSize(width: pose.offset.width * tokenDiameter,
                      height: pose.offset.height * tokenDiameter)
    }

    static func layout(for count: Int,
                       seed: UInt64 = 1_441,
                       compartment: TravelCompartment = .center) -> [R1TokenRestingPose] {
        guard count > 0 else { return [] }
        let slots = template(for: compartment)
        return slots.prefix(min(count, capacity)).enumerated().map { index, slot in
            resolvedPose(slot: slot,
                         index: index,
                         seed: seed,
                         compartment: compartment)
        }
    }

    private static func resolvedPose(
        slot: (x: Double, y: Double, angle: Double, elevation: Double),
        index: Int,
        seed: UInt64,
        compartment: TravelCompartment
    ) -> R1TokenRestingPose {
        let pileSeed = mixed(seed ^ stableSalt(for: compartment))
        let mirrored = pileSeed & 1 == 1
        let groupAngle = Double((pileSeed >> 8) % 3_600) / 10
        let itemSeed = mixed(pileSeed ^ UInt64(truncatingIfNeeded: index &* 0x45D9F3B))
        let jitterX = unit(itemSeed, shift: 12, in: -0.006...0.006)
        let jitterY = unit(itemSeed, shift: 33, in: -0.006...0.006)
        let rotationJitter = unit(itemSeed, shift: 45, in: -4.5...4.5)

        let sourceX = (mirrored ? -slot.x : slot.x) + jitterX
        let sourceY = slot.y + jitterY
        let radians = groupAngle * .pi / 180
        let x = sourceX * cos(radians) - sourceY * sin(radians)
        let y = sourceX * sin(radians) + sourceY * cos(radians)

        return R1TokenRestingPose(
            offset: CGSize(width: x, height: y),
            rotation: (mirrored ? -slot.angle : slot.angle) + rotationJitter,
            elevation: slot.elevation
        )
    }

    private static func template(for compartment: TravelCompartment) -> [Slot] {
        let index: Int
        switch compartment {
        case .king, .ten, .center: index = 0
        case .queen, .sequence: index = 1
        case .mariage, .ace: index = 2
        case .jack, .poch: index = 3
        }
        return templates[index]
    }

    private static func mixed(_ input: UInt64) -> UInt64 {
        var value = input &+ 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    private static func unit(_ value: UInt64,
                             shift: UInt64,
                             in range: ClosedRange<Double>) -> Double {
        let fraction = Double((value >> shift) & 0xFFFF) / Double(0xFFFF)
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
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
