import AppKit
import Combine
import UniformTypeIdentifiers

struct InstalledApp: Identifiable {
    let path: String
    let name: String
    var id: String { path }
}

final class AppSchedulerStore: ObservableObject {
    @Published var schedules: [ScheduledAction] = [] {
        didSet {
            let now = Date()
            // Finish actions already due under the old configuration, so editing
            // one row cannot silently drop another row's action between polls.
            for event in scheduler.dueActions(oldValue, at: now) {
                perform(event.schedule)
            }
            scheduler.reset(at: now)
            do {
                let data = try JSONEncoder().encode(schedules)
                UserDefaults.standard.set(data, forKey: Self.schedulesKey)
            } catch {
                statusMessage = "Could not save schedules: \(error.localizedDescription)"
            }
        }
    }
    @Published private(set) var applications: [InstalledApp] = []
    @Published private(set) var statusMessage = "Schedules run while App Scheduler is open, in your Mac’s local time."

    private static let schedulesKey = "scheduledActions"
    private var scheduler = Scheduler(at: Date())
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.schedulesKey) {
            do {
                schedules = try JSONDecoder().decode([ScheduledAction].self, from: data)
            } catch {
                statusMessage = "Could not load saved schedules: \(error.localizedDescription)"
            }
        }
    }

    func start() {
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkSchedules()
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.checkSchedules()
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduler.reset(at: Date())
        })
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    func refreshApplications() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fileManager = FileManager.default
            let directories = [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/System/Applications"),
                fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            ]
            var found: [String: InstalledApp] = [:]
            for directory in directories {
                guard let enumerator = fileManager.enumerator(
                    at: directory, includingPropertiesForKeys: nil,
                    options: [.skipsPackageDescendants, .skipsHiddenFiles]
                ) else { continue }
                for case let url as URL in enumerator where url.pathExtension == "app" {
                    let path = url.resolvingSymlinksInPath().path
                    let name = fileManager.displayName(atPath: url.path)
                    found[path] = InstalledApp(
                        path: path,
                        name: name.hasSuffix(".app") ? String(name.dropLast(4)) : name
                    )
                }
            }
            let scanned = found
            DispatchQueue.main.async {
                guard let self else { return }
                var available = scanned
                // Keep manually chosen apps available even outside these folders.
                for app in self.applications where available[app.path] == nil {
                    available[app.path] = app
                }
                for schedule in self.schedules
                    where schedule.appURL == nil && !schedule.appPath.isEmpty && available[schedule.appPath] == nil {
                    available[schedule.appPath] = InstalledApp(path: schedule.appPath, name: schedule.appName)
                }
                self.applications = available.values.sorted {
                    if $0.name == $1.name { return $0.path < $1.path }
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
            }
        }
    }

    func addSchedule(appPath: String = "") {
        var schedule = ScheduledAction()
        schedule.appPath = appPath
        schedules.append(schedule)
    }

    func chooseOtherApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add App"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.resolvingSymlinksInPath().path
        if !applications.contains(where: { $0.path == path }) {
            applications.append(InstalledApp(
                path: path, name: url.deletingPathExtension().lastPathComponent
            ))
            applications.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        addSchedule(appPath: path)
    }

    func report(_ message: String) {
        statusMessage = message
    }

    private func checkSchedules() {
        for event in scheduler.dueActions(schedules, at: Date()) {
            perform(event.schedule)
        }
    }

    private func perform(_ schedule: ScheduledAction) {
        if schedule.appURL != nil {
            guard schedule.action == .open, let url = schedule.urlToOpen else { return }
            report(NSWorkspace.shared.open(url)
                ? "Requested to open \(schedule.targetName)."
                : "Could not open \(schedule.targetName). Check that an app is installed to handle this URL.")
            return
        }

        let appURL = URL(fileURLWithPath: schedule.appPath).resolvingSymlinksInPath()
        switch schedule.action {
        case .open:
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { [weak self] _, error in
                DispatchQueue.main.async {
                    self?.report(error.map {
                        "Could not open \(schedule.appName): \($0.localizedDescription)"
                    } ?? "Opened \(schedule.appName).")
                }
            }
        case .quit:
            let running = NSWorkspace.shared.runningApplications.filter {
                $0.bundleURL?.resolvingSymlinksInPath() == appURL
            }
            guard !running.isEmpty else {
                report("\(schedule.appName) is already closed.")
                return
            }
            let accepted = running.map { $0.terminate() }.allSatisfy { $0 }
            report(accepted
                ? "Requested \(schedule.appName) to quit. Unsaved work may require your attention."
                : "\(schedule.appName) did not accept the quit request.")
        }
    }
}
