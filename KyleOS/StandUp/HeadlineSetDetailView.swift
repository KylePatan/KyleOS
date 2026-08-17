import SwiftUI
import SwiftData

/// PRD §7.7: Headline Set detail — title/notes/target duration, its ordered Chunks (draggable/
/// reorderable, removable without deleting the Chunk), current runtime vs target, and adding
/// loose Chunks into it.
struct HeadlineSetDetailView: View {
    let headlineSet: HeadlineSetService.HeadlineSet
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var notes = ""
    @State private var targetMinutes = 60

    /// Live @Query, not `HeadlineSetService.chunks(in:)`/`looseChunks(in:)` (which read
    /// `headlineSet.chunks` off this plain-held reference) — same class of stale-list bug
    /// confirmed for Add Scene (see SceneListView.swift's doc comment). Re-sorted in-memory to
    /// match the original service functions' sort keys exactly.
    @Query private var allChunks: [ChunkService.Chunk]

    private var memberChunks: [ChunkService.Chunk] {
        allChunks
            .filter { $0.headlineSet?.persistentModelID == headlineSet.persistentModelID }
            .sorted { $0.displayOrderInHeadlineSet < $1.displayOrderInHeadlineSet }
    }
    private var addableChunks: [ChunkService.Chunk] {
        allChunks
            .filter { $0.headlineSet == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }
    private var totalRuntimeSeconds: Int {
        HeadlineSetService.totalRuntimeSeconds(for: headlineSet)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
            header
            runtimeSummary
            chunksSection
            Spacer(minLength: 0)
        }
        .padding(RetroTheme.sectionPadding)
        .background(RetroTheme.background)
        .navigationTitle(headlineSet.title)
        .onAppear {
            title = headlineSet.title
            notes = headlineSet.notes
            targetMinutes = headlineSet.targetDurationMinutes
        }
    }

    private var header: some View {
        RetroPanel {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                TextField("Headline set title", text: $title)
                    .font(.title3.bold())
                    .textFieldStyle(.plain)
                    .foregroundStyle(RetroTheme.primaryText)
                    .onChange(of: title) {
                        HeadlineSetService.rename(headlineSet, to: title)
                        try? context.save()
                    }
                TextField("Notes", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(WritingSurfaceFont.swiftUI(size: 13))
                    .foregroundStyle(RetroTheme.secondaryText)
                    .onChange(of: notes) {
                        HeadlineSetService.updateNotes(headlineSet, notes: notes)
                        try? context.save()
                    }
                Stepper("Target: \(targetMinutes) min", value: $targetMinutes, in: 0...180, step: 5)
                    .onChange(of: targetMinutes) {
                        HeadlineSetService.updateTargetDuration(headlineSet, minutes: targetMinutes)
                        try? context.save()
                    }
            }
        }
    }

    /// PRD §7.7: "display current runtime versus target."
    private var runtimeSummary: some View {
        HStack(spacing: 12) {
            Text("Current: \(TimeFormatting.shortDuration(totalRuntimeSeconds))")
            Text("Target: \(TimeFormatting.shortDuration(HeadlineSetService.targetDurationSeconds(for: headlineSet)))")
        }
        .font(.caption)
        .foregroundStyle(RetroTheme.secondaryText)
    }

    private var chunksSection: some View {
        RetroPanel("Chunks in this Set") {
            VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                if !addableChunks.isEmpty {
                    Menu("Add Chunk") {
                        ForEach(addableChunks) { chunk in
                            Button(chunk.title) {
                                HeadlineSetService.addChunk(chunk, to: headlineSet)
                                try? context.save()
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                if memberChunks.isEmpty {
                    Text("No chunks in this set yet.")
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    List {
                        ForEach(memberChunks) { chunk in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chunk.title).font(.callout.bold()).foregroundStyle(RetroTheme.primaryText)
                                    Text("\(ChunkService.jokes(in: chunk).count) joke\(ChunkService.jokes(in: chunk).count == 1 ? "" : "s") · \(TimeFormatting.shortDuration(chunk.runtimeSeconds ?? 0))")
                                        .font(.caption)
                                        .foregroundStyle(RetroTheme.secondaryText)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    HeadlineSetService.removeChunk(chunk, from: headlineSet)
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
                            HeadlineSetService.reorderChunks(in: headlineSet, movingFromOffsets: source, toOffset: destination)
                            try? context.save()
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(height: max(120, CGFloat(memberChunks.count) * 50 + 20))
                }
            }
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let set = HeadlineSetService.createHeadlineSet(title: "Fall Tour Set", context: context)
    let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
    chunk.runtimeSeconds = 300
    HeadlineSetService.addChunk(chunk, to: set)
    return NavigationStack {
        HeadlineSetDetailView(headlineSet: set)
    }
    .modelContainer(container)
}
