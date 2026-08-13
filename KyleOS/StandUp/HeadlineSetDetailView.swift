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

    private var memberChunks: [ChunkService.Chunk] {
        HeadlineSetService.chunks(in: headlineSet)
    }
    private var addableChunks: [ChunkService.Chunk] {
        HeadlineSetService.looseChunks(in: context)
    }
    private var totalRuntimeSeconds: Int {
        HeadlineSetService.totalRuntimeSeconds(for: headlineSet)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            runtimeSummary
            Divider()
            chunksSection
        }
        .padding()
        .navigationTitle(headlineSet.title)
        .onAppear {
            title = headlineSet.title
            notes = headlineSet.notes
            targetMinutes = headlineSet.targetDurationMinutes
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Headline set title", text: $title)
                .font(.title3.bold())
                .textFieldStyle(.plain)
                .onChange(of: title) {
                    HeadlineSetService.rename(headlineSet, to: title)
                    try? context.save()
                }
            TextField("Notes", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
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

    /// PRD §7.7: "display current runtime versus target."
    private var runtimeSummary: some View {
        HStack(spacing: 12) {
            Text("Current: \(TimeFormatting.shortDuration(totalRuntimeSeconds))")
            Text("Target: \(TimeFormatting.shortDuration(HeadlineSetService.targetDurationSeconds(for: headlineSet)))")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var chunksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Chunks in this Set").font(.headline)
                Spacer()
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
            }
            if memberChunks.isEmpty {
                Text("No chunks in this set yet.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(memberChunks) { chunk in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chunk.title).font(.callout.bold())
                                Text("\(ChunkService.jokes(in: chunk).count) joke\(ChunkService.jokes(in: chunk).count == 1 ? "" : "s") · \(TimeFormatting.shortDuration(chunk.runtimeSeconds ?? 0))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                HeadlineSetService.removeChunk(chunk, from: headlineSet)
                                try? context.save()
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .onMove { source, destination in
                        HeadlineSetService.reorderChunks(in: headlineSet, movingFromOffsets: source, toOffset: destination)
                        try? context.save()
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 120, idealHeight: CGFloat(memberChunks.count) * 50 + 20)
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
