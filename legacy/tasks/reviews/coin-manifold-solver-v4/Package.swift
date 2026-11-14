// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoinManifoldSolverV4",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CoinManifoldSolver", targets: ["CoinManifoldSolver"]),
        .executable(name: "CoinManifoldSpike", targets: ["CoinManifoldSpike"]),
    ],
    targets: [
        .target(name: "CoinManifoldSolver"),
        .executableTarget(name: "CoinManifoldSpike", dependencies: ["CoinManifoldSolver"]),
        .testTarget(name: "CoinManifoldSolverTests", dependencies: ["CoinManifoldSolver"]),
    ]
)
