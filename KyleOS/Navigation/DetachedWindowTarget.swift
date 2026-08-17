import SwiftData

/// Kyle (2026-08-17): "when I'm looking at something like the ACTs in a tv pilot, I should be
/// able to open ACT 1 scenes in a different window... This should be the same for all items in
/// all potential projects." A piece of content that can be popped out into its own native macOS
/// window via `openWindow`, distinct from `DeepLinkTarget` (which navigates within the single
/// main window). `openWindow(value:)` requires `Codable & Hashable`; `PersistentIdentifier`
/// already is, so each case just carries the id(s) needed to re-resolve the real model once the
/// new window mounts, via `DetachedWindowRootView`.
///
/// 2026-08-17: extended from the single `.actScenes` slice to every module's primary
/// list-with-detail screen (Chunks, Headline Sets, Gigs, Sources, Clips, Sketch projects) per
/// Kyle's explicit "This should be the same for all items in all potential projects."
enum DetachedWindowTarget: Codable, Hashable, Identifiable {
    case actScenes(PersistentIdentifier)
    case chunkDetail(PersistentIdentifier)
    case headlineSetDetail(PersistentIdentifier)
    case gigDetail(PersistentIdentifier)
    case sourceDetail(PersistentIdentifier)
    case clipDetail(PersistentIdentifier)
    case sketchDetail(PersistentIdentifier)

    var id: Self { self }
}
