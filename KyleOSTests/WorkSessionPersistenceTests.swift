import XCTest
import SwiftData
@testable import KyleOS

final class WorkSessionPersistenceTests: XCTestCase {

    func testLoggingACompletedSessionPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let start = Date()
        let end = start.addingTimeInterval(50 * 60)
        let session = WorkSessionService.logCompletedSession(
            for: workItem,
            startAt: start,
            endAt: end,
            activeDurationSeconds: 45 * 60,
            pausedDurationSeconds: 5 * 60,
            plannedDurationMinutes: 45,
            progressBefore: 0,
            progressAfter: 40,
            entryType: .timer,
            context: context
        )
        try context.save()

        // Active + paused should sum to roughly the wall-clock span, but they're stored
        // separately (PRD §14.8) precisely so "excludes paused time" is derivable.
        XCTAssertEqual(session.activeDurationSeconds, 2700)
        XCTAssertEqual(session.pausedDurationSeconds, 300)
        XCTAssertEqual(session.progressBefore, 0)
        XCTAssertEqual(session.progressAfter, 40)
        XCTAssertEqual(session.entryType, .timer)
        XCTAssertEqual(try WorkSessionService.sessions(for: workItem, in: context).map(\.id), [session.id])
    }

    func testManualEntryDoesNotRequireAPlannedDuration() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let start = Date()
        let session = WorkSessionService.logCompletedSession(
            for: workItem,
            startAt: start,
            endAt: start.addingTimeInterval(1800),
            activeDurationSeconds: 1800,
            progressBefore: 40,
            progressAfter: 55,
            note: "Logged after the fact",
            entryType: .manual,
            context: context
        )
        try context.save()

        XCTAssertNil(session.plannedDurationMinutes)
        XCTAssertEqual(session.note, "Logged after the fact")
        XCTAssertEqual(session.entryType, .manual)
    }

    func testMultipleSessionsForAWorkItemAreOrderedByStartTime() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let first = Date(timeIntervalSinceNow: -7200)
        let second = Date(timeIntervalSinceNow: -3600)
        let s2 = WorkSessionService.logCompletedSession(
            for: workItem, startAt: second, endAt: second.addingTimeInterval(1800),
            activeDurationSeconds: 1800, progressBefore: 20, progressAfter: 35, entryType: .timer, context: context
        )
        let s1 = WorkSessionService.logCompletedSession(
            for: workItem, startAt: first, endAt: first.addingTimeInterval(1800),
            activeDurationSeconds: 1800, progressBefore: 0, progressAfter: 20, entryType: .timer, context: context
        )
        try context.save()

        let sessions = try WorkSessionService.sessions(for: workItem, in: context)
        XCTAssertEqual(sessions.map(\.id), [s1.id, s2.id])
    }

    func testDeletingWorkItemCascadesToItsWorkSessions() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        WorkSessionService.logCompletedSession(
            for: workItem, startAt: .now, endAt: Date(timeIntervalSinceNow: 1800),
            activeDurationSeconds: 1800, progressBefore: 0, progressAfter: 20, entryType: .timer, context: context
        )
        try context.save()

        context.delete(workItem)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<KyleOSSchemaV11.WorkSession>())
        XCTAssertEqual(remaining.count, 0, "Deleting a Work Item must cascade-delete its Work Sessions")
    }

    func testDataSurvivesReopeningTheStore() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSWorkSessionRestartTest-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let sessionID: UUID
        let start = Date()
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
            let session = WorkSessionService.logCompletedSession(
                for: workItem, startAt: start, endAt: start.addingTimeInterval(2700),
                activeDurationSeconds: 2400, pausedDurationSeconds: 300,
                progressBefore: 10, progressAfter: 40, entryType: .timer, context: context
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
            let sessions = try context.fetch(FetchDescriptor<KyleOSSchemaV11.WorkSession>())
            XCTAssertEqual(sessions.count, 1)
            XCTAssertEqual(sessions.first?.id, sessionID)
            XCTAssertEqual(sessions.first?.activeDurationSeconds, 2400)
            XCTAssertEqual(sessions.first?.pausedDurationSeconds, 300)
            XCTAssertNotNil(sessions.first?.workItem, "The Work Item relationship must survive a restart")
        }
    }
}
