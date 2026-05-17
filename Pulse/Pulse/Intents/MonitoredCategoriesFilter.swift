import AppIntents

/// Focus Filter intent. When the user adds Pulse's filter to one of their iOS Focus
/// modes (Settings → Focus → [Focus] → Filters → Add Filter → Pulse), they pick which
/// event categories Pulse should watch for while that Focus is active.
///
/// iOS calls `perform()` when the Focus turns on or off and when the configuration
/// changes. The intent writes the current selection to `FocusFilterStore`, which
/// AppState reads on bootstrap to override the user's default category set.
///
/// Why this exists: no other breathing app uses FocusFilter. It's a uniquely
/// Pulse-shaped feature because Pulse already projects calendar events into typed
/// categories — Work Focus shows work-only moments, Personal Focus shows the others.
struct MonitoredCategoriesFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Categories to watch"
    static let description = IntentDescription(
        "Pick which event categories Slowbeat should suggest moments for while this Focus is active."
    )

    /// SetFocusFilterIntent requires every @Parameter to be Optional — iOS treats nil
    /// as "user hasn't configured this yet."
    @Parameter(title: "Categories")
    var categories: [PulseCategoryEntity]?

    /// Rendered in the Focus configuration UI so the user can see at a glance which
    /// filter applies to which Focus mode.
    var displayRepresentation: DisplayRepresentation {
        let resolved = categories ?? []
        guard resolved.isEmpty == false else {
            return DisplayRepresentation(title: "No categories")
        }
        let names = resolved.map(\.displayName).joined(separator: ", ")
        return DisplayRepresentation(title: "Watching: \(names)")
    }

    func perform() async throws -> some IntentResult {
        let resolved = Set((categories ?? []).compactMap { EventCategory(rawValue: $0.id) })
        FocusFilterStore.write(resolved.isEmpty ? nil : resolved)
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Watch \(\.$categories)")
    }
}
