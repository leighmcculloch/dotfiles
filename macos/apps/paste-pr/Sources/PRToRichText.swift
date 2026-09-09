import Foundation

/// Converts a GitHub pull request, issue, or discussion link into a rich-text
/// clipboard entry.
///
/// This mirrors the behaviour of the reference shell script: it asks the
/// GitHub CLI for the resource's title, number, and repository, then counts
/// additions and deletions in filtered pull request diffs before formatting a
/// single line of Markdown. If GitHub cannot provide the filtered diff, the
/// pull request's basic additions and deletions counts are used instead. The
/// Slack emoji names are configurable in the app
/// and default to:
///
///     Pull requests: :github-link-pr: <title> [<repo>#<number>](<url>) `+<additions> -<deletions>`
///     Issues: :github-link-issue: <title> [<repo>#<number>](<url>)
///     Discussions: :github-link-discussion: <title> [<repo>#<number>](<url>)
///
/// The result includes the Markdown representation and an equivalent HTML
/// fragment (what `pandoc -f markdown -t html` would produce) for rich text.
enum PRToRichText {
    typealias GHRunner = ([String]) throws -> Data

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

    static func convert(
        prLink: String,
        ghRunner: GHRunner? = nil,
        emojiSettings: SlackEmojiSettings = .standard
    ) throws -> Result {
        let link = try parseGitHubLink(prLink)

        switch link.kind {
        case .pullRequest:
            return try convertPullRequest(link, ghRunner: ghRunner, emojiSettings: emojiSettings)
        case .issue, .discussion:
            return try convertIssueOrDiscussion(link, ghRunner: ghRunner, emojiSettings: emojiSettings)
        }
    }

    static func isSupportedGitHubLink(_ input: String) -> Bool {
        (try? parseGitHubLink(input)) != nil
    }

    private static func convertPullRequest(
        _ link: GitHubLink,
        ghRunner: GHRunner?,
        emojiSettings: SlackEmojiSettings
    ) throws -> Result {
        let json = try fetch([
            "pr", "view", link.url,
            "--json", "title,number,additions,deletions",
        ], with: ghRunner)

        guard let pr = try? JSONDecoder().decode(PullRequest.self, from: json) else {
            throw ConversionError.parseFailed
        }

        let counts: (additions: Int, deletions: Int)
        do {
            let diff = try fetch([
                "pr", "diff", link.url,
                "--exclude", "*.json",
                "--exclude", "*.lock",
                "--exclude", "tests-expanded/*",
            ], with: ghRunner)
            guard let diff = String(data: diff, encoding: .utf8) else {
                throw ConversionError.parseFailed
            }
            counts = countDiffLines(in: diff)
        } catch {
            // GitHub rejects diffs that exceed its size limits. The metadata
            // counts are less precise because they include excluded files,
            // but they let large PRs remain pasteable.
            counts = (pr.additions, pr.deletions)
        }

        let repo = link.repository
        let url = link.url
        let emoji = emojiSettings.pullRequestEmoji
        let escapedEmoji = escapeHTML(emoji)

        let markdown =
            "\(emoji) \(pr.title) " +
            "[\(repo)#\(pr.number)](\(url)) " +
            "`+\(counts.additions) -\(counts.deletions)`"

        let html =
            "<p>\(escapedEmoji) \(escapeHTML(pr.title)) " +
            "<a href=\"\(escapeHTML(url))\">\(escapeHTML(repo))#\(pr.number)</a> " +
            "<code>+\(counts.additions) -\(counts.deletions)</code></p>"

        return Result(markdown: markdown, html: html)
    }

    private static func convertIssueOrDiscussion(
        _ link: GitHubLink,
        ghRunner: GHRunner?,
        emojiSettings: SlackEmojiSettings
    ) throws -> Result {
        let command = link.kind == .issue ? "issue" : "discussion"
        let json = try fetch([
            command, "view", link.url,
            "--json", "title,number",
        ], with: ghRunner)

        guard let item = try? JSONDecoder().decode(IssueOrDiscussion.self, from: json) else {
            throw ConversionError.parseFailed
        }

        let emoji = link.kind == .issue
            ? emojiSettings.issueEmoji
            : emojiSettings.discussionEmoji
        let escapedEmoji = escapeHTML(emoji)
        let markdown =
            "\(emoji) \(item.title) " +
            "[\(link.repository)#\(item.number)](\(link.url))"

        let html =
            "<p>\(escapedEmoji) \(escapeHTML(item.title)) " +
            "<a href=\"\(escapeHTML(link.url))\">" +
            "\(escapeHTML(link.repository))#\(item.number)</a></p>"

        return Result(markdown: markdown, html: html)
    }

    // MARK: - GitHub CLI

    private static func fetch(_ arguments: [String], with ghRunner: GHRunner?) throws -> Data {
        if let ghRunner {
            return try ghRunner(arguments)
        }
        return try runGH(arguments)
    }

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

    private static func countDiffLines(in diff: String) -> (additions: Int, deletions: Int) {
        var additions = 0
        var deletions = 0
        var inHunk = false
        var excludedFile = false
        var oldPath: String?

        for line in diff.split(whereSeparator: { $0.isNewline }) {
            if line.hasPrefix("diff --git ") {
                inHunk = false
                excludedFile = false
                oldPath = nil
                continue
            }

            if !inHunk {
                if line.hasPrefix("--- ") {
                    oldPath = String(line.dropFirst(4))
                } else if line.hasPrefix("+++ ") {
                    let newPath = String(line.dropFirst(4))
                    let path = newPath == "/dev/null" ? oldPath : newPath
                    excludedFile = path.map(isExcludedDiffPath) ?? false
                }
                if line.hasPrefix("@@") {
                    inHunk = true
                }
                continue
            }

            if excludedFile {
                continue
            }

            switch line.first {
            case "+":
                additions += 1
            case "-":
                deletions += 1
            default:
                continue
            }
        }

        return (additions, deletions)
    }

    private static func isExcludedDiffPath(_ headerPath: String) -> Bool {
        let path = headerPath
            .split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? headerPath
        let unprefixedPath = path
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .dropFirst(path.hasPrefix("a/") || path.hasPrefix("b/") ? 2 : 0)

        return unprefixedPath.hasSuffix(".json") ||
            unprefixedPath.hasSuffix(".lock") ||
            unprefixedPath == "tests-expanded" ||
            unprefixedPath.hasPrefix("tests-expanded/") ||
            unprefixedPath.contains("/tests-expanded/")
    }

    private static func parseGitHubLink(_ input: String) throws -> GitHubLink {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString: String
        if let components = URLComponents(string: trimmedInput),
           components.scheme != nil {
            urlString = trimmedInput
        } else {
            urlString = "https://\(trimmedInput)"
        }

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

struct SlackEmojiSettings: Equatable {
    static let defaultPullRequest = "github-link-pr"
    static let defaultIssue = "github-link-issue"
    static let defaultDiscussion = "github-link-discussion"

    private static let pullRequestDefaultsKey = "SlackEmojiPullRequest"
    private static let issueDefaultsKey = "SlackEmojiIssue"
    private static let discussionDefaultsKey = "SlackEmojiDiscussion"

    static let standard = Self(
        pullRequest: defaultPullRequest,
        issue: defaultIssue,
        discussion: defaultDiscussion
    )

    let pullRequest: String
    let issue: String
    let discussion: String

    init(pullRequest: String, issue: String, discussion: String) {
        self.pullRequest = Self.normalizedName(pullRequest, fallback: Self.defaultPullRequest)
        self.issue = Self.normalizedName(issue, fallback: Self.defaultIssue)
        self.discussion = Self.normalizedName(discussion, fallback: Self.defaultDiscussion)
    }

    init(userDefaults: UserDefaults = .standard) {
        self.init(
            pullRequest: userDefaults.string(forKey: Self.pullRequestDefaultsKey) ?? Self.defaultPullRequest,
            issue: userDefaults.string(forKey: Self.issueDefaultsKey) ?? Self.defaultIssue,
            discussion: userDefaults.string(forKey: Self.discussionDefaultsKey) ?? Self.defaultDiscussion
        )
    }

    func save(to userDefaults: UserDefaults = .standard) {
        userDefaults.set(pullRequest, forKey: Self.pullRequestDefaultsKey)
        userDefaults.set(issue, forKey: Self.issueDefaultsKey)
        userDefaults.set(discussion, forKey: Self.discussionDefaultsKey)
    }

    var pullRequestEmoji: String { ":\(pullRequest):" }
    var issueEmoji: String { ":\(issue):" }
    var discussionEmoji: String { ":\(discussion):" }

    private static func normalizedName(_ value: String, fallback: String) -> String {
        let name = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? fallback : name
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
}

private struct IssueOrDiscussion: Decodable {
    let title: String
    let number: Int
}
