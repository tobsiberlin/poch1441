import SwiftUI
import os

@main
struct TranscriptMotionPlayerV1App: App {
    var body: some Scene {
        WindowGroup {
            HarnessLauncherView()
        }
    }
}

private struct HarnessLauncherView: View {
    private static let log = Logger(
        subsystem: "com.tobc.reviews.transcript-motion-player-v1",
        category: "Evidence"
    )
    @State private var status = "BEREIT"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Text("TRANSCRIPT PLAYER · V1")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                Text(status)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--export-evidence") else {
                status = "START MIT --export-evidence"
                return
            }
            status = "WALLCLOCK · 60/80/120 HZ"
            do {
                try await EvidenceRecorder.captureAll()
                status = "EXPORT VOLLSTÄNDIG"
                Self.log.info("Transcript player V1 evidence export complete")
            } catch {
                status = "EXPORT FEHLGESCHLAGEN"
                Self.log.error("Evidence export failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
