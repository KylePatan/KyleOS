import XCTest
import SwiftData
@testable import KyleOS

final class HistoryEventServiceTests: XCTestCase {

    func testChangeStatusRecordsAHistoryEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        WorkItemService.changeStatus(workItem, to: .inProgress, context: context)
        try context.save()

        let events = try HistoryEventService.events(for: workItem, in: context)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .statusChanged)
        XCTAssertEqual(events.first?.oldValue, "Not Started")
        XCTAssertEqual(events.first?.newValue, "In Progress")
    }

    func testChangeStatusToTheSameValueDoesNotRecordAnEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        WorkItemService.changeStatus(workItem, to: .notStarted, context: context)
        try context.save()

        let events = try HistoryEventService.events(for: workItem, in: context)
        XCTAssertTrue(events.isEmpty, "Setting status to its already-current value shouldn't log a no-op change")
    }

    func testUpdateProgressRecordsAHistoryEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()
        // Move off Not Started first so this call in isolation doesn't also trigger the implicit
        // Not Started -> In Progress promotion (covered separately below).
        WorkItemService.changeStatus(workItem, to: .inProgress, context: context)
        try context.save()

        WorkItemService.updateProgress(workItem, progress: 40, context: context)
        try context.save()

        let progressEvents = try HistoryEventService.events(for: workItem, in: context).filter { $0.kind == .progressChanged }
        XCTAssertEqual(progressEvents.count, 1)
        XCTAssertEqual(progressEvents.first?.oldValue, "0")
        XCTAssertEqual(progressEvents.first?.newValue, "40")
    }

    func testUpdateProgressFromZeroAlsoRecordsTheImplicitStatusPromotion() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        WorkItemService.updateProgress(workItem, progress: 40, context: context)
        try context.save()

        let events = try HistoryEventService.events(for: workItem, in: context)
        XCTAssertEqual(events.count, 2, "Both the progress change and its implicit Not Started -> In Progress promotion should be logged")
        XCTAssertTrue(events.contains { $0.kind == .progressChanged && $0.newValue == "40" })
        XCTAssertTrue(events.contains { $0.kind == .statusChanged && $0.oldValue == "Not Started" && $0.newValue == "In Progress" })
    }

    func testCompleteRecordsBothStatusAndProgressEvents() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        WorkItemService.complete(workItem, context: context)
        try context.save()

        let events = try HistoryEventService.events(for: workItem, in: context)
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.contains { $0.kind == .statusChanged && $0.newValue == "Completed" })
        XCTAssertTrue(events.contains { $0.kind == .progressChanged && $0.newValue == "100" })
    }

    func testMultipleProgressChangesRecordInChronologicalOrder() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()

        WorkItemService.updateProgress(workItem, progress: 25, context: context)
        WorkItemService.updateProgress(workItem, progress: 60, context: context)
        WorkItemService.updateProgress(workItem, progress: 100, context: context)
        try context.save()

        // The first call also implicitly promotes status Not Started -> In Progress, which is
        // itself now a logged event interleaved in the timeline — filter to progress changes only.
        let events = try HistoryEventService.events(for: workItem, in: context)
            .filter { $0.kind == .progressChanged }
        XCTAssertEqual(events.map(\.newValue), ["25", "60", "100"])
    }

    func testClipChangeStatusRecordsAHistoryEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()

        ClipService.changeStatus(clip, to: .ready, context: context)
        try context.save()

        let events = try HistoryEventService.events(for: clip, in: context)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.oldValue, "Identified / To Isolate")
        XCTAssertEqual(events.first?.newValue, "Ready")
    }

    func testSketchProductionChangeStatusRecordsAHistoryEventOnTheProject() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Airport Sketch", projectType: .sketch, status: .finished, in: context)
        try context.save()

        SketchProductionService.changeStatus(for: project, to: .filmingScheduled, context: context)
        try context.save()

        let events = try HistoryEventService.events(for: project, in: context)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.oldValue, "Filming Not Scheduled")
        XCTAssertEqual(events.first?.newValue, "Filming Scheduled")
    }

    func testJokeMoveRecordsAHistoryEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food, but for cats.", context: context)
        try context.save()

        JokeService.move(joke, to: .new, in: context)
        try context.save()

        let events = try HistoryEventService.events(for: joke, in: context)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.oldValue, "Joke Ideas")
        XCTAssertEqual(events.first?.newValue, "New")
    }

    func testJokeMoveToTheSameStatusDoesNotRecordAnEvent() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food, but for cats.", context: context)
        try context.save()

        JokeService.move(joke, to: .ideas, in: context)
        try context.save()

        XCTAssertTrue(try HistoryEventService.events(for: joke, in: context).isEmpty)
    }

    func testDeletingAJokeCascadeDeletesItsHistoryEvents() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let joke = JokeService.quickCapture(text: "Airline food, but for cats.", context: context)
        try context.save()
        JokeService.move(joke, to: .new, in: context)
        try context.save()

        context.delete(joke)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<HistoryEventService.HistoryEvent>())
        XCTAssertTrue(remaining.isEmpty)
    }

    func testDeletingAWorkItemCascadeDeletesItsHistoryEvents() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        try context.save()
        WorkItemService.updateProgress(workItem, progress: 40, context: context)
        try context.save()

        context.delete(workItem)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<HistoryEventService.HistoryEvent>())
        XCTAssertTrue(remaining.isEmpty, "History is a log owned by its subject — it shouldn't outlive the deleted Work Item")
    }
}
