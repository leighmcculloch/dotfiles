// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QRReader",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "QRReader",
            path: "Sources"
        ),
        .testTarget(
            name: "QRReaderTests",
            dependencies: ["QRReader"],
            path: "Tests/QRReaderTests"
        )
    ]
)
