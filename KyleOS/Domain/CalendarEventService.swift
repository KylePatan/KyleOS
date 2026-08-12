import Foundation
import SwiftData

/// Reusable domain actions for Calendar Events (PRD §14.9), kept out of views per CLAUDE.md §4.
/// No Google Calendar sync logic here — that's V0.6 (CLAUDE.md §8).
enum CalendarEventService {
    typealias CalendarEvent = KyleOSSchemaV9.CalendarEvent
    typealias CalendarEventType = KyleOSSchemaV9.CalendarEventType
    typealias Availability = KyleOSSchemaV9.Availability
    typealias Project = KyleOSSchemaV9.Project
    typealias WorkItem = KyleOSSchemaV9.WorkItem
    typealias Deadline = KyleOSSchemaV9.Deadline

    @discardableResult
    static func createEvent(
        type: CalendarEventType,
        startAt: Date,
        endAt: Date,
        isAllDay: Bool = false,
        availability: Availability = .busy,
        isHardCommitment: Bool = false,
        notes: String = "",
        location: String = "",
        project: Project? = nil,
        workItem: WorkItem? = nil,
        deadline: Deadline? = nil,
        context: ModelContext
    ) -> CalendarEvent {
        let event = CalendarEvent(
            eventType: type,
            startAt: startAt,
            endAt: endAt,
            isAllDay: isAllDay,
            availability: availability,
            isHardCommitment: isHardCommitment,
            notes: notes,
            location: location,
            project: project,
            workItem: workItem,
            deadline: deadline
        )
        context.insert(event)
        return event
    }

    /// Locked events (PRD §11.8: "locked sessions require explicit confirmation before moving")
    /// must be explicitly unlocked before reschedule takes effect — silently moving a locked
    /// event would defeat the point of locking it.
    static func reschedule(_ event: CalendarEvent, startAt: Date, endAt: Date) {
        guard !event.isLocked else { return }
        event.startAt = startAt
        event.endAt = endAt
        event.updatedAt = .now
    }

    static func setLocked(_ event: CalendarEvent, _ locked: Bool) {
        event.isLocked = locked
        event.updatedAt = .now
    }

    static func setAvailability(_ event: CalendarEvent, to availability: Availability) {
        event.availability = availability
        event.updatedAt = .now
    }

    static func events(from start: Date, to end: Date, in context: ModelContext) throws -> [CalendarEvent] {
        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { $0.startAt < end && $0.endAt > start },
            sortBy: [SortDescriptor(\.startAt)]
        )
        return try context.fetch(descriptor)
    }
}
