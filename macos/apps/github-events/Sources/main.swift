import AppKit
import Combine
import SwiftUI

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = GitHubEventsStore()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var storeObservation: AnyCancellable?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        storeObservation = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        store.startPolling()
    }

    func applicationWillTerminate(_: Notification) {
        store.stopPolling()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "arrow.triangle.branch",
            accessibilityDescription: "GitHub Events"
        )
        button.target = self
        button.action = #selector(togglePopover)
        button.toolTip = "GitHub Events"
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 820, height: 620)
        popover.contentViewController = NSHostingController(
            rootView: GitHubEventsView(store: store)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            updateStatusItem()
        }
    }

    private func updateStatusItem() {
        let unseenCount = store.users.reduce(0) { $0 + $1.unseenCount }
        statusItem.button?.toolTip = unseenCount == 0
            ? "GitHub Events"
            : "GitHub Events · \(unseenCount) new"
    }
}

private struct GitHubEventsView: View {
    @ObservedObject var store: GitHubEventsStore
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.secondary)
                Text("GitHub Events")
                    .font(.headline)
                if let total = unseenCountLabel {
                    Text(total)
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
                Spacer()
                Button {
                    store.refreshAll()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
                Button {
                    showingSettings.toggle()
                } label: {
                    Image(systemName: showingSettings ? "xmark" : "gearshape")
                }
                .buttonStyle(.borderless)
                .help(showingSettings ? "Close settings" : "Configure usernames")
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("Quit")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider()

            if showingSettings {
                UserSettingsView(store: store)
                    .frame(maxHeight: 250)
            } else if store.users.isEmpty {
                EmptyStateView {
                    showingSettings = true
                }
            } else {
                UserColumnsView(store: store)
            }
        }
        .frame(minWidth: 360, minHeight: 560)
        .background(.regularMaterial)
    }

    private var unseenCountLabel: String? {
        let count = store.users.reduce(0) { $0 + $1.unseenCount }
        return count == 0 ? nil : "\(count) new"
    }
}

private struct EmptyStateView: View {
    let configure: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.crop.square.stack")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Follow GitHub activity")
                .font(.headline)
            Text("Add one or more public GitHub usernames to get started.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Configure usernames", action: configure)
                .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct UserSettingsView: View {
    @ObservedObject var store: GitHubEventsStore
    @State private var username = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Usernames")
                .font(.subheadline.weight(.semibold))

            HStack {
                TextField("GitHub username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addUsername)
                Button("Add", action: addUsername)
                    .buttonStyle(.borderedProminent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if store.users.isEmpty {
                Text("No usernames configured yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 4) {
                        ForEach(store.users) { user in
                            HStack {
                                Text("@\(user.username)")
                                Spacer()
                                Button {
                                    store.removeUsername(user.username)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("Remove @\(user.username)")
                            }
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
        .padding(14)
    }

    private func addUsername() {
        let result = store.addUsername(username)
        if let result {
            errorMessage = result.localizedDescription
        } else {
            username = ""
            errorMessage = nil
        }
    }
}

private struct UserColumnsView: View {
    @ObservedObject var store: GitHubEventsStore

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(store.users) { user in
                    UserEventsColumn(user: user, store: store)
                }
            }
            .padding(12)
        }
        .scrollIndicators(.visible)
    }
}

private struct UserEventsColumn: View {
    let user: GitHubUserEvents
    @ObservedObject var store: GitHubEventsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("@\(user.username)")
                    .font(.subheadline.weight(.semibold))
                if user.unseenCount > 0 {
                    Text("\(user.unseenCount)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.tint))
                        .foregroundStyle(.white)
                }
                Spacer()
                if user.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let errorMessage = user.errorMessage {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Retry") {
                        store.retry(for: user.username)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            Divider()

            if user.events.isEmpty {
                VStack(spacing: 8) {
                    if user.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                        Text("No recent public events")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(user.events.enumerated()), id: \.element.id) { index, event in
                            EventCardView(
                                event: event,
                                isSeen: store.isSeen(event.id, for: user.username)
                            )
                            .onAppear {
                                store.markAsSeen(event.id, for: user.username)
                                if index >= max(0, user.events.count - 4) {
                                    store.loadMore(for: user.username)
                                }
                            }
                        }

                        if user.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        } else if !user.hasMore {
                            Text("End of available public activity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 360, height: 510, alignment: .top)
    }
}

private struct EventCardView: View {
    let event: GitHubEvent
    let isSeen: Bool

    var body: some View {
        let presentation = event.presentation
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Text(event.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            Text(presentation.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let markdownBody = presentation.markdownBody,
               !markdownBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MarkdownText(markdown: markdownBody)
            }

            HStack {
                Text(event.type.replacingOccurrences(of: "Event", with: ""))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if let url = presentation.url {
                    Link("Open on GitHub", destination: url)
                        .font(.caption2)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
        )
        .opacity(isSeen ? 0.52 : 1)
        .textSelection(.enabled)
    }
}

private struct MarkdownText: View {
    let markdown: String

    var body: some View {
        if let attributedString = try? AttributedString(markdown: markdown) {
            Text(attributedString)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(markdown)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

let app = NSApplication.shared
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    app.delegate = delegate
}
app.run()
