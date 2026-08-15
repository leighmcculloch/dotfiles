// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PasteMarkdown",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PasteMarkdown",
            path: "Sources"
        )
    ]
)
