import AppKit
import ServiceManagement

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var launchAtLoginItem: NSMenuItem!
    private var stopwatch = Stopwatch()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "Stopwatch")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        updateDisplay()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    @objc private func handleClick() {
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            if let button = statusItem.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
            }
            return
        }

        stopwatch.click()
        timer?.invalidate()
        timer = nil
        if stopwatch.isRunning {
            let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
                self?.updateDisplay()
            }
            timer.tolerance = 0.05
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        updateDisplay()
    }

    private func updateDisplay() {
        let title = stopwatch.title()
        statusItem.button?.title = title
        statusItem.button?.toolTip = stopwatch.isRunning
            ? "Click to reset. Right-click for options."
            : "Click to start. Right-click for options."
        statusItem.button?.setAccessibilityLabel("Stopwatch \(title)")
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
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
