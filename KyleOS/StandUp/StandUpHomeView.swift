import SwiftUI
import SwiftData

/// V0.3 Stand Up (PRD §7): Joke Board (§7.2-§7.4), Chunks (§7.5-§7.6), Headline Set (§7.7), Gigs
/// (§7.8), Gig Set Lists (§7.9), and After-Gig Notes (§7.10) exist so far. Stand-Up Work Sessions
/// (§7.11) is this increment — wired at this container level (not per-tab) so the shared
/// `ActiveTimerBanner`/"general session" affordance stays visible across all four tabs, mirroring
/// how Home shows its own banner at its top level. Per-Joke/Chunk timer starts live where those
/// items are (JokeCard, ChunkDetailView) rather than duplicating the banner there.
struct StandUpHomeView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case jokeBoard = "Joke Board"
        case chunks = "Chunks"
        case headlineSet = "Headline Set"
        case gigs = "Gigs"
        var id: String { rawValue }
    }

    @State private var selectedTab: Tab = .jokeBoard
    @Environment(\.modelContext) private var context
    @Environment(FocusTimerController.self) private var timerController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ActiveTimerBanner()
                .padding(.horizontal)
            if timerController.state == .idle {
                Button("Start General Stand-Up Session") {
                    guard let workItem = try? WorkItemService.generalStandUpWorkItem(context: context) else { return }
                    timerController.start(workItem: workItem, targetDurationMinutes: nil, progressBefore: workItem.progress, context: context)
                    try? context.save()
                }
                .padding(.horizontal)
            }
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()
            .frame(maxWidth: 520)

            switch selectedTab {
            case .jokeBoard: JokeBoardView()
            case .chunks: ChunkListView()
            case .headlineSet: HeadlineSetListView()
            case .gigs: GigListView()
            }
        }
        .navigationTitle("Stand Up")
    }
}

#Preview {
    StandUpHomeView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(FocusTimerController())
}
