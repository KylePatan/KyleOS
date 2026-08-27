import Foundation
import SwiftData

/// Reusable domain actions for Projects — Create/Rename/Archive/Restore — kept out of views
/// per CLAUDE.md §4 so later modules (Writing, Sketches, ...) call the same logic UI ever does.
enum ProjectService {
    typealias Project = KyleOSSchemaV35.Project
    typealias WritingProjectType = KyleOSSchemaV35.WritingProjectType
    typealias ProjectStatus = KyleOSSchemaV35.ProjectStatus
    typealias Document = KyleOSSchemaV35.Document

    @discardableResult
    static func createProject(
        title: String,
        projectType: WritingProjectType? = nil,
        status: ProjectStatus = .active,
        in context: ModelContext
    ) -> Project {
        let project = Project(title: title, projectType: projectType, status: status)
        context.insert(project)
        return project
    }

    static func rename(_ project: Project, to newTitle: String) {
        project.title = newTitle
        project.updatedAt = .now
    }

    /// PRD §14.19: status changes create a history record — enables §13.11's "Writing-to-post
    /// turnaround" (the Project's own transition to `.finished` is "writing done").
    static func setStatus(_ project: Project, to status: ProjectStatus, context: ModelContext) {
        let oldStatus = project.displayStatus
        project.status = status
        project.updatedAt = .now
        guard oldStatus != status else { return }
        HistoryEventService.recordStatusChange(from: oldStatus.rawValue, to: status.rawValue, sketchProject: project, context: context)
    }

    /// PRD §6.17: "Reopening a writing project should restore... last open document." Called
    /// whenever a Document within this project is opened for editing.
    static func recordLastOpenedDocument(_ document: Document, in project: Project) {
        project.lastOpenedDocument = document
    }

    static func archive(_ project: Project) {
        project.isArchived = true
        project.archivedAt = .now
        project.updatedAt = .now
    }

    static func restore(_ project: Project) {
        project.isArchived = false
        project.archivedAt = nil
        project.updatedAt = .now
    }

    /// Kyle (2026-08-20, real use): "'P' and 'test'... aren't real and from the writing page i
    /// should be able to delete things from it." Archive is the right answer for real, finished
    /// work (CLAUDE.md §5 — never lose irreplaceable creative work to a casual delete); this is
    /// the deliberate, user-initiated permanent removal for content that was never real to begin
    /// with. Every child relationship already cascades from `Project` in the schema (Documents,
    /// WorkItems, Deadline, PacketItems), so a plain `context.delete` is enough — no manual
    /// cleanup needed here.
    static func delete(_ project: Project, context: ModelContext) {
        context.delete(project)
    }

    static func activeProjects(in context: ModelContext) throws -> [Project] {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    static func archivedProjects(in context: ModelContext) throws -> [Project] {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.isArchived },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }
}
