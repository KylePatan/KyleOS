import Foundation
import SwiftData

/// PRD §11.4: "Monday–Friday, 8 AM–5 PM is blocked by default. Individual days can be overridden
/// for vacation or unusual availability." Day-Job blocks are ordinary `.dayJob` CalendarEvents,
/// generated lazily for whatever date range the Calendar workspace actually views (no background
/// job, no pre-generating indefinitely into the future) — the same "basic," on-demand posture as
/// the rest of V0.6.
///
/// "Overridden" specifically means: once the user removes a generated block for a given day, that
/// day must not silently regenerate the next time `ensureBlocks` runs over a range that includes
/// it. A CalendarEvent's mere absence can't distinguish "never generated yet" from "deliberately
/// removed," so `DayJobOverride` exists purely to record the latter.
enum DayJobScheduleService {
    typealias CalendarEvent = KyleOSSchemaV33.CalendarEvent
    typealias DayJobOverride = KyleOSSchemaV33.DayJobOverride

    /// Creates a `.dayJob` CalendarEvent for every configured weekday in `[start, end)` that
    /// doesn't already have one and hasn't been marked off — safe to call repeatedly (e.g. every
    /// time the Calendar workspace's displayed month changes) without creating duplicates.
    static func ensureBlocks(from start: Date, to end: Date, context: ModelContext) throws {
        guard start < end else { return }
        let settings = try SettingsService.currentSettings(in: context)
        guard !settings.dayJobWeekdays.isEmpty else { return }

        let calendar = Calendar.current
        let existingDayJobDates = Set(
            try CalendarEventService.events(from: start, to: end, in: context)
                .filter { $0.eventType == .dayJob }
                .map { calendar.startOfDay(for: $0.startAt) }
        )
        let offDates = Set(
            try context.fetch(FetchDescriptor<DayJobOverride>())
                .filter(\.isOff)
                .map { calendar.startOfDay(for: $0.date) }
        )

        var date = calendar.startOfDay(for: start)
        let rangeEnd = calendar.startOfDay(for: end)
        while date < rangeEnd {
            defer { date = calendar.date(byAdding: .day, value: 1, to: date) ?? rangeEnd }

            let weekday = calendar.component(.weekday, from: date)
            guard settings.dayJobWeekdays.contains(weekday) else { continue }
            guard !existingDayJobDates.contains(date), !offDates.contains(date) else { continue }
            guard
                let blockStart = calendar.date(bySettingHour: settings.dayJobStartHour, minute: 0, second: 0, of: date),
                let blockEnd = calendar.date(bySettingHour: settings.dayJobEndHour, minute: 0, second: 0, of: date),
                blockStart < blockEnd
            else { continue }

            CalendarEventService.createEvent(
                type: .dayJob,
                startAt: blockStart,
                endAt: blockEnd,
                isHardCommitment: true,
                context: context
            )
        }
    }

    /// Removes any generated Day Job block(s) on `date` and records a durable override so
    /// `ensureBlocks` won't regenerate one there again. Manually adding a new `.dayJob` event on
    /// that day afterward (via the Calendar workspace's own Add Event) still works as an ad-hoc
    /// "undo" — `ensureBlocks` already skips any date that has an event, override or not.
    static func markDayOff(_ date: Date, context: ModelContext) throws {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) else { return }

        let blocks = try CalendarEventService.events(from: day, to: dayEnd, in: context)
            .filter { $0.eventType == .dayJob }
        for block in blocks {
            CalendarEventService.delete(block, context: context)
        }

        let alreadyOverridden = try context.fetch(
            FetchDescriptor<DayJobOverride>(predicate: #Predicate { $0.date == day })
        ).first
        if alreadyOverridden == nil {
            context.insert(DayJobOverride(date: day, isOff: true))
        }
    }
}
