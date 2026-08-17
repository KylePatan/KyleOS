import SwiftUI
import SwiftData

/// PRD §7.8/§7.9/§7.10: Gig detail — venue/show/date/start time/set length/location/notes (all
/// editable, keeping the auto-created CalendarEvent in sync per "Gigs automatically appear on
/// Calendar"), the planned Set List built from existing Jokes/Chunks (§7.9), and After-Gig Notes
/// (§7.10) once the gig has passed.
struct GigDetailView: View {
    let gig: GigService.Gig
    @Environment(\.modelContext) private var context
    @Query(sort: \GigSetListService.Joke.createdAt) private var allJokes: [GigSetListService.Joke]
    @Query(sort: \GigSetListService.Chunk.createdAt) private var allChunks: [GigSetListService.Chunk]
    /// Live @Query, not `gig.setListItems` read via `GigSetListService.items(in:)` — same class of
    /// stale-list bug confirmed for Add Scene (see SceneListView.swift's doc comment); "Add to Set
    /// List" has the identical shape (a new GigSetListItem inserted, inverse-linked to `gig`).
    @Query(sort: \GigSetListService.GigSetListItem.order) private var allSetListItems: [GigSetListService.GigSetListItem]

    @State private var venue = ""
    @State private var show = ""
    @State private var startAt = Date.now
    @State private var setLengthMinutes = 10
    @State private var location = ""
    @State private var notes = ""
    @State private var afterGigNotes = ""

    private var setListItems: [GigSetListService.GigSetListItem] {
        allSetListItems.filter { $0.gig?.persistentModelID == gig.persistentModelID }
    }
    private var addableJokes: [GigSetListService.Joke] {
        let usedIDs = Set(setListItems.compactMap { $0.joke?.id })
        return allJokes.filter { !usedIDs.contains($0.id) }
    }
    private var addableChunks: [GigSetListService.Chunk] {
        let usedIDs = Set(setListItems.compactMap { $0.chunk?.id })
        return allChunks.filter { !usedIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                scheduleSection
                Divider()
                setListSection
                Divider()
                notesSection
                Divider()
                afterGigSection
            }
            .padding()
        }
        .navigationTitle(gig.venue)
        .onAppear {
            venue = gig.venue
            show = gig.show
            startAt = gig.startAt
            setLengthMinutes = gig.setLengthMinutes
            location = gig.location
            notes = gig.notes
            afterGigNotes = gig.displayAfterGigNotes
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

    /// PRD §7.9: "show the planned set duration versus the gig's target set length."
    private var setListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Set List").font(.headline)
                Spacer()
                if !addableJokes.isEmpty || !addableChunks.isEmpty {
                    Menu("Add to Set List") {
                        if !addableChunks.isEmpty {
                            Section("Chunks") {
                                ForEach(addableChunks) { chunk in
                                    Button(chunk.title) {
                                        GigSetListService.addChunk(chunk, to: gig, context: context)
                                        try? context.save()
                                    }
                                }
                            }
                        }
                        if !addableJokes.isEmpty {
                            Section("Jokes") {
                                ForEach(addableJokes) { joke in
                                    Button(joke.title.isEmpty ? joke.text : joke.title) {
                                        GigSetListService.addJoke(joke, to: gig, context: context)
                                        try? context.save()
                                    }
                                }
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            HStack(spacing: 12) {
                Text("Planned: \(TimeFormatting.shortDuration(GigSetListService.plannedDurationSeconds(for: gig)))")
                Text("Target: \(TimeFormatting.shortDuration(GigSetListService.targetDurationSeconds(for: gig)))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if setListItems.isEmpty {
                Text("No set list yet. Add Jokes or Chunks to plan this gig's set.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(setListItems) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.title)
                                Spacer()
                                Text(TimeFormatting.shortDuration(item.runtimeSeconds))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button(role: .destructive) {
                                    GigSetListService.removeItem(item, from: gig, context: context)
                                    try? context.save()
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                            /// PRD §7.10: per-item "how'd this land" note, scoped to this gig's
                            /// performance — bound directly to the model since each row is its
                            /// own SwiftData object, not a single shared `@State`.
                            TextField("How'd this land?", text: Binding(
                                get: { item.displayPerformanceNotes },
                                set: {
                                    GigSetListService.updatePerformanceNotes(item, notes: $0)
                                    try? context.save()
                                }
                            ))
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .onMove { source, destination in
                        GigSetListService.reorderItems(in: gig, movingFromOffsets: source, toOffset: destination)
                        try? context.save()
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 100, idealHeight: CGFloat(setListItems.count) * 60 + 20)
            }
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

    /// PRD §7.10: "After a gig, Kyle OS may optionally ask how the set went." Shown as a
    /// standing section (so notes can be added any time), but calls out the prompt visually once
    /// the gig has actually passed with nothing recorded yet — "optionally ask" without a full
    /// notification system (CLAUDE.md §9: don't prematurely build the reminder system).
    private var afterGigSection: some View {
        let needsNotes = GigService.needsAfterGigNotes(gig)
        return VStack(alignment: .leading, spacing: 8) {
            Text(needsNotes ? "How did the set go?" : "After the Gig")
                .font(.headline)
                .foregroundStyle(needsNotes ? .orange : .primary)
            TextField("After-gig notes", text: $afterGigNotes, axis: .vertical)
                .textFieldStyle(.plain)
                .onChange(of: afterGigNotes) {
                    GigService.updateAfterGigNotes(gig, notes: afterGigNotes)
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
