import Foundation

/// Pure, deterministic mix state for the direct-manipulation time bridge.
/// The former synthetic transition layer stays silent; the two real rooms
/// create the seam through their reversible equal-power crossfade.
struct FirstRunTimeSwipeAudioMix: Equatable, Sendable {
    let originRoomVolume: Float
    let originMotifVolume: Float
    let presentRoomVolume: Float
    let presentMotifVolume: Float
    let timeNoiseVolume: Float
    let timeNoiseRate: Float
    let originRoomPan: Float
    let originMotifPan: Float
    let presentRoomPan: Float
    let presentMotifPan: Float

    static func state(progress: Double, reduceMotion: Bool = false) -> Self {
        let clamped = min(max(progress, 0), 1)
        let angle = clamped * .pi / 2
        let origin = clamped == 1 ? Float.zero : Float(cos(angle))
        let present = clamped == 0 ? Float.zero : Float(sin(angle))

        return Self(
            // The source masters differ by 0.92 dB. These endpoints place both
            // rooms at approximately -27 dBFS RMS before device volume.
            originRoomVolume: origin * 0.50,
            originMotifVolume: origin * 0.18,
            presentRoomVolume: present * 0.45,
            presentMotifVolume: present * 0.16,
            // The previous stationary hiss and pitched 760 Hz seam were audible
            // as an effect rather than a place changing under the finger. The
            // natural rooms now carry the transformation without a radio layer.
            timeNoiseVolume: 0,
            timeNoiseRate: 1,
            // Stereo follows the chronology requested by the product: 1441 on
            // the left, the present on the right, and both rooms meeting at the
            // midpoint. This is deliberately semantic rather than a literal
            // pan beneath the image wipe, whose revealed side changes while the
            // finger moves.
            originRoomPan: -0.28,
            originMotifPan: -0.14,
            presentRoomPan: 0.28,
            presentMotifPan: 0.14
        )
    }
}
