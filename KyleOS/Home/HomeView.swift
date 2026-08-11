import SwiftUI
import SwiftData

/// The real V0.1 Home Today/Priority View + Active Timer display (PRD §4.1/§4.2/§4.8). Still
/// deliberately NOT the finished dashboard — no All Tasks drag-reorder, Quick Add, or month
/// calendar yet (those are separate increments). "Do not build the finished Home dashboard"
/// (CURRENT_PHASE.md) means don't build all of §4 at once, not that no real piece of it may
/// exist during V0.1.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController

    @Query private var allWorkItems: [HomeService.WorkItem]

    @State private var interruptedSession: KyleOSSchemaV7.ActiveTimerState?
    @State private var hasCheckedForRecovery = false

    private var todayItems: [HomeService.WorkItem] {
        HomeService.rankedTodayItems(from: allWorkItems)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ActiveTimerBanner()

                Text("Today")
                    .font(.title2)
                    .bold()

                if todayItems.isEmpty {
                    // PRD §4.9: an empty/blocked day isn't failure — say so plainly.
                    Text("Nothing scheduled. Enjoy the break, or start something from Projects.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todayItems) { item in
                        TodayItemCard(workItem: item)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Home")
        .task {
            guard !hasCheckedForRecovery else { return }
            hasCheckedForRecovery = true
            // Only a genuine leftover from a PRIOR run triggers this — if this run already
            // started/resumed a session, the controller is no longer idle, and any checkpoint
            // found is that same live session's own, not something to prompt about.
            guard timerController.state == .idle else { return }
            interruptedSession = try? TimerRecoveryService.checkForInterruptedSession(in: context)
        }
        .sheet(item: $interruptedSession) { state in
            InterruptedSessionPrompt(state: state) {
                interruptedSession = nil
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(FocusTimerController())
}
