import AppKit
import Foundation
import ServiceManagement

fileprivate struct UsageSnapshot {
    let remainingPercent: Int
    let primaryResetDate: Date?
    let secondaryResetDate: Date?
}

private enum UsageError: LocalizedError {
    case codexNotFound
    case serverFailed(String)
    case invalidResponse
    case noUsageWindow

    var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "Codex was not found on this Mac."
        case let .serverFailed(message):
            return message
        case .invalidResponse:
            return "Codex returned an unexpected usage response."
        case .noUsageWindow:
            return "Codex did not return a usage window."
        }
    }
}

private final class CodexAppServerClient {
    private let fileManager = FileManager.default
    fileprivate typealias Completion = (Result<UsageSnapshot, Error>) -> Void
    private let queue = DispatchQueue(label: "com.leighmcculloch.CodexUsage.app-server")
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var outputBuffer = Data()
    private var pollTimer: DispatchSourceTimer?
    private var restartWorkItem: DispatchWorkItem?
    private var nextRequestID = 2
    private var pendingCompletions: [Int: Completion] = [:]
    private var queuedCompletions: [Completion] = []
    private var usageObserver: Completion?
    private var stopping = false
    private var requestInFlight = false
    private var nextAllowedRequest = Date.distantPast
    private var retryDelay: TimeInterval = 60

    fileprivate func start(onUsage: @escaping Completion) {
        queue.async { [self] in
            usageObserver = onUsage
            stopping = false
            startProcessIfNeeded()
        }
    }

    fileprivate func refresh(completion: @escaping Completion) {
        queue.async { [self] in
            if process?.isRunning == true {
                sendRateLimitRequest(completion: completion)
            } else {
                queuedCompletions.append(completion)
                startProcessIfNeeded()
            }
        }
    }

    func stop() {
        queue.async { [self] in
            stopping = true
            restartWorkItem?.cancel()
            restartWorkItem = nil
            pollTimer?.cancel()
            pollTimer = nil
            process?.terminationHandler = nil
            process?.terminate()
            process = nil
            inputPipe = nil
            outputPipe = nil
        }
    }

    private func startProcessIfNeeded() {
        guard !stopping, process?.isRunning != true else { return }
        guard let codexURL = findCodexExecutable() else {
            let error = UsageError.codexNotFound
            notify(error: error, completions: queuedCompletions)
            queuedCompletions.removeAll()
            scheduleRestart(after: 60)
            return
        }

        let process = Process()
        process.executableURL = codexURL
        process.arguments = ["app-server", "--stdio"]
        process.standardError = Pipe()

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.terminationHandler = { [weak self] _ in
            self?.queue.async { [weak self] in
                self?.processTerminated()
            }
        }
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { [weak self] in
                self?.receive(data)
            }
        }

        do {
            try process.run()
        } catch {
            notify(error: error, completions: queuedCompletions)
            queuedCompletions.removeAll()
            scheduleRestart(after: 60)
            return
        }

        self.process = process
        inputPipe = input
        outputPipe = output
        outputBuffer.removeAll()
        requestInFlight = false
        nextAllowedRequest = .distantPast
        retryDelay = 60

        send([
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "menu-bar-usage-codex",
                    "version": "0.1.0"
                ]
            ]
        ])
        send(["method": "initialized", "params": [:]])
        sendRateLimitRequest()

        let queued = queuedCompletions
        queuedCompletions.removeAll()
        queued.forEach { sendRateLimitRequest(completion: $0) }
        startPolling()
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in
            self?.sendRateLimitRequest()
        }
        timer.resume()
        pollTimer = timer
    }

    private func processTerminated() {
        guard !stopping else { return }
        process = nil
        inputPipe = nil
        outputPipe = nil
        requestInFlight = false
        pollTimer?.cancel()
        pollTimer = nil
        outputBuffer.removeAll()
        let error = UsageError.serverFailed("Codex app-server exited; restarting.")
        notify(error: error, completions: Array(pendingCompletions.values) + queuedCompletions)
        pendingCompletions.removeAll()
        queuedCompletions.removeAll()
        scheduleRestart(after: 1)
    }

    private func scheduleRestart(after delay: TimeInterval) {
        guard !stopping, restartWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            restartWorkItem = nil
            startProcessIfNeeded()
        }
        restartWorkItem = workItem
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func sendRateLimitRequest(completion: Completion? = nil) {
        if let completion {
            queuedCompletions.append(completion)
        }
        guard process?.isRunning == true else {
            startProcessIfNeeded()
            return
        }
        guard !requestInFlight, Date() >= nextAllowedRequest else { return }

        let requestID = nextRequestID
        nextRequestID += 1
        if !queuedCompletions.isEmpty {
            let completions = queuedCompletions
            queuedCompletions.removeAll()
            pendingCompletions[requestID] = { result in
                completions.forEach { $0(result) }
            }
        }
        requestInFlight = true
        send([
            "id": requestID,
            "method": "account/rateLimits/read",
            "params": NSNull()
        ])
    }

    private func send(_ object: [String: Any]) {
        guard let inputPipe else { return }
        inputPipe.fileHandleForWriting.write(Data(jsonLine(object).appending("\n").utf8))
    }

    private func receive(_ data: Data) {
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let line = outputBuffer.prefix(upTo: newline)
            outputBuffer.removeSubrange(...newline)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let requestID = (object["id"] as? NSNumber)?.intValue,
                  requestID >= 2 else {
                continue
            }

            let completion = pendingCompletions.removeValue(forKey: requestID)
            let result = parseUsageResponse(object)
            requestInFlight = false
            switch result {
            case .success:
                retryDelay = 60
                nextAllowedRequest = Date().addingTimeInterval(60)
            case .failure:
                nextAllowedRequest = Date().addingTimeInterval(retryDelay)
                retryDelay = min(retryDelay * 2, 15 * 60)
            }
            notify(result, completion: completion)
        }
    }

    private func parseUsageResponse(_ response: [String: Any]) -> Result<UsageSnapshot, Error> {
        if let error = response["error"] as? [String: Any], let message = error["message"] as? String {
            return .failure(UsageError.serverFailed(message))
        }
        guard let result = response["result"] as? [String: Any] else {
            return .failure(UsageError.invalidResponse)
        }

        let rateLimits: [String: Any]
        if let byLimit = result["rateLimitsByLimitId"] as? [String: Any],
           let codex = byLimit["codex"] as? [String: Any] {
            rateLimits = codex
        } else if let legacy = result["rateLimits"] as? [String: Any] {
            rateLimits = legacy
        } else {
            return .failure(UsageError.invalidResponse)
        }

        var windows: [(remaining: Int, resetsAt: Date?)] = []
        for key in ["primary", "secondary"] {
            guard let window = rateLimits[key] as? [String: Any],
                  let usedPercent = (window["usedPercent"] as? NSNumber)?.intValue else {
                continue
            }
            let remaining = max(0, min(100, 100 - usedPercent))
            let resetDate = (window["resetsAt"] as? NSNumber).map {
                Date(timeIntervalSince1970: $0.doubleValue)
            }
            windows.append((remaining, resetDate))
        }

        guard let minimum = windows.min(by: { $0.remaining < $1.remaining }) else {
            return .failure(UsageError.noUsageWindow)
        }

        return .success(UsageSnapshot(
            remainingPercent: minimum.remaining,
            primaryResetDate: windows.first?.resetsAt,
            secondaryResetDate: windows.dropFirst().first?.resetsAt
        ))
    }

    private func notify(_ result: Result<UsageSnapshot, Error>, completion: Completion? = nil) {
        let observer = usageObserver
        DispatchQueue.main.async {
            observer?(result)
            completion?(result)
        }
    }

    private func notify(error: Error, completions: [Completion]) {
        notify(.failure(error))
        completions.forEach { notify(.failure(error), completion: $0) }
    }

    private func findCodexExecutable() -> URL? {
        let fixedLocations = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/codex").path,
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]

        let pathLocations = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map { String($0) + "/codex" }

        return (fixedLocations + pathLocations)
            .map(URL.init(fileURLWithPath:))
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    private func jsonLine(_ object: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object)
        return String(decoding: data, as: UTF8.self)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let cachedRemainingPercentKey = "cachedRemainingPercent"
    private let client = CodexAppServerClient()
    private var statusItem: NSStatusItem!
    private var launchAtLoginItem: NSMenuItem!
    private var refreshItem: NSMenuItem!
    private var lastSnapshot: UsageSnapshot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        client.start { [weak self] result in
            self?.apply(result)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        client.stop()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        lastSnapshot = loadCachedSnapshot()
        if let button = statusItem.button {
            button.title = lastSnapshot.map { statusTitle(for: $0) } ?? "—"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.alignment = .center
            button.cell?.wraps = false
            button.cell?.isScrollable = false
            button.toolTip = lastSnapshot.map { tooltip(for: $0) + "\nRefreshing…" } ?? "Codex usage remaining"
        }

        let menu = NSMenu()
        refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshUsage), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let usageItem = NSMenuItem(title: "Open Codex usage settings", action: #selector(openUsageSettings), keyEquivalent: "")
        usageItem.target = self
        menu.addItem(usageItem)

        menu.addItem(.separator())
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        updateLaunchAtLoginState()

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func refreshUsage() {
        refreshItem?.isEnabled = false
        client.refresh { [weak self] result in
            self?.refreshItem?.isEnabled = true
            self?.apply(result)
        }
    }

    private func apply(_ result: Result<UsageSnapshot, Error>) {
        switch result {
        case let .success(snapshot):
            lastSnapshot = snapshot
            UserDefaults.standard.set(snapshot.remainingPercent, forKey: cachedRemainingPercentKey)
            statusItem.button?.title = statusTitle(for: snapshot)
            statusItem.button?.toolTip = tooltip(for: snapshot)
        case let .failure(error):
            if let lastSnapshot {
                statusItem.button?.title = "\(lastSnapshot.remainingPercent)%"
                statusItem.button?.toolTip = "Last known value: \(lastSnapshot.remainingPercent)%\nCodex usage unavailable: \(error.localizedDescription)"
            } else {
                statusItem.button?.title = "—"
                statusItem.button?.toolTip = "Codex usage unavailable: \(error.localizedDescription)"
            }
        }
    }

    private func loadCachedSnapshot() -> UsageSnapshot? {
        guard let remainingPercent = UserDefaults.standard.object(forKey: cachedRemainingPercentKey) as? Int else {
            return nil
        }
        return UsageSnapshot(
            remainingPercent: remainingPercent,
            primaryResetDate: nil,
            secondaryResetDate: nil
        )
    }

    @objc private func openUsageSettings() {
        NSWorkspace.shared.open(URL(string: "https://chatgpt.com/codex/settings/usage")!)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
        updateLaunchAtLoginState()
    }

    private func updateLaunchAtLoginState() {
        launchAtLoginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func tooltip(for snapshot: UsageSnapshot) -> String {
        var text = "Codex usage remaining: \(snapshot.remainingPercent)%"
        if let primaryResetDate = snapshot.primaryResetDate {
            text += "\nPrimary window resets \(resetDetails(for: primaryResetDate))"
        }
        if let secondaryResetDate = snapshot.secondaryResetDate {
            text += "\nSecondary window resets \(resetDetails(for: secondaryResetDate))"
        }
        return text
    }

    private func statusTitle(for snapshot: UsageSnapshot) -> String {
        let resetDates = [snapshot.primaryResetDate, snapshot.secondaryResetDate].compactMap { $0 }
        guard let nextResetDate = resetDates.min() else {
            return "\(snapshot.remainingPercent)%"
        }
        return "\(snapshot.remainingPercent)% \(compactCountdown(to: nextResetDate))"
    }

    private func resetDetails(for date: Date) -> String {
        let dateText = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        return "\(dateText) (in \(compactCountdown(to: date)))"
    }

    private func compactCountdown(to date: Date) -> String {
        let secondsUntilReset = date.timeIntervalSinceNow
        guard secondsUntilReset > 0 else { return "now" }

        let totalHours = Int(ceil(secondsUntilReset / 3600))
        let days = totalHours / 24
        let hours = totalHours % 24
        if days > 0 {
            return "\(days)d \(hours)h"
        }
        return "\(hours)h"
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
