import AppKit
import CoreImage
import MetalKit
import ScreenCaptureKit

enum DisplayError: LocalizedError {
    case unavailable, exclusionFailed, interrupted, renderingFailed

    var errorDescription: String? {
        switch self {
        case .unavailable: return "No capturable display or Metal GPU is available."
        case .exclusionFailed: return "Could not exclude the simulation overlays from capture. Try starting again."
        case .interrupted: return "Screen capture was interrupted. The simulation has stopped."
        case .renderingFailed: return "Could not render the simulation. The simulation has stopped."
        }
    }
}

// Never takes focus or intercepts input: clicks go to the real windows below.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class DisplayOverlay: NSObject, SCStreamOutput, SCStreamDelegate, MTKViewDelegate {
    let displayID: CGDirectDisplayID
    let window: NSWindow
    private let view: MTKView
    private let context: CIContext
    private let commandQueue: MTLCommandQueue
    private let colourSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private var matrix: [Double]
    private var stream: SCStream?
    private let lock = NSLock()
    private var latestFrame: CVPixelBuffer?
    private var drawPending = false
    private var stopped = false
    private let createdAt = ProcessInfo.processInfo.systemUptime
    private var receivedAt = ProcessInfo.processInfo.systemUptime
    @MainActor
    private(set) var hasRendered = false
    @MainActor
    var onFailure: ((Error) -> Void)?

    @MainActor
    init(screen: NSScreen, simulation: Simulation) throws {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue()
        else { throw DisplayError.unavailable }
        displayID = id.uint32Value
        matrix = simulation.matrix
        commandQueue = queue
        // Core Image converts captured sRGB into linear sRGB before applying
        // the matrix, then encodes back to sRGB at the render destination.
        context = CIContext(mtlDevice: device, options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!,
            .cacheIntermediates: false
        ])
        view = MTKView(frame: NSRect(origin: .zero, size: screen.frame.size), device: device)
        view.framebufferOnly = false
        view.colorPixelFormat = .bgra8Unorm
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.wantsLayer = true
        if let layer = view.layer as? CAMetalLayer {
            layer.isOpaque = false
            layer.colorspace = colourSpace
        }
        window = OverlayWindow(
            contentRect: screen.frame, styleMask: [.borderless],
            backing: .buffered, defer: false, screen: screen
        )
        window.setFrame(screen.frame, display: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = view
        super.init()
        view.delegate = self
        // Allocate the WindowServer window while the view is still transparent,
        // so its SCWindow can be explicitly excluded BEFORE rendering anything.
        window.orderFrontRegardless()
    }

    @MainActor
    func start(display: SCDisplay, excluding windows: [SCWindow]) async throws {
        let configuration = SCStreamConfiguration()
        let scale = window.screen?.backingScaleFactor ?? 1
        configuration.width = Int(window.frame.width * scale)
        configuration.height = Int(window.frame.height * scale)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.colorSpaceName = CGColorSpace.sRGB
        // Keep the real hardware cursor; capturing it would show two cursors.
        configuration.showsCursor = false
        configuration.capturesAudio = false
        let filter = SCContentFilter(display: display, excludingWindows: windows)
        let capture = SCStream(filter: filter, configuration: configuration, delegate: self)
        stream = capture
        try capture.addStreamOutput(
            self, type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "ColourBlindness.capture.\(displayID)")
        )
        try await capture.startCapture()
        // A stop can race the asynchronous start. Never leave that stream live.
        if isStopped { try? await capture.stopCapture() }
    }

    private var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    @MainActor
    func update(_ simulation: Simulation) {
        matrix = simulation.matrix
        view.draw()
    }

    @MainActor
    var isHealthy: Bool {
        lock.lock()
        let lastReceived = receivedAt
        lock.unlock()
        let now = ProcessInfo.processInfo.systemUptime
        return now - lastReceived < 5 && (hasRendered || now - createdAt < 5)
    }

    @MainActor
    func stop() {
        lock.lock()
        stopped = true
        latestFrame = nil
        lock.unlock()
        window.orderOut(nil)
        window.close()
        view.delegate = nil
        onFailure = nil
        if let stream {
            self.stream = nil
            Task { try? await stream.stopCapture() }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.onFailure?(error) }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus)
        else { return }
        if status == .blank || status == .suspended || status == .stopped {
            DispatchQueue.main.async { [weak self] in self?.onFailure?(DisplayError.interrupted) }
            return
        }
        lock.lock()
        defer { lock.unlock() }
        guard !stopped else { return }
        receivedAt = ProcessInfo.processInfo.systemUptime
        // Idle is healthy: an unchanged desktop needs no new image.
        guard status == .complete, let frame = sampleBuffer.imageBuffer else { return }
        latestFrame = frame
        guard !drawPending else { return }
        drawPending = true
        // Retain only the latest frame, not a backlog of captured desktops.
        DispatchQueue.main.async { [weak self] in self?.view.draw() }
    }

    @MainActor
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    @MainActor
    func draw(in view: MTKView) {
        lock.lock()
        let frame = stopped ? nil : latestFrame
        drawPending = false
        lock.unlock()
        guard let frame else { return }
        guard let drawable = view.currentDrawable,
              let command = commandQueue.makeCommandBuffer()
        else {
            onFailure?(DisplayError.renderingFailed)
            return
        }
        let input = CIImage(cvPixelBuffer: frame, options: [.colorSpace: colourSpace])
        let output = input.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: matrix[0], y: matrix[1], z: matrix[2], w: 0),
            "inputGVector": CIVector(x: matrix[3], y: matrix[4], z: matrix[5], w: 0),
            "inputBVector": CIVector(x: matrix[6], y: matrix[7], z: matrix[8], w: 0)
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])
        let bounds = CGRect(x: 0, y: 0, width: drawable.texture.width, height: drawable.texture.height)
        let scaled = output.transformed(by: CGAffineTransform(
            scaleX: bounds.width / input.extent.width,
            y: bounds.height / input.extent.height
        ))
        context.render(scaled, to: drawable.texture, commandBuffer: command, bounds: bounds, colorSpace: colourSpace)
        command.present(drawable)
        command.addCompletedHandler { [weak self] buffer in
            DispatchQueue.main.async {
                guard let self else { return }
                if buffer.status == .error {
                    self.onFailure?(DisplayError.renderingFailed)
                } else {
                    self.hasRendered = true
                }
            }
        }
        command.commit()
    }
}
