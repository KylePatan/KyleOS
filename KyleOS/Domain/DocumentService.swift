import Foundation
import SwiftData

/// Reusable domain actions for Documents, kept out of views per CLAUDE.md §4. Content storage
/// is plain text — structured Script Blocks (PRD §14.3) are Decision Gate A territory, resolved
/// during V0.2 Writing, not decided here.
enum DocumentService {
    typealias Document = KyleOSSchemaV23.Document
    typealias DocumentType = KyleOSSchemaV23.DocumentType
    typealias Project = KyleOSSchemaV23.Project

    @discardableResult
    static func createDocument(
        title: String,
        type: DocumentType,
        in project: Project,
        context: ModelContext
    ) -> Document {
        let document = Document(title: title, documentType: type, project: project)
        context.insert(document)
        return document
    }

    static func rename(_ document: Document, to newTitle: String) {
        document.title = newTitle
        document.updatedAt = .now
    }

    /// The actual autosave write. Callers debounce via AutosaveController — this just persists.
    static func updateContent(_ document: Document, content: String) {
        document.content = content
        document.updatedAt = .now
    }

    static func documents(for project: Project, in context: ModelContext) throws -> [Document] {
        let projectID = project.id
        let descriptor = FetchDescriptor<Document>(
            predicate: #Predicate { $0.project?.id == projectID },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }
}
