import Foundation

/// Converts a GitHub pull request, issue, or discussion link into a rich-text
/// clipboard entry.
///
/// This mirrors the behaviour of the reference shell script: it asks the
/// GitHub CLI for the resource's title, number, and repository, adding
/// additions and deletions for pull requests, then formats a single line of
/// Markdown:
///
///     :github-rainbow: <title> [<repo>#<number>](<url>) `+<additions> -<deletions>`
///
/// The result includes the Markdown representation and an equivalent HTML
/// fragment (what `pandoc -f markdown -t html` would produce) for rich text.
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
        let link = try parseGitHubLink(prLink)

        switch link.kind {
        case .pullRequest:
            return try convertPullRequest(link)
        case .issue, .discussion:
            return try convertIssueOrDiscussion(link)
        }
    }

    private static func convertPullRequest(_ link: GitHubLink) throws -> Result {
        let json = try runGH([
            "pr", "view", link.url,
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

    private static func convertIssueOrDiscussion(_ link: GitHubLink) throws -> Result {
        let command = link.kind == .issue ? "issue" : "discussion"
        let json = try runGH([
            command, "view", link.url,
            "--json", "title,number",
        ])

        guard let item = try? JSONDecoder().decode(IssueOrDiscussion.self, from: json) else {
            throw ConversionError.parseFailed
        }

        let markdown =
            ":github-rainbow: \(item.title) " +
            "[\(link.repository)#\(item.number)](\(link.url))"

        let html =
            "<p>:github-rainbow: \(escapeHTML(item.title)) " +
            "<a href=\"\(escapeHTML(link.url))\">" +
            "\(escapeHTML(link.repository))#\(item.number)</a></p>"

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

    private static func parseGitHubLink(_ input: String) throws -> GitHubLink {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = trimmedInput.contains("://")
            ? trimmedInput
            : "https://\(trimmedInput)"

        guard let components = URLComponents(string: urlString),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased(),
              host == "github.com" || host == "www.github.com"
        else {
            throw ConversionError.parseFailed
        }

        let pathParts = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard pathParts.count >= 4,
              let number = Int(pathParts[3]),
              number > 0
        else {
            throw ConversionError.parseFailed
        }

        let kind: GitHubLink.Kind
        switch pathParts[2].lowercased() {
        case "pull":
            kind = .pullRequest
        case "issues":
            kind = .issue
        case "discussions":
            kind = .discussion
        default:
            throw ConversionError.parseFailed
        }

        let owner = pathParts[0]
        let repository = pathParts[1]
        let resourcePath = kind == .pullRequest ? "pull" : kind == .issue ? "issues" : "discussions"
        let canonicalURL = "https://github.com/\(owner)/\(repository)/\(resourcePath)/\(number)"

        return GitHubLink(
            kind: kind,
            repository: repository,
            url: canonicalURL
        )
    }

    private static func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }
}

private struct GitHubLink {
    enum Kind: Equatable {
        case pullRequest
        case issue
        case discussion
    }

    let kind: Kind
    let repository: String
    let url: String
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

private struct IssueOrDiscussion: Decodable {
    let title: String
    let number: Int
}
