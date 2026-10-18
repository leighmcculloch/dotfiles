import Foundation
import XCTest
import VideoCompression

final class CompressionTests: XCTestCase {
    private var directory: URL!
    private let files = FileManager.default

    override func setUpWithError() throws {
        directory = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try files.removeItem(at: directory)
    }

    func testBlogRecipesAndQualityChoices() {
        XCTAssertEqual(CompressionOptions().encodingArguments, [
            "-c:v", "libx265", "-crf", "28", "-tag:v", "hvc1", "-c:a", "aac", "-b:a", "128k",
        ])
        XCTAssertEqual(CompressionOptions(codec: .h264).encodingArguments, [
            "-c:v", "libx264", "-crf", "20", "-c:a", "aac", "-b:a", "128k",
        ])
        XCTAssertEqual(CompressionOptions(codec: .hevc, quality: .higher).crf, 24)
        XCTAssertEqual(CompressionOptions(codec: .hevc, quality: .smaller).crf, 32)
        XCTAssertEqual(CompressionOptions(codec: .h264, quality: .higher).crf, 16)
        XCTAssertEqual(CompressionOptions(codec: .h264, quality: .smaller).crf, 24)
    }

    func testRealEncodingPreservesOriginalAndExistingOutputs() throws {
        let (ffmpeg, probe) = try tools()
        let input = try fixture(ffmpeg, name: "Family's trip 日本 $(echo unsafe).mp4", audio: true)
        let original = try Data(contentsOf: input)
        let stem = input.deletingPathExtension().lastPathComponent
        let existing = directory.appendingPathComponent("\(stem)-compressed.mp4")
        let sentinel = Data("Keep the previous output".utf8)
        try sentinel.write(to: existing)

        for (index, codec) in [VideoCodec.hevc, .h264].enumerated() {
            let result = try VideoCompressor().compress(input: input, options: .init(codec: codec), ffmpeg: ffmpeg)
            XCTAssertEqual(result.output, directory.appendingPathComponent("\(stem)-compressed-\(index + 2).mp4"))
            XCTAssertEqual(try Data(contentsOf: input), original)
            XCTAssertEqual(try Data(contentsOf: existing), sentinel)
            XCTAssertEqual(result.originalBytes, Int64(original.count))
            XCTAssertEqual(result.compressedBytes, Int64(try Data(contentsOf: result.output).count))
            XCTAssertLessThan(result.compressedBytes, result.originalBytes)
            let streams = try inspect(probe, result.output)
            let video = try XCTUnwrap(streams.first { $0["codec_type"] as? String == "video" })
            XCTAssertEqual(video["codec_name"] as? String, codec == .hevc ? "hevc" : "h264")
            XCTAssertEqual(video["width"] as? Int, 320)
            XCTAssertEqual(video["height"] as? Int, 180)
            XCTAssertEqual(video["r_frame_rate"] as? String, "24/1")
            XCTAssertEqual(video["codec_tag_string"] as? String, codec == .hevc ? "hvc1" : "avc1")
            XCTAssertEqual(streams.first { $0["codec_type"] as? String == "audio" }?["codec_name"] as? String, "aac")
            _ = try run(ffmpeg, ["-v", "error", "-i", result.output.path, "-f", "null", "-"])
            print("\(codec): \(result.originalBytes) → \(result.compressedBytes) bytes; decoded successfully")
        }
        XCTAssertFalse(try files.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix(".video-compressor-") })
    }

    func testSilentVideoAndSmallerQuality() throws {
        let (ffmpeg, probe) = try tools()
        let input = try fixture(ffmpeg, name: "Silent.MOV", audio: false)
        let higher = try VideoCompressor().compress(input: input, options: .init(codec: .h264, quality: .higher), ffmpeg: ffmpeg)
        let smaller = try VideoCompressor().compress(input: input, options: .init(codec: .h264, quality: .smaller), ffmpeg: ffmpeg)
        XCTAssertLessThan(smaller.compressedBytes, higher.compressedBytes)
        XCTAssertEqual(smaller.output.pathExtension, "mp4")
        let streams = try inspect(probe, smaller.output)
        XCTAssertEqual(streams.count, 1)
        XCTAssertEqual(streams.first?["codec_name"] as? String, "h264")
        _ = try run(ffmpeg, ["-v", "error", "-i", smaller.output.path, "-f", "null", "-"])
    }

    func testErrorsLeaveNoOutputAndPreserveInput() throws {
        let input = directory.appendingPathComponent("broken.mp4")
        let original = Data("Not a video".utf8)
        try original.write(to: input)
        XCTAssertThrowsError(try VideoCompressor().compress(input: input, ffmpeg: nil)) {
            guard case CompressionError.missingFFmpeg = $0 else { return XCTFail("Unexpected error: \($0)") }
        }
        XCTAssertThrowsError(try VideoCompressor().compress(input: directory)) {
            guard case CompressionError.invalidInput = $0 else { return XCTFail("Unexpected error: \($0)") }
        }
        let (ffmpeg, _) = try tools()
        XCTAssertThrowsError(try VideoCompressor().compress(input: input, ffmpeg: ffmpeg)) {
            guard case CompressionError.encodingFailed = $0 else { return XCTFail("Unexpected error: \($0)") }
        }
        XCTAssertEqual(try Data(contentsOf: input), original)
        XCTAssertEqual(try files.contentsOfDirectory(atPath: directory.path), ["broken.mp4"])
    }

    func testCancellationRemovesPartialOutput() throws {
        let (ffmpeg, _) = try tools()
        let input = try fixture(ffmpeg, name: "long.mp4", audio: false, duration: 30)
        let original = try Data(contentsOf: input)
        let worker = VideoCompressor()
        let finished = expectation(description: "cancelled encoding exits")
        DispatchQueue.global().async {
            defer { finished.fulfill() }
            do {
                _ = try worker.compress(input: input, ffmpeg: ffmpeg)
                XCTFail("Cancelled compression unexpectedly succeeded")
            } catch {
                guard case CompressionError.cancelled = error else { return XCTFail("Unexpected error: \(error)") }
            }
        }
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if try files.contentsOfDirectory(atPath: directory.path).contains(where: { $0.hasPrefix(".video-compressor-") }) {
                break
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertTrue(try files.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix(".video-compressor-") })
        worker.cancel()
        wait(for: [finished], timeout: 15)
        XCTAssertEqual(try Data(contentsOf: input), original)
        XCTAssertEqual(try files.contentsOfDirectory(atPath: directory.path), ["long.mp4"])

        let cancelledBeforeLaunch = VideoCompressor()
        cancelledBeforeLaunch.cancel()
        XCTAssertThrowsError(try cancelledBeforeLaunch.compress(input: input, ffmpeg: ffmpeg)) {
            guard case CompressionError.cancelled = $0 else { return XCTFail("Unexpected error: \($0)") }
        }
    }

    private func tools() throws -> (URL, URL) {
        guard let ffmpeg = VideoCompressor.findFFmpeg() else { throw XCTSkip("FFmpeg is not installed") }
        let probe = ffmpeg.deletingLastPathComponent().appendingPathComponent("ffprobe")
        guard files.isExecutableFile(atPath: probe.path) else { throw XCTSkip("FFprobe is not installed") }
        return (ffmpeg, probe)
    }

    private func fixture(_ ffmpeg: URL, name: String, audio: Bool, duration: Int = 2) throws -> URL {
        let input = directory.appendingPathComponent(name)
        var arguments = ["-v", "error", "-f", "lavfi", "-i", "testsrc2=size=320x180:rate=24"]
        if audio { arguments += ["-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000"] }
        arguments += ["-t", "\(duration)", "-c:v", "libx264", "-preset", "ultrafast", "-crf", "0"]
        if audio { arguments += ["-c:a", "aac"] }
        _ = try run(ffmpeg, arguments + [input.path])
        return input
    }

    private func inspect(_ probe: URL, _ video: URL) throws -> [[String: Any]] {
        let data = try run(probe, ["-v", "error", "-show_streams", "-of", "json", video.path])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(json["streams"] as? [[String: Any]])
    }

    @discardableResult private func run(_ executable: URL, _ arguments: [String]) throws -> Data {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, String(decoding: output, as: UTF8.self))
        return output
    }
}
