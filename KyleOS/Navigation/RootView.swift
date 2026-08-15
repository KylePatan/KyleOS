import SwiftUI

/// Root application chrome. Home is the default startup screen per Master PRD §3.
///
/// Decision Gate C (`docs/VISUAL_DESIGN_SYSTEM.md`, resolved 2026-08-15) §13: "avoid giant
/// sidebar navigation... horizontal navigation near the top supports the intended top-down
/// architecture." This replaces the original `NavigationSplitView` sidebar with `RetroTopNav`
/// (primary module switching) + `RetroPageHeader` (the current destination's title, replacing
/// reliance on each module's own now-title-bar-less `.navigationTitle()`). Secondary/contextual
/// navigation — Writing's own project list, a Chunk list, Clips' Source list — still lives inside
/// each module's own content area, per the spec's own carve-out for that.
struct RootView: View {
    @Environment(AppNavigationController.self) private var navigator

    private var selection: SidebarDestination { navigator.selection ?? .home }

    var body: some View {
        VStack(spacing: 0) {
            RetroTopNav()
            RetroPageHeader(selection.title)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(RetroTheme.background)
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
        case .calendar:
            CalendarHomeView()
        case .reports:
            ReportsView()
        case .settings:
            PlaceholderDestinationView(destination: .settings)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(FocusTimerController())
        .environment(AppNavigationController())
}
