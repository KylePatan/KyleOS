import SwiftUI
import SwiftData

/// PRD §8.3/§8.4: Clip detail — title/description/source-timestamps/notes/editing-notes/status/
/// progress/post-date, plus an optional related Joke/Chunk reference. Also the Editing progress/
/// timer entry point (roadmap V0.4) — reuses the shared FocusTimerController/ActiveTimerBanner
/// verbatim, same pattern as ProseEditorView/ChunkDetailView.
struct ClipDetailView: View {
    let clip: ClipService.Clip
    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController
    @Query(sort: \ClipService.Joke.createdAt) private var allJokes: [ClipService.Joke]
    @Query(sort: \ClipService.Chunk.createdAt) private var allChunks: [ClipService.Chunk]

    /// Kyle (2026-08-17): deadlines belong on "each thing created individually," not just
    /// Projects — same lazy-WorkItem pattern as ProseEditorView/ChunkDetailView. Extended the same
    /// day to separate named deadlines per production stage ("finish editing", "finish
    /// subtitling"), so a Clip now has up to three WorkItems (Editing/Subtitling/Posting,
    /// distinguished by workTypeName — see WorkItemService's doc comment on `clipWorkItem`).
    @Query private var allWorkItems: [WorkItemService.WorkItem]

    private var editingWorkItem: WorkItemService.WorkItem? {
        allWorkItems.first { $0.clip?.persistentModelID == clip.persistentModelID && $0.workTypeName == "Clip Editing" }
    }

    private var subtitlingWorkItem: WorkItemService.WorkItem? {
        allWorkItems.first { $0.clip?.persistentModelID == clip.persistentModelID && $0.workTypeName == "Clip Subtitling" }
    }

    @State private var title = ""
    @State private var clipDescription = ""
    @State private var startSecondsText = ""
    @State private var endSecondsText = ""
    @State private var notes = ""
    @State private var editingNotes = ""
    @State private var progress = 0
    @State private var postDate = Date.now
    @State private var hasPostDate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                header
                timerSection
                timestampsSection
                statusSection
                relatedMaterialSection
                notesSection
            }
            .padding(RetroTheme.sectionPadding)
        }
        .background(RetroTheme.background)
        .navigationTitle(clip.title)
        .onAppear {
            title = clip.title
            clipDescription = clip.clipDescription
            startSecondsText = clip.sourceTimestampStartSeconds.map(String.init) ?? ""
            endSecondsText = clip.sourceTimestampEndSeconds.map(String.init) ?? ""
            notes = clip.notes
            editingNotes = clip.editingNotes
            progress = clip.progress
            if let date = clip.postDate {
                postDate = date
                hasPostDate = true
            }
        }
    }

    private var header: some View {
        RetroPanel {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                TextField("Clip title", text: $title)
                    .font(.title3.bold())
                    .textFieldStyle(.plain)
                    .foregroundStyle(RetroTheme.primaryText)
                    .onChange(of: title) {
                        ClipService.rename(clip, to: title)
                        try? context.save()
                    }
                TextField("Description", text: $clipDescription, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(RetroTheme.secondaryText)
                    .onChange(of: clipDescription) {
                        ClipService.updateDescription(clip, description: clipDescription)
                        try? context.save()
                    }
            }
        }
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
            ActiveTimerBanner()
            if timerController.state == .idle {
                Button("Start Timer") {
                    guard let workItem = try? WorkItemService.clipWorkItem(for: clip, context: context) else { return }
                    timerController.start(workItem: workItem, targetDurationMinutes: nil, progressBefore: workItem.progress, context: context)
                    try? context.save()
                }
                .buttonStyle(.retroProminent)
            }
            // Kyle (2026-08-17): "add a deadline to finish editing" / "add a deadline to finish
            // subtitling" — two separately-labeled, separately-trackable deadlines rather than one
            // generic one, each on its own WorkItem so it ranks into the Weekly Board's To Do
            // independently.
            HStack {
                DeadlineControl(
                    label: "Editing",
                    dueAt: editingWorkItem?.deadline?.dueAt,
                    isHard: editingWorkItem?.deadline?.isHard ?? true,
                    onSet: { dueAt, isHard in
                        guard let resolvedWorkItem = try? WorkItemService.clipWorkItem(for: clip, context: context) else { return }
                        DeadlineService.setDeadline(for: resolvedWorkItem, label: "Finish editing: \(clip.title)", dueAt: dueAt, isHard: isHard, context: context)
                        try? context.save()
                    },
                    onRemove: {
                        guard let editingWorkItem else { return }
                        DeadlineService.removeDeadline(for: editingWorkItem, context: context)
                        try? context.save()
                    }
                )
                DeadlineControl(
                    label: "Subtitling",
                    dueAt: subtitlingWorkItem?.deadline?.dueAt,
                    isHard: subtitlingWorkItem?.deadline?.isHard ?? true,
                    onSet: { dueAt, isHard in
                        guard let resolvedWorkItem = try? WorkItemService.clipSubtitlingWorkItem(for: clip, context: context) else { return }
                        DeadlineService.setDeadline(for: resolvedWorkItem, label: "Finish subtitling: \(clip.title)", dueAt: dueAt, isHard: isHard, context: context)
                        try? context.save()
                    },
                    onRemove: {
                        guard let subtitlingWorkItem else { return }
                        DeadlineService.removeDeadline(for: subtitlingWorkItem, context: context)
                        try? context.save()
                    }
                )
            }
        }
    }

    private var timestampsSection: some View {
        RetroPanel("Source Timestamps") {
            HStack {
                TextField("Start (sec)", text: $startSecondsText)
                    .retroInputStyle()
                    .frame(width: 100)
                    .onChange(of: startSecondsText) { saveTimestamps() }
                Text("–").foregroundStyle(RetroTheme.secondaryText)
                TextField("End (sec)", text: $endSecondsText)
                    .retroInputStyle()
                    .frame(width: 100)
                    .onChange(of: endSecondsText) { saveTimestamps() }
            }
        }
    }

    private func saveTimestamps() {
        ClipService.updateTimestamps(
            clip,
            startSeconds: Int(startSecondsText),
            endSeconds: Int(endSecondsText)
        )
        try? context.save()
    }

    private var statusSection: some View {
        RetroPanel("Status") {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                Picker("Status", selection: Binding(
                    get: { clip.status },
                    set: {
                        ClipService.changeStatus(clip, to: $0, context: context)
                        try? context.save()
                    }
                )) {
                    ForEach(ClipService.ClipStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .frame(width: 260)
                Stepper("Progress: \(progress)%", value: $progress, in: 0...100, step: 5)
                    .onChange(of: progress) {
                        ClipService.updateProgress(clip, progress: progress)
                        try? context.save()
                    }
                Toggle("Post date", isOn: $hasPostDate)
                    .onChange(of: hasPostDate) {
                        savePostDate(hasPostDate ? postDate : nil)
                    }
                if hasPostDate {
                    DatePicker("", selection: $postDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .onChange(of: postDate) {
                            savePostDate(postDate)
                        }
                } else if let recommended = PostingItemService.recommendedPostDate(in: context) {
                    // Kyle (2026-08-17): "have the recommended post dates" — confirmed to mean
                    // "depending on the settings for when we should post [the weekly posting-goal
                    // Stepper in Post It] - it slots it into there." A starting suggestion, not a
                    // persistent nag — disappears once a real date is set.
                    Button {
                        postDate = recommended
                        hasPostDate = true
                        savePostDate(recommended)
                    } label: {
                        Text("Recommended: \(recommended.formatted(date: .abbreviated, time: .omitted))")
                    }
                    .buttonStyle(.retro)
                }
            }
        }
    }

    /// Kyle (2026-08-17): post dates should "show up in my calendar - as well as my to do," and
    /// this screen's own Toggle+DatePicker used to call `ClipService.setPostDate` directly —
    /// bypassing `PostingItem` (and its Calendar/To-Do sync) entirely, even though the Post It tab
    /// on Home already managed post dates through it. Routing through `PostingItemService` here
    /// instead unifies both into the one real source of truth.
    private func savePostDate(_ date: Date?) {
        let item = PostingItemService.findOrCreate(for: clip, context: context)
        PostingItemService.setConfirmedPostDate(item, date: date, context: context)
        try? context.save()
    }

    private var linkedJokeLabel: String {
        guard let joke = clip.joke else { return "Link Joke" }
        return joke.title.isEmpty ? joke.text : joke.title
    }

    /// PRD §8.3: "related Joke/Chunk reference."
    private var relatedMaterialSection: some View {
        RetroPanel("Related Material") {
            HStack {
                Menu(linkedJokeLabel) {
                    Button("None") {
                        ClipService.linkJoke(clip, to: nil)
                        try? context.save()
                    }
                    ForEach(allJokes) { joke in
                        Button(joke.title.isEmpty ? joke.text : joke.title) {
                            ClipService.linkJoke(clip, to: joke)
                            try? context.save()
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Menu(clip.chunk?.title ?? "Link Chunk") {
                    Button("None") {
                        ClipService.linkChunk(clip, to: nil)
                        try? context.save()
                    }
                    ForEach(allChunks) { chunk in
                        Button(chunk.title) {
                            ClipService.linkChunk(clip, to: chunk)
                            try? context.save()
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private var notesSection: some View {
        RetroPanel {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                Text("Notes").font(.headline).foregroundStyle(RetroTheme.primaryText)
                TextField("Notes", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(RetroTheme.primaryText)
                    .onChange(of: notes) {
                        ClipService.updateNotes(clip, notes: notes)
                        try? context.save()
                    }
                Text("Editing Notes").font(.headline).foregroundStyle(RetroTheme.primaryText)
                TextField("Editing notes", text: $editingNotes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(RetroTheme.primaryText)
                    .onChange(of: editingNotes) {
                        ClipService.updateEditingNotes(clip, notes: editingNotes)
                        try? context.save()
                    }
            }
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let source = SourceService.createSource(title: "March Comedy Slam", context: context)
    let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
    return NavigationStack {
        ClipDetailView(clip: clip)
    }
    .modelContainer(container)
    .environment(FocusTimerController())
}
