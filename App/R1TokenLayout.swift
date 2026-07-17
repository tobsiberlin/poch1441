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
/// Die ersten vier Slots bilden keine Rosette: Ein Stein ruht in der Mitte, drei
/// weitere setzen sich mit ausreichend Abstand an seinen Rand. Die gesamte Gruppe
/// erhält je Mulde eine stabile Drehung, Spiegelung und kleine Setzabweichungen.
/// Bereits gelandete Steine behalten dadurch ihre Position, wenn der Zähler wächst,
/// ohne dass neun sichtbar geklonte Haufen entstehen.
enum R1TokenSlots {
    static let capacity = 12

    private static let slots: [(x: Double, y: Double, angle: Double, elevation: Double)] = [
        ( 0.00,  0.00,  -2, 0.00),
        (-0.49,  0.28,   4, 0.02),
        ( 0.49,  0.28,  -5, 0.04),
        ( 0.00, -0.56,   6, 0.06),
        (-0.51, -0.29,  -3, 0.08),
        ( 0.51, -0.29,   3, 0.10),
        ( 0.00,  0.58,  -6, 0.12),
        (-0.61,  0.00,   5, 0.14),
        ( 0.61,  0.00,  -4, 0.16),
        (-0.35,  0.52,   2, 0.18),
        ( 0.36,  0.52,  -5, 0.20),
        ( 0.34, -0.52,   4, 0.22)
    ]

    static func pose(for index: Int,
                     seed: UInt64 = 1_441,
                     compartment: TravelCompartment = .center) -> R1TokenRestingPose {
        let safeIndex = min(max(index, 0), capacity - 1)
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
        let jitterX = unit(itemSeed, shift: 12, in: -0.024...0.024)
        let jitterY = unit(itemSeed, shift: 33, in: -0.024...0.024)
        let rotationJitter = unit(itemSeed, shift: 45, in: -4.5...4.5)

        let sourceX = (mirrored ? -slot.x : slot.x) + jitterX
        let sourceY = slot.y + jitterY
        let radians = groupAngle * .pi / 180
        let x = sourceX * cos(radians) - sourceY * sin(radians)
        let y = sourceX * sin(radians) + sourceY * cos(radians)

        return R1TokenRestingPose(
            offset: CGSize(width: x, height: y),
            rotation: (mirrored ? -slot.angle : slot.angle) + groupAngle + rotationJitter,
            elevation: slot.elevation
        )
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
