import Foundation
import SwiftData

/// Reusable domain actions for Work Type Defaults, kept out of views per CLAUDE.md §4. The
/// whole point of this model is that "Outline takes about 1.5 hours" lives here once, not as a
/// magic number copy-pasted into every screen that needs it.
enum WorkTypeDefaultService {
    typealias WorkTypeDefault = KyleOSSchemaV22.WorkTypeDefault

    /// The only two estimates the Master PRD actually specifies (§5.1). Everything else
    /// ("script drafting, clip editing, subtitles, sketch editing, call sheets...") is
    /// explicitly left for the user to configure and refine through real use — inventing
    /// numbers for those now would pre-decide product data the PRD deliberately leaves open.
    private static let knownDefaults: [(name: String, hours: Double)] = [
        ("Outline", 1.5),
        ("Short Story", 3.0),
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
}
