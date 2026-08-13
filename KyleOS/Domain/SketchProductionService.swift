import Foundation
import SwiftData

/// Reusable domain actions for Sketch production (PRD §9.1/§9.2/§9.6/§9.8), kept out of views
/// per CLAUDE.md §4. "A finished Sketch should appear in Sketches automatically as the same
/// Project, not a copied project" — there is no separate handoff action or Sketch entity;
/// `finishedSketchProjects` just filters the existing `Project` fields that already carry this
/// (`WritingProjectType.sketch`, `ProjectStatus.finished`, both since V8).
enum SketchProductionService {
    typealias Project = KyleOSSchemaV23.Project
    typealias SketchProduction = KyleOSSchemaV23.SketchProduction
    typealias SketchProductionStatus = KyleOSSchemaV23.SketchProductionStatus
    typealias FilmShoot = KyleOSSchemaV23.FilmShoot

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

    // MARK: - Film Scheduling (PRD §9.3)

    /// "Schedule Film Date." Find-or-updates the one FilmShoot per production (there's only ever
    /// one shoot for a Sketch in this model), syncs its CalendarEvent, and — since scheduling a
    /// film date is the pipeline's own trigger for "Filming Scheduled" — advances status if it
    /// was still at the default "Filming Not Scheduled."
    @discardableResult
    static func scheduleFilm(
        for project: Project,
        callTime: Date,
        estimatedWrapTime: Date,
        context: ModelContext
    ) -> FilmShoot {
        let production = findOrCreateProduction(for: project, context: context)
        let shoot: FilmShoot
        if let existing = production.filmShoot {
            shoot = existing
            shoot.callTime = callTime
            shoot.estimatedWrapTime = estimatedWrapTime
            shoot.updatedAt = .now
        } else {
            shoot = FilmShoot(callTime: callTime, estimatedWrapTime: estimatedWrapTime)
            shoot.sketchProduction = production
            context.insert(shoot)
        }
        syncCalendarEvent(for: shoot, context: context)
        if production.status == .filmingNotScheduled {
            production.status = .filmingScheduled
            production.updatedAt = .now
        }
        return shoot
    }

    /// Location/address changes can flip "hard commitment" (§9.3's own rule), so this re-syncs
    /// the CalendarEvent; wardrobe/props/equipment/parking/general notes never affect it.
    static func updateLocation(_ shoot: FilmShoot, location: String, address: String, context: ModelContext) {
        shoot.location = location
        shoot.address = address
        shoot.updatedAt = .now
        syncCalendarEvent(for: shoot, context: context)
    }

    static func updateCastAndCrew(_ shoot: FilmShoot, cast: String, crew: String, context: ModelContext) {
        shoot.cast = cast
        shoot.crew = crew
        shoot.updatedAt = .now
        syncCalendarEvent(for: shoot, context: context)
    }

    static func updateLogistics(
        _ shoot: FilmShoot,
        wardrobe: String,
        props: String,
        equipmentNotes: String,
        parkingAccessInstructions: String,
        generalNotes: String
    ) {
        shoot.wardrobe = wardrobe
        shoot.props = props
        shoot.equipmentNotes = equipmentNotes
        shoot.parkingAccessInstructions = parkingAccessInstructions
        shoot.generalNotes = generalNotes
        shoot.updatedAt = .now
    }

    /// "The shoot automatically appears on Calendar and generally acts as a hard calendar
    /// commitment once cast/crew/location are involved."
    private static func syncCalendarEvent(for shoot: FilmShoot, context: ModelContext) {
        let isHardCommitment = !shoot.location.isEmpty || !shoot.cast.isEmpty || !shoot.crew.isEmpty
        if let event = shoot.calendarEvent {
            event.startAt = shoot.callTime
            event.endAt = shoot.estimatedWrapTime
            event.location = shoot.location
            event.isHardCommitment = isHardCommitment
            event.updatedAt = .now
        } else {
            let event = CalendarEventService.createEvent(
                type: .filmShoot,
                startAt: shoot.callTime,
                endAt: shoot.estimatedWrapTime,
                isHardCommitment: isHardCommitment,
                location: shoot.location,
                context: context
            )
            shoot.calendarEvent = event
        }
    }
}
