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
    /// Kyle (2026-09-02): "I should be able to put things in folders... Like Mac file system...
    /// drag sources and clips... to organize myself." Broad, unfiltered `@Query` + in-memory
    /// filter by `kind` (not `#Predicate<Folder> { $0.kind == .sources }`) — this codebase's
    /// established workaround for `#Predicate`'s unreliable enum-property comparisons (the same
    /// reason `generalStandUpWorkItem` filters `workspace` in-memory); `ClipBoardView` reads its
    /// own `.clips` folders the same way, never mixed.
    @Query(sort: \FolderService.Folder.title) private var allFolders: [FolderService.Folder]
    private var folders: [FolderService.Folder] { allFolders.filter { $0.kind == .sources } }

    private var sources: [SourceService.Source] { allSources.filter { !$0.displayIsArchived } }
    private var archivedSources: [SourceService.Source] { allSources.filter { $0.displayIsArchived } }
    private var ungroupedSources: [SourceService.Source] { sources.filter { $0.folder == nil } }

    @State private var newSourceTitle = ""
    @State private var newFolderTitle = ""
    @State private var path = NavigationPath()
    @State private var isPresentingArchivedSources = false

    var body: some View {
        NavigationStack(path: $path) {
            // Kyle (2026-08-27): "when there are many items anywhere, it has to be able to scroll
            // to see everything." This list had no scrolling of its own — with enough Sources it
            // just overflowed the window with no way to reach the rest.
            ScrollView {
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
                    RetroPanel {
                        HStack {
                            TextField("New folder name", text: $newFolderTitle)
                                .retroInputStyle()
                                .onSubmit(createFolder)
                            Button("Create Folder", action: createFolder)
                                .buttonStyle(.retroProminent)
                                .disabled(newFolderTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    if sources.isEmpty {
                        Text("No sources yet. Add one to start identifying clips from footage.")
                            .foregroundStyle(RetroTheme.secondaryText)
                    } else {
                        ForEach(folders) { folder in
                            SourceFolderPanel(folder: folder, sources: folder.sources.filter { !$0.displayIsArchived })
                        }
                        RetroPanel(folders.isEmpty ? "Sources" : "Ungrouped", accentCategory: .clips) {
                            if ungroupedSources.isEmpty {
                                Text("Nothing here — every source is in a folder.")
                                    .font(.caption)
                                    .foregroundStyle(RetroTheme.secondaryText)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(ungroupedSources) { source in
                                        SourceRow(source: source)
                                    }
                                }
                            }
                        }
                        // A drop target too, not just a display group — dragging a Source out of
                        // a folder and back onto "Ungrouped" is how you take it back out (the Mac
                        // Finder counterpart: moving something out of a folder onto the desktop).
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            handleDrop(providers) { source in FolderService.moveSource(source, to: nil) }
                        }
                    }
                }
                .padding(RetroTheme.sectionPadding)
            }
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

    private func createFolder() {
        let title = newFolderTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        FolderService.createFolder(title: title, kind: .sources, context: context)
        try? context.save()
        newFolderTitle = ""
    }

    /// Shared drop-payload resolver — a dragged Source's own `id: UUID` as a plain string (same
    /// `onDrag`/`onDrop` + `NSItemProvider` mechanism `WeeklyBoardView`/`ClipBoardView` already
    /// use for their lane drops), resolved back to the real Source and handed to `action`.
    private func handleDrop(_ providers: [NSItemProvider], action: @escaping (SourceService.Source) -> Void) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let string = reading as? String, let sourceID = UUID(uuidString: string) else { return }
            DispatchQueue.main.async {
                guard let source = allSources.first(where: { $0.id == sourceID }) else { return }
                action(source)
                try? context.save()
            }
        }
        return true
    }
}

private struct SourceFolderPanel: View {
    let folder: FolderService.Folder
    let sources: [SourceService.Source]

    @Environment(\.modelContext) private var context
    @State private var isTargeted = false
    @State private var isRenaming = false
    @State private var draftTitle = ""

    var body: some View {
        RetroPanel(folder.title, accentCategory: .clips) {
            if sources.isEmpty {
                Text("Drag a source here.")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(sources) { source in
                        SourceRow(source: source)
                    }
                }
            }
        }
        .background(isTargeted ? RetroTheme.accent.opacity(0.12) : .clear)
        .overlay(Rectangle().strokeBorder(isTargeted ? RetroTheme.accent : .clear, lineWidth: 3))
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { reading, _ in
                guard let string = reading as? String, let sourceID = UUID(uuidString: string) else { return }
                DispatchQueue.main.async {
                    var descriptor = FetchDescriptor<SourceService.Source>(predicate: #Predicate { $0.id == sourceID })
                    descriptor.fetchLimit = 1
                    guard let source = try? context.fetch(descriptor).first else { return }
                    FolderService.moveSource(source, to: folder)
                    try? context.save()
                }
            }
            return true
        }
        .animation(RetroTheme.interactionAnimation, value: isTargeted)
        .contextMenu {
            Button("Rename") {
                draftTitle = folder.title
                isRenaming = true
            }
            Button(role: .destructive) {
                FolderService.delete(folder, context: context)
                try? context.save()
            } label: {
                Label("Delete Folder", systemImage: "trash")
            }
        }
        .alert("Rename Folder", isPresented: $isRenaming) {
            TextField("Folder name", text: $draftTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = draftTitle.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                FolderService.rename(folder, to: trimmed)
                try? context.save()
            }
        }
    }
}

private struct SourceRow: View {
    let source: SourceService.Source
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow

    var body: some View {
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
        .contentShape(Rectangle())
        // Kyle (2026-09-02): "I also should be able to drag sources and clips... to organize
        // myself." Same payload shape (the item's own `id: UUID` as a plain string) every other
        // drag source in this app already uses.
        .onDrag {
            NSItemProvider(object: source.id.uuidString as NSString)
        }
        // Kyle (2026-08-20): "can there be an option to right click any item... 'Archive'... or
        // 'delete'." Additive alongside the existing explicit buttons above, not a replacement.
        // "Remove from Folder" only makes sense once it's actually in one.
        .contextMenu {
            if source.folder != nil {
                Button {
                    FolderService.moveSource(source, to: nil)
                    try? context.save()
                } label: {
                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                }
            }
            Button {
                SourceService.archive(source)
                try? context.save()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            Button(role: .destructive) {
                SourceService.delete(source, context: context)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
                // Kyle (2026-08-27): "when there are many items anywhere, it has to be able to
                // scroll to see everything" — this modal had no scrolling of its own either.
                ScrollView {
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
                .frame(maxHeight: RetroTheme.maxListHeight)
            }
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
