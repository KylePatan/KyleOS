import SwiftUI
import SwiftData

/// PRD §7.5-§7.6: "A Chunk is a larger thematic/story run of related jokes." List of all
/// Chunks, + New Chunk, drilling into ChunkDetailView for membership management.
struct ChunkListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ChunkService.Chunk.createdAt) private var chunks: [ChunkService.Chunk]

    @State private var newChunkTitle = ""
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    TextField("New chunk title", text: $newChunkTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(createChunk)
                    Button("Add Chunk", action: createChunk)
                        .disabled(newChunkTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if chunks.isEmpty {
                    Text("No chunks yet. Group related jokes into a Chunk once a theme emerges.")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(chunks) { chunk in
                            HStack {
                                NavigationLink(value: chunk.persistentModelID) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(chunk.title)
                                        Text("\(ChunkService.jokes(in: chunk).count) joke\(ChunkService.jokes(in: chunk).count == 1 ? "" : "s") · \(chunk.status.rawValue)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    ChunkService.delete(chunk, context: context)
                                    try? context.save()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let chunk = chunks.first(where: { $0.persistentModelID == id }) {
                    ChunkDetailView(chunk: chunk)
                }
            }
        }
    }

    private func createChunk() {
        let title = newChunkTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        ChunkService.createChunk(title: title, context: context)
        try? context.save()
        newChunkTitle = ""
    }
}

#Preview {
    ChunkListView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
