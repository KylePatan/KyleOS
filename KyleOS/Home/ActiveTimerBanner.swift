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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                    Text(workItem.title).font(.headline)
                    Spacer()
                    if timerController.state == .paused {
                        Text("Paused").foregroundStyle(.secondary)
                    }
                }

                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(spacing: 8) {
                        Text(TimeFormatting.shortDuration(timerController.currentActiveDurationSeconds))
                            .font(.system(.title2, design: .monospaced))
                        if let target = timerController.targetDurationMinutes {
                            Text("of \(TimeFormatting.shortDuration(target * 60)) planned")
                                .foregroundStyle(.secondary)
                        }
                        if timerController.hasReachedGoal {
                            Text("Goal reached — Finish or keep working")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                HStack {
                    if timerController.state == .running {
                        Button("Pause") { timerController.pause(context: context) }
                    } else {
                        Button("Resume") { timerController.resume(context: context) }
                    }
                    Button("Finish") {
                        finishProgress = Double(workItem.progress)
                        showingFinishPrompt = true
                    }
                    Button("Discard", role: .destructive) {
                        timerController.discard(context: context)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .sheet(isPresented: $showingFinishPrompt) {
                FinishSessionPrompt(progress: $finishProgress) {
                    timerController.finish(progressAfter: Int(finishProgress), context: context)
                    try? context.save()
                }
            }
        }
    }
}
