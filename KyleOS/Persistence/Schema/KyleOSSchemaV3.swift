import Foundation
import SwiftData

/// Schema version 3 — adds WorkItem. Project/AppSettings/WorkTypeDefault/Document are
/// re-declared unchanged from V2 (Apple's nested-VersionedSchema pattern; see the note at the
/// top of KyleOSSchemaV2.swift for why this discipline matters here).
enum KyleOSSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Project.self, AppSettings.self, WorkTypeDefault.self, Document.self, WorkItem.self]
    }

    @Model
    final class Project {
        @Attribute(.unique) var id: UUID
        var title: String
        var createdAt: Date
        var updatedAt: Date
        var isArchived: Bool
        var archivedAt: Date?

        @Relationship(deleteRule: .cascade, inverse: \Document.project)
        var documents: [Document] = []

        /// New in V3. Same cascade reasoning as documents above.
        @Relationship(deleteRule: .cascade, inverse: \WorkItem.project)
        var workItems: [WorkItem] = []

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

    /// The 4 creative workspaces named in the PRD's section headers (§6/§7/§8/§9). Home,
    /// Calendar, Reports, Settings are not creative workspaces and don't hold Work Items.
    enum Workspace: String, Codable, CaseIterable {
        case writing = "Writing"
        case standUp = "Stand Up"
        case clips = "Clips"
        case sketches = "Sketches"
    }

    /// PRD §15.1 names "Create/Complete Work Item" and "Change Status" as the shared actions —
    /// this is a minimal set that supports both without inventing more states than are used
    /// anywhere in Foundation. Extend when a real module needs more granularity.
    enum WorkItemStatus: String, Codable, CaseIterable {
        case notStarted = "Not Started"
        case inProgress = "In Progress"
        case completed = "Completed"
    }

    /// A Work Item represents schedulable effort (PRD §14.6). Deliberately does NOT yet have a
    /// hard-deadline relationship — Deadline is its own model, not built until build brief step
    /// 10, and bolting a raw Date on here now would contradict the acceptance criterion that
    /// "Deadlines are separate from flexible work dates." Add `var deadline: Deadline?` in a
    /// future schema version once Deadline exists.
    @Model
    final class WorkItem {
        @Attribute(.unique) var id: UUID
        var project: Project?
        /// Optional — a Work Item may concern a specific Document (e.g. "revise this outline")
        /// or just the Project generally.
        var document: Document?
        var workspace: Workspace
        /// Free-text stage/type name. Matches a WorkTypeDefault.name when one exists (used to
        /// seed the estimate/session-length fields below at creation) but is stored
        /// independently so renaming or removing a WorkTypeDefault later can't orphan this.
        var workTypeName: String
        var title: String
        var status: WorkItemStatus
        /// 0-100 (PRD §5.2: "a 0-100% internal progress value").
        var progress: Int
        var estimatedTotalMinutes: Int
        var estimatedRemainingMinutes: Int
        var preferredSessionMinutes: Int
        var minimumSessionMinutes: Int
        var isSplittable: Bool
        /// 1 (lowest) ... 5 (highest). A placeholder numeric scale — the Scheduling Engine
        /// (V0.7, Decision Gate B) will decide how priority actually weighs against deadline
        /// urgency, dependencies, etc.; this just needs to exist and persist for now.
        var priority: Int
        /// Prerequisite Work Items. Pure storage — nothing schedules around this yet
        /// (Decision Gate B territory), but the PRD lists Dependencies as a core §14.6 field.
        @Relationship var dependsOn: [WorkItem] = []
        var createdAt: Date
        var updatedAt: Date
        var completedAt: Date?

        init(
            id: UUID = UUID(),
            title: String,
            workspace: Workspace,
            workTypeName: String,
            project: Project?,
            document: Document? = nil,
            estimatedTotalMinutes: Int = 60,
            preferredSessionMinutes: Int = 45,
            minimumSessionMinutes: Int = 15,
            isSplittable: Bool = true,
            priority: Int = 3,
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title
            self.workspace = workspace
            self.workTypeName = workTypeName
            self.project = project
            self.document = document
            self.status = .notStarted
            self.progress = 0
            self.estimatedTotalMinutes = estimatedTotalMinutes
            self.estimatedRemainingMinutes = estimatedTotalMinutes
            self.preferredSessionMinutes = preferredSessionMinutes
            self.minimumSessionMinutes = minimumSessionMinutes
            self.isSplittable = isSplittable
            self.priority = priority
            self.createdAt = createdAt
            self.updatedAt = createdAt
            self.completedAt = nil
        }
    }
}
