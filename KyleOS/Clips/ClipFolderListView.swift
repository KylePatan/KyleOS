import SwiftUI
import SwiftData

/// Kyle (2026-09-02): "I should be able to put things in folders so I know what things are what.
/// Like Mac file system, I can highlight multiple in clips and 'Create folder' and put items in
/// it. I also should be able to drag sources and clips and whatever i'm doing, and drag and drop
/// them to organize myself." A separate lens from `ClipBoardView`'s own 5-lane production-status
/// board — Folders is a purely organizational grouping orthogonal to status (a folder can hold
/// clips at any stage), so it lives as its own tab (`ClipsHomeView`) rather than adding a second,
/// conflicting drop target onto the board's existing status lanes. Same "New Folder" +
/// drag-to-populate shape as `SourceListView`'s own Folders section.
struct ClipFolderListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClipService.Clip.createdAt) private var allClips: [ClipService.Clip]
    /// Broad, unfiltered `@Query` + in-memory filter by `kind` — this codebase's established
    /// workaround for `#Predicate`'s unreliable enum-property comparisons; `SourceListView` reads
    /// its own `.sources` folders the same way, never mixed.
    @Query(sort: \FolderService.Folder.title) private var allFolders: [FolderService.Folder]
    private var folders: [FolderService.Folder] { allFolders.filter { $0.kind == .clips } }

    private var unfiledClips: [ClipService.Clip] { allClips.filter { $0.folder == nil } }

    @State private var newFolderTitle = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
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
                if allClips.isEmpty {
                    Text("No clips yet. Identify some from a Source to start organizing them.")
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    ForEach(folders) { folder in
                        ClipFolderPanel(folder: folder, clips: folder.clips)
                    }
                    RetroPanel(folders.isEmpty ? "Clips" : "Unfiled", accentCategory: .clips) {
                        if unfiledClips.isEmpty {
                            Text("Nothing here — every clip is in a folder.")
                                .font(.caption)
                                .foregroundStyle(RetroTheme.secondaryText)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(unfiledClips) { clip in
                                    ClipFolderRow(clip: clip)
                                }
                            }
                        }
                    }
                    // A drop target too — dragging a clip out of a folder back onto "Unfiled" is
                    // how you take it back out (the Mac Finder counterpart: moving something out
                    // of a folder onto the desktop).
                    .onDrop(of: [.text], isTargeted: nil) { providers in
                        handleDrop(providers) { clip in FolderService.moveClip(clip, to: nil) }
                    }
                }
            }
            .padding(RetroTheme.sectionPadding)
        }
        .background(RetroTheme.background)
    }

    private func createFolder() {
        let title = newFolderTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        FolderService.createFolder(title: title, kind: .clips, context: context)
        try? context.save()
        newFolderTitle = ""
    }

    private func handleDrop(_ providers: [NSItemProvider], action: @escaping (ClipService.Clip) -> Void) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let string = reading as? String, let clipID = UUID(uuidString: string) else { return }
            DispatchQueue.main.async {
                guard let clip = allClips.first(where: { $0.id == clipID }) else { return }
                action(clip)
                try? context.save()
            }
        }
        return true
    }
}

private struct ClipFolderPanel: View {
    let folder: FolderService.Folder
    let clips: [ClipService.Clip]

    @Environment(\.modelContext) private var context
    @State private var isTargeted = false
    @State private var isRenaming = false
    @State private var draftTitle = ""

    var body: some View {
        RetroPanel(folder.title, accentCategory: .clips) {
            if clips.isEmpty {
                Text("Drag a clip here.")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(clips) { clip in
                        ClipFolderRow(clip: clip)
                    }
                }
            }
        }
        .background(isTargeted ? RetroTheme.accent.opacity(0.12) : .clear)
        .overlay(Rectangle().strokeBorder(isTargeted ? RetroTheme.accent : .clear, lineWidth: 3))
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { reading, _ in
                guard let string = reading as? String, let clipID = UUID(uuidString: string) else { return }
                DispatchQueue.main.async {
                    var descriptor = FetchDescriptor<ClipService.Clip>(predicate: #Predicate { $0.id == clipID })
                    descriptor.fetchLimit = 1
                    guard let clip = try? context.fetch(descriptor).first else { return }
                    FolderService.moveClip(clip, to: folder)
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

private struct ClipFolderRow: View {
    let clip: ClipService.Clip
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.title).foregroundStyle(RetroTheme.primaryText)
                Text("\(clip.status.rawValue) · \(clip.source?.title ?? (clip.sketchProject != nil ? "Reel" : "—"))")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
            Spacer()
            Button {
                openWindow(value: DetachedWindowTarget.clipDetail(clip.persistentModelID))
            } label: {
                Image(systemName: "arrow.up.forward.square")
            }
            .buttonStyle(.retro)
            .help("Open in a new window")
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
            NSItemProvider(object: clip.id.uuidString as NSString)
        }
        .contextMenu {
            if clip.folder != nil {
                Button {
                    FolderService.moveClip(clip, to: nil)
                    try? context.save()
                } label: {
                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                }
            }
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let source = SourceService.createSource(title: "Open Mic March 3rd", context: context)
    _ = ClipService.createClip(title: "Airport bit", in: source, context: context)
    return ClipFolderListView()
        .modelContainer(container)
}
