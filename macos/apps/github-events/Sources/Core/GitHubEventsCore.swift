import Combine
import Foundation

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

struct GitHubEvent: Codable, Equatable, Identifiable {
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
        let repositoryURL = repo.url ?? URL(string: "https://github.com/\(repository)")

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
            let countText = commitCount == 1 ? "1 commit" : "\(commitCount) commits"
            return EventPresentation(
                title: "\(actor) pushed \(countText) to \(repository)",
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
    var seenEventIDs: Set<String> = []
    var exhausted = false
    var pollInterval: TimeInterval = 300
    var lastFetchedAt: Date?

    init(username: String) {
        self.username = username
    }

    mutating func merge(
        _ newEvents: [GitHubEvent],
        page: Int,
        etag: String?,
        lastModified: String?,
        perPage: Int,
        pollInterval: TimeInterval?
    ) {
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
        if newEvents.count < perPage {
            exhausted = true
        }
        if let etag { pageETags[page] = etag }
        if let lastModified { pageLastModified[page] = lastModified }
        if let pollInterval { self.pollInterval = max(60, pollInterval) }
        lastFetchedAt = Date()
    }

    mutating func recordNotModified(page: Int, pollInterval: TimeInterval?) {
        fetchedPages.insert(page)
        if page == 1 { nextPage = max(nextPage, 2) }
        if let pollInterval { self.pollInterval = max(60, pollInterval) }
        lastFetchedAt = Date()
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
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidUsername: return "Enter a valid GitHub username."
        case .invalidURL: return "GitHub events URL could not be created."
        case .invalidResponse: return "GitHub returned an unexpected events response."
        case let .httpStatus(status, message): return "GitHub returned \(status): \(message)"
        }
    }
}

struct GitHubEventsClient {
    let session: URLSession
    let perPage: Int

    init(session: URLSession = .shared, perPage: Int = 100) {
        self.session = session
        self.perPage = min(max(perPage, 1), 100)
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
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let lastModified { request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since") }

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw GitHubEventsClientError.invalidResponse
        }

        let pollInterval = response.value(forHTTPHeaderField: "X-Poll-Interval")
            .flatMap(TimeInterval.init)
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
            throw GitHubEventsClientError.httpStatus(response.statusCode, message)
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
}

struct GitHubUserEvents: Identifiable, Equatable {
    let username: String
    var events: [GitHubEvent]
    var isLoading = false
    var isLoadingMore = false
    var hasMore = true
    var errorMessage: String?
    var unseenCount = 0

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

    private static let usernamesKey = "GitHubEvents.usernames"
    private let cacheStore: GitHubEventsDiskCache
    private let client: GitHubEventsClient
    private var caches: [String: CachedUserEvents]
    private var inFlight = Set<String>()
    private var pollingTask: Task<Void, Never>?
    private var pollInterval: TimeInterval = 300

    init(
        usernames: [String]? = nil,
        cacheStore: GitHubEventsDiskCache = GitHubEventsDiskCache(),
        client: GitHubEventsClient = GitHubEventsClient()
    ) {
        self.cacheStore = cacheStore
        self.client = client

        let configured = usernames ?? UserDefaults.standard.stringArray(forKey: Self.usernamesKey) ?? []
        let normalized = configured.compactMap(GitHubUsername.normalize)
        var loadedCaches: [String: CachedUserEvents] = [:]
        self.users = normalized.map { username in
            let cache = cacheStore.load(username: username) ?? CachedUserEvents(username: username)
            loadedCaches[username] = cache
            return GitHubUserEvents(
                username: username,
                events: cache.events,
                hasMore: !cache.exhausted,
                unseenCount: cache.events.filter { !cache.seenEventIDs.contains($0.id) }.count
            )
        }
        self.caches = loadedCaches
    }

    func startPolling() {
        stopPolling()
        refreshAll()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                let delay = max(60, self?.pollInterval ?? 300)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.refreshAll()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refreshAll() {
        users.forEach { refresh(username: $0.username) }
    }

    func refresh(username: String) {
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
              !cache.exhausted,
              !cache.fetchedPages.contains(cache.nextPage)
        else { return }
        fetch(
            username: username,
            page: cache.nextPage,
            cache: cache,
            historical: true
        )
    }

    @discardableResult
    func addUsername(_ input: String) -> GitHubUsernameError? {
        guard let username = GitHubUsername.normalize(input) else { return .invalid }
        guard !users.contains(where: { $0.username == username }) else { return .duplicate }

        let cache = caches[username] ?? cacheStore.load(username: username) ?? CachedUserEvents(username: username)
        caches[username] = cache
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
        users.removeAll { $0.username == username }
        saveConfiguredUsernames()
    }

    func markAllAsSeen() {
        for index in users.indices {
            let username = users[index].username
            guard var cache = caches[username] else { continue }
            cache.seenEventIDs.formUnion(cache.events.map(\.id))
            caches[username] = cache
            cacheStore.save(cache)
            users[index].unseenCount = 0
        }
    }

    func isSeen(_ eventID: String, for username: String) -> Bool {
        caches[username]?.seenEventIDs.contains(eventID) ?? false
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
        inFlight.insert(username)
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
                    etag: page == 1 ? cache.pageETags[1] : nil,
                    lastModified: page == 1 ? cache.pageLastModified[1] : nil
                )
                apply(pageResult, username: username, historical: historical)
            } catch {
                apply(error, username: username, historical: historical)
            }
        }
    }

    private func apply(_ page: GitHubEventsPage, username: String, historical: Bool) {
        defer { finishRequest(username: username, historical: historical) }
        guard var cache = caches[username] else { return }

        if page.notModified {
            cache.recordNotModified(page: page.page, pollInterval: page.pollInterval)
        } else {
            cache.merge(
                page.events,
                page: page.page,
                etag: page.etag,
                lastModified: page.lastModified,
                perPage: client.perPage,
                pollInterval: page.pollInterval
            )
        }
        caches[username] = cache
        cacheStore.save(cache)
        pollInterval = max(pollInterval, cache.pollInterval)
        updateUser(username: username, cache: cache, errorMessage: nil)
    }

    private func apply(_ error: Error, username: String, historical: Bool) {
        defer { finishRequest(username: username, historical: historical) }
        guard let index = users.firstIndex(where: { $0.username == username }) else { return }
        users[index].errorMessage = error.localizedDescription
    }

    private func finishRequest(username: String, historical: Bool) {
        inFlight.remove(username)
        guard let index = users.firstIndex(where: { $0.username == username }) else { return }
        if historical {
            users[index].isLoadingMore = false
        } else {
            users[index].isLoading = false
        }
    }

    private func updateUser(username: String, cache: CachedUserEvents, errorMessage: String?) {
        guard let index = users.firstIndex(where: { $0.username == username }) else { return }
        users[index].events = cache.events
        users[index].hasMore = !cache.exhausted
        users[index].unseenCount = cache.events.filter { !cache.seenEventIDs.contains($0.id) }.count
        users[index].errorMessage = errorMessage
    }

    private func saveConfiguredUsernames() {
        UserDefaults.standard.set(users.map(\.username), forKey: Self.usernamesKey)
    }
}
