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
        if window?.traitCollection.userInterfaceIdiom == .pad {
            return .all
        }
        return requestedOrientationMask ?? .allButUpsideDown
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        deviceOrientationDidChange()
    }

    @objc private func deviceOrientationDidChange() {
        guard let mask = requestedOrientationMask else { return }

        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { [logger] error in
                logger.error("Orientierungswechsel abgelehnt: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private var requestedOrientationMask: UIInterfaceOrientationMask? {
        #if DEBUG || INTERNAL_QA
        if ProcessInfo.processInfo.arguments.contains("-landscapeQA") {
            return .landscapeLeft
        }
        if ProcessInfo.processInfo.arguments.contains("-portraitQA") {
            return .portrait
        }
        #endif

        switch UIDevice.current.orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return nil
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
