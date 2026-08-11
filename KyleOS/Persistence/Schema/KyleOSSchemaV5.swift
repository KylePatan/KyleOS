import Foundation
import SwiftData

/// Schema version 5 — adds PlannedSession and WorkSession (PRD §14.7/§14.8). WorkItem gains
/// cascade-owned collections of both; CalendarEvent gains the inverse for PlannedSession's
/// optional link (PRD §11.7: "events created by modules must be the same underlying Calendar
/// Event" — a Planned Session and its Creative Work Session calendar event stay linked). All
/// other models are re-declared unchanged from V4 (see the note at the top of
/// KyleOSSchemaV2.swift for why this pattern matters).
enum KyleOSSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Project.self, AppSettings.self, WorkTypeDefault.self, Document.self, WorkItem.self, Deadline.self, CalendarEvent.self, PlannedSession.self, WorkSession.self]
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

        @Relationship(deleteRule: .cascade, inverse: \Deadline.project)
        var deadline: Deadline?

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

        @Relationship(deleteRule: .cascade, inverse: \Deadline.workItem)
        var deadline: Deadline?

        @Relationship(deleteRule: .nullify, inverse: \CalendarEvent.workItem)
        var calendarEvents: [CalendarEvent] = []

        /// New in V5. Cascade — a Planned Session only means something in relation to its
        /// Work Item, same reasoning as Deadline above.
        @Relationship(deleteRule: .cascade, inverse: \PlannedSession.workItem)
        var plannedSessions: [PlannedSession] = []

        /// New in V5. Cascade — see WorkSession's own doc comment for why this is a deliberate
        /// choice despite "historical sessions must never be rewritten."
        @Relationship(deleteRule: .cascade, inverse: \WorkSession.workItem)
        var workSessions: [WorkSession] = []

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

    @Model
    final class Deadline {
        @Attribute(.unique) var id: UUID
        var project: Project?
        var workItem: WorkItem?
        var label: String
        var dueAt: Date
        var isHard: Bool
        var isConfirmed: Bool
        var notes: String

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

    enum Availability: String, Codable, CaseIterable {
        case busy = "Busy"
        case available = "Available"
    }

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

        /// New in V5. Nullify, with an explicit inverse — same reasoning as the other
        /// CalendarEvent back-links. A Creative Work Session calendar event and the Planned
        /// Session it represents (PRD §11.7/§11.9) stay linked but the event outlives the
        /// session's deletion, same nullify-not-cascade logic as project/workItem/deadline.
        @Relationship(deleteRule: .nullify, inverse: \PlannedSession.calendarEvent)
        var plannedSessions: [PlannedSession] = []

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

    /// PRD §14.7's exact status list.
    enum PlannedSessionStatus: String, Codable, CaseIterable {
        case scheduled = "Scheduled"
        case completed = "Completed"
        case missed = "Missed"
        case cancelled = "Cancelled"
    }

    /// PRD §11.9's "auto/manual origin" — whether a future Scheduling Engine (V0.7) placed this
    /// or the user did directly. No scheduling logic reads this yet; it's just recorded.
    enum SessionOrigin: String, Codable, CaseIterable {
        case auto = "Auto"
        case manual = "Manual"
    }

    /// A Planned Session is future intended work (PRD §14.7) — not yet performed. Distinct from
    /// WorkSession (actual completed effort) per the Foundation acceptance criterion "Planned
    /// Sessions and Work Sessions are separate."
    @Model
    final class PlannedSession {
        @Attribute(.unique) var id: UUID
        var workItem: WorkItem?
        var calendarEvent: CalendarEvent?
        var scheduledAt: Date
        var plannedDurationMinutes: Int
        var isLocked: Bool
        var origin: SessionOrigin
        var status: PlannedSessionStatus
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            workItem: WorkItem?,
            scheduledAt: Date,
            plannedDurationMinutes: Int,
            origin: SessionOrigin = .manual,
            calendarEvent: CalendarEvent? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.workItem = workItem
            self.calendarEvent = calendarEvent
            self.scheduledAt = scheduledAt
            self.plannedDurationMinutes = plannedDurationMinutes
            self.isLocked = false
            self.origin = origin
            self.status = .scheduled
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// PRD §14.8's exact entry-type distinction — did a live Focus Timer produce this record, or
    /// did the user log time manually after the fact?
    enum WorkSessionEntryType: String, Codable, CaseIterable {
        case timer = "Timer"
        case manual = "Manual"
    }

    /// A Work Session is actual completed effort (PRD §14.8). `workItem` isn't explicitly named
    /// in the PRD's WorkSession field list, but "progress before/after" is meaningless without
    /// something to track progress of — inferred as implicit, same as PlannedSession's explicit
    /// workItem field. Per the PRD ("Historical completed sessions must never be rewritten by
    /// future rescheduling"), nothing in this Foundation build brief step provides an update
    /// path for a session once created — only WorkSessionService.logCompletedSession exists, no
    /// edit function. The shared timer service (build brief step 12) is what will actually
    /// produce these records from a live start/pause/resume/stop flow; this step only adds the
    /// data model and a manual-entry-style creation path.
    @Model
    final class WorkSession {
        @Attribute(.unique) var id: UUID
        var workItem: WorkItem?
        var startAt: Date
        var endAt: Date
        var activeDurationSeconds: Int
        var pausedDurationSeconds: Int
        var plannedDurationMinutes: Int?
        var progressBefore: Int
        var progressAfter: Int
        var note: String
        var entryType: WorkSessionEntryType
        var createdAt: Date

        init(
            id: UUID = UUID(),
            workItem: WorkItem?,
            startAt: Date,
            endAt: Date,
            activeDurationSeconds: Int,
            pausedDurationSeconds: Int = 0,
            plannedDurationMinutes: Int? = nil,
            progressBefore: Int,
            progressAfter: Int,
            note: String = "",
            entryType: WorkSessionEntryType,
            createdAt: Date = .now
        ) {
            self.id = id
            self.workItem = workItem
            self.startAt = startAt
            self.endAt = endAt
            self.activeDurationSeconds = activeDurationSeconds
            self.pausedDurationSeconds = pausedDurationSeconds
            self.plannedDurationMinutes = plannedDurationMinutes
            self.progressBefore = progressBefore
            self.progressAfter = progressAfter
            self.note = note
            self.entryType = entryType
            self.createdAt = createdAt
        }
    }
}
