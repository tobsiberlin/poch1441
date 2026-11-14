import CoreGraphics
import Foundation

/// Ein Punkt im normalisierten Board-Raum. `(0, 0)` ist die obere linke und
/// `(1, 1)` die untere rechte Ecke der zugrunde liegenden Board-Fläche.
struct NormalizedBoardPoint: Equatable, Sendable {
    let x: Double
    let y: Double

    var isInsideBoard: Bool {
        (0...1).contains(x) && (0...1).contains(y)
    }
}

/// Die sichtbaren Ecken einer schräg dargestellten Board-Fläche.
struct BoardScreenQuadrilateral: Equatable, Sendable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint
}

/// Deterministische Abbildung zwischen normalisiertem Board-Raum und Screen.
///
/// Die Projektionsparameter werden einmal aus den vier sichtbaren Ecken
/// berechnet. Punktabbildungen sind danach konstant schnell und allokationsfrei.
struct BoardSpaceProjection: Sendable {
    struct NumericalPolicy: Equatable, Sendable {
        /// Kleinste erlaubte Screen-Ausdehnung in Punkten.
        let minimumScreenExtent: Double
        /// Kleinste normalisierte Kreuzprodukt-Fläche einer Ecke.
        let minimumRelativeCornerArea: Double
        /// Kleinster relativer Determinant der Projektionsmatrix.
        let minimumRelativeDeterminant: Double
        /// Kleinster Betrag des homogenen Divisors bei einer Punktabbildung.
        let minimumHomogeneousScale: Double

        static let standard = Self(
            minimumScreenExtent: 1e-9,
            minimumRelativeCornerArea: 1e-12,
            minimumRelativeDeterminant: 1e-12,
            minimumHomogeneousScale: 1e-12
        )
    }

    struct Parameters: Equatable, Sendable {
        let screen: BoardScreenQuadrilateral
        let numericalPolicy: NumericalPolicy

        init(screen: BoardScreenQuadrilateral,
             numericalPolicy: NumericalPolicy = .standard) {
            self.screen = screen
            self.numericalPolicy = numericalPolicy
        }
    }

    enum ProjectionError: Error, Equatable, Sendable {
        case nonFiniteParameter
        case invalidNumericalPolicy
        case degenerateQuadrilateral
        case nonFinitePoint
        case pointAtInfinity
    }

    private struct Matrix3x3: Sendable {
        let m00: Double
        let m01: Double
        let m02: Double
        let m10: Double
        let m11: Double
        let m12: Double
        let m20: Double
        let m21: Double
        let m22: Double

        var determinant: Double {
            m00 * (m11 * m22 - m12 * m21)
                - m01 * (m10 * m22 - m12 * m20)
                + m02 * (m10 * m21 - m11 * m20)
        }

        var relativeDeterminant: Double {
            let firstRowScale = max(abs(m00), abs(m01), abs(m02))
            let secondRowScale = max(abs(m10), abs(m11), abs(m12))
            let thirdRowScale = max(abs(m20), abs(m21), abs(m22))
            let scale = firstRowScale * secondRowScale * thirdRowScale
            guard scale > 0, scale.isFinite else { return 0 }
            return abs(determinant) / scale
        }

        func inverted() -> Self? {
            let value = determinant
            guard value != 0, value.isFinite else { return nil }

            return Self(
                m00: (m11 * m22 - m12 * m21) / value,
                m01: (m02 * m21 - m01 * m22) / value,
                m02: (m01 * m12 - m02 * m11) / value,
                m10: (m12 * m20 - m10 * m22) / value,
                m11: (m00 * m22 - m02 * m20) / value,
                m12: (m02 * m10 - m00 * m12) / value,
                m20: (m10 * m21 - m11 * m20) / value,
                m21: (m01 * m20 - m00 * m21) / value,
                m22: (m00 * m11 - m01 * m10) / value
            )
        }

        func applying(x: Double,
                      y: Double,
                      minimumHomogeneousScale: Double) throws -> (x: Double, y: Double) {
            let homogeneousX = m00 * x + m01 * y + m02
            let homogeneousY = m10 * x + m11 * y + m12
            let homogeneousScale = m20 * x + m21 * y + m22
            guard homogeneousX.isFinite,
                  homogeneousY.isFinite,
                  homogeneousScale.isFinite else {
                throw ProjectionError.nonFinitePoint
            }
            guard abs(homogeneousScale) >= minimumHomogeneousScale else {
                throw ProjectionError.pointAtInfinity
            }
            return (homogeneousX / homogeneousScale,
                    homogeneousY / homogeneousScale)
        }
    }

    private let boardToUnitScreen: Matrix3x3
    private let unitScreenToBoard: Matrix3x3
    private let screenOrigin: CGPoint
    private let screenScale: Double
    private let minimumHomogeneousScale: Double

    init(parameters: Parameters) throws {
        let policy = parameters.numericalPolicy
        guard Self.isValid(policy) else {
            throw ProjectionError.invalidNumericalPolicy
        }

        let corners = [
            parameters.screen.topLeft,
            parameters.screen.topRight,
            parameters.screen.bottomRight,
            parameters.screen.bottomLeft
        ]
        guard corners.allSatisfy(Self.isFinite) else {
            throw ProjectionError.nonFiniteParameter
        }

        let xValues = corners.map { Double($0.x) }
        let yValues = corners.map { Double($0.y) }
        guard let minimumX = xValues.min(),
              let maximumX = xValues.max(),
              let minimumY = yValues.min(),
              let maximumY = yValues.max() else {
            throw ProjectionError.degenerateQuadrilateral
        }
        let extent = max(maximumX - minimumX, maximumY - minimumY)
        guard extent >= policy.minimumScreenExtent, extent.isFinite else {
            throw ProjectionError.degenerateQuadrilateral
        }

        let origin = parameters.screen.topLeft
        let normalized = corners.map { point in
            CGPoint(
                x: (Double(point.x) - Double(origin.x)) / extent,
                y: (Double(point.y) - Double(origin.y)) / extent
            )
        }
        guard Self.isStrictlyConvex(normalized,
                                    minimumRelativeArea: policy.minimumRelativeCornerArea) else {
            throw ProjectionError.degenerateQuadrilateral
        }

        let matrix = try Self.makeUnitSquareProjection(
            topLeft: normalized[0],
            topRight: normalized[1],
            bottomRight: normalized[2],
            bottomLeft: normalized[3],
            minimumRelativeDeterminant: policy.minimumRelativeDeterminant
        )
        guard matrix.relativeDeterminant >= policy.minimumRelativeDeterminant,
              let inverse = matrix.inverted(),
              inverse.relativeDeterminant >= policy.minimumRelativeDeterminant else {
            throw ProjectionError.degenerateQuadrilateral
        }

        boardToUnitScreen = matrix
        unitScreenToBoard = inverse
        screenOrigin = origin
        screenScale = extent
        minimumHomogeneousScale = policy.minimumHomogeneousScale
    }

    func screenPoint(for boardPoint: NormalizedBoardPoint) throws -> CGPoint {
        guard boardPoint.x.isFinite, boardPoint.y.isFinite else {
            throw ProjectionError.nonFinitePoint
        }
        let projected = try boardToUnitScreen.applying(
            x: boardPoint.x,
            y: boardPoint.y,
            minimumHomogeneousScale: minimumHomogeneousScale
        )
        let x = Double(screenOrigin.x) + projected.x * screenScale
        let y = Double(screenOrigin.y) + projected.y * screenScale
        guard x.isFinite, y.isFinite else {
            throw ProjectionError.nonFinitePoint
        }
        return CGPoint(x: x, y: y)
    }

    func boardPoint(for screenPoint: CGPoint) throws -> NormalizedBoardPoint {
        guard Self.isFinite(screenPoint) else {
            throw ProjectionError.nonFinitePoint
        }
        let normalizedX = (Double(screenPoint.x) - Double(screenOrigin.x)) / screenScale
        let normalizedY = (Double(screenPoint.y) - Double(screenOrigin.y)) / screenScale
        let projected = try unitScreenToBoard.applying(
            x: normalizedX,
            y: normalizedY,
            minimumHomogeneousScale: minimumHomogeneousScale
        )
        return NormalizedBoardPoint(x: projected.x, y: projected.y)
    }

    private static func makeUnitSquareProjection(
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint,
        bottomLeft: CGPoint,
        minimumRelativeDeterminant: Double
    ) throws -> Matrix3x3 {
        let x0 = Double(topLeft.x)
        let y0 = Double(topLeft.y)
        let x1 = Double(topRight.x)
        let y1 = Double(topRight.y)
        let x2 = Double(bottomRight.x)
        let y2 = Double(bottomRight.y)
        let x3 = Double(bottomLeft.x)
        let y3 = Double(bottomLeft.y)

        let deltaX1 = x1 - x2
        let deltaX2 = x3 - x2
        let deltaX3 = x0 - x1 + x2 - x3
        let deltaY1 = y1 - y2
        let deltaY2 = y3 - y2
        let deltaY3 = y0 - y1 + y2 - y3

        let perspectiveDeterminant = deltaX1 * deltaY2 - deltaX2 * deltaY1
        let perspectiveScale = max(
            abs(deltaX1 * deltaY2),
            abs(deltaX2 * deltaY1),
            minimumRelativeDeterminant
        )
        guard abs(perspectiveDeterminant) / perspectiveScale
                >= minimumRelativeDeterminant else {
            throw ProjectionError.degenerateQuadrilateral
        }

        let perspectiveX = (deltaX3 * deltaY2 - deltaX2 * deltaY3)
            / perspectiveDeterminant
        let perspectiveY = (deltaX1 * deltaY3 - deltaX3 * deltaY1)
            / perspectiveDeterminant
        return Matrix3x3(
            m00: x1 - x0 + perspectiveX * x1,
            m01: x3 - x0 + perspectiveY * x3,
            m02: x0,
            m10: y1 - y0 + perspectiveX * y1,
            m11: y3 - y0 + perspectiveY * y3,
            m12: y0,
            m20: perspectiveX,
            m21: perspectiveY,
            m22: 1
        )
    }

    private static func isValid(_ policy: NumericalPolicy) -> Bool {
        let values = [
            policy.minimumScreenExtent,
            policy.minimumRelativeCornerArea,
            policy.minimumRelativeDeterminant,
            policy.minimumHomogeneousScale
        ]
        return values.allSatisfy { $0.isFinite && $0 > 0 }
    }

    private static func isFinite(_ point: CGPoint) -> Bool {
        point.x.isFinite && point.y.isFinite
    }

    private static func isStrictlyConvex(_ points: [CGPoint],
                                         minimumRelativeArea: Double) -> Bool {
        guard points.count == 4 else { return false }
        var winding: FloatingPointSign?

        for index in points.indices {
            let first = points[index]
            let second = points[(index + 1) % points.count]
            let third = points[(index + 2) % points.count]
            let firstEdgeX = Double(second.x - first.x)
            let firstEdgeY = Double(second.y - first.y)
            let secondEdgeX = Double(third.x - second.x)
            let secondEdgeY = Double(third.y - second.y)
            let crossProduct = firstEdgeX * secondEdgeY - firstEdgeY * secondEdgeX
            guard abs(crossProduct) >= minimumRelativeArea else { return false }

            if let winding, winding != crossProduct.sign {
                return false
            }
            winding = crossProduct.sign
        }
        return true
    }
}
