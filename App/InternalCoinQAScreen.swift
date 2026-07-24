#if INTERNAL_QA
import SwiftUI

struct InternalCoinQAScreen: View {
    private enum PlaybackChoice: String, CaseIterable, Identifiable {
        case standard
        case reduced

        var id: String { rawValue }
        var mode: TranscriptPlaybackMode {
            self == .standard ? .standard : .reducedMotion
        }
        var title: String {
            switch self {
            case .standard:
                String(localized: "internal.coinQA.mode.standard", defaultValue: "Standard", table: "InternalCoinQA")
            case .reduced:
                String(localized: "internal.coinQA.mode.reduced", defaultValue: "Reduziert", table: "InternalCoinQA")
            }
        }
    }

    private enum PlaybackState {
        case ready
        case flying
        case contact
        case resting

        var title: String {
            switch self {
            case .ready:
                String(localized: "internal.coinQA.state.ready", defaultValue: "Bereit", table: "InternalCoinQA")
            case .flying:
                String(localized: "internal.coinQA.state.flying", defaultValue: "Münze unterwegs", table: "InternalCoinQA")
            case .contact:
                String(localized: "internal.coinQA.state.contact", defaultValue: "Kontakt erkannt", table: "InternalCoinQA")
            case .resting:
                String(localized: "internal.coinQA.state.resting", defaultValue: "Münze liegt", table: "InternalCoinQA")
            }
        }
    }

    @Binding var soundEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var choice: PlaybackChoice = .standard
    @State private var playbackState: PlaybackState = .ready
    @State private var runID = 0
    @State private var hasPlayback = false
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Tokens.bgLift, Tokens.bgDeep],
                center: UnitPoint(x: 0.5, y: 0.34),
                startRadius: 12,
                endRadius: 620
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                coinStage
                controls
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if systemReduceMotion { choice = .reduced }
        }
        .onChange(of: choice) { _, _ in
            hasPlayback = false
            playbackState = .ready
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(String(localized: "internal.coinQA.eyebrow", defaultValue: "INTERNER GERÄTETEST", table: "InternalCoinQA"))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.25)
                    .foregroundStyle(Tokens.jewelGold)
                Text(String(localized: "internal.coinQA.title", defaultValue: "Münzkontakt", table: "InternalCoinQA"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.jewelPlatin)
                Text(String(localized: "internal.coinQA.body", defaultValue: "Prüfe, ob Bild, Kupferklang und Haptik beim Auftreffen zusammenpassen.", table: "InternalCoinQA"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Tokens.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.jewelPlatin)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
            .accessibilityLabel(String(localized: "internal.coinQA.close", defaultValue: "Schließen", table: "InternalCoinQA"))
            .accessibilityIdentifier("internal.coinQA.close")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var coinStage: some View {
        GeometryReader { proxy in
            let boardDiameter = Tokens.ringRadius * 2 * Tokens.phase2BoardScale
                + Tokens.tileDiameter * Tokens.phase2BoardScale
            let sliderVisualRightEdge: CGFloat = 81
            let boardCenter = CGPoint(
                x: sliderVisualRightEdge + (proxy.size.width - sliderVisualRightEdge) / 2,
                y: min(Tokens.phase2StageHeight, proxy.size.height * 0.35) / 2
            )

            TableWorldBoardBase(world: .unterwegs, diameter: boardDiameter)
                .frame(width: boardDiameter, height: boardDiameter)
                .position(boardCenter)

            if hasPlayback, let plan = try? CertifiedCoinTranscript.bundled() {
                TranscriptCoinDrop(
                    plan: plan,
                    mode: choice.mode,
                    soundEnabled: soundEnabled,
                    hapticsEnabled: hapticsEnabled,
                    onContact: { playbackState = .contact },
                    onRest: {
                        playbackState = .resting
                        isPlaying = false
                    }
                )
                .id("internal-coin-\(runID)-\(choice.rawValue)")
                .allowsHitTesting(false)
            }

            Text(playbackState.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(playbackState == .resting ? Tokens.smaragdText : Tokens.jewelPlatin)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.48)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.11), lineWidth: 1))
                .position(x: proxy.size.width / 2, y: min(proxy.size.height - 24, boardDiameter + 46))
                .accessibilityIdentifier("internal.coinQA.status")
        }
        .frame(minHeight: 280)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            Picker(String(localized: "internal.coinQA.mode", defaultValue: "Bewegung", table: "InternalCoinQA"), selection: $choice) {
                ForEach(PlaybackChoice.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isPlaying)
            .accessibilityIdentifier("internal.coinQA.mode")

            HStack(spacing: 12) {
                Toggle(String(localized: "internal.coinQA.sound", defaultValue: "Sound", table: "InternalCoinQA"), isOn: $soundEnabled)
                    .tint(Tokens.jewelGold)
                Toggle(String(localized: "internal.coinQA.haptics", defaultValue: "Haptik", table: "InternalCoinQA"), isOn: $hapticsEnabled)
                    .tint(Tokens.jewelGold)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Tokens.jewelPlatin)

            Button(action: play) {
                Text(String(localized: "internal.coinQA.play", defaultValue: "Test abspielen", table: "InternalCoinQA"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Tokens.bgDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 15).fill(Tokens.jewelGold))
            }
            .buttonStyle(.plain)
            .disabled(isPlaying)
            .opacity(isPlaying ? 0.58 : 1)
            .accessibilityIdentifier("internal.coinQA.play")

            Text(String(localized: "internal.coinQA.note", defaultValue: "Bitte ohne Kabel testen. Für die Freigabe zusätzlich einmal mit „Bewegung reduzieren“ wiederholen.", table: "InternalCoinQA"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.slate)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private func play() {
        playbackState = .flying
        runID += 1
        hasPlayback = true
        isPlaying = true
    }
}
#endif
