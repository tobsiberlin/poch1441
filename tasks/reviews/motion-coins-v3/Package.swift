// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MotionCoinsV3",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "motion-coins-v3-gates", targets: ["MotionCoinsV3Gates"]),
    ],
    targets: [
        .executableTarget(name: "MotionCoinsV3Gates"),
    ]
)
