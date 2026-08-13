import Foundation
import SwiftData

/// Owns the SwiftData stack (schema + migration plan + container creation) as its own
/// architectural boundary, kept out of views and domain logic per CLAUDE.md §4.
enum PersistenceController {
    static let schema = Schema(versionedSchema: KyleOSSchemaV14.self)

    /// Namespaced under a `KyleOS/` subdirectory rather than SwiftData's bare, unnamed default
    /// location. Kyle OS isn't sandboxed yet (deliberately, Decision Gate E), which means an
    /// unnamed `ModelConfiguration()` resolves to the *shared*, machine-wide
    /// `~/Library/Application Support/default.store` — the same generic path any other
    /// unsandboxed app on the Mac would use if it also didn't specify its own location. That's
    /// not a hypothetical: a real collision happened (a different, unrelated store silently
    /// overwrote Kyle OS's file between sessions). Matches BackupService's existing `KyleOS/`
    /// namespacing for backups (CLAUDE.md §5: data safety over polish).
    static var storeDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("KyleOS", isDirectory: true)
    }

    private static var storeURL: URL {
        storeDirectory.appendingPathComponent("default.store")
    }

    /// The app's real, on-disk container. `fatalError` on failure matches SwiftData's own
    /// default template behavior — Foundation does not yet have a recovery path for a store
    /// that fails to open at all (that's the backup/recovery work in a later Foundation step).
    static func makeContainer() -> ModelContainer {
        do {
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            return try ModelContainer(
                for: schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
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
