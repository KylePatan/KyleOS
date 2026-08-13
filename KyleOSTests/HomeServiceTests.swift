import XCTest
import SwiftData
@testable import KyleOS

final class HomeServiceTests: XCTestCase {

    func testRankedTodayItemsSortsByDeadlineThenPriorityAndExcludesCompleted() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let noDeadlineLowPriority = try WorkItemService.createWorkItem(
            title: "Low priority, no deadline", workspace: .writing, workTypeName: "Outline", in: project, priority: 1, context: context
        )
        let noDeadlineHighPriority = try WorkItemService.createWorkItem(
            title: "High priority, no deadline", workspace: .writing, workTypeName: "Outline", in: project, priority: 5, context: context
        )
        let soonDeadline = try WorkItemService.createWorkItem(
            title: "Due soon", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let laterDeadline = try WorkItemService.createWorkItem(
            title: "Due later", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let completed = try WorkItemService.createWorkItem(
            title: "Already done", workspace: .writing, workTypeName: "Outline", in: project, priority: 5, context: context
        )
        WorkItemService.complete(completed)

        DeadlineService.setDeadline(for: soonDeadline, label: "Soon", dueAt: Date(timeIntervalSinceNow: 86400), context: context)
        DeadlineService.setDeadline(for: laterDeadline, label: "Later", dueAt: Date(timeIntervalSinceNow: 86400 * 10), context: context)
        try context.save()

        let ranked = HomeService.rankedTodayItems(from: [noDeadlineLowPriority, noDeadlineHighPriority, soonDeadline, laterDeadline, completed])

        XCTAssertEqual(
            ranked.map(\.title),
            ["Due soon", "Due later", "High priority, no deadline", "Low priority, no deadline"],
            "Deadlines sort first (soonest first), then no-deadline items by priority; completed items are excluded"
        )
    }

    func testRankedTodayItemsRespectsLimit() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        var items: [KyleOSSchemaV23.WorkItem] = []
        for i in 0..<15 {
            items.append(try WorkItemService.createWorkItem(
                title: "Item \(i)", workspace: .writing, workTypeName: "Outline", in: project, context: context
            ))
        }
        try context.save()

        XCTAssertEqual(HomeService.rankedTodayItems(from: items, limit: 10).count, 10)
    }

    func testTotalLoggedSecondsSumsAcrossAllWorkItemsInAProject() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let outline = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let draft = try WorkItemService.createWorkItem(
            title: "Draft", workspace: .writing, workTypeName: "Script Draft", in: project, context: context
        )
        WorkSessionService.logCompletedSession(
            for: outline, startAt: .now, endAt: Date(timeIntervalSinceNow: 1800),
            activeDurationSeconds: 1800, progressBefore: 0, progressAfter: 50, entryType: .timer, context: context
        )
        WorkSessionService.logCompletedSession(
            for: draft, startAt: .now, endAt: Date(timeIntervalSinceNow: 3600),
            activeDurationSeconds: 3600, progressBefore: 0, progressAfter: 20, entryType: .timer, context: context
        )
        try context.save()

        XCTAssertEqual(HomeService.totalLoggedSeconds(for: project), 5400)
    }

    func testTodaysSessionSecondsOnlyCountsSessionsStartedToday() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )

        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        WorkSessionService.logCompletedSession(
            for: workItem, startAt: yesterday, endAt: yesterday.addingTimeInterval(1800),
            activeDurationSeconds: 1800, progressBefore: 0, progressAfter: 10, entryType: .timer, context: context
        )
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: now, endAt: now.addingTimeInterval(900),
            activeDurationSeconds: 900, progressBefore: 10, progressAfter: 20, entryType: .timer, context: context
        )
        try context.save()

        XCTAssertEqual(HomeService.todaysSessionSeconds(for: workItem, calendar: calendar, now: now), 900)
    }

    func testTodaysSessionSecondsReturnsNilWhenNothingLoggedToday() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )

        XCTAssertNil(HomeService.todaysSessionSeconds(for: workItem))
    }

    func testAllUnfinishedItemsExcludesCompletedAndSortsByPriorityDescending() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let low = try WorkItemService.createWorkItem(
            title: "Low", workspace: .writing, workTypeName: "Outline", in: project, priority: 1, context: context
        )
        let high = try WorkItemService.createWorkItem(
            title: "High", workspace: .writing, workTypeName: "Outline", in: project, priority: 5, context: context
        )
        let completed = try WorkItemService.createWorkItem(
            title: "Done", workspace: .writing, workTypeName: "Outline", in: project, priority: 5, context: context
        )
        WorkItemService.complete(completed)
        try context.save()

        let items = HomeService.allUnfinishedItems(from: [low, high, completed])
        XCTAssertEqual(items.map(\.title), ["High", "Low"])
    }

    func testReorderedPrioritiesRenumbersWithTopOfListGettingHighestValue() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let a = try WorkItemService.createWorkItem(
            title: "A", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let b = try WorkItemService.createWorkItem(
            title: "B", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let c = try WorkItemService.createWorkItem(
            title: "C", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )

        // [A, B, C] with C (index 2) dragged to the front (index 0) -> [C, A, B].
        let result = HomeService.reorderedPriorities(current: [a, b, c], movingFromOffsets: [2], toOffset: 0)

        XCTAssertEqual(result.map { $0.item.id }, [c.id, a.id, b.id])
        XCTAssertEqual(result.map(\.newPriority), [2, 1, 0], "Top of the list gets the highest priority value")
    }

    func testReorderedPrioritiesAppliedThroughWorkItemServicePersistsAndReSorts() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let a = try WorkItemService.createWorkItem(
            title: "A", workspace: .writing, workTypeName: "Outline", in: project, priority: 3, context: context
        )
        let b = try WorkItemService.createWorkItem(
            title: "B", workspace: .writing, workTypeName: "Outline", in: project, priority: 2, context: context
        )
        let c = try WorkItemService.createWorkItem(
            title: "C", workspace: .writing, workTypeName: "Outline", in: project, priority: 1, context: context
        )
        try context.save()

        let initialOrder = HomeService.allUnfinishedItems(from: [a, b, c])
        XCTAssertEqual(initialOrder.map(\.title), ["A", "B", "C"])

        // Drag C (index 2) to the front, as a view's onMove handler would.
        for (item, newPriority) in HomeService.reorderedPriorities(current: initialOrder, movingFromOffsets: [2], toOffset: 0) {
            WorkItemService.setPriority(item, to: newPriority)
        }
        try context.save()

        let finalOrder = HomeService.allUnfinishedItems(from: [a, b, c])
        XCTAssertEqual(finalOrder.map(\.title), ["C", "A", "B"], "Re-fetching after the reorder must reflect the new order")
    }
}
