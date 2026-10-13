import Foundation

// Five-field numeric cron: minute hour day-of-month month day-of-week.
struct CronExpression {
    struct ValidationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

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
        times = hours.flatMap { hour in minutes.map { hour * 60 + $0 } }.sorted(by: >)
        days = try Self.values(fields[2], in: 1...31, name: "Day")
        months = try Self.values(fields[3], in: 1...12, name: "Month")
        weekdays = Set(try Self.values(fields[4], in: 0...7, name: "Weekday").map { $0 % 7 })
        anyDay = fields[2].hasPrefix("*")
        anyWeekday = fields[4].hasPrefix("*")
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
