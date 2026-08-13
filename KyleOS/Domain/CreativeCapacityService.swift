import Foundation
import SwiftData

/// PRD §4.4: "Home should show how much realistic creative time is available for the day, how
/// much is already scheduled, and how much remains." Kept out of views per CLAUDE.md §4. These
/// are explicitly "planning assumptions, not hard restrictions" (§4.4's own words) — a simple
/// baseline-minus-scheduled calculation, not a precise minute-by-minute free/busy derivation.
enum CreativeCapacityService {
    typealias AppSettings = KyleOSSchemaV22.AppSettings
    typealias CalendarEvent = KyleOSSchemaV22.CalendarEvent
    typealias PlannedSession = KyleOSSchemaV22.PlannedSession

    struct Summary: Equatable {
        let baselineHours: Double
        let scheduledHours: Double
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
    static func todaysCapacity(
        settings: AppSettings,
        events: [CalendarEvent],
        plannedSessions: [PlannedSession],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Summary {
        var baseline = settings.weekdayCreativeCapacityHours
        let hasGigToday = events.contains {
            $0.eventType == .standUpGig && calendar.isDate($0.startAt, inSameDayAs: now)
        }
        if hasGigToday {
            baseline = max(baseline - settings.standUpNightBonusHours, 0)
        }

        let scheduledMinutes = plannedSessions
            .filter { $0.status == .scheduled && calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.plannedDurationMinutes }

        return Summary(baselineHours: baseline, scheduledHours: Double(scheduledMinutes) / 60)
    }
}
