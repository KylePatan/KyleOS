import SwiftUI
import SwiftData

/// Add/edit form for a Calendar Event, used by `CalendarHomeView`. One sheet for both modes
/// (mirrors `QuickAddButton`'s "one sheet switched by kind" choice) since add/edit share every
/// field except which CalendarEventService call runs on Save.
struct CalendarEventFormSheet: View {
    enum Mode {
        case add(defaultDate: Date)
        case edit(CalendarEventService.CalendarEvent)
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var eventType: CalendarEventService.CalendarEventType = .personal
    @State private var startAt = Date()
    @State private var endAt = Date().addingTimeInterval(3600)
    @State private var isAllDay = false
    @State private var availability: CalendarEventService.Availability = .busy
    @State private var isHardCommitment = false
    @State private var isLocked = false
    @State private var notes = ""
    @State private var location = ""

    private var isEditingLinkedEvent: Bool {
        if case .edit(let event) = mode {
            return event.project != nil || event.workItem != nil || event.deadline != nil
                || event.gig != nil || event.filmShoot != nil
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
            Text(isEditing ? "Edit Event" : "Add Event").font(.headline).foregroundStyle(RetroTheme.primaryText)

            if isEditingLinkedEvent {
                Text("This event is managed by another module (Gig, Shoot, Deadline, etc.) — details here stay in sync automatically. Edit the source instead for type/ownership changes.")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            }

            Picker("Type", selection: $eventType) {
                ForEach(CalendarEventService.CalendarEventType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .disabled(isEditingLinkedEvent)

            Toggle("All day", isOn: $isAllDay)
            Toggle("Locked (requires explicit confirmation to move)", isOn: $isLocked)

            if isAllDay {
                DatePicker("Date", selection: $startAt, displayedComponents: .date)
                    .disabled(isLocked)
            } else {
                DatePicker("Starts", selection: $startAt)
                    .disabled(isLocked)
                DatePicker("Ends", selection: $endAt)
                    .disabled(isLocked)
            }

            Picker("Availability", selection: $availability) {
                ForEach(CalendarEventService.Availability.allCases, id: \.self) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            Toggle("Hard commitment", isOn: $isHardCommitment)

            TextField("Location", text: $location).retroInputStyle()
            TextField("Notes", text: $notes, axis: .vertical).retroInputStyle()

            HStack {
                if case .edit(let event) = mode {
                    Button("Delete", role: .destructive) {
                        // Deleting a .dayJob block is an override (PRD §11.4) — must not
                        // silently regenerate; see DayJobScheduleService.markDayOff.
                        if event.eventType == .dayJob {
                            try? DayJobScheduleService.markDayOff(event.startAt, context: context)
                        } else {
                            CalendarEventService.delete(event, context: context)
                        }
                        try? context.save()
                        dismiss()
                    }
                    .buttonStyle(.retro)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.retro)
                Button("Save", action: save)
                    .buttonStyle(.retroProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isAllDay && endAt <= startAt)
            }
        }
        .padding(RetroTheme.sectionPadding + 8)
        .frame(minWidth: 420)
        .background(RetroTheme.panelBackground)
        .onAppear(perform: populateFromExistingEventIfNeeded)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func populateFromExistingEventIfNeeded() {
        switch mode {
        case .add(let defaultDate):
            startAt = defaultDate
            endAt = defaultDate.addingTimeInterval(3600)
        case .edit(let event):
            eventType = event.eventType
            startAt = event.startAt
            endAt = event.endAt
            isAllDay = event.isAllDay
            availability = event.availability
            isHardCommitment = event.isHardCommitment
            isLocked = event.isLocked
            notes = event.notes
            location = event.location
        }
    }

    private func save() {
        let resolvedEnd = isAllDay ? startAt : endAt
        switch mode {
        case .add:
            let event = CalendarEventService.createEvent(
                type: eventType,
                startAt: startAt,
                endAt: resolvedEnd,
                isAllDay: isAllDay,
                availability: availability,
                isHardCommitment: isHardCommitment,
                notes: notes,
                location: location,
                context: context
            )
            CalendarEventService.setLocked(event, isLocked)
        case .edit(let event):
            CalendarEventService.setLocked(event, isLocked)
            CalendarEventService.reschedule(event, startAt: startAt, endAt: resolvedEnd)
            CalendarEventService.setAvailability(event, to: availability)
            CalendarEventService.setHardCommitment(event, isHardCommitment)
            CalendarEventService.updateDetails(event, notes: notes, location: location)
            CalendarEventService.setAllDay(event, isAllDay)
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    CalendarEventFormSheet(mode: .add(defaultDate: .now))
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
