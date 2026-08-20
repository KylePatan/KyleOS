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
    typealias Deadline = KyleOSSchemaV33.Deadline
    typealias Project = KyleOSSchemaV33.Project
    typealias WorkItem = KyleOSSchemaV33.WorkItem
    typealias CalendarEventType = KyleOSSchemaV33.CalendarEventType

    /// Editable, not just settable once — a UI "Set/Edit Deadline" control calling this on every
    /// save must not silently orphan the previous Deadline (and its CalendarEvent) each time.
    /// `project.deadline`/`workItem.deadline` are cascade-delete relationships, but cascade only
    /// fires when the *parent* is deleted — reassigning the relationship to a brand-new Deadline
    /// leaves the old one sitting in the store, unreferenced by anything, forever. So: update the
    /// existing Deadline in place if one's already there, only create a new one the first time.
    @discardableResult
    static func setDeadline(
        for project: Project,
        label: String,
        dueAt: Date,
        isHard: Bool = true,
        notes: String = "",
        context: ModelContext
    ) -> Deadline {
        if let existing = project.deadline {
            update(existing, label: label, dueAt: dueAt, isHard: isHard, notes: notes, context: context)
            return existing
        }
        let deadline = Deadline(label: label, dueAt: dueAt, isHard: isHard, notes: notes, project: project)
        context.insert(deadline)
        project.deadline = deadline
        syncCalendarEvent(for: deadline, context: context)
        return deadline
    }

    /// `calendarEventType` lets a caller tag the synced event as something more specific than a
    /// generic Hard Deadline — e.g. Post Date (Kyle, 2026-08-17: post dates should "show up in my
    /// calendar" with the right label, not read as an ordinary deadline). Purely cosmetic/
    /// classification; the underlying Deadline/lock/ranking behavior is identical either way.
    @discardableResult
    static func setDeadline(
        for workItem: WorkItem,
        label: String,
        dueAt: Date,
        isHard: Bool = true,
        notes: String = "",
        calendarEventType: CalendarEventType = .hardDeadline,
        context: ModelContext
    ) -> Deadline {
        if let existing = workItem.deadline {
            update(existing, label: label, dueAt: dueAt, isHard: isHard, notes: notes, calendarEventType: calendarEventType, context: context)
            return existing
        }
        let deadline = Deadline(label: label, dueAt: dueAt, isHard: isHard, notes: notes, workItem: workItem)
        context.insert(deadline)
        workItem.deadline = deadline
        syncCalendarEvent(for: deadline, calendarEventType: calendarEventType, context: context)
        return deadline
    }

    /// Removing a deadline entirely (not just editing it) — deletes its CalendarEvent outright
    /// (unlike the "orphan, don't delete" default elsewhere in this codebase) since a hard
    /// deadline's event exists *only* as that deadline's own side effect, not organic content the
    /// user created independently.
    static func removeDeadline(for project: Project, context: ModelContext) {
        guard let deadline = project.deadline else { return }
        deadline.calendarEvents.forEach { context.delete($0) }
        context.delete(deadline)
    }

    static func removeDeadline(for workItem: WorkItem, context: ModelContext) {
        guard let deadline = workItem.deadline else { return }
        deadline.calendarEvents.forEach { context.delete($0) }
        context.delete(deadline)
    }

    private static func update(
        _ deadline: Deadline,
        label: String,
        dueAt: Date,
        isHard: Bool,
        notes: String,
        calendarEventType: CalendarEventType = .hardDeadline,
        context: ModelContext
    ) {
        deadline.label = label
        deadline.dueAt = dueAt
        deadline.isHard = isHard
        deadline.notes = notes
        deadline.updatedAt = .now
        syncCalendarEvent(for: deadline, calendarEventType: calendarEventType, context: context)
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

    /// Creates the calendar event the first time a deadline goes hard, updates that same event in
    /// place on later edits (rather than creating a duplicate every time, and re-tagging its type
    /// in case a caller's `calendarEventType` changed), and removes it outright if the deadline is
    /// edited back to soft.
    private static func syncCalendarEvent(for deadline: Deadline, calendarEventType: CalendarEventType = .hardDeadline, context: ModelContext) {
        guard deadline.isHard else {
            deadline.calendarEvents.forEach { context.delete($0) }
            return
        }
        if let event = deadline.calendarEvents.first {
            event.startAt = deadline.dueAt
            event.endAt = deadline.dueAt
            event.notes = deadline.label
            event.eventType = calendarEventType
            event.updatedAt = .now
        } else {
            CalendarEventService.createEvent(
                type: calendarEventType,
                startAt: deadline.dueAt,
                endAt: deadline.dueAt,
                isHardCommitment: true,
                notes: deadline.label,
                deadline: deadline,
                context: context
            )
        }
    }
}
