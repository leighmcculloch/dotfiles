import Foundation

enum AppAction: String, Codable, CaseIterable {
    case open
    case quit

    var title: String { rawValue.capitalized }
}

struct ScheduledAction: Identifiable, Codable, Equatable {
    var id = UUID()
    var appPath = ""
    var action = AppAction.open
    var hour = 9
    var minute = 0
    // Calendar weekdays: Sunday = 1, Monday = 2, ..., Saturday = 7.
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var isEnabled = true

    var appName: String {
        URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
    }

    var isActive: Bool {
        isEnabled && !appPath.isEmpty && !weekdays.isEmpty
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

        // Only the latest missed action per app is useful after sleep. Looking
        // back one week suffices because every rule repeats weekly.
        var latestByApp: [String: (event: ScheduledEvent, row: Int)] = [:]
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
                if let previous = latestByApp[schedule.appPath], previous.event.date > date {
                    break
                }
                // Equal times are resolved by row order: the last row wins.
                latestByApp[schedule.appPath] = (event, row)
                break
            }
        }
        return latestByApp.values.sorted {
            if $0.event.date == $1.event.date { return $0.row < $1.row }
            return $0.event.date < $1.event.date
        }.map(\.event)
    }
}
