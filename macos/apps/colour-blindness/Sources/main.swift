import AppKit
import SwiftUI

@MainActor
private struct ControlsView: View {
    @ObservedObject var store: SimulationStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Colour Blindness").font(.title2).bold()
                Text("Simulate colour vision across all your displays while continuing to use your apps.")
                    .foregroundStyle(.secondary)
                Text("Vision type").font(.headline)
                Picker("Vision type", selection: $store.simulation.type) {
                    ForEach(VisionType.allCases) { type in
                        Text("\(type.title) — \(type.detail)").tag(type)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                Text(store.simulation.type.detail).foregroundStyle(.secondary)
                if store.simulation.type.hasSeverity {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Severity")
                            Spacer()
                            Text("\(Int(store.simulation.severity * 100))%")
                                .monospacedDigit()
                        }
                        Slider(value: $store.simulation.severity, in: 0...1, step: 0.05)
                            .accessibilityLabel("Simulation severity")
                        HStack {
                            Text("Normal vision")
                            Spacer()
                            Text("Full deficiency")
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                Text(store.message).fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Simulation status: \(store.message)")
                HStack {
                    Button(store.isStarting ? "Cancel" : store.isRunning ? "Stop Simulation" : "Start Simulation") {
                        if store.isRunning || store.isStarting { store.stop() } else { store.start() }
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    Spacer()
                    Button("Screen Recording Settings…") {
                        NSWorkspace.shared.open(
                            URL(
                                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                        )
                    }
                }
                Text(
                    "Screen Recording permission is required. Frames are processed locally, never saved or uploaded. Stop with ⌘. when this app is focused, or quit from the Dock. Closing this window also stops the simulation."
                )
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                Text(
                    "Colour simulations are approximations, not a medical test. The hardware cursor and protected video are not filtered."
                )
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 588)
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = SimulationStore()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let show = NSMenuItem(title: "Show Colour Blindness", action: #selector(present), keyEquivalent: "0")
        show.target = self
        appMenu.addItem(show)
        let stop = NSMenuItem(title: "Stop Simulation", action: #selector(stopSimulation), keyEquivalent: ".")
        stop.target = self
        appMenu.addItem(stop)
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Colour Blindness", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 588, height: 620),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false
        )
        window.title = "Colour Blindness"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let content = NSHostingView(rootView: ControlsView(store: store))
        window.contentView = content
        window.setContentSize(NSSize(width: 588, height: 620))
        window.center()
        self.window = window

        NotificationCenter.default.addObserver(
            self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(willSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(willSleep), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        DispatchQueue.main.async { [weak self] in self?.present() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        present()
        return true
    }

    func windowWillClose(_ notification: Notification) { store.stop() }
    func applicationWillTerminate(_ notification: Notification) { store.stop() }

    @objc private func present() {
        NSApp.activate(ignoringOtherApps: true)
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func stopSimulation() { store.stop() }

    @objc private func displaysChanged() {
        guard store.isRunning || store.isStarting else { return }
        store.stop(message: "Display configuration changed. Start again to simulate all connected displays.")
    }

    @objc private func willSleep() {
        guard store.isRunning || store.isStarting else { return }
        store.stop(message: "Simulation stopped for sleep or session change. Start again when ready.")
    }
}

private let app = NSApplication.shared
private let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
