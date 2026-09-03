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
        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
            quickCapture
            HStack(alignment: .top, spacing: RetroTheme.sectionSpacing) {
                ForEach(JokeService.JokeStatus.allCases, id: \.self) { status in
                    column(for: status)
                }
            }
        }
        .padding(RetroTheme.sectionPadding)
        .background(RetroTheme.background)
    }

    /// PRD §7.3: "+ Joke Idea should require only the idea text."
    private var quickCapture: some View {
        RetroPanel {
            HStack {
                TextField("New joke idea", text: $newIdeaText)
                    .retroInputStyle()
                    .onSubmit(capture)
                Button("Add Joke Idea", action: capture)
                    .buttonStyle(.retroProminent)
                    .disabled(newIdeaText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
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
        let items = jokes(for: status)
        return RetroPanel(status.rawValue, accentCategory: .standUp) {
            if items.isEmpty {
                Text("No jokes here yet.")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            } else {
                List {
                    ForEach(items) { joke in
                        JokeCard(joke: joke, otherStatuses: JokeService.JokeStatus.allCases.filter { $0 != status })
                            .listRowBackground(RetroTheme.panelBackground)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparatorTint(RetroTheme.border.opacity(0.5))
                    }
                    .onMove { source, destination in
                        JokeService.reorder(withStatus: status, movingFromOffsets: source, toOffset: destination, in: context)
                        try? context.save()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: min(max(160, CGFloat(items.count) * 70 + 20), RetroTheme.maxListHeight))
            }
        }
        .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
    }
}

private struct JokeCard: View {
    let joke: JokeService.Joke
    let otherStatuses: [JokeService.JokeStatus]

    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController
    @State private var title = ""
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Title (optional)", text: $title)
                .textFieldStyle(.plain)
                .font(.caption.bold())
                .foregroundStyle(RetroTheme.primaryText)
                .onChange(of: title) {
                    JokeService.rename(joke, title: title)
                    try? context.save()
                }
            TextField("Joke text", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(WritingSurfaceFont.swiftUI(size: 13))
                .foregroundStyle(RetroTheme.primaryText)
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
                /// PRD §7.11: "start a timed session against a specific Joke." Only offered when
                /// idle — the app has one shared timer, so a running session must be
                /// finished/discarded via the ActiveTimerBanner before starting another.
                if timerController.state == .idle {
                    Button {
                        guard let workItem = try? WorkItemService.standUpWorkItem(for: joke, context: context) else { return }
                        timerController.start(workItem: workItem, targetDurationMinutes: nil, progressBefore: workItem.progress, context: context)
                        try? context.save()
                    } label: {
                        Image(systemName: "timer")
                    }
                    .buttonStyle(.retro)
                }
                Button(role: .destructive) {
                    JokeService.archive(joke)
                    try? context.save()
                } label: {
                    Image(systemName: "archivebox")
                }
                .buttonStyle(.retro)
            }
            .font(.caption)
        }
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
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
    .environment(FocusTimerController())
}
