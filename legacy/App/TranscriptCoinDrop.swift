#if DEBUG || INTERNAL_QA
import AVFoundation
import Darwin
import QuartzCore
import SwiftUI

@MainActor
private final class TranscriptCoinDropCoordinator {
    private let eventID = "coin-track-b-queen-drop-seed-1441"
    private let generation = 1_441
    private var transaction: CoinTransferTransaction
    private let feedback: MotionContactCueCoordinator
    private let soundEnabled: Bool
    private let hapticsEnabled: Bool
    private let onContact: @MainActor () -> Void
    private let onRest: @MainActor () -> Void

    init(soundEnabled: Bool,
         hapticsEnabled: Bool,
         onContact: @escaping @MainActor () -> Void,
         onRest: @escaping @MainActor () -> Void) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.onContact = onContact
        self.onRest = onRest
        feedback = MotionContactCueCoordinator(output: CoinContactFeedbackEngine())
        transaction = CoinTransferTransaction(
            eventID: eventID,
            generation: generation,
            motionPreference: .standard
        )
    }

    var identity: CoinTransferIdentity { transaction.identity }

    func prepareFeedback() {
        // Physical output availability must never block the certified visual
        // transaction or its state commit.
        try? feedback.prepare()
    }

    func release(contactHostTime: UInt64, surfaceID: String) {
        guard transaction.depart(eventID: eventID, generation: generation) == .accepted else {
            return
        }
        _ = transaction.enterAirborne(eventID: eventID, generation: generation)
        let cue = MotionContactCue(
            identity: identity,
            contactHostTime: contactHostTime,
            surfaceID: surfaceID,
            audioFingerprintID: "cent-copper-polycarbonate-01",
            soundEnabled: soundEnabled,
            hapticsEnabled: hapticsEnabled
        )
        _ = try? feedback.schedule(cue)
    }

    func contact() {
        _ = feedback.markContact(identity: identity)
        _ = transaction.registerImpact(
            eventID: eventID,
            generation: generation,
            applyAtomically: onContact
        )
    }

    func rest() {
        guard transaction.beginSettling(
            eventID: eventID,
            generation: generation
        ) == .accepted else { return }
        guard transaction.complete(
            eventID: eventID,
            generation: generation
        ) == .accepted else { return }
        onRest()
    }

    func cancelBeforeRelease() {
        _ = feedback.cancelBeforeContact(identity: identity)
        _ = transaction.cancel(eventID: eventID, generation: generation)
    }

    func cancelFeedbackBeforeContact() {
        _ = feedback.cancelBeforeContact(identity: identity)
    }
}

/// Isolierter Queen-Well-Drop-Proof. Das zertifizierte V1-Transcript beginnt
/// bereits über der Mulde und ist ausdrücklich kein vollständiger Quellstapel-Wurf.
struct TranscriptCoinDrop: View {
    let plan: CertifiedCoinTranscript
    let mode: TranscriptPlaybackMode
    let soundEnabled: Bool
    let hapticsEnabled: Bool
    let onContact: @MainActor () -> Void
    let onRest: @MainActor () -> Void

    @State private var coordinator: TranscriptCoinDropCoordinator
    @State private var player: CoinTranscriptMotionPlayer
    @State private var snapshot: CoinTranscriptPlaybackSnapshot

    init(plan: CertifiedCoinTranscript,
         mode: TranscriptPlaybackMode,
         soundEnabled: Bool,
         hapticsEnabled: Bool,
         onContact: @escaping @MainActor () -> Void,
         onRest: @escaping @MainActor () -> Void) {
        self.plan = plan
        self.mode = mode
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.onContact = onContact
        self.onRest = onRest

        let coordinator = TranscriptCoinDropCoordinator(
            soundEnabled: soundEnabled,
            hapticsEnabled: hapticsEnabled,
            onContact: onContact,
            onRest: onRest
        )
        guard let player = CoinTranscriptMotionPlayer(
            plan: plan,
            mode: mode,
            onContact: coordinator.contact,
            onRest: coordinator.rest,
            onCancelBeforeRelease: coordinator.cancelBeforeRelease
        ) else {
            preconditionFailure("The admitted Track-B coin transcript must remain valid")
        }
        _coordinator = State(initialValue: coordinator)
        _player = State(initialValue: player)
        _snapshot = State(initialValue: player.currentSnapshot)
    }

    var body: some View {
        GeometryReader { proxy in
            let boardDiameter = Tokens.ringRadius * 2 * Tokens.phase2BoardScale
                + Tokens.tileDiameter * Tokens.phase2BoardScale
            let sliderVisualRightEdge: CGFloat = 81
            let boardCenter = CGPoint(
                x: sliderVisualRightEdge
                    + (proxy.size.width - sliderVisualRightEdge) / 2,
                y: min(Tokens.phase2StageHeight, proxy.size.height * 0.35) / 2
            )
            let queen = TravelTableGeometry.center(for: .queen)
            let target = CGPoint(
                x: boardCenter.x + (queen.x - 0.5) * boardDiameter,
                y: boardCenter.y + (queen.y - 0.5) * boardDiameter
            )

            spriteFrame
                .position(projectedFloorCenter(target: target))

            // Recompose the real tray pixels over the moving coin at the
            // Queen front edge, matching the admitted V3 occlusion contract.
            TableWorldBoardBase(world: .unterwegs, diameter: boardDiameter)
                .frame(width: boardDiameter, height: boardDiameter)
                .mask {
                    QueenFrontLipMask()
                        .stroke(style: StrokeStyle(
                            lineWidth: boardDiameter * 0.032,
                            lineCap: .round
                        ))
                }
                .position(boardCenter)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("phase2.coin.transcript.drop")
        .accessibilityLabel("Track-B Queen-Well Transcript-Drop")
        .accessibilityValue(
            "\(snapshot.phase.rawValue), coin 1/1, moving \(snapshot.isMoving ? 1 : 0), contact \(snapshot.contactDelivered ? 1 : 0), rest \(snapshot.restDelivered ? 1 : 0)"
        )
        .task { await play() }
    }

    private var spriteFrame: some View {
        let frameIndex = min(max(Int(floor(snapshot.elapsedSeconds * 60)), 0), 97)
        let column = frameIndex % 7
        let row = frameIndex / 7
        return Image("CoinTranscriptSpriteAtlas")
            .resizable()
            .interpolation(.high)
            .frame(width: 448, height: 896, alignment: .topLeading)
            .offset(x: -CGFloat(column) * 64,
                    y: -CGFloat(row) * 64)
            .frame(width: 64, height: 64, alignment: .topLeading)
            .clipped()
    }

    private func projectedFloorCenter(target: CGPoint) -> CGPoint {
        CGPoint(
            x: target.x + snapshot.sample.position.x / 0.049 * 51,
            y: target.y - snapshot.sample.position.y / 0.039 * 40
        )
    }

    @MainActor
    private func play() async {
        coordinator.prepareFeedback()
        if mode == .standard {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else {
                _ = player.cancel(at: CACurrentMediaTime())
                return
            }
        }
        let releaseMediaTime = CACurrentMediaTime()
        let releaseHostTime = mach_absolute_time()
        let contactDelay = mode == .standard ? (plan.contactTimeSeconds ?? 0) : 0
        let contactHostTime = releaseHostTime + AVAudioTime.hostTime(forSeconds: contactDelay)
        coordinator.release(contactHostTime: contactHostTime, surfaceID: plan.surfaceID)
        snapshot = player.release(at: releaseMediaTime)
        while snapshot.isMoving {
            do {
                try await Task.sleep(for: .milliseconds(4))
            } catch {
                // A committed transcript is never retargeted or rewound. View
                // removal owns the local proof and emits no late state write.
                coordinator.cancelFeedbackBeforeContact()
                return
            }
            guard !Task.isCancelled else {
                coordinator.cancelFeedbackBeforeContact()
                return
            }
            snapshot = player.advance(to: CACurrentMediaTime())
        }
    }
}

private struct QueenFrontLipMask: Shape {
    func path(in rect: CGRect) -> Path {
        let center = TravelTableGeometry.center(for: .queen)
        let radius = rect.width
            * TravelTableGeometry.normalizedWellDiameter(for: .queen) / 2
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.width * center.x, y: rect.height * center.y),
            radius: radius,
            startAngle: .degrees(18),
            endAngle: .degrees(162),
            clockwise: false
        )
        return path
    }
}
#endif
