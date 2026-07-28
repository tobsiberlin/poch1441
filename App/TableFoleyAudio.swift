import AVFoundation
import os

/// Real table contacts, triggered only by an admitted presentation impact.
/// Multiple voices keep closely dealt cards physical without cutting off tails.
@MainActor
final class TableFoleyAudio {
    static let shared = TableFoleyAudio()

    private static let log = Logger(subsystem: "com.tobc.poch1441",
                                    category: "TableFoleyAudio")
    private let cardVariants = [
        "card-deal-01",
        "card-deal-02",
        "card-deal-03"
    ]
    private let pochGestureVariants = [
        "table-knock-01",
        "table-knock-02",
        "table-knock-03"
    ]
    private var voices: [String: [AVAudioPlayer]] = [:]
    private var nextVoice: [String: Int] = [:]
    private var previousVariant: [String: Int] = [:]
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
        for name in cardVariants + pochGestureVariants {
            _ = players(named: name)
        }
        R1ContactAudio.shared.prepare()
    }

    /// The semantic Poch gesture: a centered knuckle-on-solid-wood table knock,
    /// deliberately separate from the chip transfer that may follow it.
    func playPochGesture(sequence: Int,
                         generation: Int,
                         seat: Int,
                         playerCount: Int) {
        guard Self.isAvailableInCurrentRuntime else { return }
        play(family: "pochGesture",
             variants: pochGestureVariants,
             seed: sequence &+ generation &* 59,
             salt: 0xB00D_1441,
             volume: 0.46,
             pan: TableFoleySpatialModel.pan(seat: seat,
                                             playerCount: playerCount))
    }

    func playCardDeal(sequence: Int,
                      generation: Int,
                      seat: Int,
                      playerCount: Int) {
        guard Self.isAvailableInCurrentRuntime else { return }
        play(family: "deal",
             variants: cardVariants,
             seed: sequence &+ generation &* 31,
             salt: 0xCA4D_1441,
             volume: 0.38,
             pan: TableFoleySpatialModel.pan(seat: seat,
                                             playerCount: playerCount))
    }

    /// A deliberate, close table-card turn. It is quieter than dealing and
    /// fires only when the trump card visibly changes face.
    func playCardReveal(sequence: Int, generation: Int) {
        guard Self.isAvailableInCurrentRuntime else { return }
        play(family: "reveal",
             variants: cardVariants,
             seed: sequence &+ generation &* 43,
             salt: 0x7EAE_1441,
             volume: 0.28,
             pan: 0)
    }

    /// One played-card contact at the exact accepted landing edge.
    func playCardPlay(sequence: Int,
                      generation: Int,
                      seat: Int,
                      playerCount: Int) {
        guard Self.isAvailableInCurrentRuntime else { return }
        play(family: "play",
             variants: cardVariants,
             seed: sequence &+ generation &* 47,
             salt: 0xCA7D_1441,
             volume: 0.34,
             pan: TableFoleySpatialModel.pan(seat: seat,
                                             playerCount: playerCount))
    }

    /// Ceramic chip contact for the Poch-Pott. Bets use the center-well
    /// family; payouts use the slightly broader stack family.
    func playChipContact(sequence: Int,
                         generation: Int,
                         seat: Int,
                         playerCount: Int,
                         isPayout: Bool) {
        guard Self.isAvailableInCurrentRuntime else { return }
        let eventNamespace = isPayout ? "phase2.payout" : "phase2.bet"
        R1ContactAudio.shared.play(
            surface: isPayout ? .playerStack : .centerWell,
            groupSize: 1,
            variantSeed: sequence &+ generation &* 53,
            eventKey: R1ContactAudio.EventKey(namespace: eventNamespace,
                                              generation: generation,
                                              sequence: sequence),
            pan: TableFoleySpatialModel.pan(seat: seat,
                                            playerCount: playerCount),
            volumeOverride: isPayout ? 0.42 : 0.34
        )
    }

    private func play(family: String,
                      variants: [String],
                      seed: Int,
                      salt: UInt64,
                      volume: Float,
                      pan: Float) {
        guard prepareSessionIfNeeded() else { return }
        let index = R1ContactVariantResolver.resolve(
            variantCount: variants.count,
            seed: seed,
            familySalt: salt,
            previousIndex: previousVariant[family]
        )
        let name = variants[index]
        guard let pool = players(named: name), !pool.isEmpty else { return }
        let voiceIndex = nextVoice[name, default: 0] % pool.count
        let player = pool[voiceIndex]

        previousVariant[family] = index
        nextVoice[name] = voiceIndex + 1
        player.currentTime = 0
        player.volume = volume
        player.pan = pan
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

    private func prepareSessionIfNeeded() -> Bool {
        if sessionPrepared { return true }
        do {
            try PochAudioSession.prepareAmbientMixing()
            sessionPrepared = true
            return true
        } catch {
            Self.log.error(
                "Unable to prepare table Foley audio session: \(error.localizedDescription, privacy: .public)"
            )
            return false
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
