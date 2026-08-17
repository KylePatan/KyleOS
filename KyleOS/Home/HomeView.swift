import SwiftUI
import SwiftData

/// The real V0.1 Home Today/Priority View + All Tasks + Creative Capacity + Basic Month Calendar +
/// Quick Add + Active Timer display (PRD §4.1/§4.2/§4.4/§4.5/§4.7/§4.8, roadmap's "Basic month
/// calendar"). Still deliberately NOT the finished dashboard and NOT the full Calendar workspace
/// (PRD §11, still a nav placeholder). "Do not build the finished Home dashboard"
/// (CURRENT_PHASE.md) means don't build all of §4 at once, not that no real piece of it may exist
/// during V0.1.
///
/// Today's ranking is now `SchedulingService.rankedItems` (V0.7 Scheduling Engine increment 1,
/// Decision Gate B resolved) rather than `HomeService.rankedTodayItems`'s simple V0.1-era sort —
/// see that service's own doc comment for the full algorithm. Cascade rescheduling (§4.6) is
/// still increment 2, not built here.
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
    @State private var interruptedSession: KyleOSSchemaV30.ActiveTimerState?
    @State private var hasCheckedForRecovery = false
    @State private var tieResolvedThisSession = false

    private var rankedItems: [SchedulingService.ScoredWorkItem] {
        SchedulingService.rankedItems(from: allWorkItems)
    }

    /// Only surfaced once per app session — once Kyle resolves a tie (or the underlying data
    /// changes enough that it's no longer actually tied), don't keep re-prompting on every view
    /// refresh for what's effectively the same decision.
    private var pendingTie: (first: HomeService.WorkItem, second: HomeService.WorkItem)? {
        guard !tieResolvedThisSession else { return nil }
        guard let tie = SchedulingService.topTie(in: rankedItems) else { return nil }
        return (tie.first.workItem, tie.second.workItem)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ActiveTimerBanner()
                .padding(.horizontal, RetroTheme.sectionPadding)
                .padding(.top, RetroTheme.controlSpacing)

            RetroTabs(tabs: Tab.allCases.map { ($0, $0.rawValue) }, selection: $selectedTab)
                .padding(.horizontal, RetroTheme.sectionPadding)
                .padding(.top, RetroTheme.controlSpacing)

            switch selectedTab {
            case .today:
                weeklyBoardContent
            case .allTasks:
                AllTasksView()
            case .calendar:
                MonthCalendarView()
            case .postIt:
                PostItView()
            }
        }
        .background(RetroTheme.background)
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
        .sheet(isPresented: Binding(
            get: { pendingTie != nil },
            set: { isPresented in if !isPresented { tieResolvedThisSession = true } }
        )) {
            if let tie = pendingTie {
                SchedulingTieBreakPrompt(first: tie.first, second: tie.second) { chosen in
                    let other = chosen.id == tie.first.id ? tie.second : tie.first
                    SchedulingService.resolveTie(choosing: chosen, over: other)
                    try? context.save()
                    tieResolvedThisSession = true
                }
            }
        }
    }

    /// Kyle (2026-08-17): "Don't just have 'today' in home. Let's extend that with a weekly
    /// calendar" — see `WeeklyBoardView`'s own doc comment for the full design. Capacity stays
    /// pinned above the board since it's still a same-day-relevant number, not a per-column one.
    private var weeklyBoardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            CreativeCapacityWidget()
                .padding(.horizontal, RetroTheme.sectionPadding)
                .padding(.top, RetroTheme.sectionPadding)
            WeeklyBoardView(allWorkItems: allWorkItems)
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(FocusTimerController())
        .environment(AppNavigationController())
}
