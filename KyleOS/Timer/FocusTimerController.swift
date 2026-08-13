import Foundation
import SwiftData
import Observation

/// The shared Focus Timer engine (PRD §5.2-§5.4): Start/Pause/Resume/Stop/Finish Session,
/// tracking active time separately from paused time so paused segments never count as active
/// Creative Time. This is the "Timer/work-session logic" architectural boundary CLAUDE.md §4
/// calls out as distinct from persistence — it owns the live clock/state machine and delegates
/// actual writes to ActiveTimerStateService (checkpointing) and WorkSessionService/
/// WorkItemService (finishing).
///
/// One shared instance lives for the app's lifetime (owned by KyleOSApp, injected via
/// `.environment`) so PRD §4.8's "the timer continues while navigating elsewhere" holds — Home
/// isn't the only screen that can see it, any screen can. `@Observable` so SwiftUI re-renders on
/// state changes; deliberately has NO internal RunLoop/Timer for live ticking — that would
/// complicate the deterministic testing this class was built around. Instead
/// `currentActiveDurationSeconds` is a plain computed property; a view drives its own refresh
/// (e.g. TimelineView) and reads it fresh each tick. The `now` closure is injectable so tests
/// can drive time deterministically instead of sleeping.
@Observable
final class FocusTimerController {
    typealias WorkItem = KyleOSSchemaV21.WorkItem
    typealias WorkSession = KyleOSSchemaV21.WorkSession

    enum State: Equatable {
        case idle
        case running
        case paused
    }

    private(set) var state: State = .idle
    private(set) var workItem: WorkItem?
    private(set) var targetDurationMinutes: Int?
    private(set) var progressBefore: Int = 0
    private(set) var activeDurationSeconds: Int = 0
    private(set) var pausedDurationSeconds: Int = 0

    private var sessionStartedAt: Date?
    private var currentSegmentStartedAt: Date?
    private var checkpoint: ActiveTimerStateService.ActiveTimerState?

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// True once accumulated active time reaches the target — PRD §5.3: "the timer is a session
    /// target, not a forced stop." Callers (a future UI) use this to offer Finish Session/Keep
    /// Working; the controller itself never forces a stop.
    var hasReachedGoal: Bool {
        guard let targetDurationMinutes else { return false }
        return activeDurationSeconds >= targetDurationMinutes * 60
    }

    /// Elapsed active seconds INCLUDING whatever segment is currently in progress — unlike
    /// `activeDurationSeconds`, which only reflects completed segments. A view that wants a
    /// live-ticking display reads this on its own periodic refresh (e.g. TimelineView); this
    /// property itself does no scheduling.
    var currentActiveDurationSeconds: Int {
        guard state == .running, let segmentStart = currentSegmentStartedAt else { return activeDurationSeconds }
        return activeDurationSeconds + Int(now().timeIntervalSince(segmentStart))
    }

    @discardableResult
    func start(
        workItem: WorkItem,
        targetDurationMinutes: Int?,
        progressBefore: Int,
        context: ModelContext
    ) -> Bool {
        guard state == .idle else { return false }
        let startTime = now()
        self.workItem = workItem
        self.targetDurationMinutes = targetDurationMinutes
        self.progressBefore = progressBefore
        self.sessionStartedAt = startTime
        self.activeDurationSeconds = 0
        self.pausedDurationSeconds = 0
        self.currentSegmentStartedAt = startTime
        self.state = .running
        self.checkpoint = ActiveTimerStateService.start(
            for: workItem,
            sessionStartedAt: startTime,
            targetDurationMinutes: targetDurationMinutes,
            progressBefore: progressBefore,
            context: context
        )
        writeCheckpoint()
        return true
    }

    @discardableResult
    func pause(context: ModelContext) -> Bool {
        guard state == .running, let segmentStart = currentSegmentStartedAt else { return false }
        activeDurationSeconds += Int(now().timeIntervalSince(segmentStart))
        currentSegmentStartedAt = now()
        state = .paused
        writeCheckpoint()
        return true
    }

    @discardableResult
    func resume(context: ModelContext) -> Bool {
        guard state == .paused, let segmentStart = currentSegmentStartedAt else { return false }
        pausedDurationSeconds += Int(now().timeIntervalSince(segmentStart))
        currentSegmentStartedAt = now()
        state = .running
        writeCheckpoint()
        return true
    }

    /// Ends the session and logs a WorkSession — used by both the "Stop" control (early/manual
    /// end) and "Finish Session" (offered once the goal is reached); PRD §5.3 treats their
    /// outcome identically ("actual elapsed active time is logged" either way).
    @discardableResult
    func finish(progressAfter: Int, note: String = "", context: ModelContext) -> WorkSession? {
        guard state != .idle, let workItem, let sessionStartedAt, let segmentStart = currentSegmentStartedAt else {
            return nil
        }
        let endTime = now()
        switch state {
        case .running: activeDurationSeconds += Int(endTime.timeIntervalSince(segmentStart))
        case .paused: pausedDurationSeconds += Int(endTime.timeIntervalSince(segmentStart))
        case .idle: break
        }

        let session = WorkSessionService.logCompletedSession(
            for: workItem,
            startAt: sessionStartedAt,
            endAt: endTime,
            activeDurationSeconds: activeDurationSeconds,
            pausedDurationSeconds: pausedDurationSeconds,
            plannedDurationMinutes: targetDurationMinutes,
            progressBefore: progressBefore,
            progressAfter: progressAfter,
            note: note,
            entryType: .timer,
            context: context
        )
        WorkItemService.updateProgress(workItem, progress: progressAfter)
        if let checkpoint {
            ActiveTimerStateService.clear(checkpoint, context: context)
        }
        reset()
        return session
    }

    /// Abandons the session with no WorkSession logged — e.g. the user started a timer by
    /// mistake. Distinct from `finish`, which always records what happened.
    func discard(context: ModelContext) {
        if let checkpoint {
            ActiveTimerStateService.clear(checkpoint, context: context)
        }
        reset()
    }

    /// Reconstructs in-memory state from a persisted checkpoint — used by
    /// TimerRecoveryService.resume() to continue an interrupted session. Always rehydrates into
    /// `.paused`, never `.running` — after an unclean shutdown we can't assume the user wants
    /// the clock immediately counting again without them explicitly resuming it.
    func rehydrate(
        workItem: WorkItem,
        sessionStartedAt: Date,
        targetDurationMinutes: Int?,
        progressBefore: Int,
        activeDurationSeconds: Int,
        pausedDurationSeconds: Int,
        checkpoint: ActiveTimerStateService.ActiveTimerState
    ) {
        self.workItem = workItem
        self.targetDurationMinutes = targetDurationMinutes
        self.progressBefore = progressBefore
        self.sessionStartedAt = sessionStartedAt
        self.activeDurationSeconds = activeDurationSeconds
        self.pausedDurationSeconds = pausedDurationSeconds
        self.currentSegmentStartedAt = now()
        self.state = .paused
        self.checkpoint = checkpoint
    }

    private func writeCheckpoint() {
        guard let checkpoint else { return }
        ActiveTimerStateService.checkpoint(
            checkpoint,
            activeDurationSeconds: activeDurationSeconds,
            pausedDurationSeconds: pausedDurationSeconds,
            isRunning: state == .running,
            at: now()
        )
    }

    private func reset() {
        state = .idle
        workItem = nil
        targetDurationMinutes = nil
        progressBefore = 0
        activeDurationSeconds = 0
        pausedDurationSeconds = 0
        sessionStartedAt = nil
        currentSegmentStartedAt = nil
        checkpoint = nil
    }
}
