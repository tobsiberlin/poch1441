import SwiftUI
import UIKit

@MainActor
final class CardMotionController: ObservableObject {
    @Published private(set) var progress = 0.0
    @Published private(set) var revealProgress = 0.0
    @Published private(set) var overlayOpacity = 1.0
    @Published private(set) var flightIdentity = 0
    @Published private(set) var phaseLabel = "IDLE"
    @Published private(set) var contactCount = 0
    @Published private(set) var isRunning = false

    private var machine = CardMotionStateMachine()
    private var sequenceTask: Task<Void, Never>?
    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    func startSequence() {
        sequenceTask?.cancel()
        let generation = machine.begin(.deal(sequence: machine.generation + 1))
        phaseLabel = "DEAL"
        isRunning = true
        overlayOpacity = 1
        revealProgress = 0
        setProgress(0, animation: nil)
        haptic.prepare()

        sequenceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            setProgress(1, animation: .timingCurve(0.42, 0, 0.58, 1, duration: 0.56))
            try? await Task.sleep(for: .milliseconds(570))
            guard !Task.isCancelled else { return }
            emitContactIfAccepted(generation: generation)

            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            let revealGeneration = machine.begin(.reveal(publicEventID: generation))
            phaseLabel = "REVEAL"
            withAnimation(.easeInOut(duration: 0.32)) {
                revealProgress = 1
            }
            try? await Task.sleep(for: .milliseconds(340))
            guard !Task.isCancelled,
                  machine.transition(to: .play(publicEventID: generation), generation: revealGeneration) else {
                return
            }

            let playGeneration = machine.begin(.play(publicEventID: generation))
            phaseLabel = "PLAY"
            setProgress(0, animation: nil)
            try? await Task.sleep(for: .milliseconds(60))
            setProgress(1, animation: .timingCurve(0.42, 0, 0.58, 1, duration: 0.54))
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
            emitContactIfAccepted(generation: playGeneration)
            phaseLabel = "SETTLED"
            isRunning = false
        }
    }

    func startCancelablePlay() {
        sequenceTask?.cancel()
        _ = machine.begin(.fan(slot: 0))
        let generation = machine.begin(.play(publicEventID: machine.generation + 1))
        phaseLabel = "PLAY"
        isRunning = true
        overlayOpacity = 1
        revealProgress = 1
        setProgress(0, animation: nil)
        haptic.prepare()

        sequenceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            setProgress(1, animation: .timingCurve(0.42, 0, 0.58, 1, duration: 1.15))
            try? await Task.sleep(for: .milliseconds(1_170))
            guard !Task.isCancelled else { return }
            emitContactIfAccepted(generation: generation)
            phaseLabel = "SETTLED"
            isRunning = false
        }
    }

    func cancelBeforeContact() {
        guard let returnGeneration = machine.cancelBeforeContact(generation: machine.generation) else {
            return
        }
        sequenceTask?.cancel()
        phaseLabel = "RETURN"
        setProgress(
            0,
            animation: .interpolatingSpring(mass: 1, stiffness: 165, damping: 26, initialVelocity: 0)
        )
        sequenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(520))
            guard let self, !Task.isCancelled,
                  machine.transition(to: .fan(slot: 0), generation: returnGeneration) else {
                return
            }
            phaseLabel = "FAN"
            isRunning = false
        }
    }

    func setReduceMotion(_ enabled: Bool) {
        guard enabled else { return }
        sequenceTask?.cancel()
        let settleGeneration = machine.settleForReducedMotion()
        phaseLabel = "REDUCE · FADE"
        withAnimation(.easeOut(duration: 0.10)) {
            overlayOpacity = 0
        }

        sequenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(105))
            guard let self, machine.generation == settleGeneration else { return }
            flightIdentity += 1
            setProgress(1, animation: nil)
            revealProgress = 1
            phaseLabel = "SETTLED · SILENT"
            withAnimation(.easeIn(duration: 0.12)) {
                overlayOpacity = 1
            }
            isRunning = false
        }
    }

    func runProbeLoop() {
        startSequence()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.1))
            guard let self else { return }
            startCancelablePlay()
            try? await Task.sleep(for: .milliseconds(430))
            cancelBeforeContact()
            try? await Task.sleep(for: .milliseconds(720))
            startCancelablePlay()
            try? await Task.sleep(for: .milliseconds(390))
            setReduceMotion(true)
        }
    }

    private func setProgress(_ value: Double, animation: Animation?) {
        if let animation {
            withAnimation(animation) {
                progress = value
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                progress = value
            }
        }
    }

    private func emitContactIfAccepted(generation: Int) {
        guard machine.acceptContact(generation: generation) == .emitFeedback else { return }
        contactCount += 1
        haptic.impactOccurred(intensity: 0.62)
    }
}
