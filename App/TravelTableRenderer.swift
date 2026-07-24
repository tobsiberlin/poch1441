import Foundation
import SwiftUI

/// Dynamisch belegbare Track-B-Schale. Artwork trägt ausschließlich Material;
/// Beschriftung, Zählstand und Münzlage bleiben reproduzierbare UI-Ebenen.
struct TravelSnackTray: View {
    let counts: [TravelCompartment: Int]
    let seed: UInt64
    let diameter: CGFloat

    var body: some View {
        let layouts = projectedLayouts
        ZStack {
            TableWorldBoardBase(world: .unterwegs, diameter: diameter)

            ForEach(layouts) { layout in
                TravelCoinPile(
                    count: counts[layout.compartment, default: 0],
                    seed: seed,
                    compartment: layout.compartment,
                    wellDiameter: layout.wellDiameter,
                    layoutSize: layout.contentSize,
                    restSlotOffsets: layout.restSlotOffsets,
                    hitTestOffsets: layout.floorOffsets
                )
                .position(layout.anchors.wellCenter)
            }

            ForEach(layouts) { layout in
                Text(layout.compartment.displayLabel)
                    .font(.system(size: max(7, diameter * 0.025),
                                  weight: .heavy,
                                  design: .rounded))
                    .tracking(diameter * 0.0018)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .shadow(color: .black.opacity(0.92), radius: 2, y: 1)
                    .position(layout.anchors.labelAnchor)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "table.world.travel.accessibility",
                                   defaultValue: "Unterwegs-Tisch mit acht Feldern und Mitte"))
    }

    private var projectedLayouts: [TravelTrayRenderLayout] {
        guard diameter > 0 else { return [] }
        do {
            let projection = try BoardSpaceProjection(parameters: .init(
                screen: BoardScreenQuadrilateral(
                    topLeft: .zero,
                    topRight: CGPoint(x: diameter, y: 0),
                    bottomRight: CGPoint(x: diameter, y: diameter),
                    bottomLeft: CGPoint(x: 0, y: diameter)
                )
            ))
            let adapter = try TravelTableProjectionAdapter(
                profile: .smokeClearSquare,
                projection: projection
            )
            return try TravelTableGeometry.compartments.map { compartment in
                TravelTrayRenderLayout(
                    anchors: try adapter.anchors(for: compartment),
                    well: try adapter.projectedWell(for: compartment)
                )
            }
        } catch {
            return []
        }
    }
}

private struct TravelTrayRenderLayout: Identifiable {
    let anchors: TravelTableProjectedAnchors
    let well: ProjectedWellProfile

    var id: TravelCompartment { compartment }
    var compartment: TravelCompartment { anchors.compartment }

    var wellDiameter: CGFloat {
        min(floorBounds.width, floorBounds.height)
    }

    var contentSize: CGSize {
        let horizontalRadius = floorOffsets.map { abs($0.x) }.max() ?? 0
        let verticalRadius = floorOffsets.map { abs($0.y) }.max() ?? 0
        return CGSize(width: horizontalRadius * 2,
                      height: verticalRadius * 2)
    }

    var restSlotOffsets: [CGSize] {
        anchors.restSlots.map { point in
            CGSize(width: point.x - anchors.wellCenter.x,
                   height: point.y - anchors.wellCenter.y)
        }
    }

    var floorOffsets: [CGPoint] {
        well.floorPath.map { point in
            CGPoint(x: point.x - anchors.wellCenter.x,
                    y: point.y - anchors.wellCenter.y)
        }
    }

    private var floorBounds: CGRect {
        guard let first = well.floorPath.first else { return .zero }
        return well.floorPath.dropFirst().reduce(
            CGRect(origin: first, size: .zero)
        ) { bounds, point in
            bounds.union(CGRect(origin: point, size: .zero))
        }
    }
}

struct TravelCoinPile: View {
    let count: Int
    let seed: UInt64
    let compartment: TravelCompartment
    let wellDiameter: CGFloat
    var layoutSize: CGSize? = nil
    var restSlotOffsets: [CGSize]? = nil
    var hitTestOffsets: [CGPoint]? = nil

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
                    .offset(resolvedOffset(for: index,
                                           pose: pose,
                                           coinSize: coinSize))
                    .zIndex(pose.elevation)
            }
        }
        .frame(width: layoutSize?.width ?? wellDiameter,
               height: layoutSize?.height ?? wellDiameter)
        .contentShape(TravelWellHitShape(offsets: hitTestOffsets ?? []))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func resolvedOffset(for index: Int,
                                pose: TravelCoinRestingPose,
                                coinSize: CGFloat) -> CGSize {
        if let restSlotOffsets,
           restSlotOffsets.indices.contains(index) {
            return restSlotOffsets[index]
        }
        return CGSize(width: coinSize * 0.58 * CGFloat(pose.offset.x),
                      height: coinSize * 0.58 * CGFloat(pose.offset.y))
    }

    private func assetIndex(for index: Int) -> Int {
        TravelCentAssetResolver.index(seed: seed,
                                      index: index,
                                      compartment: compartment)
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

private struct TravelWellHitShape: Shape {
    let offsets: [CGPoint]

    func path(in rect: CGRect) -> Path {
        guard let first = offsets.first else {
            return Path(rect)
        }
        var path = Path()
        path.move(to: CGPoint(x: rect.midX + first.x,
                              y: rect.midY + first.y))
        for point in offsets.dropFirst() {
            path.addLine(to: CGPoint(x: rect.midX + point.x,
                                     y: rect.midY + point.y))
        }
        path.closeSubpath()
        return path
    }
}

enum TravelCentAssetResolver {
    static let variantCount = 6

    static func index(seed: UInt64,
                      index: Int,
                      compartment: TravelCompartment) -> Int {
        let compartmentIndex = TravelTableGeometry.compartments
            .firstIndex(of: compartment) ?? 0
        let safeIndex = max(index, 0)
        return (Int(seed % UInt64(variantCount))
                + safeIndex * 5
                + compartmentIndex * 3) % variantCount
    }
}

/// Einzelmünze für Flüge und freie Stapel. Oberflächenvariante und Drehung
/// stammen aus derselben deterministischen Quelle wie die Münzen in der Schale.
struct TravelCentPiece: View {
    let seed: UInt64
    let index: Int
    let compartment: TravelCompartment
    let size: CGFloat

    var body: some View {
        let safeIndex = min(max(index, 0), TravelCoinLayout.capacity - 1)
        let pose = TravelCoinLayout.poses(count: safeIndex + 1,
                                          seed: seed,
                                          compartment: compartment)[safeIndex]
        TravelCentCoin(
            assetIndex: TravelCentAssetResolver.index(seed: seed,
                                                       index: safeIndex,
                                                       compartment: compartment),
            pose: pose,
            size: size
        )
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
            String(localized: "table.world.travel.field.mariage", defaultValue: "Mariage")
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
        case .mariage: String(localized: "pool.mariage.short", defaultValue: "MARIAGE")
        case .jack: "J"
        case .ten: "10"
        case .sequence: String(localized: "pool.sequence.short", defaultValue: "FOLGE")
        case .poch: "POCH"
        case .ace: "A"
        case .center: String(localized: "board.center", defaultValue: "MITTE")
        }
    }
}

#if DEBUG || INTERNAL_QA
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
