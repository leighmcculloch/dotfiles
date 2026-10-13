import SwiftUI

private let cronColumns: [(title: String, width: CGFloat, help: String)] = [
    ("Minute", 56, "Minute (0–59)"),
    ("Hour", 56, "Hour (0–23)"),
    ("Day", 56, "Day of month (1–31)"),
    ("Month", 56, "Month (1–12)"),
    ("Weekday", 112, "Day of week (0–7, Sunday = 0 or 7)")
]

struct SettingsView: View {
    @ObservedObject var store: AppSchedulerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Scheduler").font(.title2.bold())
            Text("Choose an app or enter an app URL, then set the action and cron schedule. URLs support Open only.")
                .foregroundStyle(.secondary)
            Text("Cron: minute hour day month weekday · 0 9 * * 1-5 = weekdays at 9am · */15 * * * * = every 15 minutes. Each app or exact URL can run at most once per minute.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 16)
                    .help("Drag rows to reorder schedules")
                    .accessibilityLabel("Row order")
                Text("On").frame(width: 36)
                Text("App or URL").frame(width: 320, alignment: .leading)
                Text("Action").frame(width: 90, alignment: .leading)
                HStack(spacing: 6) {
                    ForEach(cronColumns.indices, id: \.self) { index in
                        Text(cronColumns[index].title)
                            .frame(width: cronColumns[index].width)
                            .help(cronColumns[index].help)
                    }
                }
                Text("When (local time)").frame(width: 215, alignment: .leading)
                Spacer()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            Divider()

            List {
                if store.schedules.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar").font(.largeTitle)
                        Text("No schedules yet").font(.headline)
                        Text("Add a schedule to get started. New rows default to 9am Monday–Friday.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach($store.schedules) { $schedule in
                        ScheduleRow(schedule: $schedule, applications: store.applications) {
                            let id = schedule.id
                            store.schedules.removeAll { $0.id == id }
                        }
                        .listRowInsets(EdgeInsets(top: 7, leading: 0, bottom: 7, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                    .onMove { offsets, destination in
                        store.schedules.move(fromOffsets: offsets, toOffset: destination)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack {
                Button("Add Schedule") { store.addSchedule() }
                Button("Add Other App…") { store.chooseOtherApp() }
                Spacer()
                Text("Changes save automatically").font(.caption).foregroundStyle(.secondary)
            }
            Text(store.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(20)
        .frame(minWidth: 1210, minHeight: 420)
    }
}

private struct ScheduleRow: View {
    @Binding var schedule: ScheduledAction
    let applications: [InstalledApp]
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 24)
                .help("Drag to reorder this schedule")
                .accessibilityLabel("Reorder schedule for \(schedule.targetName)")

            Toggle("Enabled", isOn: $schedule.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 36)
                .help("Enable or disable this schedule")

            HStack(spacing: 6) {
                Picker("Target type", selection: Binding(
                    get: { schedule.appURL != nil },
                    set: { useURL in
                        schedule.appURL = useURL ? "" : nil
                        if useURL { schedule.action = .open }
                    }
                )) {
                    Text("App").tag(false)
                    Text("URL").tag(true)
                }
                .labelsHidden()
                .frame(width: 80)

                if schedule.appURL != nil {
                    VStack(alignment: .leading, spacing: 3) {
                        TextField("App URL (e.g. slack://)", text: Binding(
                            get: { schedule.appURL ?? "" },
                            set: { schedule.appURL = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("App URL")
                        .help("Enter a full URL including its scheme. Encode spaces as %20.")
                        if !schedule.targetName.isEmpty && schedule.urlToOpen == nil {
                            Text("Enter a full URL with a scheme.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(width: 234)
                } else {
                    Picker("App", selection: $schedule.appPath) {
                        Text("Select App…").tag("")
                        if !schedule.appPath.isEmpty,
                           !applications.contains(where: { $0.path == schedule.appPath }) {
                            Text("\(schedule.appName) (saved app)").tag(schedule.appPath)
                        }
                        ForEach(applications) { app in
                            Text(applications.filter { $0.name == app.name }.count > 1
                                ? "\(app.name) — \(URL(fileURLWithPath: app.path).deletingLastPathComponent().path)"
                                : app.name
                            ).tag(app.path)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 234)
                    .help(schedule.appPath.isEmpty ? "Select an app" : schedule.appPath)
                }
            }
            .frame(width: 320)

            Picker("Action", selection: $schedule.action) {
                ForEach(AppAction.allCases, id: \.self) { action in
                    Text(action.title).tag(action)
                }
            }
            .labelsHidden()
            .frame(width: 90)
            .disabled(schedule.appURL != nil)
            .help(schedule.appURL != nil ? "URLs can only be opened, not quit" : "Open or quit the app")

            CronEditor(expression: $schedule.cron)

            Group {
                if let description = schedule.scheduleDescription {
                    Text(description)
                        .foregroundStyle(.secondary)
                } else {
                    Text(schedule.cronError ?? "Invalid cron expression")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption)
            .frame(width: 215, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
            Button(action: remove) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Remove schedule")
                .accessibilityLabel("Remove schedule for \(schedule.targetName)")
        }
        .opacity(schedule.isEnabled ? 1 : 0.6)
    }
}

private struct CronEditor: View {
    @Binding var expression: String
    @State private var fields: [String]

    init(expression: Binding<String>) {
        _expression = expression
        _fields = State(initialValue: Self.fields(from: expression.wrappedValue))
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(cronColumns.indices, id: \.self) { index in
                TextField("*", text: Binding(
                    get: { fields[index] },
                    set: { value in
                        let pasted = value.split(whereSeparator: { $0.isWhitespace })
                        if pasted.count == 5 {
                            fields = pasted.map(String.init)
                        } else {
                            fields[index] = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        let tokens = fields.joined(separator: " ").split(whereSeparator: { $0.isWhitespace })
                        if tokens.count == 5 { fields = tokens.map(String.init) }
                        expression = fields.joined(separator: " ")
                    }
                ))
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .frame(width: cronColumns[index].width)
                .accessibilityLabel("Cron \(cronColumns[index].title)")
                .help("\(cronColumns[index].help). Supports *, lists, ranges, and /steps. Paste a five-field cron into any column to fill all five.")
            }
        }
        .onChange(of: expression) { value in
            // Keep blank columns in place while editing; splitting on whitespace
            // after every keystroke would shift the remaining fields to the left.
            if value != fields.joined(separator: " ") {
                fields = Self.fields(from: value)
            }
        }
    }

    private static func fields(from expression: String) -> [String] {
        let tokens = expression.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if tokens.count == 5 { return tokens }
        let columns = expression.components(separatedBy: " ")
        if columns.count == 5 { return columns }
        // Keep extra tokens visible in the last column rather than dropping them
        // and accidentally enabling an invalid saved expression.
        return (0..<4).map { $0 < tokens.count ? tokens[$0] : "" }
            + [tokens.dropFirst(4).joined(separator: " ")]
    }
}
