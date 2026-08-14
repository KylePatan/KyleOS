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
        WorkItemService.complete(workItem, context: context)
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
        ClipService.changeStatus(clip, to: .ready, context: context)
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

    // MARK: - plannedVsActual(in:context:)

    func testPlannedVsActualComparesBothSides() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Date()
        PlannedSessionService.schedule(for: workItem, at: now, durationMinutes: 45, context: context)
        PlannedSessionService.schedule(for: workItem, at: now, durationMinutes: 30, context: context)
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(1800),
            activeDurationSeconds: 1800, progressBefore: 0, progressAfter: 20, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let comparison = try ReportService.plannedVsActual(in: interval, context: context)

        XCTAssertEqual(comparison.plannedSessionCount, 2)
        XCTAssertEqual(comparison.plannedHours, 1.25, accuracy: 0.001, "45m + 30m = 75m = 1.25h")
        XCTAssertEqual(comparison.actualSessionCount, 1)
        XCTAssertEqual(comparison.actualHours, 0.5, accuracy: 0.001)
    }

    func testPlannedVsActualExcludesCancelledSessions() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Date()
        let cancelled = PlannedSessionService.schedule(for: workItem, at: now, durationMinutes: 45, context: context)
        PlannedSessionService.markCancelled(cancelled)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let comparison = try ReportService.plannedVsActual(in: interval, context: context)

        XCTAssertEqual(comparison.plannedSessionCount, 0, "A cancelled session was never really planned to happen")
    }

    func testPlannedVsActualStillCountsMissedSessions() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Date()
        let missed = PlannedSessionService.schedule(for: workItem, at: now, durationMinutes: 45, context: context)
        PlannedSessionService.markMissed(missed)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let comparison = try ReportService.plannedVsActual(in: interval, context: context)

        XCTAssertEqual(comparison.plannedSessionCount, 1, "A missed session was still planned — it just didn't happen")
    }

    // MARK: - estimateAccuracy(in:context:)

    func testEstimateAccuracyComparesEstimatedToActualForCompletedItems() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        try WorkTypeDefaultService.seedKnownDefaultsIfNeeded(in: context)
        try context.save()
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline pass 1", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Date()
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(7200),
            activeDurationSeconds: 7200, progressBefore: 0, progressAfter: 100, entryType: .timer, context: context
        )
        WorkItemService.complete(workItem, context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let entries = try ReportService.estimateAccuracy(in: interval, context: context)

        XCTAssertEqual(entries.count, 1)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.estimatedMinutes, 90, "PRD §5.1: Outline defaults to 1.5 creative hours = 90 minutes")
        XCTAssertEqual(entry.actualMinutes, 120)
        XCTAssertEqual(entry.varianceMinutes, 30)
    }

    func testEstimateAccuracyExcludesIncompleteWorkItems() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let entries = try ReportService.estimateAccuracy(in: interval, context: context)

        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - stalledWorkItems(notWorkedOnSince:context:)

    func testStalledWorkItemsSurfacesItemsWithNoRecentActivity() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let staleItem = try WorkItemService.createWorkItem(
            title: "Forgotten Draft", workspace: .writing, workTypeName: "Outline", in: project,
            context: context
        )
        let farPast = Date(timeIntervalSinceNow: -86400 * 30)
        WorkSessionService.logCompletedSession(
            for: staleItem, startAt: farPast, endAt: farPast.addingTimeInterval(600),
            activeDurationSeconds: 600, progressBefore: 0, progressAfter: 10, entryType: .timer, context: context
        )
        try context.save()

        let cutoff = Date(timeIntervalSinceNow: -86400 * 14)
        let stalled = try ReportService.stalledWorkItems(notWorkedOnSince: cutoff, context: context)

        XCTAssertEqual(stalled.map(\.title), ["Forgotten Draft"])
    }

    func testStalledWorkItemsExcludesRecentlyActiveItems() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let activeItem = try WorkItemService.createWorkItem(
            title: "Active Draft", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Date()
        WorkSessionService.logCompletedSession(
            for: activeItem, startAt: now, endAt: now.addingTimeInterval(600),
            activeDurationSeconds: 600, progressBefore: 0, progressAfter: 10, entryType: .timer, context: context
        )
        try context.save()

        let cutoff = Date(timeIntervalSinceNow: -86400 * 14)
        let stalled = try ReportService.stalledWorkItems(notWorkedOnSince: cutoff, context: context)

        XCTAssertTrue(stalled.isEmpty)
    }

    func testStalledWorkItemsExcludesCompletedItems() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Old Finished Thing", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        WorkItemService.complete(workItem, context: context)
        try context.save()

        let cutoff = Date(timeIntervalSinceNow: -86400 * 14)
        let stalled = try ReportService.stalledWorkItems(notWorkedOnSince: cutoff, context: context)

        XCTAssertTrue(stalled.isEmpty, "Completed items aren't 'stalled' — they're done")
    }

    func testStalledWorkItemsUsesCreationDateWhenNoSessionsExist() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        try WorkItemService.createWorkItem(
            title: "Never Started", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        // A freshly created item's own createdAt is "now," well after any 14-day-ago cutoff.
        let cutoff = Date(timeIntervalSinceNow: -86400 * 14)
        let stalled = try ReportService.stalledWorkItems(notWorkedOnSince: cutoff, context: context)

        XCTAssertTrue(stalled.isEmpty, "A brand-new item with no sessions yet isn't stalled just because it hasn't started")
    }

    // MARK: - recentActivity(in:context:)

    func testRecentActivityListsStatusAndProgressChangesWithinRange() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()
        WorkItemService.updateProgress(workItem, progress: 40, context: context)
        WorkItemService.changeStatus(workItem, to: .inProgress, context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let activity = try ReportService.recentActivity(in: interval, context: context)

        XCTAssertEqual(activity.count, 2)
        XCTAssertTrue(activity.allSatisfy { $0.subjectTitle == "Outline" })
    }

    func testRecentActivityIsSortedMostRecentFirst() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()
        // Move off Not Started first so these two calls don't also interleave an implicit status
        // promotion event into the timeline being asserted on.
        WorkItemService.changeStatus(workItem, to: .inProgress, context: context)
        try context.save()
        WorkItemService.updateProgress(workItem, progress: 25, context: context)
        WorkItemService.updateProgress(workItem, progress: 75, context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let activity = try ReportService.recentActivity(in: interval, context: context)
            .filter { $0.kind == .progressChanged }

        XCTAssertEqual(activity.map(\.newValue), ["75", "25"])
    }

    func testRecentActivityExcludesEventsOutsideRange() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()
        WorkItemService.updateProgress(workItem, progress: 40, context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: 3600), end: Date(timeIntervalSinceNow: 7200))
        let activity = try ReportService.recentActivity(in: interval, context: context)

        XCTAssertTrue(activity.isEmpty)
    }

    // MARK: - progressHistory(for:in:)

    func testProgressHistoryReturnsChronologicalSeries() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()
        WorkItemService.updateProgress(workItem, progress: 10, context: context)
        WorkItemService.updateProgress(workItem, progress: 50, context: context)
        WorkItemService.updateProgress(workItem, progress: 90, context: context)
        try context.save()

        let history = try ReportService.progressHistory(for: workItem, in: context)

        XCTAssertEqual(history.map(\.progress), [10, 50, 90])
    }

    func testProgressHistoryExcludesStatusOnlyChanges() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()
        WorkItemService.changeStatus(workItem, to: .inProgress, context: context)
        try context.save()

        let history = try ReportService.progressHistory(for: workItem, in: context)

        XCTAssertTrue(history.isEmpty)
    }

    // MARK: - §13.10 Clips Reports

    func testClipStatusTransitionsCountsTransitionsIntoEachStatus() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        ClipService.changeStatus(clip, to: .currentlyEditing, context: context)
        ClipService.changeStatus(clip, to: .ready, context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let transitions = try ReportService.clipStatusTransitions(in: interval, context: context)

        XCTAssertEqual(transitions.first { $0.status == .currentlyEditing }?.count, 1)
        XCTAssertEqual(transitions.first { $0.status == .ready }?.count, 1)
        XCTAssertEqual(transitions.first { $0.status == .posted }?.count, 0)
    }

    func testClipStatusTransitionsDoesNotDoubleCountAStaticClip() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        ClipService.changeStatus(clip, to: .ready, context: context)
        try context.save()

        // The transition happened before this report's range — a clip sitting in Ready the
        // whole period shouldn't be counted as if it just became Ready.
        let interval = DateInterval(start: Date(timeIntervalSinceNow: 3600), end: Date(timeIntervalSinceNow: 7200))
        let transitions = try ReportService.clipStatusTransitions(in: interval, context: context)

        XCTAssertEqual(transitions.first { $0.status == .ready }?.count, 0)
    }

    func testClipsReportComputesEditingTimeAndAverage() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clipA = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        let clipB = ClipService.createClip(title: "Travel Bit", in: source, context: context)
        try context.save()
        let workItemA = try WorkItemService.clipWorkItem(for: clipA, context: context)
        let workItemB = try WorkItemService.clipWorkItem(for: clipB, context: context)
        let now = Date()
        WorkSessionService.logCompletedSession(
            for: workItemA, startAt: now, endAt: now.addingTimeInterval(1800),
            activeDurationSeconds: 1800, progressBefore: 0, progressAfter: 50, entryType: .timer, context: context
        )
        WorkSessionService.logCompletedSession(
            for: workItemB, startAt: now, endAt: now.addingTimeInterval(600),
            activeDurationSeconds: 600, progressBefore: 0, progressAfter: 50, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.clipsReport(in: interval, context: context)

        XCTAssertEqual(report.editingSeconds, 2400)
        XCTAssertEqual(report.clipsWorkedOnCount, 2)
        XCTAssertEqual(report.averageProductionSeconds, 1200)
    }

    func testClipsReportExcludesNonClipWorkSessions() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let now = Date()
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(1800),
            activeDurationSeconds: 1800, progressBefore: 0, progressAfter: 50, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.clipsReport(in: interval, context: context)

        XCTAssertEqual(report.editingSeconds, 0, "Writing time must not count toward Clips editing time")
    }

    func testClipsReportIncludesLiveBufferSnapshots() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let readyClip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        ClipService.changeStatus(readyClip, to: .ready, context: context)
        let backlogClip = ClipService.createClip(title: "Travel Bit", in: source, context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.clipsReport(in: interval, context: context)

        XCTAssertEqual(report.readyBufferCount, 1)
        XCTAssertEqual(report.productionBacklogCount, 1)
        _ = backlogClip
    }

    func testTopSourcesByClipCountRanksDescending() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let sourceA = SourceService.createSource(title: "March Comedy Slam", context: context)
        let sourceB = SourceService.createSource(title: "April Comedy Slam", context: context)
        ClipService.createClip(title: "Bit 1", in: sourceA, context: context)
        ClipService.createClip(title: "Bit 2", in: sourceA, context: context)
        ClipService.createClip(title: "Bit 3", in: sourceB, context: context)
        try context.save()

        let ranked = ReportService.topSourcesByClipCount(context: context)

        XCTAssertEqual(ranked.first?.sourceTitle, "March Comedy Slam")
        XCTAssertEqual(ranked.first?.clipCount, 2)
    }

    // MARK: - §13.11 Sketch Reports

    func testSketchStatusTransitionsCountsTransitionsIntoEachStatus() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        try context.save()

        SketchProductionService.changeStatus(for: project, to: .filmingScheduled, context: context)
        SketchProductionService.changeStatus(for: project, to: .filmed, context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let transitions = try ReportService.sketchStatusTransitions(in: interval, context: context)

        XCTAssertEqual(transitions.first { $0.status == .filmingScheduled }?.count, 1)
        XCTAssertEqual(transitions.first { $0.status == .filmed }?.count, 1)
        XCTAssertEqual(transitions.first { $0.status == .posted }?.count, 0)
    }

    func testSketchesEditingSecondsOnlyCountsSketchesWorkspace() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        try context.save()
        let workItem = try WorkItemService.sketchEditingWorkItem(for: project, context: context)
        let now = Date()
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(900),
            activeDurationSeconds: 900, progressBefore: 0, progressAfter: 50, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let seconds = try ReportService.sketchesEditingSeconds(in: interval, context: context)

        XCTAssertEqual(seconds, 900)
    }

    func testSketchTurnaroundComputesDaysBetweenWritingFinishedAndPosted() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, in: context)
        try context.save()

        ProjectService.setStatus(project, to: .finished, context: context)
        try context.save()

        SketchProductionService.changeStatus(for: project, to: .posted, context: context)
        let postItem = PostingItemService.findOrCreate(for: project, context: context)
        let postedAt = Date(timeIntervalSinceNow: 86400 * 3)
        postItem.actualPostedDate = postedAt
        try context.save()

        let interval = DateInterval(start: .now, end: Date(timeIntervalSinceNow: 86400 * 10))
        let turnaround = try ReportService.sketchTurnaround(in: interval, context: context)

        XCTAssertEqual(turnaround.count, 1)
        XCTAssertEqual(turnaround.first?.title, "Airport Sketch")
        XCTAssertGreaterThanOrEqual(turnaround.first?.turnaroundDays ?? -1, 2)
    }

    func testSketchTurnaroundExcludesSketchesMissingEitherTimestamp() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        try context.save()
        // Never posted — no PostingItem.actualPostedDate.

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -86400 * 30), end: Date(timeIntervalSinceNow: 86400 * 30))
        let turnaround = try ReportService.sketchTurnaround(in: interval, context: context)

        XCTAssertTrue(turnaround.isEmpty)
    }

    // MARK: - §13.12 Posting Reports

    func testPostingReportCountsPostsWithinRangeSplitByClipsAndSketches() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Set", context: context)
        let clip = ClipService.createClip(title: "Bit One", in: source, context: context)
        ClipService.changeStatus(clip, to: .ready, context: context)
        let clipPostItem = PostingItemService.findOrCreate(for: clip, context: context)
        PostingItemService.markPosted(clipPostItem, context: context)

        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        let sketchPostItem = PostingItemService.findOrCreate(for: project, context: context)
        PostingItemService.markPosted(sketchPostItem, context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.postingReport(in: interval, context: context)

        XCTAssertEqual(report.postsCount, 2)
        XCTAssertEqual(report.clipsPostedCount, 1)
        XCTAssertEqual(report.sketchesPostedCount, 1)
    }

    func testPostingReportExcludesPostsOutsideRange() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Set", context: context)
        let clip = ClipService.createClip(title: "Bit One", in: source, context: context)
        ClipService.changeStatus(clip, to: .posted, context: context)
        let postItem = PostingItemService.findOrCreate(for: clip, context: context)
        postItem.actualPostedDate = Date(timeIntervalSinceNow: -86400 * 30)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.postingReport(in: interval, context: context)

        XCTAssertEqual(report.postsCount, 0)
    }

    func testPostingReportActualPerWeekScalesWithRangeLength() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Set", context: context)
        let clip = ClipService.createClip(title: "Bit One", in: source, context: context)
        ClipService.changeStatus(clip, to: .posted, context: context)
        let postItem = PostingItemService.findOrCreate(for: clip, context: context)
        PostingItemService.markPosted(postItem, context: context)
        try context.save()

        // A one-week-long range containing exactly one post: 1 post / 1 week = 1.0/week.
        let interval = DateInterval(start: Date(timeIntervalSinceNow: -86400 * 3), end: Date(timeIntervalSinceNow: 86400 * 4))
        let report = try ReportService.postingReport(in: interval, context: context)

        XCTAssertEqual(report.actualPerWeek, 1.0, accuracy: 0.01)
    }

    func testPostingReportTargetPerWeekReflectsSettings() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = try SettingsService.currentSettings(in: context)
        SettingsService.updatePostsPerWeekTarget(settings, to: 5)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.postingReport(in: interval, context: context)

        XCTAssertEqual(report.targetPerWeek, 5)
    }

    func testPostingReportReadyAndWaitingCountsUnpostedReadyClipsAndSketches() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Set", context: context)
        let readyClip = ClipService.createClip(title: "Bit One", in: source, context: context)
        ClipService.changeStatus(readyClip, to: .ready, context: context)
        let backlogClip = ClipService.createClip(title: "Bit Two", in: source, context: context)
        ClipService.changeStatus(backlogClip, to: .currentlyEditing, context: context)

        let readySketch = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        SketchProductionService.changeStatus(for: readySketch, to: .ready, context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.postingReport(in: interval, context: context)

        XCTAssertEqual(report.readyPiecesWaitingCount, 2)
    }

    func testPostingReportMissedPlannedPostsCountsPastConfirmedDatesNeverPosted() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Set", context: context)
        let overdueClip = ClipService.createClip(title: "Bit One", in: source, context: context)
        ClipService.changeStatus(overdueClip, to: .ready, context: context)
        let overdueItem = PostingItemService.findOrCreate(for: overdueClip, context: context)
        PostingItemService.setConfirmedPostDate(overdueItem, date: Date(timeIntervalSinceNow: -86400), context: context)

        let onTrackClip = ClipService.createClip(title: "Bit Two", in: source, context: context)
        ClipService.changeStatus(onTrackClip, to: .ready, context: context)
        let onTrackItem = PostingItemService.findOrCreate(for: onTrackClip, context: context)
        PostingItemService.setConfirmedPostDate(onTrackItem, date: Date(timeIntervalSinceNow: 86400), context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.postingReport(in: interval, context: context)

        XCTAssertEqual(report.missedPlannedPostsCount, 1)
    }

    // MARK: - §13.9 Stand-Up Reports

    func testStandUpReportCountsCreativeSecondsOnlyForStandUpWorkspace() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try WorkItemService.generalStandUpWorkItem(context: context)
        let now = Date()
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(600),
            activeDurationSeconds: 600, progressBefore: 0, progressAfter: 0, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.standUpReport(in: interval, context: context)

        XCTAssertEqual(report.creativeSeconds, 600)
    }

    func testStandUpReportCountsJokeIdeasCreatedWithinRange() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        JokeService.quickCapture(text: "Airline food, but for cats.", context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.standUpReport(in: interval, context: context)

        XCTAssertEqual(report.jokeIdeasCreatedCount, 1)
    }

    func testStandUpReportCountsJokesMovedToNewAndDoneAsTransitionsNotSnapshots() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let jokeA = JokeService.quickCapture(text: "One.", context: context)
        let jokeB = JokeService.quickCapture(text: "Two.", context: context)
        try context.save()

        JokeService.move(jokeA, to: .new, in: context)
        JokeService.move(jokeB, to: .new, in: context)
        JokeService.move(jokeB, to: .done, in: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.standUpReport(in: interval, context: context)

        XCTAssertEqual(report.jokesMovedToNewCount, 2)
        XCTAssertEqual(report.jokesMovedToDoneCount, 1)
    }

    func testStandUpReportCountsChunksCreatedWithinRange() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        ChunkService.createChunk(title: "Travel Bit", context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.standUpReport(in: interval, context: context)

        XCTAssertEqual(report.chunksCreatedCount, 1)
    }

    func testStandUpReportCountsGigsPerformedWithinRange() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        GigService.createGig(venue: "The Comedy Cellar", startAt: Date(), context: context)
        GigService.createGig(venue: "Future Gig", startAt: Date(timeIntervalSinceNow: 86400 * 30), context: context)
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let report = try ReportService.standUpReport(in: interval, context: context)

        XCTAssertEqual(report.gigsPerformedCount, 1)
    }

    func testHeadlineSetProgressReportsCurrentRuntimeAgainstTarget() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let set = HeadlineSetService.createHeadlineSet(title: "Fall Tour Set", targetDurationMinutes: 45, context: context)
        let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
        chunk.runtimeSeconds = 300
        try context.save()
        HeadlineSetService.addChunk(chunk, to: set)
        try context.save()

        let entries = ReportService.headlineSetProgress(context: context)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.currentSeconds, 300)
        XCTAssertEqual(entries.first?.targetSeconds, 45 * 60)
    }

    func testTimeByMaterialAttributesSessionsToTheirJokeOrChunk() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food, but for cats.", context: context)
        try context.save()
        let workItem = try WorkItemService.standUpWorkItem(for: joke, context: context)
        let now = Date()
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(300),
            activeDurationSeconds: 300, progressBefore: 0, progressAfter: 0, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let entries = try ReportService.timeByMaterial(in: interval, context: context)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.title, "Airline food, but for cats.")
        XCTAssertEqual(entries.first?.seconds, 300)
    }

    func testTimeByMaterialExcludesGeneralStandUpSessions() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try WorkItemService.generalStandUpWorkItem(context: context)
        let now = Date()
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(300),
            activeDurationSeconds: 300, progressBefore: 0, progressAfter: 0, entryType: .timer, context: context
        )
        try context.save()

        let interval = DateInterval(start: Date(timeIntervalSinceNow: -3600), end: Date(timeIntervalSinceNow: 3600))
        let entries = try ReportService.timeByMaterial(in: interval, context: context)

        XCTAssertTrue(entries.isEmpty)
    }
}
