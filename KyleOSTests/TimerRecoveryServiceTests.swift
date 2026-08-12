import XCTest
import SwiftData
@testable import KyleOS

final class TimerRecoveryServiceTests: XCTestCase {

    private func makeWorkItem(in context: ModelContext) throws -> KyleOSSchemaV8.WorkItem {
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        return try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
    }

    func testCheckForInterruptedSessionFindsALeftoverCheckpoint() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)

        XCTAssertNil(try TimerRecoveryService.checkForInterruptedSession(in: context))

        let timer = FocusTimerController()
        timer.start(workItem: workItem, targetDurationMinutes: 45, progressBefore: 0, context: context)
        try context.save()

        let found = try TimerRecoveryService.checkForInterruptedSession(in: context)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.workItem?.id, workItem.id)
    }

    func testEndLogsAWorkSessionFromTheCheckpointAndClearsIt() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)

        let state = ActiveTimerStateService.start(
            for: workItem, sessionStartedAt: .now, targetDurationMinutes: 45, progressBefore: 20, context: context
        )
        ActiveTimerStateService.checkpoint(state, activeDurationSeconds: 900, pausedDurationSeconds: 60, isRunning: true)
        try context.save()

        let session = TimerRecoveryService.end(state, progressAfter: 40, context: context)
        try context.save()

        XCTAssertNotNil(session)
        XCTAssertEqual(session?.activeDurationSeconds, 900)
        XCTAssertEqual(session?.pausedDurationSeconds, 60)
        XCTAssertEqual(workItem.progress, 40)
        XCTAssertNil(try TimerRecoveryService.checkForInterruptedSession(in: context))
    }

    func testDiscardClearsTheCheckpointWithoutLoggingASession() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)

        let state = ActiveTimerStateService.start(
            for: workItem, sessionStartedAt: .now, targetDurationMinutes: nil, progressBefore: 0, context: context
        )
        try context.save()

        TimerRecoveryService.discard(state, context: context)
        try context.save()

        XCTAssertEqual(try WorkSessionService.sessions(for: workItem, in: context).count, 0)
        XCTAssertNil(try TimerRecoveryService.checkForInterruptedSession(in: context))
    }

    func testResumeRehydratesAPausedControllerContinuingFromTheCheckpoint() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)

        let state = ActiveTimerStateService.start(
            for: workItem, sessionStartedAt: .now, targetDurationMinutes: 45, progressBefore: 15, context: context
        )
        ActiveTimerStateService.checkpoint(state, activeDurationSeconds: 500, pausedDurationSeconds: 30, isRunning: true)
        try context.save()

        let resumed = TimerRecoveryService.resume(state)

        XCTAssertNotNil(resumed)
        XCTAssertEqual(resumed?.state, .paused, "A recovered session must not silently start counting time again")
        XCTAssertEqual(resumed?.activeDurationSeconds, 500)
        XCTAssertEqual(resumed?.pausedDurationSeconds, 30)
        XCTAssertEqual(resumed?.workItem?.id, workItem.id)

        // Explicitly resuming from there should work like any other paused session.
        let finished = resumed?.finish(progressAfter: 30, context: context)
        XCTAssertEqual(finished?.activeDurationSeconds, 500)
    }

    /// The variant Home actually uses — the app's one shared FocusTimerController instance
    /// (injected via `.environment`), rehydrated in place rather than a throwaway new instance
    /// nothing would observe.
    func testResumeIntoRehydratesTheSharedController() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)

        let state = ActiveTimerStateService.start(
            for: workItem, sessionStartedAt: .now, targetDurationMinutes: 45, progressBefore: 15, context: context
        )
        ActiveTimerStateService.checkpoint(state, activeDurationSeconds: 500, pausedDurationSeconds: 30, isRunning: true)
        try context.save()

        let sharedController = FocusTimerController()
        XCTAssertEqual(sharedController.state, .idle, "Precondition: shared controller starts idle")

        let succeeded = TimerRecoveryService.resume(state, into: sharedController)

        XCTAssertTrue(succeeded)
        XCTAssertEqual(sharedController.state, .paused)
        XCTAssertEqual(sharedController.activeDurationSeconds, 500)
        XCTAssertEqual(sharedController.workItem?.id, workItem.id)
    }
}
