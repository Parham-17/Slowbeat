import Foundation
import SwiftData

/// Single-row settings document. Keeps everything user-tunable in one place.
@Model
final class PulseSettings {
    var monitoredCategoriesRaw: [String]
    var reminderMinutesBefore: Int
    var notificationsEnabled: Bool
    var hasCompletedOnboarding: Bool

    /// Optional so the SwiftData store can migrate without intervention; reads as "box" when nil.
    var breathingPatternRaw: String?

    /// Optional, defaults true. When false, BreathingView skips the Core Haptics playback.
    var hapticsEnabled: Bool?

    /// Optional, defaults false. When true, BreathingView dims its visual chrome so the
    /// haptic carries the ritual and the screen can be glanced at rather than watched.
    var eyesUpMode: Bool?

    init(
        monitoredCategories: [EventCategory] = [.presentation, .interview, .exam, .conversation],
        reminderMinutesBefore: Int = 15,
        notificationsEnabled: Bool = true,
        hasCompletedOnboarding: Bool = false,
        breathingPattern: BreathingPattern.Key = .box,
        hapticsEnabled: Bool = true,
        eyesUpMode: Bool = false
    ) {
        self.monitoredCategoriesRaw = monitoredCategories.map(\.rawValue)
        self.reminderMinutesBefore = reminderMinutesBefore
        self.notificationsEnabled = notificationsEnabled
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.breathingPatternRaw = breathingPattern.rawValue
        self.hapticsEnabled = hapticsEnabled
        self.eyesUpMode = eyesUpMode
    }

    var monitoredCategories: Set<EventCategory> {
        get { Set(monitoredCategoriesRaw.compactMap(EventCategory.init(rawValue:))) }
        set { monitoredCategoriesRaw = newValue.map(\.rawValue) }
    }

    var breathingPattern: BreathingPattern {
        get { BreathingPattern.from(rawKey: breathingPatternRaw) }
        set { breathingPatternRaw = newValue.key.rawValue }
    }

    var haptics: Bool {
        get { hapticsEnabled ?? true }
        set { hapticsEnabled = newValue }
    }

    var eyesUp: Bool {
        get { eyesUpMode ?? false }
        set { eyesUpMode = newValue }
    }
}
