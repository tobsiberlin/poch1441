import SwiftUI

@main
struct CoinRealityKitCalibrationApp: App {
    @StateObject private var status = CalibrationStatusModel()

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .topLeading) {
                CalibrationContainer(status: status)
                    .ignoresSafeArea()

                CalibrationStatusOverlay(status: status)
                    .padding(16)
            }
            .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class CalibrationStatusModel: ObservableObject {
    @Published var title = "RealityKit Contact Calibration"
    @Published var detail = "Szene wird aufgebaut ..."
    @Published var verdict = "RUNNING"
}

private struct CalibrationStatusOverlay: View {
    @ObservedObject var status: CalibrationStatusModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(status.title)
                .font(.headline)
            Text(status.verdict)
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(status.verdict == "GREEN" ? .green : status.verdict == "RED" ? .red : .yellow)
            Text(status.detail)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.84))
                .lineLimit(12)
        }
        .padding(12)
        .frame(maxWidth: 360, alignment: .leading)
        .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

