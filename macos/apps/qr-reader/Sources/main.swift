import AppKit
import ServiceManagement
import UniformTypeIdentifiers

private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
        .urlReadingFileURLs: true,
    ]
    guard let objects = pasteboard.readObjects(
        forClasses: [NSURL.self],
        options: options
    ) as? [NSURL]
    else {
        return []
    }

    return objects.compactMap { object in
        guard object.isFileURL, let path = object.path else { return nil }
        return URL(fileURLWithPath: path)
    }
}

private final class DropView: NSView {
    var onDrop: (([URL], NSImage?) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .png, .tiff])
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { layer?.borderColor = NSColor.separatorColor.cgColor }

        let pasteboard = sender.draggingPasteboard
        let urls = fileURLs(from: pasteboard)
        if !urls.isEmpty {
            onDrop?(urls, nil)
            return true
        }

        guard let image = NSImage(pasteboard: pasteboard) else { return false }
        onDrop?([], image)
        return true
    }
}

private final class QRCodeRowView: NSView {
    private let code: QRCode
    private let copyButton: NSButton
    private let openButton: NSButton

    init(code: QRCode) {
        self.code = code
        copyButton = NSButton(title: "Copy", target: nil, action: nil)
        openButton = NSButton(title: "Open", target: nil, action: nil)
        super.init(frame: .zero)

        let valueField = NSTextField(wrappingLabelWithString: code.value)
        valueField.lineBreakMode = .byCharWrapping
        valueField.maximumNumberOfLines = 0
        valueField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        copyButton.target = self
        copyButton.action = #selector(copyValue)
        copyButton.setAccessibilityLabel("Copy QR code")

        openButton.target = self
        openButton.action = #selector(openValue)
        openButton.isEnabled = code.url != nil
        openButton.setAccessibilityLabel("Open QR code")

        let actions = NSStackView(views: [copyButton, openButton])
        actions.orientation = .horizontal
        actions.spacing = 8

        let content = NSStackView(views: [valueField, actions])
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])

        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 6
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func copyValue() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code.value, forType: .string)
        copyButton.title = "Copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.copyButton.title = "Copy"
        }
    }

    @objc private func openValue() {
        guard let url = code.url else { return }
        NSWorkspace.shared.open(url)
    }
}

private final class QRResultsWindowController: NSWindowController {
    var onOpenImage: (() -> Void)?
    var onDrop: (([URL], NSImage?) -> Void)?

    private let dropView = DropView(frame: .zero)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let resultsScrollView = NSScrollView()
    private let resultsStack = NSStackView()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 220),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "QR Reader"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildView()
        showEmptyState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showEmptyState() {
        statusLabel.stringValue = "Drop an image here, or choose one to scan."
        statusLabel.textColor = .secondaryLabelColor
        resultsScrollView.isHidden = true
        resizeWindow(height: 220)
    }

    func showScanning(sourceName: String) {
        statusLabel.stringValue = "Scanning \(sourceName)…"
        statusLabel.textColor = .secondaryLabelColor
        resultsScrollView.isHidden = true
        resizeWindow(height: 220)
        present()
    }

    func show(results: [QRCode], sourceName: String) {
        resultsStack.arrangedSubviews.forEach {
            resultsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if results.isEmpty {
            statusLabel.stringValue = "No QR codes found in \(sourceName)."
            statusLabel.textColor = .secondaryLabelColor
            resultsScrollView.isHidden = true
            resizeWindow(height: 220)
        } else {
            let count = results.count == 1 ? "1 QR code" : "\(results.count) QR codes"
            statusLabel.stringValue = "Found \(count) in \(sourceName)."
            statusLabel.textColor = .labelColor
            results.forEach { resultsStack.addArrangedSubview(QRCodeRowView(code: $0)) }
            resultsScrollView.isHidden = false
            resizeWindow(height: min(440 + CGFloat(max(0, results.count - 2)) * 92, 600))
        }
        present()
    }

    func showError(_ message: String) {
        statusLabel.stringValue = message
        statusLabel.textColor = .systemRed
        resultsScrollView.isHidden = true
        resizeWindow(height: 220)
        present()
    }

    private func buildView() {
        guard let contentView = window?.contentView else { return }

        let dropLabel = NSTextField(labelWithString: "Drop an image to read its QR codes")
        dropLabel.alignment = .center

        let openButton = NSButton(title: "Open Image…", target: self, action: #selector(openImage))
        openButton.bezelStyle = .rounded

        let dropContent = NSStackView(views: [dropLabel, openButton])
        dropContent.orientation = .vertical
        dropContent.alignment = .centerX
        dropContent.spacing = 8
        dropContent.translatesAutoresizingMaskIntoConstraints = false
        dropView.addSubview(dropContent)

        NSLayoutConstraint.activate([
            dropContent.centerXAnchor.constraint(equalTo: dropView.centerXAnchor),
            dropContent.centerYAnchor.constraint(equalTo: dropView.centerYAnchor),
        ])

        dropView.onDrop = { [weak self] urls, image in
            self?.onDrop?(urls, image)
        }

        statusLabel.alignment = .center
        statusLabel.maximumNumberOfLines = 2

        resultsStack.orientation = .vertical
        resultsStack.alignment = .width
        resultsStack.spacing = 8

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(resultsStack)
        resultsStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            resultsStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 12),
            resultsStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -12),
            resultsStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 4),
            resultsStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -4),
            documentView.widthAnchor.constraint(equalTo: resultsScrollView.contentView.widthAnchor),
        ])

        resultsScrollView.documentView = documentView
        resultsScrollView.hasVerticalScroller = true
        resultsScrollView.drawsBackground = false
        resultsScrollView.borderType = .noBorder
        resultsScrollView.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView(views: [dropView, statusLabel, resultsScrollView])
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 12
        content.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        content.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(content)

        dropView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            content.topAnchor.constraint(equalTo: contentView.topAnchor),
            content.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            dropView.heightAnchor.constraint(equalToConstant: 92),
            resultsScrollView.heightAnchor.constraint(equalToConstant: 260),
        ])
    }

    @objc private func openImage() {
        onOpenImage?()
    }

    private func resizeWindow(height: CGFloat) {
        guard let window else { return }
        var frame = window.frame
        let heightDelta = height - window.contentRect(forFrameRect: frame).height
        frame.origin.y -= heightDelta
        frame.size.height += heightDelta
        window.setFrame(frame, display: true, animate: true)
    }

    private func present() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var launchAtLoginItem: NSMenuItem!
    private let resultsWindow = QRResultsWindowController()

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()

        resultsWindow.onOpenImage = { [weak self] in
            self?.chooseImage()
        }
        resultsWindow.onDrop = { [weak self] urls, image in
            if !urls.isEmpty {
                self?.scan(urls: urls)
            } else if let image {
                self?.scan(image: image, sourceName: "dropped image")
            }
        }

        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    func application(_: NSApplication, openFiles filenames: [String]) {
        scan(urls: filenames.map { URL(fileURLWithPath: $0) })
    }

    // MARK: - macOS Service

    @objc
    func readQRCode(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let urls = fileURLs(from: pasteboard)
        if !urls.isEmpty {
            scan(urls: urls)
            return
        }

        guard let image = NSImage(pasteboard: pasteboard) else {
            resultsWindow.showError("No image was received from the service.")
            return
        }
        scan(image: image, sourceName: "selected image")
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "qrcode",
            accessibilityDescription: "QR Reader"
        )

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Open Image…",
            action: #selector(chooseImage),
            keyEquivalent: "o"
        ))
        menu.addItem(NSMenuItem(
            title: "Read Clipboard Image",
            action: #selector(readClipboardImage),
            keyEquivalent: ""
        ))
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

    @objc private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "Read QR Codes"

        guard panel.runModal() == .OK else { return }
        scan(urls: panel.urls)
    }

    @objc private func readClipboardImage() {
        guard let image = NSImage(pasteboard: .general) else {
            resultsWindow.showError("The clipboard does not contain an image.")
            return
        }
        scan(image: image, sourceName: "clipboard image")
    }

    // MARK: - Scanning

    private func scan(urls: [URL]) {
        guard !urls.isEmpty else { return }
        let sourceName = urls.count == 1
            ? urls[0].lastPathComponent
            : "\(urls.count) images"
        resultsWindow.showScanning(sourceName: sourceName)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var results = [QRCode]()
            var hadError = false
            for url in urls {
                do {
                    results.append(contentsOf: try QRCodeScanner.scan(url: url))
                } catch {
                    hadError = true
                }
            }
            DispatchQueue.main.async {
                if results.isEmpty, hadError {
                    self?.resultsWindow.showError("Couldn’t read the selected image.")
                } else {
                    self?.resultsWindow.show(results: results, sourceName: sourceName)
                }
            }
        }
    }

    private func scan(image: NSImage, sourceName: String) {
        resultsWindow.showScanning(sourceName: sourceName)

        let cgImage: CGImage
        do {
            cgImage = try QRCodeScanner.cgImage(from: image)
        } catch {
            resultsWindow.showError("Couldn’t read the image.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let results = try QRCodeScanner.scan(cgImage: cgImage)
                DispatchQueue.main.async {
                    self?.resultsWindow.show(results: results, sourceName: sourceName)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.resultsWindow.showError("Couldn’t read the image.")
                }
            }
        }
    }

    // MARK: - Launch at Login

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // User can retry.
        }
        updateLaunchAtLoginState()
    }

    private func updateLaunchAtLoginState() {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
