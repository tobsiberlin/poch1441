import CoreGraphics
import Foundation

@main
struct BoardSpaceProjectionTests {
    private static let coordinateTolerance = 1e-9
    private static let stableCoordinateTolerance = 1e-7

    static func main() throws {
        try knownCornersMapExactly()
        try boardAndScreenRoundTrip()
        try wellAnchorsRemainInsideTheBoard()
        try largeScreenOriginsRemainStable()
        degenerationIsRejected()
        invalidInputsAreRejected()

        FileHandle.standardOutput.write(Data("BoardSpaceProjectionTests: PASS\n".utf8))
    }

    private static func knownCornersMapExactly() throws {
        let fixture = try makeProjection()
        let expectations: [(NormalizedBoardPoint, CGPoint)] = [
            (.init(x: 0, y: 0), fixture.screen.topLeft),
            (.init(x: 1, y: 0), fixture.screen.topRight),
            (.init(x: 1, y: 1), fixture.screen.bottomRight),
            (.init(x: 0, y: 1), fixture.screen.bottomLeft)
        ]

        for (boardPoint, expectedScreenPoint) in expectations {
            let screenPoint = try fixture.projection.screenPoint(for: boardPoint)
            expectPoint(screenPoint,
                        equals: expectedScreenPoint,
                        tolerance: coordinateTolerance,
                        "Every normalized corner must map to its configured screen corner")
        }
    }

    private static func boardAndScreenRoundTrip() throws {
        let projection = try makeProjection().projection
        let samples = [
            NormalizedBoardPoint(x: 0, y: 0),
            NormalizedBoardPoint(x: 0.5, y: 0.5),
            NormalizedBoardPoint(x: 0.195, y: 0.486),
            NormalizedBoardPoint(x: 0.826, y: 0.430),
            NormalizedBoardPoint(x: 1, y: 1),
            NormalizedBoardPoint(x: 0.125, y: 0.875)
        ]

        for point in samples {
            let screenPoint = try projection.screenPoint(for: point)
            let replay = try projection.boardPoint(for: screenPoint)
            expect(abs(replay.x - point.x) <= coordinateTolerance,
                   "Board x must survive a board-screen-board round trip")
            expect(abs(replay.y - point.y) <= coordinateTolerance,
                   "Board y must survive a board-screen-board round trip")
        }
    }

    private static func wellAnchorsRemainInsideTheBoard() throws {
        let projection = try makeProjection().projection
        let trackBWellAnchors = [
            NormalizedBoardPoint(x: 0.500, y: 0.145),
            NormalizedBoardPoint(x: 0.716, y: 0.225),
            NormalizedBoardPoint(x: 0.826, y: 0.430),
            NormalizedBoardPoint(x: 0.748, y: 0.666),
            NormalizedBoardPoint(x: 0.520, y: 0.790),
            NormalizedBoardPoint(x: 0.280, y: 0.704),
            NormalizedBoardPoint(x: 0.195, y: 0.486),
            NormalizedBoardPoint(x: 0.270, y: 0.252),
            NormalizedBoardPoint(x: 0.500, y: 0.480)
        ]

        for anchor in trackBWellAnchors {
            expect(anchor.isInsideBoard,
                   "Every Track-B well anchor must be normalized")
            let screenPoint = try projection.screenPoint(for: anchor)
            let recovered = try projection.boardPoint(for: screenPoint)
            expect(recovered.isInsideBoard,
                   "Every projected Track-B well anchor must recover inside the board")
        }
    }

    private static func largeScreenOriginsRemainStable() throws {
        let origin = 1_000_000_000.0
        let screen = BoardScreenQuadrilateral(
            topLeft: CGPoint(x: origin + 30, y: origin + 20),
            topRight: CGPoint(x: origin + 8_030, y: origin + 430),
            bottomRight: CGPoint(x: origin + 7_510, y: origin + 4_900),
            bottomLeft: CGPoint(x: origin - 240, y: origin + 4_280)
        )
        let projection = try BoardSpaceProjection(
            parameters: .init(screen: screen)
        )
        let sample = NormalizedBoardPoint(x: 0.327, y: 0.781)
        let screenPoint = try projection.screenPoint(for: sample)
        let replay = try projection.boardPoint(for: screenPoint)

        expect(abs(replay.x - sample.x) <= stableCoordinateTolerance,
               "A large screen origin must not destabilize inverse x projection")
        expect(abs(replay.y - sample.y) <= stableCoordinateTolerance,
               "A large screen origin must not destabilize inverse y projection")
    }

    private static func degenerationIsRejected() {
        expectThrows(.degenerateQuadrilateral,
                     screen: .init(
                        topLeft: CGPoint(x: 0, y: 0),
                        topRight: CGPoint(x: 100, y: 0),
                        bottomRight: CGPoint(x: 200, y: 0),
                        bottomLeft: CGPoint(x: 300, y: 0)
                     ),
                     "Collinear corners must be rejected")
        expectThrows(.degenerateQuadrilateral,
                     screen: .init(
                        topLeft: CGPoint(x: 10, y: 10),
                        topRight: CGPoint(x: 10, y: 10),
                        bottomRight: CGPoint(x: 10, y: 10),
                        bottomLeft: CGPoint(x: 10, y: 10)
                     ),
                     "A collapsed screen box must be rejected")
        expectThrows(.degenerateQuadrilateral,
                     screen: .init(
                        topLeft: CGPoint(x: 0, y: 0),
                        topRight: CGPoint(x: 100, y: 100),
                        bottomRight: CGPoint(x: 0, y: 100),
                        bottomLeft: CGPoint(x: 100, y: 0)
                     ),
                     "A self-intersecting quadrilateral must be rejected")
    }

    private static func invalidInputsAreRejected() {
        expectThrows(.nonFiniteParameter,
                     screen: .init(
                        topLeft: CGPoint(x: CGFloat.nan, y: 0),
                        topRight: CGPoint(x: 100, y: 0),
                        bottomRight: CGPoint(x: 100, y: 100),
                        bottomLeft: CGPoint(x: 0, y: 100)
                     ),
                     "Non-finite corners must be rejected")

        let invalidPolicy = BoardSpaceProjection.NumericalPolicy(
            minimumScreenExtent: 0,
            minimumRelativeCornerArea: 1e-12,
            minimumRelativeDeterminant: 1e-12,
            minimumHomogeneousScale: 1e-12
        )
        do {
            _ = try BoardSpaceProjection(parameters: .init(
                screen: .init(
                    topLeft: CGPoint(x: 0, y: 0),
                    topRight: CGPoint(x: 100, y: 0),
                    bottomRight: CGPoint(x: 100, y: 100),
                    bottomLeft: CGPoint(x: 0, y: 100)
                ),
                numericalPolicy: invalidPolicy
            ))
            fail("A non-positive numerical tolerance must be rejected")
        } catch let error as BoardSpaceProjection.ProjectionError {
            expect(error == .invalidNumericalPolicy,
                   "An invalid policy must report its specific error")
        } catch {
            fail("An invalid policy must report BoardSpaceProjection.ProjectionError")
        }
    }

    private static func makeProjection() throws -> (
        projection: BoardSpaceProjection,
        screen: BoardScreenQuadrilateral
    ) {
        let screen = BoardScreenQuadrilateral(
            topLeft: CGPoint(x: 142, y: 94),
            topRight: CGPoint(x: 886, y: 151),
            bottomRight: CGPoint(x: 812, y: 706),
            bottomLeft: CGPoint(x: 75, y: 621)
        )
        return (try BoardSpaceProjection(parameters: .init(screen: screen)), screen)
    }

    private static func expectThrows(
        _ expectedError: BoardSpaceProjection.ProjectionError,
        screen: BoardScreenQuadrilateral,
        _ message: String
    ) {
        do {
            _ = try BoardSpaceProjection(parameters: .init(screen: screen))
            fail(message)
        } catch let error as BoardSpaceProjection.ProjectionError {
            expect(error == expectedError, message)
        } catch {
            fail(message)
        }
    }

    private static func expectPoint(_ point: CGPoint,
                                    equals expected: CGPoint,
                                    tolerance: Double,
                                    _ message: String) {
        expect(abs(Double(point.x - expected.x)) <= tolerance, message)
        expect(abs(Double(point.y - expected.y)) <= tolerance, message)
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        if !condition() { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        Foundation.exit(1)
    }
}
