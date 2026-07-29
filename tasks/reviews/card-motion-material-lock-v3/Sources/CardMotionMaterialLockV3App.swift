import SwiftUI

@main
struct CardMotionMaterialLockV3App: App {
    var body: some Scene {
        WindowGroup {
            MaterialLockRootView()
        }
    }
}

struct MaterialLockRootView: View {
    @StateObject private var controller = PlaneLockController()
    @State private var exportStatus = "READY"

    var body: some View {
        VStack(spacing: 0) {
            MaterialLockStage(snapshot: controller.snapshot)
            HStack {
                Text(exportStatus)
                Spacer()
                Button("Wiederholen") { controller.start() }
                    .buttonStyle(.bordered)
            }
            .font(.caption.monospaced())
            .foregroundStyle(.white.opacity(0.7))
            .padding(10)
            .background(.black)
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .onAppear {
            controller.reset()
            controller.start()
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--export-evidence") else { return }
            exportStatus = "CAPTURING"
            do {
                try await PlaneLockEvidenceRecorder.capture(controller: controller)
                exportStatus = "COMPLETE"
            } catch {
                exportStatus = "RED · \(error.localizedDescription)"
                if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try? Data("\(error.localizedDescription)\n".utf8).write(
                        to: documents.appendingPathComponent("card-material-lock-v3-error.txt"),
                        options: .atomic
                    )
                }
            }
        }
    }
}
