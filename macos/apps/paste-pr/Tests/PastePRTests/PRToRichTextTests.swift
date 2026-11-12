import Foundation
import AppKit
import XCTest
@testable import PastePR

final class PRToRichTextTests: XCTestCase {
    func testClipboardChangeTrackerUsesEnableBaseline() {
        var tracker = ClipboardChangeTracker()

        tracker.beginObserving(at: 10)

        XCTAssertFalse(tracker.consumeChange(at: 10))
    }

    func testClipboardChangeTrackerConsumesEachChangeOnce() {
        var tracker = ClipboardChangeTracker()
        tracker.beginObserving(at: 10)

        XCTAssertTrue(tracker.consumeChange(at: 11))
        XCTAssertFalse(tracker.consumeChange(at: 11))
        XCTAssertTrue(tracker.consumeChange(at: 12))
    }

    func testClipboardChangeTrackerObservesAppOwnedWrites() {
        var tracker = ClipboardChangeTracker()
        tracker.beginObserving(at: 10)

        tracker.observeAppOwnedWrite(at: 11)

        XCTAssertFalse(tracker.consumeChange(at: 11))
        XCTAssertTrue(tracker.consumeChange(at: 12))
    }

    func testPullRequestNormalizesURLAndUsesBaseRepository() throws {
        var arguments = [[String]]()
        let result = try PRToRichText.convert(
            prLink: "github.com/owner/base/pull/123/changes?next=https://example.com#files",
            ghRunner: { receivedArguments in
                arguments.append(receivedArguments)
                if receivedArguments[1] == "view" {
                    return Data(#"{"title":"Fix the thing","number":123,"additions":8,"deletions":3}"#.utf8)
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
                "--json", "title,number,additions,deletions",
            ],
            [
                "pr", "diff", "https://github.com/owner/base/pull/123",
                "--exclude", "*.json",
                "--exclude", "*.lock",
                "--exclude", "tests-expanded/*",
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
                    return Data(#"{"title":"Count the diff","number":123,"additions":8,"deletions":3}"#.utf8)
                }
                return Data("""
                diff --git a/file.txt b/file.txt
                index 123..456 100644
                --- a/file.txt
                +++ b/file.txt
                @@ -1,2 +1,2 @@
                --- removed line
                +++ added line
                -removed line
                +added line
                """.utf8)
            }
        )

        XCTAssertEqual(result.markdown, ":github-rainbow: Count the diff [repo#123](https://github.com/owner/repo/pull/123) `+2 -2`")
    }

    func testPullRequestFallsBackToBasicDiffCountsWhenFilteredDiffFails() throws {
        var callCount = 0
        let result = try PRToRichText.convert(
            prLink: "github.com/owner/repo/pull/123",
            ghRunner: { _ in
                callCount += 1
                if callCount == 1 {
                    return Data(#"{"title":"Large generated diff","number":123,"additions":31019,"deletions":21}"#.utf8)
                }
                throw NSError(domain: "PastePRTests", code: 1)
            }
        )

        XCTAssertEqual(
            result.markdown,
            ":github-rainbow: Large generated diff [repo#123](https://github.com/owner/repo/pull/123) `+31019 -21`"
        )
        XCTAssertEqual(
            result.html,
            "<p>:github-rainbow: Large generated diff <a href=\"https://github.com/owner/repo/pull/123\">repo#123</a> <code>+31019 -21</code></p>"
        )
    }

    func testPullRequestExcludesJSONLockAndNestedTestsExpandedFiles() throws {
        var callCount = 0
        let result = try PRToRichText.convert(
            prLink: "github.com/owner/repo/pull/123",
            ghRunner: { _ in
                callCount += 1
                if callCount == 1 {
                    return Data(#"{"title":"Filter the diff","number":123,"additions":2,"deletions":2}"#.utf8)
                }
                return Data("""
                diff --git a/keep.swift b/keep.swift
                index 123..456 100644
                --- a/keep.swift
                +++ b/keep.swift
                @@ -1 +1 @@
                -old
                +new
                diff --git a/config.json b/config.swift
                similarity index 90%
                rename from config.json
                rename to config.swift
                --- a/config.json
                +++ b/config.swift
                @@ -1 +1 @@
                -old renamed
                +new renamed
                diff --git a/settings.json b/settings.json
                index 123..456 100644
                --- a/settings.json
                +++ b/settings.json
                @@ -1 +1 @@
                -old json
                +new json
                diff --git a/package.lock b/package.lock
                index 123..456 100644
                --- a/package.lock
                +++ b/package.lock
                @@ -1 +1 @@
                -old lock
                +new lock
                diff --git a/tests-expanded/unit/generated.swift b/tests-expanded/unit/generated.swift
                index 123..456 100644
                --- a/tests-expanded/unit/generated.swift
                +++ b/tests-expanded/unit/generated.swift
                @@ -1 +1 @@
                -old generated
                +new generated
                diff --git a/src/tests-expanded/generated.swift b/src/tests-expanded/generated.swift
                index 123..456 100644
                --- a/src/tests-expanded/generated.swift
                +++ b/src/tests-expanded/generated.swift
                @@ -1 +1 @@
                -old nested generated
                +new nested generated
                """.utf8)
            }
        )

        XCTAssertEqual(result.markdown, ":github-rainbow: Filter the diff [repo#123](https://github.com/owner/repo/pull/123) `+2 -2`")
    }

    func testStackFormatsAllPullRequestsInStackOrder() throws {
        let result = try PRToRichText.convert(
            prLink: "http://www.github.com/owner/repo/stack/13?tab=changes#top",
            ghRunner: { arguments in
                switch arguments[0] {
                case "api":
                    XCTAssertEqual(arguments, ["api", "repos/owner/repo/stacks/13"])
                    return Data(#"{"pull_requests":[{"number":42},{"number":7}]}"#.utf8)
                case "pr":
                    if arguments[1] == "view" {
                        if arguments[2] == "https://github.com/owner/repo/pull/42" {
                            return Data(#"{"title":"Base <change> & fix","number":42,"additions":9,"deletions":5}"#.utf8)
                        }
                        XCTAssertEqual(arguments[2], "https://github.com/owner/repo/pull/7")
                        return Data(#"{"title":"Follow-up","number":7,"additions":8,"deletions":3}"#.utf8)
                    }
                    if arguments[2] == "https://github.com/owner/repo/pull/7" {
                        throw NSError(domain: "PastePRTests", code: 1)
                    }
                    return Data("""
                    diff --git a/file.swift b/file.swift
                    --- a/file.swift
                    +++ b/file.swift
                    @@ -1 +1,2 @@
                    -old
                    +new
                    +another
                    """.utf8)
                default:
                    XCTFail("Unexpected GitHub CLI command: \(arguments)")
                    return Data()
                }
            }
        )

        XCTAssertEqual(result.markdown, """
        :github-rainbow: Stack of 2 changes [repo#13](https://github.com/owner/repo/stack/13):
        - :one: Base <change> & fix [repo#42](https://github.com/owner/repo/pull/42) `+2 -1`
        - :two: Follow-up [repo#7](https://github.com/owner/repo/pull/7) `+8 -3`
        """)
        XCTAssertEqual(result.html,
            "<p>:github-rainbow: Stack of 2 changes <a href=\"https://github.com/owner/repo/stack/13\">repo#13</a>:</p>" +
            "<ul><li>:one: Base &lt;change&gt; &amp; fix " +
            "<a href=\"https://github.com/owner/repo/pull/42\">repo#42</a> <code>+2 -1</code></li>" +
            "<li>:two: Follow-up <a href=\"https://github.com/owner/repo/pull/7\">repo#7</a> " +
            "<code>+8 -3</code></li></ul>"
        )
    }

    func testStackUsesConfiguredPositionalEmojisAndNumberedFallbacks() throws {
        let settings = SlackEmojiSettings(
            pullRequest: "custom-pr",
            issue: "custom-issue",
            discussion: "custom-discussion",
            stackPullRequests: [" :first: ", " : ", "third"]
        )
        let result = try PRToRichText.convert(
            prLink: "github.com/owner/repo/stack/13",
            ghRunner: { arguments in
                if arguments[0] == "api" {
                    return try JSONSerialization.data(withJSONObject: [
                        "pull_requests": (1...11).map { ["number": $0 + 20] },
                    ])
                }
                if arguments[1] == "view" {
                    let number = Int(URL(string: arguments[2])!.lastPathComponent)!
                    return try JSONSerialization.data(withJSONObject: [
                        "title": "Change \(number)", "number": number, "additions": 0, "deletions": 0,
                    ])
                }
                return Data()
            },
            emojiSettings: settings
        )

        let lines = result.markdown.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 12)
        XCTAssertEqual(lines[0], ":custom-pr: Stack of 11 changes [repo#13](https://github.com/owner/repo/stack/13):")
        for (line, emoji, number) in [
            (1, ":first:", 21), (2, ":two:", 22), (3, ":third:", 23), (4, ":four:", 24),
            (5, ":five:", 25), (6, ":six:", 26), (7, ":seven:", 27), (8, ":eight:", 28),
            (9, ":nine:", 29), (10, ":keycap_ten:", 30), (11, "11.", 31),
        ] {
            XCTAssertEqual(lines[line], "- \(emoji) Change \(number) [repo#\(number)](https://github.com/owner/repo/pull/\(number)) `+0 -0`")
        }
    }

    func testStackDoesNotReturnPartialResultsWhenAPullRequestCannotBeFetched() {
        XCTAssertThrowsError(try PRToRichText.convert(
            prLink: "github.com/owner/repo/stack/13",
            ghRunner: { arguments in
                if arguments[0] == "api" {
                    return Data(#"{"pull_requests":[{"number":42},{"number":7}]}"#.utf8)
                }
                if arguments[2].hasSuffix("/7") {
                    throw NSError(domain: "PastePRTests", code: 1)
                }
                if arguments[1] == "view" {
                    return Data(#"{"title":"Base","number":42,"additions":0,"deletions":0}"#.utf8)
                }
                return Data()
            }
        ))
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
        XCTAssertEqual(result.markdown, ":github-link-issue: Track this [repo#42](https://github.com/owner/repo/issues/42)")
        XCTAssertEqual(result.html, "<p>:github-link-issue: Track this <a href=\"https://github.com/owner/repo/issues/42\">repo#42</a></p>")
    }

    func testDiscussionUsesCanonicalURL() throws {
        var arguments: [String]?
        let result = try PRToRichText.convert(
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
        XCTAssertEqual(result.markdown, ":github-link-discussion: Question [repo#7](https://github.com/owner/repo/discussions/7)")
        XCTAssertEqual(result.html, "<p>:github-link-discussion: Question <a href=\"https://github.com/owner/repo/discussions/7\">repo#7</a></p>")
    }

    func testConversionUsesConfiguredEmojiForEachLinkKind() throws {
        let settings = SlackEmojiSettings(
            pullRequest: "custom-pr",
            issue: "custom-issue",
            discussion: "custom-discussion",
            stackPullRequests: ["custom-stack-pr"]
        )

        var pullRequestCallCount = 0
        let pullRequestResult = try PRToRichText.convert(
            prLink: "github.com/owner/repo/pull/123",
            ghRunner: { _ in
                pullRequestCallCount += 1
                if pullRequestCallCount == 1 {
                    return Data(#"{"title":"Pull request","number":123,"additions":0,"deletions":0}"#.utf8)
                }
                return Data("".utf8)
            },
            emojiSettings: settings
        )

        let issueResult = try PRToRichText.convert(
            prLink: "github.com/owner/repo/issues/42",
            ghRunner: { _ in Data(#"{"title":"Issue","number":42}"#.utf8) },
            emojiSettings: settings
        )

        let discussionResult = try PRToRichText.convert(
            prLink: "github.com/owner/repo/discussions/7",
            ghRunner: { _ in Data(#"{"title":"Discussion","number":7}"#.utf8) },
            emojiSettings: settings
        )

        let stackResult = try PRToRichText.convert(
            prLink: "github.com/owner/repo/stack/13",
            ghRunner: { arguments in
                if arguments[0] == "api" {
                    return Data(#"{"pull_requests":[{"number":123}]}"#.utf8)
                }
                if arguments[1] == "view" {
                    return Data(#"{"title":"Pull request","number":123,"additions":0,"deletions":0}"#.utf8)
                }
                return Data()
            },
            emojiSettings: settings
        )

        XCTAssertEqual(pullRequestResult.markdown, ":custom-pr: Pull request [repo#123](https://github.com/owner/repo/pull/123) `+0 -0`")
        XCTAssertEqual(issueResult.markdown, ":custom-issue: Issue [repo#42](https://github.com/owner/repo/issues/42)")
        XCTAssertEqual(discussionResult.markdown, ":custom-discussion: Discussion [repo#7](https://github.com/owner/repo/discussions/7)")
        XCTAssertEqual(stackResult.markdown, """
        :custom-pr: Stack of 1 changes [repo#13](https://github.com/owner/repo/stack/13):
        - :custom-stack-pr: Pull request [repo#123](https://github.com/owner/repo/pull/123) `+0 -0`
        """)
    }

    func testSlackEmojiSettingsPersistNormalizedNames() throws {
        let suiteName = "PastePRTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(SlackEmojiSettings(userDefaults: userDefaults), .standard)

        let settings = SlackEmojiSettings(
            pullRequest: " :custom-pr: ",
            issue: "custom-issue",
            discussion: ":custom-discussion",
            stackPullRequests: [" :first: ", "", ":third"]
        )
        settings.save(to: userDefaults)

        XCTAssertEqual(
            SlackEmojiSettings(userDefaults: userDefaults),
            SlackEmojiSettings(
                pullRequest: "custom-pr",
                issue: "custom-issue",
                discussion: "custom-discussion",
                stackPullRequests: ["first", "", "third"]
            )
        )
    }

    func testExistingEmojiPreferencesKeepStandaloneChoiceAndUseNewStackDefaults() throws {
        let suiteName = "PastePRTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        userDefaults.set("existing-pr", forKey: "SlackEmojiPullRequest")

        let settings = SlackEmojiSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.pullRequestEmoji, ":existing-pr:")
        XCTAssertEqual(settings.stackPullRequestEmoji(at: 0), ":one:")
        XCTAssertEqual(settings.stackPullRequestEmoji(at: 1), ":two:")
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

    func testMultipleLinksAreSeparatedByNewlinesInInputOrder() throws {
        let links = [
            "https://github.com/owner/base/pull/123/changes",
            "github.com/other/project/issues/42",
            "http://www.github.com/owner/base/discussions/7?answer=1",
            "github.com/owner/base/stack/13",
        ]
        for separator in [" ", "\n", "\r\n", "\t", " \n\t\u{00A0}"] {
            let result = try PRToRichText.convert(
                prLink: " \t" + links.joined(separator: separator) + "\n ",
                ghRunner: { arguments in
                    switch arguments[0] {
                    case "pr":
                        if arguments[1] == "diff" { return Data() }
                        return Data(#"{"title":"Fix <thing>","number":123,"additions":0,"deletions":0}"#.utf8)
                    case "issue":
                        return Data(#"{"title":"Track & fix","number":42}"#.utf8)
                    case "discussion":
                        return Data(#"{"title":"Question","number":7}"#.utf8)
                    case "api":
                        return Data(#"{"pull_requests":[{"number":123}]}"#.utf8)
                    default:
                        throw NSError(domain: "PastePRTests", code: 1)
                    }
                }
            )

            XCTAssertEqual(result.markdown, """
            :github-rainbow: Fix <thing> [base#123](https://github.com/owner/base/pull/123) `+0 -0`
            :github-link-issue: Track & fix [project#42](https://github.com/other/project/issues/42)
            :github-link-discussion: Question [base#7](https://github.com/owner/base/discussions/7)
            :github-rainbow: Stack of 1 changes [base#13](https://github.com/owner/base/stack/13):
            - :one: Fix <thing> [base#123](https://github.com/owner/base/pull/123) `+0 -0`
            """)
            XCTAssertEqual(result.html, """
            <p>:github-rainbow: Fix &lt;thing&gt; <a href="https://github.com/owner/base/pull/123">base#123</a> <code>+0 -0</code></p>
            <p>:github-link-issue: Track &amp; fix <a href="https://github.com/other/project/issues/42">project#42</a></p>
            <p>:github-link-discussion: Question <a href="https://github.com/owner/base/discussions/7">base#7</a></p>
            <p>:github-rainbow: Stack of 1 changes <a href="https://github.com/owner/base/stack/13">base#13</a>:</p><ul><li>:one: Fix &lt;thing&gt; <a href="https://github.com/owner/base/pull/123">base#123</a> <code>+0 -0</code></li></ul>
            """)
        }
    }

    func testMultipleLinksAreValidatedBeforeFetching() {
        var invoked = false
        for input in [
            "github.com/owner/repo/issues/42 https://gitlab.com/owner/repo/issues/7",
            "github.com/owner/repo/issues/42 extra text",
            " \n\t",
            "",
        ] {
            XCTAssertFalse(PRToRichText.isSupportedGitHubLink(input))
            XCTAssertThrowsError(try PRToRichText.convert(
                prLink: input,
                ghRunner: { _ in
                    invoked = true
                    return Data()
                }
            ))
        }
        XCTAssertFalse(invoked)
    }

    func testMultipleLinksDoNotReturnPartialResultsWhenFetchingFails() {
        XCTAssertThrowsError(try PRToRichText.convert(
            prLink: "github.com/owner/repo/issues/42 github.com/owner/repo/issues/7",
            ghRunner: { arguments in
                if arguments[2].hasSuffix("/7") {
                    throw NSError(domain: "PastePRTests", code: 1)
                }
                return Data(#"{"title":"Track this","number":42}"#.utf8)
            }
        ))
    }

    func testSupportedGitHubLinkDetection() {
        XCTAssertTrue(PRToRichText.isSupportedGitHubLink("github.com/owner/repo/pull/42"))
        XCTAssertTrue(PRToRichText.isSupportedGitHubLink("https://github.com/owner/repo/issues/42/comments"))
        XCTAssertTrue(PRToRichText.isSupportedGitHubLink("https://www.github.com/owner/repo/discussions/42?answer=1"))
        XCTAssertTrue(PRToRichText.isSupportedGitHubLink("github.com/stellar/stellar-asset-contract-spec/stack/13"))
        XCTAssertTrue(PRToRichText.isSupportedGitHubLink(" \tgithub.com/owner/repo/pull/42 \n\t github.com/other/project/issues/7\r\n"))
    }

    func testUnsupportedGitHubLinkDetection() {
        XCTAssertFalse(PRToRichText.isSupportedGitHubLink("https://gitlab.com/owner/repo/issues/42"))
        XCTAssertFalse(PRToRichText.isSupportedGitHubLink("https://github.com/owner/repo"))
        XCTAssertFalse(PRToRichText.isSupportedGitHubLink("https://github.com/owner/repo/pull/42 extra text"))
        XCTAssertFalse(PRToRichText.isSupportedGitHubLink("https://github.com/owner/repo/stack/0"))
        XCTAssertFalse(PRToRichText.isSupportedGitHubLink("https://github.com/owner/repo/stack/not-a-number"))
    }

    func testClipboardKeepsOriginalPlainTextAndWritesRichHTML() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let result = PRToRichText.Result(
            markdown: "formatted markdown",
            html: "<p>formatted HTML</p>"
        )
        var observedChangeCount: Int?

        XCTAssertEqual(writeConversionResult(
            result,
            originalInput: "github.com/owner/repo/issues/42",
            to: pasteboard,
            onAppOwnedChangeCount: { observedChangeCount = $0 }
        ), .written)
        XCTAssertEqual(observedChangeCount, pasteboard.changeCount)
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

    func testSuccessfulWriteThatMutatesPasteboardReturnsStale() {
        let pasteboard = NSPasteboard.withUniqueName()
        XCTAssertTrue(pasteboard.setString("original", forType: .string))
        let result = PRToRichText.Result(markdown: "formatted", html: "<p>formatted</p>")

        let writeResult = writeConversionResult(
            result,
            originalInput: "original",
            to: pasteboard,
            writeObjects: { items in
                guard pasteboard.writeObjects(items) else { return false }
                XCTAssertTrue(pasteboard.setString("mutated", forType: .string))
                return true
            }
        )

        XCTAssertEqual(writeResult, .stale)
        XCTAssertEqual(pasteboard.string(forType: .string), "mutated")
    }

    func testMutationBeforePasteboardWriteReturnsStaleWithoutClaimingOwnership() {
        let pasteboard = NSPasteboard.withUniqueName()
        XCTAssertTrue(pasteboard.setString("original", forType: .string))
        let result = PRToRichText.Result(markdown: "formatted", html: "<p>formatted</p>")
        var observedChangeCount: Int?

        let writeResult = writeConversionResult(
            result,
            originalInput: "original",
            to: pasteboard,
            writeObjects: { items in
                _ = pasteboard.declareTypes([.string], owner: nil)
                XCTAssertTrue(pasteboard.setString("mutated before write", forType: .string))
                return pasteboard.writeObjects(items)
            },
            onAppOwnedChangeCount: { observedChangeCount = $0 }
        )

        XCTAssertEqual(writeResult, .stale)
        XCTAssertNil(observedChangeCount)
    }

    func testClipboardSnapshotRestoresMultipleRepresentations() {
        let pasteboard = NSPasteboard.withUniqueName()
        let item = NSPasteboardItem()
        XCTAssertTrue(item.setString("<p>original</p>", forType: .html))
        XCTAssertTrue(item.setString("original", forType: .string))
        XCTAssertTrue(pasteboard.writeObjects([item]))

        let snapshot = PasteboardSnapshot(from: pasteboard)
        pasteboard.clearContents()
        let expectedRestoredChangeCount = pasteboard.changeCount + 1

        XCTAssertEqual(
            snapshot.restore(to: pasteboard),
            .restored(changeCount: expectedRestoredChangeCount)
        )
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
        var observedChangeCount: Int?

        let writeResult = writeConversionResult(
            result,
            originalInput: "original",
            to: pasteboard,
            writeObjects: { _ in false },
            restoreWriteObjects: { _ in false },
            onAppOwnedChangeCount: { observedChangeCount = $0 }
        )

        XCTAssertEqual(writeResult, .failed)
        XCTAssertEqual(observedChangeCount, pasteboard.changeCount)
        XCTAssertEqual(pasteboard.string(forType: .string), "original")
    }

    func testFailedWriteRestoresSnapshotAndReportsOwnership() {
        let pasteboard = NSPasteboard.withUniqueName()
        XCTAssertTrue(pasteboard.setString("original", forType: .string))
        let result = PRToRichText.Result(markdown: "formatted", html: "<p>formatted</p>")
        var observedChangeCount: Int?

        let writeResult = writeConversionResult(
            result,
            originalInput: "original",
            to: pasteboard,
            writeObjects: { _ in false },
            onAppOwnedChangeCount: { observedChangeCount = $0 }
        )

        XCTAssertEqual(writeResult, .failed)
        XCTAssertEqual(observedChangeCount, pasteboard.changeCount)
        XCTAssertEqual(pasteboard.string(forType: .string), "original")
    }

    func testRecoveryMutationReturnsStaleWithoutFallback() {
        let pasteboard = NSPasteboard.withUniqueName()
        XCTAssertTrue(pasteboard.setString("original", forType: .string))
        let result = PRToRichText.Result(markdown: "formatted", html: "<p>formatted</p>")
        var observedChangeCount: Int?

        let writeResult = writeConversionResult(
            result,
            originalInput: "original",
            to: pasteboard,
            writeObjects: { _ in false },
            restoreWriteObjects: { _ in
                _ = pasteboard.declareTypes([.string], owner: nil)
                XCTAssertTrue(pasteboard.setString("new", forType: .string))
                return false
            },
            onAppOwnedChangeCount: { observedChangeCount = $0 }
        )

        XCTAssertEqual(writeResult, .stale)
        XCTAssertNil(observedChangeCount)
        XCTAssertEqual(pasteboard.string(forType: .string), "new")
    }
}
