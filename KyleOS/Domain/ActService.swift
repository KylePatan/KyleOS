import Foundation
import SwiftData

/// Reusable domain actions for the High-Level Act Outline (PRD §6.11/§14.4), kept out of views
/// per CLAUDE.md §4. Acts read top-to-bottom in story order — `order` is a plain ascending
/// index, not WorkItem's inverted "higher number = more important" priority scheme.
enum ActService {
    typealias Act = KyleOSSchemaV33.Act
    typealias Document = KyleOSSchemaV33.Document

    @discardableResult
    static func createAct(title: String, synopsis: String = "", in document: Document, context: ModelContext) -> Act {
        let act = Act(title: title, synopsis: synopsis, order: document.acts.count, document: document)
        context.insert(act)
        return act
    }

    static func rename(_ act: Act, to newTitle: String) {
        act.title = newTitle
        act.updatedAt = .now
    }

    static func updateSynopsis(_ act: Act, synopsis: String) {
        act.synopsis = synopsis
        act.updatedAt = .now
    }

    static func delete(_ act: Act, from document: Document, context: ModelContext) {
        context.delete(act)
        renumber(acts(for: document).filter { $0.id != act.id })
    }

    static func acts(for document: Document) -> [Act] {
        document.acts.sorted { $0.order < $1.order }
    }

    /// Applies a drag-to-reorder move (PRD §6.11: "reorderable"). `source`/`destination` follow
    /// SwiftUI's `.onMove` semantics directly.
    static func reorder(_ document: Document, movingFromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = acts(for: document)
        ordered.move(fromOffsets: source, toOffset: destination)
        renumber(ordered)
    }

    private static func renumber(_ orderedActs: [Act]) {
        for (index, act) in orderedActs.enumerated() {
            act.order = index
            act.updatedAt = .now
        }
    }
}
