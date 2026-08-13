import SwiftData

/// Distinct navigation-value types for the Clips Sources tab's NavigationStack, rather than
/// reusing bare `PersistentIdentifier` for both — keeps `.navigationDestination(for:)`
/// resolution unambiguous between Sources and Clips sharing the same stack (same reasoning as
/// Writing's `ProjectRoute`/`DocumentRoute`/`ActRoute`).
struct SourceRoute: Hashable {
    let id: PersistentIdentifier
}

struct ClipRoute: Hashable {
    let id: PersistentIdentifier
}
