import Foundation

struct TranscriptTimelineSnapshot: Equatable, Sendable {
    let phase: TranscriptPlaybackPhase
    let elapsedSeconds: Double
    let isMoving: Bool
    let contactDelivered: Bool
    let restDelivered: Bool
    let committedCancelIgnored: Bool
}

/// Gemeinsame, rendererneutrale Uhr für zertifizierte Karten- und Münztranskripte.
/// Sie besitzt weder Samples noch SwiftUI-State und publiziert jede physische
/// Kante höchstens einmal.
@MainActor
final class TranscriptPlaybackTimeline {
    typealias Callback = @MainActor () -> Void
    private static let timeTolerance = 0.000_000_001

    private let mode: TranscriptPlaybackMode
    private let contactTimeSeconds: Double
    private let restTimeSeconds: Double
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
        mode: TranscriptPlaybackMode,
        contactTimeSeconds: Double,
        restTimeSeconds: Double,
        onContact: @escaping Callback,
        onRest: @escaping Callback,
        onCancelBeforeRelease: @escaping Callback
    ) {
        guard contactTimeSeconds.isFinite,
              restTimeSeconds.isFinite,
              contactTimeSeconds >= 0,
              restTimeSeconds >= contactTimeSeconds else { return nil }
        self.mode = mode
        self.contactTimeSeconds = contactTimeSeconds
        self.restTimeSeconds = restTimeSeconds
        self.onContact = onContact
        self.onRest = onRest
        self.onCancelBeforeRelease = onCancelBeforeRelease
    }

    var currentSnapshot: TranscriptTimelineSnapshot {
        snapshot(elapsedSeconds: currentElapsedSeconds)
    }

    func release(at hostTime: Double) -> TranscriptTimelineSnapshot {
        guard phase == .prepared, hostTime.isFinite else { return currentSnapshot }
        releaseHostTime = hostTime
        lastElapsedSeconds = 0
        if mode == .reducedMotion {
            deliverContactIfNeeded()
            deliverRestIfNeeded()
            phase = .resting
            return snapshot(elapsedSeconds: restTimeSeconds)
        }
        phase = .inFlight
        return snapshot(elapsedSeconds: 0)
    }

    func advance(to hostTime: Double) -> TranscriptTimelineSnapshot {
        guard hostTime.isFinite, let releaseHostTime else { return currentSnapshot }
        if mode == .reducedMotion {
            return snapshot(elapsedSeconds: restTimeSeconds)
        }

        let elapsed = max(lastElapsedSeconds, max(0, hostTime - releaseHostTime))
        lastElapsedSeconds = elapsed
        if elapsed + Self.timeTolerance >= contactTimeSeconds {
            deliverContactIfNeeded()
            phase = .settling
        }
        if elapsed + Self.timeTolerance >= restTimeSeconds {
            deliverRestIfNeeded()
            phase = .resting
        }
        return snapshot(elapsedSeconds: elapsed)
    }

    func cancel(at hostTime: Double) -> TranscriptTimelineSnapshot {
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
        case .resting: restTimeSeconds
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

    private func snapshot(elapsedSeconds: Double) -> TranscriptTimelineSnapshot {
        TranscriptTimelineSnapshot(
            phase: phase,
            elapsedSeconds: min(max(elapsedSeconds, 0), restTimeSeconds),
            isMoving: phase == .inFlight || phase == .settling,
            contactDelivered: contactDelivered,
            restDelivered: restDelivered,
            committedCancelIgnored: committedCancelIgnored
        )
    }
}
