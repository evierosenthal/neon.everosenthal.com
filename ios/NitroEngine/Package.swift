// swift-tools-version: 5.9
import PackageDescription

// NitroEngine: the Nitro Nebula simulation, a 1:1 port of www/game.js
// (physics, spawning, collisions, CPU wingman, online snapshot codec).
// Foundation only, so `swift test` runs on macOS without a simulator.
let package = Package(
    name: "NitroEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NitroEngine", targets: ["NitroEngine"])
    ],
    targets: [
        .target(name: "NitroEngine", path: "Sources/NitroEngine"),
        .testTarget(
            name: "NitroEngineTests",
            dependencies: ["NitroEngine"],
            path: "Tests/NitroEngineTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
