import Foundation
import SwiftData

/// Reusable domain actions for the Joke Board (PRD §7.2-§7.4), kept out of views per CLAUDE.md
/// §4. `order` positions a Joke within its current status column — the same "plain ascending
/// index, renumber on delete/move" pattern ActService/SceneService already established.
enum JokeService {
    typealias Joke = KyleOSSchemaV13.Joke
    typealias JokeStatus = KyleOSSchemaV13.JokeStatus

    /// PRD §7.3: "+ Joke Idea should require only the idea text. A short title and additional
    /// detail can be added later."
    @discardableResult
    static func quickCapture(text: String, context: ModelContext) -> Joke {
        let priorCount = jokes(withStatus: .ideas, in: context).count
        let joke = Joke(text: text, status: .ideas, order: priorCount)
        context.insert(joke)
        return joke
    }

    /// Board-level inline editing (title/text only) — the fuller Joke Detail view (§7.4:
    /// premise/setup/punchline/tags/performance notes/runtime) is a later increment; those
    /// model fields already exist but no UI writes them yet.
    static func rename(_ joke: Joke, title: String) {
        joke.title = title
        joke.updatedAt = .now
    }

    static func updateText(_ joke: Joke, text: String) {
        joke.text = text
        joke.updatedAt = .now
    }

    static func jokes(withStatus status: JokeStatus, in context: ModelContext) -> [Joke] {
        let descriptor = FetchDescriptor<Joke>(predicate: #Predicate { !$0.isArchived })
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.status == status }.sorted { $0.order < $1.order }
    }

    /// PRD §7.2: "Jokes are draggable between stages... Moving them updates status
    /// automatically." Appends to the end of the destination column and renumbers the source
    /// column contiguously, the same pattern SceneService.move uses for Acts.
    static func move(_ joke: Joke, to newStatus: JokeStatus, in context: ModelContext) {
        guard joke.status != newStatus else { return }
        let oldStatus = joke.status
        let priorCountInNewStatus = jokes(withStatus: newStatus, in: context).count
        joke.status = newStatus
        joke.order = priorCountInNewStatus
        joke.updatedAt = .now
        renumber(jokes(withStatus: oldStatus, in: context))
    }

    /// PRD §7.2: "...and reorderable within stages."
    static func reorder(withStatus status: JokeStatus, movingFromOffsets source: IndexSet, toOffset destination: Int, in context: ModelContext) {
        var ordered = jokes(withStatus: status, in: context)
        ordered.move(fromOffsets: source, toOffset: destination)
        renumber(ordered)
    }

    static func archive(_ joke: Joke) {
        joke.isArchived = true
        joke.archivedAt = .now
        joke.updatedAt = .now
    }

    static func restore(_ joke: Joke) {
        joke.isArchived = false
        joke.archivedAt = nil
        joke.updatedAt = .now
    }

    private static func renumber(_ ordered: [Joke]) {
        for (index, joke) in ordered.enumerated() {
            joke.order = index
            joke.updatedAt = .now
        }
    }
}
