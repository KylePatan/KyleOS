import SwiftUI
import SwiftData

/// Root content for a detached (`openWindow`) window. Resolves a `DetachedWindowTarget` back to
/// its live SwiftData object via the same shared `ModelContainer` the main window uses (both
/// windows' `@Query`s independently re-fetch on every save, so edits in either window show up in
/// the other live — the same reactivity guarantee this session's stale-list fixes already
/// established, see `feedback_swiftdata_relationship_lists`). Deliberately renders just the
/// content view itself, no `RetroTopNav`/`RetroPageHeader` — this is meant to read as a focused,
/// single-purpose work window (matching Xcode/Final Cut's own "open in new window" convention),
/// not a second copy of the whole app's chrome.
struct DetachedWindowRootView: View {
    let target: DetachedWindowTarget

    @Query private var allActs: [ActService.Act]
    @Query private var allChunks: [ChunkService.Chunk]
    @Query private var allHeadlineSets: [HeadlineSetService.HeadlineSet]
    @Query private var allGigs: [GigService.Gig]
    @Query private var allSources: [SourceService.Source]
    @Query private var allClips: [ClipService.Clip]
    @Query private var allProjects: [ProjectService.Project]

    var body: some View {
        content
            .frame(minWidth: 480, minHeight: 360)
            .background(RetroTheme.background)
    }

    @ViewBuilder
    private var content: some View {
        switch target {
        case .actScenes(let id):
            if let act = allActs.first(where: { $0.persistentModelID == id }) {
                SceneListView(act: act)
            } else {
                ContentUnavailableView("This Act Was Deleted", systemImage: "trash")
            }
        case .chunkDetail(let id):
            if let chunk = allChunks.first(where: { $0.persistentModelID == id }) {
                ChunkDetailView(chunk: chunk)
            } else {
                ContentUnavailableView("This Chunk Was Deleted", systemImage: "trash")
            }
        case .headlineSetDetail(let id):
            if let set = allHeadlineSets.first(where: { $0.persistentModelID == id }) {
                HeadlineSetDetailView(headlineSet: set)
            } else {
                ContentUnavailableView("This Headline Set Was Deleted", systemImage: "trash")
            }
        case .gigDetail(let id):
            if let gig = allGigs.first(where: { $0.persistentModelID == id }) {
                GigDetailView(gig: gig)
            } else {
                ContentUnavailableView("This Gig Was Deleted", systemImage: "trash")
            }
        case .sourceDetail(let id):
            if let source = allSources.first(where: { $0.persistentModelID == id }) {
                SourceDetailView(source: source)
            } else {
                ContentUnavailableView("This Source Was Deleted", systemImage: "trash")
            }
        case .clipDetail(let id):
            if let clip = allClips.first(where: { $0.persistentModelID == id }) {
                ClipDetailView(clip: clip)
            } else {
                ContentUnavailableView("This Clip Was Deleted", systemImage: "trash")
            }
        case .sketchDetail(let id):
            if let project = allProjects.first(where: { $0.persistentModelID == id }) {
                SketchDetailView(project: project)
            } else {
                ContentUnavailableView("This Sketch Was Deleted", systemImage: "trash")
            }
        }
    }
}
