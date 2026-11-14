import CoreGraphics
import Foundation

struct PlanePoint: Equatable, Codable, Sendable {
    let x: Double
    let y: Double

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: Self, rhs: Double) -> Self {
        Self(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    var length: Double { hypot(x, y) }
}

struct PlaneQuad: Equatable, Codable, Sendable {
    let topLeft: PlanePoint
    let topRight: PlanePoint
    let bottomRight: PlanePoint
    let bottomLeft: PlanePoint

    var points: [PlanePoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    var center: PlanePoint {
        points.reduce(PlanePoint(x: 0, y: 0), +) * 0.25
    }

    func translated(by offset: PlanePoint) -> Self {
        Self(
            topLeft: topLeft + offset,
            topRight: topRight + offset,
            bottomRight: bottomRight + offset,
            bottomLeft: bottomLeft + offset
        )
    }

    func scaled(around pivot: PlanePoint, by scale: Double) -> Self {
        func scaledPoint(_ point: PlanePoint) -> PlanePoint {
            pivot + (point - pivot) * scale
        }
        return Self(
            topLeft: scaledPoint(topLeft),
            topRight: scaledPoint(topRight),
            bottomRight: scaledPoint(bottomRight),
            bottomLeft: scaledPoint(bottomLeft)
        )
    }

    func interpolated(to target: Self, progress rawProgress: Double) -> Self {
        let progress = min(max(rawProgress, 0), 1)
        func point(_ start: PlanePoint, _ end: PlanePoint) -> PlanePoint {
            start + (end - start) * progress
        }
        return Self(
            topLeft: point(topLeft, target.topLeft),
            topRight: point(topRight, target.topRight),
            bottomRight: point(bottomRight, target.bottomRight),
            bottomLeft: point(bottomLeft, target.bottomLeft)
        )
    }
}

struct PlaneHomography: Equatable, Codable, Sendable {
    let m00: Double
    let m01: Double
    let m02: Double
    let m10: Double
    let m11: Double
    let m12: Double
    let m20: Double
    let m21: Double

    init(unitSquareTo quad: PlaneQuad) {
        let x0 = quad.topLeft.x
        let y0 = quad.topLeft.y
        let x1 = quad.topRight.x
        let y1 = quad.topRight.y
        let x2 = quad.bottomRight.x
        let y2 = quad.bottomRight.y
        let x3 = quad.bottomLeft.x
        let y3 = quad.bottomLeft.y
        let dx1 = x1 - x2
        let dx2 = x3 - x2
        let dx3 = x0 - x1 + x2 - x3
        let dy1 = y1 - y2
        let dy2 = y3 - y2
        let dy3 = y0 - y1 + y2 - y3
        let determinant = dx1 * dy2 - dx2 * dy1
        precondition(abs(determinant) > 0.000_001, "The calibrated Track-B plane must be non-degenerate")
        let perspectiveX = (dx3 * dy2 - dx2 * dy3) / determinant
        let perspectiveY = (dx1 * dy3 - dx3 * dy1) / determinant
        m00 = x1 - x0 + perspectiveX * x1
        m01 = x3 - x0 + perspectiveY * x3
        m02 = x0
        m10 = y1 - y0 + perspectiveX * y1
        m11 = y3 - y0 + perspectiveY * y3
        m12 = y0
        m20 = perspectiveX
        m21 = perspectiveY
    }

    func project(_ point: PlanePoint) -> PlanePoint {
        let denominator = m20 * point.x + m21 * point.y + 1
        return PlanePoint(
            x: (m00 * point.x + m01 * point.y + m02) / denominator,
            y: (m10 * point.x + m11 * point.y + m12) / denominator
        )
    }

    func projectedQuad(center: PlanePoint, halfWidth: Double, halfHeight: Double) -> PlaneQuad {
        PlaneQuad(
            topLeft: project(PlanePoint(x: center.x - halfWidth, y: center.y - halfHeight)),
            topRight: project(PlanePoint(x: center.x + halfWidth, y: center.y - halfHeight)),
            bottomRight: project(PlanePoint(x: center.x + halfWidth, y: center.y + halfHeight)),
            bottomLeft: project(PlanePoint(x: center.x - halfWidth, y: center.y + halfHeight))
        )
    }

    func calibrationRMS(expected quad: PlaneQuad) -> Double {
        let projected = [
            project(PlanePoint(x: 0, y: 0)),
            project(PlanePoint(x: 1, y: 0)),
            project(PlanePoint(x: 1, y: 1)),
            project(PlanePoint(x: 0, y: 1)),
        ]
        let squared = zip(projected, quad.points).map { pair in
            let delta = pair.0 - pair.1
            return delta.x * delta.x + delta.y * delta.y
        }
        return sqrt(squared.reduce(0, +) / Double(squared.count))
    }
}

enum PlaneLockSurface: String, Codable, Sendable {
    case cardBack
}

enum PlaneLockPhase: String, Codable, Sendable {
    case source
    case flight
    case firstEdgeContact
    case settling
    case stableRest
}

struct WorldLightProfile: Equatable, Codable, Sendable {
    let id: String
    let keyDirection: PlanePoint
    let backgroundVeilOpacity: Double
    let cardEdgeHighlightOpacity: Double
    let restingShadowOpacity: Double
    let airborneShadowOpacity: Double
    let restingShadowBlur: Double
    let airborneShadowBlur: Double
    let restingShadowOffset: Double
    let airborneShadowOffset: Double

    static let trackB = Self(
        id: "track-b-lamp-upper-left-v1",
        keyDirection: PlanePoint(x: -0.57, y: -0.82),
        backgroundVeilOpacity: 0.025,
        cardEdgeHighlightOpacity: 0.32,
        restingShadowOpacity: 0.48,
        airborneShadowOpacity: 0.29,
        restingShadowBlur: 1.0,
        airborneShadowBlur: 4.2,
        restingShadowOffset: 0.55,
        airborneShadowOffset: 13.5
    )
}

struct PlaneLockPose: Equatable, Codable, Sendable {
    let phase: PlaneLockPhase
    let surface: PlaneLockSurface
    let cardQuad: PlaneQuad
    let groundQuad: PlaneQuad
    let shadowQuad: PlaneQuad
    let height: Double
    let storedMaterialCurlMillimeters: Double
    let hasContacted: Bool
}

struct PlaneLockSnapshot: Equatable, Codable, Sendable {
    let fixedStepIndex: Int
    let simulationTime: Double
    let pose: PlaneLockPose
}

struct PlaneLockCalibration: Equatable, Sendable {
    static let viewportWidth = 402.0
    static let viewportHeight = 874.0

    // Manual feature lock against the actual 941 x 1672 Track-B master after
    // SwiftUI scaledToFill projection into 402 x 874. These are the four
    // visible corners of the snack-box insert plane, not a generic screen box.
    let tablePlane = PlaneQuad(
        topLeft: PlanePoint(x: 75.1, y: 327.8),
        topRight: PlanePoint(x: 335.5, y: 323.0),
        bottomRight: PlanePoint(x: 374.2, y: 575.5),
        bottomLeft: PlanePoint(x: 66.3, y: 569.3)
    )
    let homography: PlaneHomography
    // The deck sits on exposed wood below and right of the snack box. The
    // calibrated plane is extrapolated here so the stack has a real contact
    // shadow and never straddles a tray rim or the raised lid.
    let sourceCenter = PlanePoint(x: 0.900, y: 1.180)
    let targetCenter = PlanePoint(x: 0.500, y: 0.470)
    let cardHalfWidth = 0.075
    let cardHalfHeight = 0.105

    init() {
        homography = PlaneHomography(unitSquareTo: tablePlane)
    }

    var sourceQuad: PlaneQuad {
        homography.projectedQuad(
            center: sourceCenter,
            halfWidth: cardHalfWidth,
            halfHeight: cardHalfHeight
        )
    }

    var targetQuad: PlaneQuad {
        homography.projectedQuad(
            center: targetCenter,
            halfWidth: cardHalfWidth,
            halfHeight: cardHalfHeight
        )
    }

    // The actual large central compartment floor in the photographed world.
    var semanticMiddleRegion: PlaneQuad {
        PlaneQuad(
            topLeft: PlanePoint(x: 139.0, y: 389.5),
            topRight: PlanePoint(x: 269.7, y: 388.5),
            bottomRight: PlanePoint(x: 272.8, y: 494.0),
            bottomLeft: PlanePoint(x: 133.7, y: 495.7)
        )
    }
}

struct PlaneLockMotion: Equatable, Sendable {
    static let fixedStep = 1.0 / 240.0
    static let firstContactTime = 0.780
    static let stableRestTime = 0.890
    static let sequenceDuration = 1.300

    let calibration = PlaneLockCalibration()
    let lightProfile = WorldLightProfile.trackB

    func pose(at rawTime: Double) -> PlaneLockPose {
        let time = min(max(rawTime, 0), Self.sequenceDuration)
        let target = calibration.targetQuad

        if time >= Self.stableRestTime {
            return PlaneLockPose(
                phase: .stableRest,
                surface: .cardBack,
                cardQuad: target,
                groundQuad: target,
                shadowQuad: directedShadow(ground: target, height: 0),
                height: 0,
                storedMaterialCurlMillimeters: 0,
                hasContacted: true
            )
        }

        if time >= Self.firstContactTime {
            let rawSettle = (time - Self.firstContactTime) / (Self.stableRestTime - Self.firstContactTime)
            let settle = smooth(rawSettle)
            let firstContact = PlaneQuad(
                topLeft: target.topLeft + PlanePoint(x: -0.55, y: -2.8),
                topRight: target.topRight + PlanePoint(x: -0.55, y: -2.8),
                bottomRight: target.bottomRight,
                bottomLeft: target.bottomLeft
            )
            let card = firstContact.interpolated(to: target, progress: settle)
            return PlaneLockPose(
                phase: rawSettle < 0.12 ? .firstEdgeContact : .settling,
                surface: .cardBack,
                cardQuad: card,
                groundQuad: target,
                shadowQuad: directedShadow(ground: target, height: 0),
                height: 0,
                storedMaterialCurlMillimeters: 1.1 * (1 - settle),
                hasContacted: true
            )
        }

        let rawProgress = time / Self.firstContactTime
        let travel = smooth(rawProgress)
        let center = PlanePoint(
            x: calibration.sourceCenter.x + (calibration.targetCenter.x - calibration.sourceCenter.x) * travel,
            y: calibration.sourceCenter.y + (calibration.targetCenter.y - calibration.sourceCenter.y) * travel
        )
        let ground = calibration.homography.projectedQuad(
            center: center,
            halfWidth: calibration.cardHalfWidth,
            halfHeight: calibration.cardHalfHeight
        )
        let height = 34 * pow(max(0, sin(.pi * rawProgress)), 0.92)
        let lift = PlanePoint(x: -0.10 * height, y: -height)
        var card = ground
            .scaled(around: ground.center, by: 1 + 0.045 * height / 34)
            .translated(by: lift)
        let contactPreparation = smooth(min(max((rawProgress - 0.84) / 0.16, 0), 1))
        card = PlaneQuad(
            topLeft: card.topLeft + PlanePoint(x: -0.55, y: -2.8) * contactPreparation,
            topRight: card.topRight + PlanePoint(x: -0.55, y: -2.8) * contactPreparation,
            bottomRight: card.bottomRight,
            bottomLeft: card.bottomLeft
        )
        return PlaneLockPose(
            phase: time == 0 ? .source : .flight,
            surface: .cardBack,
            cardQuad: card,
            groundQuad: ground,
            shadowQuad: directedShadow(ground: ground, height: height),
            height: height,
            storedMaterialCurlMillimeters: 1.1,
            hasContacted: false
        )
    }

    private func directedShadow(ground: PlaneQuad, height: Double) -> PlaneQuad {
        let heightRatio = min(max(height / 34, 0), 1)
        let lightAway = lightProfile.keyDirection * -1
        let magnitude = lightProfile.restingShadowOffset
            + (lightProfile.airborneShadowOffset - lightProfile.restingShadowOffset) * heightRatio
        let offset = lightAway * magnitude
        return ground
            .scaled(around: ground.center, by: 1 + 0.05 * heightRatio)
            .translated(by: offset)
    }

    private func smooth(_ rawValue: Double) -> Double {
        let value = min(max(rawValue, 0), 1)
        return value * value * (3 - 2 * value)
    }
}

struct PlaneLockEngine: Equatable, Sendable {
    private(set) var stepIndex = 0
    private(set) var simulationTime = 0.0
    let motion = PlaneLockMotion()

    mutating func reset() {
        stepIndex = 0
        simulationTime = 0
    }

    mutating func advanceFixedStep() {
        stepIndex += 1
        simulationTime = min(Double(stepIndex) * PlaneLockMotion.fixedStep, PlaneLockMotion.sequenceDuration)
    }

    var snapshot: PlaneLockSnapshot {
        PlaneLockSnapshot(
            fixedStepIndex: stepIndex,
            simulationTime: simulationTime,
            pose: motion.pose(at: simulationTime)
        )
    }
}

func maximumCornerDeviation(_ lhs: PlaneQuad, _ rhs: PlaneQuad) -> Double {
    zip(lhs.points, rhs.points).map { ($0 - $1).length }.max() ?? 0
}

func convexQuadContains(_ quad: PlaneQuad, point: PlanePoint, tolerance: Double = 0) -> Bool {
    var sign: FloatingPointSign?
    let points = quad.points
    for index in points.indices {
        let first = points[index]
        let second = points[(index + 1) % points.count]
        let cross = (second.x - first.x) * (point.y - first.y)
            - (second.y - first.y) * (point.x - first.x)
        if abs(cross) <= tolerance { continue }
        if let sign, sign != cross.sign { return false }
        sign = cross.sign
    }
    return true
}
