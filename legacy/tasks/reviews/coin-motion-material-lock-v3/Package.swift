// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoinMotionMaterialLockV3",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "coin-material-time-gate", targets: ["CoinMaterialTimeGate"]),
    ],
    targets: [
        .executableTarget(name: "CoinMaterialTimeGate"),
    ]
)
