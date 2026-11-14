import SwiftUI

@main
struct CoinRealityKitSpikeApp: App {
    @StateObject private var status = SpikeStatusModel()

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .topLeading) {
                RealityKitSpikeContainer(status: status)
                    .ignoresSafeArea()

                SpikeStatusOverlay(status: status)
                    .padding(16)
            }
            .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class SpikeStatusModel: ObservableObject {
    @Published var title = "RealityKit Coin Spike"
    @Published var detail = "Szene wird aufgebaut …"
    @Published var verdict = "RUNNING"
}

private struct SpikeStatusOverlay: View {
    @ObservedObject var status: SpikeStatusModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(status.title)
                .font(.headline)
            Text(status.verdict)
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(status.verdict == "GREEN" ? .green : status.verdict == "RED" ? .red : .yellow)
            Text(status.detail)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(8)
        }
        .padding(12)
        .frame(maxWidth: 340, alignment: .leading)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
