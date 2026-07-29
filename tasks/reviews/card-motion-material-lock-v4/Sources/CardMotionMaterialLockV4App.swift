import SwiftUI

@main
struct CardMotionMaterialLockV4App: App {
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
            let arguments = ProcessInfo.processInfo.arguments
            guard arguments.contains("--export-evidence")
                || arguments.contains("--export-static-evidence") else { return }
            exportStatus = "CAPTURING"
            do {
                if arguments.contains("--export-static-evidence") {
                    try PlaneLockEvidenceRecorder.captureStaticGate()
                } else {
                    try await PlaneLockEvidenceRecorder.capture(controller: controller)
                }
                exportStatus = "COMPLETE"
            } catch {
                exportStatus = "RED · \(error.localizedDescription)"
                if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try? Data("\(error.localizedDescription)\n".utf8).write(
                        to: documents.appendingPathComponent("card-material-lock-v4-error.txt"),
                        options: .atomic
                    )
                }
            }
        }
    }
}
