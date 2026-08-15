import SwiftUI
import SwiftData

/// PRD §4.2's task card fields: workspace/category, project title, current stage, progress,
/// planned session duration, total project time, work date, hard deadline.
///
/// Kyle (2026-08-15): "I feel like it's easiest if everything is clickable... if i click on
/// screenplay in writing, it should take me to that project. Or what if i click on 'start timer'
/// and it takes me to that project." Both the card body and Start Timer now navigate via the
/// shared `AppNavigationController` — Start Timer starts the session (so `ActiveTimerBanner`
/// keeps tracking it anywhere you go next) and then jumps straight to the work itself, since
/// staying on Home after starting a session isn't the point.
struct TodayItemCard: View {
    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController
    @Environment(AppNavigationController.self) private var navigator

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
            Button {
                navigateToWorkItem()
            } label: {
                cardContent
            }
            .buttonStyle(.plain)

            Button("Start Timer") {
                timerController.start(
                    workItem: workItem,
                    targetDurationMinutes: workItem.preferredSessionMinutes,
                    progressBefore: workItem.progress,
                    context: context
                )
                try? context.save()
                navigateToWorkItem()
            }
            .disabled(timerController.state != .idle)
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var cardContent: some View {
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
        }
        .contentShape(Rectangle())
    }

    private func navigateToWorkItem() {
        guard let target = DeepLinkTarget.forWorkItem(workItem) else { return }
        navigator.navigate(to: target)
    }
}
