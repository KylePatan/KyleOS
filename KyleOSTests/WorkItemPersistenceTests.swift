import XCTest
import SwiftData
@testable import KyleOS

final class WorkItemPersistenceTests: XCTestCase {

    func testCreatingAWorkItemSeedsEstimateFromMatchingWorkTypeDefault() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        try WorkTypeDefaultService.seedKnownDefaultsIfNeeded(in: context)
        try context.save()

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline pass 1",
            workspace: .writing,
            workTypeName: "Outline",
            in: project,
            context: context
        )
        try context.save()

        // PRD §5.1: Outline defaults to 1.5 creative hours = 90 minutes.
        XCTAssertEqual(workItem.estimatedTotalMinutes, 90)
        XCTAssertEqual(workItem.estimatedRemainingMinutes, 90)
        XCTAssertEqual(workItem.status, .notStarted)
        XCTAssertEqual(workItem.progress, 0)
    }

    func testCreatingAWorkItemWithUnknownWorkTypeFallsBackToGenericDefaults() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Something new",
            workspace: .clips,
            workTypeName: "Never Seeded Type",
            in: project,
            context: context
        )
        try context.save()

        XCTAssertEqual(workItem.estimatedTotalMinutes, 60)
        XCTAssertEqual(workItem.preferredSessionMinutes, 45)
        XCTAssertEqual(workItem.minimumSessionMinutes, 15)
    }

    func testUpdateProgressMovesNotStartedToInProgressButNotToCompleted() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline pass 1", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        WorkItemService.updateProgress(workItem, progress: 100)
        try context.save()

        XCTAssertEqual(workItem.progress, 100)
        XCTAssertEqual(workItem.status, .inProgress, "Progress alone must not auto-complete a Work Item")
        XCTAssertNil(workItem.completedAt)
    }

    func testProgressClampsToZeroAndOneHundred() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline pass 1", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )

        WorkItemService.updateProgress(workItem, progress: 150)
        XCTAssertEqual(workItem.progress, 100)

        WorkItemService.updateProgress(workItem, progress: -20)
        XCTAssertEqual(workItem.progress, 0)
    }

    func testCompleteSetsStatusProgressAndCompletionDate() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline pass 1", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        WorkItemService.complete(workItem)
        try context.save()

        XCTAssertEqual(workItem.status, .completed)
        XCTAssertEqual(workItem.progress, 100)
        XCTAssertNotNil(workItem.completedAt)
    }

    func testPriorityAndDependenciesPersist() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let outline = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let draft = try WorkItemService.createWorkItem(
            title: "First Draft", workspace: .writing, workTypeName: "Script Draft", in: project, context: context
        )
        WorkItemService.setPriority(draft, to: 5)
        WorkItemService.addDependency(draft, dependsOn: outline)
        try context.save()

        XCTAssertEqual(draft.priority, 5)
        XCTAssertEqual(draft.dependsOn.map(\.id), [outline.id])

        WorkItemService.removeDependency(draft, dependency: outline)
        try context.save()
        XCTAssertTrue(draft.dependsOn.isEmpty)
    }

    func testDeletingProjectCascadesToItsWorkItems() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        context.delete(project)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<KyleOSSchemaV7.WorkItem>())
        XCTAssertEqual(remaining.count, 0, "Deleting a Project must cascade-delete its Work Items")
    }

    func testDataSurvivesReopeningTheStore() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSWorkItemRestartTest-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let workItemID: UUID
        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
            let workItem = try WorkItemService.createWorkItem(
                title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
            )
            WorkItemService.updateProgress(workItem, progress: 40)
            workItemID = workItem.id
            try context.save()
        }

        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let allItems = try context.fetch(FetchDescriptor<KyleOSSchemaV7.WorkItem>())
            XCTAssertEqual(allItems.count, 1)
            XCTAssertEqual(allItems.first?.id, workItemID)
            XCTAssertEqual(allItems.first?.progress, 40)
            XCTAssertEqual(allItems.first?.status, .inProgress)
            XCTAssertNotNil(allItems.first?.project, "The Project relationship must survive a restart")
        }
    }
}
