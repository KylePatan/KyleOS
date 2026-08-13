import Foundation
import SwiftData

/// Reusable domain actions for Gig Set Lists (PRD §7.9), kept out of views per CLAUDE.md §4.
/// "A Gig may have a planned set list built from existing Chunks and Jokes. Set-list items
/// reference existing material rather than duplicate it." `addJoke`/`addChunk` are the only
/// entry points that create a `GigSetListItem`, and each sets exactly one of `joke`/`chunk` —
/// the model itself has no way to enforce that (SwiftData has no sum-type/enum-relationship
/// construct), so it's enforced here instead.
enum GigSetListService {
    typealias Gig = KyleOSSchemaV17.Gig
    typealias GigSetListItem = KyleOSSchemaV17.GigSetListItem
    typealias Joke = KyleOSSchemaV17.Joke
    typealias Chunk = KyleOSSchemaV17.Chunk

    static func items(in gig: Gig) -> [GigSetListItem] {
        gig.setListItems.sorted { $0.order < $1.order }
    }

    @discardableResult
    static func addJoke(_ joke: Joke, to gig: Gig, context: ModelContext) -> GigSetListItem {
        let item = GigSetListItem(order: gig.setListItems.count, joke: joke)
        context.insert(item)
        item.gig = gig
        return item
    }

    @discardableResult
    static func addChunk(_ chunk: Chunk, to gig: Gig, context: ModelContext) -> GigSetListItem {
        let item = GigSetListItem(order: gig.setListItems.count, chunk: chunk)
        context.insert(item)
        item.gig = gig
        return item
    }

    static func removeItem(_ item: GigSetListItem, from gig: Gig, context: ModelContext) {
        context.delete(item)
        renumber(items(in: gig).filter { $0.id != item.id })
    }

    static func reorderItems(in gig: Gig, movingFromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = items(in: gig)
        ordered.move(fromOffsets: source, toOffset: destination)
        renumber(ordered)
    }

    /// "If durations exist, Kyle OS can show the planned set duration versus the gig's target
    /// set length." Items whose referenced Joke/Chunk was since deleted contribute 0, not a
    /// crash — same nil-safe rollup pattern as HeadlineSetService.
    static func plannedDurationSeconds(for gig: Gig) -> Int {
        items(in: gig).reduce(0) { $0 + $1.runtimeSeconds }
    }

    static func targetDurationSeconds(for gig: Gig) -> Int {
        gig.setLengthMinutes * 60
    }

    private static func renumber(_ ordered: [GigSetListItem]) {
        for (index, item) in ordered.enumerated() {
            item.order = index
        }
    }
}
