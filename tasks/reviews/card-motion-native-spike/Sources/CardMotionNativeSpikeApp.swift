import SwiftUI

@main
struct CardMotionNativeSpikeApp: App {
    var body: some Scene {
        WindowGroup {
            SpikeRootView()
        }
    }
}

struct SpikeRootView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @StateObject private var controller = CardMotionController()
    @StateObject private var frameProbe = RealtimeFrameProbe()
    @State private var manualReduceMotion = false

    private var effectiveReduceMotion: Bool {
        systemReduceMotion || manualReduceMotion
    }

    var body: some View {
        VStack(spacing: 0) {
            CardMotionStage(
                progress: controller.progress,
                revealProgress: controller.revealProgress,
                overlayOpacity: controller.overlayOpacity,
                phaseLabel: controller.phaseLabel,
                flightIdentity: controller.flightIdentity
            )
            .accessibilityIdentifier("live-card-motion-stage")

            controls
        }
        .background(Color(red: 0.035, green: 0.045, blue: 0.04))
        .preferredColorScheme(.dark)
        .onChange(of: effectiveReduceMotion) { _, enabled in
            controller.setReduceMotion(enabled)
        }
        .task {
            if effectiveReduceMotion {
                controller.setReduceMotion(true)
            }
            await runLaunchAutomationIfRequested()
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Kontakt: \(controller.contactCount)")
                Spacer()
                Text("Frame-Probe: \(frameProbe.verdict)")
            }
            .font(.caption.monospaced())
            .foregroundStyle(.white.opacity(0.68))

            Toggle("Reduce Motion live", isOn: $manualReduceMotion)
                .accessibilityIdentifier("reduce-motion-toggle")

            HStack {
                Button("Deal · Reveal · Play") {
                    manualReduceMotion = false
                    controller.startSequence()
                }
                Button("Play zum Abbruch") {
                    manualReduceMotion = false
                    controller.startCancelablePlay()
                }
                Button("Abbrechen") {
                    controller.cancelBeforeContact()
                }
                .disabled(!controller.isRunning)
            }
            .buttonStyle(.bordered)
            .font(.caption.weight(.semibold))
        }
        .padding(14)
        .background(.black.opacity(0.44))
    }

    @MainActor
    private func runLaunchAutomationIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--export-evidence") {
            try? EvidenceExporter.export()
        }
        if arguments.contains("--run-probe") {
            frameProbe.start()
            controller.runProbeLoop()
            try? await Task.sleep(for: .seconds(5.5))
            try? frameProbe.finishAndWrite()
        }
    }
}
