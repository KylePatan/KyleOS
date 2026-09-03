import SwiftUI
import SwiftData

/// PRD §7.5-§7.6: "A Chunk is a larger thematic/story run of related jokes." List of all
/// Chunks, + New Chunk, drilling into ChunkDetailView for membership management.
struct ChunkListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppNavigationController.self) private var navigator
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \ChunkService.Chunk.createdAt) private var chunks: [ChunkService.Chunk]

    @State private var newChunkTitle = ""
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            // Kyle (2026-08-27): "when there are many items anywhere, it has to be able to scroll
            // to see everything." This list had no scrolling of its own — with enough Chunks it
            // just overflowed the window with no way to reach the rest.
            ScrollView {
                VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                    RetroPanel {
                        HStack {
                            TextField("New chunk title", text: $newChunkTitle)
                                .retroInputStyle()
                                .onSubmit(createChunk)
                            Button("Add Chunk", action: createChunk)
                                .buttonStyle(.retroProminent)
                                .disabled(newChunkTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    if chunks.isEmpty {
                        Text("No chunks yet. Group related jokes into a Chunk once a theme emerges.")
                            .foregroundStyle(RetroTheme.secondaryText)
                    } else {
                        RetroPanel("Chunks", accentCategory: .standUp) {
                            VStack(spacing: 0) {
                                ForEach(chunks) { chunk in
                                    HStack {
                                        NavigationLink(value: chunk.persistentModelID) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(chunk.title).foregroundStyle(RetroTheme.primaryText)
                                                Text("\(ChunkService.jokes(in: chunk).count) joke\(ChunkService.jokes(in: chunk).count == 1 ? "" : "s") · \(chunk.status.rawValue)")
                                                    .font(.caption)
                                                    .foregroundStyle(RetroTheme.secondaryText)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        Spacer()
                                        Button {
                                            openWindow(value: DetachedWindowTarget.chunkDetail(chunk.persistentModelID))
                                        } label: {
                                            Image(systemName: "arrow.up.forward.square")
                                        }
                                        .buttonStyle(.retro)
                                        .help("Open in a new window")
                                        Button(role: .destructive) {
                                            ChunkService.delete(chunk, context: context)
                                            try? context.save()
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.retro)
                                    }
                                    .padding(.horizontal, RetroTheme.controlSpacing + 4)
                                    .padding(.vertical, RetroTheme.controlSpacing)
                                    .overlay(alignment: .bottom) {
                                        Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(RetroTheme.sectionPadding)
            }
            .background(RetroTheme.background)
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let chunk = chunks.first(where: { $0.persistentModelID == id }) {
                    ChunkDetailView(chunk: chunk)
                }
            }
        }
        .task(id: navigator.pendingTarget) { consumePendingTarget() }
    }

    private func consumePendingTarget() {
        guard case .standUpChunk(let id) = navigator.pendingTarget else { return }
        path.append(id)
        navigator.pendingTarget = nil
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
        .environment(AppNavigationController())
}
