import Foundation
import SwiftData

/// Schema version 4 — adds Deadline and CalendarEvent, and closes two gaps deliberately left
/// open in earlier versions: Project's "optional hard deadline" (PRD §14.1) and WorkItem's
/// "hard deadline reference" (§14.6) both now get a real `deadline: Deadline?` relationship
/// instead of a placeholder. All other models are re-declared unchanged from V3 (see the note
/// at the top of KyleOSSchemaV2.swift for why this pattern matters).
enum KyleOSSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Project.self, AppSettings.self, WorkTypeDefault.self, Document.self, WorkItem.self, Deadline.self, CalendarEvent.self]
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

        @Relationship(deleteRule: .cascade, inverse: \WorkItem.project)
        var workItems: [WorkItem] = []

        /// New in V4 — closes the gap left open in KyleOSSchemaV1 (see that file's history);
        /// PRD §14.1 lists "Optional hard deadline" as a core Project field. Cascade: a Deadline
        /// only means anything in relation to its Project, so it goes when the Project does.
        @Relationship(deleteRule: .cascade, inverse: \Deadline.project)
        var deadline: Deadline?

        /// New in V4. Nullify, not cascade — a Calendar Event represents real scheduled time
        /// and should survive its linked Project being deleted, the way a real calendar doesn't
        /// retroactively erase history when a task goes away. The explicit inverse here (rather
        /// than leaving CalendarEvent.project as a bare one-way reference) is required for
        /// SwiftData to actually perform that nullify — a prior version of this schema omitted
        /// it and left a dangling reference after delete instead, caught by
        /// CalendarEventPersistenceTests.testDeletingLinkedProjectNullifiesRatherThanDeletingTheEvent.
        @Relationship(deleteRule: .nullify, inverse: \CalendarEvent.project)
        var calendarEvents: [CalendarEvent] = []

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

    enum Workspace: String, Codable, CaseIterable {
        case writing = "Writing"
        case standUp = "Stand Up"
        case clips = "Clips"
        case sketches = "Sketches"
    }

    enum WorkItemStatus: String, Codable, CaseIterable {
        case notStarted = "Not Started"
        case inProgress = "In Progress"
        case completed = "Completed"
    }

    @Model
    final class WorkItem {
        @Attribute(.unique) var id: UUID
        var project: Project?
        var document: Document?
        var workspace: Workspace
        var workTypeName: String
        var title: String
        var status: WorkItemStatus
        var progress: Int
        var estimatedTotalMinutes: Int
        var estimatedRemainingMinutes: Int
        var preferredSessionMinutes: Int
        var minimumSessionMinutes: Int
        var isSplittable: Bool
        var priority: Int
        @Relationship var dependsOn: [WorkItem] = []

        /// New in V4 — closes the gap left open in KyleOSSchemaV3 (see that file's history).
        /// Cascade for the same reason as Project.deadline above.
        @Relationship(deleteRule: .cascade, inverse: \Deadline.workItem)
        var deadline: Deadline?

        /// New in V4. Nullify, with an explicit inverse — same reasoning as
        /// Project.calendarEvents above.
        @Relationship(deleteRule: .nullify, inverse: \CalendarEvent.workItem)
        var calendarEvents: [CalendarEvent] = []

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

    /// A Deadline (PRD §14.10) attaches to exactly one of Project or WorkItem — whichever
    /// relationship is non-nil indicates what it's "related object" is. `label` covers the
    /// PRD's separate "type" field as free text (e.g. "Submission Deadline", "Network Note")
    /// since the PRD names no fixed taxonomy to enumerate here.
    @Model
    final class Deadline {
        @Attribute(.unique) var id: UUID
        var project: Project?
        var workItem: WorkItem?
        var label: String
        var dueAt: Date
        /// Hard/suggested state (PRD §14.10) — a hard deadline is a real commitment; a
        /// suggested one is a planning target the Scheduling Engine (V0.7) can move more freely.
        var isHard: Bool
        var isConfirmed: Bool
        var notes: String

        /// Nullify, with an explicit inverse — same reasoning as Project.calendarEvents above.
        @Relationship(deleteRule: .nullify, inverse: \CalendarEvent.deadline)
        var calendarEvents: [CalendarEvent] = []

        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            label: String,
            dueAt: Date,
            isHard: Bool = true,
            isConfirmed: Bool = false,
            notes: String = "",
            project: Project? = nil,
            workItem: WorkItem? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.label = label
            self.dueAt = dueAt
            self.isHard = isHard
            self.isConfirmed = isConfirmed
            self.notes = notes
            self.project = project
            self.workItem = workItem
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// PRD §11.3's exact list. Personal/Unavailable/DayJob/StandUpGig/FilmShoot are calendar-only
    /// concepts for now — Gig and Shoot don't have their own models until V0.3/V0.5, so those
    /// event types exist as plain Calendar Events with no linked object yet.
    enum CalendarEventType: String, Codable, CaseIterable {
        case personal = "Personal Event"
        case unavailableTimeOff = "Unavailable / Time Off"
        case dayJob = "Day Job"
        case standUpGig = "Stand-Up Gig"
        case filmShoot = "Film Shoot"
        case hardDeadline = "Hard Deadline"
        case postDate = "Post Date"
        case creativeWorkSession = "Creative Work Session"
    }

    /// V1 availability types only (PRD §11.5) — "Flexible" is explicitly future, not decided now.
    enum Availability: String, Codable, CaseIterable {
        case busy = "Busy"
        case available = "Available"
    }

    /// A Calendar Event represents a time commitment (PRD §14.9). Deliberately does NOT include
    /// any Google Calendar sync logic or OAuth (that's V0.6, CLAUDE.md §8) — only the nullable
    /// metadata fields the PRD explicitly lists as part of the core model shape, so a future
    /// sync provider can be added without another migration. `project`/`workItem`/`deadline`
    /// cover 3 of the PRD's 5 linkable object kinds (Gig, Shoot, Posting Item don't have models
    /// yet). Nullify delete rule (the default — no explicit deleteRule needed) is deliberate:
    /// unlike Deadline, a Calendar Event represents actual scheduled time and should survive
    /// its linked Project/WorkItem being deleted, just losing the link, the way a real calendar
    /// doesn't retroactively erase history when a task is deleted.
    @Model
    final class CalendarEvent {
        @Attribute(.unique) var id: UUID
        var eventType: CalendarEventType
        var startAt: Date
        var endAt: Date
        var isAllDay: Bool
        var availability: Availability
        var isHardCommitment: Bool
        var isLocked: Bool
        var notes: String
        var location: String

        var project: Project?
        var workItem: WorkItem?
        var deadline: Deadline?

        /// External sync metadata (PRD §14.9) — "should not be required for Kyle OS-only
        /// events." Present so a future sync provider slots in without another migration; no
        /// provider integration exists yet.
        var provider: String?
        var externalCalendarID: String?
        var externalEventID: String?
        var lastSyncedAt: Date?
        var hasLocalModifications: Bool

        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            eventType: CalendarEventType,
            startAt: Date,
            endAt: Date,
            isAllDay: Bool = false,
            availability: Availability = .busy,
            isHardCommitment: Bool = false,
            isLocked: Bool = false,
            notes: String = "",
            location: String = "",
            project: Project? = nil,
            workItem: WorkItem? = nil,
            deadline: Deadline? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.eventType = eventType
            self.startAt = startAt
            self.endAt = endAt
            self.isAllDay = isAllDay
            self.availability = availability
            self.isHardCommitment = isHardCommitment
            self.isLocked = isLocked
            self.notes = notes
            self.location = location
            self.project = project
            self.workItem = workItem
            self.deadline = deadline
            self.provider = nil
            self.externalCalendarID = nil
            self.externalEventID = nil
            self.lastSyncedAt = nil
            self.hasLocalModifications = false
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }
}
