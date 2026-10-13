import AppKit
import ServiceManagement
import SwiftUI

private final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = AppSchedulerStore()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var launchAtLoginItem: NSMenuItem!
    private var scheduleSummaryItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Standard responder-chain shortcuts for editing and pasting app URLs.
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(
            title: "Quit App Scheduler", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        ))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [
            ("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a")
        ] {
            editMenu.addItem(NSMenuItem(title: title, action: action, keyEquivalent: key))
        }
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "App Scheduler")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "App Scheduler"

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit App Scheduler", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        statusItem.menu = menu

        store.start()
        if store.schedules.isEmpty { showSettings() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func menuWillOpen(_ menu: NSMenu) {
        for item in scheduleSummaryItems { menu.removeItem(item) }
        scheduleSummaryItems = store.schedules.map { schedule in
            let item = NSMenuItem(title: schedule.menuSummary, action: nil, keyEquivalent: "")
            item.toolTip = "\(schedule.appURL ?? schedule.appPath)\n\(schedule.scheduleDescription ?? schedule.cronError ?? "")\nCron: \(schedule.cron)"
            return item
        }
        if scheduleSummaryItems.isEmpty {
            scheduleSummaryItems = [NSMenuItem(title: "No schedules", action: nil, keyEquivalent: "")]
        }
        for (index, item) in scheduleSummaryItems.enumerated() {
            menu.insertItem(item, at: index)
        }
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1080, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            window.title = "App Scheduler Settings"
            window.contentMinSize = NSSize(width: 1020, height: 420)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(store: store))
            window.center()
            settingsWindow = window
        }
        store.refreshApplications()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            store.report("Could not change Launch at Login: \(error.localizedDescription)")
            NSSound.beep()
        }
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
