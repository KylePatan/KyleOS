import Foundation
import SwiftData

/// PRD §14.19: "Important status changes and progress changes should create history records with
/// timestamps. This enables turnaround and progress-over-time reporting." Kept out of views per
/// CLAUDE.md §4. Values are stored as Strings — each subject's status enum has a different Swift
/// type, and String is the simplest common representation for a log that's read back as display
/// text, not re-parsed into a typed enum.
enum HistoryEventService {
    typealias HistoryEvent = KyleOSSchemaV32.HistoryEvent
    typealias HistoryEventKind = KyleOSSchemaV32.HistoryEventKind
    typealias WorkItem = KyleOSSchemaV32.WorkItem
    typealias Clip = KyleOSSchemaV32.Clip
    typealias Project = KyleOSSchemaV32.Project
    typealias Joke = KyleOSSchemaV32.Joke
    typealias Chunk = KyleOSSchemaV32.Chunk

    @discardableResult
    static func recordStatusChange(
        from oldValue: String,
        to newValue: String,
        workItem: WorkItem? = nil,
        clip: Clip? = nil,
        sketchProject: Project? = nil,
        joke: Joke? = nil,
        chunk: Chunk? = nil,
        context: ModelContext
    ) -> HistoryEvent {
        let event = HistoryEvent(
            kind: .statusChanged, oldValue: oldValue, newValue: newValue,
            workItem: workItem, clip: clip, sketchProject: sketchProject, joke: joke, chunk: chunk
        )
        context.insert(event)
        return event
    }

    @discardableResult
    static func recordProgressChange(from oldValue: Int, to newValue: Int, workItem: WorkItem, context: ModelContext) -> HistoryEvent {
        let event = HistoryEvent(kind: .progressChanged, oldValue: String(oldValue), newValue: String(newValue), workItem: workItem)
        context.insert(event)
        return event
    }

    static func events(for workItem: WorkItem, in context: ModelContext) throws -> [HistoryEvent] {
        let workItemID = workItem.id
        return try context.fetch(
            FetchDescriptor<HistoryEvent>(
                predicate: #Predicate { $0.workItem?.id == workItemID },
                sortBy: [SortDescriptor(\.occurredAt)]
            )
        )
    }

    static func events(for clip: Clip, in context: ModelContext) throws -> [HistoryEvent] {
        let clipID = clip.id
        return try context.fetch(
            FetchDescriptor<HistoryEvent>(
                predicate: #Predicate { $0.clip?.id == clipID },
                sortBy: [SortDescriptor(\.occurredAt)]
            )
        )
    }

    static func events(for project: Project, in context: ModelContext) throws -> [HistoryEvent] {
        let projectID = project.id
        return try context.fetch(
            FetchDescriptor<HistoryEvent>(
                predicate: #Predicate { $0.sketchProject?.id == projectID },
                sortBy: [SortDescriptor(\.occurredAt)]
            )
        )
    }

    static func events(for joke: Joke, in context: ModelContext) throws -> [HistoryEvent] {
        let jokeID = joke.id
        return try context.fetch(
            FetchDescriptor<HistoryEvent>(
                predicate: #Predicate { $0.joke?.id == jokeID },
                sortBy: [SortDescriptor(\.occurredAt)]
            )
        )
    }

    static func events(for chunk: Chunk, in context: ModelContext) throws -> [HistoryEvent] {
        let chunkID = chunk.id
        return try context.fetch(
            FetchDescriptor<HistoryEvent>(
                predicate: #Predicate { $0.chunk?.id == chunkID },
                sortBy: [SortDescriptor(\.occurredAt)]
            )
        )
    }
}
