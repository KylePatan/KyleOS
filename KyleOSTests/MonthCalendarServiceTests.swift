import XCTest
import SwiftData
@testable import KyleOS

final class MonthCalendarServiceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }

    func testGridIsAlwaysAWholeNumberOfWeeks() throws {
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11))!
        let cells = MonthCalendarService.grid(for: date, calendar: calendar)

        XCTAssertEqual(cells.count % 7, 0)
        XCTAssertFalse(cells.isEmpty)
    }

    func testGridEveryRowStartsOnTheCalendarsFirstWeekday() throws {
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11))!
        let cells = MonthCalendarService.grid(for: date, calendar: calendar)

        for (index, cell) in cells.enumerated() where index % 7 == 0 {
            XCTAssertEqual(calendar.component(.weekday, from: cell.date), calendar.firstWeekday)
        }
    }

    func testGridCurrentMonthCellCountMatchesActualDaysInMonth() throws {
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11))!
        let cells = MonthCalendarService.grid(for: date, calendar: calendar)
        let expectedDaysInMonth = calendar.range(of: .day, in: .month, for: date)!.count

        XCTAssertEqual(cells.filter(\.isInCurrentMonth).count, expectedDaysInMonth)
    }

    func testGridIncludesTheFirstAndLastDayOfTheMonth() throws {
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11))!
        let monthInterval = calendar.dateInterval(of: .month, for: date)!
        let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end)!
        let cells = MonthCalendarService.grid(for: date, calendar: calendar)

        XCTAssertTrue(cells.contains { calendar.isDate($0.date, inSameDayAs: monthInterval.start) && $0.isInCurrentMonth })
        XCTAssertTrue(cells.contains { calendar.isDate($0.date, inSameDayAs: lastDayOfMonth) && $0.isInCurrentMonth })
    }

    func testGridForAMonthThatStartsOnTheFirstWeekdayHasNoLeadingPaddingDays() throws {
        // February 2026 starts on a Sunday (UTC, Gregorian) — a month with zero leading padding.
        let date = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        XCTAssertEqual(calendar.component(.weekday, from: date), calendar.firstWeekday, "Test assumption")

        let cells = MonthCalendarService.grid(for: date, calendar: calendar)
        XCTAssertTrue(cells.first!.isInCurrentMonth)
    }

    func testEventsOnFiltersToOnlyThatDayAndSortsByStartTime() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11))!
        let otherDay = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!

        let late = CalendarEventService.createEvent(
            type: .creativeWorkSession,
            startAt: calendar.date(byAdding: .hour, value: 18, to: day)!,
            endAt: calendar.date(byAdding: .hour, value: 19, to: day)!,
            context: context
        )
        let early = CalendarEventService.createEvent(
            type: .creativeWorkSession,
            startAt: calendar.date(byAdding: .hour, value: 9, to: day)!,
            endAt: calendar.date(byAdding: .hour, value: 10, to: day)!,
            context: context
        )
        _ = CalendarEventService.createEvent(
            type: .creativeWorkSession,
            startAt: calendar.date(byAdding: .hour, value: 9, to: otherDay)!,
            endAt: calendar.date(byAdding: .hour, value: 10, to: otherDay)!,
            context: context
        )

        let result = MonthCalendarService.events(on: day, from: [late, early], calendar: calendar)

        XCTAssertEqual(result.map(\.id), [early.id, late.id])
    }

    func testEventsOnReturnsEmptyWhenNothingMatchesTheDay() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11))!
        let otherDay = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!

        let event = CalendarEventService.createEvent(
            type: .personal, startAt: otherDay, endAt: otherDay.addingTimeInterval(3600), context: context
        )

        XCTAssertTrue(MonthCalendarService.events(on: day, from: [event], calendar: calendar).isEmpty)
    }
}
