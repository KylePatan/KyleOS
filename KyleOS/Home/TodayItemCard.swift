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

    /// Dense single-row layout per Decision Gate C §4: "prefer rows, lists, tables... over giant
    /// cards" — the spec's own example is exactly this shape (checkbox/title/category/due-date/
    /// progress on one line). The info area and Start Timer are sibling Buttons in one HStack
    /// (not nested — SwiftUI Buttons inside Buttons don't reliably route taps), so clicking
    /// anywhere in the info area navigates while Start Timer keeps its own independent tap target.
    var body: some View {
        HStack(spacing: RetroTheme.controlSpacing) {
            Button {
                navigateToWorkItem()
            } label: {
                infoRow
            }
            .buttonStyle(.plain)

            Spacer(minLength: RetroTheme.controlSpacing)

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
            .buttonStyle(.retro)
            .disabled(timerController.state != .idle)
        }
        .padding(.horizontal, RetroTheme.controlSpacing + 4)
        .padding(.vertical, RetroTheme.controlSpacing)
        .overlay(alignment: .bottom) {
            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
        }
    }

    private var infoRow: some View {
        HStack(spacing: RetroTheme.controlSpacing) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(workItem.workspace.rawValue.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(RetroTheme.accent)
                    Text("—")
                        .font(.caption2)
                        .foregroundStyle(RetroTheme.secondaryText)
                    Text(workItem.project?.title ?? "Untitled")
                        .font(.caption2)
                        .foregroundStyle(RetroTheme.secondaryText)
                }
                Text(workItem.workTypeName)
                    .font(.callout.bold())
                    .foregroundStyle(RetroTheme.primaryText)
            }

            Spacer(minLength: RetroTheme.controlSpacing)

            if let dueAt = workItem.deadline?.dueAt {
                Text("Due \(dueAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.warning)
            }

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(workItem.progress)%")
                    .font(.callout.bold())
                    .foregroundStyle(RetroTheme.primaryText)
                Text(timeSummary)
                    .font(.caption2)
                    .foregroundStyle(RetroTheme.secondaryText)
            }
        }
        .contentShape(Rectangle())
    }

    private var timeSummary: String {
        var parts = ["Total: \(TimeFormatting.shortDuration(totalProjectSeconds))"]
        if let todaysSeconds {
            parts.insert("Today: \(TimeFormatting.shortDuration(todaysSeconds))", at: 0)
        }
        return parts.joined(separator: " · ")
    }

    private func navigateToWorkItem() {
        guard let target = DeepLinkTarget.forWorkItem(workItem) else { return }
        navigator.navigate(to: target)
    }
}
