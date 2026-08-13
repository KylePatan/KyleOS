import Foundation
import SwiftData

/// Reusable domain actions for Sketch production (PRD §9.1/§9.2/§9.6/§9.8), kept out of views
/// per CLAUDE.md §4. "A finished Sketch should appear in Sketches automatically as the same
/// Project, not a copied project" — there is no separate handoff action or Sketch entity;
/// `finishedSketchProjects` just filters the existing `Project` fields that already carry this
/// (`WritingProjectType.sketch`, `ProjectStatus.finished`, both since V8).
enum SketchProductionService {
    typealias Project = KyleOSSchemaV22.Project
    typealias SketchProduction = KyleOSSchemaV22.SketchProduction
    typealias SketchProductionStatus = KyleOSSchemaV22.SketchProductionStatus

    /// Read-only, never creates a `SketchProduction` row — merely viewing the board must not
    /// write anything. `nil` reads as the natural starting state, the same Optional-with-
    /// computed-fallback shape used throughout this codebase (e.g. `Chunk.displayOrderInHeadlineSet`).
    static func status(for project: Project) -> SketchProductionStatus {
        project.sketchProduction?.status ?? .filmingNotScheduled
    }

    static func postDate(for project: Project) -> Date? {
        project.sketchProduction?.postDate
    }

    @discardableResult
    static func findOrCreateProduction(for project: Project, context: ModelContext) -> SketchProduction {
        if let existing = project.sketchProduction { return existing }
        let production = SketchProduction()
        production.project = project
        context.insert(production)
        return production
    }

    static func changeStatus(for project: Project, to status: SketchProductionStatus, context: ModelContext) {
        let production = findOrCreateProduction(for: project, context: context)
        production.status = status
        production.updatedAt = .now
    }

    static func setPostDate(for project: Project, date: Date?, context: ModelContext) {
        let production = findOrCreateProduction(for: project, context: context)
        production.postDate = date
        production.updatedAt = .now
    }

    /// PRD §9.2. Fetches all Projects (no `#Predicate`, since `projectType`/`status` are
    /// enum-typed — the Sixth/Tenth lesson) and filters in-memory.
    static func finishedSketchProjects(in context: ModelContext) -> [Project] {
        let all = (try? context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? []
        return all.filter { $0.projectType == .sketch && $0.status == .finished && !$0.isArchived }
    }

    static func finishedSketchProjects(inStatus status: SketchProductionStatus, in context: ModelContext) -> [Project] {
        finishedSketchProjects(in: context).filter { Self.status(for: $0) == status }
    }
}
