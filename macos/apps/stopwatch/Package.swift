// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Stopwatch",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Stopwatch",
            path: "Sources"
        ),
        .testTarget(
            name: "StopwatchTests",
            dependencies: ["Stopwatch"],
            path: "Tests/StopwatchTests"
        )
    ]
)
