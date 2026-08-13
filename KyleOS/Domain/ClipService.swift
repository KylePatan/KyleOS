import Foundation
import SwiftData

/// Reusable domain actions for Clips (PRD §8.3-§8.4), kept out of views per CLAUDE.md §4. "One
/// Source can contain many Clip records."
enum ClipService {
    typealias Clip = KyleOSSchemaV20.Clip
    typealias Source = KyleOSSchemaV20.Source
    typealias ClipStatus = KyleOSSchemaV20.ClipStatus
    typealias Joke = KyleOSSchemaV20.Joke
    typealias Chunk = KyleOSSchemaV20.Chunk

    /// PRD §8.4: "A board can visually simplify these to To Isolate, Editing, Needs Subtitles,
    /// Ready, Posted." The full 7-state `ClipStatus` remains the real stored value (needed for
    /// later Reports/progress-accuracy work); this is purely a display grouping — a documented
    /// simplification (CLAUDE.md §13), not a data-model decision. `.editedSubtitled` groups with
    /// `.ready` rather than getting its own lane: once subtitles are done the piece is
    /// functionally ready pending final QC, and the PRD's own 5-lane list has no separate lane
    /// for it.
    enum BoardLane: String, CaseIterable {
        case toIsolate = "To Isolate"
        case editing = "Editing"
        case needsSubtitles = "Needs Subtitles"
        case ready = "Ready"
        case posted = "Posted"
    }

    static func boardLane(for status: ClipStatus) -> BoardLane {
        switch status {
        case .identifiedToIsolate: return .toIsolate
        case .footageIsolated, .currentlyEditing: return .editing
        case .editedNotSubtitled: return .needsSubtitles
        case .editedSubtitled, .ready: return .ready
        case .posted: return .posted
        }
    }

    @discardableResult
    static func createClip(title: String, in source: Source, context: ModelContext) -> Clip {
        let clip = Clip(title: title)
        clip.source = source
        context.insert(clip)
        return clip
    }

    static func rename(_ clip: Clip, to title: String) {
        clip.title = title
        clip.updatedAt = .now
    }

    static func updateDescription(_ clip: Clip, description: String) {
        clip.clipDescription = description
        clip.updatedAt = .now
    }

    static func updateNotes(_ clip: Clip, notes: String) {
        clip.notes = notes
        clip.updatedAt = .now
    }

    static func updateEditingNotes(_ clip: Clip, notes: String) {
        clip.editingNotes = notes
        clip.updatedAt = .now
    }

    static func updateTimestamps(_ clip: Clip, startSeconds: Int?, endSeconds: Int?) {
        clip.sourceTimestampStartSeconds = startSeconds
        clip.sourceTimestampEndSeconds = endSeconds
        clip.updatedAt = .now
    }

    static func changeStatus(_ clip: Clip, to status: ClipStatus) {
        clip.status = status
        clip.updatedAt = .now
    }

    static func updateProgress(_ clip: Clip, progress: Int) {
        clip.progress = min(max(progress, 0), 100)
        clip.updatedAt = .now
    }

    static func setPostDate(_ clip: Clip, date: Date?) {
        clip.postDate = date
        clip.updatedAt = .now
    }

    static func linkJoke(_ clip: Clip, to joke: Joke?) {
        clip.joke = joke
        clip.updatedAt = .now
    }

    static func linkChunk(_ clip: Clip, to chunk: Chunk?) {
        clip.chunk = chunk
        clip.updatedAt = .now
    }

    static func clips(in source: Source) -> [Clip] {
        source.clips.sorted { $0.createdAt < $1.createdAt }
    }

    static func allClips(in context: ModelContext) -> [Clip] {
        (try? context.fetch(FetchDescriptor<Clip>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    /// In-memory filter, not `#Predicate` — the Sixth/Tenth lesson: `#Predicate` can't reliably
    /// evaluate a comparison against an enum-typed property. Fine at Foundation's data volumes.
    static func clips(inLane lane: BoardLane, in context: ModelContext) -> [Clip] {
        allClips(in: context).filter { boardLane(for: $0.status) == lane }
    }

    /// Cascade delete rule on `Source.clips` handles cascade removal; this is for deleting one
    /// Clip without touching its Source.
    static func delete(_ clip: Clip, context: ModelContext) {
        context.delete(clip)
    }
}
