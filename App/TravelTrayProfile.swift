import CoreGraphics
import Foundation

/// Eine geschlossene, konvexe Kontur im normalisierten Board-Raum.
struct TravelTrayContour: Equatable, Sendable {
    let points: [NormalizedBoardPoint]

    var isInsideBoard: Bool {
        points.count >= 3 && points.allSatisfy(\.isInsideBoard)
    }

    func contains(_ point: NormalizedBoardPoint,
                  tolerance: Double = TravelTrayProfile.containmentTolerance) -> Bool {
        guard points.count >= 3,
              point.x.isFinite,
              point.y.isFinite,
              tolerance.isFinite,
              tolerance >= 0 else {
            return false
        }

        var winding: FloatingPointSign?
        for index in points.indices {
            let start = points[index]
            let end = points[(index + 1) % points.count]
            let edgeX = end.x - start.x
            let edgeY = end.y - start.y
            let pointX = point.x - start.x
            let pointY = point.y - start.y
            let crossProduct = edgeX * pointY - edgeY * pointX
            if abs(crossProduct) <= tolerance { continue }

            if let winding, winding != crossProduct.sign {
                return false
            }
            winding = crossProduct.sign
        }
        return winding != nil
    }
}

/// Vollständige, regelneutrale Darstellungsgeometrie eines Track-B-Wells.
struct WellProfile: Equatable, Sendable {
    let compartment: TravelCompartment
    let floorPath: TravelTrayContour
    let innerRimPath: TravelTrayContour
    let frontLipPath: TravelTrayContour
    let labelAnchor: NormalizedBoardPoint
    let restSlots: [NormalizedBoardPoint]
    let overflowContactSlot: NormalizedBoardPoint

    func projected(using projection: BoardSpaceProjection) throws -> ProjectedWellProfile {
        ProjectedWellProfile(
            compartment: compartment,
            floorPath: try floorPath.points.map(projection.screenPoint(for:)),
            innerRimPath: try innerRimPath.points.map(projection.screenPoint(for:)),
            frontLipPath: try frontLipPath.points.map(projection.screenPoint(for:)),
            labelAnchor: try projection.screenPoint(for: labelAnchor),
            restSlots: try restSlots.map(projection.screenPoint(for:)),
            overflowContactSlot: try projection.screenPoint(for: overflowContactSlot)
        )
    }
}

/// Screen-Space-Ausgabe eines Well-Profils. Sie enthält weiterhin keine
/// Spiel-, Einsatz- oder Economy-Entscheidungen.
struct ProjectedWellProfile: Equatable, Sendable {
    let compartment: TravelCompartment
    let floorPath: [CGPoint]
    let innerRimPath: [CGPoint]
    let frontLipPath: [CGPoint]
    let labelAnchor: CGPoint
    let restSlots: [CGPoint]
    let overflowContactSlot: CGPoint
}

/// Datenprofil der quadratischen rauchklaren 3-1-3-1-Scharnierbox.
struct TravelTrayProfile: Equatable, Sendable {
    fileprivate static let containmentTolerance = 1e-12

    let wells: [WellProfile]

    static let smokeClearSquare = Self(
        wells: DefaultGeometry.wellDefinitions.map(Self.makeWell)
    )

    func well(for compartment: TravelCompartment) -> WellProfile? {
        wells.first { $0.compartment == compartment }
    }

    func projected(using projection: BoardSpaceProjection) throws -> [ProjectedWellProfile] {
        try wells.map { try $0.projected(using: projection) }
    }

    private struct WellDefinition: Sendable {
        let compartment: TravelCompartment
        let center: NormalizedBoardPoint
        let size: CGSize
        let rimCornerCut: Double
        let frontLipDepth: Double
    }

    private enum DefaultGeometry {
        static let floorInset = 0.018
        static let floorCornerCutScale = 0.72

        static let horizontalOuterSize = CGSize(width: 0.240, height: 0.200)
        static let sideOuterSize = CGSize(width: 0.200, height: 0.260)
        static let centerSize = CGSize(width: 0.400, height: 0.280)

        static let horizontalCornerCut = 0.036
        static let sideCornerCut = 0.030
        static let centerCornerCut = 0.042

        static let outerFrontLipDepth = 0.028
        static let centerFrontLipDepth = 0.032

        static let leftColumnX = 0.190
        static let centerColumnX = 0.500
        static let rightColumnX = 0.810
        static let sideLeftX = 0.170
        static let sideRightX = 0.830
        static let topRowY = 0.200
        static let middleRowY = 0.500
        static let bottomRowY = 0.800

        static let slotFractions: [(x: Double, y: Double)] = [
            (-0.125,  0.00), ( 0.125,  0.00),
            (-0.375,  0.00), ( 0.375,  0.00),
            (-0.125, -0.25), ( 0.125, -0.25),
            (-0.125,  0.25), ( 0.125,  0.25),
            (-0.375, -0.25), ( 0.375, -0.25),
            (-0.375,  0.25), ( 0.375,  0.25)
        ]

        static let wellDefinitions: [WellDefinition] = [
            .init(compartment: .ace,
                  center: .init(x: leftColumnX, y: topRowY),
                  size: horizontalOuterSize,
                  rimCornerCut: horizontalCornerCut,
                  frontLipDepth: outerFrontLipDepth),
            .init(compartment: .king,
                  center: .init(x: centerColumnX, y: topRowY),
                  size: horizontalOuterSize,
                  rimCornerCut: horizontalCornerCut,
                  frontLipDepth: outerFrontLipDepth),
            .init(compartment: .queen,
                  center: .init(x: rightColumnX, y: topRowY),
                  size: horizontalOuterSize,
                  rimCornerCut: horizontalCornerCut,
                  frontLipDepth: outerFrontLipDepth),
            .init(compartment: .poch,
                  center: .init(x: sideLeftX, y: middleRowY),
                  size: sideOuterSize,
                  rimCornerCut: sideCornerCut,
                  frontLipDepth: outerFrontLipDepth),
            .init(compartment: .center,
                  center: .init(x: centerColumnX, y: middleRowY),
                  size: centerSize,
                  rimCornerCut: centerCornerCut,
                  frontLipDepth: centerFrontLipDepth),
            .init(compartment: .mariage,
                  center: .init(x: sideRightX, y: middleRowY),
                  size: sideOuterSize,
                  rimCornerCut: sideCornerCut,
                  frontLipDepth: outerFrontLipDepth),
            .init(compartment: .sequence,
                  center: .init(x: leftColumnX, y: bottomRowY),
                  size: horizontalOuterSize,
                  rimCornerCut: horizontalCornerCut,
                  frontLipDepth: outerFrontLipDepth),
            .init(compartment: .ten,
                  center: .init(x: centerColumnX, y: bottomRowY),
                  size: horizontalOuterSize,
                  rimCornerCut: horizontalCornerCut,
                  frontLipDepth: outerFrontLipDepth),
            .init(compartment: .jack,
                  center: .init(x: rightColumnX, y: bottomRowY),
                  size: horizontalOuterSize,
                  rimCornerCut: horizontalCornerCut,
                  frontLipDepth: outerFrontLipDepth)
        ]
    }

    private static func makeWell(_ definition: WellDefinition) -> WellProfile {
        let width = Double(definition.size.width)
        let height = Double(definition.size.height)
        let floorWidth = width - 2 * DefaultGeometry.floorInset
        let floorHeight = height - 2 * DefaultGeometry.floorInset
        let floorCornerCut = definition.rimCornerCut
            * DefaultGeometry.floorCornerCutScale

        let innerRimPath = roundedRectangle(
            center: definition.center,
            width: width,
            height: height,
            cornerCut: definition.rimCornerCut
        )
        let floorPath = roundedRectangle(
            center: definition.center,
            width: floorWidth,
            height: floorHeight,
            cornerCut: floorCornerCut
        )
        let lip = frontLip(
            center: definition.center,
            width: width,
            height: height,
            cornerCut: definition.rimCornerCut,
            depth: definition.frontLipDepth
        )
        let labelAnchor = NormalizedBoardPoint(
            x: definition.center.x,
            y: definition.center.y + height / 2 - definition.frontLipDepth / 2
        )
        let restSlots = DefaultGeometry.slotFractions.map { fraction in
            NormalizedBoardPoint(
                x: definition.center.x + floorWidth * fraction.x,
                y: definition.center.y + floorHeight * fraction.y
            )
        }

        return WellProfile(
            compartment: definition.compartment,
            floorPath: floorPath,
            innerRimPath: innerRimPath,
            frontLipPath: lip,
            labelAnchor: labelAnchor,
            restSlots: restSlots,
            overflowContactSlot: definition.center
        )
    }

    private static func roundedRectangle(center: NormalizedBoardPoint,
                                         width: Double,
                                         height: Double,
                                         cornerCut: Double) -> TravelTrayContour {
        let minimumX = center.x - width / 2
        let maximumX = center.x + width / 2
        let minimumY = center.y - height / 2
        let maximumY = center.y + height / 2
        return TravelTrayContour(points: [
            .init(x: minimumX + cornerCut, y: minimumY),
            .init(x: maximumX - cornerCut, y: minimumY),
            .init(x: maximumX, y: minimumY + cornerCut),
            .init(x: maximumX, y: maximumY - cornerCut),
            .init(x: maximumX - cornerCut, y: maximumY),
            .init(x: minimumX + cornerCut, y: maximumY),
            .init(x: minimumX, y: maximumY - cornerCut),
            .init(x: minimumX, y: minimumY + cornerCut)
        ])
    }

    private static func frontLip(center: NormalizedBoardPoint,
                                 width: Double,
                                 height: Double,
                                 cornerCut: Double,
                                 depth: Double) -> TravelTrayContour {
        let minimumX = center.x - width / 2 + cornerCut
        let maximumX = center.x + width / 2 - cornerCut
        let maximumY = center.y + height / 2
        return TravelTrayContour(points: [
            .init(x: minimumX, y: maximumY - depth),
            .init(x: maximumX, y: maximumY - depth),
            .init(x: maximumX, y: maximumY),
            .init(x: minimumX, y: maximumY)
        ])
    }
}
