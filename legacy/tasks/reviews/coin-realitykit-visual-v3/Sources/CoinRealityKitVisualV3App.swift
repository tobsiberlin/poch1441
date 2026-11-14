import SwiftUI

@main
struct CoinRealityKitVisualV3App: App {
    @StateObject private var status = VisualStatusModel()

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .topLeading) {
                VisualRunnerContainer(status: status)
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.title).font(.headline)
                    Text(status.verdict)
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                    Text(status.detail)
                        .font(.system(.caption2, design: .monospaced))
                }
                .padding(10)
                .foregroundStyle(.white)
                .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 12))
                .padding(12)
                .allowsHitTesting(false)
            }
            .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class VisualStatusModel: ObservableObject {
    @Published var title = "RealityKit Visual Contract V3"
    @Published var verdict = "RUNNING"
    @Published var detail = "Aufbau ..."
}

struct VisualRunnerContainer: UIViewControllerRepresentable {
    let status: VisualStatusModel

    func makeUIViewController(context: Context) -> VisualRunnerViewController {
        VisualRunnerViewController(status: status)
    }

    func updateUIViewController(_ uiViewController: VisualRunnerViewController, context: Context) {}
}

