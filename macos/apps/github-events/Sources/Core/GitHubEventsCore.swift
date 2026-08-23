import Combine
import Foundation

private enum GitHubEventsLimits {
    static let minimumPollInterval: TimeInterval = 60
    static let historicalRequestInterval: TimeInterval = 1
    static let unauthenticatedPollInterval: TimeInterval = 5 * 60
    static let unauthenticatedHourlyBudget: TimeInterval = 36
    static let unauthenticatedHistoricalHourlyBudget: TimeInterval = 12
    static let authenticatedHourlyBudget: TimeInterval = 3_000
    static let authenticatedHistoricalHourlyBudget: TimeInterval = 1_000
    static let cachedPollIntervalLifetime: TimeInterval = 24 * 60 * 60
    static let maximumSleepChunk: TimeInterval = TimeInterval(UInt64.max / 1_000_000_000) - 1
}

enum GitHubCredentialProvider {
    static func token(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        if let token = nonEmptyValue(environment["GITHUB_TOKEN"]) {
            return token
        }

        guard let ghPath = executablePath(named: "gh", environment: environment) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["auth", "token", "--hostname", "github.com"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        return nonEmptyValue(String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8))
    }

    private static func nonEmptyValue(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func executablePath(named name: String, environment: [String: String]) -> String? {
        let pathEntries = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        let candidates = pathEntries.map { "\($0)/\(name)" } + [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(Double(value))
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var intValue: Int? {
        switch self {
        case let .number(value): return Int(value)
        case let .string(value): return Int(value)
        default: return nil
        }
    }

    var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    var arrayValue: [JSONValue]? {
        guard case let .array(value) = self else { return nil }
        return value
    }
}

struct GitHubActor: Codable, Equatable {
    let login: String
    let displayLogin: String
    let avatarURL: URL?

    private enum CodingKeys: String, CodingKey {
        case login
        case displayLogin = "display_login"
        case avatarURL = "avatar_url"
    }

    init(login: String, displayLogin: String? = nil, avatarURL: URL? = nil) {
        self.login = login
        self.displayLogin = displayLogin ?? login
        self.avatarURL = avatarURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        login = try container.decodeIfPresent(String.self, forKey: .login) ?? "unknown"
        displayLogin = try container.decodeIfPresent(String.self, forKey: .displayLogin) ?? login
        avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
    }
}

struct GitHubRepository: Codable, Equatable {
    let name: String
    let url: URL?

    init(name: String, url: URL? = nil) {
        self.name = name
        self.url = url
    }
}

struct GitHubEvent: Codable, Equatable, Identifiable, @unchecked Sendable {
    let id: String
    let type: String
    let actor: GitHubActor
    let repo: GitHubRepository
    let payload: [String: JSONValue]
    let isPublic: Bool
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case actor
        case repo
        case payload
        case isPublic = "public"
        case createdAt = "created_at"
    }

    init(
        id: String,
        type: String,
        actor: GitHubActor,
        repo: GitHubRepository,
        payload: [String: JSONValue] = [:],
        isPublic: Bool = true,
        createdAt: Date
    ) {
        self.id = id
        self.type = type
        self.actor = actor
        self.repo = repo
        self.payload = payload
        self.isPublic = isPublic
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        actor = try container.decodeIfPresent(GitHubActor.self, forKey: .actor)
            ?? GitHubActor(login: "unknown")
        repo = try container.decodeIfPresent(GitHubRepository.self, forKey: .repo)
            ?? GitHubRepository(name: "unknown/unknown")
        payload = try container.decodeIfPresent([String: JSONValue].self, forKey: .payload) ?? [:]
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true

        let dateString = try container.decode(String.self, forKey: .createdAt)
        guard let date = GitHubDateCoding.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .createdAt,
                in: container,
                debugDescription: "Invalid GitHub event date"
            )
        }
        createdAt = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(actor, forKey: .actor)
        try container.encode(repo, forKey: .repo)
        try container.encode(payload, forKey: .payload)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encode(GitHubDateCoding.string(from: createdAt), forKey: .createdAt)
    }
}

private enum GitHubDateCoding {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withFractionalSeconds
        ]
        return formatter
    }()

    static func date(from string: String) -> Date? {
        fractionalFormatter.date(from: string) ?? formatter.date(from: string)
    }

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}

struct EventPresentation: Equatable {
    let title: String
    let summary: String
    let markdownBody: String?
    let url: URL?
}

extension GitHubEvent {
    var presentation: EventPresentation {
        let actor = actor.displayLogin
        let repository = repo.name
        let repositoryURL = URL(string: "https://github.com/\(repository)") ?? repo.url

        switch type {
        case "IssueCommentEvent":
            let issue = object("issue")
            let comment = object("comment")
            let number = issue?.int("number").map(String.init) ?? "issue"
            let issueTitle = issue?.string("title") ?? repository
            let action = string("action") ?? "created"
            let verb = action == "created" ? "commented on" : "updated a comment on"
            return EventPresentation(
                title: "\(actor) \(verb) \(repository)#\(number)",
                summary: issueTitle,
                markdownBody: comment?.string("body"),
                url: comment?.url("html_url") ?? issue?.url("html_url") ?? repositoryURL
            )

        case "PullRequestReviewCommentEvent":
            let request = object("pull_request") ?? object("issue")
            let comment = object("comment")
            let number = request?.int("number").map(String.init) ?? "pull request"
            let title = request?.string("title") ?? repository
            let path = comment?.string("path")
            let location = path.map { " · \($0)" } ?? ""
            return EventPresentation(
                title: "\(actor) commented on \(repository)#\(number)",
                summary: "\(title)\(location)",
                markdownBody: comment?.string("body"),
                url: comment?.url("html_url") ?? request?.url("html_url") ?? repositoryURL
            )

        case "CommitCommentEvent":
            let comment = object("comment")
            let commit = string("commit_id").map { String($0.prefix(7)) } ?? "a commit"
            return EventPresentation(
                title: "\(actor) commented on \(repository) \(commit)",
                summary: "Commit comment",
                markdownBody: comment?.string("body"),
                url: comment?.url("html_url") ?? repositoryURL
            )

        case "PullRequestReviewEvent":
            let request = object("pull_request")
            let review = object("review")
            let number = request?.int("number").map(String.init) ?? "pull request"
            let title = request?.string("title") ?? repository
            let state = review?.string("state")?.lowercased() ?? "reviewed"
            return EventPresentation(
                title: "\(actor) \(state) \(repository)#\(number)",
                summary: title,
                markdownBody: review?.string("body"),
                url: review?.url("html_url") ?? request?.url("html_url") ?? repositoryURL
            )

        case "IssuesEvent":
            let issue = object("issue")
            let number = issue?.int("number").map(String.init) ?? "issue"
            let action = string("action") ?? "updated"
            return EventPresentation(
                title: "\(actor) \(action) \(repository)#\(number)",
                summary: issue?.string("title") ?? repository,
                markdownBody: issue?.string("body"),
                url: issue?.url("html_url") ?? repositoryURL
            )

        case "PullRequestEvent":
            let request = object("pull_request")
            let number = request?.int("number").map(String.init) ?? "pull request"
            let action = string("action") ?? "updated"
            return EventPresentation(
                title: "\(actor) \(action) \(repository)#\(number)",
                summary: request?.string("title") ?? repository,
                markdownBody: request?.string("body"),
                url: request?.url("html_url") ?? repositoryURL
            )

        case "PushEvent":
            let branch = string("ref")?.replacingOccurrences(of: "refs/heads/", with: "") ?? "the repository"
            let commits = array("commits")?.compactMap { $0.objectValue?.string("message") }
            let commitCount = commits?.count ?? 0
            let title = commitCount > 0
                ? "\(actor) pushed \(commitCount == 1 ? "1 commit" : "\(commitCount) commits") to \(repository)"
                : "\(actor) pushed to \(repository)"
            return EventPresentation(
                title: title,
                summary: "\(branch)",
                markdownBody: commits.map { $0.map { "- \($0)" }.joined(separator: "\n") },
                url: repositoryURL
            )

        case "WatchEvent":
            let action = string("action") == "started" ? "starred" : (string("action") ?? "updated")
            return EventPresentation(
                title: "\(actor) \(action) \(repository)",
                summary: "Repository activity",
                markdownBody: nil,
                url: repositoryURL
            )

        case "ForkEvent":
            let fork = object("forkee")
            return EventPresentation(
                title: "\(actor) forked \(repository)",
                summary: fork?.string("full_name") ?? fork?.string("name") ?? "New fork",
                markdownBody: nil,
                url: fork?.url("html_url") ?? repositoryURL
            )

        case "CreateEvent":
            let refType = string("ref_type") ?? "resource"
            let ref = string("ref").map { " · \($0)" } ?? ""
            return EventPresentation(
                title: "\(actor) created a \(refType) in \(repository)",
                summary: "\(repository)\(ref)",
                markdownBody: nil,
                url: repositoryURL
            )

        case "DeleteEvent":
            let refType = string("ref_type") ?? "resource"
            let ref = string("ref").map { " · \($0)" } ?? ""
            return EventPresentation(
                title: "\(actor) deleted a \(refType) in \(repository)",
                summary: "\(repository)\(ref)",
                markdownBody: nil,
                url: repositoryURL
            )

        case "ReleaseEvent":
            let release = object("release")
            let action = string("action") ?? "updated"
            let name = release?.string("name") ?? release?.string("tag_name") ?? repository
            return EventPresentation(
                title: "\(actor) \(action) a release in \(repository)",
                summary: name,
                markdownBody: release?.string("body"),
                url: release?.url("html_url") ?? repositoryURL
            )

        case "MemberEvent":
            let member = object("member")?.string("login") ?? "a member"
            let action = string("action") ?? "updated"
            return EventPresentation(
                title: "\(actor) \(action) \(member) in \(repository)",
                summary: "Repository membership",
                markdownBody: nil,
                url: repositoryURL
            )

        case "PublicEvent":
            return EventPresentation(
                title: "\(actor) made \(repository) public",
                summary: "Repository visibility changed",
                markdownBody: nil,
                url: repositoryURL
            )

        case "DiscussionCommentEvent":
            let discussion = object("discussion")
            let comment = object("comment")
            let number = discussion?.int("number").map(String.init) ?? "discussion"
            let title = discussion?.string("title") ?? repository
            return EventPresentation(
                title: "\(actor) commented on \(repository)#\(number)",
                summary: title,
                markdownBody: comment?.string("body"),
                url: comment?.url("html_url") ?? discussion?.url("html_url") ?? repositoryURL
            )

        case "DiscussionEvent":
            let discussion = object("discussion")
            let number = discussion?.int("number").map(String.init) ?? "discussion"
            let action = string("action") ?? "updated"
            return EventPresentation(
                title: "\(actor) \(action) \(repository)#\(number)",
                summary: discussion?.string("title") ?? repository,
                markdownBody: discussion?.string("body"),
                url: discussion?.url("html_url") ?? repositoryURL
            )

        case "PullRequestReviewThreadEvent":
            let request = object("pull_request")
            let comment = object("comment") ?? object("thread")
            let number = request?.int("number").map(String.init) ?? "pull request"
            return EventPresentation(
                title: "\(actor) updated a review thread on \(repository)#\(number)",
                summary: request?.string("title") ?? repository,
                markdownBody: comment?.string("body"),
                url: comment?.url("html_url") ?? request?.url("html_url") ?? repositoryURL
            )

        case "GollumEvent":
            let pages = array("pages")?.compactMap { page -> String? in
                guard let page = page.objectValue else { return nil }
                let action = page.string("action") ?? "updated"
                let title = page.string("title") ?? "a wiki page"
                return "- \(action) \(title)"
            }
            return EventPresentation(
                title: "\(actor) updated the wiki for \(repository)",
                summary: "Wiki activity",
                markdownBody: pages?.isEmpty == false ? pages?.joined(separator: "\n") : nil,
                url: repositoryURL
            )

        case "DeploymentEvent":
            let deployment = object("deployment")
            let environment = deployment?.string("environment") ?? "an environment"
            return EventPresentation(
                title: "\(actor) deployed \(repository) to \(environment)",
                summary: deployment?.string("description") ?? "Deployment",
                markdownBody: nil,
                url: repositoryURL
            )

        case "DeploymentStatusEvent":
            let deployment = object("deployment")
            let status = object("deployment_status")?.string("state") ?? "updated"
            let environment = deployment?.string("environment") ?? "an environment"
            return EventPresentation(
                title: "\(actor) marked the \(environment) deployment \(status)",
                summary: repository,
                markdownBody: nil,
                url: repositoryURL
            )

        case "StatusEvent":
            let state = string("state") ?? "updated"
            let context = string("context") ?? "a status"
            return EventPresentation(
                title: "\(actor) set \(context) to \(state) on \(repository)",
                summary: string("description") ?? "Commit status",
                markdownBody: nil,
                url: repositoryURL
            )

        case "SponsorshipEvent":
            let action = string("action") ?? "updated"
            let plan = object("sponsorship")?["tier"]?.objectValue?.string("name")
                ?? object("sponsorship")?.string("privacy_level")
                ?? "a sponsorship"
            return EventPresentation(
                title: "\(actor) \(action) \(plan)",
                summary: repository,
                markdownBody: nil,
                url: repositoryURL
            )

        default:
            let action = string("action")
            let title = action.map { "\(actor) \($0) in \(repository)" } ?? "\(actor) updated \(repository)"
            return EventPresentation(
                title: title,
                summary: type.replacingOccurrences(of: "Event", with: ""),
                markdownBody: nil,
                url: repositoryURL
            )
        }
    }

    private func string(_ key: String) -> String? {
        payload[key]?.stringValue
    }

    private func object(_ key: String) -> [String: JSONValue]? {
        payload[key]?.objectValue
    }

    private func array(_ key: String) -> [JSONValue]? {
        payload[key]?.arrayValue
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    func int(_ key: String) -> Int? {
        self[key]?.intValue
    }

    func url(_ key: String) -> URL? {
        guard let value = string(key) else { return nil }
        return URL(string: value)
    }
}

enum GitHubUsername {
    static func normalize(_ input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.count <= 39,
              value.range(of: "^[A-Za-z0-9-]+$", options: .regularExpression) != nil
        else {
            return nil
        }
        return value.lowercased()
    }
}

struct CachedUserEvents: Codable, Equatable {
    var username: String
    var events: [GitHubEvent] = []
    var nextPage: Int = 1
    var fetchedPages: Set<Int> = []
    var pageETags: [Int: String] = [:]
    var pageLastModified: [Int: String] = [:]
    var pageCounts: [Int: Int] = [:]
    var seenEventIDs: Set<String> = []
    var exhausted = false
    var pollInterval: TimeInterval = 60
    var pageOnePollInterval: TimeInterval?
    var lastFetchedAt: Date?
    var pageOneFetchedAt: Date?

    init(username: String) {
        self.username = username
    }

    private enum CodingKeys: String, CodingKey {
        case username
        case events
        case nextPage
        case fetchedPages
        case pageETags
        case pageLastModified
        case pageCounts
        case seenEventIDs
        case exhausted
        case pollInterval
        case pageOnePollInterval
        case lastFetchedAt
        case pageOneFetchedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = try container.decode(String.self, forKey: .username)
        events = try container.decodeIfPresent([GitHubEvent].self, forKey: .events) ?? []
        nextPage = try container.decodeIfPresent(Int.self, forKey: .nextPage) ?? 1
        fetchedPages = try container.decodeIfPresent(Set<Int>.self, forKey: .fetchedPages) ?? []
        pageETags = try container.decodeIfPresent([Int: String].self, forKey: .pageETags) ?? [:]
        pageLastModified = try container.decodeIfPresent([Int: String].self, forKey: .pageLastModified) ?? [:]
        pageCounts = try container.decodeIfPresent([Int: Int].self, forKey: .pageCounts) ?? [:]
        seenEventIDs = try container.decodeIfPresent(Set<String>.self, forKey: .seenEventIDs) ?? []
        exhausted = try container.decodeIfPresent(Bool.self, forKey: .exhausted) ?? false
        pollInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .pollInterval) ?? 60
        pageOnePollInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .pageOnePollInterval)
        lastFetchedAt = try container.decodeIfPresent(Date.self, forKey: .lastFetchedAt)
        pageOneFetchedAt = try container.decodeIfPresent(Date.self, forKey: .pageOneFetchedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(username, forKey: .username)
        try container.encode(events, forKey: .events)
        try container.encode(nextPage, forKey: .nextPage)
        try container.encode(fetchedPages, forKey: .fetchedPages)
        try container.encode(pageETags, forKey: .pageETags)
        try container.encode(pageLastModified, forKey: .pageLastModified)
        try container.encode(pageCounts, forKey: .pageCounts)
        try container.encode(seenEventIDs, forKey: .seenEventIDs)
        try container.encode(exhausted, forKey: .exhausted)
        try container.encode(pollInterval, forKey: .pollInterval)
        try container.encodeIfPresent(pageOnePollInterval, forKey: .pageOnePollInterval)
        try container.encodeIfPresent(lastFetchedAt, forKey: .lastFetchedAt)
        try container.encodeIfPresent(pageOneFetchedAt, forKey: .pageOneFetchedAt)
    }

    @discardableResult
    mutating func merge(
        _ newEvents: [GitHubEvent],
        page: Int,
        etag: String?,
        lastModified: String?,
        perPage: Int,
        pollInterval: TimeInterval?
    ) -> [GitHubEvent] {
        var knownIDs = Set(events.map(\.id))
        var insertedEvents: [GitHubEvent] = []
        for event in newEvents where knownIDs.insert(event.id).inserted {
            insertedEvents.append(event)
        }

        let hadPageOne = fetchedPages.contains(1)
        if page == 1, hadPageOne, !insertedEvents.isEmpty {
            // Page numbers move when new events arrive. Keep the event data and
            // validators, but revalidate historical pages before advancing past
            // the new page-one boundary.
            fetchedPages = Set(fetchedPages.filter { $0 == 1 })
            nextPage = 2
            exhausted = false
        }

        var byID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        for event in newEvents {
            byID[event.id] = event
        }
        events = byID.values.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id > $1.id
        }
        fetchedPages.insert(page)
        if page == 1 {
            nextPage = max(nextPage, 2)
        } else {
            nextPage = max(nextPage, page + 1)
        }
        if page == 1 {
            exhausted = newEvents.count < perPage
        } else if newEvents.count < perPage {
            exhausted = true
        }
        pageCounts[page] = newEvents.count
        if let etag { pageETags[page] = etag }
        if let lastModified { pageLastModified[page] = lastModified }
        if let pollInterval {
            let normalizedPollInterval = max(GitHubEventsLimits.minimumPollInterval, pollInterval)
            self.pollInterval = normalizedPollInterval
            if page == 1 {
                pageOnePollInterval = normalizedPollInterval
            }
        }
        lastFetchedAt = Date()
        if page == 1 {
            pageOneFetchedAt = lastFetchedAt
        }
        return insertedEvents
    }

    mutating func recordNotModified(page: Int, pollInterval: TimeInterval?, perPage: Int) {
        fetchedPages.insert(page)
        nextPage = max(nextPage, page + 1)
        if pageCounts[page].map({ $0 < perPage }) == true {
            exhausted = true
        }
        if let pollInterval {
            let normalizedPollInterval = max(GitHubEventsLimits.minimumPollInterval, pollInterval)
            self.pollInterval = normalizedPollInterval
            if page == 1 {
                pageOnePollInterval = normalizedPollInterval
            }
        }
        lastFetchedAt = Date()
        if page == 1 {
            pageOneFetchedAt = lastFetchedAt
        }
    }
}

struct GitHubEventsDiskCache {
    let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.directory = applicationSupport.appendingPathComponent(
                "GitHubEvents",
                isDirectory: true
            )
        }
    }

    func load(username: String) -> CachedUserEvents? {
        let url = fileURL(for: username)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(CachedUserEvents.self, from: data)
    }

    func save(_ cache: CachedUserEvents) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(cache)
            try data.write(to: fileURL(for: cache.username), options: .atomic)
        } catch {
            // A cache failure should never prevent the feed from being displayed.
        }
    }

    private func fileURL(for username: String) -> URL {
        directory.appendingPathComponent("\(username.lowercased()).json")
    }
}

struct GitHubEventsPage: Equatable {
    let page: Int
    let events: [GitHubEvent]
    let etag: String?
    let lastModified: String?
    let pollInterval: TimeInterval?
    let notModified: Bool
}

enum GitHubEventsClientError: LocalizedError, Equatable {
    case invalidUsername
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String, retryAfter: TimeInterval?)

    var retryAfter: TimeInterval? {
        guard case let .httpStatus(_, _, retryAfter) = self else { return nil }
        return retryAfter
    }

    var isRateLimited: Bool {
        guard case let .httpStatus(status, _, _) = self else { return false }
        return status == 403 || status == 429
    }

    var errorDescription: String? {
        switch self {
        case .invalidUsername: return "Enter a valid GitHub username."
        case .invalidURL: return "GitHub events URL could not be created."
        case .invalidResponse: return "GitHub returned an unexpected events response."
        case let .httpStatus(status, message, _): return "GitHub returned \(status): \(message)"
        }
    }
}

struct GitHubEventsClient {
    let session: URLSession
    let perPage: Int
    private let token: String?

    var isAuthenticated: Bool { token != nil }
    var defaultPollInterval: TimeInterval {
        isAuthenticated ? GitHubEventsLimits.minimumPollInterval : GitHubEventsLimits.unauthenticatedPollInterval
    }

    init(
        session: URLSession = .shared,
        perPage: Int = 100,
        token: String? = GitHubCredentialProvider.token()
    ) {
        self.session = session
        self.perPage = min(max(perPage, 1), 100)
        self.token = token?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? token?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
    }

    func fetch(
        username: String,
        page: Int,
        etag: String? = nil,
        lastModified: String? = nil
    ) async throws -> GitHubEventsPage {
        guard let username = GitHubUsername.normalize(username), page > 0 else {
            throw GitHubEventsClientError.invalidUsername
        }

        var components = URLComponents(string: "https://api.github.com")
        components?.path = "/users/\(username)/events/public"
        components?.queryItems = [
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "page", value: String(page))
        ]
        guard let url = components?.url else {
            throw GitHubEventsClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("GitHub Events", forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let lastModified { request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since") }

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw GitHubEventsClientError.invalidResponse
        }

        let pollInterval = response.value(forHTTPHeaderField: "X-Poll-Interval")
            .flatMap { value -> TimeInterval? in
                guard let interval = TimeInterval(value), interval.isFinite, interval >= 0 else {
                    return nil
                }
                return interval
            }
        let responseETag = response.value(forHTTPHeaderField: "ETag")
        let responseLastModified = response.value(forHTTPHeaderField: "Last-Modified")

        if response.statusCode == 304 {
            return GitHubEventsPage(
                page: page,
                events: [],
                etag: responseETag,
                lastModified: responseLastModified,
                pollInterval: pollInterval,
                notModified: true
            )
        }

        guard response.statusCode == 200 else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["message"]
                ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            throw GitHubEventsClientError.httpStatus(
                response.statusCode,
                message,
                retryAfter: response.statusCode == 403 || response.statusCode == 429
                    ? rateLimitDelay(for: response)
                    : nil
            )
        }

        guard let events = try? JSONDecoder().decode([GitHubEvent].self, from: data) else {
            throw GitHubEventsClientError.invalidResponse
        }
        return GitHubEventsPage(
            page: page,
            events: events,
            etag: responseETag,
            lastModified: responseLastModified,
            pollInterval: pollInterval,
            notModified: false
        )
    }

    private func rateLimitDelay(for response: HTTPURLResponse) -> TimeInterval? {
        if let retryAfter = response.value(forHTTPHeaderField: "Retry-After") {
            if let seconds = TimeInterval(retryAfter), seconds.isFinite, seconds >= 0 {
                return boundedRateLimitDelay(seconds)
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            if let date = formatter.date(from: retryAfter) {
                return boundedRateLimitDelay(date.timeIntervalSinceNow + 1)
            }
        }

        guard response.value(forHTTPHeaderField: "X-RateLimit-Remaining")
            .flatMap(Int.init) == 0,
            let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset")
            .flatMap(TimeInterval.init),
            reset.isFinite
        else {
            return nil
        }

        return boundedRateLimitDelay(
            Date(timeIntervalSince1970: reset).timeIntervalSinceNow + 1
        )
    }

    private func boundedRateLimitDelay(_ seconds: TimeInterval) -> TimeInterval {
        max(GitHubEventsLimits.minimumPollInterval, seconds)
    }
}

struct GitHubUserEvents: Identifiable, Equatable {
    let username: String
    var events: [GitHubEvent]
    var isLoading = false
    var isLoadingMore = false
    var hasMore = true
    var errorMessage: String?
    var unseenCount = 0
    var retryHistorical = false

    var id: String { username }
}

enum GitHubUsernameError: LocalizedError {
    case invalid
    case duplicate

    var errorDescription: String? {
        switch self {
        case .invalid: return "Use a GitHub username made of letters, numbers, or hyphens."
        case .duplicate: return "That username is already configured."
        }
    }
}

@MainActor
final class GitHubEventsStore: ObservableObject {
    @Published private(set) var users: [GitHubUserEvents]
    @Published private(set) var presentationSessionID = UUID()

    var onNewEvents: ((String, Int, [GitHubEvent]) -> Void)?
    var onUsernameRemoved: ((String, Int) -> Void)?

    private static let usernamesKey = "GitHubEvents.usernames"
    private static let generationsKey = "GitHubEvents.notificationGenerations"
    private static let pollRequestTimesKey = "GitHubEvents.pollRequestTimes"
    private static let historicalRequestTimesKey = "GitHubEvents.historicalRequestTimes"
    private static let rateLimitBackoffUntilKey = "GitHubEvents.rateLimitBackoffUntil"
    private let cacheStore: GitHubEventsDiskCache
    private let client: GitHubEventsClient
    private let cacheWriteQueue = DispatchQueue(
        label: "GitHubEvents.cache-writes",
        qos: .utility
    )
    private var caches: [String: CachedUserEvents]
    private var latestPageOneEventIDs: [String: Set<String>] = [:]
    private var pendingSeenUsernames = Set<String>()
    private var pendingSeenSaveTask: Task<Void, Never>?
    private var inFlight = Set<String>()
    private var pollingTask: Task<Void, Never>?
    private var pollRetryTask: Task<Void, Never>?
    private var userPollIntervals: [String: TimeInterval]
    private var userNextRequestAllowedAt: [String: Date] = [:]
    private var pollCursor = 0
    private var pollRetryOrder: [String] = []
    private var pollRetryQueued = Set<String>()
    private var pollForcedRequests = Set<String>()
    private var rateLimitBackoffUntil: Date?
    private var rateLimitFailureCount = 0
    private var historicalRequestAllowedAt: [String: Date] = [:]
    private var historicalRequestTimes: [Date] = []
    private var pollRequestTimes: [Date] = []
    private var historicalRetryOrder: [String] = []
    private var historicalRetryQueued = Set<String>()
    private var historicalRetryTask: Task<Void, Never>?
    private var requestGenerations: [String: Int] = [:]

    init(
        usernames: [String]? = nil,
        cacheStore: GitHubEventsDiskCache = GitHubEventsDiskCache(),
        client: GitHubEventsClient = GitHubEventsClient()
    ) {
        self.cacheStore = cacheStore
        self.client = client
        self.userPollIntervals = [:]

        let configured = usernames ?? UserDefaults.standard.stringArray(forKey: Self.usernamesKey) ?? []
        var configuredUsernames = Set<String>()
        let normalized = configured.compactMap(GitHubUsername.normalize).filter {
            configuredUsernames.insert($0).inserted
        }
        let storedGenerations = UserDefaults.standard
            .dictionary(forKey: Self.generationsKey)
            .flatMap { $0 as? [String: Int] } ?? [:]
        var loadedCaches: [String: CachedUserEvents] = [:]
        var loadedPollIntervals: [String: TimeInterval] = [:]
        var loadedNextRequestAllowedAt: [String: Date] = [:]
        self.users = normalized.map { username in
            let cache = cacheStore.load(username: username) ?? CachedUserEvents(username: username)
            loadedCaches[username] = cache
            let startupPollInterval = Self.startupPollInterval(
                for: cache,
                default: client.defaultPollInterval
            )
            loadedPollIntervals[username] = startupPollInterval
            let fetchedAt = cache.pageOneFetchedAt ?? cache.lastFetchedAt
            if let fetchedAt,
               Date().timeIntervalSince(fetchedAt) <= GitHubEventsLimits.cachedPollIntervalLifetime {
                loadedNextRequestAllowedAt[username] = fetchedAt.addingTimeInterval(startupPollInterval)
            }
            return GitHubUserEvents(
                username: username,
                events: cache.events,
                hasMore: !cache.exhausted,
                unseenCount: cache.events.filter { !cache.seenEventIDs.contains($0.id) }.count
            )
        }
        self.caches = loadedCaches
        self.userPollIntervals = loadedPollIntervals
        self.userNextRequestAllowedAt = loadedNextRequestAllowedAt
        self.requestGenerations = storedGenerations
        self.pollRequestTimes = Self.loadRequestTimes(forKey: Self.pollRequestTimesKey)
        self.historicalRequestTimes = Self.loadRequestTimes(forKey: Self.historicalRequestTimesKey)
        self.rateLimitBackoffUntil = UserDefaults.standard.object(
            forKey: Self.rateLimitBackoffUntilKey
        ) as? Date
    }

    func startPolling() {
        stopPolling()
        refreshAll(automatic: true)
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await self.sleep(for: self.nextPollDelay)
                guard !Task.isCancelled else { return }
                self.refreshAll(automatic: true)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        pollRetryTask?.cancel()
        pollRetryTask = nil
        pendingSeenSaveTask?.cancel()
        pendingSeenSaveTask = nil
        flushPendingSeenCaches()
        cacheWriteQueue.sync {}
    }

    func refreshAll() {
        refreshAll(automatic: false)
    }

    private func refreshAll(automatic: Bool) {
        guard !users.isEmpty else { return }

        let currentUsers = users
        let startIndex = pollCursor % currentUsers.count
        for offset in 0..<currentUsers.count {
            let index = (startIndex + offset) % currentUsers.count
            let user = currentUsers[index]
            guard (!automatic || !inFlight.contains(user.username)),
                  !automatic || isPollDue(for: user.username)
            else {
                continue
            }
            pollCursor = (index + 1) % currentUsers.count
            enqueuePollRequest(for: user.username, forced: !automatic)
        }
        drainPollRequests()
    }

    func refresh(username: String) {
        guard users.contains(where: { $0.username == username }),
              caches[username] != nil
        else { return }
        enqueuePollRequest(for: username, forced: true)
        if !inFlight.contains(username) {
            drainPollRequests()
        }
    }

    private func refreshWithoutThrottle(username: String) {
        guard let cache = caches[username] else { return }
        fetch(
            username: username,
            page: 1,
            cache: cache,
            historical: false
        )
    }

    func loadMore(for username: String) {
        guard let cache = caches[username],
              !cache.fetchedPages.contains(cache.nextPage)
        else { return }
        guard !cache.exhausted || inFlight.contains(username) else { return }
        enqueueHistoricalRequest(for: username)
        if !inFlight.contains(username) {
            drainHistoricalRequests()
        }
    }

    func retry(for username: String) {
        guard let user = users.first(where: { $0.username == username }) else { return }
        if user.retryHistorical {
            loadMore(for: username)
        } else {
            refresh(username: username)
        }
    }

    @discardableResult
    func addUsername(_ input: String) -> GitHubUsernameError? {
        guard let username = GitHubUsername.normalize(input) else { return .invalid }
        guard !users.contains(where: { $0.username == username }) else { return .duplicate }

        requestGenerations[username, default: 0] += 1
        saveRequestGenerations()
        let cache = caches[username] ?? cacheStore.load(username: username) ?? CachedUserEvents(username: username)
        caches[username] = cache
        userPollIntervals[username] = Self.startupPollInterval(
            for: cache,
            default: client.defaultPollInterval
        )
        users.append(GitHubUserEvents(
            username: username,
            events: cache.events,
            hasMore: !cache.exhausted,
            unseenCount: cache.events.filter { !cache.seenEventIDs.contains($0.id) }.count
        ))
        saveConfiguredUsernames()
        refresh(username: username)
        return nil
    }

    func removeUsername(_ username: String) {
        requestGenerations[username, default: 0] += 1
        saveRequestGenerations()
        inFlight.remove(username)
        historicalRetryQueued.remove(username)
        historicalRetryOrder.removeAll { $0 == username }
        userPollIntervals.removeValue(forKey: username)
        userNextRequestAllowedAt.removeValue(forKey: username)
        pollRetryQueued.remove(username)
        pollRetryOrder.removeAll { $0 == username }
        pollForcedRequests.remove(username)
        if pendingSeenUsernames.remove(username) != nil, let cache = caches[username] {
            saveCache(cache)
        }
        cacheWriteQueue.sync {}
        caches.removeValue(forKey: username)
        latestPageOneEventIDs.removeValue(forKey: username)
        pendingSeenUsernames.remove(username)
        historicalRequestAllowedAt.removeValue(forKey: username)
        if pollRetryOrder.isEmpty {
            pollRetryTask?.cancel()
            pollRetryTask = nil
        }
        if historicalRetryOrder.isEmpty {
            historicalRetryTask?.cancel()
            historicalRetryTask = nil
        }
        users.removeAll { $0.username == username }
        saveConfiguredUsernames()
        onUsernameRemoved?(username, requestGenerations[username, default: 0])
    }

    func markAsSeen(_ eventID: String, for username: String) {
        markAsSeen(Set([eventID]), for: username)
    }

    func markAsSeen(_ eventIDs: Set<String>, for username: String) {
        guard var cache = caches[username] else {
            return
        }
        let unseenEventIDs = eventIDs.subtracting(cache.seenEventIDs)
        guard !unseenEventIDs.isEmpty else { return }
        cache.seenEventIDs.formUnion(unseenEventIDs)
        caches[username] = cache
        scheduleSeenCacheSave(for: username)
        guard let index = users.firstIndex(where: { $0.username == username }) else { return }
        users[index].unseenCount = cache.events.filter { !cache.seenEventIDs.contains($0.id) }.count
    }

    private func scheduleSeenCacheSave(for username: String) {
        pendingSeenUsernames.insert(username)
        guard pendingSeenSaveTask == nil else { return }
        pendingSeenSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.flushPendingSeenCaches()
        }
    }

    private func flushPendingSeenCaches() {
        let usernames = pendingSeenUsernames
        pendingSeenUsernames.removeAll()
        pendingSeenSaveTask = nil
        usernames.forEach { username in
            if let cache = caches[username] {
                saveCache(cache)
            }
        }
    }

    private func saveCache(_ cache: CachedUserEvents) {
        let cacheStore = self.cacheStore
        cacheWriteQueue.async {
            cacheStore.save(cache)
        }
    }

    func beginPresentationSession() {
        presentationSessionID = UUID()
    }

    func isSeen(_ eventID: String, for username: String) -> Bool {
        caches[username]?.seenEventIDs.contains(eventID) ?? false
    }

    func pageOneInsertedEventIDs(for username: String) -> Set<String> {
        latestPageOneEventIDs[username] ?? []
    }

    func configurationGeneration(for username: String) -> Int {
        requestGenerations[username, default: 0]
    }

    private func fetch(
        username: String,
        page: Int,
        cache: CachedUserEvents,
        historical: Bool
    ) {
        guard !inFlight.contains(username), let index = users.firstIndex(where: { $0.username == username }) else {
            return
        }
        let generation = requestGenerations[username, default: 0]
        inFlight.insert(username)
        users[index].retryHistorical = historical
        if historical {
            users[index].isLoadingMore = true
        } else {
            users[index].isLoading = true
            users[index].errorMessage = nil
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let pageResult = try await self.client.fetch(
                    username: username,
                    page: page,
                    etag: cache.pageETags[page],
                    lastModified: cache.pageLastModified[page]
                )
                apply(
                    pageResult,
                    username: username,
                    historical: historical,
                    generation: generation
                )
            } catch {
                apply(
                    error,
                    username: username,
                    historical: historical,
                    generation: generation
                )
            }
        }
    }

    private func apply(
        _ page: GitHubEventsPage,
        username: String,
        historical: Bool,
        generation: Int
    ) {
        guard requestGenerations[username, default: 0] == generation else { return }
        defer {
            finishRequest(
                username: username,
                historical: historical,
                generation: generation
            )
        }
        guard var cache = caches[username] else { return }

        clearExpiredRateLimitBackoff()

        let hadPageOne = cache.fetchedPages.contains(1)
        var shouldRetryHistoricalPage = false
        var newEvents: [GitHubEvent] = []
        if page.notModified {
            cache.recordNotModified(
                page: page.page,
                pollInterval: page.pollInterval,
                perPage: client.perPage
            )
        } else {
            newEvents = cache.merge(
                page.events,
                page: page.page,
                etag: page.etag,
                lastModified: page.lastModified,
                perPage: client.perPage,
                pollInterval: page.pollInterval
            )
        }
        shouldRetryHistoricalPage = historical
            && !cache.exhausted
            && !cache.fetchedPages.contains(cache.nextPage)
            && (page.notModified || (page.events.count >= client.perPage && newEvents.isEmpty))
        caches[username] = cache
        saveCache(cache)
        if !historical {
            latestPageOneEventIDs[username, default: []].formUnion(newEvents.map(\.id))
            latestPageOneEventIDs[username]?.formIntersection(Set(cache.events.map(\.id)))
        }
        if let pagePollInterval = page.pollInterval {
            let currentInterval = max(GitHubEventsLimits.minimumPollInterval, pagePollInterval)
            if !historical {
                userPollIntervals[username] = currentInterval
            }
        }
        if !historical {
            userNextRequestAllowedAt[username] = Date().addingTimeInterval(
                pollCadence(for: username)
            )
        }
        updateUser(username: username, cache: cache, errorMessage: nil)
        if !historical, hadPageOne, !newEvents.isEmpty {
            onNewEvents?(username, requestGenerations[username, default: 0], newEvents)
        }
        if shouldRetryHistoricalPage {
            scheduleHistoricalRetry(for: username)
        }
    }

    private func apply(
        _ error: Error,
        username: String,
        historical: Bool,
        generation: Int
    ) {
        guard requestGenerations[username, default: 0] == generation else { return }
        defer {
            finishRequest(
                username: username,
                historical: historical,
                generation: generation
            )
        }
        if let clientError = error as? GitHubEventsClientError,
           clientError.isRateLimited {
            recordRateLimitBackoff(clientError.retryAfter)
            if historical {
                scheduleHistoricalRetry(for: username)
            }
        }
        guard let index = users.firstIndex(where: { $0.username == username }) else { return }
        users[index].errorMessage = error.localizedDescription
        users[index].retryHistorical = historical
    }

    private func finishRequest(username: String, historical: Bool, generation: Int) {
        guard requestGenerations[username, default: 0] == generation else { return }
        inFlight.remove(username)
        guard let index = users.firstIndex(where: { $0.username == username }) else { return }
        if historical {
            users[index].isLoadingMore = false
            drainHistoricalRequests()
        } else {
            users[index].isLoading = false
            drainHistoricalRequests()
        }
        drainPollRequests()
    }

    private func updateUser(username: String, cache: CachedUserEvents, errorMessage: String?) {
        guard let index = users.firstIndex(where: { $0.username == username }) else { return }
        users[index].events = cache.events
        users[index].hasMore = !cache.exhausted
        users[index].unseenCount = cache.events.filter { !cache.seenEventIDs.contains($0.id) }.count
        users[index].errorMessage = errorMessage
        users[index].retryHistorical = false
    }

    private func saveConfiguredUsernames() {
        UserDefaults.standard.set(users.map(\.username), forKey: Self.usernamesKey)
    }

    private func saveRequestGenerations() {
        UserDefaults.standard.set(requestGenerations, forKey: Self.generationsKey)
    }

    private static func loadRequestTimes(forKey key: String) -> [Date] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let times = try? JSONDecoder().decode([Date].self, from: data)
        else {
            return []
        }
        let cutoff = Date().addingTimeInterval(-60 * 60)
        return times.filter { $0 > cutoff }
    }

    private func saveRequestTimes(_ times: [Date], forKey key: String) {
        guard let data = try? JSONEncoder().encode(times) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func startupPollInterval(
        for cache: CachedUserEvents,
        default defaultInterval: TimeInterval
    ) -> TimeInterval {
        let fetchedAt = cache.pageOneFetchedAt ?? cache.lastFetchedAt
        guard let fetchedAt,
              Date().timeIntervalSince(fetchedAt) <= GitHubEventsLimits.cachedPollIntervalLifetime
        else {
            return defaultInterval
        }
        return max(defaultInterval, cache.pageOnePollInterval ?? cache.pollInterval)
    }

    private var isRateLimitBackedOff: Bool {
        guard let rateLimitBackoffUntil else { return false }
        return rateLimitBackoffUntil > Date()
    }

    private var canStartRequest: Bool {
        !isRateLimitBackedOff
    }

    private func isPollDue(for username: String) -> Bool {
        guard let allowedAt = userNextRequestAllowedAt[username] else { return true }
        return allowedAt <= Date()
    }

    private func schedulePollRetry() {
        guard pollRetryTask == nil else { return }
        let budgetDelay = pollRequestBudgetDelay()
        let backoffDelay = rateLimitBackoffUntil?.timeIntervalSinceNow ?? 0
        let pollDelay = earliestPollDelay
        let delay = max(0.1, max(budgetDelay, max(backoffDelay, pollDelay)))
        pollRetryTask = Task { [weak self] in
            guard let self else { return }
            try? await self.sleep(for: delay)
            guard !Task.isCancelled else { return }
            pollRetryTask = nil
            drainPollRequests()
        }
    }

    private func enqueuePollRequest(
        for username: String,
        forced: Bool = false
    ) {
        if forced {
            pollForcedRequests.insert(username)
        }
        guard pollRetryQueued.insert(username).inserted else { return }
        pollRetryOrder.append(username)
    }

    private func drainPollRequests() {
        var skippedRequests = 0
        while !pollRetryOrder.isEmpty {
            let username = pollRetryOrder.removeFirst()
            pollRetryQueued.remove(username)
            let forced = pollForcedRequests.remove(username) != nil
            guard users.contains(where: { $0.username == username }),
                  caches[username] != nil
            else {
                skippedRequests = 0
                continue
            }
            if inFlight.contains(username) {
                enqueuePollRequest(for: username, forced: forced)
                skippedRequests += 1
                if skippedRequests >= pollRetryOrder.count {
                    return
                }
                continue
            }
            guard canStartRequest else {
                pollRetryOrder.insert(username, at: 0)
                pollRetryQueued.insert(username)
                if forced { pollForcedRequests.insert(username) }
                schedulePollRetry()
                return
            }
            guard forced || isPollDue(for: username) else {
                enqueuePollRequest(for: username, forced: false)
                skippedRequests += 1
                if skippedRequests >= pollRetryOrder.count {
                    schedulePollRetry()
                    return
                }
                continue
            }
            guard canStartPollRequest() else {
                pollRetryOrder.insert(username, at: 0)
                pollRetryQueued.insert(username)
                if forced { pollForcedRequests.insert(username) }
                schedulePollRetry()
                return
            }
            markPollRequestStarted()
            markRequestStarted(for: username)
            refreshWithoutThrottle(username: username)
            skippedRequests = 0
        }
    }

    private func canStartPollRequest() -> Bool {
        prunePollRequestTimes()
        return pollRequestTimes.count < Int(pollRequestBudget)
    }

    private func markPollRequestStarted() {
        prunePollRequestTimes()
        pollRequestTimes.append(Date())
        saveRequestTimes(pollRequestTimes, forKey: Self.pollRequestTimesKey)
    }

    private func pollRequestBudgetDelay() -> TimeInterval {
        prunePollRequestTimes()
        guard pollRequestTimes.count >= Int(pollRequestBudget),
              let oldest = pollRequestTimes.first
        else {
            return 0
        }
        return max(0, oldest.addingTimeInterval(60 * 60).timeIntervalSinceNow)
    }

    private func prunePollRequestTimes() {
        let cutoff = Date().addingTimeInterval(-60 * 60)
        pollRequestTimes.removeAll { $0 <= cutoff }
    }

    private var pollRequestBudget: TimeInterval {
        client.isAuthenticated
            ? GitHubEventsLimits.authenticatedHourlyBudget
            : GitHubEventsLimits.unauthenticatedHourlyBudget
    }

    private func enqueueHistoricalRequest(for username: String) {
        guard historicalRetryQueued.insert(username).inserted else { return }
        historicalRetryOrder.append(username)
    }

    private func scheduleHistoricalRetry(for username: String) {
        enqueueHistoricalRequest(for: username)
        scheduleHistoricalRetryWake()
    }

    private func drainHistoricalRequests() {
        var skippedRequests = 0
        while !historicalRetryOrder.isEmpty {
            let username = historicalRetryOrder.removeFirst()
            historicalRetryQueued.remove(username)
            guard let cache = caches[username],
                  !cache.exhausted,
                  !cache.fetchedPages.contains(cache.nextPage)
            else {
                skippedRequests = 0
                continue
            }
            if inFlight.contains(username) {
                enqueueHistoricalRequest(for: username)
                skippedRequests += 1
                if skippedRequests >= historicalRetryOrder.count {
                    scheduleHistoricalRetryWake()
                    return
                }
                continue
            }
            guard !isRateLimitBackedOff, canStartHistoricalRequest() else {
                historicalRetryOrder.insert(username, at: 0)
                historicalRetryQueued.insert(username)
                scheduleHistoricalRetryWake()
                return
            }
            if let allowedAt = historicalRequestAllowedAt[username], allowedAt > Date() {
                enqueueHistoricalRequest(for: username)
                skippedRequests += 1
                if skippedRequests >= historicalRetryOrder.count {
                    scheduleHistoricalRetryWake()
                    return
                }
                continue
            }
            historicalRequestAllowedAt[username] = Date().addingTimeInterval(
                GitHubEventsLimits.historicalRequestInterval
            )
            markHistoricalRequestStarted()
            fetch(
                username: username,
                page: cache.nextPage,
                cache: cache,
                historical: true
            )
            skippedRequests = 0
        }
    }

    private func scheduleHistoricalRetryWake() {
        guard historicalRetryTask == nil, !historicalRetryOrder.isEmpty else { return }
        let historicalDelay = earliestHistoricalThrottleDelay
        let historicalBudgetDelay = historicalRequestBudgetDelay()
        let backoffDelay = rateLimitBackoffUntil?.timeIntervalSinceNow ?? 0
        let delay = max(0.1, max(historicalDelay, max(historicalBudgetDelay, backoffDelay)))
        historicalRetryTask = Task { [weak self] in
            guard let self else { return }
            try? await self.sleep(for: delay)
            guard !Task.isCancelled else { return }
            historicalRetryTask = nil
            drainHistoricalRequests()
        }
    }

    private var earliestHistoricalThrottleDelay: TimeInterval {
        historicalRetryOrder
            .compactMap { historicalRequestAllowedAt[$0]?.timeIntervalSinceNow }
            .map { max(0, $0) }
            .min() ?? 0
    }

    private func canStartHistoricalRequest() -> Bool {
        pruneHistoricalRequestTimes()
        return historicalRequestTimes.count < Int(historicalRequestBudget)
    }

    private func markHistoricalRequestStarted() {
        pruneHistoricalRequestTimes()
        historicalRequestTimes.append(Date())
        saveRequestTimes(historicalRequestTimes, forKey: Self.historicalRequestTimesKey)
    }

    private func historicalRequestBudgetDelay() -> TimeInterval {
        pruneHistoricalRequestTimes()
        guard historicalRequestTimes.count >= Int(historicalRequestBudget),
              let oldest = historicalRequestTimes.first
        else {
            return 0
        }
        return max(0, oldest.addingTimeInterval(60 * 60).timeIntervalSinceNow)
    }

    private func pruneHistoricalRequestTimes() {
        let cutoff = Date().addingTimeInterval(-60 * 60)
        historicalRequestTimes.removeAll { $0 <= cutoff }
    }

    private var historicalRequestBudget: TimeInterval {
        client.isAuthenticated
            ? GitHubEventsLimits.authenticatedHistoricalHourlyBudget
            : GitHubEventsLimits.unauthenticatedHistoricalHourlyBudget
    }

    private func markRequestStarted(for username: String) {
        userNextRequestAllowedAt[username] = Date().addingTimeInterval(
            pollCadence(for: username)
        )
    }

    private func pollCadence(for username: String) -> TimeInterval {
        let userCount = TimeInterval(max(users.count, 1))
        let hourlyBudget = client.isAuthenticated
            ? GitHubEventsLimits.authenticatedHourlyBudget
            : GitHubEventsLimits.unauthenticatedHourlyBudget
        let budgetDelay = 60 * 60 * userCount / hourlyBudget
        return max(
            GitHubEventsLimits.minimumPollInterval,
            max(userPollIntervals[username] ?? client.defaultPollInterval, budgetDelay)
        )
    }

    private var earliestPollDelay: TimeInterval {
        if !pollForcedRequests.isEmpty { return 0 }
        return users
            .map { max(0, userNextRequestAllowedAt[$0.username]?.timeIntervalSinceNow ?? 0) }
            .min() ?? 0
    }

    private var nextPollDelay: TimeInterval {
        let backoffDelay = rateLimitBackoffUntil.map { max(0, $0.timeIntervalSinceNow) } ?? 0
        let budgetDelay = pollRequestBudgetDelay()
        return max(
            GitHubEventsLimits.minimumPollInterval,
            max(earliestPollDelay, max(backoffDelay, budgetDelay))
        )
    }

    private func sleep(for duration: TimeInterval) async throws {
        var remaining = duration
        while remaining > 0 {
            let chunk = min(remaining, GitHubEventsLimits.maximumSleepChunk)
            try await Task.sleep(nanoseconds: UInt64(chunk * 1_000_000_000))
            remaining -= chunk
        }
    }

    private func recordRateLimitBackoff(_ retryAfter: TimeInterval?) {
        rateLimitFailureCount += 1
        let exponent = min(rateLimitFailureCount - 1, 8)
        let exponentialDelay = min(
            GitHubEventsLimits.maximumSleepChunk,
            GitHubEventsLimits.minimumPollInterval * pow(2, Double(exponent))
        )
        let delay = max(exponentialDelay, retryAfter ?? GitHubEventsLimits.minimumPollInterval)
        let newBackoffUntil = Date().addingTimeInterval(delay)
        rateLimitBackoffUntil = max(rateLimitBackoffUntil ?? .distantPast, newBackoffUntil)
        UserDefaults.standard.set(rateLimitBackoffUntil, forKey: Self.rateLimitBackoffUntilKey)
    }

    private func clearExpiredRateLimitBackoff() {
        guard let rateLimitBackoffUntil, rateLimitBackoffUntil <= Date() else { return }
        self.rateLimitBackoffUntil = nil
        UserDefaults.standard.removeObject(forKey: Self.rateLimitBackoffUntilKey)
        rateLimitFailureCount = 0
    }
}
