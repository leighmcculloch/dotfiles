import AppKit
import Carbon.HIToolbox
import ServiceManagement

// MARK: - Global hotkey callback (C-compatible function for Carbon interop)

func hotkeyHandler(
    _: EventHandlerCallRef?,
    _: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        NotificationCenter.default.post(
            name: NSNotification.Name("ConvertClipboard"),
            object: nil
        )
    }
    return noErr
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var launchAtLoginItem: NSMenuItem!
    private var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        registerGlobalHotkey()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(convertClipboard),
            name: NSNotification.Name("ConvertClipboard"),
            object: nil
        )
    }

    // MARK: Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "arrow.triangle.pull",
                accessibilityDescription: "Paste PR"
            )
        }

        let menu = NSMenu()

        let convertItem = NSMenuItem(
            title: "Convert GitHub Link to Rich Text  ⇧⌘P",
            action: #selector(convertClipboard),
            keyEquivalent: ""
        )
        menu.addItem(convertItem)

        menu.addItem(.separator())

        launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        updateLaunchAtLoginState()
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    // MARK: Global Hotkey (Cmd+Shift+P)

    private func registerGlobalHotkey() {
        var eventSpec = EventTypeSpec(
            eventClass: UInt32(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyHandler,
            1,
            &eventSpec,
            nil,
            nil
        )

        let hotKeyID = EventHotKeyID(signature: 0x50505052, id: 1) // "PPPR"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    // MARK: Clipboard Conversion

    @objc func convertClipboard() {
        let pb = NSPasteboard.general

        guard let originalInput = pb.string(forType: .string),
              !originalInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            showFeedback(success: false)
            return
        }

        let link = originalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalChangeCount = pb.changeCount

        // Fetching the GitHub resource may block on the network, so do it off
        // the main thread and update the clipboard back on the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            let result = try? PRToRichText.convert(prLink: link)
            DispatchQueue.main.async {
                guard let result else {
                    self.showFeedback(success: false)
                    return
                }
                guard pb.changeCount == originalChangeCount,
                      pb.clearContents()
                else {
                    return
                }
                pb.declareTypes([.html, .string], owner: nil)
                guard pb.setString(result.html, forType: .html),
                      pb.setString(originalInput, forType: .string)
                else {
                    self.showFeedback(success: false)
                    return
                }
                self.showFeedback(success: true)
            }
        }
    }

    private func showFeedback(success: Bool) {
        guard let button = statusItem.button else { return }
        let originalImage = button.image

        button.image = NSImage(
            systemSymbolName: success ? "checkmark.circle.fill" : "xmark.circle",
            accessibilityDescription: success ? "Conversion succeeded" : "Conversion failed"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            button.image = originalImage
        }
    }

    // MARK: Launch at Login

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // User can retry
        }
        updateLaunchAtLoginState()
    }

    private func updateLaunchAtLoginState() {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
