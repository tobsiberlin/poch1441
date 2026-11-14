import CoreGraphics
import Foundation

@main
struct TravelTrayProfileTests {
    private static let expectedRestSlotCount = 12
    private static let minimumRestSlotSpacing = 0.040
    private static let projectionTolerance = 1e-9

    static func main() throws {
        exactThreeOneThreeOneTopologyIsStable()
        contoursAndAnchorsStayInsideTheBoard()
        floorAndLipStayInsideTheirRims()
        restSlotsAreContainedAndSeparated()
        defaultProfileReplaysExactly()
        try sharedProjectionPreservesEveryAnchor()

        FileHandle.standardOutput.write(Data("TravelTrayProfileTests: PASS\n".utf8))
    }

    private static func exactThreeOneThreeOneTopologyIsStable() {
        let profile = TravelTrayProfile.smokeClearSquare
        expect(profile.wells.count == 9,
               "The smoke-clear tray must contain exactly eight outer wells and one center")
        expect(profile.wells.map(\.compartment) == [
            .ace, .king, .queen,
            .poch, .center, .mariage,
            .sequence, .ten, .jack
        ], "The square tray must retain its deterministic 3-1-3-1 reading order")
        expect(Set(profile.wells.map(\.compartment)).count == 9,
               "Every tray compartment must have one and only one profile")
        for compartment in TravelCompartment.allCases {
            expect(profile.well(for: compartment) != nil,
                   "Every semantic compartment must resolve to a well profile")
        }
    }

    private static func contoursAndAnchorsStayInsideTheBoard() {
        for well in TravelTrayProfile.smokeClearSquare.wells {
            expect(well.floorPath.isInsideBoard,
                   "Every floor contour must stay in normalized board space")
            expect(well.innerRimPath.isInsideBoard,
                   "Every inner-rim contour must stay in normalized board space")
            expect(well.frontLipPath.isInsideBoard,
                   "Every front-lip contour must stay in normalized board space")
            expect(well.labelAnchor.isInsideBoard,
                   "Every label anchor must stay in normalized board space")
            expect(well.overflowContactSlot.isInsideBoard,
                   "Every overflow contact must stay in normalized board space")
            expect(well.restSlots.allSatisfy(\.isInsideBoard),
                   "Every resting slot must stay in normalized board space")
        }
    }

    private static func floorAndLipStayInsideTheirRims() {
        for well in TravelTrayProfile.smokeClearSquare.wells {
            expect(well.floorPath.points.allSatisfy { well.innerRimPath.contains($0) },
                   "The complete floor contour must stay inside its inner rim")
            expect(well.frontLipPath.points.allSatisfy { well.innerRimPath.contains($0) },
                   "The complete front-lip contour must stay inside its inner rim")
            expect(well.frontLipPath.contains(well.labelAnchor),
                   "A well label must be anchored on its prepared front lip")
        }
    }

    private static func restSlotsAreContainedAndSeparated() {
        for well in TravelTrayProfile.smokeClearSquare.wells {
            expect(well.restSlots.count == expectedRestSlotCount,
                   "Every well must expose exactly twelve persistent rest slots")
            expect(well.restSlots.allSatisfy { well.floorPath.contains($0) },
                   "Persistent coin slots must stay on the prepared floor")
            expect(well.floorPath.contains(well.overflowContactSlot),
                   "The overflow contact must stay on the prepared floor")

            for firstIndex in well.restSlots.indices {
                for secondIndex in well.restSlots.indices where secondIndex > firstIndex {
                    let first = well.restSlots[firstIndex]
                    let second = well.restSlots[secondIndex]
                    let spacing = hypot(first.x - second.x, first.y - second.y)
                    expect(spacing >= minimumRestSlotSpacing,
                           "Persistent rest slots need deterministic visual separation")
                }
            }
        }
    }

    private static func defaultProfileReplaysExactly() {
        let first = TravelTrayProfile.smokeClearSquare
        let second = TravelTrayProfile.smokeClearSquare
        expect(first == second,
               "Default tray geometry must replay without clocks or randomness")
    }

    private static func sharedProjectionPreservesEveryAnchor() throws {
        let projection = try BoardSpaceProjection(parameters: .init(
            screen: BoardScreenQuadrilateral(
                topLeft: CGPoint(x: 124, y: 92),
                topRight: CGPoint(x: 908, y: 158),
                bottomRight: CGPoint(x: 842, y: 748),
                bottomLeft: CGPoint(x: 66, y: 674)
            )
        ))
        let profile = TravelTrayProfile.smokeClearSquare
        let projected = try profile.projected(using: projection)
        expect(projected.count == profile.wells.count,
               "Projection must preserve the complete well profile count")

        for (source, screen) in zip(profile.wells, projected) {
            expect(source.compartment == screen.compartment,
                   "Projection must preserve semantic well identity")
            expect(screen.floorPath.count == source.floorPath.points.count,
                   "Projection must preserve floor contour topology")
            expect(screen.innerRimPath.count == source.innerRimPath.points.count,
                   "Projection must preserve rim contour topology")
            expect(screen.frontLipPath.count == source.frontLipPath.points.count,
                   "Projection must preserve lip contour topology")
            expect(screen.restSlots.count == expectedRestSlotCount,
                   "Projection must preserve all persistent rest slots")

            let sourceAnchors = source.restSlots + [
                source.labelAnchor,
                source.overflowContactSlot
            ]
            let screenAnchors = screen.restSlots + [
                screen.labelAnchor,
                screen.overflowContactSlot
            ]
            for (sourceAnchor, screenAnchor) in zip(sourceAnchors, screenAnchors) {
                let replay = try projection.boardPoint(for: screenAnchor)
                expect(abs(replay.x - sourceAnchor.x) <= projectionTolerance,
                       "A projected anchor must recover its normalized x coordinate")
                expect(abs(replay.y - sourceAnchor.y) <= projectionTolerance,
                       "A projected anchor must recover its normalized y coordinate")
                expect(replay.isInsideBoard,
                       "A projected tray anchor must recover inside board space")
            }
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("TravelTrayProfileTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
