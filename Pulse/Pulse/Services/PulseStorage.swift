import Foundation
import SwiftData
import os

/// Single SwiftData save funnel. Replaces scattered `try? context.save()` calls so
/// that disk / migration failures are logged instead of silently swallowed.
enum PulseStorage {
    static let logger = Logger(subsystem: "app.pulse.storage", category: "save")

    @discardableResult
    static func save(_ context: ModelContext, reason: StaticString) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            logger.error("save failed [\(reason, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
