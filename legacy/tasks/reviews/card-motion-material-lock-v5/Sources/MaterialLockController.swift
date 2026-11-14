import QuartzCore
import SwiftUI

@MainActor
final class PlaneLockController: NSObject, ObservableObject {
    @Published private(set) var snapshot = PlaneLockEngine().snapshot

    private var engine = PlaneLockEngine()
    private var displayLink: CADisplayLink?
    private var lastWallclock = 0.0
    private var accumulator = 0.0
    private var isRunning = false

    func reset() {
        engine.reset()
        snapshot = engine.snapshot
        accumulator = 0
        lastWallclock = CACurrentMediaTime()
        isRunning = false
        ensureDisplayLink()
    }

    func start() {
        engine.reset()
        snapshot = engine.snapshot
        accumulator = 0
        lastWallclock = CACurrentMediaTime()
        isRunning = true
        ensureDisplayLink()
    }

    func synchronizeToWallclock() {
        advance(to: CACurrentMediaTime())
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
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

    private func advance(to wallclock: Double) {
        guard isRunning else {
            lastWallclock = max(lastWallclock, wallclock)
            return
        }
        guard wallclock > lastWallclock else { return }
        let elapsed = min(max(wallclock - lastWallclock, 0), 0.125)
        lastWallclock = wallclock
        accumulator += elapsed
        while accumulator + 0.000_000_1 >= PlaneLockMotion.fixedStep {
            engine.advanceFixedStep()
            accumulator -= PlaneLockMotion.fixedStep
        }
        snapshot = engine.snapshot
        if snapshot.simulationTime >= PlaneLockMotion.sequenceDuration {
            isRunning = false
        }
    }
}
