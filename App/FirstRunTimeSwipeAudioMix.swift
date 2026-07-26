import Foundation

/// Pure, deterministic mix state for the direct-manipulation time bridge.
/// The transition layer is silent at both eras and peaks only in the seam.
struct FirstRunTimeSwipeAudioMix: Equatable, Sendable {
    let originRoomVolume: Float
    let originMotifVolume: Float
    let presentRoomVolume: Float
    let presentMotifVolume: Float
    let timeNoiseVolume: Float
    let timeNoiseRate: Float

    static func state(progress: Double, reduceMotion: Bool = false) -> Self {
        let clamped = min(max(progress, 0), 1)
        let angle = clamped * .pi / 2
        let origin = clamped == 1 ? Float.zero : Float(cos(angle))
        let present = clamped == 0 ? Float.zero : Float(sin(angle))

        // A fourth-power sine bump keeps both eras completely clean while
        // concentrating the acoustic seam around the finger's midpoint.
        let seamPosition = sin(.pi * clamped)
        let seam = Float(pow(seamPosition, 4))

        return Self(
            originRoomVolume: origin * 0.78,
            originMotifVolume: origin * 0.12,
            presentRoomVolume: present * 0.78,
            presentMotifVolume: present * 0.10,
            timeNoiseVolume: seam * (reduceMotion ? 0.10 : 0.28),
            // A restrained interval reads as material transformation rather
            // than a literal radio sweep. Reversing the finger reverses it.
            timeNoiseRate: reduceMotion ? 1 : 0.84 + Float(clamped) * 0.32
        )
    }
}
