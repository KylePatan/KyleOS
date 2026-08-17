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
        }
    }
}
