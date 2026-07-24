import Foundation

struct MotionPoint: Codable, Equatable, Hashable, Sendable {
    let x: Double
    let y: Double

    var isFinite: Bool { x.isFinite && y.isFinite }
}

struct MotionShadowSample: Codable, Equatable, Hashable, Sendable {
    let offset: MotionPoint
    let blurRadius: Double
    let opacity: Double

    var isValid: Bool {
        offset.isFinite
            && blurRadius.isFinite && blurRadius >= 0
            && opacity.isFinite && (0...1).contains(opacity)
    }
}

/// One renderer-neutral sample of a certified physical path.
struct MotionSample: Codable, Equatable, Hashable, Sendable {
    let normalizedTime: Double
    let position: MotionPoint
    let depth: Double
    let rotationDegrees: Double
    let curlMillimeters: Double
    let shadow: MotionShadowSample

    var isValid: Bool {
        normalizedTime.isFinite && (0...1).contains(normalizedTime)
            && position.isFinite
            && depth.isFinite
            && rotationDegrees.isFinite
            && curlMillimeters.isFinite
            && shadow.isValid
    }
}

struct MotionContactMarker: Codable, Equatable, Hashable, Sendable {
    let sampleIndex: Int
    let timeSeconds: Double
    let surfaceID: String
}

struct MotionRestWindow: Codable, Equatable, Hashable, Sendable {
    let startTimeSeconds: Double
    let minimumDurationSeconds: Double
}

enum MotionCancelBeforeRelease: String, Codable, Sendable {
    case remainAtVisibleSource
}

enum MotionCancelInFlight: String, Codable, Sendable {
    case completeCertifiedPath
}

enum MotionCancelAfterContact: String, Codable, Sendable {
    case visibleCounterMotion
}

/// The certified cancel contract: no new spatial exit path during committed flight.
struct MotionCancelPolicy: Codable, Equatable, Hashable, Sendable {
    static let committedFlight = MotionCancelPolicy(
        beforeRelease: .remainAtVisibleSource,
        inFlight: .completeCertifiedPath,
        afterContact: .visibleCounterMotion
    )

    let beforeRelease: MotionCancelBeforeRelease
    let inFlight: MotionCancelInFlight
    let afterContact: MotionCancelAfterContact
}

enum MotionMaterialFamily: String, Codable, CaseIterable, Sendable {
    case cardStock
    case copperCent
    case r1Ceramic
}

/// Pure presentation data. It deliberately imports neither PochKit nor game state.
struct MotionPlaybackPlan: Codable, Equatable, Hashable, Sendable {
    let stableID: String
    let materialFamily: MotionMaterialFamily
    let worldLightID: String
    let durationSeconds: Double
    let samples: [MotionSample]
    let contact: MotionContactMarker
    let restWindow: MotionRestWindow
    let cancelPolicy: MotionCancelPolicy

    var isValid: Bool {
        guard !stableID.isEmpty,
              !worldLightID.isEmpty,
              durationSeconds.isFinite,
              durationSeconds > 0,
              samples.count >= 2,
              samples.allSatisfy(\.isValid),
              samples.first?.normalizedTime == 0,
              samples.last?.normalizedTime == 1,
              samples.indices.dropFirst().allSatisfy({
                  samples[$0 - 1].normalizedTime < samples[$0].normalizedTime
              }),
              samples.indices.contains(contact.sampleIndex),
              !contact.surfaceID.isEmpty,
              contact.timeSeconds.isFinite,
              (0...durationSeconds).contains(contact.timeSeconds),
              restWindow.startTimeSeconds.isFinite,
              restWindow.minimumDurationSeconds.isFinite,
              restWindow.startTimeSeconds >= contact.timeSeconds,
              restWindow.minimumDurationSeconds > 0 else {
            return false
        }

        let sampledContactTime = samples[contact.sampleIndex].normalizedTime * durationSeconds
        return abs(sampledContactTime - contact.timeSeconds) <= 0.000_001
    }
}

struct MotionVariantBucket: Codable, Equatable, Hashable, Sendable {
    static let minimumVariantCount = 9

    let stableID: String
    let plans: [MotionPlaybackPlan]

    var isValid: Bool {
        !stableID.isEmpty
            && plans.count >= Self.minimumVariantCount
            && Set(plans.map(\.stableID)).count == plans.count
            && Set(plans).count == plans.count
            && plans.allSatisfy(\.isValid)
    }
}

struct MotionVariantSelection: Codable, Equatable, Hashable, Sendable {
    let bucketID: String
    let transferIndex: Int
    let plan: MotionPlaybackPlan
}

enum MotionVariantSelector {
    /// Selects along one full-cycle modular walk. With at least nine variants,
    /// every rolling window of eight transfers contains eight different plans.
    static func selections(
        from bucket: MotionVariantBucket,
        seed: UInt64,
        count: Int
    ) -> [MotionVariantSelection] {
        guard bucket.isValid, count > 0 else { return [] }

        var random = MotionStableRandom(seed: seed ^ stableSalt(bucket.stableID))
        let variantCount = bucket.plans.count
        let offset = Int(random.next() % UInt64(variantCount))
        let validSteps = (1..<variantCount).filter { greatestCommonDivisor($0, variantCount) == 1 }
        guard !validSteps.isEmpty else { return [] }
        let step = validSteps[Int(random.next() % UInt64(validSteps.count))]

        return (0..<count).map { transferIndex in
            let index = (offset + transferIndex * step) % variantCount
            return MotionVariantSelection(
                bucketID: bucket.stableID,
                transferIndex: transferIndex,
                plan: bucket.plans[index]
            )
        }
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a
    }

    private static func stableSalt(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

struct DealRhythmScheduleEntry: Codable, Equatable, Hashable, Sendable {
    let cardIndex: Int
    let rhythmTargetSeconds: Double
    let actualStartSeconds: Double
    let restWindowStartSeconds: Double
}

struct DealRhythmSchedule: Codable, Equatable, Hashable, Sendable {
    let entries: [DealRhythmScheduleEntry]

    init?(rhythmTargetsSeconds: [Double], restWindowStartsSeconds: [Double]) {
        guard !rhythmTargetsSeconds.isEmpty,
              rhythmTargetsSeconds.count == restWindowStartsSeconds.count,
              rhythmTargetsSeconds.allSatisfy({ $0.isFinite && $0 >= 0 }),
              restWindowStartsSeconds.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            return nil
        }

        entries = rhythmTargetsSeconds.indices.map { index in
            let rhythmTarget = rhythmTargetsSeconds[index]
            let actualStart = index < 2
                ? rhythmTarget
                : max(rhythmTarget, restWindowStartsSeconds[index - 2])
            return DealRhythmScheduleEntry(
                cardIndex: index,
                rhythmTargetSeconds: rhythmTarget,
                actualStartSeconds: actualStart,
                restWindowStartSeconds: restWindowStartsSeconds[index]
            )
        }
    }
}

enum MotionTranscriptCodec {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

private struct MotionStableRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
