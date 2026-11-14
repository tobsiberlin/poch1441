import Foundation

struct SpikeCaseResult: Codable, Sendable {
    let name: String
    let contactCount: Int
    let maximumReportedPenetrationMeters: Double
    let maximumRelativeEnergyGrowth: Double
    let maximumOrientationDeltaDegrees: Double
    let sustainedRestSeconds: Double
    let lipContact: Bool
    let remainedContained: Bool
    let passed: Bool
    let failures: [String]
}

struct SpikeReport: Codable, Sendable {
    let sdkRuntime: String
    let verdict: String
    let frameP95Milliseconds: Double
    let cases: [SpikeCaseResult]
    let commands: [String]
}

enum SpikeReportWriter {
    static func write(_ report: SpikeReport) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent("coin-realitykit-spike-result.json")
        try data.write(to: url, options: .atomic)
        return url
    }
}
