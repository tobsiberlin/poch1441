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

    static func state(progress: Double) -> Self {
        let clamped = min(max(progress, 0), 1)
        let eased = smoothstep(clamped)
        let origin = Float(1 - eased)
        let present = Float(eased)

        // A fourth-power sine bump keeps both eras completely clean while
        // concentrating the acoustic seam around the finger's midpoint.
        let seamPosition = sin(.pi * clamped)
        let seam = Float(pow(seamPosition, 4))

        return Self(
            originRoomVolume: origin * 0.36,
            originMotifVolume: origin * 0.18,
            presentRoomVolume: present * 0.28,
            presentMotifVolume: present * 0.16,
            timeNoiseVolume: seam * 0.15,
            // A restrained interval reads as material transformation rather
            // than a literal radio sweep. Reversing the finger reverses it.
            timeNoiseRate: 0.84 + Float(clamped) * 0.32
        )
    }

    private static func smoothstep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}
