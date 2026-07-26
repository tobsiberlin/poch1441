import AVFoundation
import os

/// Real table contacts, triggered only by an admitted presentation impact.
/// Multiple voices keep closely dealt cards physical without cutting off tails.
@MainActor
final class TableFoleyAudio {
    static let shared = TableFoleyAudio()

    private static let log = Logger(subsystem: "com.tobc.poch1441",
                                    category: "TableFoleyAudio")
    private let variants = [
        "card-deal-01",
        "card-deal-02",
        "card-deal-03"
    ]
    private var voices: [String: [AVAudioPlayer]] = [:]
    private var nextVoice: [String: Int] = [:]
    private var previousVariant: Int?

    private static var isAvailableInCurrentRuntime: Bool {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("-enableSimulatorContactAudio")
        #else
        return true
        #endif
    }

    func prepare() {
        guard Self.isAvailableInCurrentRuntime else { return }
        do {
            try PochAudioSession.prepareAmbientMixing()
        } catch {
            Self.log.error(
                "Unable to prepare ambient audio session: \(error.localizedDescription, privacy: .public)"
            )
            return
        }
        for name in variants {
            _ = players(named: name)
        }
    }

    func playCardDeal(sequence: Int,
                      generation: Int,
                      seat: Int,
                      playerCount: Int) {
        guard Self.isAvailableInCurrentRuntime else { return }
        let index = R1ContactVariantResolver.resolve(
            variantCount: variants.count,
            seed: sequence &+ generation &* 31,
            familySalt: 0xCA4D_1441,
            previousIndex: previousVariant
        )
        let name = variants[index]
        guard let pool = players(named: name), !pool.isEmpty else { return }
        let voiceIndex = nextVoice[name, default: 0] % pool.count
        let player = pool[voiceIndex]

        previousVariant = index
        nextVoice[name] = voiceIndex + 1
        player.currentTime = 0
        player.volume = 0.52
        player.pan = TableFoleySpatialModel.pan(seat: seat,
                                                playerCount: playerCount)
        player.play()
    }

    private func players(named name: String) -> [AVAudioPlayer]? {
        if let cached = voices[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else {
            Self.log.error("Missing table Foley: \(name, privacy: .public)")
            return nil
        }
        do {
            let prepared = try (0..<3).map { _ in
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                return player
            }
            voices[name] = prepared
            return prepared
        } catch {
            Self.log.error(
                "Unable to prepare table Foley: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}

enum TableFoleySpatialModel {
    /// Mirrors the opponent target layout: seat 1 is left, the last seat is
    /// right and intermediate seats spread evenly between them. The human
    /// hand remains centered. This stays correct for every supported table
    /// size from three through six players.
    static func pan(seat: Int, playerCount: Int) -> Float {
        let safePlayerCount = min(max(playerCount, 3), 6)
        guard seat > 0 else { return 0 }
        let opponentCount = safePlayerCount - 1
        let center = Float(opponentCount - 1) / 2
        guard center > 0 else { return 0 }
        let safeSeat = min(max(seat, 1), safePlayerCount - 1)
        let index = Float(safeSeat - 1)
        let normalized = (index - center) / center
        return min(0.42, max(-0.42, normalized * 0.42))
    }
}
