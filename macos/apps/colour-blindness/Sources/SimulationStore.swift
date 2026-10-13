import AppKit
import ScreenCaptureKit
import SwiftUI

@MainActor
final class SimulationStore: ObservableObject {
    @Published var simulation = Simulation() {
        didSet { overlays.forEach { $0.update(simulation) } }
    }
    @Published private(set) var isRunning = false
    @Published private(set) var isStarting = false
    @Published private(set) var message = "Simulation is off. Your displays are unchanged."
    private var overlays: [DisplayOverlay] = []
    private var startTask: Task<Void, Never>?
    private var watchdog: Timer?
    private var generation = 0
    private var streamsStarted = false

    func start() {
        guard !isRunning, !isStarting else { return }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            message = "Allow Colour Blindness in System Settings → Privacy & Security → Screen Recording, then quit and reopen the app."
            return
        }
        isStarting = true
        message = "Starting display capture…"
        generation += 1
        let session = generation
        startTask = Task { [weak self] in
            guard let self else { return }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                try Task.checkCancellation()
                guard session == self.generation else { return }
                for screen in NSScreen.screens {
                    let overlay = try DisplayOverlay(screen: screen, simulation: self.simulation)
                    overlay.onFailure = { [weak self] error in
                        guard let self, session == self.generation else { return }
                        self.stop(message: error.localizedDescription)
                    }
                    self.overlays.append(overlay)
                }
                guard !self.overlays.isEmpty else { throw DisplayError.unavailable }
                self.watchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.checkCapture() }
                }
                // Exclude only overlay windows, not the app itself. Its controls
                // are captured and transformed once, just like every other app.
                let withOverlays = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                try Task.checkCancellation()
                guard session == self.generation else { return }
                let ids = Set(self.overlays.map { CGWindowID($0.window.windowNumber) })
                let excluded = withOverlays.windows.filter { ids.contains($0.windowID) }
                guard excluded.count == ids.count else { throw DisplayError.exclusionFailed }
                for overlay in self.overlays {
                    guard let display = content.displays.first(where: { $0.displayID == overlay.displayID }) else {
                        throw DisplayError.unavailable
                    }
                    try await overlay.start(display: display, excluding: excluded)
                    try Task.checkCancellation()
                    guard session == self.generation else { return }
                }
                self.streamsStarted = true
                // Stay in Starting until all displays actually render a frame.
                self.checkCapture()
            } catch {
                if session == self.generation {
                    self.stop(message: "Could not start simulation: \(error.localizedDescription)")
                }
            }
        }
    }

    func stop(message: String = "Simulation is off. Your displays are unchanged.") {
        generation += 1
        startTask?.cancel()
        startTask = nil
        watchdog?.invalidate()
        watchdog = nil
        overlays.forEach { $0.stop() }
        overlays.removeAll()
        isRunning = false
        isStarting = false
        streamsStarted = false
        self.message = message
    }

    private func checkCapture() {
        guard overlays.allSatisfy(\.isHealthy) else {
            stop(message: "Screen capture stopped responding. The simulation has stopped.")
            return
        }
        if isStarting, streamsStarted, overlays.allSatisfy(\.hasRendered) {
            isStarting = false
            isRunning = true
            message = "Simulation is on across \(overlays.count) display\(overlays.count == 1 ? "" : "s")."
            startTask = nil
        }
    }
}
