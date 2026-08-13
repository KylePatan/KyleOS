import XCTest
import SwiftData
@testable import KyleOS

final class SourceServiceTests: XCTestCase {

    private func makeTempFile(named name: String = "footage.mov") throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(name)
        try "fake media bytes".write(to: fileURL, atomically: true, encoding: .utf8)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: dir)
        }
        return fileURL
    }

    func testCreateSourceStoresFields() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let recordingDate = Date(timeIntervalSince1970: 1_700_000_000)

        let source = SourceService.createSource(
            title: "March Comedy Slam",
            recordingDate: recordingDate,
            location: "The Comedy Cellar",
            notes: "Full 20-minute set",
            context: context
        )
        try context.save()

        XCTAssertEqual(source.title, "March Comedy Slam")
        XCTAssertEqual(source.recordingDate, recordingDate)
        XCTAssertEqual(source.location, "The Comedy Cellar")
        XCTAssertEqual(source.notes, "Full 20-minute set")
    }

    func testRenameUpdateLocationNotesAndRecordingDatePersist() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "Draft Title", context: context)
        try context.save()

        SourceService.rename(source, to: "March Comedy Slam")
        SourceService.updateLocation(source, location: "The Comedy Cellar")
        SourceService.updateNotes(source, notes: "Full 20-minute set")
        let newDate = Date(timeIntervalSince1970: 1_700_000_000)
        SourceService.updateRecordingDate(source, date: newDate)
        try context.save()

        XCTAssertEqual(source.title, "March Comedy Slam")
        XCTAssertEqual(source.location, "The Comedy Cellar")
        XCTAssertEqual(source.notes, "Full 20-minute set")
        XCTAssertEqual(source.recordingDate, newDate)
    }

    func testAttachFileLinksFileReferenceToSource() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let fileURL = try makeTempFile()
        try context.save()

        let reference = try SourceService.attachFile(to: source, displayName: "Raw Footage", fileURL: fileURL, context: context)
        try context.save()

        XCTAssertEqual(source.fileReference?.id, reference.id)
        XCTAssertEqual(reference.source?.id, source.id)
        XCTAssertNotNil(reference.bookmarkData)
    }

    func testSourcesSortedNewestFirst() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let older = SourceService.createSource(title: "Older Source", context: context)
        older.createdAt = Date(timeIntervalSince1970: 1_600_000_000)
        let newer = SourceService.createSource(title: "Newer Source", context: context)
        newer.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        try context.save()

        let sources = SourceService.sources(in: context)

        XCTAssertEqual(sources.map(\.title), ["Newer Source", "Older Source"])
    }

    func testDeleteSourceCascadeDeletesItsClipsAndFileReference() throws {
        let container = PersistenceController.makeInMemoryContainer()
        let context = ModelContext(container)
        let source = SourceService.createSource(title: "March Comedy Slam", context: context)
        let fileURL = try makeTempFile()
        let reference = try SourceService.attachFile(to: source, displayName: "Raw Footage", fileURL: fileURL, context: context)
        let clip = ClipService.createClip(title: "Airline Bit", in: source, context: context)
        try context.save()
        let referenceID = reference.id
        let clipID = clip.id

        SourceService.delete(source, context: context)
        try context.save()

        let remainingReferences = try context.fetch(FetchDescriptor<SourceService.FileReference>())
        XCTAssertFalse(remainingReferences.contains { $0.id == referenceID })
        let remainingClips = try context.fetch(FetchDescriptor<ClipService.Clip>())
        XCTAssertFalse(remainingClips.contains { $0.id == clipID })
    }
}
