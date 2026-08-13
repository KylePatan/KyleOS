import SwiftUI
import SwiftData

/// PRD §11: the full Calendar workspace — "Primary V1 view: Month." Unlike Home's read-only
/// `MonthCalendarView` widget (which this reuses `MonthCalendarService`'s grid/filter logic
/// from, per §11.2 "The Home calendar uses the same data source as the Calendar workspace"),
/// this screen supports creating, editing, and deleting Calendar Events directly. Still no
/// Google Calendar sync (V0.6's OAuth/two-way-sync half is deferred — CLAUDE.md §8 — until Kyle
/// provisions his own Google Cloud OAuth credentials; that's not something buildable in the
/// abstract).
struct CalendarHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CalendarEventService.CalendarEvent.startAt)
    private var allEvents: [CalendarEventService.CalendarEvent]

    @State private var displayedMonth: Date = .now
    @State private var selectedDay: Date = .now
    @State private var editingEvent: CalendarEventService.CalendarEvent?
    @State private var isAddingEvent = false

    private var calendar: Calendar { .current }
    private var days: [MonthCalendarService.DayCell] {
        MonthCalendarService.grid(for: displayedMonth, calendar: calendar)
    }
    private var selectedDayEvents: [CalendarEventService.CalendarEvent] {
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
            Spacer()
        }
        .padding()
        .navigationTitle("Calendar")
        .sheet(item: $editingEvent) { event in
            CalendarEventFormSheet(mode: .edit(event))
        }
        .sheet(isPresented: $isAddingEvent) {
            CalendarEventFormSheet(mode: .add(defaultDate: selectedDay))
        }
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
            Divider().frame(height: 16)
            Button("Add Event") { isAddingEvent = true }
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
        let dayEvents = MonthCalendarService.events(on: cell.date, from: allEvents, calendar: calendar)
        let isSelected = calendar.isDate(cell.date, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(cell.date)

        return Button {
            selectedDay = cell.date
        } label: {
            VStack(spacing: 2) {
                Text(cell.date, format: .dateTime.day())
                    .font(.callout)
                    .fontWeight(isToday ? .bold : .regular)
                HStack(spacing: 2) {
                    ForEach(dayEvents.prefix(3)) { event in
                        Circle()
                            .fill(event.isHardCommitment ? Color.red : Color.accentColor)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
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
                    eventRow(event)
                }
            }
        }
    }

    private func eventRow(_ event: CalendarEventService.CalendarEvent) -> some View {
        HStack {
            if event.isLocked {
                Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
            }
            Text(event.isAllDay ? "All day" : event.startAt.formatted(.dateTime.hour().minute()))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(event.eventType.rawValue)
                .fontWeight(event.isHardCommitment ? .semibold : .regular)
            if !event.notes.isEmpty {
                Text(event.notes)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                editingEvent = event
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            Button(role: .destructive) {
                CalendarEventService.delete(event, context: context)
                try? context.save()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .font(.callout)
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
    NavigationStack {
        CalendarHomeView()
    }
    .modelContainer(PersistenceController.makeInMemoryContainer())
}
