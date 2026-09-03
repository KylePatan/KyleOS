import SwiftUI
import SwiftData

/// PRD §16.7: "offer resume/end/discard choices for an interrupted session." Shown when Home
/// detects a leftover ActiveTimerState checkpoint from a PRIOR run — see HomeView's detection
/// guard for why a live in-progress session's own checkpoint never triggers this.
struct InterruptedSessionPrompt: View {
    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController

    let state: KyleOSSchemaV36.ActiveTimerState
    let onResolved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
            Text("Interrupted Session Found")
                .font(.title2.bold())
                .foregroundStyle(RetroTheme.primaryText)
            if let workItem = state.workItem {
                Text("A timer for \u{201C}\(workItem.title)\u{201D} didn\u{2019}t close cleanly last time.")
                    .foregroundStyle(RetroTheme.primaryText)
            } else {
                Text("A timer session didn\u{2019}t close cleanly last time.")
                    .foregroundStyle(RetroTheme.primaryText)
            }
            Text("Checkpointed active time: \(TimeFormatting.shortDuration(state.activeDurationSecondsAtCheckpoint))")
                .foregroundStyle(RetroTheme.secondaryText)

            HStack {
                Button("Discard", role: .destructive) {
                    TimerRecoveryService.discard(state, context: context)
                    try? context.save()
                    onResolved()
                }
                .buttonStyle(.retro)
                Spacer()
                Button("End Session") {
                    TimerRecoveryService.end(
                        state,
                        progressAfter: state.workItem?.progress ?? state.progressBefore,
                        context: context
                    )
                    try? context.save()
                    onResolved()
                }
                .buttonStyle(.retro)
                Button("Resume") {
                    TimerRecoveryService.resume(state, into: timerController)
                    onResolved()
                }
                .buttonStyle(.retroProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RetroTheme.sectionPadding + 8)
        .frame(minWidth: 380)
        .background(RetroTheme.panelBackground)
    }
}
