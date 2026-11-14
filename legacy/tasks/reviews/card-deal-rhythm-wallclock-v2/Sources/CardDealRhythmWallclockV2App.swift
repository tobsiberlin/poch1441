import SwiftUI
import os

@main
struct CardDealRhythmWallclockV2App: App {
    var body: some Scene {
        WindowGroup {
            HarnessLauncherView()
        }
    }
}

private struct HarnessLauncherView: View {
    private static let log = Logger(
        subsystem: "com.tobc.reviews.card-deal-rhythm-wallclock-v2",
        category: "Evidence"
    )
    @State private var status = "BEREIT"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                Text("CARD DEAL RHYTHM · V2")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                Text(status)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--export-evidence") else {
                status = "START MIT --export-evidence"
                return
            }
            status = "ECHTE 60-FPS-WALLCLOCK-AUFNAHME"
            do {
                try await WallclockEvidenceRecorder.captureAll()
                status = "EXPORT VOLLSTÄNDIG"
                Self.log.info("Card deal rhythm evidence export complete")
            } catch {
                status = "EXPORT FEHLGESCHLAGEN"
                Self.log.error("Evidence export failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
