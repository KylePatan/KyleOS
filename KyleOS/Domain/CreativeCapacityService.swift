import Foundation
import SwiftData

/// PRD §4.4: "Home should show how much realistic creative time is available for the day, how
/// much is already scheduled, and how much remains." Kept out of views per CLAUDE.md §4. These
/// are explicitly "planning assumptions, not hard restrictions" (§4.4's own words) — a simple
/// baseline-minus-scheduled calculation, not a precise minute-by-minute free/busy derivation.
enum CreativeCapacityService {
    typealias AppSettings = KyleOSSchemaV31.AppSettings
    typealias CalendarEvent = KyleOSSchemaV31.CalendarEvent
    typealias PlannedSession = KyleOSSchemaV31.PlannedSession
    typealias CapacityOverride = KyleOSSchemaV31.CapacityOverride

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

        return Summary(baselineHours: baseline, scheduledHours: scheduledHours)
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
