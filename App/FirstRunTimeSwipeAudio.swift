import AVFoundation
import os

/// Four pre-rendered layers stay phase-aligned while the finger changes only
/// their mix. No audio is restarted during scrubbing, so reversing the gesture
/// sounds continuous instead of triggering a stack of short effects.
@MainActor
final class FirstRunTimeSwipeAudio {
    private static let log = Logger(subsystem: "com.tobc.poch1441",
                                    category: "FirstRunTimeSwipeAudio")

    private enum Layer: String, CaseIterable {
        case originRoom = "first-run-origin-room"
        case originMotif = "first-run-origin-motif"
        case presentRoom = "first-run-present-room"
        case presentMotif = "first-run-present-motif"
    }

    private var players: [Layer: AVAudioPlayer] = [:]
    private var isPrepared = false
    private var isPlaying = false
    private var stopTask: Task<Void, Never>?

    private static var isAvailableInCurrentRuntime: Bool {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("-enableSimulatorFirstRunAudio")
        #else
        return true
        #endif
    }

    func startIfEnabled(_ enabled: Bool, progress: Double) {
        guard enabled, Self.isAvailableInCurrentRuntime else { return }
        do {
            stopTask?.cancel()
            stopTask = nil
            try prepareIfNeeded()
            if !isPlaying {
                let startTime = (players.values.map(\.deviceCurrentTime).max() ?? 0) + 0.05
                players.values.forEach {
                    $0.currentTime = 0
                    $0.numberOfLoops = -1
                    $0.play(atTime: startTime)
                }
                isPlaying = true
            }
            update(progress: progress)
        } catch {
            Self.log.error("Unable to start time-swipe audio: \(error.localizedDescription, privacy: .public)")
        }
    }

    func update(progress: Double) {
        guard isPlaying else { return }
        let clamped = Float(FirstRunTimeSwipeProjection.clamped(progress))
        let present = smoothstep(clamped)
        let origin = 1 - present

        // Keep the mix perceptually smooth without allowing a long ramp to
        // trail behind a fast reversal of the direct-manipulation gesture.
        players[.originRoom]?.setVolume(origin * 0.36, fadeDuration: 0.012)
        players[.originMotif]?.setVolume(origin * 0.18, fadeDuration: 0.012)
        players[.presentRoom]?.setVolume(present * 0.28, fadeDuration: 0.012)
        players[.presentMotif]?.setVolume(present * 0.16, fadeDuration: 0.012)
    }

    func stop() {
        guard isPlaying else { return }
        stopTask?.cancel()
        players.values.forEach {
            $0.setVolume(0, fadeDuration: 0.18)
        }
        let activePlayers = Array(players.values)
        stopTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            activePlayers.forEach { $0.stop() }
            self?.isPlaying = false
            // The session is shared by the game table. Deactivating it here
            // could silence a round that starts while this fade is finishing.
            self?.stopTask = nil
        }
    }

    private func prepareIfNeeded() throws {
        guard !isPrepared else { return }
        var preparedPlayers: [Layer: AVAudioPlayer] = [:]

        for layer in Layer.allCases {
            guard let url = Bundle.main.url(forResource: layer.rawValue,
                                            withExtension: "wav") else {
                throw AudioError.missingLayer(layer.rawValue)
            }
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0
            player.prepareToPlay()
            preparedPlayers[layer] = player
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, options: [.mixWithOthers])
        try session.setActive(true)
        players = preparedPlayers
        isPrepared = true
    }

    private func smoothstep(_ value: Float) -> Float {
        value * value * (3 - 2 * value)
    }

    private enum AudioError: LocalizedError {
        case missingLayer(String)

        var errorDescription: String? {
            switch self {
            case .missingLayer(let name):
                return "Missing first-run audio layer \(name)"
            }
        }
    }
}
