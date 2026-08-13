import SwiftUI

/// V0.3 Stand Up (PRD §7): Joke Board (§7.2-§7.4) and Chunks (§7.5-§7.6) exist so far. Headline
/// Set, Gigs, Set Lists, and Stand-Up Work Sessions (§7.7-§7.11) are later increments — same
/// "start with the container/board, add hierarchy/detail after" sequencing Writing used.
struct StandUpHomeView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case jokeBoard = "Joke Board"
        case chunks = "Chunks"
        var id: String { rawValue }
    }

    @State private var selectedTab: Tab = .jokeBoard

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
            .frame(maxWidth: 300)

            switch selectedTab {
            case .jokeBoard: JokeBoardView()
            case .chunks: ChunkListView()
            }
        }
        .navigationTitle("Stand Up")
    }
}

#Preview {
    StandUpHomeView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
