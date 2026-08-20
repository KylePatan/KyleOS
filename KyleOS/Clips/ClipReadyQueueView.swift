import SwiftUI
import SwiftData

/// PRD §8.7: "Once required editing/subtitles/export are complete, the Clip becomes Ready. Clips
/// should provide a Ready to Post queue and show the number of finished pieces waiting for
/// release. Getting ahead should be valuable. Kyle OS should distinguish: Production Backlog,
/// Ready Content Buffer, Scheduled Posts." Read-only queue view — editing status/post date still
/// happens in ClipDetailView; this is purely the "where do things stand" rollup.
struct ClipReadyQueueView: View {
    @Query private var allClips: [ClipService.Clip]

    private var backlog: [ClipService.Clip] {
        allClips.filter {
            let lane = ClipService.boardLane(for: $0.status)
            return lane != .ready && lane != .posted
        }
    }
    private var buffer: [ClipService.Clip] {
        allClips.filter { ClipService.boardLane(for: $0.status) == .ready && $0.postDate == nil }
    }
    private var scheduled: [ClipService.Clip] {
        allClips
            .filter { ClipService.boardLane(for: $0.status) == .ready && $0.postDate != nil }
            .sorted { ($0.postDate ?? .distantFuture) < ($1.postDate ?? .distantFuture) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RetroTheme.sectionSpacing) {
                Text("\(buffer.count + scheduled.count) piece\(buffer.count + scheduled.count == 1 ? "" : "s") ready to post")
                    .font(.title3.bold())
                    .foregroundStyle(RetroTheme.primaryText)

                section(title: "Production Backlog", clips: backlog, emptyText: "Nothing in progress.") { clip in
                    Text(ClipService.boardLane(for: clip.status).rawValue)
                        .font(.caption)
                        .foregroundStyle(RetroTheme.secondaryText)
                }

                section(title: "Ready Content Buffer", clips: buffer, emptyText: "No finished pieces waiting yet.") { _ in
                    Text("No post date set")
                        .font(.caption)
                        .foregroundStyle(RetroTheme.secondaryText)
                }

                section(title: "Scheduled Posts", clips: scheduled, emptyText: "Nothing scheduled yet.") { clip in
                    if let date = clip.postDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(RetroTheme.secondaryText)
                    }
                }
            }
            .padding(RetroTheme.sectionPadding)
        }
        .background(RetroTheme.background)
    }

    @ViewBuilder
    private func section<Detail: View>(
        title: String,
        clips: [ClipService.Clip],
        emptyText: String,
        @ViewBuilder detail: @escaping (ClipService.Clip) -> Detail
    ) -> some View {
        RetroPanel("\(title) (\(clips.count))", accentCategory: .clips) {
            if clips.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(RetroTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(clips) { clip in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(clip.title).foregroundStyle(RetroTheme.primaryText)
                                if let sourceTitle = clip.source?.title {
                                    Text(sourceTitle)
                                        .font(.caption2)
                                        .foregroundStyle(RetroTheme.secondaryText)
                                }
                            }
                            Spacer()
                            detail(clip)
                        }
                        .padding(.vertical, RetroTheme.controlSpacing / 2)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(RetroTheme.border.opacity(0.5)).frame(height: RetroTheme.borderWidth)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let context = ModelContext(container)
    let source = SourceService.createSource(title: "March Comedy Slam", context: context)
    let ready = ClipService.createClip(title: "Airline Bit", in: source, context: context)
    ClipService.changeStatus(ready, to: .ready, context: context)
    let scheduled = ClipService.createClip(title: "Travel Bit", in: source, context: context)
    ClipService.changeStatus(scheduled, to: .ready, context: context)
    ClipService.setPostDate(scheduled, date: .now)
    return ClipReadyQueueView()
        .modelContainer(container)
}
