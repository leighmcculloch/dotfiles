import AppKit

let sizes: [(String, CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let iconsetPath = "build/AppIcon.iconset"
try FileManager.default.createDirectory(
    atPath: iconsetPath, withIntermediateDirectories: true
)

for (name, size) in sizes {
    let image = NSImage(
        systemSymbolName: "doc.on.clipboard",
        accessibilityDescription: nil
    )!
    let config = NSImage.SymbolConfiguration(
        pointSize: size * 0.6, weight: .regular
    )
    let configured = image.withSymbolConfiguration(config)!

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let symbolSize = configured.size
    let x = (size - symbolSize.width) / 2
    let y = (size - symbolSize.height) / 2
    configured.draw(in: NSRect(
        x: x, y: y, width: symbolSize.width, height: symbolSize.height
    ))

    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", "build/AppIcon.icns"]
try process.run()
process.waitUntilExit()
