import SwiftUI
import SwiftData

struct RemindersSection: View {
    let settings: PulseSettings
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

    var body: some View {
        SettingsSectionCard(title: "Reminders") {
            VStack(spacing: 14) {
                Toggle(isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { newValue in
                        settings.notificationsEnabled = newValue
                        PulseStorage.save(context, reason: "notifications toggle")
                        Task {
                            if newValue {
                                _ = await app.notifier.requestAccess()
                                await app.notifier.reschedule(for: app.calendar.upcoming, minutesBefore: settings.reminderMinutesBefore)
                            } else {
                                await app.notifier.cancelAll()
                            }
                        }
                    }
                )) {
                    Text("Nudge me before")
                        .font(PulseType.body(15))
                        .foregroundStyle(Theme.inkPrimary)
                }
                .tint(Theme.coolA)

                if settings.notificationsEnabled {
                    HStack {
                        Text("How early")
                            .font(PulseType.body(15))
                            .foregroundStyle(Theme.inkPrimary)
                        Spacer()
                        Picker("Minutes before", selection: Binding(
                            get: { settings.reminderMinutesBefore },
                            set: { newValue in
                                settings.reminderMinutesBefore = newValue
                                PulseStorage.save(context, reason: "reminder minutes changed")
                                Task {
                                    await app.notifier.reschedule(for: app.calendar.upcoming, minutesBefore: newValue)
                                }
                            }
                        )) {
                            ForEach([5, 10, 15, 20, 30, 45, 60], id: \.self) { minute in
                                Text("\(minute) min").tag(minute)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.inkPrimary)
                    }
                }
            }
        }
    }
}
