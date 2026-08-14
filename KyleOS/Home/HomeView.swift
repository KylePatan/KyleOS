import SwiftUI
import SwiftData

/// The real V0.1 Home Today/Priority View + All Tasks + Creative Capacity + Basic Month Calendar +
/// Quick Add + Active Timer display (PRD §4.1/§4.2/§4.4/§4.5/§4.7/§4.8, roadmap's "Basic month
/// calendar"). Still deliberately NOT the finished dashboard and NOT the full Calendar workspace
/// (PRD §11, still a nav placeholder) — cascade rescheduling (§4.6) is explicitly V0.7. "Do not
/// build the finished Home dashboard" (CURRENT_PHASE.md) means don't build all of §4 at once, not
/// that no real piece of it may exist during V0.1.
struct HomeView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case today = "Today"
        case allTasks = "All Tasks"
        case calendar = "Calendar"
        case postIt = "Post It"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController

    @Query private var allWorkItems: [HomeService.WorkItem]

    @State private var selectedTab: Tab = .today
    @State private var interruptedSession: KyleOSSchemaV28.ActiveTimerState?
    @State private var hasCheckedForRecovery = false

    private var todayItems: [HomeService.WorkItem] {
        HomeService.rankedTodayItems(from: allWorkItems)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ActiveTimerBanner()
                .padding([.horizontal, .top])

            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .frame(maxWidth: 420)

            switch selectedTab {
            case .today:
                todayContent
            case .allTasks:
                AllTasksView()
            case .calendar:
                MonthCalendarView()
            case .postIt:
                PostItView()
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                QuickAddButton()
            }
        }
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

    private var todayContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CreativeCapacityWidget()

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
    }
}

#Preview {
    HomeView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(FocusTimerController())
}
