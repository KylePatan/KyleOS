import SwiftUI
import SwiftData

/// PRD §4.8: "If a Focus Timer is running, Home should display the current session and
/// elapsed/planned duration." Live-ticks via TimelineView rather than the controller owning a
/// RunLoop timer itself — see FocusTimerController's doc comment for why that split exists.
struct ActiveTimerBanner: View {
    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController

    @State private var showingFinishPrompt = false
    @State private var finishProgress: Double = 0

    var body: some View {
        if timerController.state != .idle, let workItem = timerController.workItem {
            RetroPanel {
                VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundStyle(RetroTheme.accent)
                        Text(workItem.title).font(.headline).foregroundStyle(RetroTheme.primaryText)
                        Spacer()
                        if timerController.state == .paused {
                            Text("Paused").foregroundStyle(RetroTheme.secondaryText)
                        }
                    }

                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        HStack(spacing: RetroTheme.controlSpacing) {
                            Text(TimeFormatting.shortDuration(timerController.currentActiveDurationSeconds))
                                .font(.system(.title2, design: .monospaced))
                                .foregroundStyle(RetroTheme.primaryText)
                            if let target = timerController.targetDurationMinutes {
                                Text("of \(TimeFormatting.shortDuration(target * 60)) planned")
                                    .foregroundStyle(RetroTheme.secondaryText)
                            }
                            if timerController.hasReachedGoal {
                                Text("Goal reached — Finish or keep working")
                                    .font(.caption)
                                    .foregroundStyle(RetroTheme.accent)
                            }
                        }
                    }

                    HStack {
                        if timerController.state == .running {
                            Button("Pause") { timerController.pause(context: context) }
                                .buttonStyle(.retro)
                        } else {
                            Button("Resume") { timerController.resume(context: context) }
                                .buttonStyle(.retro)
                        }
                        Button("Finish") {
                            finishProgress = Double(workItem.progress)
                            showingFinishPrompt = true
                        }
                        .buttonStyle(.retroProminent)
                        Button("Discard", role: .destructive) {
                            timerController.discard(context: context)
                        }
                        .buttonStyle(.retro)
                    }
                }
            }
            .sheet(isPresented: $showingFinishPrompt) {
                FinishSessionPrompt(progress: $finishProgress) {
                    timerController.finish(progressAfter: Int(finishProgress), context: context)
                    try? context.save()
                }
            }
        }
    }
}
