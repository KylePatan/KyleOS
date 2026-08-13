import SwiftUI
import SwiftData

/// PRD §7.6: Chunk detail — title/notes/status, its ordered Jokes (draggable within the Chunk,
/// removable without deleting the Joke), and adding loose Jokes into it.
struct ChunkDetailView: View {
    let chunk: ChunkService.Chunk
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var notes = ""

    private var memberJokes: [JokeService.Joke] {
        ChunkService.jokes(in: chunk)
    }
    private var addableJokes: [JokeService.Joke] {
        ChunkService.looseJokes(in: context)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            jokesSection
        }
        .padding()
        .navigationTitle(chunk.title)
        .onAppear {
            title = chunk.title
            notes = chunk.notes
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Chunk title", text: $title)
                .font(.title3.bold())
                .textFieldStyle(.plain)
                .onChange(of: title) {
                    ChunkService.rename(chunk, to: title)
                    try? context.save()
                }
            TextField("Notes", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .onChange(of: notes) {
                    ChunkService.updateNotes(chunk, notes: notes)
                    try? context.save()
                }
            Picker("Status", selection: Binding(
                get: { chunk.status },
                set: { chunk.status = $0; chunk.updatedAt = .now; try? context.save() }
            )) {
                ForEach(JokeService.JokeStatus.allCases, id: \.self) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .frame(width: 160)
        }
    }

    private var jokesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Jokes in this Chunk").font(.headline)
                Spacer()
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
            }
            if memberJokes.isEmpty {
                Text("No jokes in this chunk yet.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(memberJokes) { joke in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                if !joke.title.isEmpty {
                                    Text(joke.title).font(.callout.bold())
                                }
                                Text(joke.text).font(.callout).lineLimit(2)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                ChunkService.removeJoke(joke, from: chunk)
                                try? context.save()
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .onMove { source, destination in
                        ChunkService.reorderJokes(in: chunk, movingFromOffsets: source, toOffset: destination)
                        try? context.save()
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 120, idealHeight: CGFloat(memberJokes.count) * 50 + 20)
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
}
