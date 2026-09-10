import CoreGraphics
import Foundation

struct QRCode: Equatable {
    let value: String
    /// Normalized Vision/Core Image bounds, with the origin at the image's
    /// lower-left corner. Plainly constructed values do not have bounds.
    let bounds: CGRect?

    init(value: String, bounds: CGRect? = nil) {
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bounds = bounds
    }

    var url: URL? {
        // Wi-Fi QR payloads begin with "WIFI:" but are not links to open.
        guard !value.isEmpty,
              let url = URL(string: value),
              let scheme = url.scheme,
              !scheme.isEmpty,
              scheme.lowercased() != "wifi"
        else {
            return nil
        }
        return url
    }
}
