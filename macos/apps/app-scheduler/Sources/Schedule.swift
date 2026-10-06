import Foundation

enum AppAction: String, Codable, CaseIterable {
    case open
    case quit

    var title: String { rawValue.capitalized }
}

struct ScheduledAction: Identifiable, Codable, Equatable {
    var id = UUID()
    var appPath = ""
    // nil selects an app; a string (including an unfinished empty input) selects
    // a URL. Optional decoding keeps previously saved app schedules compatible.
    var appURL: String?
    var action = AppAction.open
    var hour = 9
    var minute = 0
    // Calendar weekdays: Sunday = 1, Monday = 2, ..., Saturday = 7.
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var isEnabled = true

    var appName: String {
        URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
    }

    var urlToOpen: URL? {
        guard let appURL else { return nil }
        let value = appURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let url = URL(string: value), let scheme = url.scheme, !scheme.isEmpty
        else { return nil }
        return url
    }

    var targetName: String {
        appURL.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? appName
    }

    var targetKey: String {
        appURL == nil ? "app:\(appPath)" : "url:\(urlToOpen?.absoluteString ?? "")"
    }

    var isActive: Bool {
        isEnabled && (appURL == nil ? !appPath.isEmpty : action == .open && urlToOpen != nil)
            && !weekdays.isEmpty
            && weekdays.allSatisfy { (1...7).contains($0) }
            && (0...23).contains(hour) && (0...59).contains(minute)
    }
}

struct ScheduledEvent: Equatable {
    let schedule: ScheduledAction
    let date: Date
}

struct Scheduler {
    private var lastCheck: Date

    init(at date: Date) {
        lastCheck = date
    }

    mutating func reset(at date: Date) {
        lastCheck = date
    }

    mutating func dueActions(
        _ schedules: [ScheduledAction],
        at now: Date,
        calendar: Calendar = .current
    ) -> [ScheduledEvent] {
        let after = lastCheck
        guard now > after else { return [] }
        lastCheck = now

        // Only the latest missed action per app or exact URL is useful after
        // sleep. Looking back one week suffices because rules repeat weekly.
        var latestByTarget: [String: (event: ScheduledEvent, row: Int)] = [:]
        let today = calendar.startOfDay(for: now)
        for (row, schedule) in schedules.enumerated() where schedule.isActive {
            for offset in 0...7 {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                      schedule.weekdays.contains(calendar.component(.weekday, from: day)),
                      let date = calendar.date(
                        bySettingHour: schedule.hour, minute: schedule.minute, second: 0,
                        of: day, matchingPolicy: .nextTime, repeatedTimePolicy: .first
                      ),
                      calendar.isDate(date, inSameDayAs: day),
                      date > after, date <= now
                else { continue }

                let event = ScheduledEvent(schedule: schedule, date: date)
                if let previous = latestByTarget[schedule.targetKey], previous.event.date > date {
                    break
                }
                // Equal times are resolved by row order: the last row wins.
                latestByTarget[schedule.targetKey] = (event, row)
                break
            }
        }
        return latestByTarget.values.sorted {
            if $0.event.date == $1.event.date { return $0.row < $1.row }
            return $0.event.date < $1.event.date
        }.map(\.event)
    }
}
