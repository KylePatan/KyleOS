import Foundation
import SwiftData

/// Schema version 12 — V0.2 Writing's seventh increment: the Script Editor (PRD §6.6-§6.10),
/// per Decision Gate A resolved with Kyle (docs/PHASE_DECISION_REGISTER.md): native architecture
/// is AppKit/TextKit wrapped for SwiftUI (see ScriptEditorView.swift), not plain SwiftUI text
/// components — the only approach that supports custom Enter/Tab key-driven element transitions,
/// per-paragraph structured typing, and reliable pagination the PRD requires. PRD §14.3: "Script
/// content should ideally be stored as ordered structured blocks with element type, text, order,
/// and optional Scene ID." New ScriptBlock model + new relationship array on Document — the same
/// safe additive shape as V9/V10 (new model + relationship array), not V8's mistake (a new
/// required scalar on an existing model). All other models re-declared unchanged from V11 (see
/// the note at the top of KyleOSSchemaV2.swift for why this pattern matters).
enum KyleOSSchemaV12: VersionedSchema {
    static var versionIdentifier = Schema.Version(12, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Project.self, AppSettings.self, WorkTypeDefault.self, Document.self, Draft.self, Act.self, Scene.self, ScriptBlock.self, WorkItem.self, Deadline.self, CalendarEvent.self, PlannedSession.self, WorkSession.self, ActiveTimerState.self, FileReference.self]
    }

    enum WritingProjectType: String, Codable, CaseIterable {
        case sketch = "Sketch"
        case tvPilot = "TV Pilot"
        case screenplay = "Screenplay"
        case shortFilm = "Short Film"
        case shortStory = "Short Story"
        case other = "Other"
    }

    enum ProjectStatus: String, Codable, CaseIterable {
        case idea = "Idea"
        case active = "Active"
        case onHold = "On Hold"
        case finished = "Finished"
    }

    @Model
    final class Project {
        @Attribute(.unique) var id: UUID
        var title: String
        var createdAt: Date
        var updatedAt: Date
        var isArchived: Bool
        var archivedAt: Date?

        /// New in V8. Optional: only Writing-workspace projects have a PRD §6.2 project type;
        /// projects created generically (e.g. Foundation's Dev/ screen) leave this nil.
        var projectType: WritingProjectType?

        /// New in V8. Optional so lightweight migration leaves pre-existing rows as `nil` rather
        /// than crashing — confirmed by a live crash, not theoretical: SwiftData under Xcode
        /// 15.4 does not reliably honor a stored property's `= literal` default when adding a
        /// new *non-optional* attribute to an already-populated model (every prior migration in
        /// this codebase only ever added new models or optional/array relationships, never a
        /// new required scalar on an existing model — this was the first attempt, and it broke).
        /// `nil` means "Active" via `displayStatus` below; every real Project that already
        /// existed before this field was added was, by definition, active work. New Projects
        /// always get an explicit value through `init`.
        var status: ProjectStatus?
        var displayStatus: ProjectStatus { status ?? .active }

        @Relationship(deleteRule: .cascade, inverse: \Document.project)
        var documents: [Document] = []

        @Relationship(deleteRule: .cascade, inverse: \WorkItem.project)
        var workItems: [WorkItem] = []

        @Relationship(deleteRule: .cascade, inverse: \Deadline.project)
        var deadline: Deadline?

        @Relationship(deleteRule: .nullify, inverse: \CalendarEvent.project)
        var calendarEvents: [CalendarEvent] = []

        @Relationship(deleteRule: .nullify, inverse: \FileReference.project)
        var fileReferences: [FileReference] = []

        /// New in V11 (PRD §6.17): "reopening a writing project should restore... last open
        /// document." Plain unidirectional optional reference, no `@Relationship` wrapper — same
        /// proven-safe shape as `WorkItem.document`. Always points at one of this project's own
        /// `documents`, so the existing cascade-delete on `documents` already prevents any
        /// dangling reference (deleting the project deletes both).
        var lastOpenedDocument: Document?

        init(
            id: UUID = UUID(),
            title: String,
            projectType: WritingProjectType? = nil,
            status: ProjectStatus = .active,
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title
            self.projectType = projectType
            self.status = status
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

        /// New in V8 (PRD §6.15/§14.5). The label of whichever draft is currently live/being
        /// edited — "First Draft", "Second Draft", etc, or a custom name. Frozen historical
        /// drafts live in `drafts`; this label is NOT one of them until `DraftService.startNewDraft`
        /// freezes it. Optional for the same lightweight-migration reason as `Project.status`
        /// above — `nil` means "First Draft" via `displayDraftLabel`.
        var currentDraftLabel: String?
        var displayDraftLabel: String { currentDraftLabel ?? "First Draft" }

        @Relationship(deleteRule: .cascade, inverse: \Draft.document)
        var drafts: [Draft] = []

        /// New in V9 (PRD §6.11/§14.4). Populated on Act Outline-type Documents; empty on every
        /// other document type.
        @Relationship(deleteRule: .cascade, inverse: \Act.document)
        var acts: [Act] = []

        /// New in V12 (PRD §6.6-§6.10/§14.3). Populated on Script-type Documents; empty on every
        /// other document type.
        @Relationship(deleteRule: .cascade, inverse: \ScriptBlock.document)
        var scriptBlocks: [ScriptBlock] = []

        init(
            id: UUID = UUID(),
            title: String,
            documentType: DocumentType,
            project: Project?,
            content: String = "",
            currentDraftLabel: String = "First Draft",
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title
            self.documentType = documentType
            self.project = project
            self.content = content
            self.currentDraftLabel = currentDraftLabel
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// New in V8 (PRD §14.5/§6.15). A frozen, formally preserved prior version of a Document —
    /// distinct from autosave recovery snapshots, which are transient and never user-visible
    /// history. Immutable by convention (nothing in the domain layer mutates a Draft after
    /// creation); "restorable" per the PRD means copying `content` back into the live Document,
    /// not editing the Draft itself.
    @Model
    final class Draft {
        @Attribute(.unique) var id: UUID
        var document: Document?
        var label: String
        var content: String
        var createdAt: Date

        init(
            id: UUID = UUID(),
            label: String,
            content: String,
            document: Document?,
            createdAt: Date = .now
        ) {
            self.id = id
            self.label = label
            self.content = content
            self.document = document
            self.createdAt = createdAt
        }
    }

    /// New in V9 (PRD §6.11/§14.4). "Broad story architecture" — customizable, renameable,
    /// reorderable, addable, deletable. `order` is a plain ascending index (0 = first act in
    /// story order) — unlike WorkItem's inverted "higher number = more important" priority
    /// scheme, acts have no such ambiguity, they just read top to bottom.
    @Model
    final class Act {
        @Attribute(.unique) var id: UUID
        var document: Document?
        var title: String
        var synopsis: String
        var order: Int
        var createdAt: Date
        var updatedAt: Date

        /// New in V10. Scenes belong directly to their Act, not to a separate "Scene Outline"
        /// Document — see SceneService.swift's doc comment for why.
        @Relationship(deleteRule: .cascade, inverse: \Scene.act)
        var scenes: [Scene] = []

        init(
            id: UUID = UUID(),
            title: String,
            synopsis: String = "",
            order: Int,
            document: Document?,
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title
            self.synopsis = synopsis
            self.order = order
            self.document = document
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    enum SceneLocationType: String, Codable, CaseIterable {
        case int = "INT."
        case ext = "EXT."
        case intExt = "INT./EXT."
    }

    /// New in V10 (PRD §6.11/§14.4). Belongs to an Act, not a separate Scene Outline Document.
    /// `orderWithinAct` positions a scene inside its own Act; the PRD's "Scene Number" is not a
    /// stored field — it's the scene's overall sequential position across the whole Act Outline
    /// (all acts, in order, all scenes within each), computed by SceneService so it can never
    /// drift out of sync with reality (PRD: "Renumbering should update automatically").
    @Model
    final class Scene {
        @Attribute(.unique) var id: UUID
        var act: Act?
        var orderWithinAct: Int
        var locationType: SceneLocationType
        var location: String
        var timeOfDay: String
        var sceneDescription: String
        var purpose: String
        var characters: String
        var keyBeats: String
        var notes: String
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            act: Act?,
            orderWithinAct: Int,
            locationType: SceneLocationType = .int,
            location: String = "",
            timeOfDay: String = "",
            sceneDescription: String = "",
            purpose: String = "",
            characters: String = "",
            keyBeats: String = "",
            notes: String = "",
            createdAt: Date = .now
        ) {
            self.id = id
            self.act = act
            self.orderWithinAct = orderWithinAct
            self.locationType = locationType
            self.location = location
            self.timeOfDay = timeOfDay
            self.sceneDescription = sceneDescription
            self.purpose = purpose
            self.characters = characters
            self.keyBeats = keyBeats
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    enum ScriptElementType: String, Codable, CaseIterable {
        case sceneHeading = "Scene Heading"
        case action = "Action"
        case character = "Character"
        case dialogue = "Dialogue"
        case parenthetical = "Parenthetical"
        case transition = "Transition"
    }

    /// New in V12 (PRD §6.7/§14.3). Belongs directly to a Script-type Document. `order` is a
    /// plain ascending index (0 = first block) — the block's position IS the script's reading
    /// order, no separate "Scene Number"-style derived concept needed here.
    @Model
    final class ScriptBlock {
        @Attribute(.unique) var id: UUID
        var document: Document?
        var elementType: ScriptElementType
        var text: String
        var order: Int
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            elementType: ScriptElementType,
            text: String = "",
            order: Int,
            document: Document?,
            createdAt: Date = .now
        ) {
            self.id = id
            self.elementType = elementType
            self.text = text
            self.order = order
            self.document = document
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

    @Model
    final class ActiveTimerState {
        @Attribute(.unique) var id: UUID
        var workItem: WorkItem?
        var sessionStartedAt: Date
        var targetDurationMinutes: Int?
        var progressBefore: Int
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

    /// A pointer to an external file (PRD §16.4/§14.15) — large source media stays where it is;
    /// Kyle OS never copies it. `bookmarkData` is a macOS bookmark (not a security-scoped one —
    /// the app isn't sandboxed yet, see docs/PHASE_DECISION_REGISTER.md Decision Gate E — but
    /// using the bookmark API now, rather than a raw path string, means resolution can survive
    /// the file being renamed/moved within the same volume, and the same code keeps working
    /// unchanged once sandboxing is added later). `displayName`/`notes`/`project` are stored
    /// independently of live resolution so they survive the file being temporarily unavailable
    /// (Foundation acceptance criterion: "File References can survive temporary source-file
    /// unavailability") — only `lastKnownAvailable`/`lastCheckedAt` change when the file can't
    /// be found; nothing about the reference itself is destroyed.
    @Model
    final class FileReference {
        @Attribute(.unique) var id: UUID
        var displayName: String
        var originalPath: String
        var bookmarkData: Data?
        var notes: String
        var project: Project?
        var lastKnownAvailable: Bool
        var lastCheckedAt: Date?
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            displayName: String,
            originalPath: String,
            bookmarkData: Data?,
            notes: String = "",
            project: Project? = nil,
            lastKnownAvailable: Bool = true,
            createdAt: Date = .now
        ) {
            self.id = id
            self.displayName = displayName
            self.originalPath = originalPath
            self.bookmarkData = bookmarkData
            self.notes = notes
            self.project = project
            self.lastKnownAvailable = lastKnownAvailable
            self.lastCheckedAt = createdAt
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }
}
