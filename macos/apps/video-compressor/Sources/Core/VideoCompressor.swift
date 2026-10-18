import Foundation

public enum VideoCodec: Int, CaseIterable {
    case hevc, h264

    public var title: String {
        switch self {
        case .hevc: return "H.265 — Smaller files (Apple devices)"
        case .h264: return "H.264 — Wider compatibility (web & sharing)"
        }
    }
}

public enum VideoQuality: Int, CaseIterable {
    case higher, balanced, smaller

    public var title: String {
        switch self {
        case .higher: return "Higher quality · larger file"
        case .balanced: return "Balanced · blog default"
        case .smaller: return "Smaller file · lower quality"
        }
    }
}

public struct CompressionOptions {
    public var codec: VideoCodec
    public var quality: VideoQuality

    public init(codec: VideoCodec = .hevc, quality: VideoQuality = .balanced) {
        self.codec = codec
        self.quality = quality
    }

    public var crf: Int {
        let base = codec == .hevc ? 28 : 20
        switch quality {
        case .higher: return base - 4
        case .balanced: return base
        case .smaller: return base + 4
        }
    }

    public var encodingArguments: [String] {
        var arguments = ["-c:v", codec == .hevc ? "libx265" : "libx264", "-crf", "\(crf)"]
        if codec == .hevc { arguments += ["-tag:v", "hvc1"] }
        return arguments + ["-c:a", "aac", "-b:a", "128k"]
    }
}

public struct CompressionResult {
    public let output: URL
    public let originalBytes: Int64
    public let compressedBytes: Int64
}

public enum CompressionError: LocalizedError {
    case missingFFmpeg, invalidInput, cancelled, encodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingFFmpeg:
            return "FFmpeg was not found. Install it with brew install ffmpeg, then try again."
        case .invalidInput:
            return "Choose a readable video file, not a folder."
        case .cancelled:
            return "Compression cancelled. The original video is unchanged."
        case .encodingFailed(let message):
            return "FFmpeg could not compress this video.\n\(message)"
        }
    }
}

// One instance per compression. Call compress on a background queue; cancel is thread-safe.
public final class VideoCompressor {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    public init() {}

    public static func findFFmpeg() -> URL? {
        // Finder-launched applications don't inherit the interactive shell's PATH.
        let paths = ["/opt/homebrew/bin", "/usr/local/bin"]
            + (ProcessInfo.processInfo.environment["PATH"] ?? "").components(separatedBy: ":")
        return paths.filter { !$0.isEmpty }.map {
            URL(fileURLWithPath: $0).appendingPathComponent("ffmpeg")
        }.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    public func cancel() {
        lock.lock()
        defer { lock.unlock() }
        cancelled = true
        if let process, process.isRunning { process.terminate() }
    }

    public func compress(
        input: URL,
        options: CompressionOptions = CompressionOptions(),
        ffmpeg: URL? = VideoCompressor.findFFmpeg()
    ) throws -> CompressionResult {
        let files = FileManager.default
        guard input.isFileURL,
              (try? input.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
              files.isReadableFile(atPath: input.path)
        else { throw CompressionError.invalidInput }
        guard let ffmpeg else { throw CompressionError.missingFFmpeg }

        let originalBytes = try byteCount(input)
        let directory = input.deletingLastPathComponent()
        let temporary = directory.appendingPathComponent(".video-compressor-\(UUID().uuidString).mp4")
        defer { try? files.removeItem(at: temporary) }

        let task = Process()
        let errors = Pipe()
        task.executableURL = ffmpeg
        task.arguments = ["-hide_banner", "-loglevel", "error", "-nostdin", "-n", "-i", input.path]
            + options.encodingArguments + [temporary.path]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = errors

        // Serialize launch with cancellation so a cancellation just before launch is not lost.
        lock.lock()
        if cancelled {
            lock.unlock()
            throw CompressionError.cancelled
        }
        do {
            try task.run()
            process = task
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        lock.lock()
        process = nil
        defer { lock.unlock() }
        if cancelled { throw CompressionError.cancelled }
        guard task.terminationStatus == 0 else {
            throw CompressionError.encodingFailed(String(decoding: errorData.suffix(8_000), as: UTF8.self))
        }

        let compressedBytes = try byteCount(temporary)
        // Publish only complete files. FileManager refuses to move onto an existing
        // destination, so retry with a numbered name instead of replacing it.
        let stem = input.deletingPathExtension().lastPathComponent
        var number = 1
        while true {
            let suffix = number == 1 ? "" : "-\(number)"
            let output = directory.appendingPathComponent("\(stem)-compressed\(suffix).mp4")
            do {
                try files.moveItem(at: temporary, to: output)
                return CompressionResult(
                    output: output, originalBytes: originalBytes, compressedBytes: compressedBytes
                )
            } catch {
                guard files.fileExists(atPath: output.path) else { throw error }
                number += 1
            }
        }
    }

    private func byteCount(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}
