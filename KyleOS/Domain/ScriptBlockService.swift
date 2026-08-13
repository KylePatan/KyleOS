import Foundation
import SwiftData

/// Reusable domain actions for the Script Editor's structured blocks (PRD §6.7/§14.3), kept out
/// of views per CLAUDE.md §4.
///
/// The Enter-key/Tab-key transition rules below implement Decision Gate A's "How should
/// structured screenplay blocks behave" question, resolved as documented industry-standard
/// screenplay-formatting convention (the same Enter/Tab behavior long-established software in
/// this space uses) rather than an invented scheme — PRD §6.7: "Enter-key behavior should move
/// naturally between common screenplay elements."
enum ScriptBlockService {
    typealias ScriptBlock = KyleOSSchemaV12.ScriptBlock
    typealias ScriptElementType = KyleOSSchemaV12.ScriptElementType
    typealias Document = KyleOSSchemaV12.Document

    /// Tab cycles a block's type manually, in this fixed order, regardless of what Enter would
    /// have suggested — PRD §6.7: "The editor should offer a visible element selector as a
    /// fallback"; Tab is the keyboard equivalent of that fallback.
    private static let cycleOrder: [ScriptElementType] = [.sceneHeading, .action, .character, .parenthetical, .dialogue, .transition]

    static func nextTypeInCycle(after type: ScriptElementType) -> ScriptElementType {
        guard let index = cycleOrder.firstIndex(of: type) else { return .action }
        return cycleOrder[(index + 1) % cycleOrder.count]
    }

    /// What Enter after a block of `type` should start next, absent any other signal — standard
    /// screenplay convention: a scene heading or transition is always followed by action; a
    /// character cue is followed by their dialogue; a parenthetical is followed by more dialogue;
    /// dialogue is followed by a new character cue (the next line of the exchange); action stays
    /// in action (most action description runs multiple paragraphs).
    static func suggestedNextType(afterEnterFrom type: ScriptElementType) -> ScriptElementType {
        switch type {
        case .sceneHeading, .transition: return .action
        case .action: return .action
        case .character: return .dialogue
        case .dialogue: return .character
        case .parenthetical: return .dialogue
        }
    }

    static func blocks(for document: Document) -> [ScriptBlock] {
        document.scriptBlocks.sorted { $0.order < $1.order }
    }

    /// Syncs a document's entire block array in one operation — the simplest correct way to
    /// persist edits from a free-form NSTextStorage (see ScriptEditorView) back to structured
    /// SwiftData rows, rather than diffing paragraph-by-paragraph. Existing blocks beyond the
    /// new count are deleted; blocks are always saved together, so this can't leave stale rows.
    static func replaceAllBlocks(for document: Document, with entries: [(type: ScriptElementType, text: String)], context: ModelContext) {
        for block in document.scriptBlocks {
            context.delete(block)
        }
        for (index, entry) in entries.enumerated() {
            let block = ScriptBlock(elementType: entry.type, text: entry.text, order: index, document: document)
            context.insert(block)
        }
    }
}
