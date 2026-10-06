import Foundation

struct Stopwatch {
    private var startedAt: ContinuousClock.Instant?

    var isRunning: Bool { startedAt != nil }

    mutating func click(at now: ContinuousClock.Instant = ContinuousClock.now) {
        startedAt = isRunning ? nil : now
    }

    func title(at now: ContinuousClock.Instant = ContinuousClock.now) -> String {
        let seconds = startedAt.map { Int($0.duration(to: now).components.seconds) } ?? 0
        let minutes = seconds / 60
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, minutes % 60, seconds % 60)
        }
        return String(format: "%d:%02d", minutes, seconds % 60)
    }
}
