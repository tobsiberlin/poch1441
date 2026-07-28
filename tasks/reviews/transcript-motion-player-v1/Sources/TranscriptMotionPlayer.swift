import Foundation

enum TranscriptPlaybackMode: String, Codable, Sendable {
    case standard
    case reducedMotion
}

enum TranscriptPlaybackPhase: String, Codable, Sendable {
    case prepared
    case inFlight
    case settling
    case resting
    case cancelledBeforeRelease
}

struct TranscriptPlaybackSnapshot: Equatable, Sendable {
    let phase: TranscriptPlaybackPhase
    let elapsedSeconds: Double
    let sample: MotionSample
    let isMoving: Bool
    let contactDelivered: Bool
    let restDelivered: Bool
    let committedCancelIgnored: Bool
}

@MainActor
final class TranscriptMotionPlayer {
    typealias Callback = @MainActor @Sendable () -> Void
    private static let timeTolerance = 0.000_000_001

    private let plan: MotionPlaybackPlan
    private let mode: TranscriptPlaybackMode
    private let onContact: Callback
    private let onRest: Callback
    private let onCancelBeforeRelease: Callback

    private(set) var phase: TranscriptPlaybackPhase = .prepared
    private(set) var contactDelivered = false
    private(set) var restDelivered = false
    private(set) var committedCancelIgnored = false
    private var releaseHostTime: Double?
    private var cancelBeforeReleaseDelivered = false
    private var lastElapsedSeconds = 0.0

    init?(
        plan: MotionPlaybackPlan,
        mode: TranscriptPlaybackMode,
        onContact: @escaping Callback,
        onRest: @escaping Callback,
        onCancelBeforeRelease: @escaping Callback
    ) {
        guard plan.isValid else { return nil }
        self.plan = plan
        self.mode = mode
        self.onContact = onContact
        self.onRest = onRest
        self.onCancelBeforeRelease = onCancelBeforeRelease
    }

    var currentSnapshot: TranscriptPlaybackSnapshot {
        snapshot(elapsedSeconds: currentElapsedSeconds)
    }

    func release(at hostTime: Double) -> TranscriptPlaybackSnapshot {
        guard phase == .prepared, hostTime.isFinite else { return currentSnapshot }
        releaseHostTime = hostTime
        lastElapsedSeconds = 0
        if mode == .reducedMotion {
            deliverContactIfNeeded()
            deliverRestIfNeeded()
            phase = .resting
            return snapshot(elapsedSeconds: plan.restWindow.startTimeSeconds)
        }
        phase = .inFlight
        return snapshot(elapsedSeconds: 0)
    }

    func advance(to hostTime: Double) -> TranscriptPlaybackSnapshot {
        guard hostTime.isFinite, let releaseHostTime else { return currentSnapshot }
        if mode == .reducedMotion {
            return snapshot(elapsedSeconds: plan.restWindow.startTimeSeconds)
        }

        let elapsed = max(lastElapsedSeconds, max(0, hostTime - releaseHostTime))
        lastElapsedSeconds = elapsed
        if elapsed + Self.timeTolerance >= plan.contact.timeSeconds {
            deliverContactIfNeeded()
            phase = .settling
        }
        if elapsed + Self.timeTolerance >= plan.restWindow.startTimeSeconds {
            deliverRestIfNeeded()
            phase = .resting
        }
        return snapshot(elapsedSeconds: elapsed)
    }

    func cancel(at hostTime: Double) -> TranscriptPlaybackSnapshot {
        guard hostTime.isFinite else { return currentSnapshot }
        if phase == .inFlight || phase == .settling {
            _ = advance(to: hostTime)
        }
        switch phase {
        case .prepared:
            phase = .cancelledBeforeRelease
            if !cancelBeforeReleaseDelivered {
                cancelBeforeReleaseDelivered = true
                onCancelBeforeRelease()
            }
        case .inFlight, .settling:
            // MotionCancelPolicy.committedFlight forbids a teleport exit. The
            // certified path remains authoritative through contact and rest.
            committedCancelIgnored = true
        case .resting, .cancelledBeforeRelease:
            break
        }
        return currentSnapshot
    }

    private var currentElapsedSeconds: Double {
        switch phase {
        case .prepared, .cancelledBeforeRelease: 0
        case .inFlight, .settling: lastElapsedSeconds
        case .resting: plan.restWindow.startTimeSeconds
        }
    }

    private func deliverContactIfNeeded() {
        guard !contactDelivered else { return }
        contactDelivered = true
        onContact()
    }

    private func deliverRestIfNeeded() {
        guard !restDelivered else { return }
        restDelivered = true
        onRest()
    }

    private func snapshot(elapsedSeconds: Double) -> TranscriptPlaybackSnapshot {
        let clampedElapsed = min(max(elapsedSeconds, 0), plan.restWindow.startTimeSeconds)
        let normalized: Double
        if clampedElapsed + Self.timeTolerance >= plan.durationSeconds {
            normalized = 1
        } else {
            normalized = min(max(clampedElapsed / plan.durationSeconds, 0), 1)
        }
        return TranscriptPlaybackSnapshot(
            phase: phase,
            elapsedSeconds: clampedElapsed,
            sample: interpolatedSample(at: normalized),
            isMoving: phase == .inFlight || phase == .settling,
            contactDelivered: contactDelivered,
            restDelivered: restDelivered,
            committedCancelIgnored: committedCancelIgnored
        )
    }

    private func interpolatedSample(at normalizedTime: Double) -> MotionSample {
        guard let first = plan.samples.first, let last = plan.samples.last else {
            preconditionFailure("Validated plans always contain at least two samples")
        }
        guard normalizedTime > first.normalizedTime else { return first }
        guard normalizedTime < last.normalizedTime else { return last }

        guard let upperIndex = plan.samples.firstIndex(where: {
            $0.normalizedTime >= normalizedTime
        }), upperIndex > 0 else { return last }
        let lower = plan.samples[upperIndex - 1]
        let upper = plan.samples[upperIndex]
        let span = upper.normalizedTime - lower.normalizedTime
        let amount = span > 0 ? (normalizedTime - lower.normalizedTime) / span : 1
        return MotionSample(
            normalizedTime: normalizedTime,
            position: MotionPoint(
                x: interpolate(lower.position.x, upper.position.x, amount),
                y: interpolate(lower.position.y, upper.position.y, amount)
            ),
            depth: interpolate(lower.depth, upper.depth, amount),
            rotationDegrees: interpolate(lower.rotationDegrees, upper.rotationDegrees, amount),
            curlMillimeters: interpolate(lower.curlMillimeters, upper.curlMillimeters, amount),
            shadow: MotionShadowSample(
                offset: MotionPoint(
                    x: interpolate(lower.shadow.offset.x, upper.shadow.offset.x, amount),
                    y: interpolate(lower.shadow.offset.y, upper.shadow.offset.y, amount)
                ),
                blurRadius: interpolate(lower.shadow.blurRadius, upper.shadow.blurRadius, amount),
                opacity: interpolate(lower.shadow.opacity, upper.shadow.opacity, amount)
            )
        )
    }

    private func interpolate(_ start: Double, _ end: Double, _ amount: Double) -> Double {
        start + (end - start) * amount
    }
}
