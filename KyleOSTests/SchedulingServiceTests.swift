import XCTest
import SwiftData
@testable import KyleOS

final class SchedulingServiceTests: XCTestCase {

    func testDeadlineUrgencyDominatesPriorityAndQuickWinAndStaleness() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let dueSoon = try WorkItemService.createWorkItem(
            title: "Due Tomorrow", workspace: .writing, workTypeName: "Outline", in: project, priority: 1, context: context
        )
        DeadlineService.setDeadline(for: dueSoon, label: "Soon", dueAt: Date(timeIntervalSinceNow: 86400), context: context)

        // Everything is stacked in this item's favor except deadline urgency: max priority,
        // a quick-win-sized remaining estimate, and untouched for a long time.
        let noDeadlineButOtherwiseFavored = try WorkItemService.createWorkItem(
            title: "Favored But No Deadline", workspace: .writing, workTypeName: "Outline", in: project, priority: 5, context: context
        )
        noDeadlineButOtherwiseFavored.estimatedRemainingMinutes = 30
        noDeadlineButOtherwiseFavored.createdAt = Date(timeIntervalSinceNow: -86400 * 60)
        try context.save()

        let ranked = SchedulingService.rankedItems(from: [dueSoon, noDeadlineButOtherwiseFavored])

        XCTAssertEqual(ranked.first?.workItem.title, "Due Tomorrow")
    }

    func testQuickWinBoostRanksSmallRemainingEffortAboveLargeAtEqualPriority() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let quickWin = try WorkItemService.createWorkItem(
            title: "Almost Done", workspace: .writing, workTypeName: "Outline", in: project, priority: 3, context: context
        )
        quickWin.estimatedRemainingMinutes = 20

        let bigLift = try WorkItemService.createWorkItem(
            title: "Just Started", workspace: .writing, workTypeName: "Outline", in: project, priority: 3, context: context
        )
        bigLift.estimatedRemainingMinutes = 600
        try context.save()

        let ranked = SchedulingService.rankedItems(from: [bigLift, quickWin])

        XCTAssertEqual(ranked.first?.workItem.title, "Almost Done")
    }

    func testStalenessBoostCanOutweighASmallPriorityGap() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let fresh = try WorkItemService.createWorkItem(
            title: "Recently Started", workspace: .writing, workTypeName: "Outline", in: project, priority: 3, context: context
        )
        let stale = try WorkItemService.createWorkItem(
            title: "Forgotten", workspace: .writing, workTypeName: "Outline", in: project, priority: 2, context: context
        )
        // One priority level = 10 points; staleness accrues 5/day, so ~2+ untouched days should
        // be enough to overcome a single-level priority gap.
        stale.createdAt = Date(timeIntervalSinceNow: -86400 * 5)
        try context.save()

        let ranked = SchedulingService.rankedItems(from: [fresh, stale])

        XCTAssertEqual(ranked.first?.workItem.title, "Forgotten")
    }

    func testBlockedItemsAreExcludedFromRanking() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let dependency = try WorkItemService.createWorkItem(
            title: "Must Finish First", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let dependent = try WorkItemService.createWorkItem(
            title: "Blocked Item", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        WorkItemService.addDependency(dependent, dependsOn: dependency)
        try context.save()

        let ranked = SchedulingService.rankedItems(from: [dependency, dependent])

        XCTAssertEqual(ranked.map(\.workItem.title), ["Must Finish First"])
    }

    func testBlockedItemBecomesEligibleOnceItsDependencyCompletes() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let dependency = try WorkItemService.createWorkItem(
            title: "Must Finish First", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let dependent = try WorkItemService.createWorkItem(
            title: "Blocked Item", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        WorkItemService.addDependency(dependent, dependsOn: dependency)
        WorkItemService.complete(dependency, context: context)
        try context.save()

        XCTAssertFalse(SchedulingService.isBlocked(dependent))
    }

    func testCompletedItemsAreExcludedFromRanking() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let completed = try WorkItemService.createWorkItem(
            title: "Already Done", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        WorkItemService.complete(completed, context: context)
        try context.save()

        XCTAssertTrue(SchedulingService.rankedItems(from: [completed]).isEmpty)
    }

    func testTopTieDetectsWithinMarginScoresAtTheTopOfTheRanking() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let itemA = try WorkItemService.createWorkItem(
            title: "Item A", workspace: .writing, workTypeName: "Outline", in: project, priority: 3, context: context
        )
        let itemB = try WorkItemService.createWorkItem(
            title: "Item B", workspace: .writing, workTypeName: "Outline", in: project, priority: 3, context: context
        )
        try context.save()

        let ranked = SchedulingService.rankedItems(from: [itemA, itemB])
        let tie = SchedulingService.topTie(in: ranked)

        XCTAssertNotNil(tie, "Two items with identical inputs should score within the tie margin of each other")
    }

    func testTopTieReturnsNilWhenScoresAreClearlyDifferent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let highPriority = try WorkItemService.createWorkItem(
            title: "High Priority", workspace: .writing, workTypeName: "Outline", in: project, priority: 5, context: context
        )
        let lowPriority = try WorkItemService.createWorkItem(
            title: "Low Priority", workspace: .writing, workTypeName: "Outline", in: project, priority: 1, context: context
        )
        try context.save()

        let ranked = SchedulingService.rankedItems(from: [highPriority, lowPriority])

        XCTAssertNil(SchedulingService.topTie(in: ranked))
    }

    func testResolveTieBumpsTheChosenItemsPriorityAboveTheOther() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let itemA = try WorkItemService.createWorkItem(
            title: "Item A", workspace: .writing, workTypeName: "Outline", in: project, priority: 3, context: context
        )
        let itemB = try WorkItemService.createWorkItem(
            title: "Item B", workspace: .writing, workTypeName: "Outline", in: project, priority: 3, context: context
        )
        try context.save()

        SchedulingService.resolveTie(choosing: itemA, over: itemB)
        try context.save()

        XCTAssertGreaterThan(itemA.priority, itemB.priority)
    }

    func testResolveTieDoesNotExceedMaximumPriority() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)

        let itemA = try WorkItemService.createWorkItem(
            title: "Item A", workspace: .writing, workTypeName: "Outline", in: project, priority: 5, context: context
        )
        let itemB = try WorkItemService.createWorkItem(
            title: "Item B", workspace: .writing, workTypeName: "Outline", in: project, priority: 5, context: context
        )
        try context.save()

        SchedulingService.resolveTie(choosing: itemA, over: itemB)
        try context.save()

        XCTAssertEqual(itemA.priority, 5)
    }
}
