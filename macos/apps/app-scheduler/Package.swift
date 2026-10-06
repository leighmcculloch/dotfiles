// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppScheduler",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "AppScheduler", path: "Sources"),
        .testTarget(
            name: "AppSchedulerTests",
            dependencies: ["AppScheduler"],
            path: "Tests/AppSchedulerTests"
        )
    ]
)
