import SwiftUI

@main
struct CardMotionNativeSpikeV4App: App {
    var body: some Scene {
        WindowGroup {
            SpikeRootView()
        }
    }
}

struct SpikeRootView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @StateObject private var controller = CardMotionController()
    @State private var manualReduceMotion = false
    @State private var evidenceStatus = "READY"

    private var effectiveReduceMotion: Bool { systemReduceMotion || manualReduceMotion }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                CardMotionStage(snapshot: controller.snapshot, layout: controller.layout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                controls
            }
            .background(Color(red: 0.032, green: 0.038, blue: 0.035))
            .onAppear {
                let stageHeight = max(375, proxy.size.height - 118)
                controller.reset(width: proxy.size.width, height: stageHeight)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: effectiveReduceMotion) { _, enabled in
            controller.setReducedMotion(enabled)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--export-evidence") else { return }
            evidenceStatus = "CAPTURING"
            do {
                try await WallclockEvidenceRecorder.captureAll(controller: controller)
                evidenceStatus = "COMPLETE"
            } catch {
                evidenceStatus = "RED · \(error.localizedDescription)"
                if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try? Data("\(error.localizedDescription)\n".utf8).write(
                        to: documents.appendingPathComponent("card-motion-v4-error.txt"),
                        options: .atomic
                    )
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Text(evidenceStatus)
                Spacer()
                Text("Kontakt \(controller.snapshot.contacts.count)")
            }
            .font(.caption.monospaced())
            .foregroundStyle(.white.opacity(0.62))
            Toggle("Bewegung reduzieren", isOn: $manualReduceMotion)
                .font(.caption)
            HStack {
                Button("Deal") {
                    manualReduceMotion = false
                    controller.startSingleDeal()
                }
                Button("8 Deals") {
                    manualReduceMotion = false
                    controller.reset(width: controller.layout.viewport.width, height: controller.layout.viewport.height, deckCount: 12)
                    controller.startDealBurst(count: 8)
                }
                Button("Play") {
                    manualReduceMotion = false
                    controller.startPlay()
                }
                Button("Abbrechen") {
                    _ = controller.cancelActivePlay()
                }
            }
            .buttonStyle(.bordered)
            .font(.caption.weight(.semibold))
        }
        .padding(12)
        .background(.black.opacity(0.58))
    }
}
