import SwiftUI
import SwiftData

/// PRD §16.7: "offer resume/end/discard choices for an interrupted session." Shown when Home
/// detects a leftover ActiveTimerState checkpoint from a PRIOR run — see HomeView's detection
/// guard for why a live in-progress session's own checkpoint never triggers this.
struct InterruptedSessionPrompt: View {
    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController

    let state: KyleOSSchemaV30.ActiveTimerState
    let onResolved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Interrupted Session Found")
                .font(.title2)
            if let workItem = state.workItem {
                Text("A timer for \u{201C}\(workItem.title)\u{201D} didn\u{2019}t close cleanly last time.")
            } else {
                Text("A timer session didn\u{2019}t close cleanly last time.")
            }
            Text("Checkpointed active time: \(TimeFormatting.shortDuration(state.activeDurationSecondsAtCheckpoint))")
                .foregroundStyle(.secondary)

            HStack {
                Button("Discard", role: .destructive) {
                    TimerRecoveryService.discard(state, context: context)
                    try? context.save()
                    onResolved()
                }
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
                Button("Resume") {
                    TimerRecoveryService.resume(state, into: timerController)
                    onResolved()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 380)
    }
}
