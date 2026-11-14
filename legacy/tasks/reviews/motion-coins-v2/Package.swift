// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MotionCoinsV2",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "motion-coins-v2-gates", targets: ["MotionCoinsV2Gates"]),
    ],
    targets: [
        .executableTarget(
            name: "MotionCoinsV2Gates",
            path: "Sources/MotionCoinsV2Gates"
        ),
    ]
)
