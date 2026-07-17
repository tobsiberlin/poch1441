import SwiftUI
import UIKit
import os

@MainActor
final class PochOrientationDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger(subsystem: "com.tobc.poch1441", category: "Orientation")

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        return true
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        window?.traitCollection.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    @objc private func deviceOrientationDidChange() {
        let mask: UIInterfaceOrientationMask
        switch UIDevice.current.orientation {
        case .portrait:
            mask = .portrait
        case .portraitUpsideDown:
            mask = .portraitUpsideDown
        case .landscapeLeft:
            mask = .landscapeRight
        case .landscapeRight:
            mask = .landscapeLeft
        default:
            return
        }

        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { [logger] error in
                logger.error("Orientierungswechsel abgelehnt: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

@main
struct Poch1441App: App {
    @UIApplicationDelegateAdaptor(PochOrientationDelegate.self) private var orientationDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
