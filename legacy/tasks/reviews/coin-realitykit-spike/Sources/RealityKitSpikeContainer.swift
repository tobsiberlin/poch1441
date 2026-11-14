import RealityKit
import SwiftUI

struct RealityKitSpikeContainer: UIViewControllerRepresentable {
    let status: SpikeStatusModel

    func makeUIViewController(context: Context) -> RealityKitSpikeViewController {
        RealityKitSpikeViewController(status: status)
    }

    func updateUIViewController(_ uiViewController: RealityKitSpikeViewController, context: Context) {}
}
