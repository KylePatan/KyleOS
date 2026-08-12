import Foundation
import SwiftData

/// Reusable domain actions for Projects — Create/Rename/Archive/Restore — kept out of views
/// per CLAUDE.md §4 so later modules (Writing, Sketches, ...) call the same logic UI ever does.
enum ProjectService {
    typealias Project = KyleOSSchemaV10.Project
    typealias WritingProjectType = KyleOSSchemaV10.WritingProjectType
    typealias ProjectStatus = KyleOSSchemaV10.ProjectStatus

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

    static func setStatus(_ project: Project, to status: ProjectStatus) {
        project.status = status
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
