import Foundation
import XCTest
@testable import QRReader

final class QRCodeTests: XCTestCase {
    func testTrimsPayloadForDisplayAndCopy() {
        XCTAssertEqual(QRCode(value: "  https://example.com  ").value, "https://example.com")
    }

    func testRecognizesURLsForOpenAction() {
        XCTAssertEqual(QRCode(value: "https://example.com/path").url, URL(string: "https://example.com/path"))
        XCTAssertEqual(QRCode(value: "mailto:hello@example.com").url, URL(string: "mailto:hello@example.com"))
    }

    func testLeavesNonURLPayloadWithoutOpenAction() {
        XCTAssertNil(QRCode(value: "WIFI:T:WPA;S:network;P:password;;").url)
        XCTAssertNil(QRCode(value: "plain text").url)
    }
}
