import CryptoKit
import Foundation

struct Vector3: Codable, Sendable {
    let x: Double
    let y: Double
    let z: Double
}

struct Quaternion: Codable, Sendable {
    let w: Double
    let x: Double
    let y: Double
    let z: Double

    var yaw: Double {
        atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z))
    }
}

struct TranscriptSample: Decodable, Sendable {
    let position: Vector3
    let orientation: Quaternion
}

struct SeedTranscript: Decodable, Sendable {
    let seed: UInt64
    let samples: [TranscriptSample]
}

struct TranscriptBundle: Decodable, Sendable {
    let transcripts: [SeedTranscript]
}

struct CommitPolicy: Decodable, Sendable {
    let commitPoint: String
    let preRelease: String
    let freeFlight: String
    let postContact: String
}

struct SelectionSummary: Decodable, Sendable {
    let availableTranscriptCount: Int
    let protectedHistoryLength: Int
    let repeatWithinProtectedHistory: Bool
}

struct GateSummary: Decodable, Sendable {
    let verdict: String
    let checks: Int
    let failures: [String]
    let commitPolicy: CommitPolicy
    let selection: SelectionSummary
}

struct InheritedCertificate: Encodable, Sendable {
    let source = "../coin-motion-transcript-gate-v1"
    let gateSummarySHA256: String
    let transcriptsSHA256: String
    let checks: Int
    let transcriptCount: Int
    let commitPoint: String
    let selectionPoolCount: Int
    let protectedHistoryLength: Int
}

enum InheritedEvidence {
    static func load(from repository: URL) throws -> (
        summary: GateSummary,
        bundle: TranscriptBundle,
        certificate: InheritedCertificate
    ) {
        let root = repository.appendingPathComponent(
            "tasks/reviews/coin-motion-transcript-gate-v1/Evidence",
            isDirectory: true
        )
        let summaryURL = root.appendingPathComponent("gate-summary.json")
        let transcriptURL = root.appendingPathComponent("coin-6dof-transcripts-12-seeds.json")
        let summaryData = try Data(contentsOf: summaryURL)
        let transcriptData = try Data(contentsOf: transcriptURL)
        let decoder = JSONDecoder()
        let summary = try decoder.decode(GateSummary.self, from: summaryData)
        let bundle = try decoder.decode(TranscriptBundle.self, from: transcriptData)
        let certificate = InheritedCertificate(
            gateSummarySHA256: digest(summaryData),
            transcriptsSHA256: digest(transcriptData),
            checks: summary.checks,
            transcriptCount: bundle.transcripts.count,
            commitPoint: summary.commitPolicy.commitPoint,
            selectionPoolCount: summary.selection.availableTranscriptCount,
            protectedHistoryLength: summary.selection.protectedHistoryLength
        )
        return (summary, bundle, certificate)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
