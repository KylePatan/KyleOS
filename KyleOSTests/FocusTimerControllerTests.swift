import XCTest
import SwiftData
@testable import KyleOS

/// A manually-advanceable clock so timer math is tested deterministically instead of via real
/// sleeping — fast and exact.
private final class FakeClock {
    private(set) var current = Date(timeIntervalSince1970: 1_700_000_000)
    func advance(_ seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
    func now() -> Date { current }
}

final class FocusTimerControllerTests: XCTestCase {

    private func makeWorkItem(in context: ModelContext) throws -> KyleOSSchemaV18.WorkItem {
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        return try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
    }

    func testStartTransitionsToRunningAndChecksPoints() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)
        let clock = FakeClock()
        let timer = FocusTimerController(now: clock.now)

        let started = timer.start(workItem: workItem, targetDurationMinutes: 45, progressBefore: 0, context: context)
        try context.save()

        XCTAssertTrue(started)
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(try ActiveTimerStateService.interruptedSessions(in: context).count, 1)
    }

    func testStartWhileAlreadyRunningIsANoOp() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)
        let clock = FakeClock()
        let timer = FocusTimerController(now: clock.now)

        timer.start(workItem: workItem, targetDurationMinutes: 45, progressBefore: 0, context: context)
        let secondStart = timer.start(workItem: workItem, targetDurationMinutes: 30, progressBefore: 0, context: context)

        XCTAssertFalse(secondStart)
        XCTAssertEqual(timer.targetDurationMinutes, 45, "The original session must not be clobbered")
    }

    func testPauseAccumulatesActiveTimeAndExcludesPausedTime() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)
        let clock = FakeClock()
        let timer = FocusTimerController(now: clock.now)

        timer.start(workItem: workItem, targetDurationMinutes: nil, progressBefore: 0, context: context)
        clock.advance(300) // 5 minutes active
        timer.pause(context: context)

        XCTAssertEqual(timer.state, .paused)
        XCTAssertEqual(timer.activeDurationSeconds, 300)

        clock.advance(120) // 2 minutes paused — must NOT be counted as active
        XCTAssertEqual(timer.activeDurationSeconds, 300, "Time passing while paused must not accrue as active time")
    }

    func testResumeAccumulatesPausedTimeAndContinuesActiveTime() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)
        let clock = FakeClock()
        let timer = FocusTimerController(now: clock.now)

        timer.start(workItem: workItem, targetDurationMinutes: nil, progressBefore: 0, context: context)
        clock.advance(300)
        timer.pause(context: context)
        clock.advance(120)
        timer.resume(context: context)
        clock.advance(180)

        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.pausedDurationSeconds, 120)
        // 300 active before pause is already accumulated; the 180 since resume is still "live"
        // (not yet folded into activeDurationSeconds until the next pause/finish), so at this
        // instant the accumulated total reflects only the completed first segment.
        XCTAssertEqual(timer.activeDurationSeconds, 300)
    }

    func testFinishWhileRunningFinalizesTheCurrentSegmentAsActive() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)
        let clock = FakeClock()
        let timer = FocusTimerController(now: clock.now)

        timer.start(workItem: workItem, targetDurationMinutes: 45, progressBefore: 10, context: context)
        clock.advance(600) // 10 minutes active, straight through, no pause
        let session = timer.finish(progressAfter: 35, context: context)
        try context.save()

        XCTAssertNotNil(session)
        XCTAssertEqual(session?.activeDurationSeconds, 600)
        XCTAssertEqual(session?.pausedDurationSeconds, 0)
        XCTAssertEqual(session?.progressBefore, 10)
        XCTAssertEqual(session?.progressAfter, 35)
        XCTAssertEqual(session?.entryType, .timer)
        XCTAssertEqual(workItem.progress, 35, "Finishing must update the Work Item's progress too")
        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(try ActiveTimerStateService.interruptedSessions(in: context).count, 0, "A clean finish must clear the checkpoint")
    }

    func testFinishWhilePausedDoesNotCountTheFinalPausedSegmentAsActive() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)
        let clock = FakeClock()
        let timer = FocusTimerController(now: clock.now)

        timer.start(workItem: workItem, targetDurationMinutes: nil, progressBefore: 0, context: context)
        clock.advance(300) // 5 min active
        timer.pause(context: context)
        clock.advance(9999) // sitting paused for a long time before finishing from paused state
        let session = timer.finish(progressAfter: 20, context: context)

        XCTAssertEqual(session?.activeDurationSeconds, 300, "Only the running segment counts as active")
        XCTAssertEqual(session?.pausedDurationSeconds, 9999)
    }

    func testDiscardClearsCheckpointWithoutLoggingASession() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)
        let clock = FakeClock()
        let timer = FocusTimerController(now: clock.now)

        timer.start(workItem: workItem, targetDurationMinutes: nil, progressBefore: 0, context: context)
        clock.advance(120)
        timer.discard(context: context)
        try context.save()

        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(try WorkSessionService.sessions(for: workItem, in: context).count, 0)
        XCTAssertEqual(try ActiveTimerStateService.interruptedSessions(in: context).count, 0)
    }

    func testHasReachedGoal() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)
        let clock = FakeClock()
        let timer = FocusTimerController(now: clock.now)

        timer.start(workItem: workItem, targetDurationMinutes: 15, progressBefore: 0, context: context)
        clock.advance(600) // 10 minutes, under the 15-minute goal
        XCTAssertFalse(timer.hasReachedGoal)

        clock.advance(300) // now at 15 minutes exactly, but not yet folded into activeDurationSeconds
        timer.pause(context: context) // pausing finalizes the running segment
        XCTAssertTrue(timer.hasReachedGoal)
    }

    func testPauseResumeFinishAreNoOpsWhenIdle() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let timer = FocusTimerController()

        XCTAssertFalse(timer.pause(context: context))
        XCTAssertFalse(timer.resume(context: context))
        XCTAssertNil(timer.finish(progressAfter: 50, context: context))
    }

    /// Backs the Home Active Timer's live-ticking display (ActiveTimerBanner) — proves the
    /// computed property reflects time passing DURING a running segment, not just after a
    /// pause/finish folds it in, and that it stays flat while idle/paused.
    func testCurrentActiveDurationSecondsReflectsLiveElapsedTimeWhileRunning() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let workItem = try makeWorkItem(in: context)
        let clock = FakeClock()
        let timer = FocusTimerController(now: clock.now)

        XCTAssertEqual(timer.currentActiveDurationSeconds, 0, "Idle must read as zero")

        timer.start(workItem: workItem, targetDurationMinutes: nil, progressBefore: 0, context: context)
        clock.advance(90)
        XCTAssertEqual(timer.currentActiveDurationSeconds, 90, "Must include the in-progress running segment")

        timer.pause(context: context)
        clock.advance(500)
        XCTAssertEqual(timer.currentActiveDurationSeconds, 90, "Must not keep climbing while paused")

        timer.resume(context: context)
        clock.advance(30)
        XCTAssertEqual(timer.currentActiveDurationSeconds, 120, "Must resume climbing from where it left off")
    }
}
