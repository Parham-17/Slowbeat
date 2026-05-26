import SwiftUI
import SwiftData
import UIKit

struct PermissionsSection: View {
    let settings: PulseSettings
    @Environment(AppState.self) private var app

    var body: some View {
        SettingsSectionCard(title: "Access") {
            VStack(spacing: 12) {
                row(
                    title: "Calendar",
                    detail: "Suggests moments before important events.",
                    state: calendarStateLabel,
                    isGranted: app.calendar.access == .granted
                ) {
                    Task {
                        if app.calendar.access == .denied || app.calendar.access == .restricted {
                            openSystemSettings()
                        } else {
                            _ = await app.calendar.requestAccess()
                            await app.calendar.loadUpcoming(monitoring: settings.monitoredCategories)
                        }
                    }
                }

                Divider().background(Theme.cardStroke)

                row(
                    title: "Notifications",
                    detail: "So you don't miss the moment.",
                    state: notifStateLabel,
                    isGranted: app.notifier.access == .granted || app.notifier.access == .provisional
                ) {
                    Task { _ = await app.notifier.requestAccess() }
                }
            }
        }
    }

    private var calendarStateLabel: String {
        switch app.calendar.access {
        case .granted:    "On"
        case .denied:     "Off — open Settings"
        case .restricted: "Restricted"
        case .unknown:    "Allow"
        }
    }

    private var notifStateLabel: String {
        switch app.notifier.access {
        case .granted:     "On"
        case .provisional: "Quiet"
        case .denied:      "Off — open Settings"
        case .unknown:     "Allow"
        }
    }

    private func row(title: String, detail: String, state: String, isGranted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .fill(isGranted ? Theme.coolA : Theme.inkTertiary.opacity(0.4))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PulseType.headline(15))
                        .foregroundStyle(Theme.inkPrimary)
                    Text(detail)
                        .font(PulseType.caption(12))
                        .foregroundStyle(Theme.inkTertiary)
                }
                Spacer()
                Text(state)
                    .font(PulseType.caption(13))
                    .foregroundStyle(Theme.inkSecondary)
                Image(systemName: "chevron.right")
                    .font(PulseType.caption(11))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
