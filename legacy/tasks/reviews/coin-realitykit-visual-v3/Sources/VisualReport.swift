import Foundation

struct SizeRecord: Codable { let width: Int; let height: Int }

struct DisplayFrameTraceRecord: Codable {
    let frame: Int
    let timeSeconds: Double
    let centerXMeters: Double
    let centerYMeters: Double
    let centerZMeters: Double
    let orientationX: Double
    let orientationY: Double
    let orientationZ: Double
    let orientationW: Double
    let analyticOverlapMillimeters: Double
    let cameraProjectedPenetrationPixels: Double
}

struct VisualRunResult: Codable {
    let viewport: String
    let outputSizePixels: SizeRecord
    let caseName: String
    let displayFramesEvaluated: Int
    let sequenceFramesCaptured: Int
    let allCapturedImagesExactSize: Bool
    let contactCount: Int
    let lipContact: Bool
    let maximumReportedPenetrationMillimeters: Double
    let maximumAnalyticOverlapMillimeters: Double
    let settledAnalyticOverlapMillimeters: Double?
    let maximumCameraProjectedPenetrationPixels: Double
    let maximumEnergyGainRatio: Double
    let remainedContained: Bool
    let sustainedRestSeconds: Double
    let authoredVelocityWritesAfterSpawn: Int
    let authoredTransformWritesAfterSpawn: Int
    let technicalPassed: Bool
    let visualPixelGatePassed: Bool
    let failures: [String]
    let frameDirectory: String
}

struct VisualContractReport: Codable {
    let contract: String
    let runtime: String
    let physicalRestOverlapLimitMillimeters: Double
    let cameraProjectedPenetrationLimitPixels: Double
    let fixedCamera: String
    let collisionMeshSegments: Int
    let visualMeshSegments: Int
    let continuousCollisionDetection: Bool
    let technicalVerdict: String
    let automatedVisualVerdict: String
    let priorPhysicalRedPreserved: String
    let runs: [VisualRunResult]
}

enum VisualReportWriter {
    static func outputDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("coin-realitykit-visual-v3", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func write(_ report: VisualContractReport) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = try outputDirectory().appendingPathComponent("runtime-result.json")
        try encoder.encode(report).write(to: url, options: .atomic)
        try Data("done\n".utf8).write(
            to: try outputDirectory().appendingPathComponent("DONE"),
            options: .atomic
        )
        return url
    }
}
