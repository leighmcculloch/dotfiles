import Foundation

/// Converts whitespace-separated GitHub pull request, stack, issue, or discussion
/// links into a rich-text clipboard entry.
///
/// This mirrors the behaviour of the reference shell script: it asks the
/// GitHub CLI for the resource's title, number, and repository, then counts
/// additions and deletions in filtered pull request diffs before formatting a
/// summary of Markdown. Stacks include a header and one bullet per pull request,
/// in stack order. If GitHub cannot provide the filtered diff, the
/// pull request's basic additions and deletions counts are used instead. The
/// Slack emoji names are configurable in the app
/// and default to:
///
///     Pull requests: :github-rainbow: <title> [<repo>#<number>](<url>) `+<additions> -<deletions>`
///     Stacks: :github-rainbow: Stack of N changes [<repo>#<number>](<url>):
///     Pull requests in stacks: - :one: <title> [<repo>#<number>](<url>) `+<additions> -<deletions>`
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
        let links = try parseGitHubLinks(prLink)
        let results = try links.map { link in
            switch link.kind {
            case .pullRequest:
                let result = try convertPullRequest(link, ghRunner: ghRunner, emoji: emojiSettings.pullRequestEmoji)
                return Result(markdown: result.markdown, html: "<p>\(result.html)</p>")
            case .stack:
                return try convertStack(link, ghRunner: ghRunner, emojiSettings: emojiSettings)
            case .issue, .discussion:
                return try convertIssueOrDiscussion(link, ghRunner: ghRunner, emojiSettings: emojiSettings)
            }
        }

        return Result(
            markdown: results.map(\.markdown).joined(separator: "\n"),
            html: results.map(\.html).joined(separator: "\n")
        )
    }

    static func isSupportedGitHubLink(_ input: String) -> Bool {
        (try? parseGitHubLinks(input)) != nil
    }

    private static func convertPullRequest(
        _ link: GitHubLink,
        ghRunner: GHRunner?,
        emoji: String
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
        let escapedEmoji = escapeHTML(emoji)

        let markdown =
            "\(emoji) \(pr.title) " +
            "[\(repo)#\(pr.number)](\(url)) " +
            "`+\(counts.additions) -\(counts.deletions)`"

        let html =
            "\(escapedEmoji) \(escapeHTML(pr.title)) " +
            "<a href=\"\(escapeHTML(url))\">\(escapeHTML(repo))#\(pr.number)</a> " +
            "<code>+\(counts.additions) -\(counts.deletions)</code>"

        return Result(markdown: markdown, html: html)
    }

    private static func convertStack(
        _ link: GitHubLink,
        ghRunner: GHRunner?,
        emojiSettings: SlackEmojiSettings
    ) throws -> Result {
        let json = try fetch([
            "api", "repos/\(link.owner)/\(link.repository)/stacks/\(link.number)",
        ], with: ghRunner)
        let stack = try JSONDecoder().decode(PullRequestStack.self, from: json)
        let pullRequests = try stack.pullRequests.enumerated().map { index, entry in
            try convertPullRequest(
                GitHubLink(kind: .pullRequest, owner: link.owner, repository: link.repository, number: entry.number),
                ghRunner: ghRunner,
                emoji: emojiSettings.stackPullRequestEmoji(at: index)
            )
        }

        let header = "\(emojiSettings.pullRequestEmoji) Stack of \(pullRequests.count) changes"
        let markdown = "\(header) [\(link.repository)#\(link.number)](\(link.url)):" +
            "\n" + pullRequests.map { "- \($0.markdown)" }.joined(separator: "\n")
        let html = "<p>\(escapeHTML(header)) " +
            "<a href=\"\(escapeHTML(link.url))\">\(escapeHTML(link.repository))#\(link.number)</a>:</p>" +
            "<ul>" + pullRequests.map { "<li>\($0.html)</li>" }.joined() + "</ul>"

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

    private static func parseGitHubLinks(_ input: String) throws -> [GitHubLink] {
        let links = input.split(whereSeparator: \.isWhitespace)
        guard !links.isEmpty else {
            throw ConversionError.parseFailed
        }
        return try links.map { try parseGitHubLink(String($0)) }
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
        case "stack":
            kind = .stack
        case "issues":
            kind = .issue
        case "discussions":
            kind = .discussion
        default:
            throw ConversionError.parseFailed
        }

        let owner = pathParts[0]
        let repository = pathParts[1]

        return GitHubLink(
            kind: kind,
            owner: owner,
            repository: repository,
            number: number
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
    static let defaultPullRequest = "github-rainbow"
    static let defaultStackPullRequests = [
        "one", "two", "three", "four", "five",
        "six", "seven", "eight", "nine", "keycap_ten",
    ]
    static let defaultIssue = "github-link-issue"
    static let defaultDiscussion = "github-link-discussion"

    private static let pullRequestDefaultsKey = "SlackEmojiPullRequest"
    private static let stackPullRequestsDefaultsKey = "SlackEmojiStackPullRequests"
    private static let issueDefaultsKey = "SlackEmojiIssue"
    private static let discussionDefaultsKey = "SlackEmojiDiscussion"

    static let standard = Self(
        pullRequest: defaultPullRequest,
        issue: defaultIssue,
        discussion: defaultDiscussion
    )

    let pullRequest: String
    let stackPullRequests: [String]
    let issue: String
    let discussion: String

    init(
        pullRequest: String,
        issue: String,
        discussion: String,
        stackPullRequests: [String] = Self.defaultStackPullRequests
    ) {
        self.pullRequest = Self.normalizedName(pullRequest, fallback: Self.defaultPullRequest)
        self.stackPullRequests = stackPullRequests.map { Self.normalizedName($0, fallback: "") }
        self.issue = Self.normalizedName(issue, fallback: Self.defaultIssue)
        self.discussion = Self.normalizedName(discussion, fallback: Self.defaultDiscussion)
    }

    init(userDefaults: UserDefaults = .standard) {
        self.init(
            pullRequest: userDefaults.string(forKey: Self.pullRequestDefaultsKey) ?? Self.defaultPullRequest,
            issue: userDefaults.string(forKey: Self.issueDefaultsKey) ?? Self.defaultIssue,
            discussion: userDefaults.string(forKey: Self.discussionDefaultsKey) ?? Self.defaultDiscussion,
            stackPullRequests: userDefaults.stringArray(forKey: Self.stackPullRequestsDefaultsKey) ?? Self.defaultStackPullRequests
        )
    }

    func save(to userDefaults: UserDefaults = .standard) {
        userDefaults.set(pullRequest, forKey: Self.pullRequestDefaultsKey)
        userDefaults.set(stackPullRequests, forKey: Self.stackPullRequestsDefaultsKey)
        userDefaults.set(issue, forKey: Self.issueDefaultsKey)
        userDefaults.set(discussion, forKey: Self.discussionDefaultsKey)
    }

    var pullRequestEmoji: String { ":\(pullRequest):" }
    var issueEmoji: String { ":\(issue):" }
    var discussionEmoji: String { ":\(discussion):" }

    func stackPullRequestEmoji(at index: Int) -> String {
        if index < stackPullRequests.count, !stackPullRequests[index].isEmpty {
            return ":\(stackPullRequests[index]):"
        }
        if index < Self.defaultStackPullRequests.count {
            return ":\(Self.defaultStackPullRequests[index]):"
        }
        return "\(index + 1)."
    }

    private static func normalizedName(_ value: String, fallback: String) -> String {
        let name = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? fallback : name
    }
}

private struct GitHubLink {
    enum Kind: String {
        case pullRequest = "pull"
        case stack
        case issue = "issues"
        case discussion = "discussions"
    }

    let kind: Kind
    let owner: String
    let repository: String
    let number: Int

    var url: String { "https://github.com/\(owner)/\(repository)/\(kind.rawValue)/\(number)" }
}

// MARK: - JSON Model

private struct PullRequestStack: Decodable {
    struct Entry: Decodable {
        let number: Int
    }

    let pullRequests: [Entry]

    enum CodingKeys: String, CodingKey {
        case pullRequests = "pull_requests"
    }
}

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
