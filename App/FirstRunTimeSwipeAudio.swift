import AVFoundation
import os
import UIKit

/// Four natural scene layers stay phase-aligned while the retired transition
/// player remains silent for resource compatibility. No audio is restarted
/// during scrubbing, so reversing the gesture reverses the rooms immediately.
@MainActor
final class FirstRunTimeSwipeAudio {
    private static let log = Logger(subsystem: "com.tobc.poch1441",
                                    category: "FirstRunTimeSwipeAudio")

    private enum Layer: String, CaseIterable {
        case originRoom = "first-run-origin-room"
        case originMotif = "first-run-origin-motif"
        case presentRoom = "first-run-present-room"
        case presentMotif = "first-run-present-motif"
        case timeNoise = "first-run-time-noise"
    }

    private var players: [Layer: AVAudioPlayer] = [:]
    private var isPrepared = false
    private var isPlaying = false
    private var masterGain: Float = 0
    private var currentMix: FirstRunTimeSwipeAudioMix?
    private var startTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?

    private static var isAvailableInCurrentRuntime: Bool {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("-enableSimulatorFirstRunAudio")
        #else
        return true
        #endif
    }

    func startIfEnabled(_ enabled: Bool, progress: Double) {
        guard enabled else {
            stop()
            return
        }
        guard Self.isAvailableInCurrentRuntime else { return }
        do {
            stopTask?.cancel()
            stopTask = nil
            try prepareIfNeeded()
            if !isPlaying {
                currentMix = mixState(progress: progress)
                let startTime = (players.values.map(\.deviceCurrentTime).max() ?? 0) + 0.05
                players.values.forEach {
                    $0.currentTime = 0
                    $0.numberOfLoops = -1
                    $0.volume = 0
                    $0.play(atTime: startTime)
                }
                isPlaying = true
                masterGain = 0
                applyCurrentMix(fadeDuration: 0)
                startTask?.cancel()
                startTask = Task { @MainActor [weak self] in
                    // Keep the ambience silent until the phase-aligned players
                    // actually begin, then raise only the master. Finger progress
                    // remains live throughout this perceptual fade.
                    try? await Task.sleep(for: .milliseconds(50))
                    let frameCount = 40
                    for frame in 1...frameCount {
                        guard let self, !Task.isCancelled else { return }
                        let linear = Float(frame) / Float(frameCount)
                        self.masterGain = linear * linear * (3 - 2 * linear)
                        self.applyCurrentMix(fadeDuration: 0.02)
                        try? await Task.sleep(for: .milliseconds(16))
                    }
                    self?.masterGain = 1
                    self?.applyCurrentMix(fadeDuration: 0.02)
                    self?.startTask = nil
                }
            } else {
                update(progress: progress)
            }
        } catch {
            Self.log.error("Unable to start time-swipe audio: \(error.localizedDescription, privacy: .public)")
        }
    }

    func update(progress: Double) {
        guard isPlaying else { return }
        currentMix = mixState(progress: progress)
        applyCurrentMix(fadeDuration: 0.02)
    }

    /// Decode and prepare the five layers while the silent prelude is visible.
    /// Any failure is logged when playback is actually requested.
    func prepare() {
        guard Self.isAvailableInCurrentRuntime else { return }
        do {
            try prepareIfNeeded()
        } catch {
            Self.log.error("Unable to prepare time-swipe audio: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        startTask?.cancel()
        startTask = nil
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
            self?.masterGain = 0
            self?.currentMix = nil
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
            if layer == .timeNoise {
                player.enableRate = true
                player.rate = 1
            }
            player.prepareToPlay()
            preparedPlayers[layer] = player
        }

        try PochAudioSession.prepareAmbientMixing()
        players = preparedPlayers
        isPrepared = true
    }

    private func mixState(progress: Double) -> FirstRunTimeSwipeAudioMix {
        FirstRunTimeSwipeAudioMix.state(
            progress: FirstRunTimeSwipeProjection.clamped(progress),
            reduceMotion: UIAccessibility.isReduceMotionEnabled
        )
    }

    private func applyCurrentMix(fadeDuration: TimeInterval) {
        guard let mix = currentMix else { return }
        players[.originRoom]?.setVolume(mix.originRoomVolume * masterGain,
                                        fadeDuration: fadeDuration)
        players[.originMotif]?.setVolume(mix.originMotifVolume * masterGain,
                                         fadeDuration: fadeDuration)
        players[.presentRoom]?.setVolume(mix.presentRoomVolume * masterGain,
                                         fadeDuration: fadeDuration)
        players[.presentMotif]?.setVolume(mix.presentMotifVolume * masterGain,
                                          fadeDuration: fadeDuration)
        players[.originRoom]?.pan = mix.originRoomPan
        players[.originMotif]?.pan = mix.originMotifPan
        players[.presentRoom]?.pan = mix.presentRoomPan
        players[.presentMotif]?.pan = mix.presentMotifPan
        players[.timeNoise]?.rate = mix.timeNoiseRate
        players[.timeNoise]?.pan = 0
        players[.timeNoise]?.setVolume(mix.timeNoiseVolume * masterGain,
                                       fadeDuration: fadeDuration)
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

/// One release audio policy for intro ambience, table Foley and material
/// contacts. Poch adds itself to the room instead of taking over the device;
/// the silent switch remains respected and existing background audio may mix.
@MainActor
enum PochAudioSession {
    static func prepareAmbientMixing() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, options: [.mixWithOthers])
        try session.setActive(true)
    }
}
