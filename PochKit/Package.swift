// swift-tools-version: 5.9
import PackageDescription

// PochKit läuft auch auf macOS, damit Tests und Monte-Carlo-Simulationen headless laufen (Spec Abschnitt 5/14).
let package = Package(
    name: "PochKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PochKit", targets: ["PochKit"]),
        .executable(name: "pochsim", targets: ["pochsim"])
    ],
    targets: [
        .target(name: "PochKit"),
        .executableTarget(name: "pochsim", dependencies: ["PochKit"]),
        .testTarget(name: "PochKitTests", dependencies: ["PochKit"])
    ]
)
