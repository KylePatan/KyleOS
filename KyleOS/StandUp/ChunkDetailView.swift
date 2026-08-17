import SwiftUI
import SwiftData

/// PRD §7.6/§7.11: Chunk detail — title/notes/status, its ordered Jokes (draggable within the
/// Chunk, removable without deleting the Joke), adding loose Jokes into it, and starting a timed
/// session against this Chunk (§7.11). No `ActiveTimerBanner` here — `StandUpHomeView` already
/// shows one at the container level, shared across all Stand Up screens.
struct ChunkDetailView: View {
    let chunk: ChunkService.Chunk
    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController

    @State private var title = ""
    @State private var notes = ""

    /// Live @Query, not `ChunkService.jokes(in: chunk)` (which reads `chunk.jokes` off this
    /// plain-held `chunk` reference) — same class of stale-list bug confirmed for Add Scene (see
    /// SceneListView.swift's doc comment). "Add Joke" re-parents an *existing* Joke rather than
    /// inserting a new one, but the underlying risk is identical: reading a to-many relationship
    /// off a held parent isn't reliably observed when it changes via the child's own inverse
    /// property. Query's own sort key is arbitrary — each computed property below re-sorts to
    /// match what `ChunkService.jokes(in:)`/`looseJokes(in:)` used to (displayOrderWithinChunk,
    /// createdAt respectively), so behavior stays identical, just reactive now.
    @Query private var allJokes: [JokeService.Joke]

    private var memberJokes: [JokeService.Joke] {
        allJokes
            .filter { $0.chunk?.persistentModelID == chunk.persistentModelID }
            .sorted { $0.displayOrderWithinChunk < $1.displayOrderWithinChunk }
    }
    private var addableJokes: [JokeService.Joke] {
        allJokes
            .filter { $0.chunk == nil && !$0.isArchived }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Kyle (2026-08-17): deadlines belong on "each thing created individually," not just
    /// Projects — same lazy-WorkItem pattern as ProseEditorView/ActOutlineView.
    @Query private var allWorkItems: [WorkItemService.WorkItem]

    private var workItem: WorkItemService.WorkItem? {
        allWorkItems.first { $0.chunk?.persistentModelID == chunk.persistentModelID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
            header
            jokesSection
            Spacer(minLength: 0)
        }
        .padding(RetroTheme.sectionPadding)
        .background(RetroTheme.background)
        .navigationTitle(chunk.title)
        .onAppear {
            title = chunk.title
            notes = chunk.notes
        }
    }

    private var header: some View {
        RetroPanel {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                TextField("Chunk title", text: $title)
                    .font(.title3.bold())
                    .textFieldStyle(.plain)
                    .foregroundStyle(RetroTheme.primaryText)
                    .onChange(of: title) {
                        ChunkService.rename(chunk, to: title)
                        try? context.save()
                    }
                TextField("Notes", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(WritingSurfaceFont.swiftUI(size: 13))
                    .foregroundStyle(RetroTheme.secondaryText)
                    .onChange(of: notes) {
                        ChunkService.updateNotes(chunk, notes: notes)
                        try? context.save()
                    }
                Picker("Status", selection: Binding(
                    get: { chunk.status },
                    set: { ChunkService.changeStatus(chunk, to: $0, context: context); try? context.save() }
                )) {
                    ForEach(JokeService.JokeStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .frame(width: 160)
                HStack {
                    if timerController.state == .idle {
                        Button("Start Timer") {
                            guard let workItem = try? WorkItemService.standUpWorkItem(for: chunk, context: context) else { return }
                            timerController.start(workItem: workItem, targetDurationMinutes: nil, progressBefore: workItem.progress, context: context)
                            try? context.save()
                        }
                        .buttonStyle(.retroProminent)
                    }
                    DeadlineControl(
                        dueAt: workItem?.deadline?.dueAt,
                        isHard: workItem?.deadline?.isHard ?? true,
                        onSet: { dueAt, isHard in
                            guard let resolvedWorkItem = try? WorkItemService.standUpWorkItem(for: chunk, context: context) else { return }
                            DeadlineService.setDeadline(for: resolvedWorkItem, label: chunk.title, dueAt: dueAt, isHard: isHard, context: context)
                            try? context.save()
                        },
                        onRemove: {
                            guard let workItem else { return }
                            DeadlineService.removeDeadline(for: workItem, context: context)
                            try? context.save()
                        }
                    )
                }
            }
        }
    }

    private var jokesSection: some View {
        RetroPanel("Jokes in this Chunk") {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                if !addableJokes.isEmpty {
                    Menu("Add Joke") {
                        ForEach(addableJokes) { joke in
                            Button(joke.title.isEmpty ? joke.text : joke.title) {
                                ChunkService.addJoke(joke, to: chunk)
                                try? context.save()
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                if memberJokes.isEmpty {
                    Text("No jokes in this chunk yet.")
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    List {
                        ForEach(memberJokes) { joke in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    if !joke.title.isEmpty {
                                        Text(joke.title).font(.callout.bold()).foregroundStyle(RetroTheme.primaryText)
                                    }
                                    Text(joke.text).font(.callout).lineLimit(2).foregroundStyle(RetroTheme.primaryText)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    ChunkService.removeJoke(joke, from: chunk)
                                    try? context.save()
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.retro)
                            }
                            .listRowBackground(RetroTheme.panelBackground)
                            .listRowSeparatorTint(RetroTheme.border.opacity(0.5))
                        }
                        .onMove { source, destination in
                            ChunkService.reorderJokes(in: chunk, movingFromOffsets: source, toOffset: destination)
                            try? context.save()
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(height: max(120, CGFloat(memberJokes.count) * 50 + 20))
                }
            }
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
    let joke = JokeService.quickCapture(text: "Airline food, but for cats.", context: context)
    ChunkService.addJoke(joke, to: chunk)
    return NavigationStack {
        ChunkDetailView(chunk: chunk)
    }
    .modelContainer(container)
    .environment(FocusTimerController())
}
