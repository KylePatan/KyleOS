import Foundation
import SwiftData

/// Reusable domain actions for Work Items — Create/Complete/Change Status per PRD §15.1 — kept
/// out of views per CLAUDE.md §4.
enum WorkItemService {
    typealias WorkItem = KyleOSSchemaV6.WorkItem
    typealias Workspace = KyleOSSchemaV6.Workspace
    typealias WorkItemStatus = KyleOSSchemaV6.WorkItemStatus
    typealias Project = KyleOSSchemaV6.Project
    typealias Document = KyleOSSchemaV6.Document

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
}
