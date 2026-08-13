import Foundation
import SwiftData

/// Reusable domain actions for Chunks (PRD §7.5-§7.6), kept out of views per CLAUDE.md §4.
enum ChunkService {
    typealias Chunk = KyleOSSchemaV23.Chunk
    typealias Joke = KyleOSSchemaV23.Joke

    @discardableResult
    static func createChunk(title: String, context: ModelContext) -> Chunk {
        let chunk = Chunk(title: title)
        context.insert(chunk)
        return chunk
    }

    static func rename(_ chunk: Chunk, to title: String) {
        chunk.title = title
        chunk.updatedAt = .now
    }

    static func updateNotes(_ chunk: Chunk, notes: String) {
        chunk.notes = notes
        chunk.updatedAt = .now
    }

    static func chunks(in context: ModelContext) -> [Chunk] {
        (try? context.fetch(FetchDescriptor<Chunk>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    static func jokes(in chunk: Chunk) -> [Joke] {
        chunk.jokes.sorted { $0.displayOrderWithinChunk < $1.displayOrderWithinChunk }
    }

    /// PRD §7.5: "A Joke can exist independently or be referenced inside a Chunk." Appends to
    /// the end; if the joke already belonged to a different chunk, that chunk's remaining jokes
    /// are renumbered so no gap is left.
    static func addJoke(_ joke: Joke, to chunk: Chunk) {
        let previousChunk = joke.chunk
        let priorCount = chunk.jokes.count
        joke.chunk = chunk
        joke.orderWithinChunk = priorCount
        joke.updatedAt = .now
        if let previousChunk, previousChunk.id != chunk.id {
            renumber(jokes(in: previousChunk))
        }
    }

    /// PRD §7.6: "Removing a Joke from a Chunk should only remove the relationship, not delete
    /// the Joke."
    static func removeJoke(_ joke: Joke, from chunk: Chunk) {
        joke.chunk = nil
        joke.orderWithinChunk = nil
        joke.updatedAt = .now
        renumber(jokes(in: chunk))
    }

    /// PRD §7.6: "Jokes should be draggable within a Chunk."
    static func reorderJokes(in chunk: Chunk, movingFromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = jokes(in: chunk)
        ordered.move(fromOffsets: source, toOffset: destination)
        renumber(ordered)
    }

    /// Jokes not currently referenced by any Chunk — candidates to add. Filters `chunk == nil`
    /// in-memory rather than in the #Predicate — this codebase has no confirmed-safe precedent
    /// for relationship-nil-checks inside #Predicate (only enum comparisons are documented as
    /// unsafe so far, but the safe workaround is identical either way).
    static func looseJokes(in context: ModelContext) -> [Joke] {
        let descriptor = FetchDescriptor<Joke>(predicate: #Predicate { !$0.isArchived })
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.chunk == nil }.sorted { $0.createdAt < $1.createdAt }
    }

    /// Deleting a Chunk must not delete its member Jokes — already guaranteed by the model's
    /// `.nullify` delete rule, so this is just `context.delete`, kept here so callers go through
    /// the Service layer rather than calling SwiftData directly (CLAUDE.md §4).
    static func delete(_ chunk: Chunk, context: ModelContext) {
        context.delete(chunk)
    }

    private static func renumber(_ ordered: [Joke]) {
        for (index, joke) in ordered.enumerated() {
            joke.orderWithinChunk = index
            joke.updatedAt = .now
        }
    }
}
