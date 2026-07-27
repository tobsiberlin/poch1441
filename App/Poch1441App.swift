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
        return forcedQAOrientationMask ?? .allButUpsideDown
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        deviceOrientationDidChange()
    }

    @objc private func deviceOrientationDidChange() {
        guard let mask = forcedQAOrientationMask else { return }

        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { [logger] error in
                logger.error("Orientierungswechsel abgelehnt: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private var forcedQAOrientationMask: UIInterfaceOrientationMask? {
        #if DEBUG || INTERNAL_QA
        if ProcessInfo.processInfo.arguments.contains("-landscapeQA") {
            return .landscapeLeft
        }
        if ProcessInfo.processInfo.arguments.contains("-portraitQA") {
            return .portrait
        }
        #endif
        return nil
    }
}

@main
struct Poch1441App: App {
    @UIApplicationDelegateAdaptor(PochOrientationDelegate.self) private var orientationDelegate

    var body: some Scene {
        WindowGroup {
            PochLaunchRoot()
        }
    }
}

/// The OS owns the duration of `LaunchScreen.storyboard`. This app-owned
/// continuation gives the brand enough time to register on a cold start while
/// keeping warm resumes immediate and silent.
private struct PochLaunchRoot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsBrandContinuation: Bool

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG || INTERNAL_QA
        // UI and screenshot tests supply launch arguments and should not spend
        // their timing budget on a passive brand hold.
        _showsBrandContinuation = State(initialValue: arguments.dropFirst().isEmpty)
        #else
        _showsBrandContinuation = State(initialValue: true)
        #endif
    }

    var body: some View {
        ZStack {
            if showsBrandContinuation {
                Color(hex: 0x101821)
                    .ignoresSafeArea()
                    .overlay {
                        // Match LaunchScreen.storyboard exactly: its 200 × 44
                        // aspect-fit frame renders the 1180:220 wordmark at
                        // 200 × 37.3 points. Any other geometry visibly jumps
                        // when iOS hands the first frame to SwiftUI.
                        PochBrandWordmark(height: 200 * 220 / 1180)
                            .accessibilityHidden(true)
                    }
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .task {
            guard showsBrandContinuation else { return }
            // The OS launch screen is intentionally minimal. This continuation
            // holds the complete wordmark long enough to be read once, then
            // yields without turning every warm resume into an interstitial.
            // The previous 1.48-second continuation disappeared before the
            // wordmark had registered on a physical phone. Keep one composed
            // frame long enough to read, without turning the launch into a
            // trailer. UI-test launches still bypass this hold in init().
            let hold = reduceMotion ? 1_550 : 2_150
            try? await Task.sleep(for: .milliseconds(hold))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.24 : 0.44)) {
                showsBrandContinuation = false
            }
        }
    }
}
