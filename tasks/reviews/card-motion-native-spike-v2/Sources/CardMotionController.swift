import QuartzCore
import SwiftUI
import UIKit

@MainActor
final class CardMotionController: NSObject, ObservableObject {
    @Published private(set) var segment: CardMotionSegment = .deal
    @Published private(set) var progress = 0.0
    @Published private(set) var returnInterruptionProgress = 0.58
    @Published private(set) var overlayOpacity = 1.0
    @Published private(set) var flightIdentity = 0
    @Published private(set) var contactCount = 0
    @Published private(set) var isRunning = false

    private var machine = CardMotionStateMachine()
    private var displayLink: CADisplayLink?
    private var animationStart: CFTimeInterval?
    private var animationDuration = 0.5
    private var animationCompletion: (() -> Void)?
    private var animationEasing: Easing = .easeInOut
    private var sequenceTask: Task<Void, Never>?
    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    func startSequence() {
        stopAnimation()
        sequenceTask?.cancel()
        let generation = machine.begin(.deal(sequence: machine.generation + 1))
        overlayOpacity = 1
        flightIdentity += 1
        haptic.prepare()
        isRunning = true
        animate(segment: .deal, duration: 0.56) { [weak self] in
            guard let self else { return }
            emitContactIfAccepted(generation: generation)
            sequenceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(130))
                self?.startRevealThenPlay(eventID: generation)
            }
        }
    }

    func startCancelablePlay() {
        stopAnimation()
        sequenceTask?.cancel()
        _ = machine.begin(.fan(slot: 0))
        let generation = machine.begin(.play(publicEventID: machine.generation + 1))
        overlayOpacity = 1
        flightIdentity += 1
        haptic.prepare()
        isRunning = true
        animate(segment: .play, duration: 1.12) { [weak self] in
            guard let self else { return }
            emitContactIfAccepted(generation: generation)
            isRunning = false
        }
    }

    func cancelBeforeContact() {
        guard segment == .play, progress < 1,
              let returnGeneration = machine.cancelBeforeContact(generation: machine.generation) else {
            return
        }
        let visibleInterruption = progress
        stopAnimation()
        sequenceTask?.cancel()
        returnInterruptionProgress = visibleInterruption
        isRunning = true
        animate(segment: .return, duration: 0.48, easing: .criticallyDamped) { [weak self] in
            guard let self else { return }
            _ = machine.transition(to: .fan(slot: 0), generation: returnGeneration)
            isRunning = false
        }
    }

    func setReduceMotion(_ enabled: Bool) {
        guard enabled else { return }
        let settledSegment: CardMotionSegment = segment == .deal ? .deal : (segment == .return ? .return : .play)
        stopAnimation()
        sequenceTask?.cancel()
        let settleGeneration = machine.settleForReducedMotion()
        withAnimation(.easeOut(duration: 0.10)) {
            overlayOpacity = 0
        }
        sequenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(105))
            guard let self, machine.generation == settleGeneration else { return }
            segment = settledSegment
            progress = 1
            flightIdentity += 1
            withAnimation(.easeIn(duration: 0.12)) {
                overlayOpacity = 1
            }
            isRunning = false
        }
    }

    func runProbeLoop() {
        startSequence()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.9))
            guard let self else { return }
            startCancelablePlay()
            try? await Task.sleep(for: .milliseconds(560))
            cancelBeforeContact()
            try? await Task.sleep(for: .milliseconds(620))
            startCancelablePlay()
            try? await Task.sleep(for: .milliseconds(410))
            setReduceMotion(true)
        }
    }

    private func startRevealThenPlay(eventID: Int) {
        let revealGeneration = machine.begin(.reveal(publicEventID: eventID))
        animate(segment: .reveal, duration: 0.32) { [weak self] in
            guard let self,
                  machine.transition(to: .play(publicEventID: eventID), generation: revealGeneration) else {
                return
            }
            let playGeneration = machine.begin(.play(publicEventID: eventID))
            animate(segment: .play, duration: 0.54) { [weak self] in
                guard let self else { return }
                emitContactIfAccepted(generation: playGeneration)
                isRunning = false
            }
        }
    }

    private func animate(
        segment: CardMotionSegment,
        duration: Double,
        easing: Easing = .easeInOut,
        completion: @escaping () -> Void
    ) {
        stopAnimation()
        self.segment = segment
        progress = 0
        animationDuration = duration
        animationEasing = easing
        animationCompletion = completion
        animationStart = nil
        let link = CADisplayLink(target: self, selector: #selector(animationTick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        animationStart = nil
        animationCompletion = nil
    }

    @objc private func animationTick(_ link: CADisplayLink) {
        if animationStart == nil {
            animationStart = link.timestamp
        }
        let raw = min(max((link.timestamp - (animationStart ?? link.timestamp)) / animationDuration, 0), 1)
        progress = animationEasing.value(at: raw)
        guard raw >= 1 else { return }
        let completion = animationCompletion
        stopAnimation()
        progress = 1
        completion?()
    }

    private func emitContactIfAccepted(generation: Int) {
        guard machine.acceptContact(generation: generation) == .emitFeedback else { return }
        contactCount += 1
        haptic.impactOccurred(intensity: 0.62)
    }

    private enum Easing {
        case easeInOut
        case criticallyDamped

        func value(at raw: Double) -> Double {
            switch self {
            case .easeInOut:
                return raw * raw * (3 - 2 * raw)
            case .criticallyDamped:
                let omega = 8.0
                let unnormalized = 1 - (1 + omega * raw) * exp(-omega * raw)
                let endpoint = 1 - (1 + omega) * exp(-omega)
                return min(max(unnormalized / endpoint, 0), 1)
            }
        }
    }
}

