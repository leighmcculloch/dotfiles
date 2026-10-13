import Foundation
import XCTest
@testable import AppScheduler

final class SchedulerTests: XCTestCase {
    private var brisbane: Calendar { calendar("Australia/Brisbane") }

    func testMenuSummariesDescribeActiveDisabledAndIncompleteSchedules() {
        var rule = schedule(hour: 9, minute: 7)
        XCTAssertEqual(rule.menuSummary, "Open Test — 7 9 * * 1,2,3,4,5")
        rule.action = .quit
        rule.cron = "23 17 * * 0,1,4"
        rule.isEnabled = false
        XCTAssertEqual(rule.menuSummary, "Quit Test — 23 17 * * 0,1,4 (disabled)")

        rule.isEnabled = true
        rule.action = .open
        rule.appURL = "  slack://channel?team=T1&id=C2  "
        rule.cron = "*/15 * * * *"
        XCTAssertEqual(rule.menuSummary, "Open slack://channel?team=T1&id=C2 — */15 * * * *")

        rule.appURL = ""
        rule.cron = ""
        XCTAssertEqual(rule.menuSummary, "Open No URL entered — No cron entered (incomplete)")
        rule.appURL = nil
        rule.appPath = ""
        XCTAssertEqual(rule.menuSummary, "Open No app selected — No cron entered (incomplete)")
    }

    func testMenuSummaryKeepsLongTargetsCompactWithoutChangingTheURL() {
        var rule = schedule(hour: 12, minute: 34, days: [4])
        let target = "https://example.com/abcdefghijklmnopqrstuvwxyz01"
        rule.appURL = target
        XCTAssertEqual(rule.menuSummary, "Open https://example.com/abcdefghijklmnopqrstuvwxyz01 — 34 12 * * 3")
        rule.appURL = target + "2"
        XCTAssertEqual(rule.menuSummary, "Open https://example.com/abcdefghijklmnopqrstuvwxyz0… — 34 12 * * 3")
        XCTAssertEqual(rule.targetName, target + "2")
    }

    func testExactTimeFiresOnceAndNotBefore() {
        let rule = schedule(hour: 9, minute: 7, days: [2])
        var scheduler = Scheduler(at: date("2026-10-05T09:06:40+10:00"))
        XCTAssertTrue(scheduler.dueActions([rule], at: date("2026-10-05T09:06:59+10:00"), calendar: brisbane).isEmpty)
        XCTAssertEqual(
            scheduler.dueActions([rule], at: date("2026-10-05T09:07:00+10:00"), calendar: brisbane),
            [ScheduledEvent(schedule: rule, date: date("2026-10-05T09:07:00+10:00"))]
        )
        XCTAssertTrue(scheduler.dueActions([rule], at: date("2026-10-05T09:07:00+10:00"), calendar: brisbane).isEmpty)
        XCTAssertTrue(scheduler.dueActions([rule], at: date("2026-10-05T09:07:15+10:00"), calendar: brisbane).isEmpty)
    }

    func testWeekdaysExcludeWeekendButCanSelectSunday() {
        let weekday = schedule(hour: 9, minute: 0)
        var scheduler = Scheduler(at: date("2026-10-09T09:00:01+10:00"))
        XCTAssertTrue(scheduler.dueActions([weekday], at: date("2026-10-11T12:00:00+10:00"), calendar: brisbane).isEmpty)
        XCTAssertEqual(scheduler.dueActions([weekday], at: date("2026-10-12T09:00:00+10:00"), calendar: brisbane).map(\.schedule.id), [weekday.id])

        let sunday = schedule(hour: 9, minute: 0, days: [1])
        var sundayScheduler = Scheduler(at: date("2026-10-10T08:00:00+10:00"))
        XCTAssertTrue(sundayScheduler.dueActions([sunday], at: date("2026-10-10T10:00:00+10:00"), calendar: brisbane).isEmpty)
        XCTAssertEqual(sundayScheduler.dueActions([sunday], at: date("2026-10-11T09:00:00+10:00"), calendar: brisbane).map(\.schedule.id), [sunday.id])
    }

    func testMultipleActionsForSameAppWorkAtSeparateTimes() {
        let open = schedule(hour: 9, minute: 0)
        let quit = schedule(action: .quit, hour: 17, minute: 30)
        var scheduler = Scheduler(at: date("2026-10-05T08:59:50+10:00"))
        XCTAssertEqual(scheduler.dueActions([open, quit], at: date("2026-10-05T09:00:05+10:00"), calendar: brisbane).map(\.schedule), [open])
        XCTAssertEqual(scheduler.dueActions([open, quit], at: date("2026-10-05T17:30:10+10:00"), calendar: brisbane).map(\.schedule), [quit])
    }

    func testWakeUsesLatestActionPerAppRegardlessOfRowOrder() {
        let open = schedule(hour: 9, minute: 0)
        let quit = schedule(action: .quit, hour: 17, minute: 30)
        let other = schedule(path: "/Applications/Other.app", hour: 12, minute: 45)
        for rules in [[quit, other, open], [open, other, quit]] {
            var scheduler = Scheduler(at: date("2026-10-05T08:00:00+10:00"))
            XCTAssertEqual(
                scheduler.dueActions(rules, at: date("2026-10-05T18:00:00+10:00"), calendar: brisbane).map(\.schedule),
                [other, quit]
            )
            XCTAssertTrue(scheduler.dueActions(rules, at: date("2026-10-05T18:00:15+10:00"), calendar: brisbane).isEmpty)
        }
    }

    func testLongSleepFindsLastWeeksOccurrenceBeforeTodaysTime() {
        let rule = schedule(action: .quit, hour: 17, minute: 30, days: [5])
        var scheduler = Scheduler(at: date("2026-09-01T00:00:00+10:00"))
        XCTAssertEqual(
            scheduler.dueActions([rule], at: date("2026-10-08T08:00:00+10:00"), calendar: brisbane),
            [ScheduledEvent(schedule: rule, date: date("2026-10-01T17:30:00+10:00"))]
        )
    }

    func testSameTimeLastRowWinsWithoutConflatingDifferentAppPaths() {
        let open = schedule(hour: 9, minute: 0)
        let quit = schedule(action: .quit, hour: 9, minute: 0)
        let otherCopy = schedule(path: "/Users/test/Applications/Test.app", hour: 9, minute: 0)
        var scheduler = Scheduler(at: date("2026-10-05T08:59:59+10:00"))
        XCTAssertEqual(
            scheduler.dueActions([open, quit, otherCopy], at: date("2026-10-05T09:00:00+10:00"), calendar: brisbane).map(\.schedule),
            [quit, otherCopy]
        )
    }

    func testInactiveAndIncompleteRulesDoNotRun() {
        var disabled = schedule(hour: 9, minute: 0)
        disabled.isEnabled = false
        let noDays = schedule(hour: 9, minute: 0, days: [])
        let noApp = schedule(path: "", hour: 9, minute: 0)
        let invalidHour = schedule(hour: 24, minute: 0)
        let invalidMinute = schedule(hour: 9, minute: 60)
        var scheduler = Scheduler(at: date("2026-10-05T08:00:00+10:00"))
        XCTAssertTrue(scheduler.dueActions([disabled, noDays, noApp, invalidHour, invalidMinute], at: date("2026-10-05T10:00:00+10:00"), calendar: brisbane).isEmpty)
    }

    func testStartupAndConfigurationResetDoNotReplayPastActions() {
        let rule = schedule(hour: 9, minute: 0)
        var scheduler = Scheduler(at: date("2026-10-05T09:00:00+10:00"))
        XCTAssertTrue(scheduler.dueActions([rule], at: date("2026-10-05T09:00:15+10:00"), calendar: brisbane).isEmpty)

        scheduler.reset(at: date("2026-10-06T10:00:00+10:00"))
        XCTAssertTrue(scheduler.dueActions([rule], at: date("2026-10-06T10:00:15+10:00"), calendar: brisbane).isEmpty)
        XCTAssertEqual(scheduler.dueActions([rule], at: date("2026-10-07T09:00:00+10:00"), calendar: brisbane).map(\.schedule.id), [rule.id])
    }

    func testMovingClockBackwardsDoesNotRunSameActionAgain() {
        let rule = schedule(hour: 9, minute: 0)
        var scheduler = Scheduler(at: date("2026-10-05T08:59:50+10:00"))
        XCTAssertEqual(scheduler.dueActions([rule], at: date("2026-10-05T09:00:10+10:00"), calendar: brisbane).count, 1)
        XCTAssertTrue(scheduler.dueActions([rule], at: date("2026-10-05T08:59:00+10:00"), calendar: brisbane).isEmpty)
        XCTAssertTrue(scheduler.dueActions([rule], at: date("2026-10-05T09:00:15+10:00"), calendar: brisbane).isEmpty)
    }

    func testMidnightUsesNewDaysWeekdayAndLocalTimeNotUTC() {
        let rule = schedule(hour: 0, minute: 0, days: [2])
        var scheduler = Scheduler(at: date("2026-10-04T23:59:59+10:00"))
        XCTAssertEqual(
            scheduler.dueActions([rule], at: date("2026-10-05T00:00:00+10:00"), calendar: brisbane),
            [ScheduledEvent(schedule: rule, date: date("2026-10-04T14:00:00Z"))]
        )
    }

    func testDSTSkippedTimeRunsAtNextValidTime() {
        let rule = schedule(hour: 2, minute: 30, days: [1])
        let sydney = calendar("Australia/Sydney")
        var scheduler = Scheduler(at: date("2026-10-04T01:59:59+10:00"))
        XCTAssertEqual(
            scheduler.dueActions([rule], at: date("2026-10-04T03:00:00+11:00"), calendar: sydney),
            [ScheduledEvent(schedule: rule, date: date("2026-10-04T03:00:00+11:00"))]
        )
    }

    func testDSTRepeatedTimeRunsOnlyAtFirstOccurrence() {
        let rule = schedule(hour: 2, minute: 30, days: [1])
        let sydney = calendar("Australia/Sydney")
        var scheduler = Scheduler(at: date("2026-04-05T02:29:59+11:00"))
        XCTAssertEqual(
            scheduler.dueActions([rule], at: date("2026-04-05T02:30:00+11:00"), calendar: sydney),
            [ScheduledEvent(schedule: rule, date: date("2026-04-05T02:30:00+11:00"))]
        )
        XCTAssertTrue(scheduler.dueActions([rule], at: date("2026-04-05T02:30:00+10:00"), calendar: sydney).isEmpty)

        // Waking in the second 2am hour must still catch the first occurrence,
        // even though the current wall-clock minute is earlier than the rule.
        var sleeping = Scheduler(at: date("2026-04-05T01:59:59+11:00"))
        XCTAssertEqual(
            sleeping.dueActions([rule], at: date("2026-04-05T02:15:00+10:00"), calendar: sydney),
            [ScheduledEvent(schedule: rule, date: date("2026-04-05T02:30:00+11:00"))]
        )
    }

    func testPersistenceKeepsIndependentRowsAndEveryField() throws {
        let open = schedule(hour: 8, minute: 23, days: [2, 4, 6])
        var quit = schedule(action: .quit, hour: 19, minute: 47, days: [1, 7])
        quit.isEnabled = false
        let rows = [open, quit]
        XCTAssertNotEqual(open.id, quit.id)
        let restored = try JSONDecoder().decode([ScheduledAction].self, from: JSONEncoder().encode(rows))
        XCTAssertEqual(restored, rows)
        XCTAssertEqual(restored[0].appName, "Test")
    }

    func testLegacyAppSchedulesDecodeWithoutURLField() throws {
        let data = Data("""
        [{"id":"00000000-0000-0000-0000-000000000001",
          "appPath":"/Applications/Test.app","action":"quit",
          "hour":17,"minute":23,"weekdays":[2,4,6],"isEnabled":true}]
        """.utf8)
        let restored = try XCTUnwrap(JSONDecoder().decode([ScheduledAction].self, from: data).first)
        XCTAssertNil(restored.appURL)
        XCTAssertEqual(restored.appPath, "/Applications/Test.app")
        XCTAssertEqual(restored.action, .quit)
        XCTAssertEqual(restored.cron, "23 17 * * 1,3,5")
        XCTAssertTrue(restored.isActive)
        var scheduler = Scheduler(at: date("2026-10-07T17:22:59+10:00"))
        XCTAssertEqual(scheduler.dueActions([restored], at: date("2026-10-07T17:23:00+10:00"), calendar: brisbane).map(\.schedule), [restored])
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String: Any])
        XCTAssertEqual(saved["cron"] as? String, restored.cron)
        XCTAssertNil(saved["weekdays"])
    }

    func testURLsRequireASchemeAndPreserveEncodedParameters() {
        var rule = schedule(hour: 9, minute: 0)
        let valid = [
            ("slack://", "slack://"),
            ("  myapp://run?message=hello%20world&value=one%2Ftwo\n", "myapp://run?message=hello%20world&value=one%2Ftwo"),
            ("https://example.com/path?x=1&y=2", "https://example.com/path?x=1&y=2")
        ]
        for (input, expected) in valid {
            rule.appURL = input
            XCTAssertEqual(rule.urlToOpen?.absoluteString, expected)
            XCTAssertEqual(rule.targetName, expected)
            XCTAssertTrue(rule.isActive)
        }
        for invalid in ["", " \n", "example.com/path", "/Applications/Test.app", "not a url", "myapp://hello world", "://missing"] {
            rule.appURL = invalid
            XCTAssertNil(rule.urlToOpen, invalid)
            // A previously selected app must never be a fallback for a bad URL.
            XCTAssertFalse(rule.isActive, invalid)
        }
        rule.appURL = "myapp://run"
        rule.action = .quit
        XCTAssertFalse(rule.isActive)
    }

    func testURLSchedulesStayIndependentAndRepeatAtDifferentTimes() {
        var early = schedule(hour: 9, minute: 0)
        early.appURL = "slack://channel?team=T1&id=C1"
        var late = early
        late.id = UUID()
        late.cron = "0 13 * * 1-5"
        var differentURL = early
        differentURL.id = UUID()
        differentURL.appURL = "slack://channel?team=T1&id=C2"
        differentURL.cron = "0 11 * * 1-5"
        let appQuit = schedule(action: .quit, hour: 17, minute: 0)
        let rules = [late, differentURL, appQuit, early]
        var scheduler = Scheduler(at: date("2026-10-05T08:00:00+10:00"))
        XCTAssertEqual(scheduler.dueActions(rules, at: date("2026-10-05T09:00:05+10:00"), calendar: brisbane).map(\.schedule), [early])
        XCTAssertEqual(scheduler.dueActions(rules, at: date("2026-10-05T14:00:00+10:00"), calendar: brisbane).map(\.schedule), [differentURL, late])

        var sleepingScheduler = Scheduler(at: date("2026-10-05T08:00:00+10:00"))
        XCTAssertEqual(sleepingScheduler.dueActions(rules, at: date("2026-10-05T18:00:00+10:00"), calendar: brisbane).map(\.schedule), [differentURL, late, appQuit])
        XCTAssertTrue(sleepingScheduler.dueActions(rules, at: date("2026-10-05T18:00:15+10:00"), calendar: brisbane).isEmpty)
    }

    func testPersistencePreservesURLAndUnfinishedURLMode() throws {
        var urlRule = schedule(hour: 10, minute: 31, days: [1, 5])
        urlRule.appURL = "myapp://open?document=hello%20world"
        var unfinished = schedule(hour: 12, minute: 5)
        unfinished.appURL = ""
        let rows = [urlRule, unfinished, schedule(action: .quit, hour: 18, minute: 42)]
        let restored = try JSONDecoder().decode([ScheduledAction].self, from: JSONEncoder().encode(rows))
        XCTAssertEqual(restored, rows)
        XCTAssertEqual(restored[0].appURL, "myapp://open?document=hello%20world")
        XCTAssertEqual(restored[1].appURL, "")
        XCTAssertFalse(restored[1].isActive)
        XCTAssertNil(restored[2].appURL)
    }

    func testCronIntervalsListsAndSteppedRangesRepeatOnlyAtMatchingMinutes() {
        var rule = schedule(hour: 9, minute: 0)
        rule.cron = "7-47/20 8,13 * 10 1-5"
        var scheduler = Scheduler(at: date("2026-10-05T08:06:59+10:00"))
        for time in ["08:07", "08:27", "08:47", "13:07"] {
            let now = date("2026-10-05T\(time):00+10:00")
            XCTAssertEqual(scheduler.dueActions([rule], at: now, calendar: brisbane), [ScheduledEvent(schedule: rule, date: now)])
            XCTAssertTrue(scheduler.dueActions([rule], at: now.addingTimeInterval(60), calendar: brisbane).isEmpty)
        }
        rule.cron = "*/15 * * * *"
        scheduler.reset(at: date("2026-10-05T14:14:59+10:00"))
        XCTAssertEqual(scheduler.dueActions([rule], at: date("2026-10-05T14:15:00+10:00"), calendar: brisbane).count, 1)
        XCTAssertTrue(scheduler.dueActions([rule], at: date("2026-10-05T14:29:59+10:00"), calendar: brisbane).isEmpty)
        XCTAssertEqual(scheduler.dueActions([rule], at: date("2026-10-05T14:30:00+10:00"), calendar: brisbane).count, 1)
    }

    func testCronCalendarFieldsUseStandardDayOrWeekdayAndSundayAliases() {
        var rule = schedule(hour: 9, minute: 0)
        rule.cron = "5 6 13 10 2"
        for (day, expected) in [("2026-10-13", 1), ("2026-10-20", 1), ("2026-10-14", 0), ("2026-11-13", 0)] {
            var scheduler = Scheduler(at: date("\(day)T06:04:59+10:00"))
            XCTAssertEqual(scheduler.dueActions([rule], at: date("\(day)T06:05:00+10:00"), calendar: brisbane).count, expected)
        }
        // A non-Tuesday 13th still matches; the two restrictions are not ANDed.
        rule.cron = "5 6 13 * 2"
        var monday = Scheduler(at: date("2026-07-13T06:04:59+10:00"))
        XCTAssertEqual(monday.dueActions([rule], at: date("2026-07-13T06:05:00+10:00"), calendar: brisbane).count, 1)
        for sunday in ["0", "7"] {
            rule.cron = "0 9 * * \(sunday)"
            var scheduler = Scheduler(at: date("2026-10-11T08:59:59+10:00"))
            XCTAssertEqual(scheduler.dueActions([rule], at: date("2026-10-11T09:00:00+10:00"), calendar: brisbane).count, 1)
        }
    }

    func testAnnualAndLeapDaySchedulesCatchUpWithoutAssumingWeeklyRecurrence() {
        var rule = schedule(hour: 9, minute: 0)
        rule.cron = "5 6 1 2 *"
        var scheduler = Scheduler(at: date("2026-01-01T00:00:00+10:00"))
        XCTAssertEqual(
            scheduler.dueActions([rule], at: date("2026-10-05T12:00:00+10:00"), calendar: brisbane),
            [ScheduledEvent(schedule: rule, date: date("2026-02-01T06:05:00+10:00"))]
        )
        rule.cron = "0 6 29 2 *"
        scheduler.reset(at: date("2027-02-28T00:00:00+10:00"))
        XCTAssertTrue(scheduler.dueActions([rule], at: date("2027-03-01T12:00:00+10:00"), calendar: brisbane).isEmpty)
        XCTAssertEqual(
            scheduler.dueActions([rule], at: date("2028-03-01T12:00:00+10:00"), calendar: brisbane),
            [ScheduledEvent(schedule: rule, date: date("2028-02-29T06:00:00+10:00"))]
        )
    }

    func testInvalidAndSubMinuteCronsNeverRun() {
        var rule = schedule(hour: 9, minute: 0)
        for expression in ["", "* * * * * *", "*/0 * * * *", "*/-1 * * * *", "60 * * * *",
                           "0 24 * * *", "0 9 0 * *", "0 9 * 13 *", "0 9 * * 8", "0 9 * * MON",
                           "9-3 * * * *", "1,,2 * * * *", "1/ * * * *", "1//2 * * * *",
                           "@hourly", "* * * * * open", String(repeating: "9", count: 257)] {
            rule.cron = expression
            XCTAssertNotNil(rule.cronError, expression)
            XCTAssertFalse(rule.isActive, expression)
            var scheduler = Scheduler(at: date("2026-10-05T08:59:59+10:00"))
            XCTAssertTrue(scheduler.dueActions([rule], at: date("2026-10-05T09:00:00+10:00"), calendar: brisbane).isEmpty, expression)
        }
    }

    func testCooldownUsesDispatchTimeAcrossRowsAndResetsButKeepsOtherTargetsIndependent() {
        var recurring = schedule(hour: 9, minute: 0)
        recurring.cron = "* * * * *"
        let quit = schedule(action: .quit, hour: 9, minute: 1)
        var url = schedule(hour: 9, minute: 1)
        url.appURL = "myapp://run"
        var scheduler = Scheduler(at: date("2026-10-05T08:00:00+10:00"))
        XCTAssertEqual(
            scheduler.dueActions([recurring], at: date("2026-10-05T09:00:50+10:00"), calendar: brisbane),
            [ScheduledEvent(schedule: recurring, date: date("2026-10-05T09:00:00+10:00"))]
        )
        scheduler.reset(at: date("2026-10-05T09:00:55+10:00"))
        XCTAssertEqual(scheduler.dueActions([recurring, quit, url], at: date("2026-10-05T09:01:00+10:00"), calendar: brisbane).map(\.schedule), [url])
        XCTAssertTrue(scheduler.dueActions([recurring], at: date("2026-10-05T09:01:50+10:00"), calendar: brisbane).isEmpty)
        XCTAssertEqual(scheduler.dueActions([recurring], at: date("2026-10-05T09:02:00+10:00"), calendar: brisbane).map(\.schedule), [recurring])
        XCTAssertEqual(scheduler.dueActions([recurring], at: date("2026-10-05T09:03:00+10:00"), calendar: brisbane).map(\.schedule), [recurring])
    }

    func testLegacyEmptyDaysStayInactiveAndURLSchedulesMigrate() throws {
        let data = Data("""
        [{"id":"00000000-0000-0000-0000-000000000001",
          "appPath":"","appURL":"myapp://run","action":"open",
          "hour":8,"minute":12,"weekdays":[1,7],"isEnabled":false},
         {"id":"00000000-0000-0000-0000-000000000002",
          "appPath":"/Applications/Test.app","action":"open",
          "hour":9,"minute":0,"weekdays":[],"isEnabled":true}]
        """.utf8)
        let restored = try JSONDecoder().decode([ScheduledAction].self, from: data)
        XCTAssertEqual(restored[0].cron, "12 8 * * 0,6")
        XCTAssertEqual(restored[0].appURL, "myapp://run")
        XCTAssertFalse(restored[0].isEnabled)
        XCTAssertFalse(restored[1].isActive)
        XCTAssertNotNil(restored[1].cronError)
        XCTAssertEqual(try JSONDecoder().decode([ScheduledAction].self, from: JSONEncoder().encode(restored)), restored)
    }

    private func schedule(
        path: String = "/Applications/Test.app", action: AppAction = .open,
        hour: Int, minute: Int, days: Set<Int> = [2, 3, 4, 5, 6]
    ) -> ScheduledAction {
        var rule = ScheduledAction()
        rule.appPath = path
        rule.action = action
        let weekdays = days.map { $0 - 1 }.sorted().map(String.init).joined(separator: ",")
        rule.cron = days.isEmpty ? "" : "\(minute) \(hour) * * \(weekdays)"
        return rule
    }

    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
