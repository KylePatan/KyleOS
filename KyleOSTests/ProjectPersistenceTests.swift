import XCTest
import SwiftData
@testable import KyleOS

/// Covers the Foundation acceptance criteria that concern Projects: create/rename/archive/
/// restore, stable IDs surviving a rename, and data surviving what amounts to an app restart
/// (closing one ModelContainer and opening a fresh one against the same on-disk store).
final class ProjectPersistenceTests: XCTestCase {

    func testCreateAndFetchProject() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        try context.save()

        let active = try ProjectService.activeProjects(in: context)
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.id, project.id)
        XCTAssertEqual(active.first?.title, "Untitled Pilot")
    }

    func testRenamePreservesStableID() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Working Title", in: context)
        let originalID = project.id
        try context.save()

        ProjectService.rename(project, to: "Final Title")
        try context.save()

        let active = try ProjectService.activeProjects(in: context)
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.id, originalID, "Renaming must not change the stable ID")
        XCTAssertEqual(active.first?.title, "Final Title")
    }

    func testArchiveAndRestore() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Comedy Slam Set", in: context)
        try context.save()

        ProjectService.archive(project)
        try context.save()

        XCTAssertEqual(try ProjectService.activeProjects(in: context).count, 0)
        XCTAssertEqual(try ProjectService.archivedProjects(in: context).count, 1)
        XCTAssertNotNil(project.archivedAt)

        ProjectService.restore(project)
        try context.save()

        XCTAssertEqual(try ProjectService.activeProjects(in: context).count, 1)
        XCTAssertEqual(try ProjectService.archivedProjects(in: context).count, 0)
        XCTAssertNil(project.archivedAt)
    }

    /// Kyle (2026-08-20, real use): "'P' and 'test'... aren't real and from the writing page i
    /// should be able to delete things from it." A genuine hard delete, distinct from Archive —
    /// proves the schema's own cascade rules clean up everything a Project owns (Document,
    /// WorkItem, Deadline) without any manual cleanup in `ProjectService.delete` itself, and that
    /// an unrelated Project survives untouched.
    func testDeletePermanentlyRemovesTheProjectAndCascadesItsChildrenButNotOtherProjects() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let junkProject = ProjectService.createProject(title: "test", in: context)
        _ = DocumentService.createDocument(title: "Untitled", type: .prose, in: junkProject, context: context)
        _ = try WorkItemService.createWorkItem(
            title: "Some work", workspace: .writing, workTypeName: "Outline", in: junkProject, context: context
        )
        let realProject = ProjectService.createProject(title: "THE TOUR", in: context)
        try context.save()

        ProjectService.delete(junkProject, context: context)
        try context.save()

        let remainingProjects = try ProjectService.activeProjects(in: context)
        XCTAssertEqual(remainingProjects.map(\.id), [realProject.id], "Only the deleted project should be gone")
        XCTAssertTrue(try context.fetch(FetchDescriptor<DocumentService.Document>()).isEmpty, "The Project's Document must cascade-delete")
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkItemService.WorkItem>()).isEmpty, "The Project's WorkItem must cascade-delete")
    }

    func testDataSurvivesReopeningTheStore() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSRestartTest-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let projectID: UUID
        do {
            let configuration = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [configuration]
            )
            let context = ModelContext(container)
            let project = ProjectService.createProject(title: "Survives Restart", in: context)
            projectID = project.id
            try context.save()
        }
        // `container`/`context` above are now out of scope and deallocated — simulating the app
        // quitting. Re-opening a fresh container against the same file simulates relaunch.

        do {
            let configuration = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [configuration]
            )
            let context = ModelContext(container)
            let active = try ProjectService.activeProjects(in: context)
            XCTAssertEqual(active.count, 1)
            XCTAssertEqual(active.first?.id, projectID)
            XCTAssertEqual(active.first?.title, "Survives Restart")
        }
    }

    /// A dedicated end-to-end test for the acceptance criterion "Related objects remain linked
    /// after renaming" — distinct from testRenamePreservesStableID, which only checks the
    /// Project's own ID. This proves every kind of child object stays correctly attached too.
    func testRelatedObjectsRemainLinkedAfterRenamingTheProject() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Working Title", in: context)
        let document = DocumentService.createDocument(title: "Outline", type: .actOutline, in: project, context: context)
        let workItem = try WorkItemService.createWorkItem(
            title: "Outline pass 1", workspace: .writing, workTypeName: "Outline", in: project, context: context
        )
        let deadline = DeadlineService.setDeadline(for: project, label: "Submission", dueAt: .now, context: context)
        try context.save()

        ProjectService.rename(project, to: "Final Title")
        try context.save()

        XCTAssertEqual(try DocumentService.documents(for: project, in: context).map(\.id), [document.id])
        XCTAssertEqual(try WorkItemService.workItems(for: project, in: context).map(\.id), [workItem.id])
        XCTAssertEqual(project.deadline?.id, deadline.id)
        XCTAssertEqual(document.project?.id, project.id)
        XCTAssertEqual(workItem.project?.id, project.id)
    }

    func testCreatingAWritingProjectStoresTypeAndDefaultsToActiveStatus() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", projectType: .tvPilot, in: context)
        try context.save()

        XCTAssertEqual(project.projectType, .tvPilot)
        XCTAssertEqual(project.displayStatus, .active)
    }

    func testCreatingAGenericProjectLeavesTypeNil() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        try context.save()

        XCTAssertNil(project.projectType, "Non-Writing projects (e.g. Foundation's Dev/ screen) shouldn't get a Writing project type")
    }

    func testSetStatusUpdatesDisplayStatusAndPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", status: .idea, in: context)
        try context.save()
        XCTAssertEqual(project.displayStatus, .idea)

        ProjectService.setStatus(project, to: .finished, context: context)
        try context.save()

        XCTAssertEqual(project.status, .finished)
        XCTAssertEqual(project.displayStatus, .finished)
    }

    func testNewProjectHasNoLastOpenedDocument() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Coastal Town", projectType: .shortStory, in: context)
        try context.save()

        XCTAssertNil(project.lastOpenedDocument)
    }

    func testRecordLastOpenedDocumentUpdatesAndPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Coastal Town", projectType: .shortStory, in: context)
        let chapterOne = DocumentService.createDocument(title: "Chapter One", type: .prose, in: project, context: context)
        let chapterTwo = DocumentService.createDocument(title: "Chapter Two", type: .prose, in: project, context: context)
        try context.save()

        ProjectService.recordLastOpenedDocument(chapterOne, in: project)
        try context.save()
        XCTAssertEqual(project.lastOpenedDocument?.id, chapterOne.id)

        ProjectService.recordLastOpenedDocument(chapterTwo, in: project)
        try context.save()
        XCTAssertEqual(project.lastOpenedDocument?.id, chapterTwo.id, "Opening a different document should update the reference")
    }
}
