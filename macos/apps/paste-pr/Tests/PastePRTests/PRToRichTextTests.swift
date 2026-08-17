import Foundation
import AppKit
import XCTest
@testable import PastePR

final class PRToRichTextTests: XCTestCase {
    func testPullRequestNormalizesURLAndUsesBaseRepository() throws {
        var arguments = [[String]]()
        let result = try PRToRichText.convert(
            prLink: "github.com/owner/base/pull/123/changes?next=https://example.com#files",
            ghRunner: { receivedArguments in
                arguments.append(receivedArguments)
                if receivedArguments[1] == "view" {
                    return Data(#"{"title":"Fix the thing","number":123}"#.utf8)
                }
                return Data("""
                diff --git a/file.swift b/file.swift
                index 123..456 100644
                --- a/file.swift
                +++ b/file.swift
                @@ -1 +1 @@
                -old
                +new
                """.utf8)
            }
        )

        XCTAssertEqual(arguments, [
            [
                "pr", "view", "https://github.com/owner/base/pull/123",
                "--json", "title,number",
            ],
            [
                "pr", "diff", "https://github.com/owner/base/pull/123",
                "--exclude", "*.json",
                "--exclude", "*.lock",
            ],
        ])
        XCTAssertEqual(result.markdown, ":github-rainbow: Fix the thing [base#123](https://github.com/owner/base/pull/123) `+1 -1`")
    }

    func testPullRequestCountsChangedLinesThatBeginWithDiffCharacters() throws {
        var callCount = 0
        let result = try PRToRichText.convert(
            prLink: "github.com/owner/repo/pull/123",
            ghRunner: { _ in
                callCount += 1
                if callCount == 1 {
                    return Data(#"{"title":"Count the diff","number":123}"#.utf8)
                }
                return Data("""
                --- a/file.txt
                +++ b/file.txt
                @@ -1,2 +1,2 @@
                --removed line
                ++added line
                -removed line
                +added line
                """.utf8)
            }
        )

        XCTAssertEqual(result.markdown, ":github-rainbow: Count the diff [repo#123](https://github.com/owner/repo/pull/123) `+2 -2`")
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
        let pasteboard = NSPasteboard.withUniqueName()
        let result = PRToRichText.Result(
            markdown: "formatted markdown",
            html: "<p>formatted HTML</p>"
        )

        XCTAssertEqual(writeConversionResult(
            result,
            originalInput: "github.com/owner/repo/issues/42",
            to: pasteboard
        ), .written)
        XCTAssertEqual(
            pasteboard.string(forType: .string),
            "github.com/owner/repo/issues/42"
        )
        XCTAssertEqual(pasteboard.string(forType: .html), "<p>formatted HTML</p>")
    }

    func testClipboardDoesNotOverwriteChangedContents() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let result = PRToRichText.Result(
            markdown: "formatted markdown",
            html: "<p>formatted HTML</p>"
        )
        let originalChangeCount = pasteboard.changeCount
        XCTAssertTrue(pasteboard.setString("new clipboard input", forType: .string))

        XCTAssertEqual(writeConversionResult(
            result,
            originalInput: "old clipboard input",
            expectedChangeCount: originalChangeCount,
            to: pasteboard
        ), .stale)
        XCTAssertEqual(pasteboard.string(forType: .string), "new clipboard input")
    }

    func testClipboardSnapshotRestoresMultipleRepresentations() {
        let pasteboard = NSPasteboard.withUniqueName()
        let item = NSPasteboardItem()
        XCTAssertTrue(item.setString("<p>original</p>", forType: .html))
        XCTAssertTrue(item.setString("original", forType: .string))
        XCTAssertTrue(pasteboard.writeObjects([item]))

        let snapshot = PasteboardSnapshot(from: pasteboard)
        pasteboard.clearContents()

        XCTAssertEqual(snapshot.restore(to: pasteboard), .restored)
        XCTAssertEqual(pasteboard.string(forType: .html), "<p>original</p>")
        XCTAssertEqual(pasteboard.string(forType: .string), "original")
    }

    func testEmptyClipboardSnapshotReportsFailedRestore() {
        let pasteboard = NSPasteboard.withUniqueName()
        let snapshot = PasteboardSnapshot(from: pasteboard)

        XCTAssertEqual(
            snapshot.restore(to: pasteboard),
            .failed(expectedChangeCount: pasteboard.changeCount)
        )
    }

    func testClipboardSnapshotReportsFailedWrite() {
        let pasteboard = NSPasteboard.withUniqueName()
        let item = NSPasteboardItem()
        XCTAssertTrue(item.setString("original", forType: .string))
        XCTAssertTrue(pasteboard.writeObjects([item]))
        let snapshot = PasteboardSnapshot(from: pasteboard)
        let expectedChangeCount = pasteboard.changeCount

        let result = snapshot.restore(
            to: pasteboard,
            expectedChangeCount: expectedChangeCount,
            writeObjects: { _ in false }
        )

        guard case .failed = result else {
            return XCTFail("expected a failed restore")
        }
    }

    func testFailedWriteFallsBackToOriginalPlainText() {
        let pasteboard = NSPasteboard.withUniqueName()
        XCTAssertTrue(pasteboard.setString("original", forType: .string))
        let result = PRToRichText.Result(markdown: "formatted", html: "<p>formatted</p>")

        let writeResult = writeConversionResult(
            result,
            originalInput: "original",
            to: pasteboard,
            writeObjects: { _ in false },
            restoreWriteObjects: { _ in false }
        )

        XCTAssertEqual(writeResult, .failed)
        XCTAssertEqual(pasteboard.string(forType: .string), "original")
    }

    func testRecoveryMutationReturnsStaleWithoutFallback() {
        let pasteboard = NSPasteboard.withUniqueName()
        XCTAssertTrue(pasteboard.setString("original", forType: .string))
        let result = PRToRichText.Result(markdown: "formatted", html: "<p>formatted</p>")

        let writeResult = writeConversionResult(
            result,
            originalInput: "original",
            to: pasteboard,
            writeObjects: { _ in false },
            restoreWriteObjects: { _ in
                XCTAssertTrue(pasteboard.setString("new", forType: .string))
                return false
            }
        )

        XCTAssertEqual(writeResult, .stale)
        XCTAssertEqual(pasteboard.string(forType: .string), "new")
    }
}
