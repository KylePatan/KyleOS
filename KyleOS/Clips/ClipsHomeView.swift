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
        var id: String { rawValue }
    }

    @State private var selectedTab: Tab = .sources

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()
            .frame(maxWidth: 360)

            switch selectedTab {
            case .sources: SourceListView()
            case .board: ClipBoardView()
            case .readyQueue: ClipReadyQueueView()
            }
        }
        .navigationTitle("Clips")
    }
}

#Preview {
    ClipsHomeView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
