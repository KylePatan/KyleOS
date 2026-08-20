import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Kyle (2026-08-17): "Don't just have 'today' in home. Let's extend that with a weekly calendar.
/// Today - and the following four days with potential items that we can work on. All of these
/// tasks should be draggable between them."
///
/// Follow-up, same day, after being asked whether the 4 future days should auto-fill: "days should
/// start blank - and there should be a column for 'TO DO' and these are not assigned to days - but
/// this is the ranked by priority list... you can drag and schedule your week by dragging into
/// following days. Once it's set into a day... when the app refreshes tomorrow, those items go to
/// the 'today' column and so forth." That last part falls out for free: each day column is computed
/// from today's actual date on every render, not a fixed label, so a WorkItem scheduled for a given
/// calendar day automatically reads as "Today" once that day arrives — no extra rollover logic.
///
/// Deliberately does NOT auto-populate the day columns (see the exchange above) — no new
/// Scheduling-Engine placement algorithm invented here. "To Do" is exactly
/// `SchedulingService.rankedItems`, the same ranking Home already used for its old flat top-10
/// list; a WorkItem leaves "To Do" only once the user drags it onto a day, which lazily creates a
/// `PlannedSession` via the already-existing `PlannedSessionService.schedule`/`.reschedule` — no
/// new domain logic, just wiring two existing, already-tested primitives to a drag gesture.
struct WeeklyBoardView: View {
    let allWorkItems: [HomeService.WorkItem]

    @Environment(\.modelContext) private var context
    @Query private var allPlannedSessions: [PlannedSessionService.PlannedSession]

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }
    private let dayOffsets = Array(0..<5)

    private var rankedWorkItems: [HomeService.WorkItem] {
        SchedulingService.rankedItems(from: allWorkItems).map(\.workItem)
    }

    /// At most one active session per WorkItem is ever created (`schedule`/`reschedule` below
    /// always check for an existing one first) — "active" meaning still `.scheduled`, not
    /// completed/missed/cancelled, matching `PlannedSessionService.upcoming`'s own filter.
    private var activeSessions: [PlannedSessionService.PlannedSession] {
        allPlannedSessions.filter { $0.status == .scheduled }
    }

    private var scheduledWorkItemIDs: Set<UUID> {
        Set(activeSessions.compactMap { $0.workItem?.id })
    }

    private var toDoItems: [HomeService.WorkItem] {
        let scheduled = scheduledWorkItemIDs
        return rankedWorkItems.filter { !scheduled.contains($0.id) }
    }

    private func items(forDayOffset offset: Int) -> [HomeService.WorkItem] {
        guard let dayStart = calendar.date(byAdding: .day, value: offset, to: today),
              let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let idsForDay = Set(
            activeSessions
                .filter { $0.scheduledAt >= dayStart && $0.scheduledAt < dayEnd }
                .compactMap { $0.workItem?.id }
        )
        return rankedWorkItems.filter { idsForDay.contains($0.id) }
    }

    private func label(forDayOffset offset: Int) -> String {
        guard offset > 0, let date = calendar.date(byAdding: .day, value: offset, to: today) else { return "Today" }
        return date.formatted(.dateTime.weekday(.abbreviated).day())
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: RetroTheme.sectionSpacing) {
                BoardColumn(title: "To Do", items: toDoItems, emptyMessage: "Nothing left to schedule.") { workItemID in
                    unschedule(workItemID)
                }
                ForEach(dayOffsets, id: \.self) { offset in
                    BoardColumn(title: label(forDayOffset: offset), items: items(forDayOffset: offset), emptyMessage: "Drag something here.") { workItemID in
                        schedule(workItemID, onDayOffset: offset)
                    }
                }
            }
            .padding(RetroTheme.sectionPadding)
        }
    }

    private func resolvedWorkItem(_ id: UUID) -> HomeService.WorkItem? {
        allWorkItems.first { $0.id == id }
    }

    private func unschedule(_ workItemID: UUID) {
        guard let session = activeSessions.first(where: { $0.workItem?.id == workItemID }) else { return }
        PlannedSessionService.delete(session, context: context)
        try? context.save()
    }

    private func schedule(_ workItemID: UUID, onDayOffset offset: Int) {
        guard let workItem = resolvedWorkItem(workItemID),
              let dayStart = calendar.date(byAdding: .day, value: offset, to: today) else { return }
        let scheduledAt = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) ?? dayStart
        if let existing = activeSessions.first(where: { $0.workItem?.id == workItemID }) {
            PlannedSessionService.reschedule(existing, to: scheduledAt)
        } else {
            PlannedSessionService.schedule(
                for: workItem,
                at: scheduledAt,
                durationMinutes: workItem.preferredSessionMinutes,
                context: context
            )
        }
        try? context.save()
    }
}

private struct BoardColumn: View {
    let title: String
    let items: [HomeService.WorkItem]
    let emptyMessage: String
    let onDrop: (UUID) -> Void

    @State private var isTargeted = false

    var body: some View {
        RetroPanel(title) {
            // `.frame(maxWidth: .infinity)` here (not just on the outer RetroPanel below) matters:
            // without it, this VStack only sizes to its own content's natural width (the "Drag
            // something here." text), and a plain `.frame()` on the OUTSIDE of RetroPanel reserves
            // layout space but does not, by itself, extend the actual view/hit-test region to
            // fill it — most of an empty column would silently not accept a drop at all.
            VStack(alignment: .leading, spacing: 0) {
                if items.isEmpty {
                    Text(emptyMessage)
                        .font(.caption)
                        .foregroundStyle(RetroTheme.secondaryText)
                } else {
                    ForEach(items) { item in
                        WeeklyItemCard(workItem: item)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 240, maxWidth: .infinity, minHeight: 160, alignment: .top)
        .background(isTargeted ? RetroTheme.accent.opacity(0.12) : .clear)
        .overlay(
            Rectangle().strokeBorder(isTargeted ? RetroTheme.accent : .clear, lineWidth: 3)
        )
        .contentShape(Rectangle())
        // `.draggable`/`.dropDestination` (SwiftUI's newer Transferable-based API) turned out
        // unreliable on macOS here — a real user drag started (per Kyle) but never registered a
        // drop, and a follow-up attempt to widen the hit-test region made it stop recognizing the
        // drag at all. `onDrag`/`onDrop` + `NSItemProvider` is the older, AppKit-backed mechanism
        // with a much longer macOS track record — switched to it instead of continuing to patch
        // the newer API blind (this session's automation can start a drag but not verify a real
        // NSDraggingSession end-to-end, so every fix here has to be judged from Kyle's own report).
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { reading, _ in
                guard let string = reading as? String, let workItemID = UUID(uuidString: string) else { return }
                DispatchQueue.main.async {
                    onDrop(workItemID)
                }
            }
            return true
        }
        .animation(RetroTheme.interactionAnimation, value: isTargeted)
    }
}

private struct WeeklyItemCard: View {
    let workItem: HomeService.WorkItem

    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController
    @Environment(AppNavigationController.self) private var navigator

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                // A nested Button here (rather than onTapGesture) would compete with this card's
                // own onDrag gesture for the same touch — exactly the "two competing drag/gesture
                // mechanisms" risk JokeBoardView's doc comment flagged when it chose not to use
                // drag-and-drop at all. A plain tap gesture on non-Button content coexists with
                // onDrag cleanly; only the Play button below (a real, small, distinct hit target)
                // stays an actual Button.
                VStack(alignment: .leading, spacing: 1) {
                    Text(workItem.workspace.rawValue.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(RetroTheme.accent)
                    Text(workItem.title)
                        .font(.callout.bold())
                        .foregroundStyle(RetroTheme.primaryText)
                    if let projectTitle = workItem.project?.title {
                        Text(projectTitle)
                            .font(.caption2)
                            .foregroundStyle(RetroTheme.secondaryText)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { navigateToWorkItem() }
                Spacer(minLength: RetroTheme.controlSpacing)
                Button {
                    timerController.start(
                        workItem: workItem,
                        targetDurationMinutes: workItem.preferredSessionMinutes,
                        progressBefore: workItem.progress,
                        context: context
                    )
                    try? context.save()
                    navigateToWorkItem()
                } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.retro)
                .disabled(timerController.state != .idle)
                .help("Start Timer")
            }
            Text(TimeFormatting.dueLabel(for: workItem.deadline?.dueAt))
                .font(.caption2)
                .foregroundStyle(workItem.deadline == nil ? RetroTheme.secondaryText : RetroTheme.warning)
            HStack(spacing: 6) {
                RetroProgressBar(percent: workItem.progress)
                Text("\(workItem.progress)%")
                    .font(.caption2)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
        }
        .padding(.vertical, RetroTheme.controlSpacing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
        }
        .onDrag {
            NSItemProvider(object: workItem.id.uuidString as NSString)
        }
        // Kyle (2026-08-20): "the things on 'home' should be removeable." Reaches past the
        // WorkItem row to whatever it's actually about (its Project/Chunk/Joke/Clip) via
        // `WorkItemService.underlyingContent` — omitted entirely for a general, untargeted
        // session, which has nothing to archive or delete.
        .archiveDeleteContextMenuIfApplicable(for: workItem, context: context)
    }

    private func navigateToWorkItem() {
        guard let target = DeepLinkTarget.forWorkItem(workItem) else { return }
        navigator.navigate(to: target)
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let project = ProjectService.createProject(title: "Coastal Town", projectType: .shortStory, in: context)
    let document = DocumentService.createDocument(title: "Untitled", type: .prose, in: project, context: context)
    let workItem = try? WorkItemService.writingWorkItem(for: document, context: context)
    _ = workItem
    return WeeklyBoardView(allWorkItems: (try? context.fetch(FetchDescriptor<HomeService.WorkItem>())) ?? [])
        .modelContainer(container)
        .environment(FocusTimerController())
        .environment(AppNavigationController())
}
