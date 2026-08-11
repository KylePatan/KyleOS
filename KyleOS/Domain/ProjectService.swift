import Foundation
import SwiftData

/// Reusable domain actions for Projects — Create/Rename/Archive/Restore — kept out of views
/// per CLAUDE.md §4 so later modules (Writing, Sketches, ...) call the same logic UI ever does.
enum ProjectService {
    typealias Project = KyleOSSchemaV5.Project

    @discardableResult
    static func createProject(title: String, in context: ModelContext) -> Project {
        let project = Project(title: title)
        context.insert(project)
        return project
    }

    static func rename(_ project: Project, to newTitle: String) {
        project.title = newTitle
        project.updatedAt = .now
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
