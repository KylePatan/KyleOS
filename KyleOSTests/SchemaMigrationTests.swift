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
        }
    }
}
