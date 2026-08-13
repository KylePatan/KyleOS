import SwiftUI
import SwiftData

/// PRD §7.2's Joke Board: three columns (Joke Ideas / New / Done), draggable between stages and
/// reorderable within stages, plus Quick Joke Capture (§7.3). First V0.3 Stand Up increment —
/// mirrors how Act Outline was Writing's first real container before deeper detail work; the
/// fuller Joke Detail view (§7.4: premise/setup/punchline/tags/performance notes/runtime) is a
/// later increment.
///
/// "Draggable between stages," implemented as an explicit "Move to…" menu per card rather than a
/// true cross-column drag gesture (CLAUDE.md §13 — documented implementation choice): SwiftUI's
/// List already owns the drag gesture for within-column `.onMove` reordering (the same proven
/// pattern ActOutlineView/AllTasksView use), and layering a second, competing drag mechanism
/// (`.draggable`/`.dropDestination`) on the same rows risks the two interfering with each other
/// in ways that can't be verified without Accessibility permission to test interactively. The
/// menu fully satisfies the functional requirement — status changes automatically, cards move —
/// without introducing an unproven interaction pattern.
struct JokeBoardView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<JokeService.Joke> { !$0.isArchived })
    private var allActiveJokes: [JokeService.Joke]

    @State private var newIdeaText = ""

    private func jokes(for status: JokeService.JokeStatus) -> [JokeService.Joke] {
        allActiveJokes.filter { $0.status == status }.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            quickCapture
            HStack(alignment: .top, spacing: 16) {
                ForEach(JokeService.JokeStatus.allCases, id: \.self) { status in
                    column(for: status)
                }
            }
        }
        .padding()
    }

    /// PRD §7.3: "+ Joke Idea should require only the idea text."
    private var quickCapture: some View {
        HStack {
            TextField("New joke idea", text: $newIdeaText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(capture)
            Button("Add Joke Idea", action: capture)
                .disabled(newIdeaText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func capture() {
        let text = newIdeaText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        JokeService.quickCapture(text: text, context: context)
        try? context.save()
        newIdeaText = ""
    }

    private func column(for status: JokeService.JokeStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status.rawValue).font(.headline)
            let items = jokes(for: status)
            if items.isEmpty {
                Text("No jokes here yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(items) { joke in
                        JokeCard(joke: joke, otherStatuses: JokeService.JokeStatus.allCases.filter { $0 != status })
                    }
                    .onMove { source, destination in
                        JokeService.reorder(withStatus: status, movingFromOffsets: source, toOffset: destination, in: context)
                        try? context.save()
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 160, idealHeight: CGFloat(items.count) * 70 + 20)
            }
        }
        .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
    }
}

private struct JokeCard: View {
    let joke: JokeService.Joke
    let otherStatuses: [JokeService.JokeStatus]

    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Title (optional)", text: $title)
                .textFieldStyle(.plain)
                .font(.caption.bold())
                .onChange(of: title) {
                    JokeService.rename(joke, title: title)
                    try? context.save()
                }
            TextField("Joke text", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.callout)
                .onChange(of: text) {
                    JokeService.updateText(joke, text: text)
                    try? context.save()
                }
            HStack {
                Menu("Move to") {
                    ForEach(otherStatuses, id: \.self) { status in
                        Button(status.rawValue) {
                            JokeService.move(joke, to: status, in: context)
                            try? context.save()
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                Button(role: .destructive) {
                    JokeService.archive(joke)
                    try? context.save()
                } label: {
                    Image(systemName: "archivebox")
                }
                .buttonStyle(.borderless)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
        .onAppear {
            title = joke.title
            text = joke.text
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    JokeService.quickCapture(text: "Airline food, but for cats.", context: context)
    JokeService.quickCapture(text: "Group chats are just group texts with anxiety.", context: context)
    return NavigationStack {
        JokeBoardView()
    }
    .modelContainer(container)
}
