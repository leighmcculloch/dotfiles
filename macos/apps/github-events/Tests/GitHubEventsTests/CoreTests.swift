import Foundation
import XCTest
@testable import GitHubEvents

final class CoreTests: XCTestCase {
    func testIssueCommentEventPreservesFullMarkdownComment() throws {
        let data = Data(
            """
            [{
              "id": "1",
              "type": "IssueCommentEvent",
              "actor": { "login": "octocat", "display_login": "octocat" },
              "repo": { "name": "octo/hello", "url": "https://api.github.com/repos/octo/hello" },
              "payload": {
                "action": "created",
                "issue": {
                  "number": 42,
                  "title": "A useful issue",
                  "html_url": "https://github.com/octo/hello/issues/42"
                },
                "comment": {
                  "body": "Here is **the full comment**.\\n\\n- one\\n- two",
                  "html_url": "https://github.com/octo/hello/issues/42#issuecomment-1"
                }
              },
              "public": true,
              "created_at": "2024-01-01T12:00:00Z"
            }]
            """.utf8
        )

        let events = try JSONDecoder().decode([GitHubEvent].self, from: data)
        let presentation = try XCTUnwrap(events.first?.presentation)

        XCTAssertEqual(presentation.title, "octocat commented on octo/hello#42")
        XCTAssertEqual(presentation.summary, "A useful issue")
        XCTAssertEqual(
            presentation.markdownBody,
            """
            Here is **the full comment**.

            - one
            - two
            """
        )
        XCTAssertEqual(presentation.url?.absoluteString, "https://github.com/octo/hello/issues/42#issuecomment-1")
    }

    func testPushEventShowsBranchAndCommitMessages() {
        let event = makeEvent(
            id: "push",
            type: "PushEvent",
            payload: [
                "ref": .string("refs/heads/main"),
                "commits": .array([
                    .object(["message": .string("Add the feature")]),
                    .object(["message": .string("Fix the tests")])
                ])
            ]
        )

        let presentation = event.presentation
        XCTAssertEqual(presentation.title, "octocat pushed 2 commits to octo/hello")
        XCTAssertEqual(presentation.summary, "main")
        XCTAssertEqual(presentation.markdownBody, "- Add the feature\n- Fix the tests")
    }

    func testPushEventWithoutCommitPayloadAvoidsInventingAZeroCount() {
        let event = makeEvent(
            id: "push-without-commits",
            type: "PushEvent",
            payload: ["ref": .string("refs/heads/main")]
        )

        XCTAssertEqual(event.presentation.title, "octocat pushed to octo/hello")
        XCTAssertEqual(event.presentation.url?.absoluteString, "https://github.com/octo/hello")
    }

    func testUsernameNormalization() {
        XCTAssertEqual(GitHubUsername.normalize("  OctoCat "), "octocat")
        XCTAssertEqual(GitHubUsername.normalize("a-user-123"), "a-user-123")
        XCTAssertNil(GitHubUsername.normalize("has space"))
        XCTAssertNil(GitHubUsername.normalize("a/user"))
        XCTAssertNil(GitHubUsername.normalize(String(repeating: "a", count: 40)))
    }

    func testCredentialProviderPrefersNonEmptyEnvironmentToken() {
        XCTAssertEqual(
            GitHubCredentialProvider.token(environment: ["GITHUB_TOKEN": "  provided-token  "]),
            "provided-token"
        )
    }

    func testCredentialProviderFallsBackToGitHubCLI() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitHubEventsGH-\(UUID().uuidString)", isDirectory: true)
        let executable = directory.appendingPathComponent("gh")
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(
            "#!/bin/sh\n[ \"$1\" = auth ] && [ \"$2\" = token ] && [ \"$3\" = --hostname ] && [ \"$4\" = github.com ] || exit 1\nprintf cli-token\n".utf8
        ).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )

        XCTAssertEqual(
            GitHubCredentialProvider.token(environment: [
                "GITHUB_TOKEN": " ",
                "PATH": directory.path
            ]),
            "cli-token"
        )
    }

    func testClientWithoutTokenUsesConservativeDefault() {
        let client = GitHubEventsClient(token: nil)

        XCTAssertFalse(client.isAuthenticated)
        XCTAssertEqual(client.defaultPollInterval, 300)
    }

    func testCacheMergesByIDAndSortsNewestFirst() {
        var cache = CachedUserEvents(username: "octocat")
        cache.merge(
            [
                makeEvent(id: "old", createdAt: Date(timeIntervalSince1970: 10)),
                makeEvent(id: "new", createdAt: Date(timeIntervalSince1970: 30))
            ],
            page: 1,
            etag: "etag-1",
            lastModified: nil,
            perPage: 2,
            pollInterval: nil
        )
        cache.merge(
            [
                makeEvent(id: "middle", createdAt: Date(timeIntervalSince1970: 20))
            ],
            page: 2,
            etag: "etag-2",
            lastModified: "yesterday",
            perPage: 2,
            pollInterval: nil
        )
        cache.merge(
            [
                makeEvent(id: "old", createdAt: Date(timeIntervalSince1970: 10)),
                makeEvent(id: "new", createdAt: Date(timeIntervalSince1970: 40))
            ],
            page: 1,
            etag: "etag-3",
            lastModified: nil,
            perPage: 2,
            pollInterval: nil
        )

        XCTAssertEqual(cache.events.map(\.id), ["new", "middle", "old"])
        XCTAssertEqual(cache.events.count, 3)
        XCTAssertEqual(cache.nextPage, 3)
        XCTAssertEqual(cache.fetchedPages, [1, 2])
        XCTAssertEqual(cache.pageETags[1], "etag-3")
        XCTAssertEqual(cache.pageETags[2], "etag-2")
        XCTAssertEqual(cache.pageLastModified[2], "yesterday")
        XCTAssertFalse(cache.exhausted)

        cache.recordNotModified(page: 2, pollInterval: nil, perPage: 2)
        XCTAssertTrue(cache.exhausted)
    }

    func testCacheMergeReturnsOnlyTrulyNewEvents() {
        var cache = CachedUserEvents(username: "octocat")
        let existing = makeEvent(id: "existing")
        let firstNewEvents = cache.merge(
            [existing],
            page: 1,
            etag: nil,
            lastModified: nil,
            perPage: 100,
            pollInterval: nil
        )
        XCTAssertEqual(firstNewEvents.map(\.id), ["existing"])

        let later = makeEvent(id: "later", createdAt: Date(timeIntervalSince1970: 30))
        let secondNewEvents = cache.merge(
            [existing, later, later],
            page: 1,
            etag: nil,
            lastModified: nil,
            perPage: 100,
            pollInterval: nil
        )

        XCTAssertEqual(secondNewEvents.map(\.id), ["later"])
        XCTAssertEqual(cache.events.map(\.id), ["later", "existing"])
    }

    func testDiskCacheRoundTripsPaginationAndSeenState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitHubEventsTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        var cache = CachedUserEvents(username: "octocat")
        cache.merge(
            [makeEvent(id: "1")],
            page: 1,
            etag: "\"abc\"",
            lastModified: nil,
            perPage: 100,
            pollInterval: 60
        )
        cache.seenEventIDs = ["1"]

        let diskCache = GitHubEventsDiskCache(directory: directory)
        diskCache.save(cache)
        let loaded = try XCTUnwrap(diskCache.load(username: "octocat"))

        XCTAssertEqual(loaded.username, "octocat")
        XCTAssertEqual(loaded.events.map(\.id), ["1"])
        XCTAssertEqual(loaded.pageETags[1], "\"abc\"")
        XCTAssertEqual(loaded.seenEventIDs, ["1"])
        XCTAssertEqual(loaded.nextPage, 2)
    }

    func testClientSendsETagAndHandlesNotModified() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "If-None-Match"), "\"cached\"")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 304,
                httpVersion: nil,
                headerFields: ["X-Poll-Interval": "60"]
            )!
            return (response, Data())
        }
        defer { URLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = GitHubEventsClient(session: URLSession(configuration: configuration))
        let page = try await client.fetch(username: "octocat", page: 1, etag: "\"cached\"")

        XCTAssertTrue(page.notModified)
        XCTAssertEqual(page.page, 1)
        XCTAssertEqual(page.pollInterval, 60)
    }

    func testClientPreservesLongServerPollInterval() async throws {
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 304,
                httpVersion: nil,
                headerFields: ["X-Poll-Interval": "90000"]
            )!
            return (response, Data())
        }
        defer { URLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = GitHubEventsClient(
            session: URLSession(configuration: configuration),
            token: nil
        )
        let page = try await client.fetch(username: "octocat", page: 1)

        XCTAssertEqual(page.pollInterval, 90000)
    }

    func testClientSendsProvidedBearerToken() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer provided-token")
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 304,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        defer { URLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = GitHubEventsClient(
            session: URLSession(configuration: configuration),
            token: "provided-token"
        )
        let page = try await client.fetch(username: "octocat", page: 1)

        XCTAssertTrue(client.isAuthenticated)
        XCTAssertEqual(client.defaultPollInterval, 60)
        XCTAssertTrue(page.notModified)
    }

    func testClientSurfacesRateLimitRetryDelay() async throws {
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "120"]
            )!
            return (response, Data("{\"message\":\"slow down\"}".utf8))
        }
        defer { URLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = GitHubEventsClient(
            session: URLSession(configuration: configuration),
            token: nil
        )

        do {
            _ = try await client.fetch(username: "octocat", page: 1)
            XCTFail("Expected a rate-limit error")
        } catch let error as GitHubEventsClientError {
            XCTAssertTrue(error.isRateLimited)
            XCTAssertEqual(error.retryAfter, 120)
        }
    }

    func testClientParsesHTTPDateRetryAfter() async throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        let retryDate = formatter.string(from: Date().addingTimeInterval(120))
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 403,
                httpVersion: nil,
                headerFields: ["Retry-After": retryDate]
            )!
            return (response, Data())
        }
        defer { URLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = GitHubEventsClient(
            session: URLSession(configuration: configuration),
            token: nil
        )

        do {
            _ = try await client.fetch(username: "octocat", page: 1)
            XCTFail("Expected a rate-limit error")
        } catch let error as GitHubEventsClientError {
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(error.retryAfter), 60)
        }
    }

    func testClientUsesRateLimitResetOnlyWhenBudgetIsEmpty() async throws {
        let reset = String(Int(Date().addingTimeInterval(120).timeIntervalSince1970))
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 403,
                httpVersion: nil,
                headerFields: [
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": reset
                ]
            )!
            return (response, Data())
        }
        defer { URLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = GitHubEventsClient(
            session: URLSession(configuration: configuration),
            token: nil
        )

        do {
            _ = try await client.fetch(username: "octocat", page: 1)
            XCTFail("Expected a rate-limit error")
        } catch let error as GitHubEventsClientError {
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(error.retryAfter), 60)
        }
    }

    @MainActor
    func testStoreNotifiesOnlyForLaterPageOneEvents() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitHubEventsStore-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try JSONEncoder().encode([makeEvent(id: "first")])
        let history = try JSONEncoder().encode([
            makeEvent(id: "history", createdAt: Date(timeIntervalSince1970: 10))
        ])
        let later = try JSONEncoder().encode([
            makeEvent(id: "later", createdAt: Date(timeIntervalSince1970: 30)),
            makeEvent(id: "first")
        ])
        let lock = NSLock()
        var pageOneResponses = [first, later, later]

        URLProtocolStub.handler = { request in
            let page = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "page" })?.value
            lock.lock()
            defer { lock.unlock() }
            if page == "2" {
                return (try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )), history)
            }
            let responseData = pageOneResponses.isEmpty
                ? try XCTUnwrap(pageOneResponses.last)
                : pageOneResponses.removeFirst()
            return (try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )), responseData)
        }
        defer { URLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = GitHubEventsClient(
            session: URLSession(configuration: configuration),
            perPage: 1,
            token: nil
        )
        let cacheStore = GitHubEventsDiskCache(directory: directory)
        let initialStore = GitHubEventsStore(
            usernames: ["octocat"],
            cacheStore: cacheStore,
            client: client
        )
        var notifications: [[String]] = []
        initialStore.onNewEvents = { _, _, events in
            notifications.append(events.map(\.id))
        }

        initialStore.refreshAll()
        try await waitUntil { initialStore.users.first?.isLoading == false }
        XCTAssertTrue(notifications.isEmpty)

        let historicalStore = GitHubEventsStore(
            usernames: ["octocat"],
            cacheStore: cacheStore,
            client: client
        )
        historicalStore.onNewEvents = { _, _, events in
            notifications.append(events.map(\.id))
        }
        historicalStore.loadMore(for: "octocat")
        try await waitUntil { historicalStore.users.first?.isLoadingMore == false }
        XCTAssertTrue(notifications.isEmpty)

        let newEventStore = GitHubEventsStore(
            usernames: ["octocat"],
            cacheStore: cacheStore,
            client: client
        )
        newEventStore.onNewEvents = { _, _, events in
            notifications.append(events.map(\.id))
        }
        newEventStore.refreshAll()
        try await waitUntil { newEventStore.users.first?.isLoading == false }
        XCTAssertEqual(notifications, [["later"]])
    }

    @MainActor
    func testStoreSuppressesRefreshesDuringRateLimitBackoff() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitHubEventsBackoff-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let lock = NSLock()
        var requestCount = 0
        URLProtocolStub.handler = { request in
            lock.lock()
            requestCount += 1
            lock.unlock()
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "120"]
            )!
            return (response, Data("{\"message\":\"slow down\"}".utf8))
        }
        defer { URLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let store = GitHubEventsStore(
            usernames: ["octocat"],
            cacheStore: GitHubEventsDiskCache(directory: directory),
            client: GitHubEventsClient(
                session: URLSession(configuration: configuration),
                token: nil
            )
        )

        store.refreshAll()
        try await waitUntil { store.users.first?.isLoading == false }
        store.refreshAll()
        try await Task.sleep(nanoseconds: 20_000_000)

        lock.lock()
        let requests = requestCount
        lock.unlock()
        XCTAssertEqual(requests, 1)
    }

    @MainActor
    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for GitHub events request")
    }

    private func makeEvent(
        id: String,
        type: String = "WatchEvent",
        payload: [String: JSONValue] = [:],
        createdAt: Date = Date(timeIntervalSince1970: 20)
    ) -> GitHubEvent {
        GitHubEvent(
            id: id,
            type: type,
            actor: GitHubActor(login: "octocat"),
            repo: GitHubRepository(name: "octo/hello"),
            payload: payload,
            createdAt: createdAt
        )
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try XCTUnwrap(Self.handler?(request))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
