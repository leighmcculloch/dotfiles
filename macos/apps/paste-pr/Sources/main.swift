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
        let originalChangeCount = pb.changeCount

        guard let originalInput = pb.string(forType: .string),
              !originalInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            showFeedback(success: false)
            return
        }

        let link = originalInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fetching the GitHub resource may block on the network, so do it off
        // the main thread and update the clipboard back on the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            let result = try? PRToRichText.convert(prLink: link)
            DispatchQueue.main.async {
                guard let result else {
                    self.showFeedback(success: false)
                    return
                }
                switch writeConversionResult(
                    result,
                    originalInput: originalInput,
                    expectedChangeCount: originalChangeCount,
                    to: pb
                ) {
                case .written:
                    self.showFeedback(success: true)
                case .stale:
                    return
                case .failed:
                    self.showFeedback(success: false)
                }
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

enum PasteboardWriteResult: Equatable {
    case written
    case stale
    case failed
}

enum PasteboardRestoreResult: Equatable {
    case restored
    case stale
    case failed(expectedChangeCount: Int)
}

@discardableResult
func writeConversionResult(
    _ result: PRToRichText.Result,
    originalInput: String,
    expectedChangeCount: Int? = nil,
    to pasteboard: NSPasteboard
) -> PasteboardWriteResult {
    if let expectedChangeCount,
       pasteboard.changeCount != expectedChangeCount {
        return .stale
    }

    let originalContents = PasteboardSnapshot(from: pasteboard)
    let item = NSPasteboardItem()
    guard item.setString(result.html, forType: .html),
          item.setString(originalInput, forType: .string)
    else {
        return .failed
    }

    if let expectedChangeCount,
       pasteboard.changeCount != expectedChangeCount {
        return .stale
    }

    let clearedChangeCount = pasteboard.clearContents()
    guard pasteboard.writeObjects([item]) else {
        guard pasteboard.changeCount == clearedChangeCount else {
            return .stale
        }
        switch originalContents.restore(
            to: pasteboard,
            expectedChangeCount: clearedChangeCount
        ) {
        case .restored:
            return .failed
        case .stale:
            return .stale
        case let .failed(expectedChangeCount):
            guard pasteboard.changeCount == expectedChangeCount else {
                return .stale
            }
            pasteboard.declareTypes([.string], owner: nil)
            guard pasteboard.setString(originalInput, forType: .string) else {
                return .failed
            }
            return .failed
        }
    }
    return .written
}

struct PasteboardSnapshot {
    private struct Representation {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private let items: [[Representation]]

    init(from pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return Representation(type: type, data: data)
            }
        }
    }

    func restore(
        to pasteboard: NSPasteboard,
        expectedChangeCount: Int? = nil,
        writeObjects: (([NSPasteboardItem]) -> Bool)? = nil
    ) -> PasteboardRestoreResult {
        let expectedChangeCount = expectedChangeCount ?? pasteboard.changeCount
        guard pasteboard.changeCount == expectedChangeCount else {
            return .stale
        }

        var restoredItems: [NSPasteboardItem] = []
        for representations in items where !representations.isEmpty {
            let item = NSPasteboardItem()
            for representation in representations {
                guard item.setData(representation.data, forType: representation.type) else {
                    return .failed(expectedChangeCount: expectedChangeCount)
                }
            }
            restoredItems.append(item)
        }

        guard !restoredItems.isEmpty else {
            return .failed(expectedChangeCount: expectedChangeCount)
        }
        guard pasteboard.changeCount == expectedChangeCount else {
            return .stale
        }
        let clearedChangeCount = pasteboard.clearContents()
        let write = writeObjects ?? { pasteboard.writeObjects($0) }
        guard write(restoredItems) else {
            return pasteboard.changeCount == clearedChangeCount
                ? .failed(expectedChangeCount: clearedChangeCount)
                : .stale
        }
        return .restored
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
