import XCTest
import SwiftData
@testable import KyleOS

final class ReportServiceTests: XCTestCase {

    // MARK: - interval(for:)

    func testThisWeekAndLastWeekAreConsecutiveNonOverlappingWeeks() {
        let now = Date()
        let calendar = Calendar.current
        let thisWeek = ReportService.interval(for: .thisWeek, calendar: calendar, now: now)
        let lastWeek = ReportService.interval(for: .lastWeek, calendar: calendar, now: now)

        XCTAssertEqual(lastWeek.end.timeIntervalSince1970, thisWeek.start.timeIntervalSince1970, accuracy: 1)
    }

    func testThisMonthAndLastMonthAreConsecutiveNonOverlappingMonths() {
        let now = Date()
        let calendar = Calendar.current
        let thisMonth = ReportService.interval(for: .thisMonth, calendar: calendar, now: now)
        let lastMonth = ReportService.interval(for: .lastMonth, calendar: calendar, now: now)

        XCTAssertEqual(lastMonth.end.timeIntervalSince1970, thisMonth.start.timeIntervalSince1970, accuracy: 1)
    }

    func testCustomRangeNormalizesReversedStartAndEnd() {
        let earlier = Date(timeIntervalSinceNow: -86400)
        let later = Date(timeIntervalSinceNow: 86400)
        let interval = ReportService.interval(for: .custom, customStart: later, customEnd: earlier)

        XCTAssertEqual(interval.start.timeIntervalSince1970, earlier.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(interval.end.timeIntervalSince1970, later.timeIntervalSince1970, accuracy: 1)
    }

    // MARK: - summary(in:context:)

    func testSummaryCountsSessionsAndTotalTimeWithinRange() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Date()
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(1800),
            activeDurationSeconds: 1800, progressBefore: 0, progressAfter: 20, entryType: .timer, context: context
        )
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(900),
            activeDurationSeconds: 900, progressBefore: 20, progressAfter: 30, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let summary = try ReportService.summary(in: interval, context: context)

        XCTAssertEqual(summary.sessionCount, 2)
        XCTAssertEqual(summary.totalCreativeSeconds, 2700)
        XCTAssertEqual(summary.projectsWorkedOnCount, 1)
    }

    func testSummaryExcludesSessionsOutsideRange() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let farPast = Date(timeIntervalSinceNow: -86400 * 30)
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: farPast, endAt: farPast.addingTimeInterval(1800),
            activeDurationSeconds: 1800, progressBefore: 0, progressAfter: 20, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let summary = try ReportService.summary(in: interval, context: context)

        XCTAssertEqual(summary.sessionCount, 0)
        XCTAssertEqual(summary.totalCreativeSeconds, 0)
    }

    func testProjectsWorkedOnCountsDistinctProjectsNotSessions() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Date()
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(600),
            activeDurationSeconds: 600, progressBefore: 0, progressAfter: 10, entryType: .timer, context: context
        )
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(600),
            activeDurationSeconds: 600, progressBefore: 10, progressAfter: 20, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let summary = try ReportService.summary(in: interval, context: context)

        XCTAssertEqual(summary.sessionCount, 2)
        XCTAssertEqual(summary.projectsWorkedOnCount, 1, "Two sessions against the same Project must count once")
    }

    func testSummaryDoesNotCountStandUpWorkAsAProject() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        try context.save()
        let workItem = try WorkItemService.standUpWorkItem(for: joke, context: context)
        let now = Date()
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(600),
            activeDurationSeconds: 600, progressBefore: 0, progressAfter: 0, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let summary = try ReportService.summary(in: interval, context: context)

        XCTAssertEqual(summary.sessionCount, 1, "Stand-Up time still counts toward total time/sessions")
        XCTAssertEqual(summary.projectsWorkedOnCount, 0, "Stand-Up material has no Project, so it's excluded from this specific count")
    }

    func testSummaryCountsCompletedItemsWithinRange() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        WorkItemService.complete(workItem)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let summary = try ReportService.summary(in: interval, context: context)

        XCTAssertEqual(summary.completedItemsCount, 1)
    }

    func testSummaryCountsContentPostedWithinRange() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        ClipService.changeStatus(clip, to: .ready)
        try context.save()
        let item = PostingItemService.findOrCreate(for: clip, context: context)
        PostingItemService.markPosted(item, context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let summary = try ReportService.summary(in: interval, context: context)

        XCTAssertEqual(summary.contentPostedCount, 1)
    }

    // MARK: - workspaceBreakdown(in:context:)

    func testWorkspaceBreakdownAlwaysReturnsAllFourWorkspacesZeroFilled() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let breakdown = try ReportService.workspaceBreakdown(in: interval, context: context)

        XCTAssertEqual(breakdown.count, 4)
        XCTAssertTrue(breakdown.allSatisfy { $0.seconds == 0 })
    }

    func testWorkspaceBreakdownSumsTimePerWorkspace() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let writingItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        try context.save()
        let standUpItem = try WorkItemService.standUpWorkItem(for: joke, context: context)

        let now = Date()
        WorkSessionService.logCompletedSession(
            for: writingItem, startAt: now, endAt: now.addingTimeInterval(1200),
            activeDurationSeconds: 1200, progressBefore: 0, progressAfter: 10, entryType: .timer, context: context
        )
        WorkSessionService.logCompletedSession(
            for: standUpItem, startAt: now, endAt: now.addingTimeInterval(600),
            activeDurationSeconds: 600, progressBefore: 0, progressAfter: 0, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let breakdown = try ReportService.workspaceBreakdown(in: interval, context: context)

        XCTAssertEqual(breakdown.first { $0.workspace == .writing }?.seconds, 1200)
        XCTAssertEqual(breakdown.first { $0.workspace == .standUp }?.seconds, 600)
        XCTAssertEqual(breakdown.first { $0.workspace == .clips }?.seconds, 0)
        XCTAssertEqual(breakdown.first { $0.workspace == .sketches }?.seconds, 0)
    }
}
