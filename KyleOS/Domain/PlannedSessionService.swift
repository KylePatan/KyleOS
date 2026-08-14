import Foundation
import SwiftData

/// Reusable domain actions for Planned Sessions (PRD §14.7), kept out of views per CLAUDE.md §4.
/// This is scheduling data storage only — no Scheduling Engine logic (V0.7, Decision Gate B)
/// decides placement here.
enum PlannedSessionService {
    typealias PlannedSession = KyleOSSchemaV26.PlannedSession
    typealias PlannedSessionStatus = KyleOSSchemaV26.PlannedSessionStatus
    typealias SessionOrigin = KyleOSSchemaV26.SessionOrigin
    typealias WorkItem = KyleOSSchemaV26.WorkItem
    typealias CalendarEvent = KyleOSSchemaV26.CalendarEvent

    @discardableResult
    static func schedule(
        for workItem: WorkItem,
        at scheduledAt: Date,
        durationMinutes: Int,
        origin: SessionOrigin = .manual,
        calendarEvent: CalendarEvent? = nil,
        context: ModelContext
    ) -> PlannedSession {
        let session = PlannedSession(
            workItem: workItem,
            scheduledAt: scheduledAt,
            plannedDurationMinutes: durationMinutes,
            origin: origin,
            calendarEvent: calendarEvent
        )
        context.insert(session)
        return session
    }

    /// PRD §11.8: "locked sessions require explicit confirmation before moving" — same guard as
    /// CalendarEventService.reschedule.
    static func reschedule(_ session: PlannedSession, to newScheduledAt: Date, durationMinutes: Int? = nil) {
        guard !session.isLocked else { return }
        session.scheduledAt = newScheduledAt
        if let durationMinutes {
            session.plannedDurationMinutes = durationMinutes
        }
        session.updatedAt = .now
    }

    static func setLocked(_ session: PlannedSession, _ locked: Bool) {
        session.isLocked = locked
        session.updatedAt = .now
    }

    static func markCompleted(_ session: PlannedSession) {
        session.status = .completed
        session.updatedAt = .now
    }

    /// PRD §11.10: "A missed flexible session returns its remaining effort to the scheduling
    /// pool." Returning the effort is the Scheduling Engine's job (V0.7) — this just records the
    /// status change the engine will react to later.
    static func markMissed(_ session: PlannedSession) {
        session.status = .missed
        session.updatedAt = .now
    }

    static func markCancelled(_ session: PlannedSession) {
        session.status = .cancelled
        session.updatedAt = .now
    }

    static func sessions(for workItem: WorkItem, in context: ModelContext) throws -> [PlannedSession] {
        let workItemID = workItem.id
        let descriptor = FetchDescriptor<PlannedSession>(
            predicate: #Predicate { $0.workItem?.id == workItemID },
            sortBy: [SortDescriptor(\.scheduledAt)]
        )
        return try context.fetch(descriptor)
    }

    /// Filters by status in-memory after the date-range fetch — SwiftData's #Predicate macro
    /// doesn't reliably support comparing custom enum properties, even against a captured
    /// constant ("Captured/constant values of type 'PlannedSessionStatus' are not supported").
    /// Fine at Foundation's data volumes; revisit if this ever needs to scale.
    static func upcoming(after date: Date = .now, in context: ModelContext) throws -> [PlannedSession] {
        let descriptor = FetchDescriptor<PlannedSession>(
            predicate: #Predicate { $0.scheduledAt >= date },
            sortBy: [SortDescriptor(\.scheduledAt)]
        )
        return try context.fetch(descriptor).filter { $0.status == .scheduled }
    }
}
