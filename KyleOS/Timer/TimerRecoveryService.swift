import Foundation
import SwiftData

/// Crash-recovery entry point (PRD §16.7): on launch, check for a leftover ActiveTimerState and
/// offer resume/end/discard. This step provides the three actions; the actual "ask the user"
/// prompt is a UI concern for whichever screen eventually hosts the real timer.
enum TimerRecoveryService {
    typealias ActiveTimerState = KyleOSSchemaV15.ActiveTimerState

    static func checkForInterruptedSession(in context: ModelContext) throws -> ActiveTimerState? {
        try ActiveTimerStateService.interruptedSessions(in: context).first
    }

    /// "End" — logs whatever was checkpointed as a completed WorkSession, using the checkpoint
    /// time as the end time (we don't know exactly when the app actually quit).
    @discardableResult
    static func end(_ state: ActiveTimerState, progressAfter: Int, context: ModelContext) -> WorkSessionService.WorkSession? {
        guard let workItem = state.workItem else {
            ActiveTimerStateService.clear(state, context: context)
            return nil
        }
        let session = WorkSessionService.logCompletedSession(
            for: workItem,
            startAt: state.sessionStartedAt,
            endAt: state.checkpointedAt,
            activeDurationSeconds: state.activeDurationSecondsAtCheckpoint,
            pausedDurationSeconds: state.pausedDurationSecondsAtCheckpoint,
            plannedDurationMinutes: state.targetDurationMinutes,
            progressBefore: state.progressBefore,
            progressAfter: progressAfter,
            note: "Recovered after an interrupted session",
            entryType: .timer,
            context: context
        )
        WorkItemService.updateProgress(workItem, progress: progressAfter)
        ActiveTimerStateService.clear(state, context: context)
        return session
    }

    /// "Discard" — no WorkSession logged, the checkpoint is simply removed.
    static func discard(_ state: ActiveTimerState, context: ModelContext) {
        ActiveTimerStateService.clear(state, context: context)
    }

    /// "Resume" — rehydrates a live FocusTimerController continuing from the checkpoint, paused
    /// (see FocusTimerController.rehydrate for why). Returns nil if the linked Work Item no
    /// longer exists (deleting it already cascade-clears the checkpoint, so this is defensive).
    static func resume(_ state: ActiveTimerState, now: @escaping () -> Date = Date.init) -> FocusTimerController? {
        guard let workItem = state.workItem else { return nil }
        let controller = FocusTimerController(now: now)
        controller.rehydrate(
            workItem: workItem,
            sessionStartedAt: state.sessionStartedAt,
            targetDurationMinutes: state.targetDurationMinutes,
            progressBefore: state.progressBefore,
            activeDurationSeconds: state.activeDurationSecondsAtCheckpoint,
            pausedDurationSeconds: state.pausedDurationSecondsAtCheckpoint,
            checkpoint: state
        )
        return controller
    }

    /// "Resume" variant for the app's single shared FocusTimerController (owned by KyleOSApp,
    /// injected via `.environment` so the timer is visible/controllable from any screen) —
    /// rehydrates that existing instance in place instead of creating a new one that nothing
    /// would observe. Returns false if the linked Work Item no longer exists.
    @discardableResult
    static func resume(_ state: ActiveTimerState, into controller: FocusTimerController) -> Bool {
        guard let workItem = state.workItem else { return false }
        controller.rehydrate(
            workItem: workItem,
            sessionStartedAt: state.sessionStartedAt,
            targetDurationMinutes: state.targetDurationMinutes,
            progressBefore: state.progressBefore,
            activeDurationSeconds: state.activeDurationSecondsAtCheckpoint,
            pausedDurationSeconds: state.pausedDurationSecondsAtCheckpoint,
            checkpoint: state
        )
        return true
    }
}
