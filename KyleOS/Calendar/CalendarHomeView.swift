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
    @Query private var allSettings: [CreativeCapacityService.AppSettings]
    @Query private var allPlannedSessions: [CreativeCapacityService.PlannedSession]
    @Query private var allCapacityOverrides: [CreativeCapacityService.CapacityOverride]

    @State private var displayedMonth: Date = .now
    @State private var selectedDay: Date = .now
    @State private var editingEvent: CalendarEventService.CalendarEvent?
    @State private var isAddingEvent = false
    @State private var hasCapacityOverride = false
    @State private var overrideHours: Double = 0
    @State private var reflowSummary: ReflowSummary?

    private var calendar: Calendar { .current }
    private var days: [MonthCalendarService.DayCell] {
        MonthCalendarService.grid(for: displayedMonth, calendar: calendar)
    }
    private var selectedDayEvents: [CalendarEventService.CalendarEvent] {
        MonthCalendarService.events(on: selectedDay, from: allEvents, calendar: calendar)
    }
    private var selectedDayCapacity: CreativeCapacityService.Summary? {
        guard let settings = allSettings.first else { return nil }
        return CreativeCapacityService.todaysCapacity(
            settings: settings,
            events: allEvents,
            plannedSessions: allPlannedSessions,
            overrides: allCapacityOverrides,
            calendar: calendar,
            now: selectedDay
        )
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
            Divider()
            capacitySection
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
        .sheet(item: $reflowSummary) { summary in
            CascadeReflowSummaryView(summary: summary)
        }
        .onAppear {
            ensureDayJobBlocksForDisplayedMonth()
            reloadCapacityOverride()
        }
        .onChange(of: displayedMonth) { ensureDayJobBlocksForDisplayedMonth() }
        .onChange(of: selectedDay) { reloadCapacityOverride() }
    }

    /// PRD §11.4: generates Day Job blocks lazily for whatever month is actually being viewed —
    /// no background pre-generation. Home's own read-only MonthCalendarView deliberately does
    /// NOT call this (it must stay side-effect-free), so Day Job blocks only appear there once
    /// the Calendar workspace has generated them for that month at least once.
    private func ensureDayJobBlocksForDisplayedMonth() {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return }
        try? DayJobScheduleService.ensureBlocks(from: interval.start, to: interval.end, context: context)
        try? context.save()
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
                deleteEvent(event)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .font(.callout)
    }

    /// PRD §11.6: "The user can override a day's expected Creative Capacity, including setting it
    /// to zero or increasing it for a free day."
    private var capacitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Creative Capacity").font(.headline)
            if let summary = selectedDayCapacity {
                HStack {
                    Text("\(formatted(summary.baselineHours)) available, \(formatted(summary.scheduledHours)) scheduled, \(formatted(summary.remainingHours)) remaining")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if summary.isOverridden {
                        Text("Overridden").font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            Toggle("Override this day's capacity", isOn: $hasCapacityOverride)
                .onChange(of: hasCapacityOverride) { saveCapacityOverrideToggle() }
            if hasCapacityOverride {
                Stepper("Capacity: \(formatted(overrideHours))", value: $overrideHours, in: 0...24, step: 0.5)
                    .onChange(of: overrideHours) { saveCapacityOverrideHours() }
            }
        }
    }

    private func formatted(_ hours: Double) -> String {
        hours.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(hours))h" : String(format: "%.1fh", hours)
    }

    private func reloadCapacityOverride() {
        if let existing = try? CreativeCapacityService.override(for: selectedDay, in: context, calendar: calendar) {
            hasCapacityOverride = true
            overrideHours = existing.hours
        } else {
            hasCapacityOverride = false
            overrideHours = selectedDayCapacity?.baselineHours ?? 0
        }
    }

    private func saveCapacityOverrideToggle() {
        if hasCapacityOverride {
            try? CreativeCapacityService.setOverride(for: selectedDay, hours: overrideHours, context: context, calendar: calendar)
        } else {
            try? CreativeCapacityService.clearOverride(for: selectedDay, context: context, calendar: calendar)
        }
        try? context.save()
        runCascadeReflow()
    }

    private func saveCapacityOverrideHours() {
        guard hasCapacityOverride else { return }
        try? CreativeCapacityService.setOverride(for: selectedDay, hours: overrideHours, context: context, calendar: calendar)
        try? context.save()
        runCascadeReflow()
    }

    /// PRD §4.6/Decision Gate B: lowering a day's Creative Capacity is exactly the "blocked off
    /// things" moment Kyle described — already-planned flexible work should reflow to fit, and
    /// he should see what moved (or what didn't fit anywhere), not have it happen invisibly.
    /// Quiet when nothing actually needed to move — only a genuine reshuffle surfaces the sheet.
    private func runCascadeReflow() {
        guard let settings = allSettings.first else { return }
        let result = CascadeReschedulingService.reflow(
            startingFrom: selectedDay,
            settings: settings,
            calendarEvents: allEvents,
            capacityOverrides: allCapacityOverrides,
            allSessions: allPlannedSessions,
            calendar: calendar
        )
        guard !result.moves.isEmpty || !result.unresolved.isEmpty else { return }
        try? context.save()
        reflowSummary = ReflowSummary(moves: result.moves, unresolved: result.unresolved)
    }

    /// Deleting a `.dayJob` block specifically means "override this day off" (PRD §11.4) — must
    /// not silently regenerate the next time this month is viewed. Every other event type just
    /// deletes normally.
    private func deleteEvent(_ event: CalendarEventService.CalendarEvent) {
        if event.eventType == .dayJob {
            try? DayJobScheduleService.markDayOff(event.startAt, context: context)
        } else {
            CalendarEventService.delete(event, context: context)
        }
        try? context.save()
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

/// Wraps a `CascadeReschedulingService.ReflowResult` for `.sheet(item:)` presentation.
struct ReflowSummary: Identifiable {
    let id = UUID()
    let moves: [CascadeReschedulingService.Move]
    let unresolved: [CascadeReschedulingService.PlannedSession]
}

/// What actually happened when lowering a day's Creative Capacity triggered a cascade reflow —
/// PRD §4.6's "Kyle OS must flag the conflict," made visible rather than silent.
struct CascadeReflowSummaryView: View {
    let summary: ReflowSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule Adjusted").font(.headline)
            if !summary.moves.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Moved").font(.subheadline.bold())
                    ForEach(summary.moves, id: \.session.id) { move in
                        HStack {
                            Text(move.session.workItem?.title ?? "Untitled")
                            Spacer()
                            Text("\(move.from.formatted(.dateTime.month().day())) → \(move.to.formatted(.dateTime.month().day()))")
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }
            }
            if !summary.unresolved.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Couldn't Find Room").font(.subheadline.bold())
                    ForEach(summary.unresolved, id: \.id) { session in
                        Text(session.workItem?.title ?? "Untitled")
                            .font(.callout)
                    }
                    Text("No spare capacity in the next 30 days — these stayed where they were.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

#Preview {
    NavigationStack {
        CalendarHomeView()
    }
    .modelContainer(PersistenceController.makeInMemoryContainer())
}
