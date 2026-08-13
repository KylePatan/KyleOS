import XCTest
import SwiftData
@testable import KyleOS

final class FileReferencePersistenceTests: XCTestCase {

    private func makeTempFile(named name: String = "clip.mov") throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(name)
        try "fake media bytes".write(to: fileURL, atomically: true, encoding: .utf8)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: dir)
        }
        return fileURL
    }

    func testCreatingAFileReferenceStoresBookmarkAndMetadata() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let fileURL = try makeTempFile()

        let reference = try FileReferenceService.create(
            displayName: "Comedy Slam Clip", fileURL: fileURL, notes: "Raw footage from March", context: context
        )
        try context.save()

        XCTAssertNotNil(reference.bookmarkData)
        XCTAssertEqual(reference.originalPath, fileURL.path)
        XCTAssertEqual(reference.notes, "Raw footage from March")
        XCTAssertTrue(reference.lastKnownAvailable)
    }

    func testRenameAndUpdateNotesPersist() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let fileURL = try makeTempFile()

        let reference = try FileReferenceService.create(displayName: "Original Name", fileURL: fileURL, context: context)
        try context.save()

        FileReferenceService.rename(reference, to: "Renamed Clip")
        FileReferenceService.updateNotes(reference, notes: "Updated notes")
        try context.save()

        XCTAssertEqual(reference.displayName, "Renamed Clip")
        XCTAssertEqual(reference.notes, "Updated notes")
    }

    func testReferencesForProjectFiltersCorrectly() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let otherProject = ProjectService.createProject(title: "Other Project", in: context)

        let fileA = try makeTempFile(named: "a.mov")
        let fileB = try makeTempFile(named: "b.mov")
        let ref1 = try FileReferenceService.create(displayName: "A", fileURL: fileA, project: project, context: context)
        try FileReferenceService.create(displayName: "B", fileURL: fileB, project: otherProject, context: context)
        try context.save()

        let refs = try FileReferenceService.references(for: project, in: context)
        XCTAssertEqual(refs.map(\.id), [ref1.id])
    }

    func testDeletingProjectNullifiesRatherThanDeletingTheReference() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let project = ProjectService.createProject(title: "Untitled Pilot", in: context)
        let fileURL = try makeTempFile()
        let reference = try FileReferenceService.create(displayName: "Clip", fileURL: fileURL, project: project, context: context)
        try context.save()

        context.delete(project)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<KyleOSSchemaV18.FileReference>())
        XCTAssertEqual(remaining.count, 1, "Deleting a Project must not destroy a File Reference to real external media")
        XCTAssertEqual(remaining.first?.id, reference.id)
        XCTAssertNil(remaining.first?.project)
    }

    func testDataSurvivesReopeningTheStore() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KyleOSFileReferenceRestartTest-\(UUID().uuidString)")
            .appendingPathComponent("Store.sqlite")
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let fileURL = try makeTempFile()
        let referenceID: UUID
        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let reference = try FileReferenceService.create(displayName: "Clip", fileURL: fileURL, context: context)
            referenceID = reference.id
            try context.save()
        }

        do {
            let container = try ModelContainer(
                for: PersistenceController.schema,
                migrationPlan: KyleOSMigrationPlan.self,
                configurations: [ModelConfiguration(url: storeURL)]
            )
            let context = ModelContext(container)
            let refs = try context.fetch(FetchDescriptor<KyleOSSchemaV18.FileReference>())
            XCTAssertEqual(refs.count, 1)
            XCTAssertEqual(refs.first?.id, referenceID)
            XCTAssertNotNil(refs.first?.bookmarkData, "The bookmark itself must survive a restart")

            // And it must still actually resolve after a real restart, not just persist as bytes.
            // Not a raw string path comparison — see FileReferenceResolverTests for why.
            guard let reference = refs.first else { return XCTFail("Expected the reference to survive") }
            guard case .available(let resolvedPath) = FileReferenceResolver.resolve(reference) else {
                return XCTFail("Expected .available after restart, got a different resolution")
            }
            XCTAssertTrue(FileManager.default.fileExists(atPath: resolvedPath))
            XCTAssertEqual(URL(fileURLWithPath: resolvedPath).lastPathComponent, fileURL.lastPathComponent)
        }
    }
}
