import Foundation

/// Persists the active Focus-filter category selection. The SetFocusFilterIntent writes
/// here when iOS activates a Focus that has Pulse's filter configured; AppState reads it
/// to override the user's default monitored-categories set for the duration.
///
/// Storage is a plain string-array of `EventCategory` raw values, no metadata. If no
/// array is present (or it's empty), there is no active filter and the app falls back
/// to the user's PulseSettings.monitoredCategories.
enum FocusFilterStore {
    nonisolated private static let key = "pulse.focusFilter.categories.v1"

    nonisolated static func write(_ categories: Set<EventCategory>?) {
        if let categories, categories.isEmpty == false {
            UserDefaults.standard.set(Array(categories.map(\.rawValue)), forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// nil when no Focus filter is active. Empty arrays in storage are treated as nil
    /// so the absence-of-filter case is unambiguous.
    static func read() -> Set<EventCategory>? {
        guard let raws = UserDefaults.standard.stringArray(forKey: key) else { return nil }
        let categories = Set(raws.compactMap(EventCategory.init(rawValue:)))
        return categories.isEmpty ? nil : categories
    }
}
