import Foundation
import SwiftData

/// Schema version 1 of the Kyle OS data model.
///
/// Models live nested inside their VersionedSchema enum (Apple's recommended pattern) so a
/// future KyleOSSchemaV2 can redefine a model independently without touching this one — that's
/// what makes an explicit SchemaMigrationPlan possible later. Do not rename this enum or bump
/// its version casually; see docs/TECHNICAL_ARCHITECTURE.md §16.3.
enum KyleOSSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Project.self]
    }

    /// A Project is the top-level container for a piece of creative work (a script, a set, a
    /// sketch, etc.). Later phases attach Documents, Work Items, and Sessions to it.
    @Model
    final class Project {
        /// Stable identity independent of title/position — renaming must never break
        /// relationships (docs/TECHNICAL_ARCHITECTURE.md §16.2).
        @Attribute(.unique) var id: UUID
        var title: String
        var createdAt: Date
        var updatedAt: Date
        var isArchived: Bool
        var archivedAt: Date?

        init(id: UUID = UUID(), title: String, createdAt: Date = .now) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = createdAt
            self.isArchived = false
            self.archivedAt = nil
        }
    }
}
