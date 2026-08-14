import Foundation
import SwiftData

/// Reusable domain actions for Deadlines (PRD §14.10), kept out of views per CLAUDE.md §4. A
/// Deadline attaches to exactly one of Project or WorkItem — callers pick which factory to use.
///
/// PRD §11.3/§14.9: a hard Deadline "automatically appears on Calendar" as a `.hardDeadline`
/// event, same "domain object owns its CalendarEvent side effect" shape as GigService/
/// SketchProductionService. Soft (non-`isHard`) deadlines deliberately get no CalendarEvent —
/// the `.hardDeadline` event type name is specific, and a soft deadline isn't a commitment in
/// the PRD §11.8 sense. Unlike Gig/FilmShoot's cascade-owned single relationship, Deadline's
/// existing `calendarEvents` link (since Foundation) is a nullify array — deleting a Deadline
/// orphans rather than deletes its CalendarEvent, consistent with Project/WorkItem's own
/// CalendarEvent relationships (CalendarEvent survives as a historical record by default in this
/// codebase unless it's a Gig/FilmShoot-style single owned commitment).
enum DeadlineService {
    typealias Deadline = KyleOSSchemaV27.Deadline
    typealias Project = KyleOSSchemaV27.Project
    typealias WorkItem = KyleOSSchemaV27.WorkItem

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
        syncCalendarEvent(for: deadline, context: context)
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
        syncCalendarEvent(for: deadline, context: context)
        return deadline
    }

    /// A deliberate Deadline reschedule is the source of truth — unlike a direct calendar drag,
    /// it always moves the linked event even if that event is locked (mirrors GigService.reschedule
    /// mutating fields directly rather than going through CalendarEventService's locked guard).
    static func reschedule(_ deadline: Deadline, to newDueAt: Date) {
        deadline.dueAt = newDueAt
        deadline.updatedAt = .now
        if let event = deadline.calendarEvents.first {
            event.startAt = newDueAt
            event.endAt = newDueAt
            event.updatedAt = .now
        }
    }

    /// PRD §11.8: locked events "require explicit confirmation before moving." Confirming a
    /// Deadline is exactly that explicit confirmation, so it locks the linked CalendarEvent;
    /// unconfirming releases it back to movable.
    static func confirm(_ deadline: Deadline) {
        deadline.isConfirmed = true
        deadline.updatedAt = .now
        if let event = deadline.calendarEvents.first {
            CalendarEventService.setLocked(event, true)
        }
    }

    static func unconfirm(_ deadline: Deadline) {
        deadline.isConfirmed = false
        deadline.updatedAt = .now
        if let event = deadline.calendarEvents.first {
            CalendarEventService.setLocked(event, false)
        }
    }

    static func upcoming(after date: Date = .now, in context: ModelContext) throws -> [Deadline] {
        let descriptor = FetchDescriptor<Deadline>(
            predicate: #Predicate { $0.dueAt >= date },
            sortBy: [SortDescriptor(\.dueAt)]
        )
        return try context.fetch(descriptor)
    }

    private static func syncCalendarEvent(for deadline: Deadline, context: ModelContext) {
        guard deadline.isHard else { return }
        CalendarEventService.createEvent(
            type: .hardDeadline,
            startAt: deadline.dueAt,
            endAt: deadline.dueAt,
            isHardCommitment: true,
            notes: deadline.label,
            deadline: deadline,
            context: context
        )
    }
}
