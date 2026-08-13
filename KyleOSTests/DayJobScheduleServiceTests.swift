import XCTest
import SwiftData
@testable import KyleOS

final class DayJobScheduleServiceTests: XCTestCase {

    /// The upcoming (or current) Monday in local time — computed via `Calendar.current` like the
    /// service itself, so there's no UTC-vs-local mismatch shifting which weekday a fixed
    /// timestamp actually lands on depending on where this runs.
    private func mondayAt(_ hour: Int = 0) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilMonday = (2 - weekday + 7) % 7
        let monday = calendar.date(byAdding: .day, value: daysUntilMonday, to: today)!
        return calendar.date(byAdding: .hour, value: hour, to: monday)!
    }

    func testEnsureBlocksCreatesADayJobEventForEachConfiguredWeekday() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        try SettingsService.currentSettings(in: context)
        try context.save()

        let start = mondayAt()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        try DayJobScheduleService.ensureBlocks(from: start, to: end, context: context)
        try context.save()

        let events = try CalendarEventService.events(from: start, to: end, in: context)
        let dayJobEvents = events.filter { $0.eventType == .dayJob }
        // Default settings: Mon-Fri (weekdays 2-6) blocked.
        XCTAssertEqual(dayJobEvents.count, 5)
        XCTAssertTrue(dayJobEvents.allSatisfy(\.isHardCommitment))
    }

    func testEnsureBlocksIsIdempotent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        try SettingsService.currentSettings(in: context)
        try context.save()

        let start = mondayAt()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        try DayJobScheduleService.ensureBlocks(from: start, to: end, context: context)
        try DayJobScheduleService.ensureBlocks(from: start, to: end, context: context)
        try context.save()

        let events = try CalendarEventService.events(from: start, to: end, in: context)
        XCTAssertEqual(events.filter { $0.eventType == .dayJob }.count, 5, "Calling ensureBlocks twice must not create duplicates")
    }

    func testMarkDayOffRemovesTheBlockAndPreventsRegeneration() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        try SettingsService.currentSettings(in: context)
        try context.save()

        let monday = mondayAt()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: monday)!
        try DayJobScheduleService.ensureBlocks(from: monday, to: end, context: context)
        try context.save()
        XCTAssertEqual(try CalendarEventService.events(from: monday, to: end, in: context).filter { $0.eventType == .dayJob }.count, 5)

        try DayJobScheduleService.markDayOff(monday, context: context)
        try context.save()

        let afterMarkOff = try CalendarEventService.events(from: monday, to: end, in: context).filter { $0.eventType == .dayJob }
        XCTAssertEqual(afterMarkOff.count, 4, "Marking Monday off should remove exactly its own block")

        // Re-running ensureBlocks over the same range must not resurrect the removed Monday block.
        try DayJobScheduleService.ensureBlocks(from: monday, to: end, context: context)
        try context.save()
        let afterReensure = try CalendarEventService.events(from: monday, to: end, in: context).filter { $0.eventType == .dayJob }
        XCTAssertEqual(afterReensure.count, 4, "A marked-off day must not regenerate")
    }

    func testManuallyAddingAnEventOnAMarkedOffDayIsNotOverwritten() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        try SettingsService.currentSettings(in: context)
        try context.save()

        let monday = mondayAt()
        let end = Calendar.current.date(byAdding: .day, value: 1, to: monday)!
        try DayJobScheduleService.ensureBlocks(from: monday, to: end, context: context)
        try context.save()
        try DayJobScheduleService.markDayOff(monday, context: context)
        try context.save()

        let manualEvent = CalendarEventService.createEvent(
            type: .dayJob, startAt: mondayAt(9), endAt: mondayAt(11), context: context
        )
        try context.save()

        try DayJobScheduleService.ensureBlocks(from: monday, to: end, context: context)
        try context.save()

        let events = try CalendarEventService.events(from: monday, to: end, in: context).filter { $0.eventType == .dayJob }
        XCTAssertEqual(events.map(\.id), [manualEvent.id], "ensureBlocks must not duplicate a manually re-added event")
    }

    func testEnsureBlocksSkipsWeekendsByDefault() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        try SettingsService.currentSettings(in: context)
        try context.save()

        // Saturday the week of the fixed Monday.
        let saturday = Calendar.current.date(byAdding: .day, value: 5, to: mondayAt())!
        let sunday = Calendar.current.date(byAdding: .day, value: 1, to: saturday)!
        try DayJobScheduleService.ensureBlocks(from: saturday, to: sunday, context: context)
        try context.save()

        let events = try CalendarEventService.events(from: saturday, to: sunday, in: context)
        XCTAssertTrue(events.filter { $0.eventType == .dayJob }.isEmpty)
    }
}
