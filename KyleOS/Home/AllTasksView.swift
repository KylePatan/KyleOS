import SwiftUI
import SwiftData

/// PRD §4.5: "Home should also contain an All Tasks or Planning view containing every unfinished
/// Work Item across the app. This list should be draggable and manually reorderable. Dragging
/// changes priority, not just appearance." Cascade rescheduling (§4.6 — bumping lower-priority
/// flexible work when a deadline gets tight) is explicitly NOT built here; that's Scheduling
/// Engine territory (V0.7, Decision Gate B). Dragging only ever renumbers priority.
struct AllTasksView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\HomeService.WorkItem.priority, order: .reverse)])
    private var allWorkItems: [HomeService.WorkItem]

    private var items: [HomeService.WorkItem] {
        HomeService.allUnfinishedItems(from: allWorkItems)
    }

    var body: some View {
        if items.isEmpty {
            Text("No unfinished work items yet.")
                .foregroundStyle(RetroTheme.secondaryText)
                .padding(RetroTheme.sectionPadding)
        } else {
            RetroPanel("All Tasks") {
                List {
                    ForEach(items) { item in
                        AllTasksRow(workItem: item)
                            .listRowBackground(RetroTheme.panelBackground)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparatorTint(RetroTheme.border.opacity(0.5))
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: max(200, CGFloat(items.count) * 40 + 20))
            }
            .padding(RetroTheme.sectionPadding)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        for (item, newPriority) in HomeService.reorderedPriorities(current: items, movingFromOffsets: source, toOffset: destination) {
            WorkItemService.setPriority(item, to: newPriority)
        }
        try? context.save()
    }
}

private struct AllTasksRow: View {
    let workItem: HomeService.WorkItem
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: RetroTheme.controlSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workItem.title)
                    .font(.callout)
                    .foregroundStyle(RetroTheme.primaryText)
                Text("\(workItem.workspace.rawValue) — \(workItem.project?.title ?? "Untitled") — \(workItem.workTypeName)")
                    .font(.caption2)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
            Spacer()
            Text("\(workItem.progress)%")
                .font(.caption)
                .foregroundStyle(RetroTheme.secondaryText)
            if let dueAt = workItem.deadline?.dueAt {
                Text(dueAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(RetroTheme.warning)
            }
        }
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
        // Kyle (2026-08-20): "the things on 'home' should be removeable." Same resolution as
        // WeeklyBoardView's cards — see WorkItemService.underlyingContent's own doc comment.
        .archiveDeleteContextMenuIfApplicable(for: workItem, context: context)
    }
}
