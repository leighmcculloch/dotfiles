import XCTest
@testable import Stopwatch

final class StopwatchTests: XCTestCase {
    func testClicksStartResetAndStartFresh() {
        let start = ContinuousClock.now
        var stopwatch = Stopwatch()
        XCTAssertFalse(stopwatch.isRunning)
        XCTAssertEqual(stopwatch.title(at: start), "0:00")

        stopwatch.click(at: start)
        XCTAssertTrue(stopwatch.isRunning)
        XCTAssertEqual(stopwatch.title(at: start.advanced(by: .seconds(17))), "0:17")

        stopwatch.click(at: start.advanced(by: .seconds(17)))
        XCTAssertFalse(stopwatch.isRunning)
        XCTAssertEqual(stopwatch.title(at: start.advanced(by: .seconds(42))), "0:00")

        stopwatch.click(at: start.advanced(by: .seconds(42)))
        XCTAssertTrue(stopwatch.isRunning)
        XCTAssertEqual(stopwatch.title(at: start.advanced(by: .seconds(42))), "0:00")
        XCTAssertEqual(stopwatch.title(at: start.advanced(by: .seconds(65))), "0:23")
    }

    func testDisplayUsesElapsedTimeAndWholeSeconds() {
        let start = ContinuousClock.now
        var stopwatch = Stopwatch()
        stopwatch.click(at: start)

        let cases: [(Duration, String)] = [
            (.milliseconds(999), "0:00"),
            (.seconds(1), "0:01"),
            (.milliseconds(59_999), "0:59"),
            (.seconds(60), "1:00"),
            (.seconds(125), "2:05"),
            (.milliseconds(3_599_999), "59:59"),
            (.seconds(3600), "1:00:00"),
            (.seconds(7384), "2:03:04"),
            (.seconds(90_061), "25:01:01")
        ]
        for (elapsed, expected) in cases {
            XCTAssertEqual(stopwatch.title(at: start.advanced(by: elapsed)), expected)
        }
    }

    func testImmediateSecondClickStillResets() {
        let start = ContinuousClock.now
        var stopwatch = Stopwatch()
        stopwatch.click(at: start)
        stopwatch.click(at: start)

        XCTAssertFalse(stopwatch.isRunning)
        XCTAssertEqual(stopwatch.title(at: start.advanced(by: .seconds(10))), "0:00")
    }
}
