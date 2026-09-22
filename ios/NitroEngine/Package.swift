// swift-tools-version: 5.9
import PackageDescription

// NeonEngine: the Nitro Nebula simulation, a 1:1 port of www/game.js
// (physics, spawning, collisions, CPU wingman, online snapshot codec).
// Foundation only, so `swift test` runs on macOS without a simulator.
let package = Package(
    name: "NeonEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NeonEngine", targets: ["NeonEngine"])
    ],
    targets: [
        .target(name: "NeonEngine", path: "Sources/NeonEngine"),
        .testTarget(
            name: "NeonEngineTests",
            dependencies: ["NeonEngine"],
            path: "Tests/NeonEngineTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
