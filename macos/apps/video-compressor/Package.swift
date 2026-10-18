// swift-tools-version: 5.9
import PackageDescription

var targets: [Target] = [
    .target(name: "VideoCompression", path: "Sources/Core"),
    .testTarget(
        name: "VideoCompressionTests",
        dependencies: ["VideoCompression"],
        path: "Tests/VideoCompressionTests"
    ),
]

// The compression engine can also be tested on Linux with real FFmpeg.
#if os(macOS)
targets.append(.executableTarget(
    name: "VideoCompressor",
    dependencies: ["VideoCompression"],
    path: "Sources/App"
))
#endif

let package = Package(
    name: "VideoCompressor",
    platforms: [.macOS(.v13)],
    targets: targets
)
