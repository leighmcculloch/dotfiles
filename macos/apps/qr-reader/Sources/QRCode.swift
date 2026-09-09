import Foundation

struct QRCode: Equatable {
    let value: String

    init(value: String) {
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
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
