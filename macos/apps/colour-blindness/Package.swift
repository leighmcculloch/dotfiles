// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ColourBlindness",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ColourBlindness", path: "Sources"),
        .testTarget(
            name: "ColourBlindnessTests",
            dependencies: ["ColourBlindness"],
            path: "Tests/ColourBlindnessTests"
        )
    ]
)
