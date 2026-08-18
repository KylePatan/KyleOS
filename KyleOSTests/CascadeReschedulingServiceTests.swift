import XCTest
import SwiftData
@testable import KyleOS

final class CascadeReschedulingServiceTests: XCTestCase {
    private typealias Project = ProjectService.Project

    private func makeWorkItem(priority: Int, in project: Project, context: ModelContext) throws -> WorkItemService.WorkItem {
        try WorkItemService.createWorkItem(
            title: "Item priority \(priority)", workspace: .writing, workTypeName: "Outline", in: project, priority: priority, context: context
        )
    }

    func testOverflowPushesTheLowerScoringSessionToTheNextDay() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 2, weekendHours: 2, standUpNightBonusHours: 0)

        let highPriority = try makeWorkItem(priority: 5, in: project, context: context)
        let lowPriority = try makeWorkItem(priority: 1, in: project, context: context)
        let today = Date()
        let highSession = PlannedSessionService.schedule(for: highPriority, at: today, durationMinutes: 90, context: context)
        let lowSession = PlannedSessionService.schedule(for: lowPriority, at: today, durationMinutes: 90, context: context)
        try context.save()

        let result = CascadeReschedulingService.reflow(
            startingFrom: today, settings: settings, calendarEvents: [], capacityOverrides: [],
            allSessions: [highSession, lowSession]
        )

        XCTAssertTrue(Calendar.current.isDate(highSession.scheduledAt, inSameDayAs: today), "The higher-scoring session should keep its day")
        XCTAssertFalse(Calendar.current.isDate(lowSession.scheduledAt, inSameDayAs: today), "The lower-scoring session should be pushed off")
        XCTAssertEqual(result.moves.count, 1)
        XCTAssertEqual(result.moves.first?.session.id, lowSession.id)
    }

    /// Confirms the 2026-08-18 Creative Capacity fix (Personal/Time-Off events reduce baseline)
    /// actually reaches cascade rescheduling, not just `CreativeCapacityService`'s own tests —
    /// this file's own doc comment used to explicitly call that gap out as one of the deferred
    /// cases; it isn't anymore since this calls `todaysCapacity` directly.
    func testBusyPersonalEventReducesCascadeCapacityAndPushesASession() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 2, weekendHours: 2, standUpNightBonusHours: 0)

        let workItem = try makeWorkItem(priority: 3, in: project, context: context)
        let today = Date()
        let session = PlannedSessionService.schedule(for: workItem, at: today, durationMinutes: 90, context: context)
        try context.save()

        // A 2-hour personal event today leaves only 0h of the 2h baseline for a 90-minute session.
        let personalEvent = CalendarEventService.createEvent(
            type: .personal, startAt: today, endAt: today.addingTimeInterval(3600 * 2), context: context
        )

        let result = CascadeReschedulingService.reflow(
            startingFrom: today, settings: settings, calendarEvents: [personalEvent], capacityOverrides: [],
            allSessions: [session]
        )

        XCTAssertFalse(Calendar.current.isDate(session.scheduledAt, inSameDayAs: today), "No capacity left today once the personal event is subtracted")
        XCTAssertEqual(result.moves.count, 1)
    }

    func testLockedSessionsNeverMoveButStillCountAgainstCapacity() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 1, weekendHours: 1, standUpNightBonusHours: 0)

        let lockedItem = try makeWorkItem(priority: 3, in: project, context: context)
        let movableItem = try makeWorkItem(priority: 3, in: project, context: context)
        let today = Date()
        let lockedSession = PlannedSessionService.schedule(for: lockedItem, at: today, durationMinutes: 45, context: context)
        PlannedSessionService.setLocked(lockedSession, true)
        let movableSession = PlannedSessionService.schedule(for: movableItem, at: today, durationMinutes: 45, context: context)
        try context.save()

        let originalLockedDate = lockedSession.scheduledAt
        let result = CascadeReschedulingService.reflow(
            startingFrom: today, settings: settings, calendarEvents: [], capacityOverrides: [],
            allSessions: [lockedSession, movableSession]
        )

        XCTAssertEqual(lockedSession.scheduledAt, originalLockedDate, "A locked session must never move")
        XCTAssertFalse(Calendar.current.isDate(movableSession.scheduledAt, inSameDayAs: today), "60m capacity minus the locked 45m leaves only 15m — too little for the movable 45m session")
        XCTAssertEqual(result.unresolved.count, 0)
    }

    func testSessionsThatAlreadyFitDoNotMove() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 2, weekendHours: 2, standUpNightBonusHours: 0)

        let item = try makeWorkItem(priority: 3, in: project, context: context)
        let today = Date()
        let session = PlannedSessionService.schedule(for: item, at: today, durationMinutes: 60, context: context)
        try context.save()
        let originalDate = session.scheduledAt

        let result = CascadeReschedulingService.reflow(
            startingFrom: today, settings: settings, calendarEvents: [], capacityOverrides: [],
            allSessions: [session]
        )

        XCTAssertTrue(result.moves.isEmpty, "Nothing overflowed, so nothing should be touched")
        XCTAssertEqual(session.scheduledAt, originalDate)
    }

    func testASessionThatFitsNowhereWithinTheLookaheadWindowIsUnresolvedNotDropped() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 0, weekendHours: 0, standUpNightBonusHours: 0)

        let item = try makeWorkItem(priority: 3, in: project, context: context)
        let today = Date()
        let session = PlannedSessionService.schedule(for: item, at: today, durationMinutes: 30, context: context)
        try context.save()

        let result = CascadeReschedulingService.reflow(
            startingFrom: today, lookaheadDays: 3, settings: settings, calendarEvents: [], capacityOverrides: [],
            allSessions: [session]
        )

        XCTAssertEqual(result.unresolved.map(\.id), [session.id])
        XCTAssertNotNil(try context.fetch(FetchDescriptor<PlannedSessionService.PlannedSession>()).first { $0.id == session.id }, "Unresolved must mean flagged, not deleted")
    }

    func testOverflowCascadesForwardWhenTheNextDayIsAlsoFull() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 1, weekendHours: 1, standUpNightBonusHours: 0)

        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let itemA = try makeWorkItem(priority: 5, in: project, context: context)
        let itemB = try makeWorkItem(priority: 1, in: project, context: context)
        let itemC = try makeWorkItem(priority: 4, in: project, context: context)

        let sessionA = PlannedSessionService.schedule(for: itemA, at: today, durationMinutes: 60, context: context)
        let sessionB = PlannedSessionService.schedule(for: itemB, at: today, durationMinutes: 60, context: context)
        let sessionC = PlannedSessionService.schedule(for: itemC, at: tomorrow, durationMinutes: 60, context: context)
        try context.save()

        let result = CascadeReschedulingService.reflow(
            startingFrom: today, settings: settings, calendarEvents: [], capacityOverrides: [],
            allSessions: [sessionA, sessionB, sessionC]
        )

        XCTAssertTrue(calendar.isDate(sessionA.scheduledAt, inSameDayAs: today))
        XCTAssertTrue(calendar.isDate(sessionC.scheduledAt, inSameDayAs: tomorrow), "C was already there first and outranks B")
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today)!
        XCTAssertTrue(calendar.isDate(sessionB.scheduledAt, inSameDayAs: dayAfterTomorrow), "B keeps getting pushed until it finds real room")
        XCTAssertEqual(result.moves.count, 1)
    }

    func testLoweringACapacityOverrideTriggersOverflowOnThatDay() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 3, weekendHours: 3, standUpNightBonusHours: 0)

        let item = try makeWorkItem(priority: 3, in: project, context: context)
        let today = Date()
        let session = PlannedSessionService.schedule(for: item, at: today, durationMinutes: 90, context: context)
        try context.save()

        let override = try CreativeCapacityService.setOverride(for: today, hours: 0.5, context: context)
        try context.save()

        let result = CascadeReschedulingService.reflow(
            startingFrom: today, settings: settings, calendarEvents: [], capacityOverrides: [override],
            allSessions: [session]
        )

        XCTAssertFalse(Calendar.current.isDate(session.scheduledAt, inSameDayAs: today))
        XCTAssertEqual(result.moves.count, 1)
    }
}
