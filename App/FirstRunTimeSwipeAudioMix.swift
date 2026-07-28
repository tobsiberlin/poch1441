import Foundation

/// Pure, deterministic mix state for the direct-manipulation time bridge.
/// Two genuinely different rooms follow the finger through a reversible
/// equal-power crossfade. A quiet, broadband time texture exists only around
/// the center so the seam reads as a place in time, never as a third scene.
struct FirstRunTimeSwipeAudioMix: Equatable, Sendable {
    let originRoomVolume: Float
    let originMotifVolume: Float
    let presentRoomVolume: Float
    let presentMotifVolume: Float
    let signatureContactVolume: Float
    let timeNoiseVolume: Float
    let timeNoiseRate: Float
    let originRoomPan: Float
    let originMotifPan: Float
    let presentRoomPan: Float
    let presentMotifPan: Float
    let signatureContactPan: Float

    static func state(progress: Double, reduceMotion: Bool = false) -> Self {
        let clamped = min(max(progress, 0), 1)
        let angle = clamped * .pi / 2
        let origin = clamped == 1 ? Float.zero : Float(cos(angle))
        let present = clamped == 0 ? Float.zero : Float(sin(angle))
        let seamPosition = Float(sin(clamped * .pi))
        let seam = seamPosition * seamPosition
        let seamLevel: Float = reduceMotion ? 0.17 : 0.24
        let finger = Float(clamped)

        return Self(
            // Every layer receives the era gain itself. At the endpoints the
            // opposite world is digital silence; at the seam both worlds retain
            // equal-power audibility without a loudness hole.
            originRoomVolume: origin * 0.48,
            originMotifVolume: origin * 0.55,
            presentRoomVolume: present * 0.46,
            presentMotifVolume: present * 0.68,
            // The same physical knuckle contact and the same event grid survive
            // the complete gesture. Only their acoustic surface and position morph.
            signatureContactVolume: 0.34,
            // The authored texture is broadband and unpitched. Its squared
            // envelope creates one audible, reversible acoustic seam around
            // the center while remaining completely absent at both endpoints.
            timeNoiseVolume: seam * seamLevel,
            timeNoiseRate: 1,
            // The rooms approach the finger-controlled seam without crossing
            // chronology: 1441 remains left, today right, and the invariant
            // signature contact travels continuously through the center.
            originRoomPan: -0.58 + finger * 0.46,
            originMotifPan: -0.34 + finger * 0.24,
            presentRoomPan: 0.12 + finger * 0.46,
            presentMotifPan: 0.10 + finger * 0.24,
            signatureContactPan: -0.22 + finger * 0.44
        )
    }
}
