import SwiftUI

/// Gemeinsame, identitätsneutrale Ruhegeometrie für Austeilflug und Tableau.
/// Sie kennt nur öffentliche Slot-Indizes - niemals Farbe, Rang oder Kartenwert.
enum DealTableauLayout {
    struct Pose: Equatable {
        let offset: CGSize
        let rotationDegrees: Double
    }

    struct FlightProfile: Equatable {
        let pointsPerSecond: CGFloat
        let arcLift: CGFloat
        let lateralBias: CGFloat
        let launchDelay: Double
        let midflightTwistDegrees: Double
    }

    /// A compact opponent hand still reads as one intentional fan, but no two
    /// seats receive the exact same machine-perfect arrangement. Variation is
    /// derived exclusively from public presentation coordinates, so hidden card
    /// identity can never influence the pose.
    static func opponentPose(
        slot: Int,
        totalSlots: Int = 8,
        seat: Int = 0,
        roundGeneration: Int = 0
    ) -> Pose {
        let total = max(1, totalSlots)
        let clampedSlot = min(max(slot, 0), total - 1)
        let center = CGFloat(total - 1) / 2
        let distance = CGFloat(clampedSlot) - center
        let normalized = center > 0 ? distance / center : 0
        let horizontalVariation = centeredVariation(
            roundGeneration: roundGeneration,
            sequence: clampedSlot,
            seat: seat,
            slot: clampedSlot,
            channel: 0
        ) * 1.15
        let verticalVariation = centeredVariation(
            roundGeneration: roundGeneration,
            sequence: clampedSlot,
            seat: seat,
            slot: clampedSlot,
            channel: 1
        ) * 1.8
        let angleVariation = Double(centeredVariation(
            roundGeneration: roundGeneration,
            sequence: clampedSlot,
            seat: seat,
            slot: clampedSlot,
            channel: 2
        )) * 0.8
        return Pose(
            offset: CGSize(width: normalized * 25 + horizontalVariation,
                           height: -20 + abs(normalized) * 3 + verticalVariation),
            rotationDegrees: Double(normalized) * 12 + angleVariation
        )
    }

    static func humanPose(slot: Int, totalSlots: Int, cardScale: CGFloat) -> Pose {
        let total = max(1, totalSlots)
        let clampedSlot = min(max(slot, 0), total - 1)
        let progress = total > 1
            ? CGFloat(clampedSlot) / CGFloat(total - 1)
            : 0.5
        let spreadDegrees = min(Double(total) * 7, 38)
        let totalWidth = min(CGFloat(total) * 30, 224) * (cardScale / 1.62)
        return Pose(
            offset: CGSize(width: total > 1 ? -totalWidth / 2 + progress * totalWidth : 0,
                           height: 0),
            rotationDegrees: total > 1
                ? -spreadDegrees / 2 + Double(progress) * spreadDegrees
                : 0
        )
    }

    /// Subtle dealing signatures prevent the repeated three-path cadence from
    /// reading as a conveyor belt. Values remain deliberately narrow: the card
    /// always telegraphs its destination and settles into the exact target pose.
    static func flightProfile(
        roundGeneration: Int,
        sequence: Int,
        seat: Int,
        slot: Int
    ) -> FlightProfile {
        FlightProfile(
            pointsPerSecond: 610 + unitVariation(
                roundGeneration: roundGeneration,
                sequence: sequence,
                seat: seat,
                slot: slot,
                channel: 3
            ) * 82,
            arcLift: -3.5 + unitVariation(
                roundGeneration: roundGeneration,
                sequence: sequence,
                seat: seat,
                slot: slot,
                channel: 4
            ) * 8,
            lateralBias: centeredVariation(
                roundGeneration: roundGeneration,
                sequence: sequence,
                seat: seat,
                slot: slot,
                channel: 5
            ) * 10,
            launchDelay: Double(unitVariation(
                roundGeneration: roundGeneration,
                sequence: sequence,
                seat: seat,
                slot: slot,
                channel: 6
            )) * 0.022,
            midflightTwistDegrees: Double(centeredVariation(
                roundGeneration: roundGeneration,
                sequence: sequence,
                seat: seat,
                slot: slot,
                channel: 7
            )) * 2.6
        )
    }

    private static func centeredVariation(
        roundGeneration: Int,
        sequence: Int,
        seat: Int,
        slot: Int,
        channel: Int
    ) -> CGFloat {
        unitVariation(
            roundGeneration: roundGeneration,
            sequence: sequence,
            seat: seat,
            slot: slot,
            channel: channel
        ) * 2 - 1
    }

    private static func unitVariation(
        roundGeneration: Int,
        sequence: Int,
        seat: Int,
        slot: Int,
        channel: Int
    ) -> CGFloat {
        var value = UInt64(truncatingIfNeeded: roundGeneration) &* 0x9E3779B97F4A7C15
        value ^= UInt64(truncatingIfNeeded: sequence) &* 0xBF58476D1CE4E5B9
        value ^= UInt64(truncatingIfNeeded: seat) &* 0x94D049BB133111EB
        value ^= UInt64(truncatingIfNeeded: slot) &* 0xD6E8FEB86659FD93
        value ^= UInt64(truncatingIfNeeded: channel) &* 0xA0761D6478BD642F
        value ^= value >> 30
        value &*= 0xBF58476D1CE4E5B9
        value ^= value >> 27
        value &*= 0x94D049BB133111EB
        value ^= value >> 31
        let fraction = Double(value & 0x00FF_FFFF) / Double(0x00FF_FFFF)
        return CGFloat(fraction)
    }
}
