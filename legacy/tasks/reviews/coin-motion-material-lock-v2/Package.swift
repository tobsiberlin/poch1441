// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoinMotionMaterialLockV2",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "coin-material-lock", targets: ["CoinMaterialLock"]),
    ],
    targets: [
        .executableTarget(name: "CoinMaterialLock"),
    ]
)
