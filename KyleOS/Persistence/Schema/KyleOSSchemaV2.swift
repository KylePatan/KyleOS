import Foundation
import SwiftData

/// Schema version 2 — adds Document. Project/AppSettings/WorkTypeDefault are re-declared here
/// unchanged (Apple's nested-VersionedSchema pattern: each version independently owns its full
/// model set so it can evolve any of them later without touching the frozen historical version).
///
/// This is a genuine version bump with a real migration stage in KyleOSMigrationPlan, not a
/// silent edit to KyleOSSchemaV1 — V1 has already been opened by real builds, and a prior
/// session found that adding entities to an already-used VersionedSchema without an explicit
/// migration stage can corrupt an existing store (SwiftData/Core Data automatic staged-migration
/// inference bug, reproduced even after a clean rebuild). See docs/TECHNICAL_ARCHITECTURE.md
/// §16.3 and CLAUDE.md §5 — this is exactly the discipline those sections ask for.
enum KyleOSSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Project.self, AppSettings.self, WorkTypeDefault.self, Document.self]
    }

    @Model
    final class Project {
        @Attribute(.unique) var id: UUID
        var title: String
        var createdAt: Date
        var updatedAt: Date
        var isArchived: Bool
        var archivedAt: Date?

        /// New in V2. Cascade: deleting a Project deletes its Documents — per PRD §16.8,
        /// Projects use Archive/soft-delete by default, so this only fires on a deliberate,
        /// explicit hard delete, not routine archiving.
        @Relationship(deleteRule: .cascade, inverse: \Document.project)
        var documents: [Document] = []

        init(id: UUID = UUID(), title: String, createdAt: Date = .now) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.updatedAt = createdAt
            self.isArchived = false
            self.archivedAt = nil
        }
    }

    @Model
    final class AppSettings {
        @Attribute(.unique) var id: UUID
        var dayJobWeekdays: [Int]
        var dayJobStartHour: Int
        var dayJobEndHour: Int
        var weekdayCreativeCapacityHours: Double
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

    /// PRD §14.2's named examples. Custom covers anything else without forcing a generic
    /// catch-all to be the default.
    enum DocumentType: String, Codable, CaseIterable {
        case script = "Script"
        case prose = "Prose"
        case actOutline = "Act Outline"
        case sceneOutline = "Scene Outline"
        case notes = "Notes"
        case seriesBible = "Series Bible"
        case onePager = "One Pager"
        case custom = "Custom"
    }

    /// A Document belongs to a Project (PRD §14.2). Content is plain text for now — structured
    /// Script Blocks (§14.3) are explicitly Decision Gate A territory, resolved during V0.2
    /// Writing, not invented here. This model exists so Foundation can prove persistence +
    /// autosave work, not to be the real screenplay editor's data model.
    @Model
    final class Document {
        @Attribute(.unique) var id: UUID
        var project: Project?
        var documentType: DocumentType
        var title: String
        var content: String
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            title: String,
            documentType: DocumentType,
            project: Project?,
            content: String = "",
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title
            self.documentType = documentType
            self.project = project
            self.content = content
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }
}
