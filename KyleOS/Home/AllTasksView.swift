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
                .foregroundStyle(.secondary)
                .padding()
        } else {
            List {
                ForEach(items) { item in
                    AllTasksRow(workItem: item)
                }
                .onMove(perform: move)
            }
            .listStyle(.inset)
            .frame(minHeight: 200, idealHeight: CGFloat(items.count) * 44 + 20)
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workItem.title)
                Text("\(workItem.workspace.rawValue) — \(workItem.project?.title ?? "Untitled") — \(workItem.workTypeName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(workItem.progress)%")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let dueAt = workItem.deadline?.dueAt {
                Text(dueAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
