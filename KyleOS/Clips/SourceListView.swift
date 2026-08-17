import SwiftUI
import SwiftData

/// PRD §8.2: "A Source can represent a stand-up set, sketch footage, interview, podcast
/// appearance, or other recorded material." List of all Sources, + New Source. Owns the shared
/// NavigationStack for this tab — both SourceDetailView and ClipDetailView push into it via
/// `SourceRoute`/`ClipRoute` (same "one stack, distinct route types" pattern as WritingHomeView),
/// rather than each detail view nesting its own NavigationStack.
struct SourceListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppNavigationController.self) private var navigator
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \SourceService.Source.createdAt, order: .reverse) private var sources: [SourceService.Source]
    @Query private var allClips: [ClipService.Clip]

    @State private var newSourceTitle = ""
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                RetroPanel {
                    HStack {
                        TextField("New source title", text: $newSourceTitle)
                            .retroInputStyle()
                            .onSubmit(createSource)
                        Button("Add Source", action: createSource)
                            .buttonStyle(.retroProminent)
                            .disabled(newSourceTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if sources.isEmpty {
                    Text("No sources yet. Add one to start identifying clips from footage.")
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    RetroPanel("Sources") {
                        VStack(spacing: 0) {
                            ForEach(sources) { source in
                                HStack {
                                    NavigationLink(value: SourceRoute(id: source.persistentModelID)) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(source.title).foregroundStyle(RetroTheme.primaryText)
                                            Text("\(ClipService.clips(in: source).count) clip\(ClipService.clips(in: source).count == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundStyle(RetroTheme.secondaryText)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    Spacer()
                                    Button {
                                        openWindow(value: DetachedWindowTarget.sourceDetail(source.persistentModelID))
                                    } label: {
                                        Image(systemName: "arrow.up.forward.square")
                                    }
                                    .buttonStyle(.retro)
                                    .help("Open in a new window")
                                    Button(role: .destructive) {
                                        SourceService.delete(source, context: context)
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
                Spacer(minLength: 0)
            }
            .padding(RetroTheme.sectionPadding)
            .background(RetroTheme.background)
            .navigationDestination(for: SourceRoute.self) { route in
                if let source = sources.first(where: { $0.persistentModelID == route.id }) {
                    SourceDetailView(source: source)
                }
            }
            .navigationDestination(for: ClipRoute.self) { route in
                if let clip = allClips.first(where: { $0.persistentModelID == route.id }) {
                    ClipDetailView(clip: clip)
                }
            }
        }
        .task(id: navigator.pendingTarget) { consumePendingTarget() }
    }

    private func consumePendingTarget() {
        guard case .clip(let id) = navigator.pendingTarget else { return }
        path.append(ClipRoute(id: id))
        navigator.pendingTarget = nil
    }

    private func createSource() {
        let title = newSourceTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        SourceService.createSource(title: title, context: context)
        try? context.save()
        newSourceTitle = ""
    }
}

#Preview {
    SourceListView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(AppNavigationController())
}
