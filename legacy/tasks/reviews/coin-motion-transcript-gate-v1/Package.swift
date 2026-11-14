// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoinMotionTranscriptGateV1",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "coin-transcript-gate", targets: ["CoinTranscriptGate"]),
    ],
    targets: [
        .executableTarget(name: "CoinTranscriptGate"),
    ]
)
