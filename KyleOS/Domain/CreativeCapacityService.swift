import Foundation
import SwiftData

/// PRD §4.4: "Home should show how much realistic creative time is available for the day, how
/// much is already scheduled, and how much remains." Kept out of views per CLAUDE.md §4. These
/// are explicitly "planning assumptions, not hard restrictions" (§4.4's own words) — a simple
/// baseline-minus-scheduled calculation, not a precise minute-by-minute free/busy derivation.
enum CreativeCapacityService {
    typealias AppSettings = KyleOSSchemaV36.AppSettings
    typealias CalendarEvent = KyleOSSchemaV36.CalendarEvent
    typealias CalendarEventType = KyleOSSchemaV36.CalendarEventType
    typealias Availability = KyleOSSchemaV36.Availability
    typealias PlannedSession = KyleOSSchemaV36.PlannedSession
    typealias CapacityOverride = KyleOSSchemaV36.CapacityOverride

    /// PRD §4.4: "Personal calendar events and all-day time-off events reduce available capacity."
    /// Only these two types count — Day Job is already baked into the weekday/weekend baseline
    /// itself (not derived from its own CalendarEvent), and a Stand-Up Gig has its own separate,
    /// differently-shaped reduction (`standUpNightBonusHours`) right below.
    private static let capacityReducingEventTypes: Set<CalendarEventType> = [.personal, .unavailableTimeOff]

    struct Summary: Equatable {
        let baselineHours: Double
        let scheduledHours: Double
        var isOverridden: Bool = false
        var remainingHours: Double { max(baselineHours - scheduledHours, 0) }
    }

    /// Baseline = Settings' weekday Creative Capacity, minus a stand-up-night reduction if a
    /// Stand-Up Gig calendar event falls today. This is §7.8's wording ("Gigs... reduce expected
    /// Creative Capacity that day"), not §4.4's ("a stand-up gig night generally supports about 1
    /// additional creative hour") — the two sections directly conflicted (one says gig nights add
    /// capacity, the other says they reduce it), surfaced to Kyle once Gigs (§7.8) actually
    /// existed to build against, and he explicitly chose §7.8's "reduce" behavior. The
    /// `standUpNightBonusHours` Settings field is reused as-is (a gig night now *costs* about
    /// that many hours instead of granting them) rather than adding a new schema field for a
    /// same-shaped Double — the field's name is a minor legacy misnomer worth cleaning up in a
    /// future Settings-UI pass, not worth a schema migration on its own. Scheduled = today's
    /// Scheduled (not missed/cancelled) Planned Sessions.
    ///
    /// PRD §11.6: "The user can override a day's expected Creative Capacity, including setting it
    /// to zero or increasing it for a free day." An override is the user's own stated number for
    /// that specific day — used directly as the baseline, bypassing the Settings/gig-night
    /// calculation entirely rather than adjusting it further.
    ///
    /// Kyle (2026-08-18): flagged as a known, deliberately-deferred gap in `CURRENT_PHASE.md` —
    /// "Personal calendar events and all-day time-off events reduce available capacity" (§4.4)
    /// wasn't implemented; only Gigs and manual overrides reduced the baseline. Reduces baseline by
    /// each `.busy` Personal/Unavailable event's actual overlap with today (clipped to
    /// [startOfDay, endOfDay) — an all-day event's `startAt`/`endAt` span the full day, so it
    /// naturally zeroes the baseline rather than needing special-case handling). An event marked
    /// `.available` doesn't reduce capacity — same distinction real calendar apps make between a
    /// loosely-scheduled reminder and something that actually blocks time.
    static func todaysCapacity(
        settings: AppSettings,
        events: [CalendarEvent],
        plannedSessions: [PlannedSession],
        overrides: [CapacityOverride] = [],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Summary {
        let scheduledMinutes = plannedSessions
            .filter { $0.status == .scheduled && calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.plannedDurationMinutes }
        let scheduledHours = Double(scheduledMinutes) / 60

        if let override = overrides.first(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
            return Summary(baselineHours: override.hours, scheduledHours: scheduledHours, isOverridden: true)
        }

        let weekday = calendar.component(.weekday, from: now)
        let isWeekend = weekday == 1 || weekday == 7
        var baseline = isWeekend ? settings.displayWeekendCreativeCapacityHours : settings.weekdayCreativeCapacityHours
        let hasGigToday = events.contains {
            $0.eventType == .standUpGig && calendar.isDate($0.startAt, inSameDayAs: now)
        }
        if hasGigToday {
            baseline = max(baseline - settings.standUpNightBonusHours, 0)
        }
        baseline = max(baseline - personalEventReductionHours(events: events, calendar: calendar, now: now), 0)

        return Summary(baselineHours: baseline, scheduledHours: scheduledHours)
    }

    private static func personalEventReductionHours(events: [CalendarEvent], calendar: Calendar, now: Date) -> Double {
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        return events
            .filter { capacityReducingEventTypes.contains($0.eventType) && $0.availability == .busy }
            .reduce(0.0) { total, event in
                let overlapStart = max(event.startAt, startOfDay)
                let overlapEnd = min(event.endAt, endOfDay)
                return total + max(overlapEnd.timeIntervalSince(overlapStart), 0) / 3600
            }
    }

    static func override(for date: Date, in context: ModelContext, calendar: Calendar = .current) throws -> CapacityOverride? {
        let day = calendar.startOfDay(for: date)
        return try context.fetch(
            FetchDescriptor<CapacityOverride>(predicate: #Predicate { $0.date == day })
        ).first
    }

    @discardableResult
    static func setOverride(for date: Date, hours: Double, context: ModelContext, calendar: Calendar = .current) throws -> CapacityOverride {
        let day = calendar.startOfDay(for: date)
        if let existing = try override(for: day, in: context, calendar: calendar) {
            existing.hours = max(hours, 0)
            existing.updatedAt = .now
            return existing
        }
        let created = CapacityOverride(date: day, hours: max(hours, 0))
        context.insert(created)
        return created
    }

    static func clearOverride(for date: Date, context: ModelContext, calendar: Calendar = .current) throws {
        if let existing = try override(for: date, in: context, calendar: calendar) {
            context.delete(existing)
        }
    }
}
