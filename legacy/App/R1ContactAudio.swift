import AVFoundation
import os

/// One playback path for every R1 impact. Accepted event identities are
/// deduplicated; distinct physical contacts are never discarded by wall time.
@MainActor
final class R1ContactAudio {
    static let shared = R1ContactAudio()

    struct EventKey: Hashable, Sendable {
        let namespace: String
        let generation: Int
        let sequence: Int
    }

    private static let log = Logger(subsystem: "com.tobc.poch1441",
                                    category: "R1ContactAudio")
    private static let voiceCount = 6
    private static let retainedEventCount = 192

    private let outerVariants = [
        "r1-ceramic-outer-01", "r1-ceramic-outer-02", "r1-ceramic-outer-03"
    ]
    private let centerVariants = [
        "r1-ceramic-center-01", "r1-ceramic-center-02", "r1-ceramic-center-03"
    ]
    private let stackVariants = [
        "r1-ceramic-stack-01", "r1-ceramic-stack-02", "r1-ceramic-stack-03"
    ]
    private var voices: [String: [AVAudioPlayer]] = [:]
    private var nextVoice: [String: Int] = [:]
    private var previousVariant: [String: Int] = [:]
    private var acceptedEvents: Set<EventKey> = []
    private var acceptedEventOrder: [EventKey] = []
    private var sessionPrepared = false

    private static var isAvailableInCurrentRuntime: Bool {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("-enableSimulatorContactAudio")
        #else
        return true
        #endif
    }

    func prepare() {
        guard Self.isAvailableInCurrentRuntime else { return }
        guard prepareSessionIfNeeded() else { return }
        for name in outerVariants + centerVariants + stackVariants {
            _ = players(named: name)
        }
    }

    /// Stable root-modifier path. Trigger values already represent accepted
    /// presentation contacts and therefore form their own event identity.
    func play(surface: R1ContactSurface,
              groupSize: Int,
              variantSeed: Int) {
        guard Self.isAvailableInCurrentRuntime,
              prepareSessionIfNeeded() else { return }
        playResolved(surface: surface,
                     groupSize: groupSize,
                     variantSeed: variantSeed,
                     pan: 0,
                     volumeOverride: nil)
    }

    /// Table-Foley path for Phase-2 transfers. It uses the same material,
    /// session, variant resolver, deduplication and voice pools as every R1 cue.
    func play(surface: R1ContactSurface,
              groupSize: Int,
              variantSeed: Int,
              eventKey: EventKey,
              pan: Float,
              volumeOverride: Float? = nil) {
        guard Self.isAvailableInCurrentRuntime,
              prepareSessionIfNeeded(),
              register(eventKey) else { return }
        playResolved(surface: surface,
                     groupSize: groupSize,
                     variantSeed: variantSeed,
                     pan: pan,
                     volumeOverride: volumeOverride)
    }

    private func playResolved(surface: R1ContactSurface,
                              groupSize: Int,
                              variantSeed: Int,
                              pan: Float,
                              volumeOverride: Float?) {
        let selection = variants(for: surface, groupSize: groupSize)
        let index = R1ContactVariantResolver.resolve(
            variantCount: selection.names.count,
            seed: variantSeed,
            familySalt: selection.salt,
            semanticIndex: selection.semanticIndex,
            previousIndex: previousVariant[selection.family]
        )
        let name = selection.names[index]
        guard let pool = players(named: name), !pool.isEmpty else { return }
        let voiceIndex = nextVoice[name, default: 0] % pool.count
        let player = pool[voiceIndex]
        let dynamics = R1ContactDynamics.resolve(surface: surface,
                                                 groupSize: groupSize)

        previousVariant[selection.family] = index
        nextVoice[name] = voiceIndex + 1
        player.currentTime = 0
        player.volume = volumeOverride ?? dynamics.audioVolume
        player.pan = min(0.58, max(-0.58, pan))
        player.play()
    }

    private func variants(
        for surface: R1ContactSurface,
        groupSize: Int
    ) -> (names: [String], family: String, salt: UInt64, semanticIndex: Int?) {
        switch surface {
        case .outerWell:
            return (outerVariants, "outer", 0xA17E_1441, nil)
        case .centerWell:
            return (centerVariants, "center", 0xCE17_1441, nil)
        case .playerStack:
            let semanticIndex = groupSize > 1 ? min(groupSize - 1, 2) : nil
            return (stackVariants, "stack", 0x57AC_1441, semanticIndex)
        }
    }

    private func register(_ event: EventKey) -> Bool {
        guard acceptedEvents.insert(event).inserted else { return false }
        acceptedEventOrder.append(event)
        if acceptedEventOrder.count > Self.retainedEventCount {
            let excess = acceptedEventOrder.count - Self.retainedEventCount
            let removed = acceptedEventOrder.prefix(excess)
            acceptedEvents.subtract(removed)
            acceptedEventOrder.removeFirst(excess)
        }
        return true
    }

    private func prepareSessionIfNeeded() -> Bool {
        if sessionPrepared { return true }
        do {
            try PochAudioSession.prepareAmbientMixing()
            sessionPrepared = true
            return true
        } catch {
            Self.log.error(
                "Unable to prepare ceramic audio session: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    private func players(named name: String) -> [AVAudioPlayer]? {
        if let cached = voices[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else {
            Self.log.error("Missing ceramic contact sound: \(name, privacy: .public)")
            return nil
        }
        do {
            let prepared = try (0..<Self.voiceCount).map { _ in
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                return player
            }
            voices[name] = prepared
            return prepared
        } catch {
            Self.log.error(
                "Unable to prepare ceramic contact: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}
