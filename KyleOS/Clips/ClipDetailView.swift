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
                        ClipService.setPostDate(clip, date: hasPostDate ? postDate : nil)
                        try? context.save()
                    }
                if hasPostDate {
                    DatePicker("", selection: $postDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: postDate) {
                            ClipService.setPostDate(clip, date: postDate)
                            try? context.save()
                        }
                }
            }
        }
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
