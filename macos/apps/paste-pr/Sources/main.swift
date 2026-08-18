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
    private static let autoConvertDefaultsKey = "AutoConvertGitHubLinks"

    private var statusItem: NSStatusItem!
    private var launchAtLoginItem: NSMenuItem!
    private var autoConvertItem: NSMenuItem!
    private var hotKeyRef: EventHotKeyRef?
    private var clipboardMonitorTimer: Timer?
    private var lastObservedClipboardChangeCount: Int?
    private var autoConvertEnabled = false

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        autoConvertEnabled = UserDefaults.standard.bool(forKey: Self.autoConvertDefaultsKey)
        setupMenuBar()
        registerGlobalHotkey()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(convertClipboard),
            name: NSNotification.Name("ConvertClipboard"),
            object: nil
        )

        updateClipboardMonitoring()
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

        autoConvertItem = NSMenuItem(
            title: "Automatically Convert GitHub Links",
            action: #selector(toggleAutoConvert),
            keyEquivalent: ""
        )
        updateAutoConvertState()
        menu.addItem(autoConvertItem)

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
        beginClipboardConversion(automatically: false)
    }

    private func beginClipboardConversion(automatically: Bool) {
        let pb = NSPasteboard.general
        let originalChangeCount = pb.changeCount

        guard let originalInput = pb.string(forType: .string),
              !originalInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            if !automatically {
                showFeedback(success: false)
            }
            return
        }

        let link = originalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if automatically && !PRToRichText.isSupportedGitHubLink(link) {
            return
        }

        // Fetching the GitHub resource may block on the network, so do it off
        // the main thread and update the clipboard back on the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            let result = try? PRToRichText.convert(prLink: link)
            DispatchQueue.main.async {
                guard let result else {
                    if !automatically {
                        self.showFeedback(success: false)
                    }
                    return
                }
                if automatically && !self.autoConvertEnabled {
                    return
                }
                switch writeConversionResult(
                    result,
                    originalInput: originalInput,
                    expectedChangeCount: originalChangeCount,
                    to: pb
                ) {
                case .written:
                    self.markClipboardWriteAsObserved(pasteboard: pb)
                    if !automatically {
                        self.showFeedback(success: true)
                    }
                case .stale:
                    return
                case .failed:
                    if !automatically {
                        self.showFeedback(success: false)
                    }
                }
            }
        }
    }

    private func updateClipboardMonitoring() {
        clipboardMonitorTimer?.invalidate()
        clipboardMonitorTimer = nil
        lastObservedClipboardChangeCount = nil

        guard autoConvertEnabled else { return }

        let pasteboard = NSPasteboard.general
        lastObservedClipboardChangeCount = pasteboard.changeCount

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollClipboard()
        }
        clipboardMonitorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func pollClipboard() {
        guard autoConvertEnabled else {
            updateClipboardMonitoring()
            return
        }

        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard let lastObservedClipboardChangeCount else {
            lastObservedClipboardChangeCount = changeCount
            return
        }
        guard changeCount != lastObservedClipboardChangeCount else { return }

        self.lastObservedClipboardChangeCount = changeCount
        beginClipboardConversion(automatically: true)
    }

    private func markClipboardWriteAsObserved(pasteboard: NSPasteboard) {
        guard autoConvertEnabled else { return }
        lastObservedClipboardChangeCount = pasteboard.changeCount
    }

    // MARK: Auto Conversion

    @objc private func toggleAutoConvert() {
        autoConvertEnabled.toggle()
        UserDefaults.standard.set(autoConvertEnabled, forKey: Self.autoConvertDefaultsKey)
        updateAutoConvertState()
        updateClipboardMonitoring()
    }

    private func updateAutoConvertState() {
        autoConvertItem?.state = autoConvertEnabled ? .on : .off
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
    to pasteboard: NSPasteboard,
    writeObjects: (([NSPasteboardItem]) -> Bool)? = nil,
    restoreWriteObjects: (([NSPasteboardItem]) -> Bool)? = nil
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
    let write = writeObjects ?? { pasteboard.writeObjects($0) }
    guard write([item]) else {
        guard pasteboard.changeCount == clearedChangeCount else {
            return .stale
        }
        switch originalContents.restore(
            to: pasteboard,
            expectedChangeCount: clearedChangeCount,
            writeObjects: restoreWriteObjects
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
