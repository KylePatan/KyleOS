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
    @Query(sort: \SourceService.Source.createdAt, order: .reverse) private var allSources: [SourceService.Source]
    @Query private var allClips: [ClipService.Clip]

    private var sources: [SourceService.Source] { allSources.filter { !$0.displayIsArchived } }
    private var archivedSources: [SourceService.Source] { allSources.filter { $0.displayIsArchived } }

    @State private var newSourceTitle = ""
    @State private var path = NavigationPath()
    @State private var isPresentingArchivedSources = false

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
                    RetroPanel("Sources", accentCategory: .clips) {
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
                                // Kyle (2026-08-20): "can there be an option to right click any
                                // item... 'Archive'... or 'delete'." Additive alongside the
                                // existing explicit buttons above, not a replacement for them.
                                .archiveDeleteContextMenu(
                                    onArchive: {
                                        SourceService.archive(source)
                                        try? context.save()
                                    },
                                    onDelete: {
                                        SourceService.delete(source, context: context)
                                        try? context.save()
                                    }
                                )
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(RetroTheme.sectionPadding)
            .background(RetroTheme.background)
            .navigationDestination(for: SourceRoute.self) { route in
                // Looks up `allSources` (unfiltered), not the active-only `sources` — a Source
                // archived while its own detail view is open must stay resolvable, not vanish
                // out from under the user mid-navigation.
                if let source = allSources.first(where: { $0.persistentModelID == route.id }) {
                    SourceDetailView(source: source)
                }
            }
            .navigationDestination(for: ClipRoute.self) { route in
                if let clip = allClips.first(where: { $0.persistentModelID == route.id }) {
                    ClipDetailView(clip: clip)
                }
            }
            .toolbar {
                if !archivedSources.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isPresentingArchivedSources = true
                        } label: {
                            Label("Archived Sources (\(archivedSources.count))", systemImage: "archivebox")
                        }
                    }
                }
            }
            .sheet(isPresented: $isPresentingArchivedSources) {
                ArchivedSourcesSheet()
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

/// Kyle (2026-08-20, real use): "there should be an archive in both writing and clips." Same
/// shape as `WritingHomeView`'s `ArchivedWritingProjectsSheet` — own live `@Query` so Restore
/// shrinks the list in this same sheet session, not a passed-in array snapshot.
private struct ArchivedSourcesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \SourceService.Source.updatedAt, order: .reverse)
    private var allSources: [SourceService.Source]

    private var sources: [SourceService.Source] { allSources.filter { $0.displayIsArchived } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Archived Sources").font(.headline).foregroundStyle(RetroTheme.primaryText)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.retroProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(RetroTheme.sectionPadding)
            if sources.isEmpty {
                Text("Nothing archived.").foregroundStyle(RetroTheme.secondaryText).padding(RetroTheme.sectionPadding)
            } else {
                VStack(spacing: 0) {
                    ForEach(sources) { source in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.title).foregroundStyle(RetroTheme.primaryText)
                                Text("\(ClipService.clips(in: source).count) clip\(ClipService.clips(in: source).count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(RetroTheme.secondaryText)
                            }
                            Spacer()
                            Button("Restore") {
                                SourceService.restore(source)
                                try? context.save()
                            }
                            .buttonStyle(.retro)
                        }
                        .padding(.horizontal, RetroTheme.sectionPadding)
                        .padding(.vertical, RetroTheme.controlSpacing)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minWidth: 380, minHeight: 300)
        .background(RetroTheme.panelBackground)
    }
}

#Preview {
    SourceListView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(AppNavigationController())
}
