import AppKit
import CoreImage
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
        var results = [QRCode]()
        var visionError: Error?

        do {
            results.append(contentsOf: try scanWithVision(cgImage: cgImage, orientation: orientation))
        } catch {
            visionError = error
        }

        // Vision is the primary detector, but Core Image is a useful second
        // pass for small QR codes embedded in a larger poster or screenshot.
        // Merge both passes so one detector cannot hide a code found by the
        // other, then remove duplicates by payload.
        results.append(contentsOf: scanWithCoreImage(cgImage: cgImage, orientation: orientation))
        let uniqueResults = unique(results)
        if uniqueResults.isEmpty, let visionError {
            throw visionError
        }
        return uniqueResults
    }

    private static func scanWithVision(
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
                return (QRCode(value: value, bounds: observation.boundingBox), observation.boundingBox)
            }
            .sorted { lhs, rhs in
                if abs(lhs.1.maxY - rhs.1.maxY) > 0.01 {
                    return lhs.1.maxY > rhs.1.maxY
                }
                return lhs.1.minX < rhs.1.minX
            }

        return detections.map { $0.0 }
    }

    private static func scanWithCoreImage(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> [QRCode] {
        guard let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        ) else {
            return []
        }

        let image = CIImage(cgImage: cgImage)
            .oriented(forExifOrientation: Int32(orientation.rawValue))
        let extent = image.extent
        return detector.features(in: image).compactMap { feature in
            guard let feature = feature as? CIQRCodeFeature,
                  let message = feature.messageString,
                  !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }
            let bounds = CGRect(
                x: (feature.bounds.minX - extent.minX) / extent.width,
                y: (feature.bounds.minY - extent.minY) / extent.height,
                width: feature.bounds.width / extent.width,
                height: feature.bounds.height / extent.height
            )
            return QRCode(value: message, bounds: bounds)
        }
    }

    private static func unique(_ results: [QRCode]) -> [QRCode] {
        var uniqueResults = [QRCode]()
        for result in results {
            let isDuplicate = uniqueResults.contains { existing in
                guard existing.value == result.value else { return false }
                guard let existingBounds = existing.bounds,
                      let resultBounds = result.bounds
                else {
                    return existing.bounds == nil && result.bounds == nil
                }

                let intersection = existingBounds.intersection(resultBounds)
                let overlapArea = intersection.isNull
                    ? 0
                    : intersection.width * intersection.height
                let smallerArea = min(
                    existingBounds.width * existingBounds.height,
                    resultBounds.width * resultBounds.height
                )
                return smallerArea > 0 && overlapArea / smallerArea >= 0.25
            }
            if !isDuplicate {
                uniqueResults.append(result)
            }
        }
        return uniqueResults
    }
}
