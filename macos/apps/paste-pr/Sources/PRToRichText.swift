import Foundation

/// Converts a GitHub pull request link into a rich-text clipboard entry.
///
/// This mirrors the behaviour of the reference shell script: it asks the
/// GitHub CLI (`gh pr view`) for the PR's title, number, additions, deletions
/// and repository, then formats a single line of Markdown:
///
///     :github-rainbow: <title> [<repo>#<number>](<url>) `+<additions> -<deletions>`
///
/// The Markdown is used as the plain-text representation, and an equivalent
/// HTML fragment (what `pandoc -f markdown -t html` would produce) is used as
/// the rich-text representation.
enum PRToRichText {
    struct Result {
        let markdown: String
        let html: String
    }

    enum ConversionError: Error {
        case ghNotFound
        case ghFailed(String)
        case parseFailed
    }

    // MARK: - Conversion

    static func convert(prLink: String) throws -> Result {
        let json = try runGH([
            "pr", "view", prLink,
            "--json", "title,number,additions,deletions,headRepository,headRepositoryOwner",
        ])

        guard let pr = try? JSONDecoder().decode(PullRequest.self, from: json) else {
            throw ConversionError.parseFailed
        }

        let repo = pr.headRepository.name
        let owner = pr.headRepositoryOwner.login
        let url = "https://github.com/\(owner)/\(repo)/pull/\(pr.number)"

        let markdown =
            ":github-rainbow: \(pr.title) " +
            "[\(repo)#\(pr.number)](\(url)) " +
            "`+\(pr.additions) -\(pr.deletions)`"

        let html =
            "<p>:github-rainbow: \(escapeHTML(pr.title)) " +
            "<a href=\"\(escapeHTML(url))\">\(escapeHTML(repo))#\(pr.number)</a> " +
            "<code>+\(pr.additions) -\(pr.deletions)</code></p>"

        return Result(markdown: markdown, html: html)
    }

    // MARK: - GitHub CLI

    private static func runGH(_ arguments: [String]) throws -> Data {
        guard let ghPath = locateGH() else {
            throw ConversionError.ghNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ConversionError.ghFailed("\(error)")
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errData, encoding: .utf8) ?? "gh exited with status \(process.terminationStatus)"
            throw ConversionError.ghFailed(message)
        }

        return data
    }

    /// A GUI app launched from /Applications does not inherit the user's shell
    /// PATH, so look for `gh` in the common install locations.
    private static func locateGH() -> String? {
        let candidates = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
        ]
        let fm = FileManager.default
        if let found = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) {
            return found
        }
        // Fall back to any PATH the process happens to have inherited.
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let candidate = "\(dir)/gh"
                if fm.isExecutableFile(atPath: candidate) { return candidate }
            }
        }
        return nil
    }

    // MARK: - Helpers

    private static func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }
}

// MARK: - JSON Model

private struct PullRequest: Decodable {
    let title: String
    let number: Int
    let additions: Int
    let deletions: Int
    let headRepository: Repository
    let headRepositoryOwner: Owner

    struct Repository: Decodable {
        let name: String
    }

    struct Owner: Decodable {
        let login: String
    }
}
