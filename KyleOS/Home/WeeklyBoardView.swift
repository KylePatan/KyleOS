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

    private var scheduledWorkItemIDs: Set<PersistentIdentifier> {
        Set(activeSessions.compactMap { $0.workItem?.persistentModelID })
    }

    private var toDoItems: [HomeService.WorkItem] {
        let scheduled = scheduledWorkItemIDs
        return rankedWorkItems.filter { !scheduled.contains($0.persistentModelID) }
    }

    private func items(forDayOffset offset: Int) -> [HomeService.WorkItem] {
        guard let dayStart = calendar.date(byAdding: .day, value: offset, to: today),
              let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let idsForDay = Set(
            activeSessions
                .filter { $0.scheduledAt >= dayStart && $0.scheduledAt < dayEnd }
                .compactMap { $0.workItem?.persistentModelID }
        )
        return rankedWorkItems.filter { idsForDay.contains($0.persistentModelID) }
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

    private func resolvedWorkItem(_ id: PersistentIdentifier) -> HomeService.WorkItem? {
        allWorkItems.first { $0.persistentModelID == id }
    }

    private func unschedule(_ workItemID: PersistentIdentifier) {
        guard let session = activeSessions.first(where: { $0.workItem?.persistentModelID == workItemID }) else { return }
        PlannedSessionService.delete(session, context: context)
        try? context.save()
    }

    private func schedule(_ workItemID: PersistentIdentifier, onDayOffset offset: Int) {
        guard let workItem = resolvedWorkItem(workItemID),
              let dayStart = calendar.date(byAdding: .day, value: offset, to: today) else { return }
        let scheduledAt = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) ?? dayStart
        if let existing = activeSessions.first(where: { $0.workItem?.persistentModelID == workItemID }) {
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

/// The drag payload — just enough to re-resolve the real WorkItem on drop. In-process only (drag
/// source and drop destination are both this same view), so the UTType needs no Info.plist export
/// declaration.
private struct DraggedWorkItemID: Codable, Transferable {
    let modelID: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .kyleOSWorkItem)
    }
}

private extension UTType {
    static var kyleOSWorkItem: UTType { UTType(exportedAs: "com.kylepatan.KyleOS.workitem") }
}

private struct BoardColumn: View {
    let title: String
    let items: [HomeService.WorkItem]
    let emptyMessage: String
    let onDrop: (PersistentIdentifier) -> Void

    @State private var isTargeted = false

    var body: some View {
        RetroPanel(title) {
            if items.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        WeeklyItemCard(workItem: item)
                    }
                }
            }
        }
        .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
        .overlay(
            Rectangle().strokeBorder(isTargeted ? RetroTheme.accent : .clear, lineWidth: 2)
        )
        .dropDestination(for: DraggedWorkItemID.self) { dropped, _ in
            guard let dragged = dropped.first else { return false }
            onDrop(dragged.modelID)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
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
                // own .draggable() gesture for the same touch — exactly the "two competing drag/
                // gesture mechanisms" risk JokeBoardView's doc comment flagged when it chose not
                // to use draggable/dropDestination at all. A plain tap gesture on non-Button
                // content coexists with .draggable() cleanly; only the Play button below (a real,
                // small, distinct hit target) stays an actual Button.
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
            if let dueAt = workItem.deadline?.dueAt {
                Text("Due \(dueAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(RetroTheme.warning)
            }
            Text("\(workItem.progress)%")
                .font(.caption2)
                .foregroundStyle(RetroTheme.secondaryText)
        }
        .padding(.vertical, RetroTheme.controlSpacing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
        }
        .draggable(DraggedWorkItemID(modelID: workItem.persistentModelID))
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
