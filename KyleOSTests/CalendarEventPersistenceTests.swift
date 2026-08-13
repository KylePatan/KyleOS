import XCTest
import SwiftData
@testable import KyleOS

final class CalendarEventPersistenceTests: XCTestCase {

    func testCreatingAnEventPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let start = Date()
        let end = start.addingTimeInterval(45 * 60)
        let event = CalendarEventService.createEvent(
            type: .creativeWorkSession, startAt: start, endAt: end, context: context
        )
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<KyleOSSchemaV17.CalendarEvent>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, event.id)
        XCTAssertEqual(fetched.first?.availability, .busy)
    }

    /// Acceptance criterion "Calendar Events persist with Busy/Available state" — the prior test
    /// only proves the default (.busy); this proves the other V1 availability type (PRD §11.5)
    /// is genuinely settable and persists, not just present as an unused enum case.
    func testAvailabilityCanBeSetToAvailableAndPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let start = Date()
        let event = CalendarEventService.createEvent(
            type: .personal, startAt: start, endAt: start.addingTimeInterval(3600), availability: .available, context: context
        )
        try context.save()
        XCTAssertEqual(event.availability, .available)

        CalendarEventService.setAvailability(event, to: .busy)
        try context.save()
        XCTAssertEqual(event.availability, .busy)

        let fetched = try context.fetch(FetchDescriptor<KyleOSSchemaV17.CalendarEvent>())
        XCTAssertEqual(fetched.first?.availability, .busy)
    }

    func testDayJobDefaultsMatchSettings() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let settings = try SettingsService.currentSettings(in: context)
        XCTAssertEqual(settings.dayJobStartHour, 8)
        XCTAssertEqual(settings.dayJobEndHour, 17)

        // A Day Job calendar event should be able to represent that exact PRD §11.4 default.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(bySettingHour: settings.dayJobStartHour, minute: 0, second: 0, of: today)!
        let end = calendar.date(bySettingHour: settings.dayJobEndHour, minute: 0, second: 0, of: today)!

        let event = CalendarEventService.createEvent(
            type: .dayJob, startAt: start, endAt: end, availability: .busy, isHardCommitment: true, context: context
        )
        try context.save()

        XCTAssertEqual(event.eventType, .dayJob)
        XCTAssertTrue(event.isHardCommitment)
    }

    func testLockedEventCannotBeRescheduled() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let start = Date()
        let end = start.addingTimeInterval(3600)
        let event = CalendarEventService.createEvent(type: .standUpGig, startAt: start, endAt: end, context: context)
        CalendarEventService.setLocked(event, true)
        try context.save()

        let newStart = start.addingTimeInterval(3600)
        let newEnd = end.addingTimeInterval(3600)
        CalendarEventService.reschedule(event, startAt: newStart, endAt: newEnd)

        XCTAssertEqual(event.startAt, start, "A locked event must not move")
    }

    func testUnlockedEventCanBeRescheduled() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let start = Date()
        let end = start.addingTimeInterval(3600)
        let event = CalendarEventService.createEvent(type: .personal, startAt: start, endAt: end, context: context)
        try context.save()

        let newStart = start.addingTimeInterval(7200)
        let newEnd = end.addingTimeInterval(7200)
        CalendarEventService.reschedule(event, startAt: newStart, endAt: newEnd)

        XCTAssertEqual(event.startAt, newStart)
        XCTAssertEqual(event.endAt, newEnd)
    }

    func testEventsInRangeFiltersCorrectly() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86400)
        let day3 = day1.addingTimeInterval(86400 * 2)

        CalendarEventService.createEvent(type: .personal, startAt: day1, endAt: day1.addingTimeInterval(3600), context: context)
        CalendarEventService.createEvent(type: .personal, startAt: day2, endAt: day2.addingTimeInterval(3600), context: context)
        CalendarEventService.createEvent(type: .personal, startAt: day3, endAt: day3.addingTimeInterval(3600), context: context)
        try context.save()

        let inRange = try CalendarEventService.events(from: day1, to: day2.addingTimeInterval(1), in: context)
        XCTAssertEqual(inRange.count, 2)
    }

    func testDeletingLinkedProjectNullifiesRatherThanDeletingTheEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let start = Date()
        let event = CalendarEventService.createEvent(
            type: .creativeWorkSession, startAt: start, endAt: start.addingTimeInterval(2700), project: project, context: context
        )
        try context.save()

        context.delete(project)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<KyleOSSchemaV17.CalendarEvent>())
        XCTAssertEqual(remaining.count, 1, "A Calendar Event must survive its linked Project being deleted")
        XCTAssertEqual(remaining.first?.id, event.id)
        XCTAssertNil(remaining.first?.project, "The link should be nullified, not left dangling")
    }

    func testDataSurvivesReopeningTheStore() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSCalendarEventRestartTest-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let eventID: UUID
        let start = Date()
        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let event = CalendarEventService.createEvent(
                type: .filmShoot, startAt: start, endAt: start.addingTimeInterval(3600 * 8), notes: "Location TBD", context: context
            )
            eventID = event.id
            try context.save()
        }

        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let events = try context.fetch(FetchDescriptor<KyleOSSchemaV17.CalendarEvent>())
            XCTAssertEqual(events.count, 1)
            XCTAssertEqual(events.first?.id, eventID)
            XCTAssertEqual(events.first?.notes, "Location TBD")
            XCTAssertEqual(events.first?.eventType, .filmShoot)
        }
    }
}
