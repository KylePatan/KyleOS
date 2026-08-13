import SwiftUI
import SwiftData

/// PRD §7.8: Gig detail — venue/show/date/start time/set length/location/notes, all editable.
/// Edits keep the auto-created CalendarEvent (`gig.calendarEvent`) in sync so the gig stays
/// correctly reflected on Calendar, per "Gigs automatically appear on Calendar."
struct GigDetailView: View {
    let gig: GigService.Gig
    @Environment(\.modelContext) private var context

    @State private var venue = ""
    @State private var show = ""
    @State private var startAt = Date.now
    @State private var setLengthMinutes = 10
    @State private var location = ""
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            scheduleSection
            Divider()
            notesSection
        }
        .padding()
        .navigationTitle(gig.venue)
        .onAppear {
            venue = gig.venue
            show = gig.show
            startAt = gig.startAt
            setLengthMinutes = gig.setLengthMinutes
            location = gig.location
            notes = gig.notes
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Venue", text: $venue)
                .font(.title3.bold())
                .textFieldStyle(.plain)
                .onChange(of: venue) {
                    GigService.rename(gig, venue: venue)
                    try? context.save()
                }
            TextField("Show", text: $show)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .onChange(of: show) {
                    GigService.rename(gig, show: show)
                    try? context.save()
                }
            TextField("Location", text: $location)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .onChange(of: location) {
                    GigService.updateLocation(gig, location: location)
                    try? context.save()
                }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker("Start", selection: $startAt)
                .onChange(of: startAt) {
                    GigService.reschedule(gig, startAt: startAt, setLengthMinutes: setLengthMinutes)
                    try? context.save()
                }
            Stepper("Set length: \(setLengthMinutes) min", value: $setLengthMinutes, in: 1...60, step: 1)
                .onChange(of: setLengthMinutes) {
                    GigService.reschedule(gig, startAt: startAt, setLengthMinutes: setLengthMinutes)
                    try? context.save()
                }
            Text("Automatically appears on Calendar as a Stand-Up Gig.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.headline)
            TextField("Notes", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .onChange(of: notes) {
                    GigService.updateNotes(gig, notes: notes)
                    try? context.save()
                }
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let gig = GigService.createGig(venue: "The Comedy Cellar", show: "Late Show", startAt: .now, setLengthMinutes: 15, context: context)
    return NavigationStack {
        GigDetailView(gig: gig)
    }
    .modelContainer(container)
}
