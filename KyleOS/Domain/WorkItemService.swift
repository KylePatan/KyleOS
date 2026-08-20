import Foundation
import SwiftData

/// Reusable domain actions for Work Items — Create/Complete/Change Status per PRD §15.1 — kept
/// out of views per CLAUDE.md §4.
enum WorkItemService {
    typealias WorkItem = KyleOSSchemaV33.WorkItem
    typealias Workspace = KyleOSSchemaV33.Workspace
    typealias WorkItemStatus = KyleOSSchemaV33.WorkItemStatus
    typealias Project = KyleOSSchemaV33.Project
    typealias Document = KyleOSSchemaV33.Document
    typealias Joke = KyleOSSchemaV33.Joke
    typealias Chunk = KyleOSSchemaV33.Chunk
    typealias Clip = KyleOSSchemaV33.Clip

    /// Generic fallback when no WorkTypeDefault matches `workTypeName` — better than a hard
    /// crash, but real usage should mostly hit the WorkTypeDefault-seeded path below.
    private static let fallbackEstimateMinutes = 60
    private static let fallbackPreferredSessionMinutes = 45
    private static let fallbackMinimumSessionMinutes = 15

    /// Creates a Work Item, seeding its estimate/session-length fields from the matching
    /// WorkTypeDefault (by name) when one exists — PRD §5.1: "Each work type can have a
    /// configurable default estimate that can be overridden for an individual project/task."
    /// If no WorkTypeDefault matches, falls back to generic values rather than failing.
    @discardableResult
    static func createWorkItem(
        title: String,
        workspace: Workspace,
        workTypeName: String,
        in project: Project,
        document: Document? = nil,
        priority: Int = 3,
        context: ModelContext
    ) throws -> WorkItem {
        let matchingDefault = try context.fetch(
            FetchDescriptor<WorkTypeDefaultService.WorkTypeDefault>(
                predicate: #Predicate { $0.name == workTypeName }
            )
        ).first

        let estimatedTotalMinutes = matchingDefault.map { Int($0.defaultEstimateHours * 60) } ?? fallbackEstimateMinutes
        let preferredSessionMinutes = matchingDefault?.preferredSessionMinutes ?? fallbackPreferredSessionMinutes
        let minimumSessionMinutes = matchingDefault?.minimumSessionMinutes ?? fallbackMinimumSessionMinutes
        let isSplittable = matchingDefault?.isSplittable ?? true

        let workItem = WorkItem(
            title: title,
            workspace: workspace,
            workTypeName: workTypeName,
            project: project,
            document: document,
            estimatedTotalMinutes: estimatedTotalMinutes,
            preferredSessionMinutes: preferredSessionMinutes,
            minimumSessionMinutes: minimumSessionMinutes,
            isSplittable: isSplittable,
            priority: priority
        )
        context.insert(workItem)
        return workItem
    }

    static func rename(_ workItem: WorkItem, to newTitle: String) {
        workItem.title = newTitle
        workItem.updatedAt = .now
    }

    /// PRD §14.19: status changes create a history record — enables progress-over-time/turnaround
    /// reporting (`ReportService`).
    static func changeStatus(_ workItem: WorkItem, to status: WorkItemStatus, context: ModelContext) {
        let oldStatus = workItem.status
        workItem.status = status
        workItem.updatedAt = .now
        guard oldStatus != status else { return }
        HistoryEventService.recordStatusChange(from: oldStatus.rawValue, to: status.rawValue, workItem: workItem, context: context)
    }

    /// Progress is user/session-driven, not automatically tied to status — completing a Work
    /// Item is a deliberate separate action (`complete(_:)`), matching PRD §15.1 naming
    /// "Create/Complete Work Item" as its own shared action rather than an implicit side effect.
    static func updateProgress(_ workItem: WorkItem, progress: Int, context: ModelContext) {
        let oldProgress = workItem.progress
        let oldStatus = workItem.status
        workItem.progress = min(max(progress, 0), 100)
        if workItem.status == .notStarted, workItem.progress > 0 {
            workItem.status = .inProgress
        }
        workItem.updatedAt = .now
        if oldProgress != workItem.progress {
            HistoryEventService.recordProgressChange(from: oldProgress, to: workItem.progress, workItem: workItem, context: context)
        }
        if oldStatus != workItem.status {
            HistoryEventService.recordStatusChange(from: oldStatus.rawValue, to: workItem.status.rawValue, workItem: workItem, context: context)
        }
    }

    static func complete(_ workItem: WorkItem, context: ModelContext) {
        let oldStatus = workItem.status
        let oldProgress = workItem.progress
        workItem.status = .completed
        workItem.progress = 100
        workItem.completedAt = .now
        workItem.updatedAt = .now
        if oldStatus != .completed {
            HistoryEventService.recordStatusChange(from: oldStatus.rawValue, to: WorkItemStatus.completed.rawValue, workItem: workItem, context: context)
        }
        if oldProgress != 100 {
            HistoryEventService.recordProgressChange(from: oldProgress, to: 100, workItem: workItem, context: context)
        }
    }

    static func setPriority(_ workItem: WorkItem, to priority: Int) {
        workItem.priority = priority
        workItem.updatedAt = .now
    }

    static func addDependency(_ workItem: WorkItem, dependsOn dependency: WorkItem) {
        guard !workItem.dependsOn.contains(where: { $0.id == dependency.id }) else { return }
        workItem.dependsOn.append(dependency)
        workItem.updatedAt = .now
    }

    static func removeDependency(_ workItem: WorkItem, dependency: WorkItem) {
        workItem.dependsOn.removeAll { $0.id == dependency.id }
        workItem.updatedAt = .now
    }

    static func workItems(for project: Project, in context: ModelContext) throws -> [WorkItem] {
        let projectID = project.id
        let descriptor = FetchDescriptor<WorkItem>(
            predicate: #Predicate { $0.project?.id == projectID },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    /// PRD §6.18: "Writing documents/stages use the universal Focus Timer." Lazily finds or
    /// creates the one Work Item that represents timed sessions on this Document, rather than
    /// requiring the user to set one up explicitly before they can just start writing.
    static func writingWorkItem(for document: Document, context: ModelContext) throws -> WorkItem {
        guard let project = document.project else {
            preconditionFailure("A Document used for Writing sessions must belong to a Project")
        }
        let documentID = document.id
        let existing = try context.fetch(
            FetchDescriptor<WorkItem>(predicate: #Predicate { $0.document?.id == documentID })
        ).first
        if let existing { return existing }
        return try createWorkItem(
            title: document.title,
            workspace: .writing,
            workTypeName: document.documentType.rawValue,
            in: project,
            document: document,
            context: context
        )
    }

    /// PRD §7.11: "The user can start a timed session against a specific Joke... or a general
    /// Stand-Up Writing session." Stand-Up material has no Project (unlike Writing's Documents),
    /// so this constructs the WorkItem directly rather than routing through `createWorkItem`
    /// (which requires one). Lazily finds or creates, same pattern as `writingWorkItem`.
    static func standUpWorkItem(for joke: Joke, context: ModelContext) throws -> WorkItem {
        let jokeID = joke.id
        if let existing = try context.fetch(
            FetchDescriptor<WorkItem>(predicate: #Predicate { $0.joke?.id == jokeID })
        ).first {
            return existing
        }
        let workItem = WorkItem(
            title: joke.title.isEmpty ? joke.text : joke.title,
            workspace: .standUp,
            workTypeName: "Stand-Up Development",
            project: nil
        )
        workItem.joke = joke
        context.insert(workItem)
        return workItem
    }

    static func standUpWorkItem(for chunk: Chunk, context: ModelContext) throws -> WorkItem {
        let chunkID = chunk.id
        if let existing = try context.fetch(
            FetchDescriptor<WorkItem>(predicate: #Predicate { $0.chunk?.id == chunkID })
        ).first {
            return existing
        }
        let workItem = WorkItem(
            title: chunk.title,
            workspace: .standUp,
            workTypeName: "Stand-Up Development",
            project: nil
        )
        workItem.chunk = chunk
        context.insert(workItem)
        return workItem
    }

    /// The "general Stand-Up Writing session" case — no Joke/Chunk attached. Filters in-memory
    /// rather than via `#Predicate` (the Sixth/Tenth lesson: `#Predicate` can't reliably
    /// evaluate a comparison against an enum-typed property like `workspace`); fine at
    /// Foundation's data volumes, same established workaround used elsewhere.
    static func generalStandUpWorkItem(context: ModelContext) throws -> WorkItem {
        let all = try context.fetch(FetchDescriptor<WorkItem>())
        if let existing = all.first(where: { $0.workspace == .standUp && $0.joke == nil && $0.chunk == nil }) {
            return existing
        }
        let workItem = WorkItem(
            title: "Stand-Up Writing",
            workspace: .standUp,
            workTypeName: "Stand-Up Development",
            project: nil
        )
        context.insert(workItem)
        return workItem
    }

    /// PRD roadmap V0.4 "Editing progress/timer." Every Clips timer is against a specific Clip —
    /// unlike Stand-Up, the PRD never mentions a "general" untargeted Clips session, so there's
    /// no `generalClipsWorkItem` counterpart to `generalStandUpWorkItem`. Lazily finds or
    /// creates, same pattern as `standUpWorkItem`.
    /// `workTypeName` is now part of the lookup, not just the created value — Kyle (2026-08-17)
    /// asked for separate named deadlines per production stage ("finish editing", "finish
    /// subtitling"), which means a Clip can have more than one WorkItem now. Filtering only by
    /// `clip.id` (the original, single-WorkItem-per-clip shape) would make this and the new
    /// per-stage factories below ambiguous about which WorkItem they're each supposed to find or
    /// create. Existing data is unaffected — every WorkItem this factory ever created already has
    /// `workTypeName == "Clip Editing"`.
    static func clipWorkItem(for clip: Clip, context: ModelContext) throws -> WorkItem {
        let clipID = clip.id
        let workTypeName = "Clip Editing"
        if let existing = try context.fetch(
            FetchDescriptor<WorkItem>(predicate: #Predicate { $0.clip?.id == clipID && $0.workTypeName == workTypeName })
        ).first {
            return existing
        }
        let workItem = WorkItem(
            title: clip.title,
            workspace: .clips,
            workTypeName: workTypeName,
            project: nil
        )
        workItem.clip = clip
        context.insert(workItem)
        return workItem
    }

    /// Same lazy find-or-create shape as `clipWorkItem`, scoped to the Subtitling stage
    /// specifically so it carries its own independent Deadline.
    static func clipSubtitlingWorkItem(for clip: Clip, context: ModelContext) throws -> WorkItem {
        let clipID = clip.id
        let workTypeName = "Clip Subtitling"
        if let existing = try context.fetch(
            FetchDescriptor<WorkItem>(predicate: #Predicate { $0.clip?.id == clipID && $0.workTypeName == workTypeName })
        ).first {
            return existing
        }
        let workItem = WorkItem(
            title: "\(clip.title) — Subtitling",
            workspace: .clips,
            workTypeName: workTypeName,
            project: nil
        )
        workItem.clip = clip
        context.insert(workItem)
        return workItem
    }

    /// Exists purely as an anchor for the Post Date Deadline (`PostingItemService.
    /// setConfirmedPostDate`) so a confirmed post date can reuse the same Deadline/CalendarEvent/
    /// ranking pipeline as every other deadline — no separate "Start Timer" or UI of its own.
    static func clipPostingWorkItem(for clip: Clip, context: ModelContext) throws -> WorkItem {
        let clipID = clip.id
        let workTypeName = "Clip Posting"
        if let existing = try context.fetch(
            FetchDescriptor<WorkItem>(predicate: #Predicate { $0.clip?.id == clipID && $0.workTypeName == workTypeName })
        ).first {
            return existing
        }
        let workItem = WorkItem(
            title: "\(clip.title) — Post",
            workspace: .clips,
            workTypeName: workTypeName,
            project: nil
        )
        workItem.clip = clip
        context.insert(workItem)
        return workItem
    }

    /// Sketch-side counterpart to `clipPostingWorkItem`, same anchor-only purpose.
    static func sketchPostingWorkItem(for project: Project, context: ModelContext) throws -> WorkItem {
        let workTypeName = "Sketch Posting"
        if let existing = try workItems(for: project, in: context).first(where: { $0.workTypeName == workTypeName }) {
            return existing
        }
        return try createWorkItem(
            title: "\(project.title) — Post",
            workspace: .sketches,
            workTypeName: workTypeName,
            in: project,
            context: context
        )
    }

    /// PRD §9.7: "Cumulative project time should include Writing and later production/post-
    /// production work as one connected history." Unlike Writing (per-Document) or Clips
    /// (per-Clip), the whole Project is the natural unit for a Sketch's editing phase, and
    /// Project already supports WorkItem directly, so no new schema is needed. Lazily finds or
    /// creates, same pattern as `writingWorkItem`/`clipWorkItem`.
    static func sketchEditingWorkItem(for project: Project, context: ModelContext) throws -> WorkItem {
        if let existing = try workItems(for: project, in: context).first(where: { $0.workspace == .sketches }) {
            return existing
        }
        return try createWorkItem(
            title: project.title,
            workspace: .sketches,
            workTypeName: "Sketch Editing",
            in: project,
            context: context
        )
    }

    /// What real content a WorkItem represents — for Home's right-click Archive/Delete (Kyle,
    /// 2026-08-20: "the things on 'home' should be removeable"), which needs to reach past the
    /// WorkItem row to whatever it's actually about. Mirrors `DeepLinkTarget.forWorkItem`'s exact
    /// resolution order (project first, then chunk/joke/clip) — "where this opens to" and "what
    /// this actually represents" are the same underlying question, so they must never drift apart
    /// into two different answers for the same WorkItem.
    enum UnderlyingContent {
        case project(Project)
        case chunk(Chunk)
        case joke(Joke)
        case clip(Clip)
    }

    static func underlyingContent(for workItem: WorkItem) -> UnderlyingContent? {
        if let project = workItem.project { return .project(project) }
        if let chunk = workItem.chunk { return .chunk(chunk) }
        if let joke = workItem.joke { return .joke(joke) }
        if let clip = workItem.clip { return .clip(clip) }
        return nil
    }

    /// `nil` when the content has no archive concept of its own (Chunk/Clip) or there's nothing
    /// to act on at all (a general, untargeted session) — the caller should omit the Archive menu
    /// entry entirely in that case, not show one that silently does nothing.
    static func archiveUnderlyingContent(for workItem: WorkItem) -> (() -> Void)? {
        switch underlyingContent(for: workItem) {
        case .project(let project):
            return { ProjectService.archive(project) }
        case .joke(let joke):
            return { JokeService.archive(joke) }
        case .chunk, .clip, .none:
            return nil
        }
    }

    /// Kyle (2026-08-20, real use): found this the hard way — deleted a Clip's Source (correctly
    /// cascading away the Clip itself), but the Clip's own "Post" WorkItem/Deadline stayed on Home
    /// forever with no way to remove it. That's not a bug in the cascade rule itself:
    /// `Clip.workItems`/`Chunk.workItems`/`Joke.workItems` are deliberately `.nullify`, not
    /// `.cascade` — a WorkItem represents real session/time-tracking history that a codebase-wide
    /// design choice (see those relationships' own doc comments) says must outlive the content it
    /// was originally about, the same way a HistoryEvent record does. So once its target is gone,
    /// `underlyingContent` correctly returns `nil` — but that used to mean "nothing to delete,"
    /// when what Kyle actually needed was "delete the row itself, there's nothing richer left."
    /// Same fallback also covers a genuinely general, untargeted Stand-Up session ("Stand-Up
    /// Writing") that never had real content to begin with — same "just remove this row" ask.
    static func deleteUnderlyingContent(for workItem: WorkItem, context: ModelContext) {
        switch underlyingContent(for: workItem) {
        case .project(let project): ProjectService.delete(project, context: context)
        case .chunk(let chunk): ChunkService.delete(chunk, context: context)
        case .joke(let joke): JokeService.delete(joke, context: context)
        case .clip(let clip): ClipService.delete(clip, context: context)
        case .none: context.delete(workItem)
        }
    }
}
