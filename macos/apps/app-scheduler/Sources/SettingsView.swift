import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppSchedulerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Scheduler").font(.title2.bold())
            Text("Choose an app, action, time, and days. Add multiple rows for the same app to open and quit it at different times.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Text("On").frame(width: 36)
                Text("App").frame(width: 220, alignment: .leading)
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
        .frame(minWidth: 920, minHeight: 420)
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
            .frame(width: 220)
            .help(schedule.appPath.isEmpty ? "Select an app" : schedule.appPath)

            Picker("Action", selection: $schedule.action) {
                ForEach(AppAction.allCases, id: \.self) { action in
                    Text(action.title).tag(action)
                }
            }
            .labelsHidden()
            .frame(width: 90)

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
                .accessibilityLabel("Remove schedule for \(schedule.appPath.isEmpty ? "unselected app" : schedule.appName)")
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
