import Foundation
import SwiftData

/// PRD §4.1's "What is coming up on the calendar?" / roadmap's "Basic month calendar" for V0.1
/// Home. Deliberately basic: read-only, no drag-reschedule, no Google Calendar sync (V0.6, CLAUDE.md
/// §8). "The Home calendar uses the same data source as the Calendar workspace" (PRD §11.3) — this
/// reads the same CalendarEvent model the full Calendar workspace (still a placeholder) will use.
enum MonthCalendarService {
    typealias CalendarEvent = KyleOSSchemaV25.CalendarEvent

    struct DayCell: Identifiable, Equatable {
        let date: Date
        let isInCurrentMonth: Bool
        var id: Date { date }
    }

    /// A full-week grid (always a multiple of 7) covering the month containing `date`, padded
    /// with the trailing days of the prior/next month so every displayed week is complete.
    static func grid(for date: Date, calendar: Calendar = .current) -> [DayCell] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let monthStart = monthInterval.start

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = ((firstWeekday - calendar.firstWeekday) % 7 + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingEmptyDays, to: monthStart) else { return [] }

        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 0
        let cellsBeforeTrailing = leadingEmptyDays + daysInMonth
        let trailingDays = (7 - (cellsBeforeTrailing % 7)) % 7
        let totalCells = cellsBeforeTrailing + trailingDays

        return (0..<totalCells).compactMap { offset in
            guard let cellDate = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            return DayCell(date: cellDate, isInCurrentMonth: calendar.isDate(cellDate, equalTo: date, toGranularity: .month))
        }
    }

    static func events(on day: Date, from events: [CalendarEvent], calendar: Calendar = .current) -> [CalendarEvent] {
        events
            .filter { calendar.isDate($0.startAt, inSameDayAs: day) }
            .sorted { $0.startAt < $1.startAt }
    }
}
