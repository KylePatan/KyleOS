import Foundation
import SwiftData

/// Reusable domain actions for File References (PRD §16.4/§14.15), kept out of views per
/// CLAUDE.md §4. Creates the macOS bookmark; resolution/availability-checking lives in
/// FileReferenceResolver so the two concerns (persistence vs. live filesystem access) are
/// independently testable.
enum FileReferenceService {
    typealias FileReference = KyleOSSchemaV11.FileReference
    typealias Project = KyleOSSchemaV11.Project

    enum FileReferenceError: Error {
        case bookmarkCreationFailed(underlying: Error)
    }

    @discardableResult
    static func create(
        displayName: String,
        fileURL: URL,
        project: Project? = nil,
        notes: String = "",
        context: ModelContext
    ) throws -> FileReference {
        let bookmarkData: Data
        do {
            bookmarkData = try fileURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            throw FileReferenceError.bookmarkCreationFailed(underlying: error)
        }
        let reference = FileReference(
            displayName: displayName,
            originalPath: fileURL.path,
            bookmarkData: bookmarkData,
            notes: notes,
            project: project
        )
        context.insert(reference)
        return reference
    }

    static func rename(_ reference: FileReference, to newDisplayName: String) {
        reference.displayName = newDisplayName
        reference.updatedAt = .now
    }

    static func updateNotes(_ reference: FileReference, notes: String) {
        reference.notes = notes
        reference.updatedAt = .now
    }

    static func all(in context: ModelContext) throws -> [FileReference] {
        try context.fetch(FetchDescriptor<FileReference>(sortBy: [SortDescriptor(\.displayName)]))
    }

    static func references(for project: Project, in context: ModelContext) throws -> [FileReference] {
        let projectID = project.id
        let descriptor = FetchDescriptor<FileReference>(
            predicate: #Predicate { $0.project?.id == projectID },
            sortBy: [SortDescriptor(\.displayName)]
        )
        return try context.fetch(descriptor)
    }
}
