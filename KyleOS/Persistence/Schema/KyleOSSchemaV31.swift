import Foundation
import SwiftData

/// Schema version 31 — Settings: adds AppSettings.weekendCreativeCapacityHours, a weekend
/// counterpart to the existing weekday-only `weekdayCreativeCapacityHours` baseline used by
/// `CreativeCapacityService.todaysCapacity`. A new Optional scalar on an already-populated
/// model, the safe V8-lesson shape (not a `= literal` default on a non-optional type) — see
/// V28's `postsPerWeekTarget` for the same pattern.
///
/// All other models re-declared unchanged from V30 (see the note at the top of
/// KyleOSSchemaV2.swift for why this pattern matters).
enum KyleOSSchemaV31: VersionedSchema {
    static var versionIdentifier = Schema.Version(31, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Project.self, AppSettings.self, WorkTypeDefault.self, Document.self, Draft.self, Act.self, Scene.self, ScriptBlock.self, Joke.self, Chunk.self, HeadlineSet.self, Gig.self, GigSetListItem.self, Source.self, Clip.self, SketchProduction.self, FilmShoot.self, CallSheet.self, WorkItem.self, Deadline.self, CalendarEvent.self, PlannedSession.self, WorkSession.self, ActiveTimerState.self, FileReference.self, DayJobOverride.self, CapacityOverride.self, PostingItem.self, HistoryEvent.self]
    }

    enum HistoryEventKind: String, Codable, CaseIterable {
        case statusChanged = "Status Changed"
        case progressChanged = "Progress Changed"
    }

    @Model
    final class HistoryEvent {
        @Attribute(.unique) var id: UUID
        var kind: HistoryEventKind
        var oldValue: String
        var newValue: String
        var occurredAt: Date

        var workItem: WorkItem?
        var clip: Clip?
        var sketchProject: Project?
        var joke: Joke?
        var chunk: Chunk?

        init(
            id: UUID = UUID(),
            kind: HistoryEventKind,
            oldValue: String,
            newValue: String,
            occurredAt: Date = .now,
            workItem: WorkItem? = nil,
            clip: Clip? = nil,
            sketchProject: Project? = nil,
            joke: Joke? = nil,
            chunk: Chunk? = nil
        ) {
            self.id = id
            self.kind = kind
            self.oldValue = oldValue
            self.newValue = newValue
            self.occurredAt = occurredAt
            self.workItem = workItem
            self.clip = clip
            self.sketchProject = sketchProject
            self.joke = joke
            self.chunk = chunk
        }
    }

    @Model
    final class PostingItem {
        @Attribute(.unique) var id: UUID
        var clip: Clip?
        var sketchProject: Project?
        var suggestedPostDate: Date?
        var confirmedPostDate: Date?
        var platform: String
        var actualPostedDate: Date?
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            clip: Clip? = nil,
            sketchProject: Project? = nil,
            suggestedPostDate: Date? = nil,
            confirmedPostDate: Date? = nil,
            platform: String = "",
            actualPostedDate: Date? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.clip = clip
            self.sketchProject = sketchProject
            self.suggestedPostDate = suggestedPostDate
            self.confirmedPostDate = confirmedPostDate
            self.platform = platform
            self.actualPostedDate = actualPostedDate
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    @Model
    final class DayJobOverride {
        @Attribute(.unique) var id: UUID
        var date: Date
        var isOff: Bool
        var createdAt: Date

        init(id: UUID = UUID(), date: Date, isOff: Bool = true, createdAt: Date = .now) {
            self.id = id
            self.date = date
            self.isOff = isOff
            self.createdAt = createdAt
        }
    }

    @Model
    final class CapacityOverride {
        @Attribute(.unique) var id: UUID
        var date: Date
        var hours: Double
        var createdAt: Date
        var updatedAt: Date

        init(id: UUID = UUID(), date: Date, hours: Double, createdAt: Date = .now) {
            self.id = id
            self.date = date
            self.hours = hours
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
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

        /// New in V22 (PRD §9.2). Cascade — a production record has no meaning without its
        /// Project, same shape as `Gig.calendarEvent`.
        @Relationship(deleteRule: .cascade, inverse: \SketchProduction.project)
        var sketchProduction: SketchProduction?

        /// New in V27 (PRD §14.18/§10). Cascade — a Post It queue entry has no meaning without
        /// the Sketch Project it schedules, same shape as `sketchProduction` above.
        @Relationship(deleteRule: .cascade, inverse: \PostingItem.sketchProject)
        var postingItem: PostingItem?

        /// New in V29 (PRD §14.19/§13.5). Records this Project's own status transitions (Sketch
        /// production status lives on the linked `SketchProduction`, not here, so this array is
        /// specifically for `Project.status` changes). Cascade, same shape as `workItems`/
        /// `documents` — history is a log owned by its subject, not an independent record that
        /// outlives it (consistent with `WorkSession`/`PlannedSession` also cascading with their
        /// WorkItem).
        @Relationship(deleteRule: .cascade, inverse: \HistoryEvent.sketchProject)
        var historyEvents: [HistoryEvent] = []

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

    enum SketchProductionStatus: String, Codable, CaseIterable {
        case filmingNotScheduled = "Filming Not Scheduled"
        case filmingScheduled = "Filming Scheduled"
        case filmed = "Filmed"
        case editing = "Editing"
        case ready = "Ready"
        case posted = "Posted"
    }

    /// New in V22 (PRD §9.1/§9.6/§9.8). "Written -> Filming Not Scheduled -> Filming Scheduled ->
    /// Filmed -> Editing -> Ready -> Posted" minus "Written" itself, which is `ProjectStatus.
    /// finished` on the Project, not a state here. `postDate` is storage only this increment —
    /// no backward-scheduling automation (V0.7 territory, same reasoning as `Clip.postDate`).
    @Model
    final class SketchProduction {
        @Attribute(.unique) var id: UUID
        var status: SketchProductionStatus
        var postDate: Date?
        var createdAt: Date
        var updatedAt: Date

        var project: Project?

        /// New in V23 (PRD §9.3). Cascade — a shoot record has no meaning without its
        /// production, same shape as `Gig.calendarEvent`.
        @Relationship(deleteRule: .cascade, inverse: \FilmShoot.sketchProduction)
        var filmShoot: FilmShoot?

        init(
            id: UUID = UUID(),
            status: SketchProductionStatus = .filmingNotScheduled,
            postDate: Date? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.status = status
            self.postDate = postDate
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// New in V23 (PRD §9.3). "Schedule Film Date should capture: Date, Call time, Estimated
    /// wrap, Location, Address, Cast, Crew, Wardrobe, Props, Equipment notes, Parking/access
    /// instructions, General notes." `calendarEvent` is the auto-created/kept-in-sync
    /// CalendarEvent that makes the shoot "automatically appear on Calendar" — cascade, same
    /// shape as `Gig.calendarEvent`.
    @Model
    final class FilmShoot {
        @Attribute(.unique) var id: UUID
        var callTime: Date
        var estimatedWrapTime: Date
        var location: String
        var address: String
        var cast: String
        var crew: String
        var wardrobe: String
        var props: String
        var equipmentNotes: String
        var parkingAccessInstructions: String
        var generalNotes: String
        var createdAt: Date
        var updatedAt: Date

        var sketchProduction: SketchProduction?

        @Relationship(deleteRule: .cascade, inverse: \CalendarEvent.filmShoot)
        var calendarEvent: CalendarEvent?

        /// New in V24 (PRD §9.4). Cascade — a call sheet has no meaning without its shoot, same
        /// shape as `SketchProduction.filmShoot`.
        @Relationship(deleteRule: .cascade, inverse: \CallSheet.filmShoot)
        var callSheet: CallSheet?

        init(
            id: UUID = UUID(),
            callTime: Date,
            estimatedWrapTime: Date,
            location: String = "",
            address: String = "",
            cast: String = "",
            crew: String = "",
            wardrobe: String = "",
            props: String = "",
            equipmentNotes: String = "",
            parkingAccessInstructions: String = "",
            generalNotes: String = "",
            createdAt: Date = .now
        ) {
            self.id = id
            self.callTime = callTime
            self.estimatedWrapTime = estimatedWrapTime
            self.location = location
            self.address = address
            self.cast = cast
            self.crew = crew
            self.wardrobe = wardrobe
            self.props = props
            self.equipmentNotes = equipmentNotes
            self.parkingAccessInstructions = parkingAccessInstructions
            self.generalNotes = generalNotes
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// New in V24 (PRD §9.4). "Generating an editable Call Sheet populated from project data" —
    /// a real snapshot-and-diverge, not a live mirror of FilmShoot (see this schema's own doc
    /// comment). `contactInformation`/`sceneNotes` have no FilmShoot counterpart, start empty.
    @Model
    final class CallSheet {
        @Attribute(.unique) var id: UUID
        var projectTitle: String
        var callTime: Date
        var wrapTime: Date
        var location: String
        var address: String
        var castAndCharacters: String
        var crewAndRoles: String
        var wardrobe: String
        var props: String
        var equipment: String
        var parkingAccess: String
        var contactInformation: String
        var sceneNotes: String
        var additionalNotes: String
        var createdAt: Date
        var updatedAt: Date

        var filmShoot: FilmShoot?

        init(
            id: UUID = UUID(),
            projectTitle: String,
            callTime: Date,
            wrapTime: Date,
            location: String = "",
            address: String = "",
            castAndCharacters: String = "",
            crewAndRoles: String = "",
            wardrobe: String = "",
            props: String = "",
            equipment: String = "",
            parkingAccess: String = "",
            contactInformation: String = "",
            sceneNotes: String = "",
            additionalNotes: String = "",
            createdAt: Date = .now
        ) {
            self.id = id
            self.projectTitle = projectTitle
            self.callTime = callTime
            self.wrapTime = wrapTime
            self.location = location
            self.address = address
            self.castAndCharacters = castAndCharacters
            self.crewAndRoles = crewAndRoles
            self.wardrobe = wardrobe
            self.props = props
            self.equipment = equipment
            self.parkingAccess = parkingAccess
            self.contactInformation = contactInformation
            self.sceneNotes = sceneNotes
            self.additionalNotes = additionalNotes
            self.createdAt = createdAt
            self.updatedAt = createdAt
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

        /// New in V28 (PRD §8.8: "The user should be able to set a general goal such as... 3
        /// posts per week"). Optional so lightweight migration leaves pre-existing rows `nil`
        /// rather than crashing (the V8 lesson) — `displayPostsPerWeekTarget` supplies the PRD's
        /// own example default for rows that predate this field.
        var postsPerWeekTarget: Int?
        var displayPostsPerWeekTarget: Int { postsPerWeekTarget ?? 3 }

        /// New in V31 — weekend counterpart to `weekdayCreativeCapacityHours`. Optional for the
        /// same V8-lesson reason as `postsPerWeekTarget`; `displayWeekendCreativeCapacityHours`
        /// falls back to the weekday value for rows that predate this field, so pre-existing
        /// users see an unchanged baseline until they explicitly set a weekend value.
        var weekendCreativeCapacityHours: Double?
        var displayWeekendCreativeCapacityHours: Double { weekendCreativeCapacityHours ?? weekdayCreativeCapacityHours }

        var updatedAt: Date

        init(
            id: UUID = UUID(),
            dayJobWeekdays: [Int] = [2, 3, 4, 5, 6],
            dayJobStartHour: Int = 8,
            dayJobEndHour: Int = 17,
            weekdayCreativeCapacityHours: Double = 2.5,
            standUpNightBonusHours: Double = 1.0,
            postsPerWeekTarget: Int? = 3,
            weekendCreativeCapacityHours: Double? = nil
        ) {
            self.id = id
            self.dayJobWeekdays = dayJobWeekdays
            self.dayJobStartHour = dayJobStartHour
            self.dayJobEndHour = dayJobEndHour
            self.weekdayCreativeCapacityHours = weekdayCreativeCapacityHours
            self.standUpNightBonusHours = standUpNightBonusHours
            self.postsPerWeekTarget = postsPerWeekTarget
            self.weekendCreativeCapacityHours = weekendCreativeCapacityHours
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

    /// PRD §7.2's three Joke Board columns.
    enum JokeStatus: String, Codable, CaseIterable {
        case ideas = "Joke Ideas"
        case new = "New"
        case done = "Done"
    }

    /// New in V13 (PRD §7.2-§7.4/§14.11). "A dedicated Stand-Up object" — deliberately not
    /// attached to a Project (see this schema's own doc comment for why). `order` positions a
    /// Joke within its current status column; moving between columns renumbers both the old and
    /// new column, the same pattern ActService/SceneService already use.
    @Model
    final class Joke {
        @Attribute(.unique) var id: UUID
        var title: String
        var text: String
        var status: JokeStatus
        var order: Int
        var progress: Int
        var notes: String
        var runtimeSeconds: Int?
        var priority: Int
        var isArchived: Bool
        var archivedAt: Date?
        var createdAt: Date
        var updatedAt: Date

        /// New in V14 (PRD §7.5-§7.6). "A Joke can exist independently or be referenced inside a
        /// Chunk." Plain optional relationship — same proven-safe shape as
        /// `Project.lastOpenedDocument`.
        var chunk: Chunk?

        /// New in V14. Position within `chunk.jokes`, distinct from `order` (the Joke Board's
        /// per-status-column position) — a Joke's board position and its position within a
        /// Chunk's story-run are independent. Optional for the same lightweight-migration
        /// reason as `Project.status`: `nil` reads as 0 via `displayOrderWithinChunk`.
        var orderWithinChunk: Int?
        var displayOrderWithinChunk: Int { orderWithinChunk ?? 0 }

        /// New in V17 (PRD §7.9). "Set-list items reference existing material rather than
        /// duplicate it." Nullify, not cascade — deleting a Joke that's on a planned set list
        /// must not silently delete the set-list row it's referenced from.
        @Relationship(deleteRule: .nullify, inverse: \GigSetListItem.joke)
        var setListAppearances: [GigSetListItem] = []

        /// New in V19 (PRD §7.11). Nullify, not cascade — deleting a Joke must not erase its
        /// logged Work Session history, only detach it (same reasoning as `setListAppearances`).
        @Relationship(deleteRule: .nullify, inverse: \WorkItem.joke)
        var workItems: [WorkItem] = []

        /// New in V20 (PRD §8.3). "Related Joke/Chunk reference." Same nullify reasoning as
        /// `setListAppearances`/`workItems`.
        @Relationship(deleteRule: .nullify, inverse: \Clip.joke)
        var clipAppearances: [Clip] = []

        /// New in V30 (PRD §13.9/§14.19). Records `status` transitions ("Joke Ideas"/New/Done)
        /// for Stand-Up Reports. Cascade, same shape as `WorkItem.historyEvents`/
        /// `Clip.historyEvents`.
        @Relationship(deleteRule: .cascade, inverse: \HistoryEvent.joke)
        var historyEvents: [HistoryEvent] = []

        init(
            id: UUID = UUID(),
            title: String = "",
            text: String,
            status: JokeStatus = .ideas,
            order: Int,
            progress: Int = 0,
            notes: String = "",
            runtimeSeconds: Int? = nil,
            priority: Int = 3,
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title
            self.text = text
            self.status = status
            self.order = order
            self.progress = progress
            self.notes = notes
            self.runtimeSeconds = runtimeSeconds
            self.priority = priority
            self.isArchived = false
            self.archivedAt = nil
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// New in V14 (PRD §7.5-§7.6/§14.12). "A larger thematic/story run of related jokes."
    /// Deliberately reuses JokeStatus for `status` — the PRD gives Chunk a "development status"
    /// without specifying distinct stage names from a Joke's, and a documented simplification
    /// (CLAUDE.md §13) beats inventing a second, undifferentiated status enum.
    @Model
    final class Chunk {
        @Attribute(.unique) var id: UUID
        var title: String
        var notes: String
        var status: JokeStatus
        var runtimeSeconds: Int?
        var createdAt: Date
        var updatedAt: Date

        /// Nullify, not cascade — "removing a Joke from a Chunk should only remove the
        /// relationship, not delete the Joke" (§7.6); the same must hold when the Chunk itself
        /// is deleted.
        @Relationship(deleteRule: .nullify, inverse: \Joke.chunk)
        var jokes: [Joke] = []

        /// New in V15 (PRD §7.7). Plain optional relationship — same proven-safe shape as
        /// `Joke.chunk`.
        var headlineSet: HeadlineSet?

        /// New in V15. This Chunk's position within `headlineSet.chunks`. Optional for the same
        /// lightweight-migration reason as `Project.status`.
        var orderInHeadlineSet: Int?
        var displayOrderInHeadlineSet: Int { orderInHeadlineSet ?? 0 }

        /// New in V17 (PRD §7.9). Same reasoning as `Joke.setListAppearances`.
        @Relationship(deleteRule: .nullify, inverse: \GigSetListItem.chunk)
        var setListAppearances: [GigSetListItem] = []

        /// New in V19 (PRD §7.11). Same reasoning as `Joke.workItems`.
        @Relationship(deleteRule: .nullify, inverse: \WorkItem.chunk)
        var workItems: [WorkItem] = []

        /// New in V20 (PRD §8.3). Same reasoning as `Joke.clipAppearances`.
        @Relationship(deleteRule: .nullify, inverse: \Clip.chunk)
        var clipAppearances: [Clip] = []

        /// New in V30 (PRD §13.9/§14.19). Same reasoning as `Joke.historyEvents`.
        @Relationship(deleteRule: .cascade, inverse: \HistoryEvent.chunk)
        var historyEvents: [HistoryEvent] = []

        init(
            id: UUID = UUID(),
            title: String,
            notes: String = "",
            status: JokeStatus = .ideas,
            runtimeSeconds: Int? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title
            self.notes = notes
            self.status = status
            self.runtimeSeconds = runtimeSeconds
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// New in V15 (PRD §7.7/§14.13). "Represents the evolving album/headlining set." Runtime is
    /// derived from members (HeadlineSetService.totalRuntimeSeconds), not stored — the same
    /// "computed, never stored, never drifts" approach already used for the Script Editor's
    /// scene numbers.
    @Model
    final class HeadlineSet {
        @Attribute(.unique) var id: UUID
        var title: String
        var notes: String
        var targetDurationMinutes: Int
        var createdAt: Date
        var updatedAt: Date

        @Relationship(deleteRule: .nullify, inverse: \Chunk.headlineSet)
        var chunks: [Chunk] = []

        init(
            id: UUID = UUID(),
            title: String,
            notes: String = "",
            targetDurationMinutes: Int = 60,
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title
            self.notes = notes
            self.targetDurationMinutes = targetDurationMinutes
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// New in V16 (PRD §7.8). "Stand Up should store gigs with date, venue, show, start time,
    /// set length, location, and notes." `calendarEvent` is the auto-created/kept-in-sync
    /// CalendarEvent that makes the gig "automatically appear on Calendar" — cascade, not
    /// nullify, since that event has no independent existence apart from the Gig (same shape as
    /// `Project.deadline`).
    @Model
    final class Gig {
        @Attribute(.unique) var id: UUID
        var venue: String
        var show: String
        var startAt: Date
        var setLengthMinutes: Int
        var location: String
        var notes: String
        var createdAt: Date
        var updatedAt: Date

        @Relationship(deleteRule: .cascade, inverse: \CalendarEvent.gig)
        var calendarEvent: CalendarEvent?

        /// New in V17 (PRD §7.9). Cascade — a set-list row has no meaning without its Gig, unlike
        /// its `joke`/`chunk` reference (nullify, see `Joke.setListAppearances`).
        @Relationship(deleteRule: .cascade, inverse: \GigSetListItem.gig)
        var setListItems: [GigSetListItem] = []

        /// New in V18 (PRD §7.10). "How did the set go?" — distinct from `notes` (pre-gig
        /// planning). Optional for the same lightweight-migration reason as `Project.status`.
        var afterGigNotes: String?
        var displayAfterGigNotes: String { afterGigNotes ?? "" }

        init(
            id: UUID = UUID(),
            venue: String,
            show: String = "",
            startAt: Date,
            setLengthMinutes: Int = 10,
            location: String = "",
            notes: String = "",
            createdAt: Date = .now
        ) {
            self.id = id
            self.venue = venue
            self.show = show
            self.startAt = startAt
            self.setLengthMinutes = setLengthMinutes
            self.location = location
            self.notes = notes
            self.afterGigNotes = nil
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// New in V17 (PRD §7.9). "A Gig may have a planned set list built from existing Chunks and
    /// Jokes. Set-list items reference existing material rather than duplicate it." Exactly one
    /// of `joke`/`chunk` should be set — enforced by `GigSetListService`'s two factory methods,
    /// not the model itself (SwiftData has no sum-type/enum-relationship construct). `order`
    /// positions the item within `gig.setListItems`, same renumber-on-move pattern as every
    /// other ordered collection in this codebase.
    @Model
    final class GigSetListItem {
        @Attribute(.unique) var id: UUID
        var order: Int
        var gig: Gig?
        var joke: Joke?
        var chunk: Chunk?
        var createdAt: Date

        /// Falls back to "Removed material" if the referenced Joke/Chunk was since deleted
        /// elsewhere (nullify, not cascade — see `Joke.setListAppearances`).
        var title: String { joke?.title ?? chunk?.title ?? "Removed material" }
        var runtimeSeconds: Int { joke?.runtimeSeconds ?? chunk?.runtimeSeconds ?? 0 }

        /// New in V18 (PRD §7.10). "Notes can be attached to... individual Jokes, or Chunks" —
        /// scoped to how this specific piece of material landed at this specific gig, not the
        /// Joke/Chunk's own standing `notes` field (which isn't gig-specific).
        var performanceNotes: String?
        var displayPerformanceNotes: String { performanceNotes ?? "" }

        init(
            id: UUID = UUID(),
            order: Int,
            joke: Joke? = nil,
            chunk: Chunk? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.order = order
            self.joke = joke
            self.chunk = chunk
            self.performanceNotes = nil
            self.createdAt = createdAt
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
        /// New in V19 (PRD §7.11). Plain optional relationships, the inverse side of `Joke.
        /// workItems`/`Chunk.workItems` — same proven-safe shape as `document`. A "general
        /// Stand-Up Writing session" WorkItem has both nil.
        var joke: Joke?
        var chunk: Chunk?
        /// New in V21 (PRD roadmap V0.4 "Editing progress/timer"). Inverse of `Clip.workItems`.
        var clip: Clip?
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

        /// New in V29 (PRD §14.19/§13.5/§13.7). Records status and progress transitions for
        /// "progress-over-time" reporting. Cascade, same shape as `workSessions`/`plannedSessions`.
        @Relationship(deleteRule: .cascade, inverse: \HistoryEvent.workItem)
        var historyEvents: [HistoryEvent] = []

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
        var gig: Gig?
        var filmShoot: FilmShoot?

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
        /// New in V20 (PRD §8.2). Plain optional relationship, same shape as `project` — the
        /// inverse of `Source.fileReference`.
        var source: Source?
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
            self.source = nil
            self.lastKnownAvailable = lastKnownAvailable
            self.lastCheckedAt = createdAt
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    enum ClipStatus: String, Codable, CaseIterable {
        case identifiedToIsolate = "Identified / To Isolate"
        case footageIsolated = "Footage Isolated"
        case currentlyEditing = "Currently Editing"
        case editedNotSubtitled = "Edited — Not Subtitled"
        case editedSubtitled = "Edited — Subtitled"
        case ready = "Ready"
        case posted = "Posted"
    }

    /// New in V20 (PRD §8.2). "A Source can represent a stand-up set, sketch footage, interview,
    /// podcast appearance, or other recorded material."
    @Model
    final class Source {
        @Attribute(.unique) var id: UUID
        var title: String
        var recordingDate: Date?
        var location: String
        var notes: String
        var createdAt: Date
        var updatedAt: Date

        /// Cascade — the bookmark has no independent existence apart from its Source, same
        /// reasoning as `Gig.calendarEvent`.
        @Relationship(deleteRule: .cascade, inverse: \FileReference.source)
        var fileReference: FileReference?

        /// Cascade — a Clip has no meaning without its Source, same shape as `Document.acts`.
        @Relationship(deleteRule: .cascade, inverse: \Clip.source)
        var clips: [Clip] = []

        init(
            id: UUID = UUID(),
            title: String,
            recordingDate: Date? = nil,
            location: String = "",
            notes: String = "",
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title
            self.recordingDate = recordingDate
            self.location = location
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }

    /// New in V20 (PRD §8.3). "One Source can contain many Clip records." `status` uses the
    /// PRD's own 7 "core states" (§8.4) as the real stored value; the board's simplified 5-lane
    /// display grouping is a view-layer concern, not modeled here.
    @Model
    final class Clip {
        @Attribute(.unique) var id: UUID
        var title: String
        var clipDescription: String
        var sourceTimestampStartSeconds: Int?
        var sourceTimestampEndSeconds: Int?
        var notes: String
        var editingNotes: String
        var status: ClipStatus
        var progress: Int
        var postDate: Date?
        var createdAt: Date
        var updatedAt: Date

        var source: Source?

        /// "Related Joke/Chunk reference." Nullify — deleting the referenced Joke/Chunk must not
        /// delete the Clip, only detach it (same reasoning as every prior cross-reference).
        var joke: Joke?
        var chunk: Chunk?

        /// New in V21. Nullify, not cascade — deleting a Clip must not erase its logged Work
        /// Session history, only detach it (same reasoning as `Joke.workItems`/`Chunk.workItems`).
        @Relationship(deleteRule: .nullify, inverse: \WorkItem.clip)
        var workItems: [WorkItem] = []

        /// New in V27 (PRD §14.18/§10). Cascade — a Post It queue entry has no meaning without
        /// the Clip it schedules, same shape as `Project.postingItem`.
        @Relationship(deleteRule: .cascade, inverse: \PostingItem.clip)
        var postingItem: PostingItem?

        /// New in V29 (PRD §14.19/§13.10-§13.11). Records `status` transitions for turnaround-
        /// style reporting. Cascade, same shape as `postingItem`.
        @Relationship(deleteRule: .cascade, inverse: \HistoryEvent.clip)
        var historyEvents: [HistoryEvent] = []

        init(
            id: UUID = UUID(),
            title: String,
            clipDescription: String = "",
            sourceTimestampStartSeconds: Int? = nil,
            sourceTimestampEndSeconds: Int? = nil,
            notes: String = "",
            editingNotes: String = "",
            status: ClipStatus = .identifiedToIsolate,
            progress: Int = 0,
            postDate: Date? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.title = title
            self.clipDescription = clipDescription
            self.sourceTimestampStartSeconds = sourceTimestampStartSeconds
            self.sourceTimestampEndSeconds = sourceTimestampEndSeconds
            self.notes = notes
            self.editingNotes = editingNotes
            self.status = status
            self.progress = progress
            self.postDate = postDate
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }
}
