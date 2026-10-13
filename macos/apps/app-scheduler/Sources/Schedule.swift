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
    var cron = "0 9 * * 1-5"
    var isEnabled = true

    private enum CodingKeys: String, CodingKey {
        case id, appPath, appURL, action, cron, isEnabled
    }

    private enum LegacyKeys: String, CodingKey {
        case hour, minute, weekdays
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        appPath = try values.decode(String.self, forKey: .appPath)
        appURL = try values.decodeIfPresent(String.self, forKey: .appURL)
        action = try values.decode(AppAction.self, forKey: .action)
        isEnabled = try values.decode(Bool.self, forKey: .isEnabled)
        if let expression = try values.decodeIfPresent(String.self, forKey: .cron) {
            cron = expression
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let hour = try legacy.decode(Int.self, forKey: .hour)
            let minute = try legacy.decode(Int.self, forKey: .minute)
            let weekdays = try legacy.decode(Set<Int>.self, forKey: .weekdays)
            // Preserve incomplete/invalid rows as inactive, never as an all-days rule.
            if (0...23).contains(hour), (0...59).contains(minute),
               !weekdays.isEmpty, weekdays.allSatisfy({ (1...7).contains($0) }) {
                let days = weekdays == Set(1...7) ? "*" : weekdays.map { $0 - 1 }.sorted().map(String.init).joined(separator: ",")
                cron = "\(minute) \(hour) * * \(days)"
            } else {
                cron = ""
            }
        }
    }

    var cronError: String? {
        do {
            _ = try CronExpression(cron)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

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

    var scheduleDescription: String? {
        (try? CronExpression(cron))?.humanDescription
    }

    var menuSummary: String {
        let target: String
        if appURL == nil && appPath.isEmpty {
            target = "No app selected"
        } else {
            target = targetName.isEmpty ? "No URL entered" : targetName
        }
        let shortTarget = target.count > 48 ? String(target.prefix(47)) + "…" : target
        let state = !isEnabled ? " (disabled)" : (isActive ? "" : " (incomplete)")
        let description = scheduleDescription ?? (cron.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No cron entered" : "Invalid cron")
        let shortDescription = description.count > 96 ? String(description.prefix(95)) + "…" : description
        return "\(action.title) \(shortTarget) — \(shortDescription)\(state)"
    }

    var targetKey: String {
        appURL == nil ? "app:\(appPath)" : "url:\(urlToOpen?.absoluteString ?? "")"
    }

    var isActive: Bool {
        isEnabled && (appURL == nil ? !appPath.isEmpty : action == .open && urlToOpen != nil)
            && cronError == nil
    }
}

struct ScheduledEvent: Equatable {
    let schedule: ScheduledAction
    let date: Date
}

struct Scheduler {
    private var lastCheck: Date
    private var lastRunByTarget: [String: Date] = [:]
    static let minimumInterval: TimeInterval = 60

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

        // Only the latest missed action per app or exact URL is useful after sleep.
        var latestByTarget: [String: (event: ScheduledEvent, row: Int)] = [:]
        for (row, schedule) in schedules.enumerated() where schedule.isActive {
            guard let cron = try? CronExpression(schedule.cron),
                  let date = cron.latestDate(after: after, through: now, calendar: calendar)
            else { continue }
            let event = ScheduledEvent(schedule: schedule, date: date)
            if let previous = latestByTarget[schedule.targetKey], previous.event.date > date { continue }
            // Equal times are resolved by row order: the last row wins.
            latestByTarget[schedule.targetKey] = (event, row)
        }
        let events = latestByTarget.values.sorted {
            if $0.event.date == $1.event.date { return $0.row < $1.row }
            return $0.event.date < $1.event.date
        }.map(\.event)
        return events.filter { event in
            let key = event.schedule.targetKey
            // Use actual dispatch time, not the scheduled minute: a late poll or
            // wake must not cause another action seconds later. Edits keep this guard.
            if let lastRun = lastRunByTarget[key], now.timeIntervalSince(lastRun) < Self.minimumInterval {
                return false
            }
            lastRunByTarget[key] = now
            return true
        }
    }
}
