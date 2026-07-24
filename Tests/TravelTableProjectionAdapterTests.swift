import CoreGraphics
import Foundation

@main
struct TravelTableProjectionAdapterTests {
    private static let coordinateTolerance = 1e-9

    static func main() throws {
        try componentOrderAndIdentityRemainStable()
        try profileAnchorsProjectWithoutSemanticDrift()
        try completeWellGeometryUsesTheSameProjection()
        try projectedAnchorsRoundTripToBoardSpace()
        invalidProfilesAreRejectedDeterministically()

        FileHandle.standardOutput.write(Data("TravelTableProjectionAdapterTests: PASS\n".utf8))
    }

    private static func componentOrderAndIdentityRemainStable() throws {
        let adapter = try makeAdapter().adapter
        let anchors = try adapter.anchorsInComponentOrder()

        expect(anchors.map(\.compartment) == TravelTableGeometry.compartments,
               "The adapter must preserve the existing Track-B component order")
        expect(TravelTableGeometry.compartments
            == TravelCompartment.outerClockwise + [.center],
               "The adapter must not redefine the existing 8+1 topology")
    }

    private static func profileAnchorsProjectWithoutSemanticDrift() throws {
        let fixture = try makeAdapter()
        let profile = TravelTrayProfile.smokeClearSquare

        for compartment in TravelTableGeometry.compartments {
            guard let well = profile.well(for: compartment) else {
                fail("The default profile must contain every existing component")
            }
            let anchors = try fixture.adapter.anchors(for: compartment)
            expect(anchors.compartment == compartment,
                   "A projected anchor set must retain its compartment identity")
            expectPoint(anchors.labelAnchor,
                        equals: try fixture.projection.screenPoint(for: well.labelAnchor),
                        "Labels must use the profile's prepared anchor")
            expect(anchors.restSlots.count == TravelCoinLayout.capacity,
                   "The projected slot capacity must match the existing coin component")
            for (actual, source) in zip(anchors.restSlots, well.restSlots) {
                expectPoint(actual,
                            equals: try fixture.projection.screenPoint(for: source),
                            "Rest slots must use the shared board projection")
            }
            expectPoint(
                anchors.overflowContactSlot,
                equals: try fixture.projection.screenPoint(for: well.overflowContactSlot),
                "Overflow contact must use the profile's prepared anchor"
            )
        }
    }

    private static func completeWellGeometryUsesTheSameProjection() throws {
        let fixture = try makeAdapter()
        let profile = TravelTrayProfile.smokeClearSquare

        for compartment in TravelTableGeometry.compartments {
            guard let well = profile.well(for: compartment) else {
                fail("The default profile must contain every existing component")
            }
            let expected = try well.projected(using: fixture.projection)
            let actual = try fixture.adapter.projectedWell(for: compartment)
            expect(actual == expected,
                   "Contours and anchors must share one projection path")
        }
    }

    private static func projectedAnchorsRoundTripToBoardSpace() throws {
        let fixture = try makeAdapter()
        let anchors = try fixture.adapter.anchorsInComponentOrder()

        for component in anchors {
            let points = component.restSlots + [
                component.wellCenter,
                component.labelAnchor,
                component.overflowContactSlot
            ]
            for screenPoint in points {
                let boardPoint = try fixture.projection.boardPoint(for: screenPoint)
                expect(boardPoint.isInsideBoard,
                       "Every adapter anchor must round-trip inside normalized board space")
            }
        }
    }

    private static func invalidProfilesAreRejectedDeterministically() {
        let profile = TravelTrayProfile.smokeClearSquare
        guard let king = profile.well(for: .king) else {
            fail("The default profile must provide the king well")
        }
        let missing = TravelTrayProfile(
            wells: profile.wells.filter { $0.compartment != .king }
        )
        let duplicate = TravelTrayProfile(wells: profile.wells + [king])

        expectAdapterError(.missingWell(.king), profile: missing)
        expectAdapterError(.duplicateWell(.king), profile: duplicate)
    }

    private static func makeAdapter() throws -> (
        adapter: TravelTableProjectionAdapter,
        projection: BoardSpaceProjection
    ) {
        let projection = try makeProjection()
        return (
            try TravelTableProjectionAdapter(projection: projection),
            projection
        )
    }

    private static func makeProjection() throws -> BoardSpaceProjection {
        try BoardSpaceProjection(parameters: .init(
            screen: BoardScreenQuadrilateral(
                topLeft: CGPoint(x: 126, y: 88),
                topRight: CGPoint(x: 914, y: 154),
                bottomRight: CGPoint(x: 836, y: 746),
                bottomLeft: CGPoint(x: 62, y: 670)
            )
        ))
    }

    private static func expectAdapterError(
        _ expected: TravelTableProjectionAdapter.AdapterError,
        profile: TravelTrayProfile
    ) {
        do {
            _ = try TravelTableProjectionAdapter(
                profile: profile,
                projection: try makeProjection()
            )
            fail("An invalid profile must not create a runtime adapter")
        } catch let error as TravelTableProjectionAdapter.AdapterError {
            expect(error == expected,
                   "Invalid profile geometry must report its precise adapter error")
        } catch {
            fail("Invalid profile geometry must report an adapter error")
        }
    }

    private static func expectPoint(_ point: CGPoint,
                                    equals expected: CGPoint,
                                    _ message: String) {
        expect(abs(Double(point.x - expected.x)) <= coordinateTolerance, message)
        expect(abs(Double(point.y - expected.y)) <= coordinateTolerance, message)
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("TravelTableProjectionAdapterTests: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
