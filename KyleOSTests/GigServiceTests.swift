import XCTest
import SwiftData
@testable import KyleOS

final class GigServiceTests: XCTestCase {

    func testCreateGigAutoCreatesLinkedStandUpGigCalendarEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let startAt = Date(timeIntervalSince1970: 1_700_000_000)

        let gig = GigService.createGig(
            venue: "The Comedy Cellar",
            show: "Late Show",
            startAt: startAt,
            setLengthMinutes: 15,
            location: "New York, NY",
            context: context
        )
        try context.save()

        let event = try XCTUnwrap(gig.calendarEvent)
        XCTAssertEqual(event.eventType, .standUpGig)
        XCTAssertEqual(event.startAt, startAt)
        XCTAssertEqual(event.endAt, startAt.addingTimeInterval(15 * 60))
        XCTAssertEqual(event.location, "New York, NY")
        XCTAssertEqual(event.gig?.id, gig.id)
    }

    func testCreateGigDefaultsSetLengthToTenMinutes() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
        try context.save()

        XCTAssertEqual(gig.setLengthMinutes, 10)
    }

    func testRenameUpdatesVenueAndShowIndependently() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "Draft Venue", show: "Draft Show", startAt: .now, context: context)
        try context.save()

        GigService.rename(gig, venue: "The Comedy Cellar")
        try context.save()

        XCTAssertEqual(gig.venue, "The Comedy Cellar")
        XCTAssertEqual(gig.show, "Draft Show")
    }

    func testUpdateNotesAndLocationPropagateToLinkedCalendarEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
        try context.save()

        GigService.updateNotes(gig, notes: "Bring new closer.")
        GigService.updateLocation(gig, location: "New York, NY")
        try context.save()

        XCTAssertEqual(gig.notes, "Bring new closer.")
        XCTAssertEqual(gig.calendarEvent?.notes, "Bring new closer.")
        XCTAssertEqual(gig.location, "New York, NY")
        XCTAssertEqual(gig.calendarEvent?.location, "New York, NY")
    }

    func testRescheduleKeepsLinkedCalendarEventInSync() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let originalStart = Date(timeIntervalSince1970: 1_700_000_000)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: originalStart, setLengthMinutes: 10, context: context)
        try context.save()

        let newStart = originalStart.addingTimeInterval(86400)
        GigService.reschedule(gig, startAt: newStart, setLengthMinutes: 20)
        try context.save()

        XCTAssertEqual(gig.startAt, newStart)
        XCTAssertEqual(gig.setLengthMinutes, 20)
        XCTAssertEqual(gig.calendarEvent?.startAt, newStart)
        XCTAssertEqual(gig.calendarEvent?.endAt, newStart.addingTimeInterval(20 * 60))
    }

    func testRescheduleNeverGoesNegativeSetLength() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
        try context.save()

        GigService.reschedule(gig, startAt: .now, setLengthMinutes: -5)
        try context.save()

        XCTAssertEqual(gig.setLengthMinutes, 0)
    }

    func testGigsSortedByStartAt() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let later = Date(timeIntervalSince1970: 1_800_000_000)
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        GigService.createGig(venue: "Later Venue", startAt: later, context: context)
        GigService.createGig(venue: "Earlier Venue", startAt: earlier, context: context)
        try context.save()

        let gigs = GigService.gigs(in: context)

        XCTAssertEqual(gigs.map(\.venue), ["Earlier Venue", "Later Venue"])
    }

    func testUpcomingExcludesPastGigs() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let past = Date(timeIntervalSince1970: 1_000_000_000)
        let future = Date.now.addingTimeInterval(86400)
        GigService.createGig(venue: "Past Venue", startAt: past, context: context)
        GigService.createGig(venue: "Future Venue", startAt: future, context: context)
        try context.save()

        let upcoming = GigService.upcoming(in: context)

        XCTAssertEqual(upcoming.map(\.venue), ["Future Venue"])
    }

    func testDeleteGigCascadeDeletesLinkedCalendarEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
        try context.save()
        let eventID = try XCTUnwrap(gig.calendarEvent?.id)

        GigService.delete(gig, context: context)
        try context.save()

        let remainingEvents = try context.fetch(FetchDescriptor<GigService.CalendarEvent>())
        XCTAssertFalse(remainingEvents.contains { $0.id == eventID })
    }

    func testNeedsAfterGigNotesIsFalseBeforeTheGigEnds() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let now = Date()
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: now, setLengthMinutes: 15, context: context)
        try context.save()

        XCTAssertFalse(GigService.needsAfterGigNotes(gig, now: now))
        XCTAssertFalse(GigService.needsAfterGigNotes(gig, now: now.addingTimeInterval(5 * 60)))
    }

    func testNeedsAfterGigNotesIsTrueAfterTheGigEndsUntilNotesAreAdded() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let now = Date()
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: now, setLengthMinutes: 15, context: context)
        try context.save()
        let afterGig = now.addingTimeInterval(20 * 60)

        XCTAssertTrue(GigService.needsAfterGigNotes(gig, now: afterGig))

        GigService.updateAfterGigNotes(gig, notes: "Killed with the closer.")
        try context.save()

        XCTAssertFalse(GigService.needsAfterGigNotes(gig, now: afterGig))
    }

    func testUpdateAfterGigNotesPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
        try context.save()

        GigService.updateAfterGigNotes(gig, notes: "Killed with the closer.")
        try context.save()

        XCTAssertEqual(gig.afterGigNotes, "Killed with the closer.")
        XCTAssertEqual(gig.displayAfterGigNotes, "Killed with the closer.")
    }
}
