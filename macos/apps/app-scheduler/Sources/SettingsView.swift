import SwiftUI

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
                Text("On").frame(width: 36)
                Text("App or URL").frame(width: 320, alignment: .leading)
                Text("Action").frame(width: 90, alignment: .leading)
                Text("Cron").frame(width: 210, alignment: .leading)
                Text("When (local time)").frame(width: 215, alignment: .leading)
                Spacer()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            Divider()

            ScrollView {
                if store.schedules.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar").font(.largeTitle)
                        Text("No schedules yet").font(.headline)
                        Text("Add a schedule to get started. New rows default to 9am Monday–Friday.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach($store.schedules) { $schedule in
                            ScheduleRow(schedule: $schedule, applications: store.applications) {
                                let id = schedule.id
                                store.schedules.removeAll { $0.id == id }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
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
        .frame(minWidth: 1020, minHeight: 420)
    }
}

private struct ScheduleRow: View {
    @Binding var schedule: ScheduledAction
    let applications: [InstalledApp]
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
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

            TextField("0 9 * * 1-5", text: $schedule.cron)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Cron schedule")
                .help("minute (0–59) hour (0–23) day (1–31) month (1–12) weekday (0–7, Sunday = 0 or 7). Supports *, lists, ranges, and /steps. No seconds or commands.")
                .frame(width: 210)

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
