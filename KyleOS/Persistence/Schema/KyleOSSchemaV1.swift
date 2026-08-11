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
        [Project.self, AppSettings.self, WorkTypeDefault.self]
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

    /// App-wide Settings — a single row, created on first launch by SettingsService.
    ///
    /// Scoped to what Master PRD §14.20 assigns to Foundation's acceptance criteria: day-job
    /// schedule and baseline Creative Capacity. Posting target and Auto Scheduling are also
    /// named in §14.20, but they configure the Scheduling Engine (V0.7) and Post It (V0.8),
    /// neither of which exists yet — adding those toggles now would silently pre-decide
    /// behavior for modules the Phase Decision Register deliberately defers. Add them when
    /// those modules are actually built.
    @Model
    final class AppSettings {
        @Attribute(.unique) var id: UUID

        /// Calendar.Component.weekday values (1 = Sunday ... 7 = Saturday). Default Mon-Fri.
        var dayJobWeekdays: [Int]
        /// 0-23. Default 8 (PRD §11.4: "Monday-Friday, 8 AM-5 PM is blocked by default").
        var dayJobStartHour: Int
        /// 0-23. Default 17.
        var dayJobEndHour: Int
        /// PRD §4.4: "a normal available day/evening can generally support about 2-3 creative
        /// hours." A planning assumption, not a hard restriction — stored as one editable
        /// number rather than inventing false precision.
        var weekdayCreativeCapacityHours: Double
        /// PRD §4.4: "a stand-up gig night generally supports about 1 additional creative hour."
        var standUpNightBonusHours: Double
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            dayJobWeekdays: [Int] = [2, 3, 4, 5, 6],
            dayJobStartHour: Int = 8,
            dayJobEndHour: Int = 17,
            weekdayCreativeCapacityHours: Double = 2.5,
            standUpNightBonusHours: Double = 1.0
        ) {
            self.id = id
            self.dayJobWeekdays = dayJobWeekdays
            self.dayJobStartHour = dayJobStartHour
            self.dayJobEndHour = dayJobEndHour
            self.weekdayCreativeCapacityHours = weekdayCreativeCapacityHours
            self.standUpNightBonusHours = standUpNightBonusHours
            self.updatedAt = .now
        }
    }

    /// A configurable default for one kind of work (Outline, Short Story, Script Draft, ...),
    /// per PRD §5.1/§14.20 — the whole point is that these live in one editable place instead
    /// of as magic numbers scattered through the codebase.
    @Model
    final class WorkTypeDefault {
        @Attribute(.unique) var id: UUID
        var name: String
        var defaultEstimateHours: Double
        var preferredSessionMinutes: Int
        var minimumSessionMinutes: Int
        var isSplittable: Bool
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            name: String,
            defaultEstimateHours: Double,
            preferredSessionMinutes: Int = 45,
            minimumSessionMinutes: Int = 15,
            isSplittable: Bool = true,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.defaultEstimateHours = defaultEstimateHours
            self.preferredSessionMinutes = preferredSessionMinutes
            self.minimumSessionMinutes = minimumSessionMinutes
            self.isSplittable = isSplittable
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }
}
