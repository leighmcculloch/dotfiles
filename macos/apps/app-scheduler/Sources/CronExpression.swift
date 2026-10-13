import Foundation

// Five-field numeric cron: minute hour day-of-month month day-of-week.
struct CronExpression {
    struct ValidationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let minutes: Set<Int>
    private let hours: Set<Int>
    private let times: [Int]
    private let days: Set<Int>
    private let months: Set<Int>
    private let weekdays: Set<Int>
    private let anyDay: Bool
    private let anyWeekday: Bool

    init(_ expression: String) throws {
        guard expression.count <= 256 else {
            throw ValidationError(message: "Cron must be at most 256 characters.")
        }
        let fields = expression.split(whereSeparator: { $0.isWhitespace })
        guard fields.count == 5 else {
            throw ValidationError(message: "Use five fields: minute hour day month weekday (no seconds).")
        }
        let minutes = try Self.values(fields[0], in: 0...59, name: "Minute")
        let hours = try Self.values(fields[1], in: 0...23, name: "Hour")
        self.minutes = minutes
        self.hours = hours
        times = hours.flatMap { hour in minutes.map { hour * 60 + $0 } }.sorted(by: >)
        days = try Self.values(fields[2], in: 1...31, name: "Day")
        months = try Self.values(fields[3], in: 1...12, name: "Month")
        weekdays = Set(try Self.values(fields[4], in: 0...7, name: "Weekday").map { $0 % 7 })
        anyDay = fields[2].hasPrefix("*")
        anyWeekday = fields[4].hasPrefix("*")
    }

    var humanDescription: String {
        let minuteList = Self.list(minutes.sorted().map(String.init))
        let hourList = Self.list(hours.sorted().map { Self.time($0 * 60) })
        let time: String
        if hours.count == 24 {
            if minutes.count == 60 {
                time = "Every minute"
            } else if let step = Self.uniformInterval(minutes, within: 60) {
                time = "Every \(step) minutes"
            } else if minutes.count == 1 {
                time = minutes == [0] ? "Every hour" : "Every hour at minute \(minuteList)"
            } else {
                time = "At minutes \(minuteList) of every hour"
            }
        } else if minutes.count == 1, let step = Self.uniformInterval(hours, within: 24) {
            time = "Every \(step) hours" + (minutes == [0] ? "" : " at minute \(minuteList)")
        } else if minutes.count == 1 || times.count <= 4 {
            time = "At " + Self.list(times.sorted().map(Self.time))
        } else {
            let hourWord = hours.count == 1 ? "hour" : "hours"
            if minutes.count == 60 {
                time = "Every minute during the \(hourList) \(hourWord)"
            } else if let step = Self.uniformInterval(minutes, within: 60) {
                time = "Every \(step) minutes during the \(hourList) \(hourWord)"
            } else {
                time = "At minutes \(minuteList) past \(hourList)"
            }
        }

        let dayList = Self.list(days.sorted().map(Self.ordinal))
        let dayRule = days.count == 31 ? nil : "on the \(dayList) of \(months.count == 12 ? "each month" : "the month")"
        let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let weekdayList = weekdays == [1, 2, 3, 4, 5]
            ? "Monday–Friday"
            : Self.list([1, 2, 3, 4, 5, 6, 0].filter { weekdays.contains($0) }.map { weekdayNames[$0] })
        let weekdayRule = weekdays.count == 7 ? nil : "on \(weekdayList)"
        let dayDescription: String?
        if anyDay || anyWeekday {
            if let weekdayRule, dayRule != nil {
                dayDescription = "\(weekdayRule), restricted to the \(dayList) of the month"
            } else {
                dayDescription = dayRule ?? weekdayRule
            }
        } else if let dayRule, let weekdayRule {
            dayDescription = "\(dayRule) or \(weekdayRule)"
        } else {
            // An explicit all-values day field makes cron's OR rule always true.
            dayDescription = nil
        }
        let dayText = dayDescription.map { " \($0)" } ?? (time.hasPrefix("At ") ? " every day" : "")
        let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        let monthText = months.count == 12 ? "" : " in " + Self.list(months.sorted().map { monthNames[$0 - 1] })
        return time + monthText + dayText
    }

    private static func uniformInterval(_ values: Set<Int>, within span: Int) -> Int? {
        let sorted = values.sorted()
        guard sorted.count > 1, sorted[0] == 0 else { return nil }
        let step = sorted[1]
        // */7 means 0, 7, …, 56, then 0 again, not a constant seven-minute interval.
        return span % step == 0 && values == Set(stride(from: 0, to: span, by: step)) ? step : nil
    }

    private static func time(_ minuteOfDay: Int) -> String {
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60
        let minuteText = minute == 0 ? "" : String(format: ":%02d", minute)
        return "\(hour % 12 == 0 ? 12 : hour % 12)\(minuteText)\(hour < 12 ? "am" : "pm")"
    }

    private static func ordinal(_ day: Int) -> String {
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        return "\(day)\(suffix)"
    }

    private static func list(_ items: [String]) -> String {
        if items.count <= 2 { return items.joined(separator: " and ") }
        return items.dropLast().joined(separator: ", ") + ", and " + items.last!
    }

    private static func values(_ field: Substring, in bounds: ClosedRange<Int>, name: String) throws -> Set<Int> {
        func invalid() -> ValidationError {
            ValidationError(message: "\(name): use \(bounds.lowerBound)–\(bounds.upperBound), *, lists, ranges, or /steps.")
        }
        func number(_ value: Substring) throws -> Int {
            guard !value.isEmpty, value.allSatisfy({ $0 >= "0" && $0 <= "9" }),
                  let number = Int(value) else { throw invalid() }
            return number
        }

        var result = Set<Int>()
        for item in field.split(separator: ",", omittingEmptySubsequences: false) {
            let parts = item.split(separator: "/", omittingEmptySubsequences: false)
            guard (1...2).contains(parts.count) else { throw invalid() }
            let step = parts.count == 2 ? try number(parts[1]) : 1
            guard step > 0, step <= bounds.count else { throw invalid() }
            let lower: Int
            let upper: Int
            if parts[0] == "*" {
                lower = bounds.lowerBound
                upper = bounds.upperBound
            } else {
                let range = parts[0].split(separator: "-", omittingEmptySubsequences: false)
                guard (1...2).contains(range.count) else { throw invalid() }
                lower = try number(range[0])
                upper = range.count == 2 ? try number(range[1]) : (parts.count == 2 ? bounds.upperBound : lower)
            }
            guard bounds.contains(lower), bounds.contains(upper), lower <= upper else { throw invalid() }
            result.formUnion(stride(from: lower, through: upper, by: step))
        }
        return result
    }

    func latestDate(after: Date, through now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        // Bound catch-up work to the past year, including annual schedules.
        // Never walk every missed minute or replay a recurring backlog.
        for offset in 0...366 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let interval = calendar.dateInterval(of: .day, for: day), interval.end > after
            else { break }
            let components = calendar.dateComponents([.month, .day, .weekday], from: day)
            guard months.contains(components.month!) else { continue }
            let matchesDay = days.contains(components.day!)
            let matchesWeekday = weekdays.contains(components.weekday! - 1)
            // Standard cron uses OR when both day fields are restricted.
            guard anyDay || anyWeekday ? matchesDay && matchesWeekday : matchesDay || matchesWeekday else { continue }

            for time in times {
                let date: Date
                if interval.duration == 86400 {
                    date = day.addingTimeInterval(TimeInterval(time * 60))
                } else {
                    guard let matched = calendar.date(
                        bySettingHour: time / 60, minute: time % 60, second: 0, of: day,
                        matchingPolicy: .nextTime, repeatedTimePolicy: .first
                    ), calendar.isDate(matched, inSameDayAs: day) else { continue }
                    date = matched
                }
                if date <= after { break }
                if date <= now { return date }
            }
        }
        return nil
    }
}
