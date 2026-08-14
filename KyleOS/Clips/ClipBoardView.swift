import SwiftUI
import SwiftData

/// PRD §8.4: "A board can visually simplify these to To Isolate, Editing, Needs Subtitles,
/// Ready, Posted." Shows every Clip across every Source, grouped into the 5 simplified lanes
/// (`ClipService.boardLane`) — same "explicit Move to… menu, not a competing drag gesture" choice
/// as JokeBoardView (CLAUDE.md §13, documented implementation choice).
struct ClipBoardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClipService.Clip.createdAt) private var allClips: [ClipService.Clip]

    private func clips(in lane: ClipService.BoardLane) -> [ClipService.Clip] {
        allClips.filter { ClipService.boardLane(for: $0.status) == lane }
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(ClipService.BoardLane.allCases, id: \.self) { lane in
                    column(for: lane)
                }
            }
            .padding()
        }
    }

    private func column(for lane: ClipService.BoardLane) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lane.rawValue).font(.headline)
            let items = clips(in: lane)
            if items.isEmpty {
                Text("No clips here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(items) { clip in
                        ClipCard(clip: clip, otherLanes: ClipService.BoardLane.allCases.filter { $0 != lane })
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 160, idealHeight: CGFloat(items.count) * 60 + 20)
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
    }
}

private struct ClipCard: View {
    let clip: ClipService.Clip
    let otherLanes: [ClipService.BoardLane]

    @Environment(\.modelContext) private var context

    /// The "Move to" menu sets a lane's primary/entry status — a documented simplification
    /// (CLAUDE.md §13) since a lane can represent more than one real `ClipStatus`. Finer-grained
    /// status selection (e.g. distinguishing Footage Isolated from Currently Editing) is
    /// available via ClipDetailView's full status picker.
    private func primaryStatus(for lane: ClipService.BoardLane) -> ClipService.ClipStatus {
        switch lane {
        case .toIsolate: return .identifiedToIsolate
        case .editing: return .currentlyEditing
        case .needsSubtitles: return .editedNotSubtitled
        case .ready: return .ready
        case .posted: return .posted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(clip.title).font(.callout.bold())
            if let sourceTitle = clip.source?.title {
                Text(sourceTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Menu("Move to") {
                ForEach(otherLanes, id: \.self) { lane in
                    Button(lane.rawValue) {
                        ClipService.changeStatus(clip, to: primaryStatus(for: lane), context: context)
                        try? context.save()
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let source = SourceService.createSource(title: "March Comedy Slam", context: context)
    ClipService.createClip(title: "Airline Bit", in: source, context: context)
    return ClipBoardView()
        .modelContainer(container)
}
