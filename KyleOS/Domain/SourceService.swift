import Foundation
import SwiftData

/// Reusable domain actions for Source Media (PRD §8.2), kept out of views per CLAUDE.md §4. "A
/// Source can represent a stand-up set, sketch footage, interview, podcast appearance, or other
/// recorded material. Kyle OS should normally reference the existing local video file instead of
/// copying it" — `attachFile` routes through the existing `FileReferenceService`/bookmark
/// infrastructure rather than duplicating file-handling logic.
enum SourceService {
    typealias Source = KyleOSSchemaV26.Source
    typealias FileReference = KyleOSSchemaV26.FileReference

    @discardableResult
    static func createSource(
        title: String,
        recordingDate: Date? = nil,
        location: String = "",
        notes: String = "",
        context: ModelContext
    ) -> Source {
        let source = Source(title: title, recordingDate: recordingDate, location: location, notes: notes)
        context.insert(source)
        return source
    }

    static func rename(_ source: Source, to title: String) {
        source.title = title
        source.updatedAt = .now
    }

    static func updateLocation(_ source: Source, location: String) {
        source.location = location
        source.updatedAt = .now
    }

    static func updateNotes(_ source: Source, notes: String) {
        source.notes = notes
        source.updatedAt = .now
    }

    static func updateRecordingDate(_ source: Source, date: Date?) {
        source.recordingDate = date
        source.updatedAt = .now
    }

    /// "If an external drive is disconnected, the source record and clip metadata remain intact
    /// and the file is simply shown as unavailable" — availability is a live-filesystem concern
    /// resolved by `FileReferenceResolver`, not stored here.
    @discardableResult
    static func attachFile(to source: Source, displayName: String, fileURL: URL, context: ModelContext) throws -> FileReference {
        let reference = try FileReferenceService.create(
            displayName: displayName,
            fileURL: fileURL,
            source: source,
            context: context
        )
        source.updatedAt = .now
        return reference
    }

    static func sources(in context: ModelContext) -> [Source] {
        (try? context.fetch(FetchDescriptor<Source>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
    }

    /// Cascade delete rule on `Source.clips`/`Source.fileReference` removes both along with it.
    static func delete(_ source: Source, context: ModelContext) {
        context.delete(source)
    }
}
