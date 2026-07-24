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

/// Renderer-neutral playback for an already validated motion transcript.
/// Callers own the clock and therefore remain testable without SwiftUI.
@MainActor
final class TranscriptMotionPlayer {
    typealias Callback = @MainActor () -> Void

    private let plan: MotionPlaybackPlan
    private let timeline: TranscriptPlaybackTimeline

    init?(
        plan: MotionPlaybackPlan,
        mode: TranscriptPlaybackMode,
        onContact: @escaping Callback,
        onRest: @escaping Callback,
        onCancelBeforeRelease: @escaping Callback
    ) {
        guard plan.isValid,
              let timeline = TranscriptPlaybackTimeline(
                mode: mode,
                contactTimeSeconds: plan.contact.timeSeconds,
                restTimeSeconds: plan.restWindow.startTimeSeconds,
                onContact: onContact,
                onRest: onRest,
                onCancelBeforeRelease: onCancelBeforeRelease
              ) else { return nil }
        self.plan = plan
        self.timeline = timeline
    }

    var currentSnapshot: TranscriptPlaybackSnapshot {
        snapshot(from: timeline.currentSnapshot)
    }

    func release(at hostTime: Double) -> TranscriptPlaybackSnapshot {
        snapshot(from: timeline.release(at: hostTime))
    }

    func advance(to hostTime: Double) -> TranscriptPlaybackSnapshot {
        snapshot(from: timeline.advance(to: hostTime))
    }

    func cancel(at hostTime: Double) -> TranscriptPlaybackSnapshot {
        snapshot(from: timeline.cancel(at: hostTime))
    }

    private func snapshot(from timelineSnapshot: TranscriptTimelineSnapshot) -> TranscriptPlaybackSnapshot {
        let clampedElapsed = timelineSnapshot.elapsedSeconds
        let normalized: Double
        if clampedElapsed + 0.000_000_001 >= plan.durationSeconds {
            normalized = 1
        } else {
            normalized = min(max(clampedElapsed / plan.durationSeconds, 0), 1)
        }
        return TranscriptPlaybackSnapshot(
            phase: timelineSnapshot.phase,
            elapsedSeconds: clampedElapsed,
            sample: interpolatedSample(at: normalized),
            isMoving: timelineSnapshot.isMoving,
            contactDelivered: timelineSnapshot.contactDelivered,
            restDelivered: timelineSnapshot.restDelivered,
            committedCancelIgnored: timelineSnapshot.committedCancelIgnored
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
