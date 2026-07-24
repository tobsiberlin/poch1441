import Foundation

struct CoinVector3: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let z: Double

    func interpolated(to other: CoinVector3, amount: Double) -> CoinVector3 {
        CoinVector3(
            x: x + (other.x - x) * amount,
            y: y + (other.y - y) * amount,
            z: z + (other.z - z) * amount
        )
    }
}

struct CoinQuaternion: Codable, Equatable, Sendable {
    let w: Double
    let x: Double
    let y: Double
    let z: Double

    var norm: Double { sqrt(w * w + x * x + y * y + z * z) }

    var yawRadians: Double {
        atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z))
    }

    var coinAxisZ: Double { 1 - 2 * (x * x + y * y) }

    /// Shortest-arc spherical interpolation. This retains 6DoF orientation and
    /// cannot jump at the ±π yaw boundary like scalar degree interpolation.
    func slerped(to destination: CoinQuaternion, amount: Double) -> CoinQuaternion {
        let clampedAmount = min(max(amount, 0), 1)
        var target = destination
        var dot = w * target.w + x * target.x + y * target.y + z * target.z
        if dot < 0 {
            dot = -dot
            target = CoinQuaternion(w: -target.w, x: -target.x, y: -target.y, z: -target.z)
        }

        if dot > 0.9995 {
            return CoinQuaternion(
                w: w + (target.w - w) * clampedAmount,
                x: x + (target.x - x) * clampedAmount,
                y: y + (target.y - y) * clampedAmount,
                z: z + (target.z - z) * clampedAmount
            ).normalized()
        }

        let theta0 = acos(min(max(dot, -1), 1))
        let sinTheta0 = sin(theta0)
        guard abs(sinTheta0) > 0.000_000_001 else { return self }
        let theta = theta0 * clampedAmount
        let startScale = cos(theta) - dot * sin(theta) / sinTheta0
        let endScale = sin(theta) / sinTheta0
        return CoinQuaternion(
            w: startScale * w + endScale * target.w,
            x: startScale * x + endScale * target.x,
            y: startScale * y + endScale * target.y,
            z: startScale * z + endScale * target.z
        ).normalized()
    }

    private func normalized() -> CoinQuaternion {
        let length = norm
        guard length.isFinite, length > 0 else { return self }
        return CoinQuaternion(w: w / length, x: x / length, y: y / length, z: z / length)
    }
}

enum CoinContactMarker: String, Codable, Equatable, Sendable {
    case impactBegin
    case contactImpulse
    case supportBegin
    case restWindowBegin
    case restCertified
}

struct CoinTranscriptSample: Codable, Equatable, Sendable {
    let time: Double
    let position: CoinVector3
    let orientation: CoinQuaternion
    let linearVelocity: CoinVector3
    let angularVelocity: CoinVector3
    let contacts: [CoinContactMarker]

    func interpolated(to other: CoinTranscriptSample, at time: Double) -> CoinTranscriptSample {
        let span = other.time - self.time
        let amount = span > 0 ? min(max((time - self.time) / span, 0), 1) : 1
        return CoinTranscriptSample(
            time: time,
            position: position.interpolated(to: other.position, amount: amount),
            orientation: orientation.slerped(to: other.orientation, amount: amount),
            linearVelocity: linearVelocity.interpolated(to: other.linearVelocity, amount: amount),
            angularVelocity: angularVelocity.interpolated(to: other.angularVelocity, amount: amount),
            contacts: amount < 1 ? contacts : other.contacts
        )
    }
}

struct CertifiedCoinTranscript: Codable, Equatable, Sendable {
    struct Selection: Codable, Equatable, Sendable {
        struct Bucket: Codable, Equatable, Sendable {
            let id: String
            let intensity: String
            let materialSignature: String
            let payload: String
            let targetWell: String
            let viewport: String
        }

        let auditDraws: [UInt64]
        let availableTranscriptCount: Int
        let bucket: Bucket
        let protectedHistoryLength: Int
        let repeatWithinProtectedHistory: Bool
    }

    struct Well: Codable, Equatable, Sendable {
        let name: String
        let sourceCenterPixels: CoinVector3
        let floorWidth: Double
        let floorHeight: Double
        let frontLipDepth: Double
        let screenWellWidthPixels: Double
    }

    struct Coin: Codable, Equatable, Sendable {
        let radius: Double
        let halfThickness: Double
        let mass: Double
    }

    struct Metrics: Codable, Equatable, Sendable {
        let seed: UInt64
        let contactCount: Int
        let maximumContactEnergyGainRatio: Double
        let maximumPenetrationMeters: Double
        let maximumPenetrationPhysicalPixels: Double
        let restingWindowSeconds: Double
        let finalLinearSpeedMetersPerSecond: Double
        let finalAngularSpeedRadiansPerSecond: Double
        let minimumContainmentMarginMeters: Double
        let hardVelocityZeroingUsed: Bool
        let passed: Bool
    }

    struct Transcript: Codable, Equatable, Sendable {
        let seed: UInt64
        let well: Well
        let coin: Coin
        let metrics: Metrics
        let samples: [CoinTranscriptSample]
    }

    let schema: String
    let stableID: String
    let sourceBundleSHA256: String
    let sourceSchema: String
    let sampleRateHertz: Int
    let materialFamily: String
    let worldLightID: String
    let surfaceID: String
    let selection: Selection
    let transcript: Transcript

    var contactSampleIndex: Int? {
        transcript.samples.firstIndex { $0.contacts.contains(.impactBegin) }
    }

    var restSampleIndex: Int? {
        transcript.samples.firstIndex { $0.contacts.contains(.restCertified) }
    }

    var contactTimeSeconds: Double? { contactSampleIndex.map { transcript.samples[$0].time } }
    var restTimeSeconds: Double? { restSampleIndex.map { transcript.samples[$0].time } }

    var isValid: Bool {
        guard schema == "poch.certified-coin-transcript.v1",
              sourceSchema == "poch.coin-6dof-transcript.v1",
              sourceBundleSHA256 == "76e883093a396548b07060d29d3f2149857240c1026cd1fefe35450de52d98be",
              sampleRateHertz == 240,
              materialFamily == "copperCent",
              worldLightID == "track-b-lamp-left-v1",
              surfaceID == "queen-outer-well",
              selection.availableTranscriptCount == 12,
              selection.protectedHistoryLength == 8,
              !selection.repeatWithinProtectedHistory,
              selection.bucket.targetWell == "queen",
              selection.bucket.payload == "single-cent",
              transcript.seed == 1_441,
              transcript.metrics.passed,
              !transcript.metrics.hardVelocityZeroingUsed,
              transcript.metrics.maximumContactEnergyGainRatio <= 0.0025,
              transcript.metrics.maximumPenetrationPhysicalPixels <= 0.5,
              transcript.samples.count == 388,
              let contactSampleIndex,
              let restSampleIndex,
              contactSampleIndex < restSampleIndex,
              contactSampleIndex == 18,
              restSampleIndex == transcript.samples.count - 1 else { return false }

        for index in transcript.samples.indices {
            let sample = transcript.samples[index]
            guard sample.time.isFinite,
                  sample.orientation.norm.isFinite,
                  abs(sample.orientation.norm - 1) <= 0.000_001 else { return false }
            if index > 0 {
                let expectedStep = 1.0 / Double(sampleRateHertz)
                guard abs(sample.time - transcript.samples[index - 1].time - expectedStep)
                        <= 0.000_000_001 else { return false }
            }
        }
        return contactTimeSeconds == 0.075 && restTimeSeconds == 1.6125
    }

    func sample(at elapsedSeconds: Double) -> CoinTranscriptSample {
        guard let first = transcript.samples.first,
              let last = transcript.samples.last else {
            preconditionFailure("Validated coin transcripts contain samples")
        }
        guard elapsedSeconds > first.time else { return first }
        guard elapsedSeconds < last.time else { return last }

        var lower = 0
        var upper = transcript.samples.count - 1
        while lower + 1 < upper {
            let middle = (lower + upper) / 2
            if transcript.samples[middle].time < elapsedSeconds {
                lower = middle
            } else {
                upper = middle
            }
        }
        return transcript.samples[lower].interpolated(
            to: transcript.samples[upper],
            at: elapsedSeconds
        )
    }

    static func decode(_ data: Data) throws -> CertifiedCoinTranscript {
        let decoded = try JSONDecoder().decode(CertifiedCoinTranscript.self, from: data)
        guard decoded.isValid else { throw ValidationError.invalidTranscript }
        return decoded
    }

    static func bundled() throws -> CertifiedCoinTranscript {
        guard let url = Bundle.main.url(
            forResource: "CertifiedCoinTranscriptSeed1441",
            withExtension: "json"
        ) else { throw ValidationError.missingResource }
        return try decode(Data(contentsOf: url))
    }

    enum ValidationError: Error { case invalidTranscript, missingResource }
}

struct CoinTranscriptPlaybackSnapshot: Equatable, Sendable {
    let phase: TranscriptPlaybackPhase
    let elapsedSeconds: Double
    let sample: CoinTranscriptSample
    let isMoving: Bool
    let contactDelivered: Bool
    let restDelivered: Bool
    let committedCancelIgnored: Bool
}

/// 6DoF-Consumer derselben TranscriptPlaybackTimeline wie der Kartenplayer.
@MainActor
final class CoinTranscriptMotionPlayer {
    typealias Callback = @MainActor () -> Void

    private let plan: CertifiedCoinTranscript
    private let timeline: TranscriptPlaybackTimeline

    init?(
        plan: CertifiedCoinTranscript,
        mode: TranscriptPlaybackMode,
        onContact: @escaping Callback,
        onRest: @escaping Callback,
        onCancelBeforeRelease: @escaping Callback
    ) {
        guard plan.isValid,
              let contactTime = plan.contactTimeSeconds,
              let restTime = plan.restTimeSeconds,
              let timeline = TranscriptPlaybackTimeline(
                mode: mode,
                contactTimeSeconds: contactTime,
                restTimeSeconds: restTime,
                onContact: onContact,
                onRest: onRest,
                onCancelBeforeRelease: onCancelBeforeRelease
              ) else { return nil }
        self.plan = plan
        self.timeline = timeline
    }

    var currentSnapshot: CoinTranscriptPlaybackSnapshot {
        snapshot(from: timeline.currentSnapshot)
    }

    func release(at hostTime: Double) -> CoinTranscriptPlaybackSnapshot {
        snapshot(from: timeline.release(at: hostTime))
    }

    func advance(to hostTime: Double) -> CoinTranscriptPlaybackSnapshot {
        snapshot(from: timeline.advance(to: hostTime))
    }

    func cancel(at hostTime: Double) -> CoinTranscriptPlaybackSnapshot {
        snapshot(from: timeline.cancel(at: hostTime))
    }

    private func snapshot(from timelineSnapshot: TranscriptTimelineSnapshot) -> CoinTranscriptPlaybackSnapshot {
        CoinTranscriptPlaybackSnapshot(
            phase: timelineSnapshot.phase,
            elapsedSeconds: timelineSnapshot.elapsedSeconds,
            sample: plan.sample(at: timelineSnapshot.elapsedSeconds),
            isMoving: timelineSnapshot.isMoving,
            contactDelivered: timelineSnapshot.contactDelivered,
            restDelivered: timelineSnapshot.restDelivered,
            committedCancelIgnored: timelineSnapshot.committedCancelIgnored
        )
    }
}
