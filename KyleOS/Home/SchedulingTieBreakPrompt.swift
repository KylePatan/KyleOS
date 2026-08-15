import SwiftUI

/// Decision Gate B: "If there are two things that are scored basically exactly [the same], there
/// should be a prompt to ask which one should be worked on - and the user gets to choose as the
/// tie-breaker." Presented from `HomeView` when `SchedulingService.topTie` finds a genuine tie for
/// the #1 spot.
struct SchedulingTieBreakPrompt: View {
    let first: HomeService.WorkItem
    let second: HomeService.WorkItem
    let onChoose: (HomeService.WorkItem) -> Void

    var body: some View {
        VStack(spacing: RetroTheme.sectionSpacing) {
            Text("Which should you work on?")
                .font(.headline)
                .foregroundStyle(RetroTheme.primaryText)
            Text("These are scored about the same — your call breaks the tie.")
                .font(.caption)
                .foregroundStyle(RetroTheme.secondaryText)

            VStack(spacing: RetroTheme.controlSpacing) {
                Button {
                    onChoose(first)
                } label: {
                    optionLabel(for: first)
                }
                .buttonStyle(.retro)

                Button {
                    onChoose(second)
                } label: {
                    optionLabel(for: second)
                }
                .buttonStyle(.retro)
            }
        }
        .padding(RetroTheme.sectionPadding + 8)
        .frame(width: 360)
        .background(RetroTheme.panelBackground)
    }

    private func optionLabel(for workItem: HomeService.WorkItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(workItem.title).font(.body.bold()).foregroundStyle(RetroTheme.primaryText)
            Text(workItem.workspace.rawValue).font(.caption).foregroundStyle(RetroTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SchedulingTieBreakPrompt(
        first: HomeService.WorkItem(title: "Outline", workspace: .writing, workTypeName: "Outline", project: nil),
        second: HomeService.WorkItem(title: "Airline Bit", workspace: .standUp, workTypeName: "Stand-Up Development", project: nil),
        onChoose: { _ in }
    )
}
