import SwiftUI
import SwiftData

/// Roadmap's "Basic month calendar" for V0.1 Home — read-only browsing of CalendarEvent by
/// month/day. Not the full Calendar workspace (PRD §11, still a nav placeholder): no drag-
/// reschedule, no Google Calendar sync (V0.6, CLAUDE.md §8), no Gig/Shoot-specific rendering.
struct MonthCalendarView: View {
    @Query(sort: \MonthCalendarService.CalendarEvent.startAt)
    private var allEvents: [MonthCalendarService.CalendarEvent]

    @State private var displayedMonth: Date = .now
    @State private var selectedDay: Date = .now

    private var calendar: Calendar { .current }
    private var days: [MonthCalendarService.DayCell] {
        MonthCalendarService.grid(for: displayedMonth, calendar: calendar)
    }
    private var selectedDayEvents: [MonthCalendarService.CalendarEvent] {
        MonthCalendarService.events(on: selectedDay, from: allEvents, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            weekdayLabels
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days) { cell in
                    dayCell(cell)
                }
            }
            Divider()
            selectedDaySection
        }
        .padding()
    }

    private var header: some View {
        HStack {
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.title3.bold())
            Spacer()
            Button { shiftMonth(by: -1) } label: { Image(systemName: "chevron.left") }
            Button("Today") {
                displayedMonth = .now
                selectedDay = .now
            }
            Button { shiftMonth(by: 1) } label: { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.borderless)
    }

    private var weekdayLabels: some View {
        HStack {
            ForEach(shortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ cell: MonthCalendarService.DayCell) -> some View {
        let dayEventCount = MonthCalendarService.events(on: cell.date, from: allEvents, calendar: calendar).count
        let isSelected = calendar.isDate(cell.date, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(cell.date)

        return Button {
            selectedDay = cell.date
        } label: {
            VStack(spacing: 2) {
                Text(cell.date, format: .dateTime.day())
                    .font(.callout)
                    .fontWeight(isToday ? .bold : .regular)
                if dayEventCount > 0 {
                    Circle().frame(width: 4, height: 4)
                } else {
                    Circle().frame(width: 4, height: 4).opacity(0)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .foregroundStyle(cell.isInCurrentMonth ? .primary : .secondary)
            .padding(4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedDay, format: .dateTime.weekday(.wide).month().day())
                .font(.headline)
            if selectedDayEvents.isEmpty {
                Text("Nothing on the calendar.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(selectedDayEvents) { event in
                    HStack {
                        Text(event.startAt, format: .dateTime.hour().minute())
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        Text(event.eventType.rawValue)
                        if !event.notes.isEmpty {
                            Text(event.notes)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout)
                }
            }
        }
    }

    private var shortWeekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    private func shiftMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = newMonth
    }
}

#Preview {
    MonthCalendarView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
