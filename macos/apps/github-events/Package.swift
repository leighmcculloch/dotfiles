// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitHubEvents",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GitHubEvents",
            path: "Sources"
        ),
        .testTarget(
            name: "GitHubEventsTests",
            dependencies: ["GitHubEvents"],
            path: "Tests/GitHubEventsTests"
        )
    ]
)
