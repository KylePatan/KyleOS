import XCTest
import SwiftData
@testable import KyleOS

final class DocumentPersistenceTests: XCTestCase {

    func testCreateAndFetchDocumentsForAProject() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let doc = DocumentService.createDocument(title: "Outline", type: .actOutline, in: project, context: context)
        try context.save()

        let documents = try DocumentService.documents(for: project, in: context)
        XCTAssertEqual(documents.count, 1)
        XCTAssertEqual(documents.first?.id, doc.id)
        XCTAssertEqual(documents.first?.documentType, .actOutline)
    }

    func testUpdatingContentPersists() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let doc = DocumentService.createDocument(title: "Notes", type: .notes, in: project, context: context)
        try context.save()

        DocumentService.updateContent(doc, content: "First draft of a joke about airline food.")
        try context.save()

        let reloaded = try DocumentService.documents(for: project, in: context).first
        XCTAssertEqual(reloaded?.content, "First draft of a joke about airline food.")
    }

    func testDeletingProjectCascadesToItsDocuments() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)

        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        DocumentService.createDocument(title: "Outline", type: .actOutline, in: project, context: context)
        DocumentService.createDocument(title: "Script", type: .script, in: project, context: context)
        try context.save()

        context.delete(project)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<KyleOSSchemaV5.Document>())
        XCTAssertEqual(remaining.count, 0, "Deleting a Project must cascade-delete its Documents")
    }

    func testDataSurvivesReopeningTheStore() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSDocumentRestartTest-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let documentID: UUID
        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
            let doc = DocumentService.createDocument(title: "Outline", type: .actOutline, in: project, context: context)
            DocumentService.updateContent(doc, content: "Beat sheet draft one.")
            documentID = doc.id
            try context.save()
        }

        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let allDocs = try context.fetch(FetchDescriptor<KyleOSSchemaV5.Document>())
            XCTAssertEqual(allDocs.count, 1)
            XCTAssertEqual(allDocs.first?.id, documentID)
            XCTAssertEqual(allDocs.first?.content, "Beat sheet draft one.")
            XCTAssertNotNil(allDocs.first?.project, "The Project relationship must survive a restart")
        }
    }
}
