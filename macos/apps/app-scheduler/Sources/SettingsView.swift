import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppSchedulerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Scheduler").font(.title2.bold())
            Text("Choose an app or enter an app URL, then set the action, time, and days. URLs support Open only. Add multiple rows for different times.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Text("On").frame(width: 36)
                Text("App or URL").frame(width: 320, alignment: .leading)
                Text("Action").frame(width: 90, alignment: .leading)
                Text("Time").frame(width: 105, alignment: .leading)
                Text("Days").frame(width: 280, alignment: .leading)
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
                        Text("Add a schedule to get started. New rows default to Monday–Friday.")
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

    private let days: [(Int, String, String)] = [
        (2, "Mon", "Monday"), (3, "Tue", "Tuesday"), (4, "Wed", "Wednesday"),
        (5, "Thu", "Thursday"), (6, "Fri", "Friday"), (7, "Sat", "Saturday"),
        (1, "Sun", "Sunday")
    ]

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

            DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .frame(width: 105)

            HStack(spacing: 4) {
                ForEach(days, id: \.0) { day, shortName, fullName in
                    Toggle(shortName, isOn: Binding(
                        get: { schedule.weekdays.contains(day) },
                        set: { selected in
                            if selected { schedule.weekdays.insert(day) }
                            else { schedule.weekdays.remove(day) }
                        }
                    ))
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .accessibilityLabel(fullName)
                }
            }
            .frame(width: 280, alignment: .leading)
            .help(schedule.weekdays.isEmpty ? "Select at least one day to run this schedule" : "Days this schedule runs")

            Spacer(minLength: 0)
            Button(action: remove) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Remove schedule")
                .accessibilityLabel("Remove schedule for \(schedule.targetName)")
        }
        .opacity(schedule.isEnabled ? 1 : 0.6)
    }

    private var time: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(
                    year: 2001, month: 1, day: 15, hour: schedule.hour, minute: schedule.minute
                ))!
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                schedule.hour = components.hour!
                schedule.minute = components.minute!
            }
        )
    }
}
