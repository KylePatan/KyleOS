import SwiftUI

/// Root application chrome. Home is the default startup screen per Master PRD §3.
///
/// Decision Gate C (`docs/VISUAL_DESIGN_SYSTEM.md`, resolved 2026-08-15) originally moved primary
/// module switching from a left sidebar to a horizontal top bar (`RetroTopNav`). Kyle reversed
/// that call 2026-08-19: "I want to change the top bar and put it on the left hand side again. I
/// like that look better." Back to a left `RetroSidebar` + `RetroPageHeader` (the current
/// destination's title) for the content area. Secondary/contextual navigation — Writing's own
/// project list, a Chunk list, Clips' Source list — still lives inside each module's own content
/// area, unaffected by this primary-nav change either way.
struct RootView: View {
    @Environment(AppNavigationController.self) private var navigator

    private var selection: SidebarDestination { navigator.selection ?? .home }

    var body: some View {
        HStack(spacing: 0) {
            RetroSidebar()
            VStack(spacing: 0) {
                RetroPageHeader(selection.title)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(RetroTheme.background)
            }
        }
        .background(RetroTheme.background)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .home:
            HomeView()
        case .writing:
            WritingHomeView()
        case .standUp:
            StandUpHomeView()
        case .clips:
            ClipsHomeView()
        case .sketches:
            SketchBoardView()
        case .packets:
            PacketsHomeView()
        case .submissions:
            SubmissionsBoardView()
        case .calendar:
            CalendarHomeView()
        case .reports:
            ReportsView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(FocusTimerController())
        .environment(AppNavigationController())
}
