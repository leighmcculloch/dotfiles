import AppKit
import ImageIO
import Vision

enum QRScanError: LocalizedError {
    case imageCouldNotBeRead

    var errorDescription: String? {
        switch self {
        case .imageCouldNotBeRead:
            return "The image could not be read."
        }
    }
}

enum QRCodeScanner {
    static func scan(url: URL) throws -> [QRCode] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw QRScanError.imageCouldNotBeRead
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as NSDictionary?
        let rawOrientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up
        return try scan(cgImage: image, orientation: orientation)
    }

    static func cgImage(from image: NSImage) throws -> CGImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw QRScanError.imageCouldNotBeRead
        }
        return cgImage
    }

    static func scan(cgImage: CGImage) throws -> [QRCode] {
        try scan(cgImage: cgImage, orientation: .up)
    }

    private static func scan(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> [QRCode] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation,
            options: [:]
        )
        try handler.perform([request])

        let detections = (request.results ?? [])
            .compactMap { observation -> (QRCode, CGRect)? in
                guard let value = observation.payloadStringValue,
                      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { return nil }
                return (QRCode(value: value), observation.boundingBox)
            }
            .sorted { lhs, rhs in
                if abs(lhs.1.maxY - rhs.1.maxY) > 0.01 {
                    return lhs.1.maxY > rhs.1.maxY
                }
                return lhs.1.minX < rhs.1.minX
            }

        return detections.map { $0.0 }
    }
}
