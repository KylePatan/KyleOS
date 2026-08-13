import SwiftData

/// The single source of truth for how Kyle OS's on-disk schema evolves over time.
///
/// The plan exists from Foundation V0 so that adding a new schema version is a matter of
/// appending a schema and a migration stage, not inventing this infrastructure under pressure.
/// Never resolve a future model change by deleting the user's store (CLAUDE.md §5).
enum KyleOSMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [KyleOSSchemaV1.self, KyleOSSchemaV2.self, KyleOSSchemaV3.self, KyleOSSchemaV4.self, KyleOSSchemaV5.self, KyleOSSchemaV6.self, KyleOSSchemaV7.self, KyleOSSchemaV8.self, KyleOSSchemaV9.self, KyleOSSchemaV10.self, KyleOSSchemaV11.self, KyleOSSchemaV12.self, KyleOSSchemaV13.self, KyleOSSchemaV14.self, KyleOSSchemaV15.self, KyleOSSchemaV16.self, KyleOSSchemaV17.self, KyleOSSchemaV18.self, KyleOSSchemaV19.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6, migrateV6toV7, migrateV7toV8, migrateV8toV9, migrateV9toV10, migrateV10toV11, migrateV11toV12, migrateV12toV13, migrateV13toV14, migrateV14toV15, migrateV15toV16, migrateV16toV17, migrateV17toV18, migrateV18toV19]
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

    /// V4 adds Deadline and CalendarEvent, and new optional `deadline` relationships on Project
    /// and WorkItem — additive only, same lightweight approach as the prior two stages.
    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV3.self,
        toVersion: KyleOSSchemaV4.self
    )

    /// V5 adds PlannedSession and WorkSession, and new relationships pointing at them from
    /// WorkItem/CalendarEvent — additive only, same lightweight approach as the prior stages.
    static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV4.self,
        toVersion: KyleOSSchemaV5.self
    )

    /// V6 adds ActiveTimerState and a new relationship pointing at it from WorkItem — additive
    /// only, same lightweight approach as the prior stages.
    static let migrateV5toV6 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV5.self,
        toVersion: KyleOSSchemaV6.self
    )

    /// V7 adds FileReference and a new relationship pointing at it from Project — additive only,
    /// same lightweight approach as the prior stages.
    static let migrateV6toV7 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV6.self,
        toVersion: KyleOSSchemaV7.self
    )

    /// V8 adds Draft (with a new relationship from Document) plus two new Project fields
    /// (`projectType`, `status`) and one new Document field (`currentDraftLabel`). Unlike prior
    /// stages, these three are genuinely new *optional* scalar attributes on already-populated
    /// models, not new models/relationships — a stored property's `= literal` default does NOT
    /// reliably survive lightweight migration for that shape under this SwiftData version
    /// (confirmed by a live crash: "Passed nil for a non-optional keypath"), so all three are
    /// Optional at the model level with a `displayX` computed fallback, not defaulted directly.
    /// See KyleOSSchemaV8's doc comments on `Project.status`/`Document.currentDraftLabel`.
    static let migrateV7toV8 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV7.self,
        toVersion: KyleOSSchemaV8.self
    )

    /// V9 adds Act (with a new relationship from Document) — a new model + a new relationship
    /// array on an existing model, the same safe additive shape as every stage except V8 (see
    /// that stage's doc comment for why *this* shape is safe and V8's wasn't).
    static let migrateV8toV9 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV8.self,
        toVersion: KyleOSSchemaV9.self
    )

    /// V10 adds Scene (with a new relationship from Act) — same safe additive shape as V9.
    static let migrateV9toV10 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV9.self,
        toVersion: KyleOSSchemaV10.self
    )

    /// V11 adds Project.lastOpenedDocument — a new field, but genuinely Optional from the start
    /// (not a `= literal` default on a non-optional type), the same safe shape as V8's
    /// `projectType` (which worked) rather than V8's `status`/`currentDraftLabel` (which didn't).
    static let migrateV10toV11 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV10.self,
        toVersion: KyleOSSchemaV11.self
    )

    /// V12 adds ScriptBlock (with a new relationship from Document) — same safe additive shape
    /// as V9/V10.
    static let migrateV11toV12 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV11.self,
        toVersion: KyleOSSchemaV12.self
    )

    /// V13 adds Joke — a brand new top-level model with no relationships to any existing model,
    /// the simplest possible additive shape.
    static let migrateV12toV13 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV12.self,
        toVersion: KyleOSSchemaV13.self
    )

    /// V14 adds Chunk (with a new relationship from Chunk to the existing Joke model) plus two
    /// new fields on Joke (chunk, orderWithinChunk) — both genuinely Optional, the safe shape,
    /// not V8's mistake.
    static let migrateV13toV14 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV13.self,
        toVersion: KyleOSSchemaV14.self
    )

    /// V15 adds HeadlineSet (with a new relationship from HeadlineSet to the existing Chunk
    /// model) plus two new fields on Chunk (headlineSet, orderInHeadlineSet) — both genuinely
    /// Optional, the safe shape, not V8's mistake.
    static let migrateV14toV15 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV14.self,
        toVersion: KyleOSSchemaV15.self
    )

    /// V16 adds Gig (with a new relationship from Gig to the existing CalendarEvent model) plus
    /// one new field on CalendarEvent (gig) — both genuinely Optional/additive, the safe shape,
    /// not V8's mistake.
    static let migrateV15toV16 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV15.self,
        toVersion: KyleOSSchemaV16.self
    )

    /// V17 adds GigSetListItem (with new relationships from Gig, Joke, and Chunk to it) — all
    /// new relationship arrays with `= []` defaults, the same safe additive shape as V9/V10/V12/
    /// V13/V16, not V8's mistake.
    static let migrateV16toV17 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV16.self,
        toVersion: KyleOSSchemaV17.self
    )

    /// V18 adds two new Optional String fields (Gig.afterGigNotes, GigSetListItem.
    /// performanceNotes) — genuinely Optional, the safe shape, not V8's mistake.
    static let migrateV17toV18 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV17.self,
        toVersion: KyleOSSchemaV18.self
    )

    /// V19 adds two new plain optional relationships on WorkItem (joke, chunk) plus their
    /// inverse arrays on Joke/Chunk — genuinely Optional/additive, the safe shape, not V8's
    /// mistake.
    static let migrateV18toV19 = MigrationStage.lightweight(
        fromVersion: KyleOSSchemaV18.self,
        toVersion: KyleOSSchemaV19.self
    )
}
