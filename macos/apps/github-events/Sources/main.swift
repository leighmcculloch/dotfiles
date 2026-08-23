import AppKit
import Combine
import SwiftUI
import UserNotifications

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let store = GitHubEventsStore()
    private let notificationCenter = UNUserNotificationCenter.current()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var storeObservation: AnyCancellable?
    private var notificationAuthorizationResolved = false
    private var notificationsAuthorized = false
    private var pendingNotifications: [(username: String, generation: Int, events: [GitHubEvent])] = []
    private var notificationAuthorizationRetryDelay: TimeInterval = 1
    private var notificationAuthorizationRetryScheduled = false
    private var pendingNotificationRetryScheduled = false
    private var notificationIdentifiersByUsername: [String: Set<String>] = [:]

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        notificationCenter.delegate = self
        cleanupNotifications()
        requestNotificationAuthorization()
        store.onNewEvents = { [weak self] username, generation, events in
            self?.notify(username: username, generation: generation, events: events)
        }
        store.onUsernameRemoved = { [weak self] username, generation in
            self?.removeNotifications(for: username, generation: generation)
        }
        setupStatusItem()
        setupPopover()
        storeObservation = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        store.startPolling()
    }

    private func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if error != nil {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        switch settings.authorizationStatus {
                        case .authorized, .provisional:
                            self.finishNotificationAuthorization(granted: true)
                        case .denied:
                            self.finishNotificationAuthorization(granted: false)
                        default:
                            self.retryNotificationAuthorizationLater()
                        }
                    }
                }
                return
            }
            DispatchQueue.main.async {
                self?.finishNotificationAuthorization(granted: granted)
            }
        }
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
            store.beginPresentationSession()
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

    private func notify(username: String, generation: Int, events: [GitHubEvent]) {
        guard !events.isEmpty else { return }
        guard notificationAuthorizationResolved else {
            pendingNotifications.append((username: username, generation: generation, events: events))
            return
        }
        guard notificationsAuthorized else { return }
        scheduleNotification(username: username, generation: generation, events: events)
    }

    private func finishNotificationAuthorization(granted: Bool) {
        notificationAuthorizationResolved = true
        notificationsAuthorized = granted
        notificationAuthorizationRetryDelay = 1
        guard granted else {
            pendingNotifications.removeAll()
            return
        }

        let pendingNotifications = pendingNotifications.filter { pending in
            store.users.contains { $0.username == pending.username }
                && store.configurationGeneration(for: pending.username) == pending.generation
        }
        self.pendingNotifications.removeAll()
        pendingNotifications.forEach {
            scheduleNotification(
                username: $0.username,
                generation: $0.generation,
                events: $0.events
            )
        }
    }

    private func retryNotificationAuthorizationLater() {
        guard !notificationAuthorizationRetryScheduled else { return }
        notificationAuthorizationRetryScheduled = true
        let delay = notificationAuthorizationRetryDelay
        notificationAuthorizationRetryDelay = min(60, delay * 2)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.notificationAuthorizationRetryScheduled = false
            self.requestNotificationAuthorization()
        }
    }

    private func scheduleNotification(
        username: String,
        generation: Int,
        events: [GitHubEvent],
        retryCount: Int = 0
    ) {
        guard !events.isEmpty,
              store.users.contains(where: { $0.username == username }),
              store.configurationGeneration(for: username) == generation
        else { return }

        let sortedEvents = events.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.id > $1.id
            }
            return $0.createdAt > $1.createdAt
        }
        let content = UNMutableNotificationContent()
        content.title = sortedEvents.count == 1
            ? "@\(username) · New GitHub event"
            : "@\(username) · \(sortedEvents.count) new GitHub events"
        content.body = sortedEvents.prefix(3).map { event in
            let presentation = event.presentation
            if presentation.summary.isEmpty || presentation.summary == presentation.title {
                return presentation.title
            }
            return "\(presentation.title) — \(presentation.summary)"
        }.joined(separator: "\n")
        if sortedEvents.count > 3 {
            content.body += "\n+and \(sortedEvents.count - 3) more"
        }
        content.sound = .default
        content.threadIdentifier = "github-events.\(username)"

        let identifier = "github-events.\(username).\(generation).\(sortedEvents.map(\.id).joined(separator: ","))"
        notificationIdentifiersByUsername[username, default: []].insert(identifier)
        notificationCenter.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        ) { [weak self] error in
            guard let self else { return }
            if error == nil {
                DispatchQueue.main.async {
                    guard self.store.users.contains(where: { $0.username == username }),
                          self.store.configurationGeneration(for: username) == generation
                    else {
                        self.notificationIdentifiersByUsername[username]?.remove(identifier)
                        self.notificationCenter.removePendingNotificationRequests(
                            withIdentifiers: [identifier]
                        )
                        self.notificationCenter.removeDeliveredNotifications(
                            withIdentifiers: [identifier]
                        )
                        return
                    }
                    self.notificationIdentifiersByUsername[username]?.remove(identifier)
                }
                return
            }
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    self.notificationIdentifiersByUsername[username]?.remove(identifier)
                    guard self.store.users.contains(where: { $0.username == username }),
                          self.store.configurationGeneration(for: username) == generation
                    else { return }
                    if settings.authorizationStatus == .denied {
                        self.finishNotificationAuthorization(granted: false)
                    } else if settings.authorizationStatus == .notDetermined {
                        self.pendingNotifications.append((username: username, generation: generation, events: events))
                        self.notificationAuthorizationResolved = false
                        self.retryNotificationAuthorizationLater()
                    } else if retryCount == 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                            guard let self,
                                  self.store.users.contains(where: { $0.username == username }),
                                  self.store.configurationGeneration(for: username) == generation
                            else { return }
                            self.scheduleNotification(
                                username: username,
                                generation: generation,
                                events: events,
                                retryCount: 1
                            )
                        }
                    } else {
                        self.pendingNotifications.append((username: username, generation: generation, events: events))
                        self.retryPendingNotificationsLater()
                    }
                }
            }
        }
    }

    private func removeNotifications(for username: String, generation: Int) {
        let knownIdentifiers = Array(
            (notificationIdentifiersByUsername.removeValue(forKey: username) ?? [])
                .filter {
                    Self.notificationIdentifier(
                        $0,
                        belongsTo: username,
                        generation: generation
                    )
                }
        )
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiers = requests
                .filter {
                    Self.notificationIdentifier(
                        $0.identifier,
                        belongsTo: username,
                        generation: generation
                    )
                }
                .map(\.identifier)
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.store.configurationGeneration(for: username) >= generation
                else { return }
                self.notificationCenter.removePendingNotificationRequests(
                    withIdentifiers: Array(Set(identifiers).union(knownIdentifiers))
                )
            }
        }
        notificationCenter.getDeliveredNotifications { notifications in
            let identifiers = notifications
                .filter {
                    Self.notificationIdentifier(
                        $0.request.identifier,
                        belongsTo: username,
                        generation: generation
                    )
                }
                .map { $0.request.identifier }
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.store.configurationGeneration(for: username) >= generation
                else { return }
                self.notificationCenter.removeDeliveredNotifications(
                    withIdentifiers: Array(Set(identifiers).union(knownIdentifiers))
                )
            }
        }
    }

    private func cleanupNotifications() {
        let configuredUsernames = Set(store.users.map(\.username))
        let generations = Dictionary(uniqueKeysWithValues: store.users.map {
            ($0.username, store.configurationGeneration(for: $0.username))
        })
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter {
                    Self.shouldRemoveNotification(
                        $0,
                        configuredUsernames: configuredUsernames,
                        generations: generations
                    )
                }
            guard !identifiers.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let currentIdentifiers = self.currentlyStaleNotificationIdentifiers(identifiers)
                guard !currentIdentifiers.isEmpty else { return }
                self.notificationCenter.removePendingNotificationRequests(withIdentifiers: currentIdentifiers)
            }
        }
        notificationCenter.getDeliveredNotifications { notifications in
            let identifiers = notifications
                .map { $0.request.identifier }
                .filter {
                    Self.shouldRemoveNotification(
                        $0,
                        configuredUsernames: configuredUsernames,
                        generations: generations
                    )
                }
            guard !identifiers.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let currentIdentifiers = self.currentlyStaleNotificationIdentifiers(identifiers)
                guard !currentIdentifiers.isEmpty else { return }
                self.notificationCenter.removeDeliveredNotifications(withIdentifiers: currentIdentifiers)
            }
        }
    }

    private func currentlyStaleNotificationIdentifiers(_ identifiers: [String]) -> [String] {
        let configuredUsernames = Set(store.users.map(\.username))
        let generations = Dictionary(uniqueKeysWithValues: store.users.map {
            ($0.username, store.configurationGeneration(for: $0.username))
        })
        return identifiers.filter {
            Self.shouldRemoveNotification(
                $0,
                configuredUsernames: configuredUsernames,
                generations: generations
            )
        }
    }

    private nonisolated static func shouldRemoveNotification(
        _ identifier: String,
        configuredUsernames: Set<String>,
        generations: [String: Int]
    ) -> Bool {
        let prefix = "github-events."
        guard identifier.hasPrefix(prefix) else { return false }
        let suffix = identifier.dropFirst(prefix.count)
        guard let usernameEnd = suffix.firstIndex(of: ".") else { return false }
        let username = String(suffix[..<usernameEnd])
        guard configuredUsernames.contains(username) else { return true }

        let generationAndEvents = suffix[suffix.index(after: usernameEnd)...]
        guard let generationEnd = generationAndEvents.firstIndex(of: "."),
              let generation = Int(generationAndEvents[..<generationEnd])
        else {
            return false
        }
        return generation < (generations[username] ?? 0)
    }

    private nonisolated static func notificationIdentifier(
        _ identifier: String,
        belongsTo username: String,
        generation: Int
    ) -> Bool {
        let prefix = "github-events.\(username)."
        guard identifier.hasPrefix(prefix) else { return false }
        let suffix = identifier.dropFirst(prefix.count)
        guard let separator = suffix.firstIndex(of: "."),
              let identifierGeneration = Int(suffix[..<separator])
        else {
            return true
        }
        return identifierGeneration < generation
    }

    private func retryPendingNotificationsLater() {
        guard !pendingNotificationRetryScheduled else { return }
        pendingNotificationRetryScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self else { return }
            self.pendingNotificationRetryScheduled = false
            guard self.notificationsAuthorized else { return }
            let pendingNotifications = self.pendingNotifications.filter { pending in
                self.store.users.contains { $0.username == pending.username }
                    && self.store.configurationGeneration(for: pending.username) == pending.generation
            }
            self.pendingNotifications.removeAll()
            pendingNotifications.forEach {
                self.scheduleNotification(
                    username: $0.username,
                    generation: $0.generation,
                    events: $0.events
                )
            }
        }
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

private struct GitHubEventsView: View {
    @ObservedObject var store: GitHubEventsStore
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.tint)
                Text("GitHub Events")
                    .font(.headline.weight(.semibold))
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
                    .id(store.presentationSessionID)
            }
        }
        .frame(minWidth: 360, minHeight: 560)
        .background(.regularMaterial)
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
    private let visibilityCoordinateSpace = "github-events-columns"

    var body: some View {
        GeometryReader { viewport in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(store.users) { user in
                        UserEventsColumn(
                            user: user,
                            store: store,
                            visibilityCoordinateSpace: visibilityCoordinateSpace
                        )
                    }
                }
                .padding(12)
            }
            .coordinateSpace(name: visibilityCoordinateSpace)
            .onPreferenceChange(VisibilityPreferenceKey.self) { report in
                markVisibleEvents(report, viewportSize: viewport.size)
            }
        }
        .frame(maxHeight: .infinity)
        .scrollIndicators(.visible)
    }

    private func markVisibleEvents(_ report: VisibilityReport, viewportSize: CGSize) {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }
        let outerViewport = CGRect(origin: .zero, size: viewportSize)
        let columnFrames = Dictionary(
            report.columnFrames.map { ($0.username, $0.frame) },
            uniquingKeysWith: { _, new in new }
        )
        var visibleEventIDsByUsername: [String: Set<String>] = [:]

        for eventFrame in report.eventFrames {
            guard let columnFrame = columnFrames[eventFrame.username] else { continue }
            let visibleFrame = eventFrame.frame
                .intersection(outerViewport)
                .intersection(columnFrame.insetBy(dx: 0, dy: 24))
            let requiredHeight = min(eventFrame.frame.height * 0.5, 80)
            let requiredWidth = eventFrame.frame.width * 0.5
            if visibleFrame.width >= requiredWidth, visibleFrame.height >= requiredHeight {
                visibleEventIDsByUsername[eventFrame.username, default: []].insert(eventFrame.eventID)
            }
        }

        visibleEventIDsByUsername.forEach { username, eventIDs in
            store.markAsSeen(eventIDs, for: username)
        }
    }
}

private struct UserEventsColumn: View {
    let user: GitHubUserEvents
    @ObservedObject var store: GitHubEventsStore
    let visibilityCoordinateSpace: String
    @State private var unreadEventIDs: Set<String>
    @State private var knownEventIDs: Set<String>
    @State private var oldestKnownEventDate: Date?

    init(
        user: GitHubUserEvents,
        store: GitHubEventsStore,
        visibilityCoordinateSpace: String
    ) {
        self.user = user
        self.store = store
        self.visibilityCoordinateSpace = visibilityCoordinateSpace
        let eventIDs = Set(user.events.map(\.id))
        let unreadIDs = Self.initialUnreadEventIDs(
            in: user.events,
            username: user.username,
            store: store
        )
        _knownEventIDs = State(initialValue: eventIDs)
        _unreadEventIDs = State(initialValue: unreadIDs)
        _oldestKnownEventDate = State(initialValue: user.events.map(\.createdAt).min())
    }

    var body: some View {
        let indexedEvents = Array(user.events.enumerated())
        let newPageOneEventIDs = newlyLoadedPageOneEventIDs(in: user.events)
        let displayUnreadEventIDs = unreadEventIDs.union(newPageOneEventIDs)
        let unreadPrefixCount = countUnreadPrefix(
            in: user.events,
            unreadEventIDs: displayUnreadEventIDs
        )
        let unreadEvents = Array(indexedEvents.prefix(unreadPrefixCount))
        let earlierEvents = Array(indexedEvents.dropFirst(unreadPrefixCount))

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("@\(user.username)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                if !unreadEvents.isEmpty {
                    Text("\(unreadEvents.count)")
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
                .overlay(Color.primary.opacity(0.16))

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
                        LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                            if !unreadEvents.isEmpty {
                                Section {
                                    ForEach(unreadEvents, id: \.element.id) { indexedEvent in
                                        EventCardView(
                                            event: indexedEvent.element,
                                            isUnread: true
                                        )
                                        .background(
                                            EventFrameReporter(
                                                eventID: indexedEvent.element.id,
                                                username: user.username,
                                                coordinateSpace: visibilityCoordinateSpace
                                            )
                                        )
                                        .onAppear {
                                            handleEventAppearance(at: indexedEvent.offset)
                                        }
                                    }
                                } header: {
                                    EventSectionHeader(
                                        title: "New when opened",
                                        count: unreadEvents.count,
                                        isUnread: true
                                    )
                                }
                            }

                            if !earlierEvents.isEmpty {
                                Section {
                                    ForEach(earlierEvents, id: \.element.id) { indexedEvent in
                                        EventCardView(
                                            event: indexedEvent.element,
                                            isUnread: false
                                        )
                                        .background(
                                            EventFrameReporter(
                                                eventID: indexedEvent.element.id,
                                                username: user.username,
                                                coordinateSpace: visibilityCoordinateSpace
                                            )
                                        )
                                        .onAppear {
                                            handleEventAppearance(at: indexedEvent.offset)
                                        }
                                    }
                                } header: {
                                    EventSectionHeader(
                                        title: "Earlier in feed",
                                        count: nil,
                                        isUnread: false
                                    )
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
                        .padding(.top, 2)
                        .padding(.bottom, 8)
                }
                .background(
                    ColumnFrameReporter(
                        username: user.username,
                        coordinateSpace: visibilityCoordinateSpace
                    )
                )
            }
        }
        .onChange(of: user.events.map(\.id)) { _ in
            synchronizeNewEvents()
        }
        .frame(width: 360, height: 510, alignment: .top)
    }

    private func handleEventAppearance(at index: Int) {
        if index >= max(0, user.events.count - 4) {
            store.loadMore(for: user.username)
        }
    }

    private func synchronizeNewEvents() {
        let currentEventIDs = Set(user.events.map(\.id))
        unreadEventIDs.formUnion(newlyLoadedPageOneEventIDs(in: user.events))
        knownEventIDs = currentEventIDs
        if let currentOldestEventDate = user.events.map(\.createdAt).min() {
            oldestKnownEventDate = min(
                oldestKnownEventDate ?? currentOldestEventDate,
                currentOldestEventDate
            )
        }
    }

    private func newlyLoadedPageOneEventIDs(in events: [GitHubEvent]) -> Set<String> {
        let newEventIDs = Set(events.map(\.id)).subtracting(knownEventIDs)
        guard let oldestKnownEventDate else {
            return newEventIDs
        }
        return Set(
            events.compactMap { event in
                guard newEventIDs.contains(event.id),
                      event.createdAt >= oldestKnownEventDate
                else { return nil }
                return event.id
            }
        )
    }

    private func countUnreadPrefix(
        in events: [GitHubEvent],
        unreadEventIDs: Set<String>
    ) -> Int {
        var count = 0
        for event in events {
            guard unreadEventIDs.contains(event.id) else { break }
            count += 1
        }
        return count
    }

    private static func initialUnreadEventIDs(
        in events: [GitHubEvent],
        username: String,
        store: GitHubEventsStore
    ) -> Set<String> {
        var unreadIDs = Set<String>()
        for event in events {
            guard !store.isSeen(event.id, for: username) else { break }
            unreadIDs.insert(event.id)
        }
        return unreadIDs
    }

}

private struct EventFrame: Equatable {
    let eventID: String
    let username: String
    let frame: CGRect
}

private struct ColumnFrame: Equatable {
    let username: String
    let frame: CGRect
}

private struct VisibilityReport: Equatable {
    var eventFrames: [EventFrame] = []
    var columnFrames: [ColumnFrame] = []
}

private struct VisibilityPreferenceKey: PreferenceKey {
    static var defaultValue = VisibilityReport()

    static func reduce(value: inout VisibilityReport, nextValue: () -> VisibilityReport) {
        let next = nextValue()
        value.eventFrames.append(contentsOf: next.eventFrames)
        value.columnFrames.append(contentsOf: next.columnFrames)
    }
}

private struct EventFrameReporter: View {
    let eventID: String
    let username: String
    let coordinateSpace: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: VisibilityPreferenceKey.self,
                value: VisibilityReport(eventFrames: [
                    EventFrame(
                        eventID: eventID,
                        username: username,
                        frame: proxy.frame(in: .named(coordinateSpace))
                    )
                ])
            )
        }
    }
}

private struct ColumnFrameReporter: View {
    let username: String
    let coordinateSpace: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: VisibilityPreferenceKey.self,
                value: VisibilityReport(columnFrames: [
                    ColumnFrame(
                        username: username,
                        frame: proxy.frame(in: .named(coordinateSpace))
                    )
                ])
            )
        }
    }
}

private struct EventSectionHeader: View {
    let title: String
    let count: Int?
    let isUnread: Bool

    var body: some View {
        HStack(spacing: 7) {
            if isUnread {
                Circle()
                    .fill(.tint)
                    .frame(width: 7, height: 7)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if let count {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                    .foregroundStyle(.tint)
            }

            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 5)
        .background(.regularMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct EventCardView: View {
    let event: GitHubEvent
    let isUnread: Bool

    var body: some View {
        let presentation = event.presentation
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Text(event.createdAt, style: .relative)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .fixedSize()
            }

            Text(presentation.summary)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let markdownBody = presentation.markdownBody,
               !markdownBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
                    .opacity(0.7)
                MarkdownText(markdown: markdownBody)
            }

            HStack {
                Text(event.type.replacingOccurrences(of: "Event", with: ""))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if let url = presentation.url {
                    Link("Open on GitHub", destination: url)
                        .font(.caption.weight(.medium))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(isUnread ? 0.9 : 0.65), lineWidth: 0.7)
        )
        .overlay(alignment: .leading) {
            if isUnread {
                Capsule()
                    .fill(.tint)
                    .frame(width: 3)
                    .padding(.vertical, 12)
                    .padding(.leading, 1)
            }
        }
        .textSelection(.enabled)
        .accessibilityLabel(Text(presentation.title))
        .accessibilityElement(children: .contain)
        .accessibilityValue(Text(
            "\(isUnread ? "New when opened" : "Earlier in feed") · \(presentation.summary)"
        ))
    }
}

private struct MarkdownText: View {
    let markdown: String

    var body: some View {
        if let attributedString = try? AttributedString(markdown: markdown) {
            Text(attributedString)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(markdown)
                .font(.callout)
                .foregroundStyle(.primary)
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
