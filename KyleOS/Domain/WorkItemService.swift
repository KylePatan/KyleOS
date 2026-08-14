import Foundation
import SwiftData

/// Reusable domain actions for Work Items — Create/Complete/Change Status per PRD §15.1 — kept
/// out of views per CLAUDE.md §4.
enum WorkItemService {
    typealias WorkItem = KyleOSSchemaV28.WorkItem
    typealias Workspace = KyleOSSchemaV28.Workspace
    typealias WorkItemStatus = KyleOSSchemaV28.WorkItemStatus
    typealias Project = KyleOSSchemaV28.Project
    typealias Document = KyleOSSchemaV28.Document
    typealias Joke = KyleOSSchemaV28.Joke
    typealias Chunk = KyleOSSchemaV28.Chunk
    typealias Clip = KyleOSSchemaV28.Clip

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

    static func changeStatus(_ workItem: WorkItem, to status: WorkItemStatus) {
        workItem.status = status
        workItem.updatedAt = .now
    }

    /// Progress is user/session-driven, not automatically tied to status — completing a Work
    /// Item is a deliberate separate action (`complete(_:)`), matching PRD §15.1 naming
    /// "Create/Complete Work Item" as its own shared action rather than an implicit side effect.
    static func updateProgress(_ workItem: WorkItem, progress: Int) {
        workItem.progress = min(max(progress, 0), 100)
        if workItem.status == .notStarted, workItem.progress > 0 {
            workItem.status = .inProgress
        }
        workItem.updatedAt = .now
    }

    static func complete(_ workItem: WorkItem) {
        workItem.status = .completed
        workItem.progress = 100
        workItem.completedAt = .now
        workItem.updatedAt = .now
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
    static func clipWorkItem(for clip: Clip, context: ModelContext) throws -> WorkItem {
        let clipID = clip.id
        if let existing = try context.fetch(
            FetchDescriptor<WorkItem>(predicate: #Predicate { $0.clip?.id == clipID })
        ).first {
            return existing
        }
        let workItem = WorkItem(
            title: clip.title,
            workspace: .clips,
            workTypeName: "Clip Editing",
            project: nil
        )
        workItem.clip = clip
        context.insert(workItem)
        return workItem
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
}
