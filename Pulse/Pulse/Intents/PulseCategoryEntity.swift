import Foundation
import AppIntents

/// AppEntity wrapper around `EventCategory` so iOS Focus Filter configuration UI
/// can render the list of categories the user picks from when adding Pulse's filter
/// to one of their Focus modes.
struct PulseCategoryEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Event category"
    static let defaultQuery = PulseCategoryEntityQuery()

    var id: String
    var displayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    static func from(_ category: EventCategory) -> PulseCategoryEntity {
        PulseCategoryEntity(id: category.rawValue, displayName: category.displayName)
    }
}

/// Returns the full set of Pulse categories for the Focus configuration picker.
/// Lookup by id is straightforward because the id is the EventCategory raw value.
struct PulseCategoryEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PulseCategoryEntity] {
        identifiers.compactMap {
            EventCategory(rawValue: $0).map(PulseCategoryEntity.from)
        }
    }

    func suggestedEntities() async throws -> [PulseCategoryEntity] {
        EventCategory.allCases.map(PulseCategoryEntity.from)
    }
}
