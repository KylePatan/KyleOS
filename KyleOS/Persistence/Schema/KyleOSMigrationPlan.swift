import SwiftData

/// The single source of truth for how Kyle OS's on-disk schema evolves over time.
///
/// Currently one version, no migration stages — but the plan exists from Foundation V0 so that
/// adding KyleOSSchemaV2 later is a matter of appending a schema and a migration stage, not
/// inventing this infrastructure under pressure. Never resolve a future model change by
/// deleting the user's store (CLAUDE.md §5).
enum KyleOSMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [KyleOSSchemaV1.self, KyleOSSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// V2 only adds a new entity (Document) and a relationship pointing at it — no existing
    /// attribute changed shape, so lightweight migration is sufficient. Test coverage for this
    /// exact transition lives in KyleOSTests/SchemaMigrationTests.swift.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV1.self,
        toVersion: KyleOSSchemaV2.self
    )
}
