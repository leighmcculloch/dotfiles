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
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "Paste Markdown"
            )
        }

        let menu = NSMenu()

        let convertItem = NSMenuItem(
            title: "Convert Clipboard to Markdown  ⇧⌘M",
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

    // MARK: Global Hotkey (Cmd+Shift+M)

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

        let hotKeyID = EventHotKeyID(signature: 0x504D4D44, id: 1) // "PMMD"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_M),
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

        guard let html = pb.string(forType: .html) else {
            showFeedback(success: false)
            return
        }

        let markdown = HTMLToMarkdown.convert(html)

        pb.clearContents()
        pb.setString(markdown, forType: .string)

        showFeedback(success: true)
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
