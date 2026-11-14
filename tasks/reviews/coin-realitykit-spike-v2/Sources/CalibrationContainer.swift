import SwiftUI

struct CalibrationContainer: UIViewControllerRepresentable {
    let status: CalibrationStatusModel

    func makeUIViewController(context: Context) -> CalibrationViewController {
        CalibrationViewController(status: status)
    }

    func updateUIViewController(_ uiViewController: CalibrationViewController, context: Context) {}
}

