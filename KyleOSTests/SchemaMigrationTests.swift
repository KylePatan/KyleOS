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
            // A hard Deadline automatically appears on Calendar (PRD §11.3) — no need to create
            // the CalendarEvent manually.
            let deadline = DeadlineService.setDeadline(
                for: project, label: "Submission Deadline", dueAt: .now, context: context
            )
            try context.save()

            XCTAssertEqual(project.deadline?.id, deadline.id)
            let events = try CalendarEventService.events(from: .distantPast, to: .distantFuture, in: context)
            XCTAssertEqual(events.map(\.id), deadline.calendarEvents.map(\.id))
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

    func testStoreWrittenUnderV6OpensCleanlyAsV7WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV6Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        // Write a store using ONLY the V6 schema shape — FileReference does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV6.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV6.Project(title: "Pre-V7 Project")
            projectID = project.id
            context.insert(project)
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

            // The new entity must actually be usable post-migration, not just present.
            let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
            try "fake media bytes".write(to: tempFile, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: tempFile) }

            let reference = try FileReferenceService.create(displayName: "Clip", fileURL: tempFile, project: project, context: context)
            try context.save()

            XCTAssertEqual(try FileReferenceService.references(for: project, in: context).map(\.id), [reference.id])
        }
    }

    func testStoreWrittenUnderV7OpensCleanlyAsV8WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV7Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        let documentID: UUID
        // Write a store using ONLY the V7 schema shape — Project has no projectType/status,
        // Document has no currentDraftLabel/drafts, and Draft does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV7.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV7.Project(title: "Pre-V8 Project")
            projectID = project.id
            context.insert(project)
            let document = KyleOSSchemaV7.Document(title: "Draft", documentType: .prose, project: project, content: "Once upon a time...")
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
            XCTAssertNil(project.projectType, "New optional field should default to nil, not crash or fabricate data")
            XCTAssertNil(project.status, "Lightweight migration leaves pre-existing rows nil (see KyleOSSchemaV8's doc comment) rather than crashing")
            XCTAssertEqual(project.displayStatus, .active, "nil reads as Active, the sensible default for pre-existing work")

            let documents = try DocumentService.documents(for: project, in: context)
            XCTAssertEqual(documents.count, 1)
            XCTAssertEqual(documents.first?.id, documentID)
            guard let document = documents.first else {
                return XCTFail("Expected the pre-migration document to survive")
            }
            XCTAssertEqual(document.content, "Once upon a time...", "Existing content must survive untouched")
            XCTAssertNil(document.currentDraftLabel, "Same lightweight-migration reasoning as Project.status")
            XCTAssertEqual(document.displayDraftLabel, "First Draft")
            XCTAssertTrue(document.drafts.isEmpty)

            // The new entity must actually be usable post-migration, not just present.
            let frozen = DraftService.startNewDraft(for: document, context: context)
            try context.save()

            XCTAssertEqual(DraftService.drafts(for: document).map(\.id), [frozen.id])
            XCTAssertEqual(frozen.content, "Once upon a time...")
            XCTAssertEqual(frozen.label, "First Draft")
            XCTAssertEqual(document.currentDraftLabel, "Second Draft", "Any write self-heals the field to a concrete value going forward")
        }
    }

    func testStoreWrittenUnderV8OpensCleanlyAsV9WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV8Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        let documentID: UUID
        // Write a store using ONLY the V8 schema shape — Act does not exist yet, Document has no
        // `acts` relationship.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV8.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV8.Project(title: "Pre-V9 Project", projectType: .tvPilot)
            projectID = project.id
            context.insert(project)
            let document = KyleOSSchemaV8.Document(title: "Act Outline", documentType: .actOutline, project: project)
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
            guard let document = documents.first else {
                return XCTFail("Expected the pre-migration document to survive")
            }
            XCTAssertTrue(document.acts.isEmpty)

            // The new entity must actually be usable post-migration, not just present.
            let act = ActService.createAct(title: "Act One", in: document, context: context)
            try context.save()

            XCTAssertEqual(ActService.acts(for: document).map(\.id), [act.id])
        }
    }

    func testStoreWrittenUnderV9OpensCleanlyAsV10WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV9Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        let actID: UUID
        // Write a store using ONLY the V9 schema shape — Scene does not exist yet, Act has no
        // `scenes` relationship.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV9.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV9.Project(title: "Pre-V10 Project", projectType: .tvPilot)
            projectID = project.id
            context.insert(project)
            let document = KyleOSSchemaV9.Document(title: "Act Outline", documentType: .actOutline, project: project)
            context.insert(document)
            let act = KyleOSSchemaV9.Act(title: "Act One", order: 0, document: document)
            actID = act.id
            context.insert(act)
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
            guard let project = projects.first else {
                return XCTFail("Expected the pre-migration project to survive")
            }
            let documents = try DocumentService.documents(for: project, in: context)
            guard let document = documents.first else {
                return XCTFail("Expected the pre-migration document to survive")
            }
            let acts = ActService.acts(for: document)
            XCTAssertEqual(acts.count, 1)
            XCTAssertEqual(acts.first?.id, actID)
            guard let act = acts.first else {
                return XCTFail("Expected the pre-migration act to survive")
            }
            XCTAssertTrue(act.scenes.isEmpty)

            // The new entity must actually be usable post-migration, not just present.
            let scene = SceneService.createScene(in: act, context: context)
            try context.save()

            XCTAssertEqual(SceneService.scenes(for: act).map(\.id), [scene.id])
            XCTAssertEqual(SceneService.numberedScenes(for: document).map(\.number), [1])
        }
    }

    func testStoreWrittenUnderV10OpensCleanlyAsV11WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV10Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        let documentID: UUID
        // Write a store using ONLY the V10 schema shape — Project has no lastOpenedDocument.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV10.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV10.Project(title: "Pre-V11 Project", projectType: .shortStory)
            projectID = project.id
            context.insert(project)
            let document = KyleOSSchemaV10.Document(title: "Chapter One", documentType: .prose, project: project)
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
            guard let project = projects.first else {
                return XCTFail("Expected the pre-migration project to survive")
            }
            XCTAssertNil(project.lastOpenedDocument, "New optional field should default to nil, not crash or fabricate data")

            let documents = try DocumentService.documents(for: project, in: context)
            XCTAssertEqual(documents.count, 1)
            XCTAssertEqual(documents.first?.id, documentID)
            guard let document = documents.first else {
                return XCTFail("Expected the pre-migration document to survive")
            }

            // The new field must actually be usable post-migration, not just present.
            ProjectService.recordLastOpenedDocument(document, in: project)
            try context.save()

            XCTAssertEqual(project.lastOpenedDocument?.id, documentID)
        }
    }

    func testStoreWrittenUnderV11OpensCleanlyAsV12WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV11Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        let documentID: UUID
        // Write a store using ONLY the V11 schema shape — ScriptBlock does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV11.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV11.Project(title: "Pre-V12 Project", projectType: .tvPilot)
            projectID = project.id
            context.insert(project)
            let document = KyleOSSchemaV11.Document(title: "Pilot Script", documentType: .script, project: project)
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
            guard let project = projects.first else {
                return XCTFail("Expected the pre-migration project to survive")
            }
            let documents = try DocumentService.documents(for: project, in: context)
            XCTAssertEqual(documents.count, 1)
            XCTAssertEqual(documents.first?.id, documentID)
            guard let document = documents.first else {
                return XCTFail("Expected the pre-migration document to survive")
            }
            XCTAssertTrue(document.scriptBlocks.isEmpty)

            // The new entity must actually be usable post-migration, not just present.
            ScriptBlockService.replaceAllBlocks(for: document, with: [(.sceneHeading, "INT. DINER - DAY")], context: context)
            try context.save()

            XCTAssertEqual(ScriptBlockService.blocks(for: document).map(\.text), ["INT. DINER - DAY"])
        }
    }

    func testStoreWrittenUnderV12OpensCleanlyAsV13WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV12Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        // Write a store using ONLY the V12 schema shape — Joke does not exist yet. Joke has no
        // relationship to any existing model, so this test's job is mainly confirming unrelated
        // data survives a migration stage that adds a wholly independent new model.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV12.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV12.Project(title: "Pre-V13 Project")
            projectID = project.id
            context.insert(project)
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

            // The new entity must actually be usable post-migration, not just present.
            let joke = JokeService.quickCapture(text: "A brand new joke.", context: context)
            try context.save()

            XCTAssertEqual(JokeService.jokes(withStatus: .ideas, in: context).map(\.id), [joke.id])
        }
    }

    func testStoreWrittenUnderV13OpensCleanlyAsV14WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV13Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let jokeID: UUID
        // Write a store using ONLY the V13 schema shape — Joke has no chunk/orderWithinChunk,
        // Chunk does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV13.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let joke = KyleOSSchemaV13.Joke(text: "Pre-V14 joke.", order: 0)
            jokeID = joke.id
            context.insert(joke)
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

            let jokes = JokeService.jokes(withStatus: .ideas, in: context)
            XCTAssertEqual(jokes.count, 1)
            XCTAssertEqual(jokes.first?.id, jokeID)
            guard let joke = jokes.first else {
                return XCTFail("Expected the pre-migration joke to survive")
            }
            XCTAssertNil(joke.chunk, "New optional field should default to nil, not crash or fabricate data")
            XCTAssertNil(joke.orderWithinChunk)
            XCTAssertEqual(joke.displayOrderWithinChunk, 0)

            // The new entity must actually be usable post-migration, not just present.
            let chunk = ChunkService.createChunk(title: "Travel Bit", context: context)
            ChunkService.addJoke(joke, to: chunk)
            try context.save()

            XCTAssertEqual(ChunkService.jokes(in: chunk).map(\.id), [jokeID])
            XCTAssertEqual(joke.chunk?.id, chunk.id)
        }
    }

    func testStoreWrittenUnderV14OpensCleanlyAsV15WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV14Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let chunkID: UUID
        // Write a store using ONLY the V14 schema shape — Chunk has no headlineSet/
        // orderInHeadlineSet, HeadlineSet does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV14.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let chunk = KyleOSSchemaV14.Chunk(title: "Pre-V15 Chunk")
            chunkID = chunk.id
            context.insert(chunk)
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

            let chunks = HeadlineSetService.looseChunks(in: context)
            XCTAssertEqual(chunks.count, 1)
            XCTAssertEqual(chunks.first?.id, chunkID)
            guard let chunk = chunks.first else {
                return XCTFail("Expected the pre-migration chunk to survive")
            }
            XCTAssertNil(chunk.headlineSet, "New optional field should default to nil, not crash or fabricate data")
            XCTAssertNil(chunk.orderInHeadlineSet)
            XCTAssertEqual(chunk.displayOrderInHeadlineSet, 0)

            // The new entity must actually be usable post-migration, not just present.
            let set = HeadlineSetService.createHeadlineSet(title: "Fall Tour Set", context: context)
            HeadlineSetService.addChunk(chunk, to: set)
            try context.save()

            XCTAssertEqual(HeadlineSetService.chunks(in: set).map(\.id), [chunkID])
            XCTAssertEqual(chunk.headlineSet?.id, set.id)
        }
    }

    func testStoreWrittenUnderV15OpensCleanlyAsV16WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV15Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let eventID: UUID
        // Write a store using ONLY the V15 schema shape — CalendarEvent has no `gig` field,
        // Gig does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV15.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let event = KyleOSSchemaV15.CalendarEvent(
                eventType: .personal,
                startAt: .now,
                endAt: .now.addingTimeInterval(3600)
            )
            eventID = event.id
            context.insert(event)
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

            let events = try context.fetch(FetchDescriptor<CalendarEventService.CalendarEvent>())
            XCTAssertEqual(events.count, 1)
            guard let event = events.first(where: { $0.id == eventID }) else {
                return XCTFail("Expected the pre-migration calendar event to survive")
            }
            XCTAssertNil(event.gig, "New optional field should default to nil, not crash or fabricate data")

            // The new entity must actually be usable post-migration, not just present.
            let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
            try context.save()

            XCTAssertNotNil(gig.calendarEvent)
            XCTAssertEqual(gig.calendarEvent?.eventType, .standUpGig)
        }
    }

    func testStoreWrittenUnderV16OpensCleanlyAsV17WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV16Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let jokeID: UUID
        // Write a store using ONLY the V16 schema shape — Joke/Chunk have no setListAppearances,
        // GigSetListItem does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV16.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let joke = KyleOSSchemaV16.Joke(text: "Pre-V17 joke", order: 0)
            jokeID = joke.id
            context.insert(joke)
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

            let jokes = try context.fetch(FetchDescriptor<JokeService.Joke>())
            XCTAssertEqual(jokes.count, 1)
            guard let joke = jokes.first(where: { $0.id == jokeID }) else {
                return XCTFail("Expected the pre-migration joke to survive")
            }
            XCTAssertTrue(joke.setListAppearances.isEmpty, "New relationship array should default to empty, not crash or fabricate data")

            // The new entity must actually be usable post-migration, not just present.
            let gig = GigService.createGig(venue: "The Comedy Cellar", startAt: .now, context: context)
            GigSetListService.addJoke(joke, to: gig, context: context)
            try context.save()

            XCTAssertEqual(GigSetListService.items(in: gig).map { $0.joke?.id }, [jokeID])
        }
    }

    func testStoreWrittenUnderV17OpensCleanlyAsV18WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV17Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let gigID: UUID
        // Write a store using ONLY the V17 schema shape — Gig has no afterGigNotes,
        // GigSetListItem has no performanceNotes.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV17.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let gig = KyleOSSchemaV17.Gig(venue: "Pre-V18 Venue", startAt: .now)
            gigID = gig.id
            context.insert(gig)
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

            let gigs = GigService.gigs(in: context)
            XCTAssertEqual(gigs.count, 1)
            guard let gig = gigs.first(where: { $0.id == gigID }) else {
                return XCTFail("Expected the pre-migration gig to survive")
            }
            XCTAssertNil(gig.afterGigNotes, "New optional field should default to nil, not crash or fabricate data")
            XCTAssertEqual(gig.displayAfterGigNotes, "")

            // The new entity must actually be usable post-migration, not just present.
            GigService.updateAfterGigNotes(gig, notes: "Killed with the closer.")
            try context.save()

            XCTAssertEqual(gig.afterGigNotes, "Killed with the closer.")
        }
    }

    func testStoreWrittenUnderV18OpensCleanlyAsV19WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV18Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let jokeID: UUID
        // Write a store using ONLY the V18 schema shape — WorkItem has no joke/chunk fields yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV18.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let joke = KyleOSSchemaV18.Joke(text: "Pre-V19 joke", order: 0)
            jokeID = joke.id
            context.insert(joke)
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

            let jokes = try context.fetch(FetchDescriptor<JokeService.Joke>())
            XCTAssertEqual(jokes.count, 1)
            guard let joke = jokes.first(where: { $0.id == jokeID }) else {
                return XCTFail("Expected the pre-migration joke to survive")
            }
            XCTAssertTrue(joke.workItems.isEmpty, "New relationship array should default to empty, not crash or fabricate data")

            // The new entity must actually be usable post-migration, not just present.
            let workItem = try WorkItemService.standUpWorkItem(for: joke, context: context)
            try context.save()

            XCTAssertEqual(workItem.joke?.id, jokeID)
            XCTAssertEqual(joke.workItems.map(\.id), [workItem.id])
        }
    }

    func testStoreWrittenUnderV19OpensCleanlyAsV20WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV19Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let jokeID: UUID
        // Write a store using ONLY the V19 schema shape — Source/Clip don't exist yet, Joke has
        // no clipAppearances.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV19.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let joke = KyleOSSchemaV19.Joke(text: "Pre-V20 joke", order: 0)
            jokeID = joke.id
            context.insert(joke)
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

            let jokes = try context.fetch(FetchDescriptor<JokeService.Joke>())
            XCTAssertEqual(jokes.count, 1)
            guard let joke = jokes.first(where: { $0.id == jokeID }) else {
                return XCTFail("Expected the pre-migration joke to survive")
            }
            XCTAssertTrue(joke.clipAppearances.isEmpty, "New relationship array should default to empty, not crash or fabricate data")

            // The new entities must actually be usable post-migration, not just present.
            let source = SourceService.createSource(title: "March Comedy Slam", context: context)
            let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
            ClipService.linkJoke(clip, to: joke)
            try context.save()

            XCTAssertEqual(clip.source?.id, source.id)
            XCTAssertEqual(clip.joke?.id, jokeID)
            XCTAssertEqual(joke.clipAppearances.map(\.id), [clip.id])
        }
    }

    func testStoreWrittenUnderV20OpensCleanlyAsV21WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV20Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let clipID: UUID
        // Write a store using ONLY the V20 schema shape — WorkItem/Clip have no relationship to
        // each other yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV20.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let source = KyleOSSchemaV20.Source(title: "March Comedy Slam")
            let clip = KyleOSSchemaV20.Clip(title: "Pre-V21 Clip")
            clip.source = source
            clipID = clip.id
            context.insert(source)
            context.insert(clip)
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

            let clips = try context.fetch(FetchDescriptor<ClipService.Clip>())
            XCTAssertEqual(clips.count, 1)
            guard let clip = clips.first(where: { $0.id == clipID }) else {
                return XCTFail("Expected the pre-migration clip to survive")
            }
            XCTAssertTrue(clip.workItems.isEmpty, "New relationship array should default to empty, not crash or fabricate data")

            // The new entity must actually be usable post-migration, not just present.
            let workItem = try WorkItemService.clipWorkItem(for: clip, context: context)
            try context.save()

            XCTAssertEqual(workItem.clip?.id, clipID)
            XCTAssertEqual(clip.workItems.map(\.id), [workItem.id])
        }
    }

    func testStoreWrittenUnderV21OpensCleanlyAsV22WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV21Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        // Write a store using ONLY the V21 schema shape — Project has no sketchProduction field,
        // SketchProduction does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV21.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV21.Project(title: "Airport Sketch", projectType: .sketch, status: .finished)
            projectID = project.id
            context.insert(project)
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

            let projects = SketchProductionService.finishedSketchProjects(in: context)
            XCTAssertEqual(projects.count, 1)
            guard let project = projects.first(where: { $0.id == projectID }) else {
                return XCTFail("Expected the pre-migration project to survive")
            }
            XCTAssertNil(project.sketchProduction, "New optional relationship should default to nil, not crash or fabricate data")
            XCTAssertEqual(SketchProductionService.status(for: project), .filmingNotScheduled)

            // The new entity must actually be usable post-migration, not just present.
            SketchProductionService.changeStatus(for: project, to: .filmingScheduled, context: context)
            try context.save()

            XCTAssertEqual(SketchProductionService.status(for: project), .filmingScheduled)
        }
    }

    func testStoreWrittenUnderV22OpensCleanlyAsV23WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV22Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        // Write a store using ONLY the V22 schema shape — SketchProduction has no filmShoot
        // field, FilmShoot does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV22.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV22.Project(title: "Airport Sketch", projectType: .sketch, status: .finished)
            projectID = project.id
            context.insert(project)
            let production = KyleOSSchemaV22.SketchProduction(status: .filmingNotScheduled)
            production.project = project
            context.insert(production)
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

            let projects = SketchProductionService.finishedSketchProjects(in: context)
            guard let project = projects.first(where: { $0.id == projectID }) else {
                return XCTFail("Expected the pre-migration project to survive")
            }
            XCTAssertNil(project.sketchProduction?.filmShoot, "New optional relationship should default to nil, not crash or fabricate data")

            // The new entity must actually be usable post-migration, not just present.
            let shoot = SketchProductionService.scheduleFilm(for: project, callTime: .now, estimatedWrapTime: .now.addingTimeInterval(3600), context: context)
            try context.save()

            XCTAssertEqual(project.sketchProduction?.filmShoot?.id, shoot.id)
            XCTAssertNotNil(shoot.calendarEvent)
        }
    }

    func testStoreWrittenUnderV23OpensCleanlyAsV24WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV23Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        // Write a store using ONLY the V23 schema shape — FilmShoot has no callSheet field,
        // CallSheet does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV23.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV23.Project(title: "Airport Sketch", projectType: .sketch, status: .finished)
            projectID = project.id
            context.insert(project)
            let production = KyleOSSchemaV23.SketchProduction(status: .filmingScheduled)
            production.project = project
            context.insert(production)
            let shoot = KyleOSSchemaV23.FilmShoot(callTime: .now, estimatedWrapTime: .now.addingTimeInterval(3600))
            shoot.sketchProduction = production
            context.insert(shoot)
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

            let projects = SketchProductionService.finishedSketchProjects(in: context)
            guard let project = projects.first(where: { $0.id == projectID }) else {
                return XCTFail("Expected the pre-migration project to survive")
            }
            guard let shoot = project.sketchProduction?.filmShoot else {
                return XCTFail("Expected the pre-migration film shoot to survive")
            }
            XCTAssertNil(shoot.callSheet, "New optional relationship should default to nil, not crash or fabricate data")

            // The new entity must actually be usable post-migration, not just present.
            let callSheet = SketchProductionService.generateCallSheet(for: shoot, projectTitle: project.title, context: context)
            try context.save()

            XCTAssertEqual(shoot.callSheet?.id, callSheet.id)
        }
    }

    func testStoreWrittenUnderV24OpensCleanlyAsV25WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV24Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        // Write a store using ONLY the V24 schema shape — DayJobOverride does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV24.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV24.Project(title: "Untitled Pilot")
            projectID = project.id
            context.insert(project)
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
            guard let project = projects.first(where: { $0.id == projectID }) else {
                return XCTFail("Expected the pre-migration project to survive")
            }
            XCTAssertEqual(project.title, "Untitled Pilot")

            // The new entity must actually be usable post-migration, not just present.
            try DayJobScheduleService.ensureBlocks(from: .now, to: Date(timeIntervalSinceNow: 86400 * 7), context: context)
            try context.save()

            let events = try CalendarEventService.events(from: .now, to: Date(timeIntervalSinceNow: 86400 * 7), in: context)
            XCTAssertFalse(events.isEmpty, "Day Job blocks should have generated for the coming week")
        }
    }

    func testStoreWrittenUnderV25OpensCleanlyAsV26WithDataIntact() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSMigrationV25Test-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        // Write a store using ONLY the V25 schema shape — CapacityOverride does not exist yet.
        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: KyleOSSchemaV25.self),
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = KyleOSSchemaV25.Project(title: "Untitled Pilot")
            projectID = project.id
            context.insert(project)
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
            guard let project = projects.first(where: { $0.id == projectID }) else {
                return XCTFail("Expected the pre-migration project to survive")
            }
            XCTAssertEqual(project.title, "Untitled Pilot")

            // The new entity must actually be usable post-migration, not just present.
            let settings = try SettingsService.currentSettings(in: context)
            let override = try CreativeCapacityService.setOverride(for: .now, hours: 5, context: context)
            try context.save()

            let summary = CreativeCapacityService.todaysCapacity(
                settings: settings, events: [], plannedSessions: [], overrides: [override]
            )
            XCTAssertEqual(summary.baselineHours, 5)
            XCTAssertTrue(summary.isOverridden)
        }
    }
}
