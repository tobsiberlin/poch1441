import QuartzCore
import SwiftUI
import UIKit

@MainActor
final class CardMotionController: NSObject, ObservableObject {
    @Published private(set) var snapshot: StageSnapshot = .empty
    @Published private(set) var layout = CardMotionLayout(width: 402, height: 874)
    private(set) var lastCancellationProgress: Double?

    private var engine = CardMotionEngine(layout: CardMotionLayout(width: 402, height: 874))
    private var displayLink: CADisplayLink?
    private var activePlayID: Int?
    private var scheduledCancellation: (flightID: Int, time: Double, progress: Double)?
    private var emittedHapticContacts = 0
    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    func reset(width: Double, height: Double, deckCount: Int = 3) {
        let timestamp = CACurrentMediaTime()
        layout = CardMotionLayout(width: width, height: height)
        engine.reset(layout: layout, deckCount: deckCount, at: timestamp)
        activePlayID = nil
        scheduledCancellation = nil
        lastCancellationProgress = nil
        emittedHapticContacts = 0
        snapshot = engine.snapshot
        ensureDisplayLink()
    }

    func startSingleDeal() {
        haptic.prepare()
        _ = engine.startDeal(at: CACurrentMediaTime())
        snapshot = engine.snapshot
        ensureDisplayLink()
    }

    func startDealBurst(count: Int = 10, interval: Double = 0.135) {
        haptic.prepare()
        engine.scheduleDealBurst(count: count, interval: interval, at: CACurrentMediaTime())
        snapshot = engine.snapshot
        ensureDisplayLink()
    }

    func startPlay() {
        haptic.prepare()
        activePlayID = engine.startPlay(at: CACurrentMediaTime())
        snapshot = engine.snapshot
        ensureDisplayLink()
    }

    func startPlayWithScheduledCancellation(atProgress progress: Double) {
        haptic.prepare()
        let start = CACurrentMediaTime()
        let id = engine.startPlay(at: start)
        activePlayID = id
        scheduledCancellation = (
            flightID: id,
            time: start + 0.64 * min(max(progress, 0), 0.999),
            progress: min(max(progress, 0), 0.999)
        )
        snapshot = engine.snapshot
        ensureDisplayLink()
    }

    @discardableResult
    func cancelActivePlay() -> Bool {
        guard let activePlayID,
              engine.cancelPlay(flightID: activePlayID, at: CACurrentMediaTime()) != nil else {
            return false
        }
        self.activePlayID = nil
        snapshot = engine.snapshot
        ensureDisplayLink()
        return true
    }

    func setReducedMotion(_ enabled: Bool) {
        engine.setReducedMotion(enabled, at: CACurrentMediaTime())
        snapshot = engine.snapshot
        publishPendingHaptics()
    }

    var activePlayProgress: Double? {
        snapshot.flights.first(where: { $0.kind == .play })?.normalizedProgress
    }

    var isIdle: Bool { snapshot.flights.isEmpty }

    /// Evidence and tests call the same monotonic-clock advancement path used
    /// by CADisplayLink. This keeps headless Simulator capture wallclock-driven
    /// even when CoreSimulator suppresses display callbacks offscreen.
    func synchronizeToWallclock() {
        advance(to: CACurrentMediaTime())
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func ensureDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        advance(to: link.timestamp)
    }

    private func advance(to timestamp: Double) {
        if let scheduledCancellation, timestamp >= scheduledCancellation.time {
            snapshot = engine.advance(to: scheduledCancellation.time)
            _ = engine.cancelPlay(
                flightID: scheduledCancellation.flightID,
                at: scheduledCancellation.time
            )
            lastCancellationProgress = scheduledCancellation.progress
            activePlayID = nil
            self.scheduledCancellation = nil
        }
        snapshot = engine.advance(to: timestamp)
        publishPendingHaptics()
    }

    private func publishPendingHaptics() {
        guard snapshot.contacts.count > emittedHapticContacts else { return }
        for _ in emittedHapticContacts..<snapshot.contacts.count {
            haptic.impactOccurred(intensity: 0.58)
        }
        emittedHapticContacts = snapshot.contacts.count
    }
}
