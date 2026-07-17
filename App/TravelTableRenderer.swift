import Foundation
import SwiftUI

/// Dynamisch belegbare Track-B-Schale. Artwork trägt ausschließlich Material;
/// Beschriftung, Zählstand und Münzlage bleiben reproduzierbare UI-Ebenen.
struct TravelSnackTray: View {
    let counts: [TravelCompartment: Int]
    let seed: UInt64
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Image("TravelTray")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .shadow(color: .black.opacity(0.48), radius: diameter * 0.055,
                        y: diameter * 0.035)

            ForEach(TravelTableGeometry.compartments) { compartment in
                TravelCoinPile(
                    count: counts[compartment, default: 0],
                    seed: seed,
                    compartment: compartment,
                    wellDiameter: diameter
                        * CGFloat(TravelTableGeometry.normalizedWellDiameter(for: compartment))
                )
                .position(point(for: compartment))
            }

            ForEach(TravelTableGeometry.compartments) { compartment in
                Text(compartment.displayLabel)
                    .font(.system(size: max(7, diameter * 0.025),
                                  weight: .heavy,
                                  design: .rounded))
                    .tracking(diameter * 0.0018)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .shadow(color: .black.opacity(0.92), radius: 2, y: 1)
                    .position(notationPoint(for: compartment))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "table.world.travel.accessibility",
                                   defaultValue: "Unterwegs-Tisch mit acht Feldern und Mitte"))
    }

    private func point(for compartment: TravelCompartment) -> CGPoint {
        let point = TravelTableGeometry.center(for: compartment)
        return CGPoint(x: diameter * CGFloat(point.x),
                       y: diameter * CGFloat(point.y))
    }

    private func notationPoint(for compartment: TravelCompartment) -> CGPoint {
        let center = TravelTableGeometry.center(for: compartment)
        if compartment == .center {
            let lift = TravelTableGeometry.normalizedFloorRadius(for: compartment) * 0.62
            return CGPoint(x: diameter * CGFloat(center.x),
                           y: diameter * CGFloat(center.y - lift))
        }

        let tableCenter = TravelTableGeometry.center(for: .center)
        let inward: Double
        switch compartment {
        case .mariage: inward = 0.34
        case .sequence: inward = 0.30
        case .poch: inward = 0.26
        default: inward = 0.20
        }
        return CGPoint(
            x: diameter * CGFloat(center.x + (tableCenter.x - center.x) * inward),
            y: diameter * CGFloat(center.y + (tableCenter.y - center.y) * inward)
        )
    }
}

private struct TravelCoinPile: View {
    let count: Int
    let seed: UInt64
    let compartment: TravelCompartment
    let wellDiameter: CGFloat

    var body: some View {
        let poses = TravelCoinLayout.poses(count: count,
                                           seed: seed,
                                           compartment: compartment)
        let coinSize = wellDiameter * (compartment == .center ? 0.26 : 0.42)
        ZStack {
            ForEach(Array(poses.enumerated()), id: \.offset) { index, pose in
                TravelCentCoin(assetIndex: assetIndex(for: index),
                               pose: pose,
                               size: coinSize)
                    .offset(x: coinSize * 0.58 * CGFloat(pose.offset.x),
                            y: coinSize * 0.58 * CGFloat(pose.offset.y))
                    .zIndex(pose.elevation)
            }
        }
        .frame(width: wellDiameter, height: wellDiameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func assetIndex(for index: Int) -> Int {
        let compartmentIndex = TravelTableGeometry.compartments
            .firstIndex(of: compartment) ?? 0
        return (Int(seed % 6) + index * 5 + compartmentIndex * 3) % 6
    }

    private var accessibilityLabel: String {
        let format = String(localized: "table.world.travel.fieldCoinCount",
                            defaultValue: "%1$@, Münzanzahl %2$lld")
        return String(format: format,
                      locale: Locale.current,
                      compartment.accessibilityLabel,
                      max(0, count))
    }
}

private extension TravelCompartment {
    var accessibilityLabel: String {
        switch self {
        case .king:
            String(localized: "table.world.travel.field.king", defaultValue: "König")
        case .queen:
            String(localized: "table.world.travel.field.queen", defaultValue: "Dame")
        case .mariage:
            String(localized: "table.world.travel.field.mariage", defaultValue: "Ehe")
        case .jack:
            String(localized: "table.world.travel.field.jack", defaultValue: "Bube")
        case .ten:
            String(localized: "table.world.travel.field.ten", defaultValue: "Zehn")
        case .sequence:
            String(localized: "table.world.travel.field.sequence", defaultValue: "Folge")
        case .poch:
            String(localized: "table.world.travel.field.poch", defaultValue: "Poch")
        case .ace:
            String(localized: "table.world.travel.field.ace", defaultValue: "Ass")
        case .center:
            String(localized: "table.world.travel.field.center", defaultValue: "Mitte")
        }
    }
}

struct TravelCentCoin: View {
    let assetIndex: Int
    let pose: TravelCoinRestingPose
    let size: CGFloat

    var body: some View {
        Image("TravelCent\(assetIndex)")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .rotationEffect(.degrees(pose.rotation))
            .shadow(color: .black.opacity(0.60),
                    radius: max(1, size * 0.055),
                    y: max(1, size * 0.045))
            .accessibilityHidden(true)
    }
}

extension TravelCompartment {
    fileprivate var displayLabel: String {
        switch self {
        case .king: "K"
        case .queen: "Q"
        case .mariage: String(localized: "pool.mariage.short", defaultValue: "EHE")
        case .jack: "J"
        case .ten: "10"
        case .sequence: String(localized: "pool.sequence.short", defaultValue: "FOLGE")
        case .poch: "POCH"
        case .ace: "A"
        case .center: String(localized: "board.center", defaultValue: "MITTE")
        }
    }
}

#if DEBUG
struct TravelTableMaterialProbe: View {
    private let counts: [TravelCompartment: Int] = [
        .king: 0, .queen: 3, .mariage: 2, .jack: 0,
        .ten: 1, .sequence: 3, .poch: 0, .ace: 2, .center: 9
    ]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width * 0.82, proxy.size.height * 0.82, 620)
            ZStack {
                LinearGradient(colors: [Color(hex: 0x16171A), Tokens.bgDeep],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                TravelSnackTray(counts: counts, seed: 1_441, diameter: side)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("travelTable.materialProbe")
    }
}
#endif
