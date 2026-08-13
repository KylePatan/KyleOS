import XCTest
import SwiftData
@testable import KyleOS

final class ActiveTimerStateServiceTests: XCTestCase {

    func testStartCreatesACheckpointLinkedToTheWorkItem() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let start = Date()
        let state = ActiveTimerStateService.start(
            for: workItem, sessionStartedAt: start, targetDurationMinutes: 45, progressBefore: 0, context: context
        )
        try context.save()

        XCTAssertEqual(workItem.activeTimerState?.id, state.id)
        XCTAssertEqual(try ActiveTimerStateService.interruptedSessions(in: context).map(\.id), [state.id])
    }

    func testCheckpointUpdatesAccumulatedDurations() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let state = ActiveTimerStateService.start(
            for: workItem, sessionStartedAt: .now, targetDurationMinutes: nil, progressBefore: 0, context: context
        )
        ActiveTimerStateService.checkpoint(state, activeDurationSeconds: 300, pausedDurationSeconds: 60, isRunning: false)
        try context.save()

        XCTAssertEqual(state.activeDurationSecondsAtCheckpoint, 300)
        XCTAssertEqual(state.pausedDurationSecondsAtCheckpoint, 60)
        XCTAssertFalse(state.wasRunningAtCheckpoint)
    }

    func testClearRemovesTheCheckpoint() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let state = ActiveTimerStateService.start(
            for: workItem, sessionStartedAt: .now, targetDurationMinutes: nil, progressBefore: 0, context: context
        )
        try context.save()

        ActiveTimerStateService.clear(state, context: context)
        try context.save()

        XCTAssertEqual(try ActiveTimerStateService.interruptedSessions(in: context).count, 0)
    }

    func testDeletingWorkItemCascadesToItsCheckpoint() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        ActiveTimerStateService.start(
            for: workItem, sessionStartedAt: .now, targetDurationMinutes: nil, progressBefore: 0, context: context
        )
        try context.save()

        context.delete(workItem)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<KyleOSSchemaV15.ActiveTimerState>()).count, 0)
    }
}
