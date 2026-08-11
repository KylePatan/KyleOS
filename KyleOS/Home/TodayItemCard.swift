import SwiftUI
import SwiftData

/// PRD §4.2's task card fields: workspace/category, project title, current stage, progress,
/// planned session duration, total project time, work date, hard deadline.
struct TodayItemCard: View {
    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController

    let workItem: HomeService.WorkItem

    private var totalProjectSeconds: Int {
        guard let project = workItem.project else { return 0 }
        return HomeService.totalLoggedSeconds(for: project)
    }

    private var todaysSeconds: Int? {
        HomeService.todaysSessionSeconds(for: workItem)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(workItem.workspace.rawValue.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("—").foregroundStyle(.secondary)
                Text(workItem.project?.title ?? "Untitled")
                    .font(.caption)
                    .bold()
                Spacer()
                if let dueAt = workItem.deadline?.dueAt {
                    Text("Deadline: \(dueAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Text(workItem.workTypeName)
                .font(.title3)

            ProgressView(value: Double(workItem.progress), total: 100)
            Text("\(workItem.progress)% complete")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("Planned: \(TimeFormatting.shortDuration(workItem.preferredSessionMinutes * 60))")
                if let todaysSeconds {
                    Text("· Today: \(TimeFormatting.shortDuration(todaysSeconds))")
                }
                Text("· Total: \(TimeFormatting.shortDuration(totalProjectSeconds))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button("Start Timer") {
                timerController.start(
                    workItem: workItem,
                    targetDurationMinutes: workItem.preferredSessionMinutes,
                    progressBefore: workItem.progress,
                    context: context
                )
                try? context.save()
            }
            .disabled(timerController.state != .idle)
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
