import Foundation
import SwiftData

/// Owns the SwiftData stack (schema + migration plan + container creation) as its own
/// architectural boundary, kept out of views and domain logic per CLAUDE.md §4.
enum PersistenceController {
    static let schema = Schema(versionedSchema: KyleOSSchemaV7.self)

    /// The app's real, on-disk container. `fatalError` on failure matches SwiftData's own
    /// default template behavior — Foundation does not yet have a recovery path for a store
    /// that fails to open at all (that's the backup/recovery work in a later Foundation step).
    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration()]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// An isolated, in-memory container for tests and previews so dev/test data never touches
    /// the real store (Foundation acceptance criteria: "test/dev data kept separate").
    static func makeInMemoryContainer() -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }
}
