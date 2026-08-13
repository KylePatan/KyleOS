import XCTest
import SwiftData
@testable import KyleOS

final class PlannedSessionPersistenceTests: XCTestCase {

    func testSchedulingASessionPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let when = Date(timeIntervalSinceNow: 3600)
        let session = PlannedSessionService.schedule(for: workItem, at: when, durationMinutes: 45, context: context)
        try context.save()

        XCTAssertEqual(session.status, .scheduled)
        XCTAssertEqual(session.origin, .manual)
        XCTAssertFalse(session.isLocked)
        XCTAssertEqual(try PlannedSessionService.sessions(for: workItem, in: context).map(\.id), [session.id])
    }

    func testLockedSessionCannotBeRescheduled() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let originalTime = Date(timeIntervalSinceNow: 3600)
        let session = PlannedSessionService.schedule(for: workItem, at: originalTime, durationMinutes: 45, context: context)
        PlannedSessionService.setLocked(session, true)
        try context.save()

        PlannedSessionService.reschedule(session, to: Date(timeIntervalSinceNow: 7200))

        XCTAssertEqual(session.scheduledAt, originalTime, "A locked session must not move")
    }

    func testStatusTransitions() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let s1 = PlannedSessionService.schedule(for: workItem, at: .now, durationMinutes: 30, context: context)
        let s2 = PlannedSessionService.schedule(for: workItem, at: .now, durationMinutes: 30, context: context)
        let s3 = PlannedSessionService.schedule(for: workItem, at: .now, durationMinutes: 30, context: context)
        try context.save()

        PlannedSessionService.markCompleted(s1)
        PlannedSessionService.markMissed(s2)
        PlannedSessionService.markCancelled(s3)
        try context.save()

        XCTAssertEqual(s1.status, .completed)
        XCTAssertEqual(s2.status, .missed)
        XCTAssertEqual(s3.status, .cancelled)
    }

    func testUpcomingOnlyReturnsFutureScheduledSessions() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let past = PlannedSessionService.schedule(
            for: workItem, at: Date(timeIntervalSinceNow: -3600), durationMinutes: 30, context: context
        )
        let futureCompleted = PlannedSessionService.schedule(
            for: workItem, at: Date(timeIntervalSinceNow: 3600), durationMinutes: 30, context: context
        )
        let futureScheduled = PlannedSessionService.schedule(
            for: workItem, at: Date(timeIntervalSinceNow: 7200), durationMinutes: 30, context: context
        )
        PlannedSessionService.markCompleted(futureCompleted)
        try context.save()
        _ = past

        let upcoming = try PlannedSessionService.upcoming(in: context)
        XCTAssertEqual(upcoming.map(\.id), [futureScheduled.id])
    }

    func testDeletingWorkItemCascadesToItsPlannedSessions() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        PlannedSessionService.schedule(for: workItem, at: .now, durationMinutes: 30, context: context)
        try context.save()

        context.delete(workItem)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<KyleOSSchemaV12.PlannedSession>())
        XCTAssertEqual(remaining.count, 0, "Deleting a Work Item must cascade-delete its Planned Sessions")
    }

    func testDataSurvivesReopeningTheStore() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSPlannedSessionRestartTest-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let sessionID: UUID
        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
            let workItem = try WorkItemService.createWorkItem(
                title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
            )
            let session = PlannedSessionService.schedule(
                for: workItem, at: Date(timeIntervalSinceNow: 3600), durationMinutes: 45, context: context
            )
            sessionID = session.id
            try context.save()
        }

        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let sessions = try context.fetch(FetchDescriptor<KyleOSSchemaV12.PlannedSession>())
            XCTAssertEqual(sessions.count, 1)
            XCTAssertEqual(sessions.first?.id, sessionID)
            XCTAssertEqual(sessions.first?.plannedDurationMinutes, 45)
            XCTAssertNotNil(sessions.first?.workItem, "The Work Item relationship must survive a restart")
        }
    }
}
