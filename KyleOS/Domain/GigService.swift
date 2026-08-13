import Foundation
import SwiftData

/// Reusable domain actions for Gigs (PRD §7.8), kept out of views per CLAUDE.md §4. A Gig
/// "automatically appears on Calendar" — this service is responsible for creating and keeping
/// in sync the CalendarEvent that makes that true, so no other layer needs to know Gig has a
/// calendar side effect.
///
/// Deliberately does NOT touch `CreativeCapacityService`. PRD §7.8 says gigs "reduce expected
/// Creative Capacity that day," but §4.4 — the section that actually defines the Creative
/// Capacity calculation, already shipped in V0.1 — says the opposite: "a stand-up gig night
/// generally supports about 1 additional creative hour," and `CreativeCapacityService` already
/// implements exactly that by checking for a `.standUpGig` CalendarEvent on the day. Since a Gig
/// creates a real `.standUpGig` CalendarEvent, that already-tested bonus applies automatically —
/// no new capacity logic is needed, and this increment does not resolve the wording conflict by
/// changing already-shipped, PRD-§4.4-accurate behavior. Flagged, not silently decided either
/// way, per CLAUDE.md §13.
enum GigService {
    typealias Gig = KyleOSSchemaV18.Gig
    typealias CalendarEvent = KyleOSSchemaV18.CalendarEvent

    @discardableResult
    static func createGig(
        venue: String,
        show: String = "",
        startAt: Date,
        setLengthMinutes: Int = 10,
        location: String = "",
        notes: String = "",
        context: ModelContext
    ) -> Gig {
        let gig = Gig(
            venue: venue,
            show: show,
            startAt: startAt,
            setLengthMinutes: setLengthMinutes,
            location: location,
            notes: notes
        )
        context.insert(gig)
        let event = CalendarEventService.createEvent(
            type: .standUpGig,
            startAt: startAt,
            endAt: startAt.addingTimeInterval(TimeInterval(setLengthMinutes * 60)),
            notes: notes,
            location: location,
            context: context
        )
        gig.calendarEvent = event
        return gig
    }

    static func rename(_ gig: Gig, venue: String? = nil, show: String? = nil) {
        if let venue { gig.venue = venue }
        if let show { gig.show = show }
        gig.updatedAt = .now
    }

    static func updateNotes(_ gig: Gig, notes: String) {
        gig.notes = notes
        gig.calendarEvent?.notes = notes
        gig.calendarEvent?.updatedAt = .now
        gig.updatedAt = .now
    }

    static func updateLocation(_ gig: Gig, location: String) {
        gig.location = location
        gig.calendarEvent?.location = location
        gig.calendarEvent?.updatedAt = .now
        gig.updatedAt = .now
    }

    /// Keeps the linked CalendarEvent's start/end in sync — "automatically appear on Calendar"
    /// means staying correct on edits, not just at creation.
    static func reschedule(_ gig: Gig, startAt: Date, setLengthMinutes: Int) {
        gig.startAt = startAt
        gig.setLengthMinutes = max(setLengthMinutes, 0)
        gig.updatedAt = .now
        if let event = gig.calendarEvent {
            event.startAt = startAt
            event.endAt = startAt.addingTimeInterval(TimeInterval(gig.setLengthMinutes * 60))
            event.updatedAt = .now
        }
    }

    static func gigs(in context: ModelContext) -> [Gig] {
        (try? context.fetch(FetchDescriptor<Gig>(sortBy: [SortDescriptor(\.startAt)]))) ?? []
    }

    static func upcoming(after date: Date = .now, in context: ModelContext) -> [Gig] {
        gigs(in: context).filter { $0.startAt >= date }
    }

    /// PRD §7.10: "After a gig, Kyle OS may optionally ask how the set went." A gig "ends" at
    /// startAt + setLengthMinutes; once that's passed and no reflection has been recorded yet,
    /// it's a candidate to ask about.
    static func hasEnded(_ gig: Gig, now: Date = .now) -> Bool {
        gig.startAt.addingTimeInterval(TimeInterval(gig.setLengthMinutes * 60)) < now
    }

    static func needsAfterGigNotes(_ gig: Gig, now: Date = .now) -> Bool {
        hasEnded(gig, now: now) && gig.displayAfterGigNotes.isEmpty
    }

    static func updateAfterGigNotes(_ gig: Gig, notes: String) {
        gig.afterGigNotes = notes
        gig.updatedAt = .now
    }

    /// Cascade delete rule on `Gig.calendarEvent` removes the linked CalendarEvent too.
    static func delete(_ gig: Gig, context: ModelContext) {
        context.delete(gig)
    }
}
