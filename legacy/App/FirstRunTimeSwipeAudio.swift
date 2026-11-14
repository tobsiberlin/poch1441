import AVFoundation
import os
import UIKit

/// Four era layers, one invariant signature contact and a centered broadband
/// time texture stay phase-aligned.
/// No audio is restarted during scrubbing, so reversing the gesture reverses
/// both real-world gains immediately and the seam remains finger-bound.
@MainActor
final class FirstRunTimeSwipeAudio {
    private static let log = Logger(subsystem: "com.tobc.poch1441",
                                    category: "FirstRunTimeSwipeAudio")

    private enum Layer: String, CaseIterable, Sendable {
        case originRoom = "first-run-origin-room"
        case originMotif = "first-run-origin-motif"
        case presentRoom = "first-run-present-room"
        case presentMotif = "first-run-present-motif"
        case signatureContact = "first-run-signature-contact"
        case timeNoise = "first-run-time-noise"

        var resourceExtension: String {
            switch self {
            case .originRoom, .presentRoom: "m4a"
            default: "wav"
            }
        }

        var fileTypeHint: String {
            switch self {
            case .originRoom, .presentRoom: AVFileType.m4a.rawValue
            default: AVFileType.wav.rawValue
            }
        }
    }

    private var players: [Layer: AVAudioPlayer] = [:]
    private var isPrepared = false
    private var isPlaying = false
    private var masterGain: Float = 0
    private var currentMix: FirstRunTimeSwipeAudioMix?
    private var pendingStartProgress: Double?
    private var preparationTask: Task<Void, Never>?
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
        stopTask?.cancel()
        stopTask = nil
        if isPrepared {
            startPrepared(progress: progress)
        } else {
            pendingStartProgress = progress
            beginPreparationIfNeeded()
        }
    }

    func update(progress: Double) {
        currentMix = mixState(progress: progress)
        if pendingStartProgress != nil {
            pendingStartProgress = progress
        }
        guard isPlaying else { return }
        applyCurrentMix(fadeDuration: 0.008)
    }

    /// Reads every audio layer on a utility executor while the silent prelude is
    /// visible. Timeline entry never performs synchronous file I/O.
    func prepare() {
        guard Self.isAvailableInCurrentRuntime else { return }
        beginPreparationIfNeeded()
    }

    func stop() {
        pendingStartProgress = nil
        guard isPlaying else { return }
        startTask?.cancel()
        startTask = nil
        stopTask?.cancel()
        players.values.forEach {
            $0.setVolume(0, fadeDuration: 0.12)
        }
        let activePlayers = Array(players.values)
        stopTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(140))
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

    private func beginPreparationIfNeeded() {
        guard !isPrepared, preparationTask == nil else { return }
        var resources: [(Layer, URL)] = []
        for layer in Layer.allCases {
            guard let url = Bundle.main.url(forResource: layer.rawValue,
                                            withExtension: layer.resourceExtension) else {
                Self.log.error("Missing first-run audio layer \(layer.rawValue, privacy: .public)")
                return
            }
            resources.append((layer, url))
        }

        preparationTask = Task { @MainActor [weak self] in
            let dataByLayer = await Task.detached(priority: .utility) {
                var loaded: [Layer: Data] = [:]
                for (layer, url) in resources {
                    guard let data = try? Data(contentsOf: url,
                                               options: [.mappedIfSafe]) else {
                        return Optional<[Layer: Data]>.none
                    }
                    loaded[layer] = data
                }
                return Optional(loaded)
            }.value
            guard let self, !Task.isCancelled else { return }
            self.preparationTask = nil
            guard let dataByLayer else {
                Self.log.error("Unable to read first-run audio layers")
                self.pendingStartProgress = nil
                return
            }
            do {
                try self.finishPreparation(dataByLayer)
                if let progress = self.pendingStartProgress {
                    self.pendingStartProgress = nil
                    self.startPrepared(progress: progress)
                }
            } catch {
                Self.log.error(
                    "Unable to prepare time-swipe audio: \(error.localizedDescription, privacy: .public)"
                )
                self.pendingStartProgress = nil
            }
        }
    }

    private func finishPreparation(_ dataByLayer: [Layer: Data]) throws {
        guard !isPrepared else { return }
        var preparedPlayers: [Layer: AVAudioPlayer] = [:]

        for layer in Layer.allCases {
            guard let data = dataByLayer[layer] else {
                throw AudioError.missingLayer(layer.rawValue)
            }
            let player = try AVAudioPlayer(data: data,
                                           fileTypeHint: layer.fileTypeHint)
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

    private func startPrepared(progress: Double) {
        guard isPrepared else { return }
        if isPlaying {
            update(progress: progress)
            return
        }
        currentMix = mixState(progress: progress)
        let startTime = (players.values.map(\.deviceCurrentTime).max() ?? 0) + 0.02
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
            try? await Task.sleep(for: .milliseconds(20))
            let frameCount = 12
            for frame in 1...frameCount {
                guard let self, !Task.isCancelled else { return }
                let linear = Float(frame) / Float(frameCount)
                self.masterGain = linear * linear * (3 - 2 * linear)
                self.applyCurrentMix(fadeDuration: 0.008)
                try? await Task.sleep(for: .milliseconds(12))
            }
            self?.masterGain = 1
            self?.applyCurrentMix(fadeDuration: 0.008)
            self?.startTask = nil
        }
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
        players[.signatureContact]?.setVolume(mix.signatureContactVolume * masterGain,
                                              fadeDuration: fadeDuration)
        players[.originRoom]?.pan = mix.originRoomPan
        players[.originMotif]?.pan = mix.originMotifPan
        players[.presentRoom]?.pan = mix.presentRoomPan
        players[.presentMotif]?.pan = mix.presentMotifPan
        players[.signatureContact]?.pan = mix.signatureContactPan
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
