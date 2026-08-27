import Foundation
import SwiftData

/// Reusable domain actions for Work Type Defaults, kept out of views per CLAUDE.md §4. The
/// whole point of this model is that "Outline takes about 1.5 hours" lives here once, not as a
/// magic number copy-pasted into every screen that needs it.
enum WorkTypeDefaultService {
    typealias WorkTypeDefault = KyleOSSchemaV35.WorkTypeDefault

    /// The original two estimates the Master PRD actually specifies (§5.1) — left in place even
    /// though neither name matches a `workTypeName` the app currently generates, since existing
    /// installs may already have real rows for them by these names and this seed list is
    /// additive/idempotent-by-name only, never a removal.
    ///
    /// Kyle (2026-08-17): "there also should have EVERY type of creative thing that we can then
    /// add timing to." Below that: every `workTypeName` string actually produced by
    /// `WorkItemService`/`Document.documentType` today — every `DocumentType` case (Writing),
    /// Stand-Up's single work type, and each of Clip's/Sketch's per-stage work items — seeded
    /// with a simple 1-hour placeholder for Kyle to tune from the Settings screen; the PRD
    /// deliberately leaves the actual numbers open (see the original two above), this just makes
    /// sure every real type has a row to tune in the first place.
    private static let knownDefaults: [(name: String, hours: Double)] = [
        ("Outline", 1.5),
        ("Short Story", 3.0),
        ("Script", 4.0),
        ("Prose", 2.0),
        ("Act Outline", 1.5),
        ("Scene Outline", 1.0),
        ("Notes", 0.5),
        ("Series Bible", 3.0),
        ("One Pager", 1.0),
        ("Custom", 1.0),
        ("Stand-Up Development", 1.0),
        ("Clip Editing", 1.5),
        ("Clip Subtitling", 0.5),
        ("Clip Posting", 0.25),
        ("Sketch Writing", 2.0),
        ("Sketch Editing", 3.0),
        ("Sketch Posting", 0.25),
        ("Submission", 0.5),
        ("Submission Reminder", 0.25),
    ]

    /// Inserts the PRD's known defaults if they aren't already present. Idempotent — safe to
    /// call on every launch.
    static func seedKnownDefaultsIfNeeded(in context: ModelContext) throws {
        let existingNames = Set(try context.fetch(FetchDescriptor<WorkTypeDefault>()).map(\.name))
        for entry in knownDefaults where !existingNames.contains(entry.name) {
            context.insert(WorkTypeDefault(name: entry.name, defaultEstimateHours: entry.hours))
        }
    }

    @discardableResult
    static func createWorkTypeDefault(
        name: String,
        defaultEstimateHours: Double,
        preferredSessionMinutes: Int = 45,
        minimumSessionMinutes: Int = 15,
        isSplittable: Bool = true,
        in context: ModelContext
    ) -> WorkTypeDefault {
        let workType = WorkTypeDefault(
            name: name,
            defaultEstimateHours: defaultEstimateHours,
            preferredSessionMinutes: preferredSessionMinutes,
            minimumSessionMinutes: minimumSessionMinutes,
            isSplittable: isSplittable
        )
        context.insert(workType)
        return workType
    }

    static func update(
        _ workType: WorkTypeDefault,
        defaultEstimateHours: Double,
        preferredSessionMinutes: Int,
        minimumSessionMinutes: Int,
        isSplittable: Bool
    ) {
        workType.defaultEstimateHours = defaultEstimateHours
        workType.preferredSessionMinutes = preferredSessionMinutes
        workType.minimumSessionMinutes = minimumSessionMinutes
        workType.isSplittable = isSplittable
        workType.updatedAt = .now
    }

    static func all(in context: ModelContext) throws -> [WorkTypeDefault] {
        try context.fetch(FetchDescriptor<WorkTypeDefault>(sortBy: [SortDescriptor(\.name)]))
    }

    /// Kyle: "everything you create, you have an option to remove" — same delete pattern as
    /// every other list this session. A deleted Work Type Default just means new Work Items of
    /// that name fall back to `WorkItemService`'s generic estimate instead of a seeded one;
    /// existing Work Items are untouched (they only ever read the default once, at creation).
    static func delete(_ workType: WorkTypeDefault, context: ModelContext) {
        context.delete(workType)
    }
}
