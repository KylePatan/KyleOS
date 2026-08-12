import SwiftData

/// Distinct navigation-value types for Writing's NavigationStack, rather than reusing bare
/// `PersistentIdentifier` for both — keeps `.navigationDestination(for:)` resolution unambiguous
/// between Projects and Documents sharing the same stack.
struct ProjectRoute: Hashable {
    let id: PersistentIdentifier
}

struct DocumentRoute: Hashable {
    let id: PersistentIdentifier
}
