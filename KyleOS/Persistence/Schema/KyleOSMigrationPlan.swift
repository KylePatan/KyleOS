import SwiftData

/// The single source of truth for how Kyle OS's on-disk schema evolves over time.
///
/// The plan exists from Foundation V0 so that adding a new schema version is a matter of
/// appending a schema and a migration stage, not inventing this infrastructure under pressure.
/// Never resolve a future model change by deleting the user's store (CLAUDE.md §5).
enum KyleOSMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [KyleOSSchemaV1.self, KyleOSSchemaV2.self, KyleOSSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    /// V2 only adds a new entity (Document) and a relationship pointing at it — no existing
    /// attribute changed shape, so lightweight migration is sufficient. Test coverage for this
    /// exact transition lives in KyleOSTests/SchemaMigrationTests.swift.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV1.self,
        toVersion: KyleOSSchemaV2.self
    )

    /// V3 adds WorkItem and a new Project relationship pointing at it — same additive shape as
    /// V1->V2, same lightweight migration approach.
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV2.self,
        toVersion: KyleOSSchemaV3.self
    )
}
