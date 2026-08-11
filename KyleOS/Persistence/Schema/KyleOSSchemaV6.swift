import Foundation
import SwiftData

/// Schema version 6 — adds ActiveTimerState, the crash-recovery checkpoint for a live Focus
/// Timer session (PRD §16.7: "On an unclean shutdown, Kyle OS should restore latest autosaved
/// writing and enough timer state to offer resume/end/discard choices for an interrupted
/// session"). All other models are re-declared unchanged from V5 (see the note at the top of
/// KyleOSSchemaV2.swift for why this pattern matters).
enum KyleOSSchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Project.self, AppSettings.self, WorkTypeDefault.self, Document.self, WorkItem.self, Deadline.self, CalendarEvent.self, PlannedSession.self, WorkSession.self, ActiveTimerState.self]
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

        @Relationship(deleteRule: .cascade, inverse: \PlannedSession.workItem)
        var plannedSessions: [PlannedSession] = []

        @Relationship(deleteRule: .cascade, inverse: \WorkSession.workItem)
        var workSessions: [WorkSession] = []

        /// New in V6. Cascade — an interrupted-timer checkpoint only means something in relation
        /// to its Work Item, same reasoning as Deadline/PlannedSession/WorkSession above.
        @Relationship(deleteRule: .cascade, inverse: \ActiveTimerState.workItem)
        var activeTimerState: ActiveTimerState?

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

    enum PlannedSessionStatus: String, Codable, CaseIterable {
        case scheduled = "Scheduled"
        case completed = "Completed"
        case missed = "Missed"
        case cancelled = "Cancelled"
    }

    enum SessionOrigin: String, Codable, CaseIterable {
        case auto = "Auto"
        case manual = "Manual"
    }

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

    enum WorkSessionEntryType: String, Codable, CaseIterable {
        case timer = "Timer"
        case manual = "Manual"
    }

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

    /// A checkpoint of a live Focus Timer session, written on every state transition
    /// (start/pause/resume) so an unclean shutdown leaves enough to detect and offer
    /// resume/end/discard on next launch (PRD §16.7). Not a complete live-tick record — a crash
    /// mid-running-segment loses only the time since the last checkpoint, an honest "where
    /// practical" limitation (Foundation acceptance criteria's own wording) rather than a full
    /// per-second persistence engine. Deleted on Finish/Discard, so its mere existence at launch
    /// IS the signal that recovery is needed.
    @Model
    final class ActiveTimerState {
        @Attribute(.unique) var id: UUID
        var workItem: WorkItem?
        var sessionStartedAt: Date
        var targetDurationMinutes: Int?
        var progressBefore: Int
        /// Accumulated active/paused seconds as of the last checkpoint — NOT including whatever
        /// segment was in progress when the checkpoint was written.
        var activeDurationSecondsAtCheckpoint: Int
        var pausedDurationSecondsAtCheckpoint: Int
        var wasRunningAtCheckpoint: Bool
        var checkpointedAt: Date

        init(
            id: UUID = UUID(),
            workItem: WorkItem?,
            sessionStartedAt: Date,
            targetDurationMinutes: Int?,
            progressBefore: Int,
            activeDurationSecondsAtCheckpoint: Int = 0,
            pausedDurationSecondsAtCheckpoint: Int = 0,
            wasRunningAtCheckpoint: Bool = true,
            checkpointedAt: Date = .now
        ) {
            self.id = id
            self.workItem = workItem
            self.sessionStartedAt = sessionStartedAt
            self.targetDurationMinutes = targetDurationMinutes
            self.progressBefore = progressBefore
            self.activeDurationSecondsAtCheckpoint = activeDurationSecondsAtCheckpoint
            self.pausedDurationSecondsAtCheckpoint = pausedDurationSecondsAtCheckpoint
            self.wasRunningAtCheckpoint = wasRunningAtCheckpoint
            self.checkpointedAt = checkpointedAt
        }
    }
}
