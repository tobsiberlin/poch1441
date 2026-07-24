#if DEBUG || INTERNAL_QA
import AVFoundation
import CoreHaptics
import os

/// Vorbereiteter Hardware-Adapter. Audio erhält den zertifizierten mach-Host-
/// Tick direkt. Core Haptics erhält dieselbe verbleibende Dauer in seiner
/// eigenen, laut Apple nicht mit AVAudio korrelierten Engine-Zeit.
@MainActor
final class CoinContactFeedbackEngine: MotionContactCueOutput {
    private static let log = Logger(subsystem: "com.tobc.poch1441",
                                    category: "CoinContactFeedback")

    private let audioEngine = AVAudioEngine()
    private let audioPlayer = AVAudioPlayerNode()
    private var audioBuffer: AVAudioPCMBuffer?
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayer: (any CHHapticAdvancedPatternPlayer)?
    private var prepared = false

    private var skipsSimulatorOutput: Bool {
        #if targetEnvironment(simulator)
        !ProcessInfo.processInfo.arguments.contains("-enableSimulatorContactAudio")
        #else
        false
        #endif
    }

    func prepare() throws {
        guard !prepared else { return }
        guard !skipsSimulatorOutput else {
            prepared = true
            return
        }
        guard let audioURL = Bundle.main.url(
            forResource: "cent-copper-polycarbonate-01",
            withExtension: "wav"
        ) else { throw FeedbackError.missingAudioFingerprint }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, options: [.mixWithOthers])
        try session.setActive(true)

        let file = try AVAudioFile(forReading: audioURL)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else { throw FeedbackError.invalidAudioFingerprint }
        try file.read(into: buffer)
        audioEngine.attach(audioPlayer)
        audioEngine.connect(audioPlayer,
                            to: audioEngine.mainMixerNode,
                            format: buffer.format)
        audioEngine.prepare()
        try audioEngine.start()
        audioPlayer.play()
        audioBuffer = buffer

        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            let engine = try CHHapticEngine(audioSession: session)
            engine.isAutoShutdownEnabled = false
            try engine.start()
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.58),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.72),
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            hapticPlayer = try engine.makeAdvancedPlayer(with: pattern)
            hapticEngine = engine
        }
        prepared = true
    }

    func schedule(_ cue: MotionContactCue) throws {
        try prepare()
        guard !skipsSimulatorOutput else { return }
        let target = AVAudioTime(hostTime: cue.contactHostTime)
        if cue.soundEnabled, let audioBuffer {
            let renderLog = Self.log
            if !audioPlayer.isPlaying { audioPlayer.play() }
            audioPlayer.scheduleBuffer(
                audioBuffer,
                at: target,
                options: [],
                completionCallbackType: .dataRendered
            ) { _ in
                renderLog.debug("AudioRenderObserved \(cue.identity.eventID, privacy: .public) \(cue.identity.generation)")
            }
            Self.log.debug("AudioScheduled \(cue.identity.eventID, privacy: .public) \(cue.contactHostTime)")
        }

        if cue.hapticsEnabled,
           let hapticEngine,
           let hapticPlayer {
            let nowHostSeconds = AVAudioTime.seconds(forHostTime: mach_absolute_time())
            let targetHostSeconds = AVAudioTime.seconds(forHostTime: cue.contactHostTime)
            let delay = max(0, targetHostSeconds - nowHostSeconds)
            try hapticPlayer.start(atTime: hapticEngine.currentTime + delay)
            Self.log.debug("HapticScheduled \(cue.identity.eventID, privacy: .public) \(cue.contactHostTime)")
        }
    }

    func cancel(identity: CoinTransferIdentity) {
        guard !skipsSimulatorOutput else { return }
        audioPlayer.stop()
        try? hapticPlayer?.cancel()
        Self.log.debug("CueCancelled \(identity.eventID, privacy: .public) \(identity.generation)")
    }

    enum FeedbackError: Error {
        case missingAudioFingerprint
        case invalidAudioFingerprint
    }
}
#endif
