import SwiftUI

@main
struct CoinMotionPresentationV5App: App {
    var body: some Scene {
        WindowGroup {
            CoinMotionRootView()
                .preferredColorScheme(.dark)
        }
    }
}

struct CoinMotionRootView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var manualReduceMotion = false

    private var reducedMotion: Bool { systemReduceMotion || manualReduceMotion }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LiveMotionRepresentable(reducedMotion: reducedMotion)
                .ignoresSafeArea()
            Toggle("Bewegung reduzieren", isOn: $manualReduceMotion)
                .labelsHidden()
                .tint(Color(red: 0.84, green: 0.68, blue: 0.35))
                .padding(18)
                .accessibilityLabel("Bewegung reduzieren")
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--export-evidence") else { return }
            await EvidenceExporter.exportAll()
        }
    }
}

struct LiveMotionRepresentable: UIViewRepresentable {
    let reducedMotion: Bool

    func makeUIView(context: Context) -> UIView {
        guard let renderer = CoinSceneRenderer(),
              let view = LiveMotionView(frame: .zero, renderer: renderer) else {
            return UIView(frame: .zero)
        }
        view.setReducedMotion(reducedMotion)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? LiveMotionView)?.setReducedMotion(reducedMotion)
    }
}
