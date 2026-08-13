import Foundation
import SwiftData

/// Reusable domain actions for the Headline Set (PRD §7.7), kept out of views per CLAUDE.md §4.
/// Scoped to Chunks only this increment — the PRD's own "primarily... from ordered Chunks";
/// "loose jokes may also be allowed when useful" is a documented later refinement, not decided
/// here (CLAUDE.md §13).
enum HeadlineSetService {
    typealias HeadlineSet = KyleOSSchemaV23.HeadlineSet
    typealias Chunk = KyleOSSchemaV23.Chunk

    @discardableResult
    static func createHeadlineSet(title: String, targetDurationMinutes: Int = 60, context: ModelContext) -> HeadlineSet {
        let set = HeadlineSet(title: title, targetDurationMinutes: targetDurationMinutes)
        context.insert(set)
        return set
    }

    static func rename(_ set: HeadlineSet, to title: String) {
        set.title = title
        set.updatedAt = .now
    }

    static func updateNotes(_ set: HeadlineSet, notes: String) {
        set.notes = notes
        set.updatedAt = .now
    }

    static func updateTargetDuration(_ set: HeadlineSet, minutes: Int) {
        set.targetDurationMinutes = max(minutes, 0)
        set.updatedAt = .now
    }

    static func headlineSets(in context: ModelContext) -> [HeadlineSet] {
        (try? context.fetch(FetchDescriptor<HeadlineSet>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    static func chunks(in set: HeadlineSet) -> [Chunk] {
        set.chunks.sorted { $0.displayOrderInHeadlineSet < $1.displayOrderInHeadlineSet }
    }

    /// PRD §7.7: "Chunk runtimes roll up into total set runtime." Always computed fresh from
    /// members, never stored — can't drift out of sync.
    static func totalRuntimeSeconds(for set: HeadlineSet) -> Int {
        chunks(in: set).reduce(0) { $0 + ($1.runtimeSeconds ?? 0) }
    }

    /// PRD §7.7: "The Headline Set should support a target duration... and display current
    /// runtime versus target."
    static func targetDurationSeconds(for set: HeadlineSet) -> Int {
        set.targetDurationMinutes * 60
    }

    static func addChunk(_ chunk: Chunk, to set: HeadlineSet) {
        let previousSet = chunk.headlineSet
        let priorCount = set.chunks.count
        chunk.headlineSet = set
        chunk.orderInHeadlineSet = priorCount
        chunk.updatedAt = .now
        if let previousSet, previousSet.id != set.id {
            renumber(chunks(in: previousSet))
        }
    }

    static func removeChunk(_ chunk: Chunk, from set: HeadlineSet) {
        chunk.headlineSet = nil
        chunk.orderInHeadlineSet = nil
        chunk.updatedAt = .now
        renumber(chunks(in: set))
    }

    static func reorderChunks(in set: HeadlineSet, movingFromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = chunks(in: set)
        ordered.move(fromOffsets: source, toOffset: destination)
        renumber(ordered)
    }

    /// Chunks not currently in any Headline Set — candidates to add. Filters `headlineSet ==
    /// nil` in-memory, same defensive pattern as ChunkService.looseJokes.
    static func looseChunks(in context: ModelContext) -> [Chunk] {
        let all = (try? context.fetch(FetchDescriptor<Chunk>())) ?? []
        return all.filter { $0.headlineSet == nil }.sorted { $0.createdAt < $1.createdAt }
    }

    static func delete(_ set: HeadlineSet, context: ModelContext) {
        context.delete(set)
    }

    private static func renumber(_ ordered: [Chunk]) {
        for (index, chunk) in ordered.enumerated() {
            chunk.orderInHeadlineSet = index
            chunk.updatedAt = .now
        }
    }
}
