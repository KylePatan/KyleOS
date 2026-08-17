import SwiftData

/// Kyle (2026-08-17): "when I'm looking at something like the ACTs in a tv pilot, I should be
/// able to open ACT 1 scenes in a different window... This should be the same for all items in
/// all potential projects." A piece of content that can be popped out into its own native macOS
/// window via `openWindow`, distinct from `DeepLinkTarget` (which navigates within the single
/// main window). `openWindow(value:)` requires `Codable & Hashable`; `PersistentIdentifier`
/// already is, so each case just carries the id(s) needed to re-resolve the real model once the
/// new window mounts, via `DetachedWindowRootView`.
///
/// Deliberately extensible, one case at a time — `.actScenes` is the first real slice (matching
/// Kyle's own concrete example exactly), not a blanket rollout to every list in the app yet.
enum DetachedWindowTarget: Codable, Hashable, Identifiable {
    case actScenes(PersistentIdentifier)

    var id: Self { self }
}
