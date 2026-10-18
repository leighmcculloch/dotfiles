import AppKit
import UniformTypeIdentifiers
import VideoCompression

private final class VideoDropView: NSView {
    var onDrop: (([URL]) -> Void)?
    var isEnabled = true

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 12
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func urls(_ sender: NSDraggingInfo) -> [URL] {
        let objects = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) ?? []
        let urls = objects.compactMap { $0 as? URL }.filter { $0.isFileURL }
        if !urls.isEmpty { return urls }
        return sender.draggingPasteboard.pasteboardItems?.compactMap {
            $0.string(forType: .fileURL).flatMap { URL(string: $0) }
        }.filter { $0.isFileURL } ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isEnabled, !urls(sender).isEmpty else { return [] }
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.borderWidth = 2
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { layer?.borderWidth = 0 }
    override func draggingEnded(_ sender: NSDraggingInfo) { layer?.borderWidth = 0 }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.borderWidth = 0
        guard isEnabled else { return false }
        let files = urls(sender)
        guard !files.isEmpty else { return false }
        onDrop?(files)
        return true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private let dropView = VideoDropView()
    private let codec = NSPopUpButton()
    private let quality = NSPopUpButton()
    private let details = NSTextField(wrappingLabelWithString: "")
    private let status = NSTextField(wrappingLabelWithString: "Ready. Choose options, then drop a video to start.")
    private let progress = NSProgressIndicator()
    private lazy var openButton = NSButton(title: "Open Video…", target: self, action: #selector(chooseVideo))
    private lazy var cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
    private lazy var revealButton = NSButton(title: "Show in Finder", target: self, action: #selector(reveal))
    private var compressor: VideoCompressor?
    private var output: URL?
    private var quitting = false
    private var pendingFiles: [URL]?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        setupWindow()
        DispatchQueue.main.async { [self] in
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if let files = pendingFiles {
                pendingFiles = nil
                compress(files)
            }
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let files = filenames.map { URL(fileURLWithPath: $0) }
        if window == nil { pendingFiles = files } else { compress(files) }
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard compressor != nil else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Stop compression and quit?"
        alert.informativeText = "The unfinished output will be removed. Your original video will not be changed."
        alert.addButton(withTitle: "Keep Compressing")
        alert.addButton(withTitle: "Stop and Quit")
        guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        // Encoding may have finished while the confirmation was open.
        guard let compressor else { return .terminateNow }
        quitting = true
        compressor.cancel()
        return .terminateLater
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard compressor != nil else { return true }
        NSApp.terminate(nil)
        return false
    }

    private func setupMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Video Compressor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let open = fileMenu.addItem(withTitle: "Open Video…", action: #selector(chooseVideo), keyEquivalent: "o")
        open.target = self
        fileItem.submenu = fileMenu
        menu.addItem(fileItem)
        NSApp.mainMenu = menu
    }

    private func setupWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Video Compressor"
        window.contentMinSize = NSSize(width: 620, height: 660)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "film", accessibilityDescription: nil)
        icon.contentTintColor = .secondaryLabelColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 40, weight: .regular)
        let title = NSTextField(labelWithString: "Drop a video here")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Creates an MP4 alongside the original. Never overwrites it.")
        subtitle.textColor = .secondaryLabelColor
        let dropContent = NSStackView(views: [icon, title, subtitle, openButton])
        dropContent.orientation = .vertical
        dropContent.spacing = 12
        dropContent.translatesAutoresizingMaskIntoConstraints = false
        dropView.addSubview(dropContent)
        NSLayoutConstraint.activate([
            dropContent.centerXAnchor.constraint(equalTo: dropView.centerXAnchor),
            dropContent.centerYAnchor.constraint(equalTo: dropView.centerYAnchor),
            dropView.heightAnchor.constraint(equalToConstant: 215),
        ])
        dropView.onDrop = { [weak self] in self?.compress($0) }

        codec.addItems(withTitles: VideoCodec.allCases.map(\.title))
        quality.addItems(withTitles: VideoQuality.allCases.map(\.title))
        quality.selectItem(at: VideoQuality.balanced.rawValue)
        codec.target = self
        codec.action = #selector(optionsChanged)
        quality.target = self
        quality.action = #selector(optionsChanged)
        codec.setAccessibilityLabel("Video format")
        quality.setAccessibilityLabel("Video quality")
        let options = NSGridView(views: [
            [NSTextField(labelWithString: "Format"), codec],
            [NSTextField(labelWithString: "Quality"), quality],
        ])
        options.rowSpacing = 10
        options.columnSpacing = 16
        options.column(at: 0).xPlacement = .trailing
        options.column(at: 1).xPlacement = .fill
        details.font = .systemFont(ofSize: 12)
        details.textColor = .secondaryLabelColor
        optionsChanged()

        progress.style = .bar
        progress.isIndeterminate = true
        progress.isHidden = true
        cancelButton.isHidden = true
        revealButton.isHidden = true
        status.isSelectable = true
        status.maximumNumberOfLines = 5
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let actions = NSStackView(views: [cancelButton, revealButton])
        actions.spacing = 8
        let note = NSTextField(wrappingLabelWithString: "Runs locally using FFmpeg. Size savings vary; compression is lossy. The original is always kept.")
        note.font = .systemFont(ofSize: 12)
        note.textColor = .secondaryLabelColor

        let content = NSStackView(views: [dropView, options, details, progress, status, actions, note])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        let root = window.contentView!
        root.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            content.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -24),
        ])
        for view in [dropView, options, details, progress, status, note] {
            view.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
    }

    private var options: CompressionOptions {
        CompressionOptions(
            codec: VideoCodec(rawValue: codec.indexOfSelectedItem) ?? .hevc,
            quality: VideoQuality(rawValue: quality.indexOfSelectedItem) ?? .balanced
        )
    }

    @objc private func optionsChanged() {
        details.stringValue = "CRF \(options.crf) · AAC audio at 128 kb/s · Original resolution and frame rate"
    }

    @objc private func chooseVideo() {
        guard compressor == nil else { NSSound.beep(); return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Compress"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.compress([url])
        }
    }

    private func compress(_ files: [URL]) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        guard compressor == nil else { NSSound.beep(); return }
        guard files.count == 1, let input = files.first,
              let type = UTType(filenameExtension: input.pathExtension), type.conforms(to: .movie)
        else {
            status.stringValue = "Please choose one video file at a time (for example, MP4 or MOV)."
            return
        }
        output = nil
        let worker = VideoCompressor()
        compressor = worker
        let selectedOptions = options
        setBusy(true)
        status.stringValue = "Compressing \(input.lastPathComponent)…\nSoftware encoding can take a while, especially for large videos."
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = Result { try worker.compress(input: input, options: selectedOptions) }
            DispatchQueue.main.async { [self] in
                compressor = nil
                setBusy(false)
                switch result {
                case .success(let result):
                    output = result.output
                    let before = ByteCountFormatter.string(fromByteCount: result.originalBytes, countStyle: .file)
                    let after = ByteCountFormatter.string(fromByteCount: result.compressedBytes, countStyle: .file)
                    let change: String
                    if result.compressedBytes < result.originalBytes, result.originalBytes > 0 {
                        let percent = 100 * (1 - Double(result.compressedBytes) / Double(result.originalBytes))
                        change = String(format: "%.1f%% smaller", percent)
                    } else {
                        change = "Not smaller — try Smaller file quality. The original is unchanged."
                    }
                    status.stringValue = "\(before) → \(after) · \(change)\nSaved: \(result.output.lastPathComponent)"
                    status.toolTip = result.output.path
                    revealButton.isHidden = false
                case .failure(let error):
                    status.stringValue = error.localizedDescription
                    status.toolTip = error.localizedDescription
                }
                if quitting { NSApp.reply(toApplicationShouldTerminate: true) }
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        codec.isEnabled = !busy
        quality.isEnabled = !busy
        openButton.isEnabled = !busy
        dropView.isEnabled = !busy
        cancelButton.isHidden = !busy
        cancelButton.isEnabled = true
        revealButton.isHidden = true
        progress.isHidden = !busy
        if busy { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
        status.toolTip = nil
    }

    @objc private func cancel() {
        compressor?.cancel()
        cancelButton.isEnabled = false
        status.stringValue = "Cancelling… Removing unfinished output."
    }

    @objc private func reveal() {
        if let output { NSWorkspace.shared.activateFileViewerSelecting([output]) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
