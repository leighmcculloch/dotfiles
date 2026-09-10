import AppKit

fileprivate extension NSView {
    var qrUsesDarkAppearance: Bool {
        effectiveAppearance.bestMatch(
            from: [NSAppearance.Name.darkAqua, NSAppearance.Name.aqua]
        ) == .darkAqua
    }

    var qrPrimaryTextColor: NSColor {
        qrUsesDarkAppearance ? .white : .black
    }

    var qrToolbarBackgroundColor: NSColor {
        qrUsesDarkAppearance
            ? NSColor(calibratedWhite: 0.16, alpha: 1)
            : NSColor(calibratedWhite: 0.96, alpha: 1)
    }
}

private final class QRToolbarView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        qrToolbarBackgroundColor.setFill()
        bounds.fill()

        qrPrimaryTextColor.withAlphaComponent(0.22).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }
}

private final class QRToolbarStatusView: NSView {
    var stringValue = "" {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    var textColor: NSColor = .black {
        didSet { needsDisplay = true }
    }

    var primaryTextColor: NSColor {
        qrPrimaryTextColor
    }

    override var intrinsicContentSize: NSSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        ]
        let width = (stringValue as NSString).size(withAttributes: attributes).width
        return NSSize(width: min(max(width, 180), 520), height: 22)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !stringValue.isEmpty else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byTruncatingMiddle
        let text = NSAttributedString(
            string: stringValue,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle,
            ]
        )
        text.draw(
            with: bounds.insetBy(dx: 0, dy: 2),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            context: nil
        )
    }
}

private final class QRReaderWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class QRImageCanvasView: NSView {
    var image: NSImage? {
        didSet {
            selectedIndex = nil
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
        }
    }

    var codes: [QRCode] = [] {
        didSet {
            selectedIndex = nil
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
        }
    }

    var onDrop: (([URL], NSImage?) -> Void)?
    var onCodeSelected: ((QRCode, NSRect) -> Void)?
    var onBackgroundSelected: (() -> Void)?

    private var codeRects = [(index: Int, rect: NSRect)]()
    private var selectedIndex: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        clipsToBounds = true
        registerForDraggedTypes([.fileURL, .png, .tiff])
        wantsLayer = true
        layer?.backgroundColor = NSColor.underPageBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.underPageBackgroundColor.setFill()
        dirtyRect.fill()
        codeRects.removeAll(keepingCapacity: true)

        guard let image else {
            drawEmptyState()
            return
        }

        let imageRect = displayedImageRect(for: image)
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        for (index, code) in codes.enumerated() {
            guard let bounds = code.bounds,
                  let rect = displayedRect(for: bounds, in: imageRect)
            else {
                continue
            }
            codeRects.append((index: index, rect: rect))
            drawHighlight(in: rect, index: index, selected: selectedIndex == index)
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        for codeRect in codeRects {
            addCursorRect(codeRect.rect.insetBy(dx: -8, dy: -8), cursor: .pointingHand)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let codeRect = codeRects.reversed().first(where: {
            $0.rect.insetBy(dx: -10, dy: -10).contains(point)
        }) else {
            selectedIndex = nil
            needsDisplay = true
            onBackgroundSelected?()
            return
        }

        selectedIndex = codeRect.index
        needsDisplay = true
        onCodeSelected?(codes[codeRect.index], codeRect.rect)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderWidth = 0
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { layer?.borderWidth = 0 }

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

    private func displayedImageRect(for image: NSImage) -> NSRect {
        let availableRect = bounds.insetBy(dx: 24, dy: 24)
        guard image.size.width > 0, image.size.height > 0,
              availableRect.width > 0, availableRect.height > 0
        else {
            return .zero
        }

        let scale = min(
            availableRect.width / image.size.width,
            availableRect.height / image.size.height
        )
        let size = NSSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        return NSRect(
            x: availableRect.midX - size.width / 2,
            y: availableRect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func displayedRect(for normalizedBounds: CGRect, in imageRect: NSRect) -> NSRect? {
        guard normalizedBounds.width > 0,
              normalizedBounds.height > 0,
              normalizedBounds.minX.isFinite,
              normalizedBounds.minY.isFinite,
              normalizedBounds.maxX.isFinite,
              normalizedBounds.maxY.isFinite
        else {
            return nil
        }

        let rect = NSRect(
            x: imageRect.minX + normalizedBounds.minX * imageRect.width,
            y: imageRect.minY + normalizedBounds.minY * imageRect.height,
            width: normalizedBounds.width * imageRect.width,
            height: normalizedBounds.height * imageRect.height
        )
        let clipped = rect.intersection(imageRect)
        return clipped.isNull || clipped.isEmpty ? nil : clipped
    }

    private func drawHighlight(in rect: NSRect, index: Int, selected: Bool) {
        let highlightRect = rect.insetBy(dx: -4, dy: -4)
        let path = NSBezierPath(
            roundedRect: highlightRect,
            xRadius: 8,
            yRadius: 8
        )
        NSColor.controlAccentColor.withAlphaComponent(selected ? 0.28 : 0.16).setFill()
        path.fill()

        NSColor.controlAccentColor.withAlphaComponent(selected ? 1.0 : 0.85).setStroke()
        path.lineWidth = selected ? 3 : 2
        path.stroke()

        let badgeRect = NSRect(
            x: highlightRect.minX - 2,
            y: highlightRect.maxY - 20,
            width: 20,
            height: 20
        )
        NSColor.controlAccentColor.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()

        let label = NSString(string: "\(index + 1)")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let labelSize = label.size(withAttributes: attributes)
        label.draw(
            at: NSPoint(
                x: badgeRect.midX - labelSize.width / 2,
                y: badgeRect.midY - labelSize.height / 2 + 1
            ),
            withAttributes: attributes
        )
    }

    private func drawEmptyState() {
        let title = NSString(string: "Open or drop an image to find QR codes")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let size = title.size(withAttributes: attributes)
        title.draw(
            at: NSPoint(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2
            ),
            withAttributes: attributes
        )
    }
}

final class QRCodeActionViewController: NSViewController {
    private let code: QRCode
    private let copyButton = NSButton(title: "Copy Value", target: nil, action: nil)
    private let openButton = NSButton(title: "Open Link", target: nil, action: nil)
    private let feedbackLabel = NSTextField(labelWithString: "")

    var onFinished: (() -> Void)?

    init(code: QRCode) {
        self.code = code
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 170))
        view = rootView

        let heading = NSTextField(labelWithString: "QR Code")
        heading.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        let valueLabel = NSTextField(wrappingLabelWithString: code.value)
        valueLabel.maximumNumberOfLines = 4
        valueLabel.lineBreakMode = .byCharWrapping
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        copyButton.target = self
        copyButton.action = #selector(copyValue)
        copyButton.setAccessibilityLabel("Copy QR code value")

        openButton.target = self
        openButton.action = #selector(openLink)
        openButton.isHidden = code.url == nil
        openButton.setAccessibilityLabel("Open QR code link")

        let actions = NSStackView(views: [copyButton, openButton])
        actions.orientation = .horizontal
        actions.spacing = 8

        feedbackLabel.textColor = .secondaryLabelColor
        feedbackLabel.alignment = .center

        let content = NSStackView(views: [heading, valueLabel, actions, feedbackLabel])
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 10
        content.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 14),
            content.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -14),
        ])

        preferredContentSize = NSSize(
            width: 340,
            height: openButton.isHidden ? 150 : 170
        )
    }

    @objc private func copyValue() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code.value, forType: .string)
        feedbackLabel.stringValue = "Copied to clipboard"
    }

    @objc private func openLink() {
        guard let url = code.url else { return }
        NSWorkspace.shared.open(url)
        onFinished?()
    }
}

final class QRReaderWindowController: NSWindowController {
    var onOpenImage: (() -> Void)?
    var onPasteImage: (() -> Void)?
    var onDrop: (([URL], NSImage?) -> Void)?

    private let canvas = QRImageCanvasView(frame: .zero)
    private let openButton = NSButton(title: "Open Image…", target: nil, action: nil)
    private let pasteButton = NSButton(title: "Paste Image", target: nil, action: nil)
    private let statusLabel = QRToolbarStatusView()
    private var clipboardMonitor: Timer?
    private var clipboardChangeCount: Int?
    private var popover: NSPopover?

    init() {
        let window = QRReaderWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "QR Reader"
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 420)
        window.center()
        super.init(window: window)
        buildView()
        showEmptyState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        clipboardMonitor?.invalidate()
    }

    func showEmptyState() {
        closePopover()
        canvas.image = nil
        canvas.codes = []
        statusLabel.stringValue = "Open or drop an image to find QR codes."
        statusLabel.textColor = statusLabel.primaryTextColor
    }

    func showEmptyStateAndPresent() {
        showEmptyState()
        present()
    }

    func showScanning(sourceName: String, image: NSImage? = nil) {
        closePopover()
        if let image {
            canvas.image = image
            canvas.codes = []
        }
        statusLabel.stringValue = "Scanning \(sourceName)…"
        statusLabel.textColor = statusLabel.primaryTextColor
        present()
    }

    func show(image: NSImage, results: [QRCode], sourceName: String) {
        closePopover()
        canvas.image = image
        canvas.codes = results
        if results.isEmpty {
            statusLabel.stringValue = "No QR codes found in \(sourceName)."
            statusLabel.textColor = statusLabel.primaryTextColor
        } else {
            let count = results.count == 1 ? "1 QR code" : "\(results.count) QR codes"
            statusLabel.stringValue = "Found \(count) — click a highlighted code for options."
            statusLabel.textColor = statusLabel.primaryTextColor
        }
        present()
    }

    func showError(_ message: String) {
        closePopover()
        statusLabel.stringValue = message
        statusLabel.textColor = .systemRed
        present()
    }

    private func buildView() {
        guard let contentView = window?.contentView else { return }

        openButton.target = self
        openButton.action = #selector(openImage)
        pasteButton.target = self
        pasteButton.action = #selector(pasteImage)
        styleToolbarButton(openButton)
        styleToolbarButton(pasteButton)
        updatePasteButtonState(force: true)
        startClipboardMonitoring()

        let controls = NSStackView(views: [openButton, pasteButton])
        controls.orientation = .horizontal
        controls.spacing = 8

        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let toolbarContent = NSStackView(views: [controls, spacer, statusLabel])
        toolbarContent.orientation = .horizontal
        toolbarContent.alignment = .centerY
        toolbarContent.spacing = 12
        toolbarContent.translatesAutoresizingMaskIntoConstraints = false

        let toolbar = QRToolbarView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(toolbarContent)
        contentView.addSubview(toolbar)

        canvas.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(canvas)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 52),
            toolbarContent.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            toolbarContent.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            toolbarContent.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 8),
            toolbarContent.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: -8),
            canvas.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            canvas.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        canvas.onDrop = { [weak self] urls, image in
            self?.onDrop?(urls, image)
        }
        canvas.onCodeSelected = { [weak self] code, rect in
            self?.showActions(for: code, at: rect)
        }
        canvas.onBackgroundSelected = { [weak self] in
            self?.closePopover()
        }
    }

    private func styleToolbarButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.controlSize = .large
    }

    @objc private func openImage() {
        onOpenImage?()
    }

    @objc private func pasteImage() {
        onPasteImage?()
    }

    private func startClipboardMonitoring() {
        clipboardMonitor?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updatePasteButtonState()
        }
        RunLoop.main.add(timer, forMode: .common)
        clipboardMonitor = timer
    }

    private func updatePasteButtonState(force: Bool = false) {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard force || changeCount != clipboardChangeCount else { return }

        clipboardChangeCount = changeCount
        pasteButton.isEnabled = clipboardImageSource(from: pasteboard) != nil
    }

    private func showActions(for code: QRCode, at rect: NSRect) {
        closePopover()

        let controller = QRCodeActionViewController(code: code)
        controller.onFinished = { [weak self] in
            self?.closePopover()
        }

        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.animates = true
        self.popover = popover
        popover.show(
            relativeTo: rect.insetBy(dx: -4, dy: -4),
            of: canvas,
            preferredEdge: .maxY
        )
    }

    private func closePopover() {
        popover?.performClose(nil)
        popover = nil
    }

    private func present() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
    }
}
