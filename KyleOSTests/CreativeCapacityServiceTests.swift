import XCTest
import SwiftData
@testable import KyleOS

final class CreativeCapacityServiceTests: XCTestCase {
    /// 2026-09-02, real failure: several tests here construct event spans up to 8 hours from
    /// `now` (`now.addingTimeInterval(3600 * N)`). Using the live wall-clock `Date()` directly
    /// meant a test run late enough in the evening had that span cross midnight, silently
    /// truncating how much of it counts toward "today" — `CreativeCapacityService.
    /// personalEventReductionHours` correctly clips each event to `[startOfDay, endOfDay)`, so a
    /// 2-hour personal event starting at 10:29 PM only reduced the baseline by ~1.5 hours, not 2 —
    /// a real, reproducible failure (confirmed via an immediate rerun, not a flake) this exact
    /// bug caused, not a bug in the production code being tested. Keeps the real calendar date
    /// (weekday/weekend-sensitive tests still exercise whatever day the suite actually runs on)
    /// but pins the time-of-day to a safe mid-morning hour, removing the midnight-crossing risk
    /// for every span used in this file.
    private static var now: Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    }

    func testBaselineWithNoGigOrScheduledSessionsMatchesSettings() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [], plannedSessions: [])

        XCTAssertEqual(summary.baselineHours, 2.5, "Matches AppSettings' default weekday Creative Capacity")
        XCTAssertEqual(summary.scheduledHours, 0)
        XCTAssertEqual(summary.remainingHours, 2.5)
    }

    func testStandUpGigTodayReducesBaselineByTheNightReductionHours() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let now = Self.now

        let gigEvent = CalendarEventService.createEvent(
            type: .standUpGig, startAt: now, endAt: now.addingTimeInterval(3600), context: context
        )

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [gigEvent], plannedSessions: [], now: now)

        XCTAssertEqual(summary.baselineHours, 1.5, "2.5h baseline - 1h stand-up night reduction, per §7.8")
    }

    func testGigOnADifferentDayDoesNotReduceBaseline() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let now = Self.now
        let tomorrow = Date(timeIntervalSinceNow: 86400)

        let gigEvent = CalendarEventService.createEvent(
            type: .standUpGig, startAt: tomorrow, endAt: tomorrow.addingTimeInterval(3600), context: context
        )

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [gigEvent], plannedSessions: [], now: now)

        XCTAssertEqual(summary.baselineHours, 2.5)
    }

    func testBaselineNeverGoesNegativeWhenTheReductionExceedsIt() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 0.5, weekendHours: 0.5, standUpNightBonusHours: 1.0)
        let now = Self.now

        let gigEvent = CalendarEventService.createEvent(
            type: .standUpGig, startAt: now, endAt: now.addingTimeInterval(3600), context: context
        )

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [gigEvent], plannedSessions: [], now: now)

        XCTAssertEqual(summary.baselineHours, 0)
    }

    func testScheduledPlannedSessionsTodayReduceRemaining() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Self.now

        let session = PlannedSessionService.schedule(for: workItem, at: now, durationMinutes: 45, context: context)

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [], plannedSessions: [session], now: now)

        XCTAssertEqual(summary.scheduledHours, 0.75, accuracy: 0.001)
        XCTAssertEqual(summary.remainingHours, 2.5 - 0.75, accuracy: 0.001)
    }

    func testOnlyScheduledStatusSessionsCountNotMissedOrCancelled() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Self.now

        let missed = PlannedSessionService.schedule(for: workItem, at: now, durationMinutes: 45, context: context)
        PlannedSessionService.markMissed(missed)
        let cancelled = PlannedSessionService.schedule(for: workItem, at: now, durationMinutes: 30, context: context)
        PlannedSessionService.markCancelled(cancelled)
        let stillScheduled = PlannedSessionService.schedule(for: workItem, at: now, durationMinutes: 15, context: context)

        let summary = CreativeCapacityService.todaysCapacity(
            settings: settings, events: [], plannedSessions: [missed, cancelled, stillScheduled], now: now
        )

        XCTAssertEqual(summary.scheduledHours, 0.25, accuracy: 0.001, "Only the still-Scheduled 15m session should count")
    }

    func testSessionsScheduledOnOtherDaysDontCount() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Self.now
        let tomorrow = Date(timeIntervalSinceNow: 86400)

        let session = PlannedSessionService.schedule(for: workItem, at: tomorrow, durationMinutes: 45, context: context)

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [], plannedSessions: [session], now: now)

        XCTAssertEqual(summary.scheduledHours, 0)
    }

    func testOverrideForTodayReplacesTheBaselineEntirely() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let now = Self.now

        let gigEvent = CalendarEventService.createEvent(
            type: .standUpGig, startAt: now, endAt: now.addingTimeInterval(3600), context: context
        )
        let override = try CreativeCapacityService.setOverride(for: now, hours: 6, context: context)
        try context.save()

        let summary = CreativeCapacityService.todaysCapacity(
            settings: settings, events: [gigEvent], plannedSessions: [], overrides: [override], now: now
        )

        XCTAssertEqual(summary.baselineHours, 6, "The override replaces the baseline, bypassing the gig-night reduction entirely")
        XCTAssertTrue(summary.isOverridden)
    }

    func testOverrideOnADifferentDayDoesNotApply() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let now = Self.now
        let tomorrow = Date(timeIntervalSinceNow: 86400)

        let override = try CreativeCapacityService.setOverride(for: tomorrow, hours: 6, context: context)
        try context.save()

        let summary = CreativeCapacityService.todaysCapacity(
            settings: settings, events: [], plannedSessions: [], overrides: [override], now: now
        )

        XCTAssertEqual(summary.baselineHours, 2.5)
        XCTAssertFalse(summary.isOverridden)
    }

    func testSetOverrideTwiceUpdatesRatherThanDuplicates() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let now = Self.now

        let first = try CreativeCapacityService.setOverride(for: now, hours: 4, context: context)
        try context.save()
        let second = try CreativeCapacityService.setOverride(for: now, hours: 8, context: context)
        try context.save()

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.hours, 8)

        let fetched = try context.fetch(FetchDescriptor<CreativeCapacityService.CapacityOverride>())
        XCTAssertEqual(fetched.count, 1, "A second setOverride call must update, not create a duplicate")
    }

    func testSetOverrideClampsNegativeHoursToZero() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let now = Self.now

        let override = try CreativeCapacityService.setOverride(for: now, hours: -3, context: context)
        try context.save()

        XCTAssertEqual(override.hours, 0)
    }

    func testClearOverrideRestoresNormalCalculation() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let now = Self.now

        try CreativeCapacityService.setOverride(for: now, hours: 10, context: context)
        try context.save()
        try CreativeCapacityService.clearOverride(for: now, context: context)
        try context.save()

        XCTAssertNil(try CreativeCapacityService.override(for: now, in: context))

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [], plannedSessions: [], overrides: [], now: now)
        XCTAssertEqual(summary.baselineHours, 2.5)
        XCTAssertFalse(summary.isOverridden)
    }

    /// Kyle (2026-08-17): "if there's a weekday capacity there should be an option for a weekend
    /// capacity." Uses `nextDate(after:matching:)` for a guaranteed Saturday/Sunday/Tuesday
    /// rather than depending on whatever day the test happens to run on.
    func testWeekendUsesWeekendCapacityHoursNotWeekday() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 2.5, weekendHours: 5.0, standUpNightBonusHours: 1.0)
        let calendar = Calendar.current
        let saturday = calendar.nextDate(after: .now, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime, direction: .forward)!

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [], plannedSessions: [], now: saturday)

        XCTAssertEqual(summary.baselineHours, 5.0)
    }

    func testSundayAlsoUsesWeekendCapacityHours() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 2.5, weekendHours: 5.0, standUpNightBonusHours: 1.0)
        let calendar = Calendar.current
        let sunday = calendar.nextDate(after: .now, matching: DateComponents(weekday: 1), matchingPolicy: .nextTime, direction: .forward)!

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [], plannedSessions: [], now: sunday)

        XCTAssertEqual(summary.baselineHours, 5.0)
    }

    func testWeekdayStillUsesWeekdayCapacityHoursWithWeekendSet() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updateCreativeCapacity(settings, weekdayHours: 2.5, weekendHours: 5.0, standUpNightBonusHours: 1.0)
        let calendar = Calendar.current
        let tuesday = calendar.nextDate(after: .now, matching: DateComponents(weekday: 3), matchingPolicy: .nextTime, direction: .forward)!

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [], plannedSessions: [], now: tuesday)

        XCTAssertEqual(summary.baselineHours, 2.5)
    }

    /// Pre-migration rows have `weekendCreativeCapacityHours == nil` — `displayWeekendCreativeCapacityHours`
    /// falls back to the weekday value so existing users see an unchanged weekend baseline until
    /// they explicitly set one (the V8-lesson-safe pattern, same as `displayPostsPerWeekTarget`).
    /// PRD §4.4: "Personal calendar events and all-day time-off events reduce available capacity."
    /// A known gap until 2026-08-18 — only Gigs and manual overrides reduced the baseline before.
    func testPersonalEventTodayReducesBaselineByItsDuration() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let now = Self.now

        let personalEvent = CalendarEventService.createEvent(
            type: .personal, startAt: now, endAt: now.addingTimeInterval(3600 * 2), context: context
        )

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [personalEvent], plannedSessions: [], now: now)

        XCTAssertEqual(summary.baselineHours, 0.5, accuracy: 0.01, "2.5h baseline - 2h personal event")
    }

    func testAllDayTimeOffEventZeroesTheBaseline() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let calendar = Calendar.current
        let now = Self.now
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let timeOff = CalendarEventService.createEvent(
            type: .unavailableTimeOff, startAt: startOfDay, endAt: endOfDay, isAllDay: true, context: context
        )

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [timeOff], plannedSessions: [], now: now)

        XCTAssertEqual(summary.baselineHours, 0)
    }

    func testAvailableMarkedPersonalEventDoesNotReduceCapacity() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let now = Self.now

        let looseReminder = CalendarEventService.createEvent(
            type: .personal, startAt: now, endAt: now.addingTimeInterval(3600 * 2), availability: .available, context: context
        )

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [looseReminder], plannedSessions: [], now: now)

        XCTAssertEqual(summary.baselineHours, 2.5, "An .available event doesn't actually block time")
    }

    func testPersonalEventOnADifferentDayDoesNotReduceCapacity() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let now = Self.now
        let tomorrow = Date(timeIntervalSinceNow: 86400)

        let personalEvent = CalendarEventService.createEvent(
            type: .personal, startAt: tomorrow, endAt: tomorrow.addingTimeInterval(3600 * 2), context: context
        )

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [personalEvent], plannedSessions: [], now: now)

        XCTAssertEqual(summary.baselineHours, 2.5)
    }

    func testDayJobAndCreativeWorkSessionEventsDoNotReduceCapacity() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let now = Self.now

        let dayJob = CalendarEventService.createEvent(type: .dayJob, startAt: now, endAt: now.addingTimeInterval(3600 * 8), context: context)
        let workSession = CalendarEventService.createEvent(type: .creativeWorkSession, startAt: now, endAt: now.addingTimeInterval(3600), context: context)

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [dayJob, workSession], plannedSessions: [], now: now)

        XCTAssertEqual(summary.baselineHours, 2.5, "Day Job is already baked into the baseline itself; Creative Work Session isn't a capacity-reducing type")
    }

    func testPersonalEventReductionCombinesWithGigNightReduction() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let now = Self.now

        let gigEvent = CalendarEventService.createEvent(type: .standUpGig, startAt: now, endAt: now.addingTimeInterval(3600), context: context)
        let personalEvent = CalendarEventService.createEvent(
            type: .personal, startAt: now, endAt: now.addingTimeInterval(3600), context: context
        )

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [gigEvent, personalEvent], plannedSessions: [], now: now)

        XCTAssertEqual(summary.baselineHours, 0.5, accuracy: 0.01, "2.5h - 1h gig-night reduction - 1h personal event")
    }

    func testWeekendFallsBackToWeekdayHoursWhenNeverSet() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let calendar = Calendar.current
        let saturday = calendar.nextDate(after: .now, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime, direction: .forward)!

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [], plannedSessions: [], now: saturday)

        XCTAssertEqual(summary.baselineHours, 2.5, "Falls back to the default weekday value since weekendCreativeCapacityHours was never set")
    }

    func testRemainingNeverGoesNegative() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Self.now

        let overbooked = PlannedSessionService.schedule(for: workItem, at: now, durationMinutes: 600, context: context)

        let summary = CreativeCapacityService.todaysCapacity(settings: settings, events: [], plannedSessions: [overbooked], now: now)

        XCTAssertEqual(summary.remainingHours, 0)
    }
}
