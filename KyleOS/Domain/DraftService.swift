import Foundation
import SwiftData

/// Reusable domain actions for Draft history (PRD §14.5/§6.15), kept out of views per CLAUDE.md
/// §4. A Draft is a formally preserved, immutable prior version — distinct from autosave
/// recovery snapshots, which are transient and never user-visible (§6.16).
enum DraftService {
    typealias Document = KyleOSSchemaV32.Document
    typealias Draft = KyleOSSchemaV32.Draft

    /// PRD §6.15's own example progression: "First Draft, Second Draft, Third Draft,
    /// additional/custom drafts." Beyond the named ordinals, falls back to a numbered label —
    /// the user can always rename `Document.currentDraftLabel` manually afterward.
    private static let ordinalLabels = [
        "First Draft", "Second Draft", "Third Draft", "Fourth Draft", "Fifth Draft",
        "Sixth Draft", "Seventh Draft", "Eighth Draft", "Ninth Draft", "Tenth Draft"
    ]

    static func suggestedLabel(afterFrozenDraftCount count: Int) -> String {
        count < ordinalLabels.count ? ordinalLabels[count] : "Draft \(count + 1)"
    }

    /// Freezes the document's current content under its current label as formal history, then
    /// advances `currentDraftLabel` to the next suggested name. Content itself is left
    /// untouched — starting a new draft continues from where the last one left off, it doesn't
    /// blank the page.
    @discardableResult
    static func startNewDraft(for document: Document, context: ModelContext) -> Draft {
        let priorDraftCount = document.drafts.count
        let frozen = Draft(label: document.displayDraftLabel, content: document.content, document: document)
        context.insert(frozen)
        document.currentDraftLabel = suggestedLabel(afterFrozenDraftCount: priorDraftCount + 1)
        document.updatedAt = .now
        return frozen
    }

    /// Restoring never silently discards the current live content (CLAUDE.md §5: data safety
    /// over polish) — it's frozen as its own draft first, so nothing is lost even if the restore
    /// wasn't what the user meant.
    static func restore(_ draft: Draft, into document: Document, context: ModelContext) {
        startNewDraft(for: document, context: context)
        document.content = draft.content
        document.updatedAt = .now
    }

    static func drafts(for document: Document) -> [Draft] {
        document.drafts.sorted { $0.createdAt > $1.createdAt }
    }
}
