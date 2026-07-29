import Foundation

struct Vector3Record: Codable, Sendable {
    let x: Double
    let y: Double
    let z: Double
}

struct QuaternionRecord: Codable, Sendable {
    let x: Double
    let y: Double
    let z: Double
    let w: Double
}

struct TransformRecord: Codable, Sendable {
    let centerPositionMeters: Vector3Record
    let orientationXYZW: QuaternionRecord
}

struct ContactRecord: Codable, Sendable {
    let timeSeconds: Double
    let reportedPenetrationMeters: Double
    let transformGeometrySignedGapMeters: Double
}

struct GeometryRecord: Codable, Sendable {
    let floorTopYMeters: Double
    let supportBottomYMeters: Double
    let signedGapMeters: Double
    let overlapMeters: Double
}

struct CalibrationCaseResult: Codable, Sendable {
    let name: String
    let bodyKind: String
    let nominalDimensionsMeters: Vector3Record
    let visualMeshSegments: Int?
    let collisionMeshSegments: Int?
    let collisionRadialSagittaMeters: Double?
    let contactCount: Int
    let penetrationSampleCount: Int
    let firstContact: ContactRecord?
    let maximumReportedContact: ContactRecord?
    let lastReportedContact: ContactRecord?
    let settledReportedContact: ContactRecord?
    let minimumTransformGeometrySignedGapMeters: Double
    let finalTransform: TransformRecord
    let finalGeometry: GeometryRecord
    let sustainedRestSeconds: Double
    let passed: Bool
    let failures: [String]
}

struct CalibrationReport: Codable, Sendable {
    let sdkRuntime: String
    let verdict: String
    let penetrationLimitMeters: Double
    let finding: String
    let frameP95Milliseconds: Double
    let cases: [CalibrationCaseResult]
    let commands: [String]
}

enum CalibrationReportWriter {
    static func write(_ report: CalibrationReport) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent("coin-realitykit-calibration-result.json")
        try data.write(to: url, options: .atomic)
        return url
    }
}

