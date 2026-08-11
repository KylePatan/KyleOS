import XCTest
import SwiftData
@testable import KyleOS

/// Directly tests the scenario a prior session got wrong: a store written under an older
/// schema shape, reopened by a build that adds new entities. Last time this was done by
/// silently changing KyleOSSchemaV1's model list (no explicit migration stage) and it broke a
/// real store even after a clean rebuild. This time it's a genuine KyleOSSchemaV2 with an
/// explicit MigrationStage — this test is the regression guard proving that actually works.
final class SchemaMigrationTests: XCTestCase {

    func testStoreWrittenUnderV1OpensCleanlyAsV2WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationTest-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        // Write a store using ONLY the V1 schema shape — Document does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV1.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV1.Project(title: "Pre-Migration Project")
            projectID = project.id
            context.insert(project)
            try SettingsService.currentSettings(in: context)
            try context.save()
        }

        // Reopen the same file with the full V1->V2 migration plan, as the real app does.
        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)

            let projects = try ProjectService.activeProjects(in: context)
            XCTAssertEqual(projects.count, 1)
            XCTAssertEqual(projects.first?.id, projectID)
            XCTAssertEqual(projects.first?.title, "Pre-Migration Project")

            // The new entity must actually be usable post-migration, not just present.
            guard let project = projects.first else {
                return XCTFail("Expected the pre-migration project to survive")
            }
            let document = DocumentService.createDocument(
                title: "Outline",
                type: .notes,
                in: project,
                context: context
            )
            try context.save()

            let documents = try DocumentService.documents(for: project, in: context)
            XCTAssertEqual(documents.count, 1)
            XCTAssertEqual(documents.first?.id, document.id)

            // This store also crosses V2->V3 in the same migration run (PersistenceController.schema
            // is V3) — WorkItem, added in V3, must be usable too.
            let workItem = try WorkItemService.createWorkItem(
                title: "Outline pass 1",
                workspace: .writing,
                workTypeName: "Outline",
                in: project,
                context: context
            )
            try context.save()
            let workItems = try WorkItemService.workItems(for: project, in: context)
            XCTAssertEqual(workItems.count, 1)
            XCTAssertEqual(workItems.first?.id, workItem.id)
        }
    }

    func testStoreWrittenUnderV2OpensCleanlyAsV3WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV2Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        let documentID: UUID
        // Write a store using ONLY the V2 schema shape — WorkItem does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV2.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV2.Project(title: "Pre-V3 Project")
            projectID = project.id
            context.insert(project)
            let document = KyleOSSchemaV2.Document(title: "Outline", documentType: .actOutline, project: project)
            documentID = document.id
            context.insert(document)
            try context.save()
        }

        // Reopen with the full migration plan, as the real app does.
        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)

            let projects = try ProjectService.activeProjects(in: context)
            XCTAssertEqual(projects.count, 1)
            XCTAssertEqual(projects.first?.id, projectID)
            guard let project = projects.first else {
                return XCTFail("Expected the pre-migration project to survive")
            }

            let documents = try DocumentService.documents(for: project, in: context)
            XCTAssertEqual(documents.count, 1)
            XCTAssertEqual(documents.first?.id, documentID)

            let workItem = try WorkItemService.createWorkItem(
                title: "Outline pass 1",
                workspace: .writing,
                workTypeName: "Outline",
                in: project,
                context: context
            )
            try context.save()
            let workItems = try WorkItemService.workItems(for: project, in: context)
            XCTAssertEqual(workItems.count, 1)
            XCTAssertEqual(workItems.first?.id, workItem.id)
        }
    }

    func testStoreWrittenUnderV3OpensCleanlyAsV4WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV3Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        let workItemID: UUID
        // Write a store using ONLY the V3 schema shape — Deadline and CalendarEvent do not
        // exist yet, and neither Project nor WorkItem has a `deadline` relationship.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV3.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV3.Project(title: "Pre-V4 Project")
            projectID = project.id
            context.insert(project)
            let workItem = KyleOSSchemaV3.WorkItem(
                title: "Outline", workspace: .writing, workTypeName: "Outline", project: project
            )
            workItemID = workItem.id
            context.insert(workItem)
            try context.save()
        }

        // Reopen with the full migration plan, as the real app does.
        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)

            let projects = try ProjectService.activeProjects(in: context)
            XCTAssertEqual(projects.count, 1)
            XCTAssertEqual(projects.first?.id, projectID)
            guard let project = projects.first else {
                return XCTFail("Expected the pre-migration project to survive")
            }
            XCTAssertNil(project.deadline, "New relationship should default to nil, not crash or fabricate data")

            let workItems = try WorkItemService.workItems(for: project, in: context)
            XCTAssertEqual(workItems.count, 1)
            XCTAssertEqual(workItems.first?.id, workItemID)

            // The new entities must actually be usable post-migration, not just present.
            let deadline = DeadlineService.setDeadline(
                for: project, label: "Submission Deadline", dueAt: .now, context: context
            )
            let event = CalendarEventService.createEvent(
                type: .hardDeadline, startAt: .now, endAt: .now, project: project, deadline: deadline, context: context
            )
            try context.save()

            XCTAssertEqual(project.deadline?.id, deadline.id)
            let events = try CalendarEventService.events(from: .distantPast, to: .distantFuture, in: context)
            XCTAssertEqual(events.map(\.id), [event.id])
        }
    }

    func testStoreWrittenUnderV4OpensCleanlyAsV5WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV4Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        let workItemID: UUID
        // Write a store using ONLY the V4 schema shape — PlannedSession and WorkSession do not
        // exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV4.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV4.Project(title: "Pre-V5 Project")
            projectID = project.id
            context.insert(project)
            let workItem = KyleOSSchemaV4.WorkItem(
                title: "Outline", workspace: .writing, workTypeName: "Outline", project: project
            )
            workItemID = workItem.id
            context.insert(workItem)
            try context.save()
        }

        // Reopen with the full migration plan, as the real app does.
        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)

            let projects = try ProjectService.activeProjects(in: context)
            XCTAssertEqual(projects.count, 1)
            XCTAssertEqual(projects.first?.id, projectID)
            guard let project = projects.first else {
                return XCTFail("Expected the pre-migration project to survive")
            }

            let workItems = try WorkItemService.workItems(for: project, in: context)
            XCTAssertEqual(workItems.count, 1)
            XCTAssertEqual(workItems.first?.id, workItemID)
            guard let workItem = workItems.first else {
                return XCTFail("Expected the pre-migration work item to survive")
            }

            // The new entities must actually be usable post-migration, not just present.
            let plannedSession = PlannedSessionService.schedule(
                for: workItem, at: .now, durationMinutes: 45, context: context
            )
            let workSession = WorkSessionService.logCompletedSession(
                for: workItem,
                startAt: .now,
                endAt: Date(timeIntervalSinceNow: 2700),
                activeDurationSeconds: 2400,
                progressBefore: 0,
                progressAfter: 30,
                entryType: .timer,
                context: context
            )
            try context.save()

            XCTAssertEqual(try PlannedSessionService.sessions(for: workItem, in: context).map(\.id), [plannedSession.id])
            XCTAssertEqual(try WorkSessionService.sessions(for: workItem, in: context).map(\.id), [workSession.id])
        }
    }

    func testStoreWrittenUnderV5OpensCleanlyAsV6WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV5Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        let workItemID: UUID
        // Write a store using ONLY the V5 schema shape — ActiveTimerState does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV5.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV5.Project(title: "Pre-V6 Project")
            projectID = project.id
            context.insert(project)
            let workItem = KyleOSSchemaV5.WorkItem(
                title: "Outline", workspace: .writing, workTypeName: "Outline", project: project
            )
            workItemID = workItem.id
            context.insert(workItem)
            try context.save()
        }

        // Reopen with the full migration plan, as the real app does.
        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)

            let projects = try ProjectService.activeProjects(in: context)
            XCTAssertEqual(projects.count, 1)
            XCTAssertEqual(projects.first?.id, projectID)
            guard let project = projects.first else {
                return XCTFail("Expected the pre-migration project to survive")
            }

            let workItems = try WorkItemService.workItems(for: project, in: context)
            XCTAssertEqual(workItems.count, 1)
            XCTAssertEqual(workItems.first?.id, workItemID)
            guard let workItem = workItems.first else {
                return XCTFail("Expected the pre-migration work item to survive")
            }

            // The new entity must actually be usable post-migration, not just present.
            let timer = FocusTimerController()
            XCTAssertTrue(timer.start(workItem: workItem, targetDurationMinutes: 30, progressBefore: 0, context: context))
            try context.save()

            XCTAssertEqual(try ActiveTimerStateService.interruptedSessions(in: context).count, 1)
        }
    }
}
