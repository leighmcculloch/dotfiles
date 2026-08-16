import Foundation
import XCTest
@testable import PastePR

final class PRToRichTextTests: XCTestCase {
    func testPullRequestNormalizesURLAndUsesBaseRepository() throws {
        var arguments: [String]?
        let result = try PRToRichText.convert(
            prLink: "github.com/owner/base/pull/123/changes?next=https://example.com#files",
            ghRunner: { receivedArguments in
                arguments = receivedArguments
                return Data(#"{"title":"Fix the thing","number":123,"additions":4,"deletions":2}"#.utf8)
            }
        )

        XCTAssertEqual(arguments, [
            "pr", "view", "https://github.com/owner/base/pull/123",
            "--json", "title,number,additions,deletions",
        ])
        XCTAssertEqual(result.markdown, ":github-rainbow: Fix the thing [base#123](https://github.com/owner/base/pull/123) `+4 -2`")
    }

    func testIssueUsesCanonicalURL() throws {
        var arguments: [String]?
        let result = try PRToRichText.convert(
            prLink: "http://www.github.com/owner/repo/issues/42/comments",
            ghRunner: { receivedArguments in
                arguments = receivedArguments
                return Data(#"{"title":"Track this","number":42}"#.utf8)
            }
        )

        XCTAssertEqual(arguments, [
            "issue", "view", "https://github.com/owner/repo/issues/42",
            "--json", "title,number",
        ])
        XCTAssertEqual(result.html, "<p>:github-rainbow: Track this <a href=\"https://github.com/owner/repo/issues/42\">repo#42</a></p>")
    }

    func testDiscussionUsesCanonicalURL() throws {
        var arguments: [String]?
        _ = try PRToRichText.convert(
            prLink: "github.com/owner/repo/discussions/7/answer",
            ghRunner: { receivedArguments in
                arguments = receivedArguments
                return Data(#"{"title":"Question","number":7}"#.utf8)
            }
        )

        XCTAssertEqual(arguments, [
            "discussion", "view", "https://github.com/owner/repo/discussions/7",
            "--json", "title,number",
        ])
    }

    func testUnsupportedHostDoesNotInvokeGitHubCLI() {
        var invoked = false

        XCTAssertThrowsError(try PRToRichText.convert(
            prLink: "https://gitlab.com/owner/repo/issues/42",
            ghRunner: { _ in
                invoked = true
                return Data()
            }
        ))
        XCTAssertFalse(invoked)
    }

    func testClipboardKeepsOriginalPlainTextAndWritesRichHTML() throws {
        let pasteboard = try XCTUnwrap(NSPasteboard(name: .init("PastePRTests")))
        let result = PRToRichText.Result(
            markdown: "formatted markdown",
            html: "<p>formatted HTML</p>"
        )

        XCTAssertTrue(writeConversionResult(
            result,
            originalInput: "github.com/owner/repo/issues/42",
            to: pasteboard
        ))
        XCTAssertEqual(
            pasteboard.string(forType: .string),
            "github.com/owner/repo/issues/42"
        )
        XCTAssertEqual(pasteboard.string(forType: .html), "<p>formatted HTML</p>")
    }
}
