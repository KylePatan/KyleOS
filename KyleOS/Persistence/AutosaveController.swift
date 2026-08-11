import Foundation

/// Debounces rapid changes (e.g. keystrokes) into a single delayed save instead of writing on
/// every character. Framework-agnostic, no SwiftUI/View dependency — autosave timing is
/// persistence infrastructure, not view logic (CLAUDE.md §4).
final class AutosaveController {
    private var pendingWork: DispatchWorkItem?
    private let delay: TimeInterval

    init(delay: TimeInterval = 1.5) {
        self.delay = delay
    }

    /// Schedules `action` after the debounce delay, cancelling any not-yet-run save from a
    /// previous call — so a burst of edits collapses into one write.
    func scheduleSave(_ action: @escaping () -> Void) {
        pendingWork?.cancel()
        let work = DispatchWorkItem(block: action)
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Cancels any pending debounced save and runs `action` immediately — e.g. when a document
    /// is about to close and a not-yet-fired autosave must not be lost or fire late.
    func saveImmediately(_ action: () -> Void) {
        pendingWork?.cancel()
        pendingWork = nil
        action()
    }

    var hasPendingSave: Bool {
        pendingWork != nil
    }
}
