import SwiftUI
import SwiftData

/// PRD §8.4: "A board can visually simplify these to To Isolate, Editing, Needs Subtitles,
/// Ready, Posted." Shows every Clip across every Source, grouped into the 5 simplified lanes
/// (`ClipService.boardLane`).
///
/// Kyle (2026-08-17): "for the clip board - let's make sure all the information for clips like -
/// when to post them and how you can edit that as well as timelines is on the homepage/clips page
/// and not the extension page" (ClipDetailView, only reachable by drilling into a Source) — cards
/// now surface progress, the Editing/Subtitling deadlines, and Post Date editing directly, same
/// info ClipDetailView already had, just here too. "Also - like the home page, the clip page has
/// to be completely draggable" — lanes are now drag targets (`onDrag`/`onDrop` + `NSItemProvider`,
/// the exact same mechanism `WeeklyBoardView` already uses — SwiftUI's newer `.draggable`/
/// `.dropDestination` proved unreliable on macOS there), replacing the previous "Move to" menu
/// entirely rather than keeping both, per "completely draggable."
struct ClipBoardView: View {
    @Query(sort: \ClipService.Clip.createdAt) private var allClips: [ClipService.Clip]
    @Query private var allWorkItems: [WorkItemService.WorkItem]
    @Environment(\.modelContext) private var context

    private func clips(in lane: ClipService.BoardLane) -> [ClipService.Clip] {
        allClips.filter { ClipService.boardLane(for: $0.status) == lane }
    }

    /// Computed once here (not as a per-card `@Query`, which would re-run the same fetch once for
    /// every card on the board) and handed down as plain model references — still live/reactive,
    /// since the underlying `WorkItem` instances themselves stay tracked by the context.
    private func editingWorkItem(for clip: ClipService.Clip) -> WorkItemService.WorkItem? {
        allWorkItems.first { $0.clip?.persistentModelID == clip.persistentModelID && $0.workTypeName == "Clip Editing" }
    }

    private func subtitlingWorkItem(for clip: ClipService.Clip) -> WorkItemService.WorkItem? {
        allWorkItems.first { $0.clip?.persistentModelID == clip.persistentModelID && $0.workTypeName == "Clip Subtitling" }
    }

    /// The "Move to" menu used to set a lane's primary/entry status directly — a documented
    /// simplification since a lane can represent more than one real `ClipStatus`. Drag now drives
    /// the same mapping; finer-grained status selection (e.g. distinguishing Footage Isolated from
    /// Currently Editing) is still available via ClipDetailView's full status picker.
    private static func primaryStatus(for lane: ClipService.BoardLane) -> ClipService.ClipStatus {
        switch lane {
        case .toIsolate: return .identifiedToIsolate
        case .editing: return .currentlyEditing
        case .needsSubtitles: return .editedNotSubtitled
        case .ready: return .ready
        case .posted: return .posted
        }
    }

    private func resolvedClip(_ id: UUID) -> ClipService.Clip? {
        allClips.first { $0.id == id }
    }

    private func drop(_ clipID: UUID, onto lane: ClipService.BoardLane) {
        guard let clip = resolvedClip(clipID) else { return }
        ClipService.changeStatus(clip, to: Self.primaryStatus(for: lane), context: context)
        try? context.save()
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: RetroTheme.sectionSpacing) {
                ForEach(ClipService.BoardLane.allCases, id: \.self) { lane in
                    ClipBoardColumn(
                        lane: lane,
                        clips: clips(in: lane),
                        editingWorkItem: editingWorkItem,
                        subtitlingWorkItem: subtitlingWorkItem
                    ) { clipID in
                        drop(clipID, onto: lane)
                    }
                }
            }
            .padding(RetroTheme.sectionPadding)
        }
        .background(RetroTheme.background)
    }
}

private struct ClipBoardColumn: View {
    let lane: ClipService.BoardLane
    let clips: [ClipService.Clip]
    let editingWorkItem: (ClipService.Clip) -> WorkItemService.WorkItem?
    let subtitlingWorkItem: (ClipService.Clip) -> WorkItemService.WorkItem?
    let onDrop: (UUID) -> Void

    @State private var isTargeted = false

    var body: some View {
        RetroPanel(lane.rawValue) {
            VStack(alignment: .leading, spacing: 0) {
                if clips.isEmpty {
                    Text("Drag a clip here.")
                        .font(.caption)
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    ForEach(clips) { clip in
                        ClipCard(clip: clip, editingWorkItem: editingWorkItem(clip), subtitlingWorkItem: subtitlingWorkItem(clip))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 280, maxWidth: .infinity, minHeight: 160, alignment: .top)
        .background(isTargeted ? RetroTheme.accent.opacity(0.12) : .clear)
        .overlay(
            Rectangle().strokeBorder(isTargeted ? RetroTheme.accent : .clear, lineWidth: 3)
        )
        .contentShape(Rectangle())
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { reading, _ in
                guard let string = reading as? String, let clipID = UUID(uuidString: string) else { return }
                DispatchQueue.main.async {
                    onDrop(clipID)
                }
            }
            return true
        }
        .animation(RetroTheme.interactionAnimation, value: isTargeted)
    }
}

private struct ClipCard: View {
    let clip: ClipService.Clip
    let editingWorkItem: WorkItemService.WorkItem?
    let subtitlingWorkItem: WorkItemService.WorkItem?

    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(clip.title).font(.callout.bold()).foregroundStyle(RetroTheme.primaryText)
                    if let sourceTitle = clip.source?.title {
                        Text(sourceTitle)
                            .font(.caption2)
                            .foregroundStyle(RetroTheme.secondaryText)
                    }
                }
                Spacer(minLength: RetroTheme.controlSpacing)
                Button {
                    openWindow(value: DetachedWindowTarget.clipDetail(clip.persistentModelID))
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.retro)
                .help("Open in a new window")
            }

            HStack(spacing: 6) {
                RetroProgressBar(percent: clip.progress)
                Text("\(clip.progress)%")
                    .font(.caption2)
                    .foregroundStyle(RetroTheme.secondaryText)
            }

            HStack(spacing: RetroTheme.controlSpacing) {
                DeadlineControl(
                    label: "Editing",
                    dueAt: editingWorkItem?.deadline?.dueAt,
                    isHard: editingWorkItem?.deadline?.isHard ?? true,
                    onSet: { dueAt, isHard in
                        guard let resolvedWorkItem = try? WorkItemService.clipWorkItem(for: clip, context: context) else { return }
                        DeadlineService.setDeadline(for: resolvedWorkItem, label: "Finish editing: \(clip.title)", dueAt: dueAt, isHard: isHard, context: context)
                        try? context.save()
                    },
                    onRemove: {
                        guard let editingWorkItem else { return }
                        DeadlineService.removeDeadline(for: editingWorkItem, context: context)
                        try? context.save()
                    }
                )
                DeadlineControl(
                    label: "Subtitling",
                    dueAt: subtitlingWorkItem?.deadline?.dueAt,
                    isHard: subtitlingWorkItem?.deadline?.isHard ?? true,
                    onSet: { dueAt, isHard in
                        guard let resolvedWorkItem = try? WorkItemService.clipSubtitlingWorkItem(for: clip, context: context) else { return }
                        DeadlineService.setDeadline(for: resolvedWorkItem, label: "Finish subtitling: \(clip.title)", dueAt: dueAt, isHard: isHard, context: context)
                        try? context.save()
                    },
                    onRemove: {
                        guard let subtitlingWorkItem else { return }
                        DeadlineService.removeDeadline(for: subtitlingWorkItem, context: context)
                        try? context.save()
                    }
                )
            }

            PostDateControl(clip: clip)
        }
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
        }
        .onDrag {
            NSItemProvider(object: clip.id.uuidString as NSString)
        }
    }
}

/// Compact Post Date editor for board/card use — same underlying action as ClipDetailView's own
/// Post Date section (`PostingItemService.setConfirmedPostDate`, so Calendar/To Do sync and the
/// "static once confirmed" behavior are identical), just condensed into a popover button instead
/// of an inline Toggle+DatePicker. Deliberately its own small control rather than reusing
/// `DeadlineControl` — that control exposes a hard/soft toggle that `setConfirmedPostDate` ignores
/// (a Post Date is always hard/locked), which would show a control with no real effect.
private struct PostDateControl: View {
    let clip: ClipService.Clip
    @Environment(\.modelContext) private var context

    @State private var isEditing = false
    @State private var draftDate = Date.now

    var body: some View {
        HStack(spacing: RetroTheme.controlSpacing) {
            if let date = clip.postDate {
                Button {
                    draftDate = date
                    isEditing = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.checkmark")
                        Text("Post \(date.formatted(date: .abbreviated, time: .omitted))")
                    }
                    .foregroundStyle(RetroTheme.primaryText)
                }
                .buttonStyle(.retro)
                Button(role: .destructive) {
                    savePostDate(nil)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.retro)
                .help("Remove post date")
            } else {
                if let recommended = PostingItemService.recommendedPostDate(in: context) {
                    Button {
                        savePostDate(recommended)
                    } label: {
                        Text("Recommended: \(recommended.formatted(date: .abbreviated, time: .omitted))")
                    }
                    .buttonStyle(.retro)
                }
                Button {
                    draftDate = PostingItemService.recommendedPostDate(in: context) ?? .now
                    isEditing = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                }
                .buttonStyle(.retro)
                .help("Set post date")
            }
        }
        .popover(isPresented: $isEditing) { editor }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
            Text("Post Date").font(.headline).foregroundStyle(RetroTheme.primaryText)
            DatePicker("Date", selection: $draftDate, displayedComponents: .date)
            Text("Static once set — appears on Calendar and To Do, and won't move unless changed here.")
                .font(.caption)
                .foregroundStyle(RetroTheme.secondaryText)
                .frame(maxWidth: 220, alignment: .leading)
            HStack {
                Spacer()
                Button("Save") {
                    savePostDate(draftDate)
                    isEditing = false
                }
                .buttonStyle(.retroProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RetroTheme.sectionPadding)
        .frame(width: 260)
        .background(RetroTheme.panelBackground)
    }

    private func savePostDate(_ date: Date?) {
        let item = PostingItemService.findOrCreate(for: clip, context: context)
        PostingItemService.setConfirmedPostDate(item, date: date, context: context)
        try? context.save()
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let source = SourceService.createSource(title: "March Comedy Slam", context: context)
    ClipService.createClip(title: "Airline Bit", in: source, context: context)
    return ClipBoardView()
        .modelContainer(container)
}
