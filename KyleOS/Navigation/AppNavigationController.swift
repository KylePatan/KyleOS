import Foundation
import SwiftData

/// What a Home card (or any future cross-module "take me there" affordance) should navigate to.
/// One case per real destination the app can currently reach, not a generic PersistentIdentifier
/// + type-tag pair — keeps each module's own consumption code exhaustive and compiler-checked
/// rather than needing a runtime type check.
enum DeepLinkTarget: Equatable {
    case writingProject(PersistentIdentifier)
    case standUpChunk(PersistentIdentifier)
    /// A loose Joke isn't in a Chunk, and there's no standalone Joke Detail screen yet (PRD
    /// §7.4's fuller Joke Detail view is a later increment — board-level inline editing only so
    /// far, see JokeService's own doc comment). The honest destination is the Joke Board tab
    /// itself, not a fabricated detail push to a screen that doesn't exist.
    case standUpJokeBoard
    case clip(PersistentIdentifier)
    case sketchProject(PersistentIdentifier)

    /// Where a given Work Item's own material actually lives, if anywhere navigable. Centralized
    /// here (not duplicated per card/view) since any future "make it clickable" affordance needs
    /// the exact same resolution: a Project either is a Sketch (`projectType == .sketch`) or a
    /// plain Writing project; Stand-Up material is a Chunk, a loose Joke, or neither (a general,
    /// untargeted session, which has nowhere specific to go).
    static func forWorkItem(_ workItem: KyleOSSchemaV32.WorkItem) -> DeepLinkTarget? {
        if let project = workItem.project {
            return project.projectType == .sketch
                ? .sketchProject(project.persistentModelID)
                : .writingProject(project.persistentModelID)
        }
        if let chunk = workItem.chunk {
            return .standUpChunk(chunk.persistentModelID)
        }
        if workItem.joke != nil {
            return .standUpJokeBoard
        }
        if let clip = workItem.clip {
            return .clip(clip.persistentModelID)
        }
        return nil
    }
}

/// Kyle (2026-08-15): "I feel like it's easiest if everything is clickable... if i click on
/// screenplay in writing, it should take me to that project." Shared across the whole app
/// (injected once from KyleOSApp, same pattern as FocusTimerController) so any screen — starting
/// with Home's Today cards — can request a jump into another module's specific item, not just
/// switch the sidebar to that module's default list.
///
/// Owns primary-navigation `selection` itself (moved out of RootView, which previously held it
/// as private `@State`) so switching sections and setting a deep-link target happen together,
/// atomically, from one `navigate(to:)` call — a caller never has to separately flip the nav and
/// then hope the destination module notices a target arrived. `selection` is a bare
/// `SidebarDestination` now, not a wrapper enum — the wrapper existed only to unify real
/// destinations with the temporary Dev/ section, which is gone (2026-08-15, once every module it
/// stood in for actually shipped, per that section's own doc comment).
@Observable
final class AppNavigationController {
    var selection: SidebarDestination? = .home

    /// Set by `navigate(to:)`; consumed and cleared by whichever module view owns the
    /// NavigationStack that target belongs to (see each module's own `.task`/`.onChange` hook,
    /// e.g. `WritingHomeView`, `StandUpHomeView`+`ChunkListView`, `ClipsHomeView`+
    /// `SourceListView`, `SketchBoardView`). Nil once consumed so switching sections manually
    /// afterward doesn't replay a stale push.
    var pendingTarget: DeepLinkTarget?

    func navigate(to target: DeepLinkTarget) {
        switch target {
        case .writingProject:
            selection = .writing
        case .standUpChunk, .standUpJokeBoard:
            selection = .standUp
        case .clip:
            selection = .clips
        case .sketchProject:
            selection = .sketches
        }
        pendingTarget = target
    }
}
