import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// A clock domain is intentionally explicit. Timestamps from different domains
/// must never be subtracted before a measured clock bridge has been applied.
enum MotionSyncClockDomain: String, Codable, Sendable {
    /// `mach_absolute_time`, normalized to nanoseconds at capture time.
    case deviceHost
    /// Camera frames and recorder samples, aligned by the laboratory sync slate.
    case externalCapture
}

enum MotionSyncObjectKind: String, Codable, Sendable {
    case coin
    case card
}

enum MotionSyncMotionVariant: String, Codable, Sendable {
    case standard
    case reducedMotion
}

enum MotionSyncMarkerKind: String, Codable, Sendable {
    // Software diagnostics. These may explain a failure but cannot pass the
    // physical acceptance gate on their own.
    case simulationContact
    case visualSubmitted
    case audioScheduled
    case audioRenderObserved
    case hapticScheduled
    case cancelled

    // Physical laboratory evidence in the externalCapture domain.
    case physicalVisualContact
    case physicalAudioOnset
    case physicalHapticOnset
}

enum MotionSyncEvidenceSource: String, Codable, Sendable {
    case hostClock
    case displayLink
    case audioRenderTap
    case hapticEngine
    case highSpeedVideo
    case acousticMicrophone
    case contactMicrophone
}

enum MotionSyncThermalState: String, Codable, CaseIterable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown
}

struct MotionSyncObservation: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let runID: String
    let eventID: String
    let generation: Int
    let object: MotionSyncObjectKind
    let variant: MotionSyncMotionVariant
    let marker: MotionSyncMarkerKind
    let clockDomain: MotionSyncClockDomain
    /// Nanoseconds relative to the domain's run epoch. Device-host values are
    /// converted from mach ticks; external values are derived from measured
    /// camera frame and recorder sample timestamps.
    let timestampNanoseconds: UInt64
    let source: MotionSyncEvidenceSource

    init(
        schemaVersion: Int = 1,
        runID: String,
        eventID: String,
        generation: Int,
        object: MotionSyncObjectKind,
        variant: MotionSyncMotionVariant,
        marker: MotionSyncMarkerKind,
        clockDomain: MotionSyncClockDomain,
        timestampNanoseconds: UInt64,
        source: MotionSyncEvidenceSource
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.eventID = eventID
        self.generation = generation
        self.object = object
        self.variant = variant
        self.marker = marker
        self.clockDomain = clockDomain
        self.timestampNanoseconds = timestampNanoseconds
        self.source = source
    }
}

struct MotionSyncRunMetadata: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let runID: String
    let deviceModel: String
    let osBuild: String
    /// Derived from the first stable CADisplayLink interval segment. This is
    /// evidence, not a capability inferred from the device model.
    let initialMeasuredDisplayRefreshHertz: Int?
    let requestedFrameRateMinimumHertz: Double
    let requestedFrameRateMaximumHertz: Double
    let requestedFrameRatePreferredHertz: Double
    let audioSampleRateHertz: Double
    let audioRoute: String
    let hapticsAvailable: Bool
    let lowPowerModeEnabled: Bool
    let initialThermalState: MotionSyncThermalState

    init(
        schemaVersion: Int = 1,
        runID: String,
        deviceModel: String,
        osBuild: String,
        initialMeasuredDisplayRefreshHertz: Int?,
        requestedFrameRateMinimumHertz: Double,
        requestedFrameRateMaximumHertz: Double,
        requestedFrameRatePreferredHertz: Double,
        audioSampleRateHertz: Double,
        audioRoute: String,
        hapticsAvailable: Bool,
        lowPowerModeEnabled: Bool,
        initialThermalState: MotionSyncThermalState
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.deviceModel = deviceModel
        self.osBuild = osBuild
        self.initialMeasuredDisplayRefreshHertz = initialMeasuredDisplayRefreshHertz
        self.requestedFrameRateMinimumHertz = requestedFrameRateMinimumHertz
        self.requestedFrameRateMaximumHertz = requestedFrameRateMaximumHertz
        self.requestedFrameRatePreferredHertz = requestedFrameRatePreferredHertz
        self.audioSampleRateHertz = audioSampleRateHertz
        self.audioRoute = audioRoute
        self.hapticsAvailable = hapticsAvailable
        self.lowPowerModeEnabled = lowPowerModeEnabled
        self.initialThermalState = initialThermalState
    }
}

struct MotionSyncRefreshDecision: Equatable, Sendable {
    let activeRefreshHertz: Int
    let startsNewSegment: Bool
}

/// Converts observed CADisplayLink intervals into stable rate segments. It does
/// not read the device model and does not trust a preferred frame-rate request.
struct MotionSyncRefreshRateTracker: Sendable {
    private let supportedRates = [120, 80, 60]
    private let relativeTolerance: Double
    private let confirmationCount: Int
    private var activeRate: Int?
    private var pendingRate: Int?
    private var pendingCount = 0

    init(relativeTolerance: Double = 0.12, confirmationCount: Int = 3) {
        self.relativeTolerance = relativeTolerance
        self.confirmationCount = max(1, confirmationCount)
    }

    mutating func observe(displayIntervalNanoseconds: UInt64) -> MotionSyncRefreshDecision? {
        guard displayIntervalNanoseconds > 0 else { return nil }
        let measuredHertz = 1_000_000_000 / Double(displayIntervalNanoseconds)
        guard let candidate = supportedRates.min(by: {
            abs(Double($0) - measuredHertz) < abs(Double($1) - measuredHertz)
        }) else { return nil }
        let relativeError = abs(Double(candidate) - measuredHertz) / Double(candidate)
        guard relativeError <= relativeTolerance else {
            pendingRate = nil
            pendingCount = 0
            return nil
        }

        if candidate == activeRate {
            pendingRate = nil
            pendingCount = 0
            return MotionSyncRefreshDecision(
                activeRefreshHertz: candidate,
                startsNewSegment: false
            )
        }

        if candidate == pendingRate {
            pendingCount += 1
        } else {
            pendingRate = candidate
            pendingCount = 1
        }

        guard pendingCount >= confirmationCount else { return nil }
        activeRate = candidate
        pendingRate = nil
        pendingCount = 0
        return MotionSyncRefreshDecision(
            activeRefreshHertz: candidate,
            startsNewSegment: true
        )
    }
}

struct MotionSyncFrameSample: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let runID: String
    let segmentIndex: Int
    let frameIndex: Int
    let displayTimestampNanoseconds: UInt64
    /// Difference between consecutive actual CADisplayLink timestamps.
    let observedDisplayIntervalNanoseconds: UInt64
    /// CPU plus GPU work for this frame, measured from render begin until the
    /// command buffer or equivalent presentation work is complete.
    let renderDurationNanoseconds: UInt64
    let measuredRefreshHertz: Int
    let lowPowerModeEnabled: Bool
    let thermalState: MotionSyncThermalState

    init(
        schemaVersion: Int = 1,
        runID: String,
        segmentIndex: Int,
        frameIndex: Int,
        displayTimestampNanoseconds: UInt64,
        observedDisplayIntervalNanoseconds: UInt64,
        renderDurationNanoseconds: UInt64,
        measuredRefreshHertz: Int,
        lowPowerModeEnabled: Bool,
        thermalState: MotionSyncThermalState
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.segmentIndex = segmentIndex
        self.frameIndex = frameIndex
        self.displayTimestampNanoseconds = displayTimestampNanoseconds
        self.observedDisplayIntervalNanoseconds = observedDisplayIntervalNanoseconds
        self.renderDurationNanoseconds = renderDurationNanoseconds
        self.measuredRefreshHertz = measuredRefreshHertz
        self.lowPowerModeEnabled = lowPowerModeEnabled
        self.thermalState = thermalState
    }
}

struct MotionSyncFrameSegmentEvaluation: Equatable, Sendable {
    let runID: String
    let segmentIndex: Int
    let measuredRefreshHertz: Int?
    let frameCount: Int
    let frameTimeP99Milliseconds: Double?
    let budgetMilliseconds: Double?
    let lowPowerModeStates: Set<Bool>
    let thermalStates: Set<MotionSyncThermalState>
    let hasConsistentRate: Bool
    let hasConsistentOperatingConditions: Bool
    let hasMeasurableThermalState: Bool
    let passesMinimumFrameCount: Bool
    let passesFrameTime: Bool

    var passes: Bool {
        hasConsistentRate &&
            hasConsistentOperatingConditions &&
            hasMeasurableThermalState &&
            passesMinimumFrameCount &&
            passesFrameTime
    }
}

enum MotionSyncFrameEvaluator {
    private static let budgetsMilliseconds: [Int: Double] = [
        120: 8.33,
        80: 12.5,
        60: 16.67
    ]

    /// A run is evaluated as independent contiguous segments. The capture
    /// adapter increments `segmentIndex` whenever the confirmed measured rate,
    /// Low Power state, or thermal state changes.
    static func evaluate(
        _ samples: [MotionSyncFrameSample],
        minimumFramesPerSegment: Int = 120
    ) -> [MotionSyncFrameSegmentEvaluation] {
        let grouped = Dictionary(grouping: samples) {
            SegmentKey(runID: $0.runID, segmentIndex: $0.segmentIndex)
        }

        return grouped.map { key, segmentSamples in
            let rates = Set(segmentSamples.map(\.measuredRefreshHertz))
            let rate = rates.count == 1 ? rates.first : nil
            let budget = rate.flatMap { budgetsMilliseconds[$0] }
            let durations = segmentSamples.map {
                Double($0.renderDurationNanoseconds) / 1_000_000
            }
            let p99 = nearestRankPercentile(durations, percentile: 0.99)
            let enoughFrames = segmentSamples.count >= max(1, minimumFramesPerSegment)
            let lowPowerStates = Set(segmentSamples.map(\.lowPowerModeEnabled))
            let thermalStates = Set(segmentSamples.map(\.thermalState))
            let stableConditions = lowPowerStates.count == 1 && thermalStates.count == 1
            let measurableThermalState = thermalStates.isDisjoint(with: [.serious, .critical])
            let passesFrameTime = if let p99, let budget {
                p99 < budget
            } else {
                false
            }

            return MotionSyncFrameSegmentEvaluation(
                runID: key.runID,
                segmentIndex: key.segmentIndex,
                measuredRefreshHertz: rate,
                frameCount: segmentSamples.count,
                frameTimeP99Milliseconds: p99,
                budgetMilliseconds: budget,
                lowPowerModeStates: lowPowerStates,
                thermalStates: thermalStates,
                hasConsistentRate: rates.count == 1 && budget != nil,
                hasConsistentOperatingConditions: stableConditions,
                hasMeasurableThermalState: measurableThermalState,
                passesMinimumFrameCount: enoughFrames,
                passesFrameTime: passesFrameTime
            )
        }
        .sorted {
            ($0.runID, $0.segmentIndex) < ($1.runID, $1.segmentIndex)
        }
    }

    private struct SegmentKey: Hashable {
        let runID: String
        let segmentIndex: Int
    }

    private static func nearestRankPercentile(
        _ values: [Double],
        percentile: Double
    ) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let rank = Int(ceil(percentile * Double(sorted.count)))
        return sorted[max(0, rank - 1)]
    }
}

#if canImport(Darwin)
enum MotionSyncDeviceHostClock {
    private static let timebase: mach_timebase_info_data_t = {
        var value = mach_timebase_info_data_t()
        mach_timebase_info(&value)
        return value
    }()

    static func nowNanoseconds() -> UInt64 {
        nanoseconds(fromMachTicks: mach_absolute_time())
    }

    static func nanoseconds(fromMachTicks ticks: UInt64) -> UInt64 {
        let numerator = Double(timebase.numer)
        let denominator = Double(timebase.denom)
        return UInt64((Double(ticks) * numerator / denominator).rounded())
    }
}
#endif

/// Core Haptics exposes engine-relative seconds rather than AVAudioTime host
/// ticks. Capture the host clock immediately before and after reading
/// `CHHapticEngine.currentTime`; use their midpoint for the bridge anchor.
struct MotionSyncHapticClockAnchor: Equatable, Sendable {
    let hostNanosecondsAtMidpoint: UInt64
    let hapticEngineSeconds: Double

    func hostNanoseconds(forHapticEngineSeconds seconds: Double) -> UInt64 {
        let delta = Int64(((seconds - hapticEngineSeconds) * 1_000_000_000).rounded())
        if delta >= 0 {
            return hostNanosecondsAtMidpoint + UInt64(delta)
        }
        let magnitude = UInt64(-delta)
        return hostNanosecondsAtMidpoint >= magnitude
            ? hostNanosecondsAtMidpoint - magnitude
            : 0
    }
}

struct MotionSyncThresholds: Equatable, Sendable {
    let audioToImageP95Milliseconds: Double
    let hapticToImageP95Milliseconds: Double

    static let production = MotionSyncThresholds(
        audioToImageP95Milliseconds: 16.7,
        hapticToImageP95Milliseconds: 20.0
    )
}

struct MotionSyncEvaluation: Equatable, Sendable {
    let completeEventCount: Int
    let rejectedEventCount: Int
    let audioToImageP95Milliseconds: Double?
    let hapticToImageP95Milliseconds: Double?
    let passesMinimumSampleCount: Bool
    let passesAudio: Bool
    let passesHaptic: Bool

    var passes: Bool {
        passesMinimumSampleCount && passesAudio && passesHaptic
    }
}

enum MotionSyncEvaluator {
    /// Evaluates physical onsets only. Values are absolute temporal error, so an
    /// early cue and a late cue are penalized identically. p95 uses nearest rank
    /// and no outlier removal.
    static func evaluatePhysicalCapture(
        _ observations: [MotionSyncObservation],
        thresholds: MotionSyncThresholds = .production,
        minimumSampleCount: Int = 30
    ) -> MotionSyncEvaluation {
        let physical = observations.filter { observation in
            observation.clockDomain == .externalCapture &&
                [.physicalVisualContact, .physicalAudioOnset, .physicalHapticOnset]
                    .contains(observation.marker)
        }
        let grouped = Dictionary(grouping: physical) { observation in
            EventKey(
                runID: observation.runID,
                eventID: observation.eventID,
                generation: observation.generation,
                object: observation.object,
                variant: observation.variant
            )
        }

        var audioErrors: [Double] = []
        var hapticErrors: [Double] = []
        var rejected = 0

        for event in grouped.values {
            guard
                let visual = uniqueTimestamp(
                    for: .physicalVisualContact,
                    source: .highSpeedVideo,
                    in: event
                ),
                let audio = uniqueTimestamp(
                    for: .physicalAudioOnset,
                    source: .acousticMicrophone,
                    in: event
                ),
                let haptic = uniqueTimestamp(
                    for: .physicalHapticOnset,
                    source: .contactMicrophone,
                    in: event
                )
            else {
                rejected += 1
                continue
            }

            audioErrors.append(millisecondsBetween(visual, audio))
            hapticErrors.append(millisecondsBetween(visual, haptic))
        }

        let audioP95 = nearestRankP95(audioErrors)
        let hapticP95 = nearestRankP95(hapticErrors)
        let enoughSamples = audioErrors.count >= max(1, minimumSampleCount)

        return MotionSyncEvaluation(
            completeEventCount: audioErrors.count,
            rejectedEventCount: rejected,
            audioToImageP95Milliseconds: audioP95,
            hapticToImageP95Milliseconds: hapticP95,
            passesMinimumSampleCount: enoughSamples,
            passesAudio: audioP95.map { $0 <= thresholds.audioToImageP95Milliseconds } ?? false,
            passesHaptic: hapticP95.map { $0 <= thresholds.hapticToImageP95Milliseconds } ?? false
        )
    }

    private struct EventKey: Hashable {
        let runID: String
        let eventID: String
        let generation: Int
        let object: MotionSyncObjectKind
        let variant: MotionSyncMotionVariant
    }

    private static func uniqueTimestamp(
        for marker: MotionSyncMarkerKind,
        source: MotionSyncEvidenceSource,
        in observations: [MotionSyncObservation]
    ) -> UInt64? {
        let matches = observations.filter {
            $0.marker == marker && $0.source == source
        }
        guard matches.count == 1 else { return nil }
        return matches[0].timestampNanoseconds
    }

    private static func millisecondsBetween(_ lhs: UInt64, _ rhs: UInt64) -> Double {
        let delta = lhs > rhs ? lhs - rhs : rhs - lhs
        return Double(delta) / 1_000_000
    }

    private static func nearestRankP95(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let rank = Int(ceil(0.95 * Double(sorted.count)))
        return sorted[max(0, rank - 1)]
    }
}
