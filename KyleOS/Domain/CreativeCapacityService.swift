import Foundation
import SwiftData

/// PRD §4.4: "Home should show how much realistic creative time is available for the day, how
/// much is already scheduled, and how much remains." Kept out of views per CLAUDE.md §4. These
/// are explicitly "planning assumptions, not hard restrictions" (§4.4's own words) — a simple
/// baseline-minus-scheduled calculation, not a precise minute-by-minute free/busy derivation.
enum CreativeCapacityService {
    typealias AppSettings = KyleOSSchemaV8.AppSettings
    typealias CalendarEvent = KyleOSSchemaV8.CalendarEvent
    typealias PlannedSession = KyleOSSchemaV8.PlannedSession

    struct Summary: Equatable {
        let baselineHours: Double
        let scheduledHours: Double
        var remainingHours: Double { max(baselineHours - scheduledHours, 0) }
    }

    /// Baseline = Settings' weekday Creative Capacity, plus the stand-up-night bonus if a
    /// Stand-Up Gig calendar event falls today (§4.4: "a stand-up gig night generally supports
    /// about 1 additional creative hour"). Scheduled = today's Scheduled (not missed/cancelled)
    /// Planned Sessions.
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
            baseline += settings.standUpNightBonusHours
        }

        let scheduledMinutes = plannedSessions
            .filter { $0.status == .scheduled && calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.plannedDurationMinutes }

        return Summary(baselineHours: baseline, scheduledHours: Double(scheduledMinutes) / 60)
    }
}
