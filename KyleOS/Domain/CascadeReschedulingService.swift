import Foundation
import SwiftData

/// Scheduling Engine increment 2 (PRD §4.6, Decision Gate B): cascade rescheduling. When a day's
/// actual Creative Capacity shrinks below what's already Scheduled there, already-planned
/// flexible (non-locked) Planned Sessions reflow forward to the next day with spare capacity.
///
/// Kyle's resolution of the cascade-aggressiveness question (2026-08-14): "Schedule changes
/// (especially blocked off things) should re-shuffle the already-planned creative work. And if
/// there are no hours to do the creative work - so be it. It should be more aggressive because
/// it's dealing with time we don't have anymore." Implemented as: search forward up to
/// `lookaheadDays` for a home; a session that still doesn't fit within that window is returned as
/// `unresolved`, not silently deleted or force-fit — the caller (a real UI, not silent background
/// mutation) surfaces that as the PRD's "flag the conflict."
///
/// `PlannedSession.isLocked` is the one "never move" signal (matching the pre-existing
/// `PlannedSessionService.reschedule`/`CalendarEventService.reschedule` no-op-on-locked pattern,
/// PRD §11.8) — a locked session's minutes still count against the day's capacity (it's really
/// happening then), it just can't itself be the one that moves.
///
/// Which movable session stays versus gets pushed is decided by `SchedulingService.score` — the
/// same ranking Home's Today view already uses, so cascade and "what should I work on" never
/// disagree about what matters more.
///
/// Deliberately scoped to ONE real trigger this increment: `CreativeCapacityService.setOverride`
/// lowering a day's capacity (wired into `CalendarHomeView`). Other capacity-shrinking moments —
/// a new Gig, a DayJobOverride — are real future call sites, not built here. Not scope creep to
/// defer; matches every other module's own "narrowest real slice first" pattern this session. A
/// new Busy Personal/Time-Off CalendarEvent is no longer one of the deferred cases: since this
/// calls `CreativeCapacityService.todaysCapacity` directly (below), it started reducing each
/// lookahead day's capacity for those automatically the moment that gap was fixed (2026-08-18) —
/// no change needed here.
enum CascadeReschedulingService {
    typealias PlannedSession = KyleOSSchemaV34.PlannedSession
    typealias CalendarEvent = KyleOSSchemaV34.CalendarEvent
    typealias AppSettings = KyleOSSchemaV34.AppSettings
    typealias CapacityOverride = KyleOSSchemaV34.CapacityOverride

    struct Move {
        let session: PlannedSession
        let from: Date
        let to: Date
    }

    struct ReflowResult {
        let moves: [Move]
        let unresolved: [PlannedSession]
    }

    /// PRD §4.4's own baseline example, same default `SchedulingService` uses — a reasonable
    /// forward-search window before giving up and flagging a session as unresolved.
    static let defaultLookaheadDays = 30

    static func reflow(
        startingFrom date: Date,
        lookaheadDays: Int = defaultLookaheadDays,
        settings: AppSettings,
        calendarEvents: [CalendarEvent],
        capacityOverrides: [CapacityOverride],
        allSessions: [PlannedSession],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> ReflowResult {
        var moves: [Move] = []
        var pending: [PlannedSession] = []
        var day = calendar.startOfDay(for: date)

        for _ in 0..<max(lookaheadDays, 1) {
            let dayCapacityMinutes = Int(
                CreativeCapacityService.todaysCapacity(
                    settings: settings, events: calendarEvents, plannedSessions: [],
                    overrides: capacityOverrides, calendar: calendar, now: day
                ).baselineHours * 60
            )

            let scheduledOnDay = allSessions.filter {
                $0.status == .scheduled && calendar.isDate($0.scheduledAt, inSameDayAs: day)
            }
            let lockedMinutes = scheduledOnDay.filter(\.isLocked).reduce(0) { $0 + $1.plannedDurationMinutes }
            let movableOnDay = scheduledOnDay.filter { !$0.isLocked }

            let candidates = (pending + movableOnDay).sorted { scoreForStaying($0, now: now, calendar: calendar) > scoreForStaying($1, now: now, calendar: calendar) }
            pending = []

            var remainingMinutes = max(dayCapacityMinutes - lockedMinutes, 0)
            for session in candidates {
                if session.plannedDurationMinutes <= remainingMinutes {
                    let originalDay = calendar.startOfDay(for: session.scheduledAt)
                    if !calendar.isDate(originalDay, inSameDayAs: day) {
                        let newScheduledAt = combining(day: day, timeOfDay: session.scheduledAt, calendar: calendar)
                        moves.append(Move(session: session, from: session.scheduledAt, to: newScheduledAt))
                        PlannedSessionService.reschedule(session, to: newScheduledAt)
                    }
                    remainingMinutes -= session.plannedDurationMinutes
                } else {
                    pending.append(session)
                }
            }

            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }

        return ReflowResult(moves: moves, unresolved: pending)
    }

    private static func scoreForStaying(_ session: PlannedSession, now: Date, calendar: Calendar) -> Double {
        guard let workItem = session.workItem else { return 0 }
        return SchedulingService.score(workItem, now: now, calendar: calendar)
    }

    private static func combining(day: Date, timeOfDay: Date, calendar: Calendar) -> Date {
        let time = calendar.dateComponents([.hour, .minute, .second], from: timeOfDay)
        return calendar.date(
            bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: time.second ?? 0, of: day
        ) ?? day
    }
}
