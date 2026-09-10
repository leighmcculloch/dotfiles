import AppKit
import UniformTypeIdentifiers

func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
    let objects = pasteboard.readObjects(
        forClasses: [NSURL.self],
        options: nil
    ) ?? []

    let urls = objects.compactMap { object in
        if let url = object as? URL, url.isFileURL {
            return url
        }
        guard let object = object as? NSURL,
              object.isFileURL,
              let path = object.path
        else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
    if !urls.isEmpty { return urls }

    // Finder and some image viewers expose file URLs as a pasteboard string
    // rather than an NSURL object. Keep this fallback for those clients.
    return pasteboard.pasteboardItems?.compactMap { item in
        guard let value = item.string(forType: .fileURL) else { return nil }
        if let url = URL(string: value), url.isFileURL { return url }
        return URL(fileURLWithPath: value)
    } ?? []
}

enum ClipboardImageSource {
    case file(URL)
    case image(NSImage)
}

func clipboardImageSource(from pasteboard: NSPasteboard) -> ClipboardImageSource? {
    let urls = fileURLs(from: pasteboard)
    if !urls.isEmpty {
        guard let url = urls.first(where: { NSImage(contentsOf: $0) != nil }) else {
            return nil
        }
        return .file(url)
    }

    guard let image = NSImage(pasteboard: pasteboard),
          (try? QRCodeScanner.cgImage(from: image)) != nil
    else {
        return nil
    }
    return .image(image)
}

final class QRCodeServiceProvider: NSObject {
    var onReadFiles: (([URL]) -> Void)?
    var onReadImage: ((NSImage) -> Void)?
    var onReadError: ((String) -> Void)?

    @objc(readQRCode:userData:error:)
    func readQRCode(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        NSLog("QR Reader: image service invoked")

        let urls = fileURLs(from: pasteboard)
        if !urls.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.onReadFiles?(urls)
            }
            return
        }

        if let image = NSImage(pasteboard: pasteboard) {
            DispatchQueue.main.async { [weak self] in
                self?.onReadImage?(image)
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.onReadError?("No image was received from the service.")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowController = QRReaderWindowController()
    private let serviceProvider = QRCodeServiceProvider()

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()

        windowController.onOpenImage = { [weak self] in
            self?.chooseImage()
        }
        windowController.onPasteImage = { [weak self] in
            self?.readClipboardImage()
        }
        windowController.onDrop = { [weak self] urls, image in
            if !urls.isEmpty {
                self?.scan(urls: urls)
            } else if let image {
                self?.scan(image: image, sourceName: "dropped image")
            }
        }

        serviceProvider.onReadFiles = { [weak self] urls in
            self?.scan(urls: urls)
        }
        serviceProvider.onReadImage = { [weak self] image in
            self?.scan(image: image, sourceName: "selected image")
        }
        serviceProvider.onReadError = { [weak self] message in
            self?.windowController.showError(message)
        }

        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
        NSLog("QR Reader: ready")
        // Wait until the launch event has finished before activating the
        // window. Activating it synchronously here can leave the content in
        // macOS's inactive-window state even though the window is visible.
        DispatchQueue.main.async { [weak self] in
            self?.windowController.showEmptyStateAndPresent()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

    func application(_: NSApplication, openFiles filenames: [String]) {
        scan(urls: filenames.map { URL(fileURLWithPath: $0) })
    }

    // MARK: - Application Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(
            title: "Quit QR Reader",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")

        let openItem = NSMenuItem(
            title: "Open Image…",
            action: #selector(chooseImage),
            keyEquivalent: "o"
        )
        openItem.target = self
        fileMenu.addItem(openItem)

        let pasteItem = NSMenuItem(
            title: "Paste Image",
            action: #selector(readClipboardImage),
            keyEquivalent: ""
        )
        pasteItem.target = self
        fileMenu.addItem(pasteItem)

        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Read QR Codes"

        guard let window = windowController.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.scan(url: url)
        }
    }

    @objc private func readClipboardImage() {
        guard let source = clipboardImageSource(from: .general) else {
            windowController.showError("The clipboard does not contain a readable image.")
            return
        }

        switch source {
        case .file(let url):
            scan(url: url, sourceName: "clipboard image")
        case .image(let image):
            scan(image: image, sourceName: "clipboard image")
        }
    }

    // MARK: - Scanning

    private func scan(urls: [URL]) {
        guard let url = urls.first else { return }
        let sourceName = urls.count == 1
            ? url.lastPathComponent
            : "\(url.lastPathComponent) (first of \(urls.count) images)"
        scan(url: url, sourceName: sourceName)
    }

    private func scan(url: URL, sourceName: String? = nil) {
        let name = sourceName ?? (url.lastPathComponent.isEmpty ? "image" : url.lastPathComponent)
        NSLog("QR Reader: scanning \(name)")
        windowController.showScanning(sourceName: name)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = NSImage(contentsOf: url)
            do {
                let results = try QRCodeScanner.scan(url: url)
                DispatchQueue.main.async {
                    guard let image else {
                        self?.windowController.showError("Couldn’t display the selected image.")
                        return
                    }
                    NSLog("QR Reader: found \(results.count) QR code(s)")
                    self?.windowController.show(
                        image: image,
                        results: results,
                        sourceName: name
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self?.windowController.showError("Couldn’t read the selected image.")
                }
            }
        }
    }

    private func scan(image: NSImage, sourceName: String) {
        NSLog("QR Reader: scanning \(sourceName)")
        windowController.showScanning(sourceName: sourceName, image: image)

        let cgImage: CGImage
        do {
            cgImage = try QRCodeScanner.cgImage(from: image)
        } catch {
            windowController.showError("Couldn’t read the image.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let results = try QRCodeScanner.scan(cgImage: cgImage)
                DispatchQueue.main.async {
                    NSLog("QR Reader: found \(results.count) QR code(s)")
                    self?.windowController.show(
                        image: image,
                        results: results,
                        sourceName: sourceName
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self?.windowController.showError("Couldn’t read the image.")
                }
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
