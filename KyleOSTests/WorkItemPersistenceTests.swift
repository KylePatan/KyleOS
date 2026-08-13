import XCTest
import SwiftData
@testable import KyleOS

final class WorkItemPersistenceTests: XCTestCase {

    func testWritingWorkItemCreatesOneLinkedToTheDocumentOnFirstCall() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Coastal Town", projectType: .shortStory, in: context)
        let document = DocumentService.createDocument(title: "Chapter One", type: .prose, in: project, context: context)

        let workItem = try WorkItemService.writingWorkItem(for: document, context: context)
        try context.save()

        XCTAssertEqual(workItem.document?.id, document.id)
        XCTAssertEqual(workItem.workspace, .writing)
        XCTAssertEqual(workItem.title, "Chapter One")
    }

    func testWritingWorkItemReusesTheExistingOneOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Coastal Town", projectType: .shortStory, in: context)
        let document = DocumentService.createDocument(title: "Chapter One", type: .prose, in: project, context: context)

        let first = try WorkItemService.writingWorkItem(for: document, context: context)
        try context.save()
        let second = try WorkItemService.writingWorkItem(for: document, context: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try WorkItemService.workItems(for: project, in: context).count, 1, "A second call must not create a duplicate")
    }

    func testStandUpWorkItemForJokeCreatesOneLinkedToTheJokeOnFirstCall() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        try context.save()

        let workItem = try WorkItemService.standUpWorkItem(for: joke, context: context)
        try context.save()

        XCTAssertEqual(workItem.joke?.id, joke.id)
        XCTAssertNil(workItem.chunk)
        XCTAssertNil(workItem.project)
        XCTAssertEqual(workItem.workspace, .standUp)
    }

    func testStandUpWorkItemForJokeReusesTheExistingOneOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        try context.save()

        let first = try WorkItemService.standUpWorkItem(for: joke, context: context)
        try context.save()
        let second = try WorkItemService.standUpWorkItem(for: joke, context: context)

        XCTAssertEqual(first.id, second.id)
    }

    func testStandUpWorkItemForChunkCreatesOneLinkedToTheChunk() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
        try context.save()

        let workItem = try WorkItemService.standUpWorkItem(for: chunk, context: context)
        try context.save()

        XCTAssertEqual(workItem.chunk?.id, chunk.id)
        XCTAssertNil(workItem.joke)
        XCTAssertEqual(workItem.title, "Travel Bit")
    }

    func testGeneralStandUpWorkItemHasNoJokeOrChunkAndIsReused() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let first = try WorkItemService.generalStandUpWorkItem(context: context)
        try context.save()
        let second = try WorkItemService.generalStandUpWorkItem(context: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertNil(first.joke)
        XCTAssertNil(first.chunk)
        XCTAssertEqual(first.workspace, .standUp)
        XCTAssertEqual(first.title, "Stand-Up Writing")
    }

    func testGeneralStandUpWorkItemIsDistinctFromAJokeSpecificWorkItem() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        try context.save()

        let general = try WorkItemService.generalStandUpWorkItem(context: context)
        let jokeSpecific = try WorkItemService.standUpWorkItem(for: joke, context: context)

        XCTAssertNotEqual(general.id, jokeSpecific.id)
    }

    func testDeletingJokeNullifiesRatherThanDeletingItsWorkItem() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food bit", context: context)
        try context.save()
        let workItem = try WorkItemService.standUpWorkItem(for: joke, context: context)
        let workItemID = workItem.id
        try context.save()

        context.delete(joke)
        try context.save()

        let survivingWorkItems = try context.fetch(FetchDescriptor<WorkItemService.WorkItem>())
        let survivor = survivingWorkItems.first { $0.id == workItemID }
        XCTAssertNotNil(survivor, "Deleting the Joke must not delete its logged Work Item history")
        XCTAssertNil(survivor?.joke)
    }

    func testClipWorkItemCreatesOneLinkedToTheClipOnFirstCall() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        let workItem = try WorkItemService.clipWorkItem(for: clip, context: context)
        try context.save()

        XCTAssertEqual(workItem.clip?.id, clip.id)
        XCTAssertNil(workItem.project)
        XCTAssertEqual(workItem.workspace, .clips)
        XCTAssertEqual(workItem.title, "Airline Bit")
    }

    func testClipWorkItemReusesTheExistingOneOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        let first = try WorkItemService.clipWorkItem(for: clip, context: context)
        try context.save()
        let second = try WorkItemService.clipWorkItem(for: clip, context: context)

        XCTAssertEqual(first.id, second.id)
    }

    func testDeletingClipNullifiesRatherThanDeletingItsWorkItem() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()
        let workItem = try WorkItemService.clipWorkItem(for: clip, context: context)
        let workItemID = workItem.id
        try context.save()

        ClipService.delete(clip, context: context)
        try context.save()

        let survivingWorkItems = try context.fetch(FetchDescriptor<WorkItemService.WorkItem>())
        let survivor = survivingWorkItems.first { $0.id == workItemID }
        XCTAssertNotNil(survivor, "Deleting the Clip must not delete its logged Work Item history")
        XCTAssertNil(survivor?.clip)
    }

    func testSketchEditingWorkItemCreatesOneLinkedToTheProjectOnFirstCall() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        try context.save()

        let workItem = try WorkItemService.sketchEditingWorkItem(for: project, context: context)
        try context.save()

        XCTAssertEqual(workItem.project?.id, project.id)
        XCTAssertEqual(workItem.workspace, .sketches)
        XCTAssertEqual(workItem.title, "Airport Sketch")
        XCTAssertEqual(workItem.workTypeName, "Sketch Editing")
    }

    func testSketchEditingWorkItemReusesTheExistingOneOnSubsequentCalls() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        try context.save()

        let first = try WorkItemService.sketchEditingWorkItem(for: project, context: context)
        try context.save()
        let second = try WorkItemService.sketchEditingWorkItem(for: project, context: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try WorkItemService.workItems(for: project, in: context).count, 1, "A second call must not create a duplicate")
    }

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

        let remaining = try context.fetch(FetchDescriptor<KyleOSSchemaV24.WorkItem>())
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
            let allItems = try context.fetch(FetchDescriptor<KyleOSSchemaV24.WorkItem>())
            XCTAssertEqual(allItems.count, 1)
            XCTAssertEqual(allItems.first?.id, workItemID)
            XCTAssertEqual(allItems.first?.progress, 40)
            XCTAssertEqual(allItems.first?.status, .inProgress)
            XCTAssertNotNil(allItems.first?.project, "The Project relationship must survive a restart")
        }
    }
}
