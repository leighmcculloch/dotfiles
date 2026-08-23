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
        XCTAssertEqual(cache.nextPage, 2)
        XCTAssertEqual(cache.fetchedPages, [1])
        XCTAssertEqual(cache.pageETags[1], "etag-3")
        XCTAssertEqual(cache.pageETags[2], "etag-2")
        XCTAssertEqual(cache.pageLastModified[2], "yesterday")
        XCTAssertFalse(cache.exhausted)
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
