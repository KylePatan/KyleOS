import Foundation
import SwiftData

/// Persistence for the Focus Timer's crash-recovery checkpoint (PRD §16.7). Kept separate from
/// FocusTimerController (the live in-memory state machine) so the persistence primitive is
/// independently testable, matching the AutosaveController/DocumentService split.
enum ActiveTimerStateService {
    typealias ActiveTimerState = KyleOSSchemaV36.ActiveTimerState
    typealias WorkItem = KyleOSSchemaV36.WorkItem

    @discardableResult
    static func start(
        for workItem: WorkItem,
        sessionStartedAt: Date,
        targetDurationMinutes: Int?,
        progressBefore: Int,
        context: ModelContext
    ) -> ActiveTimerState {
        let state = ActiveTimerState(
            workItem: workItem,
            sessionStartedAt: sessionStartedAt,
            targetDurationMinutes: targetDurationMinutes,
            progressBefore: progressBefore
        )
        context.insert(state)
        workItem.activeTimerState = state
        return state
    }

    static func checkpoint(
        _ state: ActiveTimerState,
        activeDurationSeconds: Int,
        pausedDurationSeconds: Int,
        isRunning: Bool,
        at checkpointedAt: Date = .now
    ) {
        state.activeDurationSecondsAtCheckpoint = activeDurationSeconds
        state.pausedDurationSecondsAtCheckpoint = pausedDurationSeconds
        state.wasRunningAtCheckpoint = isRunning
        state.checkpointedAt = checkpointedAt
    }

    /// Called when a session ends cleanly (Finish/Stop) or is explicitly discarded — either way
    /// there's nothing left to recover.
    static func clear(_ state: ActiveTimerState, context: ModelContext) {
        context.delete(state)
    }

    /// Any row's mere existence means a session was interrupted (Foundation only ever runs one
    /// timer at a time, but this doesn't hard-enforce that — it just reports what it finds).
    static func interruptedSessions(in context: ModelContext) throws -> [ActiveTimerState] {
        try context.fetch(FetchDescriptor<ActiveTimerState>())
    }
}
