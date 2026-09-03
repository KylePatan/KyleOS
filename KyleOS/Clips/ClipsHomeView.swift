import SwiftUI

/// V0.4 Clips (PRD §8): "Source Footage -> Identify Clip -> Isolate -> Edit -> Subtitle if
/// needed -> Ready -> Post." Source Media (§8.2), Child Clips (§8.3), the Production status board
/// (§8.4), Editing progress/timer, and the Ready Queue (§8.7) exist so far. Post Date
/// backward-scheduling is explicitly deferred (V0.7 Scheduling Engine territory).
struct ClipsHomeView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case sources = "Sources"
        case board = "Board"
        case readyQueue = "Ready Queue"
        /// Kyle (2026-09-02): "I should be able to put things in folders so I know what things
        /// are what." A separate lens from the Board's own production-status lanes — folders are
        /// purely organizational, orthogonal to status.
        case folders = "Folders"
        var id: String { rawValue }
    }

    @State private var selectedTab: Tab = .sources
    @Environment(AppNavigationController.self) private var navigator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RetroTabs(tabs: Tab.allCases.map { ($0, $0.rawValue) }, selection: $selectedTab)
                .padding(.horizontal, RetroTheme.sectionPadding)
                .padding(.top, RetroTheme.controlSpacing)

            switch selectedTab {
            case .sources: SourceListView()
            case .board: ClipBoardView()
            case .readyQueue: ClipReadyQueueView()
            case .folders: ClipFolderListView()
            }
        }
        .background(RetroTheme.background)
        .navigationTitle("Clips")
        .task(id: navigator.pendingTarget) { selectTabForPendingTarget() }
    }

    /// Only switches the tab — `SourceListView` owns the actual NavigationStack `ClipRoute`
    /// pushes into (it's the tab that stack lives on), so it consumes and clears the target
    /// itself once mounted.
    private func selectTabForPendingTarget() {
        guard case .clip = navigator.pendingTarget else { return }
        selectedTab = .sources
    }
}

#Preview {
    ClipsHomeView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(AppNavigationController())
}
