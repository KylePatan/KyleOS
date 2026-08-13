import Foundation
import SwiftData

/// Reusable domain actions for Deadlines (PRD §14.10), kept out of views per CLAUDE.md §4. A
/// Deadline attaches to exactly one of Project or WorkItem — callers pick which factory to use.
enum DeadlineService {
    typealias Deadline = KyleOSSchemaV14.Deadline
    typealias Project = KyleOSSchemaV14.Project
    typealias WorkItem = KyleOSSchemaV14.WorkItem

    @discardableResult
    static func setDeadline(
        for project: Project,
        label: String,
        dueAt: Date,
        isHard: Bool = true,
        notes: String = "",
        context: ModelContext
    ) -> Deadline {
        let deadline = Deadline(label: label, dueAt: dueAt, isHard: isHard, notes: notes, project: project)
        context.insert(deadline)
        project.deadline = deadline
        return deadline
    }

    @discardableResult
    static func setDeadline(
        for workItem: WorkItem,
        label: String,
        dueAt: Date,
        isHard: Bool = true,
        notes: String = "",
        context: ModelContext
    ) -> Deadline {
        let deadline = Deadline(label: label, dueAt: dueAt, isHard: isHard, notes: notes, workItem: workItem)
        context.insert(deadline)
        workItem.deadline = deadline
        return deadline
    }

    static func reschedule(_ deadline: Deadline, to newDueAt: Date) {
        deadline.dueAt = newDueAt
        deadline.updatedAt = .now
    }

    static func confirm(_ deadline: Deadline) {
        deadline.isConfirmed = true
        deadline.updatedAt = .now
    }

    static func unconfirm(_ deadline: Deadline) {
        deadline.isConfirmed = false
        deadline.updatedAt = .now
    }

    static func upcoming(after date: Date = .now, in context: ModelContext) throws -> [Deadline] {
        let descriptor = FetchDescriptor<Deadline>(
            predicate: #Predicate { $0.dueAt >= date },
            sortBy: [SortDescriptor(\.dueAt)]
        )
        return try context.fetch(descriptor)
    }
}
